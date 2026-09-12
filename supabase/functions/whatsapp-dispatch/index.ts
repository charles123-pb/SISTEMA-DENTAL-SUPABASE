import { requireSecret } from '../_shared/auth.ts';
import { errorMessage, errorResponse, json } from '../_shared/http.ts';
import { serviceClient } from '../_shared/client.ts';
import { sendWhatsApp } from '../_shared/whatsapp.ts';

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
      .eq('estado', 'PENDIENTE').lte('programado_para', new Date().toISOString()).limit(25);
    if (pending.error) throw new Error(pending.error.message);
    let sent = 0;
    let failed = 0;
    let skipped = 0;
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
      try {
        const conversation = await client.from('conversaciones_whatsapp').select('telefono')
          .eq('id', message.conversacion_id).single();
        if (conversation.error || !conversation.data) throw new Error('Conversación no encontrada');
        const providerId = await sendWhatsApp(conversation.data.telefono, message.contenido);
        const sentAt = new Date().toISOString();
        const updated = await client.from('mensajes_whatsapp').update({ estado: 'ENVIADO',
          proveedor_id: providerId, enviado_en: sentAt, ultimo_intento_en: sentAt,
          error_detalle: null }).eq('id', message.id).eq('estado', 'EN_PROCESO');
        if (updated.error) throw new Error(updated.error.message);
        sent++;
        if (message.tipo === 'CITA_CONFIRMACION' && message.cita_id) {
          await client.from('citas').update({ confirmacion_enviada: true }).eq('id', message.cita_id);
        } else if (message.tipo === 'CITA_RECORDATORIO' && message.cita_id) {
          await client.from('citas').update({ recordatorio_enviado: true }).eq('id', message.cita_id);
        } else if (message.tipo === 'POSTCONSULTA' && message.atencion_id) {
          await client.from('seguimientos_postconsulta').update({ estado: 'ENVIADO', actualizado_en: sentAt }).eq('mensaje_id', message.id);
        }
      } catch (error) {
        const nextStatus = attempts >= message.max_intentos ? 'FALLIDO' : 'PENDIENTE';
        await client.from('mensajes_whatsapp').update({ estado: nextStatus,
          error_detalle: errorMessage(error).slice(0, 500), ultimo_intento_en: new Date().toISOString() })
          .eq('id', message.id).eq('estado', 'EN_PROCESO');
        failed++;
      }
    }
    return json({ remindersQueued: reminders.data ?? 0, recovered: recovered.data?.length ?? 0,
      processed: (pending.data ?? []).length, sent, failed, skipped });
  } catch (error) {
    return errorResponse(error);
  }
});
