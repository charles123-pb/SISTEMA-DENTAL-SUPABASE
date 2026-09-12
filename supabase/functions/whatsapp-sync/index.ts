import { matchesSecret, requirePermission } from '../_shared/auth.ts';
import { serviceClient } from '../_shared/client.ts';
import { corsHeaders, errorResponse, json, readJsonObject } from '../_shared/http.ts';
import { connectionState, findChats, findMessages } from '../_shared/whatsapp.ts';

const directJid = (value: unknown) => {
  const jid = String(value ?? '').trim();
  return jid.endsWith('@s.whatsapp.net') || jid.endsWith('@lid') ? jid : '';
};
const digits = (value: unknown) => String(value ?? '').split('@')[0].replace(/\D/g, '');
const timestamp = (value: unknown) => {
  const raw = typeof value === 'object' && value ? (value as { low?: unknown }).low : value;
  const seconds = Number(raw);
  return Number.isFinite(seconds) && seconds > 0
    ? new Date(seconds * 1000).toISOString()
    : new Date().toISOString();
};
const text = (message: Record<string, any> = {}, type = '') =>
  String(message.conversation ?? message.extendedTextMessage?.text
    ?? message.imageMessage?.caption ?? message.videoMessage?.caption
    ?? message.documentMessage?.caption ?? message.buttonsResponseMessage?.selectedDisplayText
    ?? message.listResponseMessage?.title
    ?? (type === 'imageMessage' ? '[Imagen]' : type === 'videoMessage' ? '[Video]'
      : type === 'audioMessage' ? '[Audio]' : type === 'documentMessage' ? '[Documento]'
      : type === 'stickerMessage' ? '[Sticker]' : '')).trim();
const messageStatus = (value: unknown) => {
  const raw = String(value ?? '').toUpperCase();
  if (raw === 'READ' || raw === 'READ_ACK' || raw === 'PLAYED') return 'LEIDO';
  if (raw === 'DELIVERED' || raw === 'DELIVERY_ACK') return 'ENTREGADO';
  if (raw === 'FAILED' || raw === 'ERROR') return 'FALLIDO';
  return 'ENVIADO';
};

async function authorized(request: Request) {
  if (matchesSecret(request.headers.get('x-cron-secret'), 'WHATSAPP_CRON_SECRET')) return;
  await requirePermission(request, 'SEGUIMIENTO_ESCRIBIR');
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ message: 'Método no permitido' }, 405);
  try {
    await authorized(request);
    const body = await readJsonObject(request);
    if (body.healthOnly === true) return json(await connectionState());
    const [chats, messages] = await Promise.all([findChats(), findMessages(500)]);
    const admin = serviceClient();
    const validChats = chats.filter((chat) => directJid(chat.remoteJid));

    const importChat = async (chat: Record<string, any>) => {
      const last = chat.lastMessage ?? {};
      const jid = directJid(chat.remoteJid);
      const result = await admin.rpc('importar_chat_whatsapp', { datos: {
        providerChatId: jid,
        phone: digits(jid),
        contactName: chat.pushName || (!last.key?.fromMe ? last.pushName : null),
        lastMessage: text(last.message, last.messageType),
        lastMessageDirection: last.key?.fromMe ? 'SALIENTE' : 'ENTRANTE',
        lastMessageAt: timestamp(last.messageTimestamp ?? new Date(chat.updatedAt).getTime() / 1000),
        unreadCount: Number(chat.unreadCount ?? 0),
      } });
      if (result.error) throw new Error(result.error.message);
    };

    for (const chat of validChats) await importChat(chat);

    let importedMessages = 0;
    const orderedMessages = messages
      .filter((message) => directJid(message.key?.remoteJid) && text(message.message, message.messageType))
      .sort((a, b) => Number(a.messageTimestamp ?? 0) - Number(b.messageTimestamp ?? 0));
    for (const message of orderedMessages) {
      const latestUpdate = Array.isArray(message.MessageUpdate) ? message.MessageUpdate.at(-1) : null;
      const result = await admin.rpc('importar_mensaje_whatsapp', { datos: {
        providerChatId: directJid(message.key?.remoteJid),
        providerId: message.key?.id,
        direction: message.key?.fromMe ? 'SALIENTE' : 'ENTRANTE',
        content: text(message.message, message.messageType),
        status: messageStatus(latestUpdate?.status ?? message.status),
        createdAt: timestamp(message.messageTimestamp),
      } });
      if (result.error) throw new Error(result.error.message);
      if (result.data) importedMessages++;
    }

    // Evolution conserva el contador de no leídos y el último mensaje autoritativos.
    for (const chat of validChats) await importChat(chat);
    return json({ chats: validChats.length, messages: importedMessages });
  } catch (error) {
    return errorResponse(error, 502);
  }
});
