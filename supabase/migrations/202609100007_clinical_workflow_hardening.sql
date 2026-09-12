-- Refuerza reglas clínicas y control de concurrencia sin depender del frontend.

create or replace function public.validar_registro_atencion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.peso_kg is not null and (new.peso_kg < 0.5 or new.peso_kg > 500) then
    raise exception using errcode = 'P0001', message = 'El peso debe estar entre 0.5 y 500 kg';
  end if;
  if new.talla_cm is not null and (new.talla_cm < 20 or new.talla_cm > 250) then
    raise exception using errcode = 'P0001', message = 'La talla debe estar entre 20 y 250 cm';
  end if;
  if new.presion_sistolica is not null and new.presion_diastolica is not null
     and new.presion_sistolica <= new.presion_diastolica then
    raise exception using errcode = 'P0001', message = 'La presión sistólica debe ser mayor que la diastólica';
  end if;
  if char_length(coalesce(new.relato_cronologico, '')) > 4000
     or char_length(coalesce(new.examen_general, '')) > 4000
     or char_length(coalesce(new.examen_odontologico, '')) > 4000
     or char_length(coalesce(new.diagnostico, '')) > 4000
     or char_length(coalesce(new.plan_trabajo, '')) > 4000
     or char_length(coalesce(new.evolucion, '')) > 4000
     or char_length(coalesce(new.indicaciones, '')) > 4000 then
    raise exception using errcode = 'P0001', message = 'Uno de los textos clínicos supera los 4000 caracteres';
  end if;
  if new.alta_paciente and nullif(btrim(new.observacion_alta), '') is null then
    raise exception using errcode = 'P0001', message = 'Registra una observación cuando se da de alta al paciente';
  end if;
  if new.estado = 'FINALIZADA' and (
    nullif(btrim(new.motivo_consulta), '') is null
    or nullif(btrim(new.examen_odontologico), '') is null
    or nullif(btrim(new.diagnostico), '') is null
    or nullif(btrim(new.plan_trabajo), '') is null
    or not new.consentimiento_paciente
    or new.aprobado_por is null
    or new.aprobado_en is null
  ) then
    raise exception using errcode = 'P0001', message = 'La atención finalizada requiere motivo, examen, diagnóstico, plan, consentimiento y aprobación';
  end if;
  return new;
end;
$$;

drop trigger if exists validar_registro_atencion_trigger on public.atenciones_clinicas;
create trigger validar_registro_atencion_trigger
before insert or update on public.atenciones_clinicas
for each row execute function public.validar_registro_atencion();

create or replace function public.validar_registro_odontograma()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if char_length(coalesce(new.observacion_general, '')) > 4000 then
    raise exception using errcode = 'P0001', message = 'La observación del odontograma supera los 4000 caracteres';
  end if;
  if new.estado = 'APROBADO' and (new.aprobado_por is null or new.aprobado_en is null) then
    raise exception using errcode = 'P0001', message = 'El odontograma aprobado requiere responsable y fecha de aprobación';
  end if;
  return new;
end;
$$;

drop trigger if exists validar_registro_odontograma_trigger on public.odontogramas;
create trigger validar_registro_odontograma_trigger
before insert or update on public.odontogramas
for each row execute function public.validar_registro_odontograma();

create or replace function public.registrar_hallazgo_odontograma(odontograma_id bigint, datos jsonb)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id bigint := public.current_app_user_id();
  item public.odontogramas;
  finding_id bigint;
  valid_tooth boolean;
begin
  if actor_id is null or not public.has_permission('CLINICA_ESCRIBIR') then
    raise exception using errcode = '42501', message = 'No autorizado para registrar hallazgos';
  end if;
  item := public.validar_edicion_odontograma(odontograma_id, actor_id);
  if nullif(datos ->> 'version', '') is null or item.version <> (datos ->> 'version')::bigint then
    raise exception using errcode = 'P0001', message = 'El odontograma fue modificado por otro usuario';
  end if;
  valid_tooth := case when item.tipo_denticion = 'PERMANENTE' then
    datos ->> 'tooth' = any(array['18','17','16','15','14','13','12','11','21','22','23','24','25','26','27','28','48','47','46','45','44','43','42','41','31','32','33','34','35','36','37','38'])
  else
    datos ->> 'tooth' = any(array['55','54','53','52','51','61','62','63','64','65','85','84','83','82','81','71','72','73','74','75'])
  end;
  if not valid_tooth then
    raise exception using errcode = 'P0001', message = 'La pieza no corresponde a la dentición seleccionada';
  end if;
  if datos ->> 'surface' not in ('GENERAL','OCLUSAL','INCISAL','MESIAL','DISTAL','VESTIBULAR','LINGUAL_PALATINA') then
    raise exception using errcode = 'P0001', message = 'Superficie dental inválida';
  end if;
  if datos ->> 'condition' not in ('CARIES','RESTAURACION','CORONA','AUSENTE','EXTRACCION_INDICADA','ENDODONCIA','FRACTURA','SELLANTE','PROTESIS','IMPLANTE','MOVILIDAD','OTRO') then
    raise exception using errcode = 'P0001', message = 'Condición dental inválida';
  end if;
  if datos ->> 'treatmentState' not in ('EXISTENTE','INDICADO','REALIZADO') then
    raise exception using errcode = 'P0001', message = 'Estado de tratamiento inválido';
  end if;
  if char_length(coalesce(datos ->> 'observation', '')) > 500 then
    raise exception using errcode = 'P0001', message = 'La observación del hallazgo supera los 500 caracteres';
  end if;

  select h.id into finding_id
  from public.odontograma_hallazgos h
  where h.odontograma_id = registrar_hallazgo_odontograma.odontograma_id
    and h.pieza = datos ->> 'tooth'
    and h.superficie = datos ->> 'surface'
    and h.condicion = datos ->> 'condition'
    and h.activo
  for update;

  if finding_id is null then
    insert into public.odontograma_hallazgos(
      odontograma_id, pieza, superficie, condicion, estado_tratamiento, observacion,
      creado_por, actualizado_por
    ) values (
      odontograma_id, datos ->> 'tooth', datos ->> 'surface', datos ->> 'condition',
      datos ->> 'treatmentState', nullif(btrim(datos ->> 'observation'), ''), actor_id, actor_id
    ) returning id into finding_id;
  else
    update public.odontograma_hallazgos
    set estado_tratamiento = datos ->> 'treatmentState',
        observacion = nullif(btrim(datos ->> 'observation'), ''),
        actualizado_por = actor_id, actualizado_en = now(), version = version + 1
    where id = finding_id;
  end if;

  update public.odontogramas
  set actualizado_por = actor_id, actualizado_en = now(), version = version + 1
  where id = odontograma_id
  returning * into item;
  perform public.guardar_version_odontograma(item, 'Hallazgo registrado en pieza ' || (datos ->> 'tooth'), actor_id);
  perform public.registrar_auditoria('REGISTRAR_HALLAZGO_ODONTOGRAMA', 'ODONTOGRAMA', odontograma_id::text, 'Hallazgo ' || finding_id::text);
  return odontograma_id;
end;
$$;

create or replace function public.validar_evolucion_tratamiento()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.procedimiento_realizado := btrim(new.procedimiento_realizado);
  if new.procedimiento_realizado = '' then
    raise exception using errcode = 'P0001', message = 'Describe el procedimiento realizado';
  end if;
  if char_length(new.procedimiento_realizado) > 4000
     or char_length(coalesce(new.observaciones, '')) > 4000 then
    raise exception using errcode = 'P0001', message = 'La evolución clínica supera los 4000 caracteres';
  end if;
  if new.proxima_sesion is not null and new.proxima_sesion < new.fecha::date then
    raise exception using errcode = 'P0001', message = 'La próxima sesión no puede ser anterior a la evolución';
  end if;
  return new;
end;
$$;

drop trigger if exists validar_evolucion_tratamiento_trigger on public.evoluciones_tratamiento;
create trigger validar_evolucion_tratamiento_trigger
before insert or update on public.evoluciones_tratamiento
for each row execute function public.validar_evolucion_tratamiento();

revoke all on function public.validar_registro_atencion() from public;
revoke all on function public.validar_registro_odontograma() from public;
revoke all on function public.validar_evolucion_tratamiento() from public;
revoke all on function public.registrar_hallazgo_odontograma(bigint, jsonb) from public;
grant execute on function public.registrar_hallazgo_odontograma(bigint, jsonb) to authenticated;
