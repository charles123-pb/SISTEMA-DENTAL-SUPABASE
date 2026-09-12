import { createClient } from 'npm:@supabase/supabase-js@2';

export const userClient = (authorization: string) => createClient(
  Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!,
  { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } },
);
export const serviceClient = () => {
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    serviceRoleKey,
    {
      // El apiKey identifica el proyecto, pero PostgREST necesita además el JWT
      // de servicio para que las RPC protegidas reconozcan el rol service_role.
      global: { headers: { Authorization: `Bearer ${serviceRoleKey}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
};
