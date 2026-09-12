-- Permite agendar una solicitud web/WhatsApp creando el paciente si todavia no existe.
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
  paciente_id bigint := nullif($3 ->> 'patientId', '')::bigint;
  celular_value text;
  documento_value text;
  nombre_limpio text;
  partes_nombre text[];
  nombres_value text;
  apellido_value text;
  notas_value text;
  paciente_creado boolean := false;
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

  celular_value := nullif(regexp_replace(coalesce(solicitud.celular, ''), '\D', '', 'g'), '');
  documento_value := nullif(upper(btrim(coalesce(solicitud.numero_documento, ''))), '');

  if paciente_id is null then
    if documento_value is not null then
      select p.id into paciente_id
      from public.pacientes p
      where p.activo and p.numero_documento = documento_value
      limit 1;
    end if;

    if paciente_id is null and celular_value is not null then
      select p.id into paciente_id
      from public.pacientes p
      where p.activo and regexp_replace(coalesce(p.celular, ''), '\D', '', 'g') = celular_value
      order by p.creado_en desc
      limit 1;
    end if;
  end if;

  if paciente_id is null then
    if not public.has_permission('PACIENTE_ESCRIBIR') then
      raise exception using errcode = '42501', message = 'No autorizado para registrar el paciente de la solicitud';
    end if;

    nombre_limpio := regexp_replace(btrim(coalesce(solicitud.nombre_completo, 'Paciente')), '\s+', ' ', 'g');
    partes_nombre := regexp_split_to_array(nombre_limpio, '\s+');

    if array_length(partes_nombre, 1) > 1 then
      nombres_value := array_to_string(partes_nombre[1:array_length(partes_nombre, 1) - 1], ' ');
      apellido_value := partes_nombre[array_length(partes_nombre, 1)];
    else
      nombres_value := nombre_limpio;
      apellido_value := 'No registrado';
    end if;

    insert into public.pacientes(
      numero_historia, tipo_documento, numero_documento, nombres, apellido_paterno,
      fecha_nacimiento, sexo, celular, email, whatsapp_autorizado, whatsapp_autorizado_en,
      whatsapp_autorizado_por, creado_por, actualizado_por
    ) values (
      'HC-' || lpad(nextval('public.patient_history_number_seq')::text, 6, '0'),
      case
        when documento_value is null then 'SIN_DOCUMENTO'
        when documento_value ~ '^\d{8}$' then 'DNI'
        else 'CE'
      end,
      documento_value,
      nombres_value,
      apellido_value,
      (current_date - interval '30 years')::date,
      'NO_ESPECIFICA',
      celular_value,
      nullif(lower(btrim(coalesce(solicitud.email, ''))), ''),
      celular_value is not null,
      case when celular_value is not null then now() end,
      case when celular_value is not null then actor_id end,
      actor_id,
      actor_id
    ) returning id into paciente_id;
    paciente_creado := true;

    perform public.registrar_auditoria(
      'CREAR_PACIENTE_DESDE_SOLICITUD',
      'PACIENTE',
      paciente_id::text,
      'Solicitud ' || solicitud.id::text
    );
  end if;

  notas_value := concat_ws(E'\n',
    nullif(btrim($3 ->> 'notes'), ''),
    case when paciente_creado
      then 'Paciente creado automaticamente desde solicitud web/WhatsApp; completar DNI, fecha de nacimiento, sexo y datos clinicos.'
    end
  );

  nueva_cita_id := public.crear_cita(
    coalesce($3, '{}'::jsonb)
    || jsonb_build_object('patientId', paciente_id, 'source', 'WEB', 'notes', nullif(btrim(notas_value), ''))
  );

  update public.solicitudes_cita_web s
  set estado = 'AGENDADO',
      observacion_interna = 'Solicitud vinculada automaticamente al crear la cita',
      cita_id = nueva_cita_id,
      atendido_por = actor_id,
      actualizado_en = now(),
      version = s.version + 1
  where s.id = $1;

  perform public.registrar_auditoria(
    'AGENDAR_SOLICITUD_WEB',
    'SOLICITUD_CITA',
    $1::text,
    'Cita ' || nueva_cita_id::text || ' paciente ' || paciente_id::text
  );

  return nueva_cita_id;
end;
$$;

revoke all on function public.crear_cita_desde_solicitud(bigint, bigint, jsonb) from public;
grant execute on function public.crear_cita_desde_solicitud(bigint, bigint, jsonb) to authenticated;
