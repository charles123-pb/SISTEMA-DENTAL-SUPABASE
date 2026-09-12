import { userClient } from './client.ts';
import { HttpError } from './http.ts';

const bearerToken = (authorization: string | null) => {
  const match = authorization?.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
};

const safeEqual = (left: string, right: string) => {
  const encoder = new TextEncoder();
  const a = encoder.encode(left);
  const b = encoder.encode(right);
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let index = 0; index < a.length; index++) difference |= a[index] ^ b[index];
  return difference === 0;
};

export async function requirePermission(request: Request, permission: string) {
  const authorization = request.headers.get('Authorization');
  const token = bearerToken(authorization);
  if (!authorization || !token) throw new HttpError(401, 'Sesión requerida');

  const client = userClient(authorization);
  const identity = await client.auth.getUser(token);
  if (identity.error || !identity.data.user) {
    throw new HttpError(401, 'La sesión venció. Cierra sesión e ingresa nuevamente.');
  }

  const context = await client.rpc('current_user_context');
  if (context.error || !context.data) {
    throw new HttpError(403, 'Tu cuenta no está vinculada a un usuario activo del sistema.');
  }

  const rawPermissions = (context.data as { permissions?: unknown }).permissions;
  const permissions = Array.isArray(rawPermissions)
    ? rawPermissions.filter((value): value is string => typeof value === 'string')
    : [];
  if (!permissions.includes(permission)) {
    throw new HttpError(403, 'Tu usuario no tiene permiso para realizar esta operación.');
  }
  return client;
}

export function requireSecret(request: Request, environmentName: string, headerName: string) {
  const expected = Deno.env.get(environmentName)?.trim() ?? '';
  if (expected.length < 24) {
    throw new HttpError(503, `Falta configurar ${environmentName}`);
  }
  const provided = request.headers.get(headerName)?.trim() ?? '';
  if (!safeEqual(provided, expected)) throw new HttpError(401, 'No autorizado');
}

export function matchesSecret(provided: string | null, environmentName: string) {
  const expected = Deno.env.get(environmentName)?.trim() ?? '';
  return expected.length >= 24 && safeEqual(provided?.trim() ?? '', expected);
}
