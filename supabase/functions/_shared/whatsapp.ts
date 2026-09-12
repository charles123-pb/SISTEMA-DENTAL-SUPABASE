export type EvolutionConnectionStatus = 'CONECTADO' | 'DESCONECTADO' | 'CONECTANDO' | 'ERROR';
export type JsonRecord = Record<string, unknown>;

const asRecord = (value: unknown): JsonRecord =>
  value && typeof value === 'object' && !Array.isArray(value) ? value as JsonRecord : {};

const records = (value: unknown): JsonRecord[] =>
  Array.isArray(value) ? value.filter((item): item is JsonRecord =>
    Boolean(item) && typeof item === 'object' && !Array.isArray(item)) : [];

const configuration = () => {
  const baseUrl = Deno.env.get('EVOLUTION_API_URL')?.trim().replace(/\/$/, '');
  const apiKey = Deno.env.get('EVOLUTION_API_KEY')?.trim();
  const instance = Deno.env.get('EVOLUTION_INSTANCE_NAME')?.trim();
  if (!baseUrl || !apiKey || !instance) throw new Error('Evolution API todavía no está configurada');
  return { baseUrl, apiKey, instance };
};

const evolutionRequest = async (path: string, init: RequestInit = {}) => {
  const { baseUrl, apiKey } = configuration();
  const response = await fetch(`${baseUrl}${path}`, {
    ...init,
    signal: init.signal ?? AbortSignal.timeout(20_000),
    headers: { apikey: apiKey, 'Content-Type': 'application/json', ...init.headers },
  });
  const payload: unknown = await response.json().catch(() => ({}));
  if (!response.ok) {
    const errorPayload = asRecord(payload);
    const providerResponse = asRecord(errorPayload.response);
    const responseMessages = Array.isArray(providerResponse.message) ? providerResponse.message : [];
    const message = responseMessages[0] ?? errorPayload.message ?? errorPayload.error;
    const detail = typeof message === 'string'
      ? message
      : message && typeof message === 'object'
        ? JSON.stringify(message).slice(0, 500)
        : '';
    throw new Error(detail || `Evolution API respondió ${response.status}`);
  }
  return payload;
};

export function normalizeWhatsAppNumber(phone: string): string {
  let digits = String(phone ?? '').replace(/\D/g, '');
  if (digits.startsWith('00')) digits = digits.slice(2);
  // Los celulares peruanos se registran habitualmente con 9 dígitos.
  // Evolution/WhatsApp requiere el código de país: 51 + celular.
  if (/^9\d{8}$/.test(digits)) digits = `51${digits}`;
  return digits;
}

export async function sendWhatsApp(phone: string, content: string): Promise<string> {
  const { instance } = configuration();
  const number = normalizeWhatsAppNumber(phone);
  if (number.length < 10) throw new Error('El celular no incluye un código de país válido');
  const payload = await evolutionRequest(`/message/sendText/${encodeURIComponent(instance)}`, {
    method: 'POST', body: JSON.stringify({ number, text: content, delay: 500, linkPreview: false }),
  });
  const result = asRecord(payload);
  const providerId = asRecord(result.key).id
    ?? asRecord(asRecord(result.message).key).id
    ?? result.id;
  if (!providerId) throw new Error('Evolution API no devolvió el identificador del mensaje');
  return String(providerId);
}

export async function connectionState(): Promise<{ status: EvolutionConnectionStatus; phone?: string; detail?: string }> {
  const { instance } = configuration();
  try {
    const payload = await evolutionRequest(`/instance/connectionState/${encodeURIComponent(instance)}`);
    const result = asRecord(payload);
    const providerInstance = asRecord(result.instance);
    const raw = String(providerInstance.state ?? result.state ?? '').toLowerCase();
    const status: EvolutionConnectionStatus = raw === 'open' || raw === 'connected'
      ? 'CONECTADO' : raw === 'connecting' ? 'CONECTANDO' : 'DESCONECTADO';
    const phone = providerInstance.owner ?? providerInstance.number;
    return { status, phone: phone == null ? undefined : String(phone), detail: raw || undefined };
  } catch (error) {
    return { status: 'ERROR', detail: error instanceof Error ? error.message : String(error) };
  }
}

export async function connectInstance() {
  const { instance } = configuration();
  return evolutionRequest(`/instance/connect/${encodeURIComponent(instance)}`);
}

export async function findChats(): Promise<JsonRecord[]> {
  const { instance } = configuration();
  const payload = await evolutionRequest(`/chat/findChats/${encodeURIComponent(instance)}`, {
    method: 'POST', body: '{}',
  });
  return records(payload);
}

export async function findMessages(limit = 500): Promise<JsonRecord[]> {
  const { instance } = configuration();
  const payload = await evolutionRequest(`/chat/findMessages/${encodeURIComponent(instance)}`, {
    method: 'POST', body: JSON.stringify({ page: 1, offset: limit }),
  });
  const messages = asRecord(payload).messages;
  if (Array.isArray(messages)) return records(messages);
  return records(asRecord(messages).records);
}

export async function createInstance() {
  const { instance } = configuration();
  const webhookSecret = Deno.env.get('EVOLUTION_WEBHOOK_SECRET');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  if (!webhookSecret || !supabaseUrl) throw new Error('Falta configurar el secreto del webhook');
  return evolutionRequest('/instance/create', {
    method: 'POST',
    body: JSON.stringify({
      instanceName: instance, qrcode: true, integration: 'WHATSAPP-BAILEYS',
      webhook: { enabled: true,
        url: `${supabaseUrl}/functions/v1/whatsapp-webhook?token=${encodeURIComponent(webhookSecret)}`,
        byEvents: false, base64: false,
        events: ['QRCODE_UPDATED', 'MESSAGES_UPSERT', 'MESSAGES_UPDATE', 'CONNECTION_UPDATE'] },
    }),
  });
}

export function qrFromPayload(payload: unknown) {
  const result = asRecord(payload);
  const qr = asRecord(result.qrcode ?? result);
  const base64 = String(qr?.base64 ?? '');
  return {
    qrCode: base64 ? (base64.startsWith('data:image') ? base64 : `data:image/png;base64,${base64}`) : null,
    pairingCode: qr?.pairingCode ? String(qr.pairingCode) : null,
    code: qr?.code ? String(qr.code) : null,
  };
}
