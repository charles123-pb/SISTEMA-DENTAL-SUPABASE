import { createClient } from 'npm:@supabase/supabase-js@2';
import { corsHeaders, errorResponse, HttpError, json, readJsonObject } from '../_shared/http.ts';
import { serviceClient } from '../_shared/client.ts';

const invalidCredentials = () => json({ message: 'Usuario o contraseña incorrectos.' }, 401);
const temporaryBlock = () => json({
  message: 'Demasiados intentos fallidos. Espera 15 minutos y vuelve a intentarlo.',
}, 429);

const requestMetadata = (request: Request) => ({
  ip: request.headers.get('cf-connecting-ip')
    ?? request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
    ?? null,
  userAgent: request.headers.get('user-agent'),
});

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ message: 'Método no permitido.' }, 405);

  try {
    const body = await readJsonObject(request);
    const identifier = typeof body.identifier === 'string' ? body.identifier.trim().toLowerCase() : '';
    const password = typeof body.password === 'string' ? body.password : '';
    if (!identifier || identifier.length > 150 || !password || password.length > 100) {
      return invalidCredentials();
    }
    if (!identifier.includes('@') && !/^[a-z0-9._-]{3,60}$/.test(identifier)) {
      return invalidCredentials();
    }

    const admin = serviceClient();
    const profileQuery = admin.from('usuarios')
      .select('id,auth_user_id,activo,bloqueado,bloqueado_hasta,intentos_fallidos');
    const profile = identifier.includes('@')
      ? await profileQuery.eq('email', identifier).maybeSingle()
      : await profileQuery.eq('username', identifier).maybeSingle();
    if (profile.error) throw new Error(profile.error.message);
    if (!profile.data?.auth_user_id) return invalidCredentials();
    if (!profile.data.activo || profile.data.bloqueado) {
      return json({ message: 'La cuenta está deshabilitada. Comunícate con el administrador.' }, 403);
    }
    if (profile.data.bloqueado_hasta
      && Date.parse(profile.data.bloqueado_hasta) > Date.now()) return temporaryBlock();

    const identity = await admin.auth.admin.getUserById(profile.data.auth_user_id);
    if (identity.error || !identity.data.user?.email) return invalidCredentials();
    const email = identity.data.user.email;
    const metadata = requestMetadata(request);

    const authClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    const signed = await authClient.auth.signInWithPassword({ email, password });
    if (signed.error || !signed.data.session) {
      const tracked = await admin.rpc('registrar_intento_login', {
        p_usuario_id: profile.data.id,
        p_exitoso: false,
        p_ip: metadata.ip,
        p_user_agent: metadata.userAgent,
      });
      if (tracked.error) console.error('No se pudo registrar el intento fallido', tracked.error.message);
      const lockUntil = (tracked.data as { lockedUntil?: string | null } | null)?.lockedUntil;
      if (lockUntil && Date.parse(lockUntil) > Date.now()) return temporaryBlock();
      if ((signed.error as { status?: number }).status === 429) return temporaryBlock();
      return invalidCredentials();
    }

    const tracked = await admin.rpc('registrar_intento_login', {
      p_usuario_id: profile.data.id,
      p_exitoso: true,
      p_ip: metadata.ip,
      p_user_agent: metadata.userAgent,
    });
    if (tracked.error) throw new Error(tracked.error.message);

    return json({
      accessToken: signed.data.session.access_token,
      refreshToken: signed.data.session.refresh_token,
      expiresInSeconds: signed.data.session.expires_in,
    });
  } catch (error) {
    console.error('Error validando el acceso', error);
    return errorResponse(error instanceof HttpError
      ? error
      : new HttpError(500, 'No se pudo validar el acceso.'));
  }
});
