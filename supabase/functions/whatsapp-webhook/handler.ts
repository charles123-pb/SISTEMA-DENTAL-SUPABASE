import { matchesSecret } from '../_shared/auth.ts';
import { errorResponse, json, readJsonObject } from '../_shared/http.ts';
import { serviceClient } from '../_shared/client.ts';

const statusMap: Record<string, string> = {
  PENDING: 'PENDIENTE', SERVER_ACK: 'ENVIADO', SENT: 'ENVIADO',
  DELIVERY_ACK: 'ENTREGADO', DELIVERED: 'ENTREGADO', READ: 'LEIDO',
  READ_ACK: 'LEIDO', PLAYED: 'LEIDO', FAILED: 'FALLIDO', ERROR: 'FALLIDO',
  '0': 'FALLIDO', '1': 'PENDIENTE', '2': 'ENVIADO', '3': 'ENTREGADO', '4': 'LEIDO', '5': 'LEIDO',
};
const rank: Record<string, number> = { PENDIENTE: 0, ENVIADO: 1, ENTREGADO: 2, LEIDO: 3 };
const phoneFromJid = (jid: unknown) => String(jid ?? '').split('@')[0].split(':')[0].replace(/\D/g, '');
const textFromMessage = (message: Record<string, any> = {}) =>
  message.conversation ?? message.extendedTextMessage?.text ?? message.imageMessage?.caption
  ?? message.videoMessage?.caption ?? message.buttonsResponseMessage?.selectedDisplayText
  ?? message.listResponseMessage?.title ?? '';
const authorized = (request: Request) => {
  const provided = new URL(request.url).searchParams.get('token')
    ?? request.headers.get('x-webhook-secret') ?? request.headers.get('authorization')?.replace(/^Bearer\s+/i, '');
  return matchesSecret(provided ?? null, 'EVOLUTION_WEBHOOK_SECRET');
};

export async function handleWebhook(request: Request, getClient = serviceClient): Promise<Response> {
  if (request.method !== 'POST') return json({ message: 'Método no permitido' }, 405);
  if (!authorized(request)) return json({ message: 'Webhook no autorizado' }, 401);
  try {
    const payload = await readJsonObject(request);
    const expectedInstance = Deno.env.get('EVOLUTION_INSTANCE_NAME');
    if (expectedInstance && payload.instance && payload.instance !== expectedInstance)
      return json({ received: true, ignored: true });
    const event = String(payload.event ?? '').replaceAll('.', '_').toUpperCase();
    const dataValue = payload.data;
    const data = dataValue && typeof dataValue === 'object' && !Array.isArray(dataValue)
      ? dataValue as Record<string, unknown> : {};
    const client = getClient();

    if (event === 'CONNECTION_UPDATE' || event === 'CONNECTION') {
      const raw = String(data.state ?? data.statusReason ?? data.status ?? '').toLowerCase();
      const state = raw === 'open' || raw === 'connected' ? 'CONECTADO'
        : raw === 'connecting' ? 'CONECTANDO' : raw.includes('error') ? 'ERROR' : 'DESCONECTADO';
      const saved = await client.from('whatsapp_instancia_estado').upsert({ id: 1, estado: state,
        numero: phoneFromJid(data.wuid ?? data.owner) || null, nombre_instancia: payload.instance ?? expectedInstance,
        detalle: raw || null, actualizado_en: new Date().toISOString() });
      if (saved.error) throw new Error(saved.error.message);
    }

    if (event === 'MESSAGES_UPSERT' || event === 'MESSAGE' || event === 'MESSAGES_SET') {
      const items = Array.isArray(dataValue) ? dataValue : [data];
      for (const item of items) {
        const key = item.key ?? item.message?.key ?? {};
        if (key.fromMe || String(key.remoteJid ?? '').endsWith('@g.us')) continue;
        const message = item.message?.message ?? item.message ?? {};
        const content = textFromMessage(message);
        const phone = phoneFromJid(key.senderPn ?? item.senderPn ?? item.sender ?? key.remoteJid ?? item.from);
        if (!phone || !content) continue;
        const result = await client.rpc('registrar_evento_whatsapp', { datos: {
          phone, content, providerId: key.id ?? item.id,
          contextProviderId: message.extendedTextMessage?.contextInfo?.stanzaId ?? null,
        } });
        if (result.error) throw new Error(result.error.message);
      }
    }

    if (event === 'MESSAGES_UPDATE' || event === 'MESSAGE_UPDATE' || event === 'SEND_MESSAGE') {
      const items = Array.isArray(dataValue) ? dataValue : [data];
      for (const item of items) {
        const providerId = item.key?.id ?? item.id ?? item.messageId;
        const rawStatus = String(item.update?.status ?? item.status ?? '').toUpperCase();
        const normalized = statusMap[rawStatus];
        if (!providerId || !normalized) continue;
        const current = await client.from('mensajes_whatsapp').select('id,estado,tipo,cita_id,atencion_id')
          .eq('proveedor_id', providerId).maybeSingle();
        if (current.error) throw new Error(current.error.message);
        if (!current.data) continue;
        if (normalized !== 'FALLIDO' && (rank[normalized] ?? 0) < (rank[current.data.estado] ?? 0)) continue;
        if (normalized === 'FALLIDO' && ['ENTREGADO', 'LEIDO'].includes(current.data.estado)) continue;
        const updated = await client.from('mensajes_whatsapp').update({ estado: normalized,
          error_detalle: normalized === 'FALLIDO' ? String(item.error ?? 'Evolution API reportó un error').slice(0, 500) : null })
          .eq('id', current.data.id).eq('estado', current.data.estado);
        if (updated.error) throw new Error(updated.error.message);
      }
    }
    return json({ received: true });
  } catch (error) {
    console.error('Error procesando webhook de WhatsApp', error);
    return errorResponse(error);
  }
}
