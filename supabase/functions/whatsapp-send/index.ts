import { requirePermission } from '../_shared/auth.ts';
import { serviceClient } from '../_shared/client.ts';
import { corsHeaders, errorMessage, errorResponse, HttpError, json, readJsonObject } from '../_shared/http.ts';
import { sendWhatsApp } from '../_shared/whatsapp.ts';

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    if (request.method !== 'POST') return json({ message: 'Método no permitido' }, 405);
    const client = await requirePermission(request, 'SEGUIMIENTO_ESCRIBIR');
    const body = await readJsonObject(request);
    const retryMessageId = typeof body.retryMessageId === 'number' && Number.isInteger(body.retryMessageId)
      ? body.retryMessageId : null;
    let message: Record<string, unknown>;
    if (retryMessageId && retryMessageId > 0) {
      const retried = await client.rpc('reintentar_mensaje_whatsapp', { mensaje_id: retryMessageId });
      if (retried.error) throw new HttpError(400, retried.error.message);
      message = retried.data;
    } else {
      const patientId = typeof body.patientId === 'number' && Number.isInteger(body.patientId)
        ? body.patientId : null;
      const content = typeof body.content === 'string' ? body.content.trim() : '';
      if (!patientId || patientId <= 0 || !content) {
        throw new HttpError(400, 'Paciente y contenido son obligatorios');
      }
      if (content.length > 4000) throw new HttpError(400, 'El mensaje supera los 4000 caracteres');
      const scheduledFor = typeof body.scheduledFor === 'string' && body.scheduledFor.trim()
        ? body.scheduledFor.trim() : null;
      if (scheduledFor && !Number.isFinite(Date.parse(scheduledFor))) {
        throw new HttpError(400, 'La fecha programada no es válida');
      }
      const queued = await client.rpc('programar_mensaje', { paciente_id: patientId,
        contenido: content, programado_para: scheduledFor });
      if (queued.error) throw new HttpError(400, queued.error.message);
      message = queued.data;
      if (scheduledFor && Date.parse(scheduledFor) > Date.now() + 30_000) return json(message);
    }
    if (!message || typeof message !== 'object') throw new Error('No se pudo recuperar el mensaje creado');

    const admin = serviceClient();
    const messageId = Number(message.id);
    const conversationId = Number(message.conversationId);
    const content = String(message.content ?? '').trim();
    const attempts = Number(message.attempts ?? 0) + 1;
    if (!Number.isInteger(messageId) || !Number.isInteger(conversationId) || !content) {
      throw new Error('El mensaje creado tiene datos incompletos');
    }

    const claimedAt = new Date().toISOString();
    const claim = await admin.from('mensajes_whatsapp')
      .update({ estado: 'EN_PROCESO', intentos: attempts, ultimo_intento_en: claimedAt })
      .eq('id', messageId).eq('estado', 'PENDIENTE').select('id').maybeSingle();
    if (claim.error) throw new Error(claim.error.message);
    if (!claim.data) throw new HttpError(409, 'El mensaje ya está siendo procesado');

    const eligibility = await admin.rpc('validar_envio_whatsapp', { mensaje_id: messageId });
    if (eligibility.error || !eligibility.data) {
      const reason = eligibility.error?.message ?? 'Envío no autorizado';
      await admin.from('mensajes_whatsapp').update({ estado: 'FALLIDO',
        error_detalle: reason.slice(0, 500), ultimo_intento_en: new Date().toISOString() })
        .eq('id', messageId).eq('estado', 'EN_PROCESO');
      throw new HttpError(409, reason);
    }

    let providerId: string;
    try {
      providerId = await sendWhatsApp(eligibility.data, content);
    } catch (sendError) {
      await admin.from('mensajes_whatsapp').update({ estado: 'FALLIDO',
        error_detalle: errorMessage(sendError).slice(0, 500), intentos: attempts,
        ultimo_intento_en: new Date().toISOString() })
        .eq('id', messageId).eq('estado', 'EN_PROCESO');
      throw new HttpError(502, errorMessage(sendError));
    }

    const sentAt = new Date().toISOString();
    const updated = await admin.from('mensajes_whatsapp').update({ estado: 'ENVIADO', proveedor_id: providerId,
      enviado_en: sentAt, ultimo_intento_en: sentAt, error_detalle: null })
      .eq('id', messageId).eq('estado', 'EN_PROCESO');
    if (updated.error) {
      console.error('WhatsApp aceptó el mensaje, pero no se pudo actualizar su estado', updated.error.message);
      throw new HttpError(500,
        'WhatsApp recibió el mensaje, pero no se pudo confirmar su estado. Verifique el chat antes de reintentar.');
    }
    return json({ ...message, status: 'ENVIADO', attempts, sentAt, errorDetail: null });
  } catch (error) {
    return errorResponse(error);
  }
});
