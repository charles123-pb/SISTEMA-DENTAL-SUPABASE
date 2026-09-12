export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-cron-secret, x-hub-signature-256',
};

export class HttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
    this.name = 'HttpError';
  }
}

export const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: {
    ...corsHeaders,
    'Content-Type': 'application/json',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  },
});
export const errorMessage = (error: unknown) => error instanceof Error ? error.message : String(error);

export const errorResponse = (error: unknown, fallbackStatus = 500) => {
  const status = error instanceof HttpError ? error.status : fallbackStatus;
  return json({ message: errorMessage(error) }, status);
};

export const requireMethod = (request: Request, method: 'GET' | 'POST') => {
  if (request.method !== method) throw new HttpError(405, 'Método no permitido');
};

export const readJsonObject = async (request: Request): Promise<Record<string, unknown>> => {
  try {
    const value: unknown = await request.json();
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      throw new Error('body inválido');
    }
    return value as Record<string, unknown>;
  } catch {
    throw new HttpError(400, 'El cuerpo de la solicitud no contiene JSON válido');
  }
};
