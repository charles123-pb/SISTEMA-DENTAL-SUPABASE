-- Las default privileges de Supabase conceden EXECUTE directamente a anon.
-- Revocarlo explícitamente; la comprobación SEGUIMIENTO_LEER dentro de cada función se mantiene.
revoke all on function public.listar_conversaciones_whatsapp_paginadas(text, timestamptz, bigint, integer),
  public.listar_mensajes_conversacion_paginados(bigint, timestamptz, bigint, integer) from anon;
