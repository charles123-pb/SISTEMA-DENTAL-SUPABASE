import { EvolutionRequestError, normalizeWhatsAppNumber, retryDelay, sendWhatsApp } from './whatsapp.ts';

function equal(actual: unknown, expected: unknown) {
  if (actual !== expected) throw new Error(`Expected ${expected}, got ${actual}`);
}

Deno.test('429 reintenta con espera y respeta el máximo de intentos', () => {
  const error = new EvolutionRequestError('Ocupado', 429);
  equal(retryDelay(error, 1, 4), 60_000);
  equal(retryDelay(error, 2, 4), 300_000);
  equal(retryDelay(error, 3, 4), 900_000);
  equal(retryDelay(error, 4, 4), null);
});

Deno.test('fallos ambiguos o permanentes requieren revisión, sin reenvío automático', () => {
  for (const error of [new Error('Timeout'), new EvolutionRequestError('Error', 500),
    new EvolutionRequestError('No autorizado', 401), new EvolutionRequestError('Inválido', 400)]) {
    equal(retryDelay(error, 1, 4), null);
  }
});

Deno.test('normaliza celulares peruanos e internacionales', () => {
  equal(normalizeWhatsAppNumber('999 111 222'), '51999111222');
  equal(normalizeWhatsAppNumber('+51 999 111 222'), '51999111222');
  equal(normalizeWhatsAppNumber('0051999111222'), '51999111222');
});

Deno.test('el proveedor debe devolver un identificador antes de registrar ENVIADO', async () => {
  const originalFetch = globalThis.fetch;
  const keys = ['EVOLUTION_API_URL', 'EVOLUTION_API_KEY', 'EVOLUTION_INSTANCE_NAME', 'CF_ACCESS_CLIENT_ID', 'CF_ACCESS_CLIENT_SECRET'];
  const previous = keys.map((key) => Deno.env.get(key));
  try {
    Deno.env.set(keys[0], 'https://example.invalid');
    Deno.env.set(keys[1], 'test-only');
    Deno.env.set(keys[2], 'test');
    Deno.env.delete(keys[3]); Deno.env.delete(keys[4]);
    globalThis.fetch = () => Promise.resolve(new Response('{}', { status: 200 }));
    let rejected = false;
    try { await sendWhatsApp('999111222', 'Prueba'); } catch { rejected = true; }
    equal(rejected, true);
    globalThis.fetch = () => Promise.resolve(Response.json({ key: { id: 'test-message' } }));
    equal(await sendWhatsApp('999111222', 'Prueba'), 'test-message');
  } finally {
    globalThis.fetch = originalFetch;
    keys.forEach((key, i) => previous[i] === undefined ? Deno.env.delete(key) : Deno.env.set(key, previous[i]!));
  }
});
