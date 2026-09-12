-- Crea y vincula una cita desde una solicitud web/WhatsApp en una sola transacción.
create or replace function public.crear_cita_desde_solicitud(
  solicitud_id bigint,
  version_actual bigint,
  datos jsonb
) returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id bigint := public.current_app_user_id();
  solicitud public.solicitudes_cita_web;
  nueva_cita_id bigint;
begin
  if actor_id is null or not public.has_permission('CITA_ESCRIBIR') then
    raise exception using errcode = '42501', message = 'No autorizado para crear citas';
  end if;

  select * into solicitud
  from public.solicitudes_cita_web s
  where s.id = $1
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'Solicitud no encontrada';
  end if;
  if solicitud.version <> $2 then
    raise exception using errcode = 'P0001', message = 'La solicitud fue actualizada por otro usuario';
  end if;
  if solicitud.estado in ('AGENDADO', 'DESCARTADO') or solicitud.cita_id is not null then
    raise exception using errcode = 'P0001', message = 'La solicitud ya fue finalizada';
  end if;

  nueva_cita_id := public.crear_cita(
    coalesce($3, '{}'::jsonb) || jsonb_build_object('source', 'WEB')
  );

  update public.solicitudes_cita_web s
  set estado = 'AGENDADO',
      observacion_interna = 'Solicitud vinculada automáticamente al crear la cita',
      cita_id = nueva_cita_id,
      atendido_por = actor_id,
      actualizado_en = now(),
      version = s.version + 1
  where s.id = $1;

  perform public.registrar_auditoria(
    'AGENDAR_SOLICITUD_WEB',
    'SOLICITUD_CITA',
    $1::text,
    'Cita ' || nueva_cita_id::text
  );

  return nueva_cita_id;
end;
$$;

revoke all on function public.crear_cita_desde_solicitud(bigint, bigint, jsonb) from public;
grant execute on function public.crear_cita_desde_solicitud(bigint, bigint, jsonb) to authenticated;
