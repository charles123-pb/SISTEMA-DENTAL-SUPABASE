create or replace function public.cita_json(item public.citas) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', item.id,
    'patientId', p.id,
    'patientHistoryNumber', p.numero_historia,
    'patientName', concat_ws(' ', p.nombres, p.apellido_paterno, p.apellido_materno),
    'patientMobile', p.celular,
    'professionalId', u.id,
    'professionalName', u.nombre_completo,
    'appointmentTypeId', t.id,
    'appointmentTypeName', t.nombre,
    'appointmentTypeColor', t.color,
    'durationMinutes', t.duracion_minutos,
    'start', item.inicio,
    'end', item.fin,
    'status', item.estado,
    'reason', item.motivo,
    'notes', item.notas,
    'source', item.origen,
    'cancellationReason', item.motivo_cancelacion,
    'confirmationSent', item.confirmacion_enviada,
    'reminderScheduled', item.recordatorio_programado,
    'reminderSent', item.recordatorio_enviado,
    'createdAt', item.creado_en,
    'updatedAt', item.actualizado_en,
    'version', item.version
  )
  from public.pacientes p
  join public.usuarios u on u.id = item.profesional_id
  join public.tipos_cita t on t.id = item.tipo_cita_id
  where p.id = item.paciente_id
$$;

create or replace function public.listar_citas(
  desde timestamptz, hasta timestamptz, profesional_id bigint default null, estado_filtro text default null
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if not public.has_permission('CITA_LEER') then
    raise exception using errcode = '42501', message = 'No autorizado para consultar citas';
  end if;
  if desde is null or hasta is null or hasta <= desde then
    raise exception using errcode = 'P0001', message = 'Rango de agenda inválido';
  end if;
  if hasta - desde > interval '62 days' then
    raise exception using errcode = 'P0001', message = 'El rango consultado es demasiado amplio';
  end if;
  select coalesce(jsonb_agg(public.cita_json(c) order by c.inicio), '[]'::jsonb) into result
  from public.citas c
  where c.inicio < hasta and c.fin > desde
    and (listar_citas.profesional_id is null or c.profesional_id = listar_citas.profesional_id)
    and (listar_citas.estado_filtro is null or c.estado = listar_citas.estado_filtro);
  return result;
end;
$$;

create or replace function public.obtener_cita(cita_id bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if not public.has_permission('CITA_LEER') then
    raise exception using errcode = '42501', message = 'No autorizado para consultar citas';
  end if;
  select public.cita_json(c) into result from public.citas c where c.id = cita_id;
  if result is null then raise exception using errcode = 'P0001', message = 'Cita no encontrada'; end if;
  return result;
end;
$$;

create or replace function public.validar_profesional_cita(profesional_id bigint) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.usuarios u
    join public.usuarios_roles ur on ur.usuario_id = u.id
    join public.roles r on r.id = ur.rol_id
    where u.id = profesional_id and u.activo and not u.bloqueado and r.codigo = 'ODONTOLOGO' and r.activo
  ) then
    raise exception using errcode = 'P0001', message = 'El usuario seleccionado no es un odontólogo activo';
  end if;
end;
$$;

create or replace function public.validar_disponibilidad_cita(
  paciente_id bigint, profesional_id bigint, inicio_value timestamptz, fin_value timestamptz,
  cita_excluida bigint default null
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  inicio_local timestamp := inicio_value at time zone 'America/Lima';
  fin_local timestamp := fin_value at time zone 'America/Lima';
  dia smallint := extract(isodow from inicio_local)::smallint;
  tiene_horario boolean;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('cita-profesional:' || profesional_id::text, 0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('cita-paciente:' || paciente_id::text, 0));
  if inicio_value <= now() then raise exception using errcode = 'P0001', message = 'La cita debe programarse en una fecha futura'; end if;
  if inicio_local::date <> fin_local::date then raise exception using errcode = 'P0001', message = 'La cita debe iniciar y terminar el mismo día'; end if;

  select exists(select 1 from public.horarios_profesionales h
    where h.profesional_id = validar_disponibilidad_cita.profesional_id and h.dia_semana = dia and h.activo)
  into tiene_horario;
  if tiene_horario then
    if not exists(select 1 from public.horarios_profesionales h
      where h.profesional_id = validar_disponibilidad_cita.profesional_id and h.dia_semana = dia and h.activo
        and inicio_local::time >= h.hora_inicio and fin_local::time <= h.hora_fin) then
      raise exception using errcode = 'P0001', message = 'El horario está fuera de la jornada del profesional';
    end if;
  elsif dia = 7 or inicio_local::time < time '08:00' or fin_local::time > time '20:00' then
    raise exception using errcode = 'P0001', message = 'El horario está fuera de la jornada del profesional';
  end if;

  if exists(select 1 from public.bloqueos_agenda b
    where b.profesional_id = validar_disponibilidad_cita.profesional_id and b.activo
      and b.inicio < fin_value and b.fin > inicio_value) then
    raise exception using errcode = 'P0001', message = 'El profesional tiene el horario bloqueado';
  end if;
  if exists(select 1 from public.citas c
    where c.profesional_id = validar_disponibilidad_cita.profesional_id
      and c.id <> coalesce(cita_excluida, 0) and c.estado not in ('CANCELADA','NO_ASISTIO')
      and c.inicio < fin_value and c.fin > inicio_value) then
    raise exception using errcode = 'P0001', message = 'El profesional ya tiene una cita en ese horario';
  end if;
  if exists(select 1 from public.citas c
    where c.paciente_id = validar_disponibilidad_cita.paciente_id
      and c.id <> coalesce(cita_excluida, 0) and c.estado not in ('CANCELADA','NO_ASISTIO')
      and c.inicio < fin_value and c.fin > inicio_value) then
    raise exception using errcode = 'P0001', message = 'El paciente ya tiene una cita en ese horario';
  end if;
end;
$$;

create or replace function public.disponibilidad_cita(
  profesional_id bigint, fecha date, tipo_cita_id bigint
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare result jsonb; duracion integer;
begin
  if not public.has_permission('CITA_LEER') then
    raise exception using errcode = '42501', message = 'No autorizado para consultar disponibilidad';
  end if;
  perform public.validar_profesional_cita(profesional_id);
  select duracion_minutos into duracion from public.tipos_cita where id = tipo_cita_id and activo;
  if duracion is null then raise exception using errcode = 'P0001', message = 'Tipo de cita no encontrado'; end if;

  with ventanas as (
    select h.hora_inicio, h.hora_fin, h.intervalo_minutos
    from public.horarios_profesionales h
    where h.profesional_id = disponibilidad_cita.profesional_id
      and h.dia_semana = extract(isodow from fecha)::smallint and h.activo
    union all
    select time '08:00', time '20:00', 15
    where extract(isodow from fecha) <> 7 and not exists (
      select 1 from public.horarios_profesionales h
      where h.profesional_id = disponibilidad_cita.profesional_id
        and h.dia_semana = extract(isodow from fecha)::smallint and h.activo
    )
  ), slots as (
    select slot_start,
      slot_start + make_interval(mins => duracion) as slot_end
    from ventanas v
    cross join lateral generate_series(
      (fecha + v.hora_inicio) at time zone 'America/Lima',
      (fecha + v.hora_fin) at time zone 'America/Lima' - make_interval(mins => duracion),
      make_interval(mins => v.intervalo_minutos)
    ) slot_start
  ), evaluated as (
    select s.*,
      case
        when s.slot_start <= now() then 'Horario pasado'
        when exists(select 1 from public.bloqueos_agenda b where b.profesional_id = disponibilidad_cita.profesional_id
          and b.activo and b.inicio < s.slot_end and b.fin > s.slot_start) then 'Horario bloqueado'
        when exists(select 1 from public.citas c where c.profesional_id = disponibilidad_cita.profesional_id
          and c.estado not in ('CANCELADA','NO_ASISTIO') and c.inicio < s.slot_end and c.fin > s.slot_start) then 'Horario ocupado'
      end unavailable_reason
    from slots s
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'start', slot_start, 'end', slot_end, 'available', unavailable_reason is null,
    'unavailableReason', unavailable_reason) order by slot_start), '[]'::jsonb)
  into result from evaluated;
  return result;
end;
$$;

create or replace function public.crear_cita(datos jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  actor_id bigint := public.current_app_user_id();
  patient_id bigint := (datos ->> 'patientId')::bigint;
  professional_id bigint := (datos ->> 'professionalId')::bigint;
  type_id bigint := (datos ->> 'appointmentTypeId')::bigint;
  starts_at timestamptz := (datos ->> 'start')::timestamptz;
  duration_minutes integer;
  ends_at timestamptz;
  new_id bigint;
  source_value text := coalesce(nullif(datos ->> 'source', ''), 'RECEPCION');
begin
  if actor_id is null or not public.has_permission('CITA_ESCRIBIR') then
    raise exception using errcode = '42501', message = 'No autorizado para crear citas';
  end if;
  if not exists(select 1 from public.pacientes where id = patient_id and activo) then
    raise exception using errcode = 'P0001', message = 'No se puede citar a un paciente inactivo o inexistente';
  end if;
  if nullif(btrim(datos ->> 'reason'), '') is null then raise exception using errcode = 'P0001', message = 'El motivo es obligatorio'; end if;
  perform public.validar_profesional_cita(professional_id);
  select duracion_minutos into duration_minutes from public.tipos_cita where id = type_id and activo;
  if duration_minutes is null then raise exception using errcode = 'P0001', message = 'Tipo de cita no encontrado'; end if;
  ends_at := starts_at + make_interval(mins => duration_minutes);
  perform public.validar_disponibilidad_cita(patient_id, professional_id, starts_at, ends_at, null);
  insert into public.citas(paciente_id, profesional_id, tipo_cita_id, inicio, fin, motivo, notas, origen, creado_por, actualizado_por)
  values (patient_id, professional_id, type_id, starts_at, ends_at, btrim(datos ->> 'reason'),
    nullif(btrim(datos ->> 'notes'), ''), source_value, actor_id, actor_id)
  returning id into new_id;
  insert into public.cita_historial_estados(cita_id, estado_anterior, estado_nuevo, motivo, creado_por)
  values (new_id, null, 'PENDIENTE_CONFIRMACION', 'Cita creada', actor_id);
  perform public.registrar_auditoria('CREAR_CITA', 'CITA', new_id::text, 'Inicio ' || starts_at::text);
  return new_id;
end;
$$;

create or replace function public.actualizar_cita(cita_id bigint, datos jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  actor_id bigint := public.current_app_user_id();
  current_item public.citas;
  professional_id bigint := (datos ->> 'professionalId')::bigint;
  type_id bigint := (datos ->> 'appointmentTypeId')::bigint;
  starts_at timestamptz := (datos ->> 'start')::timestamptz;
  duration_minutes integer;
  ends_at timestamptz;
begin
  if actor_id is null or not public.has_permission('CITA_ESCRIBIR') then raise exception using errcode = '42501', message = 'No autorizado para actualizar citas'; end if;
  select * into current_item from public.citas where id = cita_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'Cita no encontrada'; end if;
  if current_item.estado in ('COMPLETADA','CANCELADA','NO_ASISTIO') then raise exception using errcode = 'P0001', message = 'No se puede reprogramar una cita finalizada'; end if;
  if current_item.version <> (datos ->> 'version')::bigint then raise exception using errcode = 'P0001', message = 'La cita fue modificada por otro usuario'; end if;
  if current_item.paciente_id <> (datos ->> 'patientId')::bigint then raise exception using errcode = 'P0001', message = 'No se puede cambiar el paciente de una cita'; end if;
  if nullif(btrim(datos ->> 'reason'), '') is null then raise exception using errcode = 'P0001', message = 'El motivo es obligatorio'; end if;
  perform public.validar_profesional_cita(professional_id);
  select duracion_minutos into duration_minutes from public.tipos_cita where id = type_id and activo;
  if duration_minutes is null then raise exception using errcode = 'P0001', message = 'Tipo de cita no encontrado'; end if;
  ends_at := starts_at + make_interval(mins => duration_minutes);
  perform public.validar_disponibilidad_cita(current_item.paciente_id, professional_id, starts_at, ends_at, cita_id);
  update public.citas set profesional_id = professional_id, tipo_cita_id = type_id, inicio = starts_at, fin = ends_at,
    motivo = btrim(datos ->> 'reason'), notas = nullif(btrim(datos ->> 'notes'), ''),
    estado = case when estado = 'CONFIRMADA' then 'PENDIENTE_CONFIRMACION' else estado end,
    confirmacion_enviada = false, recordatorio_programado = false, recordatorio_enviado = false,
    actualizado_por = actor_id, actualizado_en = now(), version = version + 1
  where id = cita_id;
  perform public.registrar_auditoria('REPROGRAMAR_CITA', 'CITA', cita_id::text, 'Nuevo inicio ' || starts_at::text);
  return cita_id;
end;
$$;

create or replace function public.cambiar_estado_cita(cita_id bigint, nuevo_estado text, version_actual bigint, motivo_value text default null) returns bigint
language plpgsql security definer set search_path = '' as $$
declare actor_id bigint := public.current_app_user_id(); item public.citas; allowed boolean := false;
begin
  if actor_id is null or not public.has_permission('CITA_ESCRIBIR') then raise exception using errcode = '42501', message = 'No autorizado para actualizar citas'; end if;
  select * into item from public.citas where id = cita_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'Cita no encontrada'; end if;
  if item.version <> version_actual then raise exception using errcode = 'P0001', message = 'La cita fue modificada por otro usuario'; end if;
  if item.estado = nuevo_estado then return cita_id; end if;
  if item.estado in ('COMPLETADA','CANCELADA','NO_ASISTIO') then raise exception using errcode = 'P0001', message = 'La cita ya se encuentra finalizada'; end if;
  if nuevo_estado = 'CANCELADA' then
    if nullif(btrim(motivo_value), '') is null then raise exception using errcode = 'P0001', message = 'Indique el motivo de cancelación'; end if;
    allowed := true;
  elsif nuevo_estado = 'COMPLETADA' then
    raise exception using errcode = 'P0001', message = 'Finalice y apruebe la historia clínica para completar la cita';
  elsif item.estado = 'PENDIENTE_CONFIRMACION' and nuevo_estado in ('CONFIRMADA','NO_ASISTIO') then allowed := true;
  elsif item.estado = 'CONFIRMADA' and nuevo_estado in ('EN_ESPERA','NO_ASISTIO') then allowed := true;
  elsif item.estado = 'EN_ESPERA' and nuevo_estado in ('EN_ATENCION','NO_ASISTIO') then allowed := true;
  end if;
  if not allowed then raise exception using errcode = 'P0001', message = 'Cambio de estado no permitido: ' || item.estado || ' a ' || nuevo_estado; end if;
  update public.citas set estado = nuevo_estado,
    motivo_cancelacion = case when nuevo_estado = 'CANCELADA' then btrim(motivo_value) else motivo_cancelacion end,
    actualizado_por = actor_id, actualizado_en = now(), version = version + 1 where id = cita_id;
  insert into public.cita_historial_estados(cita_id, estado_anterior, estado_nuevo, motivo, creado_por)
  values (cita_id, item.estado, nuevo_estado, nullif(btrim(motivo_value), ''), actor_id);
  perform public.registrar_auditoria('CAMBIAR_ESTADO_CITA', 'CITA', cita_id::text, item.estado || ' -> ' || nuevo_estado);
  return cita_id;
end;
$$;

create or replace function public.solicitud_cita_json(item public.solicitudes_cita_web) returns jsonb
language sql immutable set search_path = '' as $$
  select jsonb_build_object('id', item.id, 'fullName', item.nombre_completo, 'documentNumber', item.numero_documento,
    'mobile', item.celular, 'email', item.email, 'service', item.servicio, 'preferredDate', item.fecha_preferida,
    'preferredShift', item.turno_preferido, 'message', item.mensaje, 'status', item.estado,
    'internalObservation', item.observacion_interna, 'appointmentId', item.cita_id, 'attendedBy', item.atendido_por,
    'createdAt', item.creado_en, 'updatedAt', item.actualizado_en, 'version', item.version)
$$;

create or replace function public.crear_solicitud_cita(datos jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare item public.solicitudes_cita_web; mobile_value text := regexp_replace(coalesce(datos ->> 'mobile', ''), '\D', '', 'g'); shift_value text := coalesce(nullif(datos ->> 'preferredShift', ''), 'INDIFERENTE');
begin
  if coalesce((datos ->> 'privacyConsent')::boolean, false) is not true then raise exception using errcode = 'P0001', message = 'Debe aceptar el tratamiento de datos para solicitar contacto'; end if;
  if nullif(btrim(datos ->> 'fullName'), '') is null or nullif(btrim(datos ->> 'service'), '') is null then raise exception using errcode = 'P0001', message = 'Nombre y servicio son obligatorios'; end if;
  if length(mobile_value) < 7 or length(mobile_value) > 20 then raise exception using errcode = 'P0001', message = 'Celular inválido'; end if;
  if shift_value not in ('MANANA','TARDE','INDIFERENTE') then raise exception using errcode = 'P0001', message = 'Turno preferido inválido'; end if;
  if nullif(datos ->> 'preferredDate', '')::date < current_date then raise exception using errcode = 'P0001', message = 'La fecha preferida no puede estar en el pasado'; end if;
  insert into public.solicitudes_cita_web(nombre_completo, numero_documento, celular, email, servicio,
    fecha_preferida, turno_preferido, mensaje, consentimiento_privacidad)
  values (btrim(datos ->> 'fullName'), nullif(btrim(datos ->> 'documentNumber'), ''), mobile_value,
    nullif(lower(btrim(datos ->> 'email')), ''), btrim(datos ->> 'service'), nullif(datos ->> 'preferredDate', '')::date,
    shift_value, nullif(btrim(datos ->> 'message'), ''), true) returning * into item;
  insert into public.auditoria(usuario_id, username, accion, recurso, recurso_id, resultado, detalle)
  values (null, null, 'CREAR_SOLICITUD_WEB', 'SOLICITUD_CITA', item.id::text, 'EXITO', 'Solicitud pública recibida');
  return public.solicitud_cita_json(item);
end;
$$;

create or replace function public.listar_solicitudes_cita(estado_filtro text default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if not public.has_permission('CITA_LEER') then raise exception using errcode = '42501', message = 'No autorizado para consultar solicitudes'; end if;
  select coalesce(jsonb_agg(public.solicitud_cita_json(s) order by s.creado_en desc), '[]'::jsonb) into result
  from public.solicitudes_cita_web s
  where listar_solicitudes_cita.estado_filtro is null
     or s.estado = listar_solicitudes_cita.estado_filtro;
  return result;
end;
$$;

create or replace function public.gestionar_solicitud_cita(solicitud_id bigint, datos jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor_id bigint := public.current_app_user_id(); item public.solicitudes_cita_web; next_status text := datos ->> 'status'; appointment_id bigint := nullif(datos ->> 'appointmentId', '')::bigint;
begin
  if actor_id is null or not public.has_permission('CITA_ESCRIBIR') then raise exception using errcode = '42501', message = 'No autorizado para gestionar solicitudes'; end if;
  if next_status not in ('PENDIENTE','CONTACTADO','AGENDADO','DESCARTADO') then raise exception using errcode = 'P0001', message = 'Estado de solicitud inválido'; end if;
  select * into item from public.solicitudes_cita_web where id = solicitud_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'Solicitud no encontrada'; end if;
  if item.version <> (datos ->> 'version')::bigint then raise exception using errcode = 'P0001', message = 'La solicitud fue actualizada por otro usuario'; end if;
  if next_status = 'AGENDADO' and (appointment_id is null or not exists(select 1 from public.citas where id = appointment_id)) then
    raise exception using errcode = 'P0001', message = 'Para marcar como agendada indique una cita válida';
  end if;
  update public.solicitudes_cita_web set estado = next_status, observacion_interna = nullif(btrim(datos ->> 'observation'), ''),
    cita_id = appointment_id, atendido_por = actor_id, actualizado_en = now(), version = version + 1
  where id = solicitud_id returning * into item;
  perform public.registrar_auditoria('GESTIONAR_SOLICITUD_WEB', 'SOLICITUD_CITA', solicitud_id::text, next_status);
  return public.solicitud_cita_json(item);
end;
$$;

revoke all on function public.cita_json(public.citas) from public;
revoke all on function public.listar_citas(timestamptz, timestamptz, bigint, text) from public;
revoke all on function public.obtener_cita(bigint) from public;
revoke all on function public.validar_profesional_cita(bigint) from public;
revoke all on function public.validar_disponibilidad_cita(bigint, bigint, timestamptz, timestamptz, bigint) from public;
revoke all on function public.disponibilidad_cita(bigint, date, bigint) from public;
revoke all on function public.crear_cita(jsonb) from public;
revoke all on function public.actualizar_cita(bigint, jsonb) from public;
revoke all on function public.cambiar_estado_cita(bigint, text, bigint, text) from public;
revoke all on function public.solicitud_cita_json(public.solicitudes_cita_web) from public;
revoke all on function public.crear_solicitud_cita(jsonb) from public;
revoke all on function public.listar_solicitudes_cita(text) from public;
revoke all on function public.gestionar_solicitud_cita(bigint, jsonb) from public;

grant execute on function public.listar_citas(timestamptz, timestamptz, bigint, text) to authenticated;
grant execute on function public.obtener_cita(bigint) to authenticated;
grant execute on function public.disponibilidad_cita(bigint, date, bigint) to authenticated;
grant execute on function public.crear_cita(jsonb) to authenticated;
grant execute on function public.actualizar_cita(bigint, jsonb) to authenticated;
grant execute on function public.cambiar_estado_cita(bigint, text, bigint, text) to authenticated;
grant execute on function public.crear_solicitud_cita(jsonb) to anon, authenticated;
grant execute on function public.listar_solicitudes_cita(text) to authenticated;
grant execute on function public.gestionar_solicitud_cita(bigint, jsonb) to authenticated;
