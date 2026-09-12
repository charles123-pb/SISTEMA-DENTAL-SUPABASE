create or replace function public.atencion_json(item public.atenciones_clinicas) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', item.id, 'patientId', p.id, 'patientHistoryNumber', p.numero_historia,
    'patientName', concat_ws(' ', p.nombres, p.apellido_paterno, p.apellido_materno),
    'patientAge', extract(year from age(current_date, p.fecha_nacimiento))::integer,
    'appointmentId', item.cita_id, 'dentistId', u.id, 'dentistName', u.nombre_completo,
    'encounterDate', item.fecha_atencion, 'status', item.estado,
    'consultationReason', item.motivo_consulta, 'illnessDuration', item.tiempo_enfermedad,
    'signsSymptoms', item.signos_sintomas, 'chronologicalStory', item.relato_cronologico,
    'systolicPressure', item.presion_sistolica, 'diastolicPressure', item.presion_diastolica,
    'pulse', item.pulso, 'temperature', item.temperatura,
    'respiratoryRate', item.frecuencia_respiratoria, 'weightKg', item.peso_kg,
    'heightCm', item.talla_cm, 'generalExam', item.examen_general,
    'dentalExam', item.examen_odontologico, 'diagnosis', item.diagnostico,
    'workPlan', item.plan_trabajo, 'prognosis', item.pronostico,
    'evolution', item.evolucion, 'instructions', item.indicaciones,
    'nextControlDate', item.fecha_proximo_control, 'discharged', item.alta_paciente,
    'dischargeObservation', item.observacion_alta, 'patientConsent', item.consentimiento_paciente,
    'approvedBy', item.aprobado_por, 'approvedAt', item.aprobado_en,
    'createdAt', item.creado_en, 'updatedAt', item.actualizado_en, 'version', item.version
  )
  from public.pacientes p join public.usuarios u on u.id = item.odontologo_id
  where p.id = item.paciente_id
$$;

create or replace function public.guardar_version_atencion(
  item public.atenciones_clinicas, accion_value text, resumen_value text, actor_id bigint
) returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into public.atencion_versiones(atencion_id, numero_version, accion, resumen, datos, creado_por)
  values (item.id, item.version, accion_value, resumen_value, public.atencion_json(item), actor_id);
end;
$$;

create or replace function public.listar_atenciones(
  desde timestamptz default null, hasta timestamptz default null,
  estado_filtro text default null, paciente_id bigint default null
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if not public.has_permission('CLINICA_LEER') then
    raise exception using errcode = '42501', message = 'No autorizado para consultar historia clínica';
  end if;
  if listar_atenciones.paciente_id is null and (
    desde is null or hasta is null or hasta <= desde or hasta - desde > interval '93 days'
  ) then raise exception using errcode = 'P0001', message = 'Rango de atenciones inválido'; end if;
  select coalesce(jsonb_agg(public.atencion_json(a) order by a.fecha_atencion desc), '[]'::jsonb)
  into result from public.atenciones_clinicas a
  where (listar_atenciones.paciente_id is not null and a.paciente_id = listar_atenciones.paciente_id)
     or (listar_atenciones.paciente_id is null and a.fecha_atencion >= desde and a.fecha_atencion < hasta
       and (listar_atenciones.estado_filtro is null or a.estado = listar_atenciones.estado_filtro));
  return result;
end;
$$;

create or replace function public.obtener_atencion(atencion_id bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if not public.has_permission('CLINICA_LEER') then
    raise exception using errcode = '42501', message = 'No autorizado para consultar historia clínica';
  end if;
  select public.atencion_json(a) into result from public.atenciones_clinicas a where a.id = atencion_id;
  if result is null then raise exception using errcode = 'P0001', message = 'Atención no encontrada'; end if;
  return result;
end;
$$;

create or replace function public.iniciar_atencion(paciente_id bigint, cita_id bigint default null) returns bigint
language plpgsql security definer set search_path = '' as $$
declare actor_id bigint := public.current_app_user_id(); new_item public.atenciones_clinicas; appointment public.citas;
begin
  if actor_id is null or not public.has_permission('CLINICA_ESCRIBIR') or not exists (
    select 1 from public.usuarios_roles ur join public.roles r on r.id = ur.rol_id
    where ur.usuario_id = actor_id and r.codigo = 'ODONTOLOGO' and r.activo
  ) then raise exception using errcode = '42501', message = 'La acción requiere un odontólogo activo'; end if;
  if not exists(select 1 from public.pacientes p where p.id = iniciar_atencion.paciente_id and p.activo) then
    raise exception using errcode = 'P0001', message = 'El paciente está inactivo o no existe';
  end if;
  if iniciar_atencion.cita_id is not null then
    select * into appointment from public.citas c where c.id = iniciar_atencion.cita_id for update;
    if not found then raise exception using errcode = 'P0001', message = 'Cita no encontrada'; end if;
    if appointment.paciente_id <> iniciar_atencion.paciente_id then raise exception using errcode = 'P0001', message = 'La cita no pertenece al paciente'; end if;
    if appointment.profesional_id <> actor_id then raise exception using errcode = 'P0001', message = 'La cita está asignada a otro odontólogo'; end if;
    select * into new_item from public.atenciones_clinicas a where a.cita_id = iniciar_atencion.cita_id;
    if found then return new_item.id; end if;
    if appointment.estado in ('COMPLETADA','CANCELADA','NO_ASISTIO') then
      raise exception using errcode = 'P0001', message = 'No se puede iniciar una atención desde una cita finalizada';
    end if;
    if appointment.estado <> 'EN_ATENCION' then
      update public.citas set estado = 'EN_ATENCION', actualizado_por = actor_id,
        actualizado_en = now(), version = version + 1,
        confirmacion_enviada = false, recordatorio_programado = false, recordatorio_enviado = false
      where id = appointment.id;
      insert into public.cita_historial_estados(cita_id, estado_anterior, estado_nuevo, motivo, creado_por)
      values (appointment.id, appointment.estado, 'EN_ATENCION', 'Atención clínica iniciada', actor_id);
    end if;
  end if;
  insert into public.atenciones_clinicas(paciente_id, cita_id, odontologo_id, creado_por, actualizado_por)
  values (iniciar_atencion.paciente_id, iniciar_atencion.cita_id, actor_id, actor_id, actor_id)
  returning * into new_item;
  perform public.guardar_version_atencion(new_item, 'CREACION', 'Atención iniciada', actor_id);
  perform public.registrar_auditoria('INICIAR_ATENCION', 'ATENCION_CLINICA', new_item.id::text, 'Atención clínica iniciada');
  return new_item.id;
end;
$$;

create or replace function public.actualizar_atencion(atencion_id bigint, datos jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
declare actor_id bigint := public.current_app_user_id(); item public.atenciones_clinicas; affected integer;
begin
  if actor_id is null or not public.has_permission('CLINICA_ESCRIBIR') then raise exception using errcode = '42501', message = 'No autorizado para actualizar historia clínica'; end if;
  select * into item from public.atenciones_clinicas a where a.id = atencion_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'Atención no encontrada'; end if;
  if item.estado <> 'BORRADOR' then raise exception using errcode = 'P0001', message = 'La atención ya no se encuentra en borrador'; end if;
  if item.odontologo_id <> actor_id then raise exception using errcode = 'P0001', message = 'Solo el odontólogo responsable puede modificar esta atención'; end if;
  update public.atenciones_clinicas set
    motivo_consulta = nullif(btrim(datos ->> 'consultationReason'), ''),
    tiempo_enfermedad = nullif(btrim(datos ->> 'illnessDuration'), ''),
    signos_sintomas = nullif(btrim(datos ->> 'signsSymptoms'), ''),
    relato_cronologico = nullif(btrim(datos ->> 'chronologicalStory'), ''),
    presion_sistolica = nullif(datos ->> 'systolicPressure', '')::smallint,
    presion_diastolica = nullif(datos ->> 'diastolicPressure', '')::smallint,
    pulso = nullif(datos ->> 'pulse', '')::smallint,
    temperatura = nullif(datos ->> 'temperature', '')::numeric,
    frecuencia_respiratoria = nullif(datos ->> 'respiratoryRate', '')::smallint,
    peso_kg = nullif(datos ->> 'weightKg', '')::numeric,
    talla_cm = nullif(datos ->> 'heightCm', '')::numeric,
    examen_general = nullif(btrim(datos ->> 'generalExam'), ''),
    examen_odontologico = nullif(btrim(datos ->> 'dentalExam'), ''),
    diagnostico = nullif(btrim(datos ->> 'diagnosis'), ''),
    plan_trabajo = nullif(btrim(datos ->> 'workPlan'), ''),
    pronostico = nullif(btrim(datos ->> 'prognosis'), ''),
    evolucion = nullif(btrim(datos ->> 'evolution'), ''),
    indicaciones = nullif(btrim(datos ->> 'instructions'), ''),
    fecha_proximo_control = nullif(datos ->> 'nextControlDate', '')::date,
    alta_paciente = coalesce((datos ->> 'discharged')::boolean, false),
    observacion_alta = nullif(btrim(datos ->> 'dischargeObservation'), ''),
    consentimiento_paciente = coalesce((datos ->> 'patientConsent')::boolean, false),
    actualizado_por = actor_id, actualizado_en = now(), version = version + 1
  where id = atencion_id and version = (datos ->> 'version')::bigint;
  get diagnostics affected = row_count;
  if affected = 0 then raise exception using errcode = 'P0001', message = 'La atención fue modificada por otro usuario'; end if;
  select * into item from public.atenciones_clinicas a where a.id = atencion_id;
  perform public.guardar_version_atencion(item, 'ACTUALIZACION', 'Borrador clínico actualizado', actor_id);
  perform public.registrar_auditoria('ACTUALIZAR_ATENCION', 'ATENCION_CLINICA', atencion_id::text, 'Borrador clínico actualizado');
  return atencion_id;
end;
$$;

create or replace function public.finalizar_atencion(
  atencion_id bigint, version_actual bigint, confirmar_aprobacion boolean
) returns bigint language plpgsql security definer set search_path = '' as $$
declare actor_id bigint := public.current_app_user_id(); item public.atenciones_clinicas;
begin
  if actor_id is null or not public.has_permission('CLINICA_APROBAR') then raise exception using errcode = '42501', message = 'No autorizado para aprobar historia clínica'; end if;
  if confirmar_aprobacion is not true then raise exception using errcode = 'P0001', message = 'Confirme la aprobación profesional'; end if;
  select * into item from public.atenciones_clinicas a where a.id = atencion_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'Atención no encontrada'; end if;
  if item.estado <> 'BORRADOR' then raise exception using errcode = 'P0001', message = 'La atención ya no se encuentra en borrador'; end if;
  if item.odontologo_id <> actor_id then raise exception using errcode = 'P0001', message = 'Solo el odontólogo responsable puede finalizar esta atención'; end if;
  if item.version <> version_actual then raise exception using errcode = 'P0001', message = 'La atención fue modificada por otro usuario'; end if;
  if item.motivo_consulta is null or item.examen_odontologico is null or item.diagnostico is null or item.plan_trabajo is null then
    raise exception using errcode = 'P0001', message = 'Complete motivo, examen odontológico, diagnóstico y plan de trabajo';
  end if;
  if not item.consentimiento_paciente then raise exception using errcode = 'P0001', message = 'Debe registrar la conformidad del paciente antes de finalizar'; end if;
  update public.atenciones_clinicas set estado = 'FINALIZADA', aprobado_por = actor_id, aprobado_en = now(),
    actualizado_por = actor_id, actualizado_en = now(), version = version + 1 where id = atencion_id returning * into item;
  if item.cita_id is not null then
    if exists(select 1 from public.citas c where c.id = item.cita_id and c.estado in ('CANCELADA','NO_ASISTIO')) then
      raise exception using errcode = 'P0001', message = 'La cita vinculada fue cancelada o marcada como inasistencia';
    end if;
    insert into public.cita_historial_estados(cita_id, estado_anterior, estado_nuevo, motivo, creado_por)
    select c.id, c.estado, 'COMPLETADA', 'Atención clínica finalizada y aprobada', actor_id
    from public.citas c where c.id = item.cita_id and c.estado <> 'COMPLETADA';
    update public.citas set estado = 'COMPLETADA', actualizado_por = actor_id, actualizado_en = now(),
      version = version + 1, confirmacion_enviada = false, recordatorio_programado = false, recordatorio_enviado = false
    where id = item.cita_id and estado <> 'COMPLETADA';
  end if;
  perform public.guardar_version_atencion(item, 'FINALIZACION', 'Registro clínico aprobado por el odontólogo', actor_id);
  perform public.registrar_auditoria('FINALIZAR_ATENCION', 'ATENCION_CLINICA', atencion_id::text, 'Aprobación profesional');
  return atencion_id;
end;
$$;

revoke all on function public.atencion_json(public.atenciones_clinicas) from public;
revoke all on function public.guardar_version_atencion(public.atenciones_clinicas,text,text,bigint) from public;
revoke all on function public.listar_atenciones(timestamptz,timestamptz,text,bigint) from public;
revoke all on function public.obtener_atencion(bigint) from public;
revoke all on function public.iniciar_atencion(bigint,bigint) from public;
revoke all on function public.actualizar_atencion(bigint,jsonb) from public;
revoke all on function public.finalizar_atencion(bigint,bigint,boolean) from public;
grant execute on function public.listar_atenciones(timestamptz,timestamptz,text,bigint) to authenticated;
grant execute on function public.obtener_atencion(bigint) to authenticated;
grant execute on function public.iniciar_atencion(bigint,bigint) to authenticated;
grant execute on function public.actualizar_atencion(bigint,jsonb) to authenticated;
grant execute on function public.finalizar_atencion(bigint,bigint,boolean) to authenticated;
