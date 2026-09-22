import { requireSecret } from '../_shared/auth.ts';
import { errorMessage, errorResponse, json } from '../_shared/http.ts';
import { serviceClient } from '../_shared/client.ts';
import { retryDelay, sendWhatsApp } from '../_shared/whatsapp.ts';

Deno.serve(async (request) => {
  try {
    if (request.method !== 'POST') return json({ message: 'Método no permitido' }, 405);
    requireSecret(request, 'WHATSAPP_CRON_SECRET', 'x-cron-secret');
    const client = serviceClient();
    const staleBefore = new Date(Date.now() - 5 * 60_000).toISOString();
    const recovered = await client.from('mensajes_whatsapp')
      .update({ estado: 'FALLIDO',
        error_detalle: 'El envío quedó interrumpido; revise WhatsApp antes de reintentar' })
      .eq('estado', 'EN_PROCESO').lt('ultimo_intento_en', staleBefore).select('id');
    if (recovered.error) throw new Error(recovered.error.message);

    const reminders = await client.rpc('preparar_recordatorios_whatsapp');
    if (reminders.error) throw new Error(reminders.error.message);
    const pending = await client.from('mensajes_whatsapp')
      .select('id,contenido,conversacion_id,intentos,max_intentos,tipo,parametros_plantilla,cita_id,atencion_id')
      .eq('estado', 'PENDIENTE').lte('programado_para', new Date().toISOString())
      .order('programado_para', { ascending: true }).order('id', { ascending: true }).limit(5);
    if (pending.error) throw new Error(pending.error.message);
    let sent = 0;
    let failed = 0;
    let skipped = 0;
    let uncertain = 0;
    let rescheduled = 0;
    for (const message of pending.data ?? []) {
      const claimedAt = new Date().toISOString();
      const attempts = Number(message.intentos) + 1;
      if (attempts > Number(message.max_intentos)) {
        await client.from('mensajes_whatsapp').update({ estado: 'FALLIDO',
          error_detalle: 'Se alcanzó el máximo de intentos de envío' }).eq('id', message.id)
          .eq('estado', 'PENDIENTE');
        failed++;
        continue;
      }
      const claim = await client.from('mensajes_whatsapp')
        .update({ estado: 'EN_PROCESO', intentos: attempts, ultimo_intento_en: claimedAt })
        .eq('id', message.id).eq('estado', 'PENDIENTE').select('id').maybeSingle();
      if (claim.error) throw new Error(claim.error.message);
      if (!claim.data) {
        skipped++;
        continue;
      }
      // Once a request reaches Evolution, a timeout does not prove the message was not sent.
      // Keep ambiguous failures out of the automatic queue to avoid duplicate messages.
      const markForReview = async (reason: string) => {
        const result = await client.from('mensajes_whatsapp').update({
          estado: 'FALLIDO', error_detalle: reason.slice(0, 500),
          ultimo_intento_en: new Date().toISOString(),
        }).eq('id', message.id).eq('estado', 'EN_PROCESO');
        if (result.error) console.error('No se pudo marcar el mensaje para revisión', message.id, result.error.message);
      };
      let phone: string;
      try {
        const eligibility = await client.rpc('validar_envio_whatsapp', { mensaje_id: message.id });
        if (eligibility.error || !eligibility.data) throw new Error(eligibility.error?.message ?? 'Envío no autorizado');
        phone = eligibility.data;
        if (message.cita_id && ['CITA_CONFIRMACION', 'CITA_RECORDATORIO'].includes(message.tipo)) {
          const appointment = await client.from('citas').select('estado').eq('id', message.cita_id).single();
          if (appointment.error || !appointment.data) throw new Error('No se pudo verificar la cita');
          if (!['PENDIENTE_CONFIRMACION', 'CONFIRMADA'].includes(appointment.data.estado)
            || (message.tipo === 'CITA_CONFIRMACION' && appointment.data.estado !== 'PENDIENTE_CONFIRMACION')) {
            const cancelled = await client.from('mensajes_whatsapp').update({
              estado: 'CANCELADO', error_detalle: 'La cita ya no requiere este mensaje',
            }).eq('id', message.id).eq('estado', 'EN_PROCESO');
            if (cancelled.error) throw new Error(cancelled.error.message);
            skipped++;
            continue;
          }
        }
      } catch (error) {
        await markForReview(`No se pudo preparar el envío: ${errorMessage(error)}`);
        failed++;
        continue;
      }

      let providerId: string;
      try {
        providerId = await sendWhatsApp(phone, message.contenido);
      } catch (error) {
        const delay = retryDelay(error, attempts, Number(message.max_intentos));
        if (delay !== null) {
          const retry = await client.from('mensajes_whatsapp').update({ estado: 'PENDIENTE',
            programado_para: new Date(Date.now() + delay).toISOString(),
            error_detalle: 'Proveedor ocupado (429); reintento programado',
          }).eq('id', message.id).eq('estado', 'EN_PROCESO');
          if (retry.error) throw new Error(retry.error.message);
          rescheduled++;
          continue;
        }
        await markForReview(`Evolution pudo recibir el mensaje; verifique WhatsApp antes de reintentar: ${errorMessage(error)}`);
        failed++;
        uncertain++;
        continue;
      }

      const sentAt = new Date().toISOString();
      const updated = await client.from('mensajes_whatsapp').update({ estado: 'ENVIADO',
        proveedor_id: providerId, enviado_en: sentAt, ultimo_intento_en: sentAt,
        error_detalle: null }).eq('id', message.id).eq('estado', 'EN_PROCESO').select('id').maybeSingle();
      if (updated.error || !updated.data) {
        // Evolution accepted the request. Never return this message to PENDIENTE.
        console.error('Evolution recibió el mensaje, pero no se pudo registrar el envío',
          message.id, updated.error?.message ?? 'Estado modificado por otro proceso');
        await markForReview('Evolution recibió el mensaje, pero no se pudo registrar el envío; verifique WhatsApp antes de reintentar');
        uncertain++;
        continue;
      }
      sent++;
      if (message.tipo === 'CITA_CONFIRMACION' && message.cita_id) {
        const flag = await client.from('citas').update({ confirmacion_enviada: true }).eq('id', message.cita_id);
        if (flag.error) console.error('No se pudo actualizar confirmacion_enviada', message.cita_id, flag.error.message);
      } else if (message.tipo === 'CITA_RECORDATORIO' && message.cita_id) {
        const flag = await client.from('citas').update({ recordatorio_enviado: true }).eq('id', message.cita_id);
        if (flag.error) console.error('No se pudo actualizar recordatorio_enviado', message.cita_id, flag.error.message);
      } else if (message.tipo === 'POSTCONSULTA' && message.atencion_id) {
        const followUp = await client.from('seguimientos_postconsulta')
          .update({ estado: 'ENVIADO', actualizado_en: sentAt }).eq('mensaje_id', message.id);
        if (followUp.error) console.error('No se pudo actualizar seguimiento postconsulta', message.id, followUp.error.message);
      }
    }
    return json({ remindersQueued: reminders.data ?? 0, recovered: recovered.data?.length ?? 0,
      processed: (pending.data ?? []).length, sent, failed, skipped, uncertain, rescheduled });
  } catch (error) {
    return errorResponse(error);
  }
});
