import { handleWebhook } from './handler.ts';
import { serviceClient } from '../_shared/client.ts';

const secret = 'test-webhook-secret-never-for-production';
const clientFactory = (client: unknown) => () => client as ReturnType<typeof serviceClient>;
function check(ok: boolean, message: string) { if (!ok) throw new Error(message); }
function request(event: string, data: unknown) {
  return new Request('https://example.invalid/webhook', { method: 'POST',
    headers: { 'x-webhook-secret': secret, 'content-type': 'application/json' },
    body: JSON.stringify({ event, data }),
  });
}
async function withSecret(run: () => Promise<void>) {
  const previous = Deno.env.get('EVOLUTION_WEBHOOK_SECRET');
  Deno.env.set('EVOLUTION_WEBHOOK_SECRET', secret);
  try { await run(); } finally {
    if (previous === undefined) Deno.env.delete('EVOLUTION_WEBHOOK_SECRET');
    else Deno.env.set('EVOLUTION_WEBHOOK_SECRET', previous);
  }
}

Deno.test('un fallo al guardar el mensaje devuelve 500 para permitir redelivery', () => withSecret(async () => {
  const response = await handleWebhook(request('messages.upsert', {
    key: { remoteJid: '51999111222@s.whatsapp.net', id: 'test-incoming' },
    message: { conversation: 'CONFIRMO' },
  }), clientFactory({ rpc: () => Promise.resolve({ error: { message: 'Database unavailable' } }) }));
  check(response.status === 500, 'No debe confirmar un mensaje que no se guardó');
}));

Deno.test('mensaje persistido devuelve 200 y conserva el contexto citado', () => withSecret(async () => {
  let received: unknown;
  const response = await handleWebhook(request('messages.upsert', {
    key: { remoteJid: '51999111222@s.whatsapp.net', id: 'test-incoming' },
    message: { extendedTextMessage: { text: 'CONFIRMO', contextInfo: { stanzaId: 'test-outgoing' } } },
  }), clientFactory({ rpc: (_name: string, args: unknown) => { received = args; return Promise.resolve({ error: null }); } }));
  check(response.status === 200, 'Debe aceptar el mensaje guardado');
  check(JSON.stringify(received).includes('test-outgoing'), 'Debe conservar la cita respondida');
}));

Deno.test('estados numéricos distinguen enviado, entregado y leído sin retroceder', () => withSecret(async () => {
  for (const [current, incoming, expected] of [
    ['ENVIADO', 3, 'ENTREGADO'], ['ENTREGADO', 4, 'LEIDO'],
    ['LEIDO', 2, null], ['LEIDO', 0, null],
  ] as const) {
    let saved: string | null = null;
    const query = {
      select: () => query, eq: () => query,
      maybeSingle: () => Promise.resolve({ data: { id: 1, estado: current }, error: null }),
      update: (value: { estado: string }) => { saved = value.estado; return query; },
      then: (resolve: (value: unknown) => unknown) => Promise.resolve({ error: null }).then(resolve),
    };
    const response = await handleWebhook(request('messages.update', { key: { id: 'test' }, status: incoming }),
      clientFactory({ from: () => query }));
    check(response.status === 200 && saved === expected, `Estado ${current} + ${incoming}`);
  }
}));

Deno.test('sin secreto válido no consulta la base de datos', async () => {
  let queried = false;
  const response = await handleWebhook(new Request('https://example.invalid', { method: 'POST' }),
    () => { queried = true; throw new Error('No debe ejecutarse'); });
  check(response.status === 401 && !queried, 'Rechazar webhook no autorizado');
});
