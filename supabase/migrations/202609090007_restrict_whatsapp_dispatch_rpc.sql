-- Supabase concede permisos de ejecución a funciones nuevas de public por defecto.
-- Esta RPC prepara la cola de envíos y nunca debe ser invocable desde el navegador.
revoke all on function public.preparar_recordatorios_whatsapp() from public, anon, authenticated;
grant execute on function public.preparar_recordatorios_whatsapp() to service_role;
