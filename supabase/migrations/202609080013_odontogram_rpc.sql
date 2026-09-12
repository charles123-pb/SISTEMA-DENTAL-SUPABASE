create or replace function public.odontograma_json(item public.odontogramas) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', item.id, 'encounterId', item.atencion_id, 'patientId', item.paciente_id,
    'dentitionType', item.tipo_denticion, 'status', item.estado,
    'generalObservation', item.observacion_general, 'approvedBy', item.aprobado_por,
    'approvedAt', item.aprobado_en, 'createdAt', item.creado_en,
    'updatedAt', item.actualizado_en, 'version', item.version,
    'findings', coalesce((select jsonb_agg(jsonb_build_object(
      'id', h.id, 'tooth', h.pieza, 'surface', h.superficie, 'condition', h.condicion,
      'treatmentState', h.estado_tratamiento, 'observation', h.observacion,
      'createdAt', h.creado_en, 'updatedAt', h.actualizado_en, 'version', h.version
    ) order by h.pieza, h.superficie) from public.odontograma_hallazgos h
      where h.odontograma_id = item.id and h.activo), '[]'::jsonb)
  )
$$;

create or replace function public.validar_edicion_odontograma(odontograma_id bigint, actor_id bigint)
returns public.odontogramas language plpgsql security definer set search_path = '' as $$
declare item public.odontogramas; encounter public.atenciones_clinicas;
begin
  select * into item from public.odontogramas o where o.id = odontograma_id for update;
  if not found then raise exception using errcode='P0001', message='Odontograma no encontrado'; end if;
  select * into encounter from public.atenciones_clinicas a where a.id = item.atencion_id;
  if encounter.estado <> 'BORRADOR' then raise exception using errcode='P0001', message='La atención ya fue finalizada'; end if;
  if encounter.odontologo_id <> actor_id then raise exception using errcode='42501', message='Solo el odontólogo responsable puede modificar este odontograma'; end if;
  if item.estado <> 'BORRADOR' then raise exception using errcode='P0001', message='El odontograma ya fue aprobado'; end if;
  return item;
end;
$$;

create or replace function public.guardar_version_odontograma(item public.odontogramas, resumen_value text, actor_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare next_version bigint;
begin
  select coalesce(max(numero_version), 0) + 1 into next_version from public.odontograma_versiones where odontograma_id = item.id;
  insert into public.odontograma_versiones(odontograma_id, numero_version, resumen, datos, creado_por)
  values (item.id, next_version, resumen_value, public.odontograma_json(item), actor_id);
end;
$$;

create or replace function public.listar_odontogramas(atencion_id bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if not public.has_permission('CLINICA_LEER') then raise exception using errcode='42501', message='No autorizado para consultar odontogramas'; end if;
  if not exists(select 1 from public.atenciones_clinicas a where a.id = atencion_id) then raise exception using errcode='P0001', message='Atención no encontrada'; end if;
  select coalesce(jsonb_agg(public.odontograma_json(o) order by o.tipo_denticion), '[]'::jsonb)
  into result from public.odontogramas o where o.atencion_id = listar_odontogramas.atencion_id;
  return result;
end;
$$;

create or replace function public.inicializar_odontograma(atencion_id bigint, tipo_denticion text, observacion text default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare actor_id bigint := public.current_app_user_id(); encounter public.atenciones_clinicas; item public.odontogramas;
begin
  if actor_id is null or not public.has_permission('CLINICA_ESCRIBIR') then raise exception using errcode='42501', message='No autorizado para crear odontogramas'; end if;
  select * into encounter from public.atenciones_clinicas a where a.id = atencion_id for update;
  if not found then raise exception using errcode='P0001', message='Atención no encontrada'; end if;
  if encounter.estado <> 'BORRADOR' then raise exception using errcode='P0001', message='La atención ya fue finalizada'; end if;
  if encounter.odontologo_id <> actor_id then raise exception using errcode='42501', message='Solo el odontólogo responsable puede modificar este odontograma'; end if;
  if tipo_denticion not in ('PERMANENTE','INFANTIL') then raise exception using errcode='P0001', message='Tipo de dentición inválido'; end if;
  select * into item from public.odontogramas o where o.atencion_id = inicializar_odontograma.atencion_id and o.tipo_denticion = inicializar_odontograma.tipo_denticion;
  if found then return item.id; end if;
  insert into public.odontogramas(atencion_id,paciente_id,tipo_denticion,observacion_general,creado_por,actualizado_por)
  values (encounter.id,encounter.paciente_id,tipo_denticion,nullif(btrim(observacion),''),actor_id,actor_id) returning * into item;
  perform public.guardar_version_odontograma(item,'Odontograma creado',actor_id);
  perform public.registrar_auditoria('CREAR_ODONTOGRAMA','ODONTOGRAMA',item.id::text,tipo_denticion);
  return item.id;
end;
$$;

create or replace function public.observar_odontograma(odontograma_id bigint, observacion text, version_actual bigint)
returns bigint language plpgsql security definer set search_path = '' as $$
declare actor_id bigint := public.current_app_user_id(); item public.odontogramas;
begin
  if actor_id is null or not public.has_permission('CLINICA_ESCRIBIR') then raise exception using errcode='42501', message='No autorizado para actualizar odontogramas'; end if;
  item := public.validar_edicion_odontograma(odontograma_id,actor_id);
  if item.version <> version_actual then raise exception using errcode='P0001', message='El odontograma fue modificado por otro usuario'; end if;
  update public.odontogramas set observacion_general=nullif(btrim(observacion),''),actualizado_por=actor_id,actualizado_en=now(),version=version+1 where id=odontograma_id returning * into item;
  perform public.guardar_version_odontograma(item,'Observación general actualizada',actor_id);
  perform public.registrar_auditoria('ACTUALIZAR_ODONTOGRAMA','ODONTOGRAMA',odontograma_id::text,'Observación general');
  return odontograma_id;
end;
$$;

create or replace function public.registrar_hallazgo_odontograma(odontograma_id bigint, datos jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare actor_id bigint := public.current_app_user_id(); item public.odontogramas; finding_id bigint; valid_tooth boolean;
begin
  if actor_id is null or not public.has_permission('CLINICA_ESCRIBIR') then raise exception using errcode='42501', message='No autorizado para registrar hallazgos'; end if;
  item := public.validar_edicion_odontograma(odontograma_id,actor_id);
  valid_tooth := case when item.tipo_denticion='PERMANENTE' then datos->>'tooth' = any(array['18','17','16','15','14','13','12','11','21','22','23','24','25','26','27','28','48','47','46','45','44','43','42','41','31','32','33','34','35','36','37','38'])
    else datos->>'tooth' = any(array['55','54','53','52','51','61','62','63','64','65','85','84','83','82','81','71','72','73','74','75']) end;
  if not valid_tooth then raise exception using errcode='P0001', message='La pieza no corresponde a la dentición seleccionada'; end if;
  if datos->>'surface' not in ('GENERAL','OCLUSAL','INCISAL','MESIAL','DISTAL','VESTIBULAR','LINGUAL_PALATINA') then raise exception using errcode='P0001', message='Superficie dental inválida'; end if;
  if datos->>'condition' not in ('CARIES','RESTAURACION','CORONA','AUSENTE','EXTRACCION_INDICADA','ENDODONCIA','FRACTURA','SELLANTE','PROTESIS','IMPLANTE','MOVILIDAD','OTRO') then raise exception using errcode='P0001', message='Condición dental inválida'; end if;
  if datos->>'treatmentState' not in ('EXISTENTE','INDICADO','REALIZADO') then raise exception using errcode='P0001', message='Estado de tratamiento inválido'; end if;
  select h.id into finding_id from public.odontograma_hallazgos h where h.odontograma_id=registrar_hallazgo_odontograma.odontograma_id
    and h.pieza=datos->>'tooth' and h.superficie=datos->>'surface' and h.condicion=datos->>'condition' and h.activo for update;
  if finding_id is null then
    insert into public.odontograma_hallazgos(odontograma_id,pieza,superficie,condicion,estado_tratamiento,observacion,creado_por,actualizado_por)
    values(odontograma_id,datos->>'tooth',datos->>'surface',datos->>'condition',datos->>'treatmentState',nullif(btrim(datos->>'observation'),''),actor_id,actor_id) returning id into finding_id;
  else
    update public.odontograma_hallazgos set estado_tratamiento=datos->>'treatmentState',observacion=nullif(btrim(datos->>'observation'),''),actualizado_por=actor_id,actualizado_en=now(),version=version+1 where id=finding_id;
  end if;
  update public.odontogramas set actualizado_por=actor_id,actualizado_en=now(),version=version+1 where id=odontograma_id returning * into item;
  perform public.guardar_version_odontograma(item,'Hallazgo registrado en pieza '||(datos->>'tooth'),actor_id);
  perform public.registrar_auditoria('REGISTRAR_HALLAZGO_ODONTOGRAMA','ODONTOGRAMA',odontograma_id::text,'Hallazgo '||finding_id::text);
  return odontograma_id;
end;
$$;

create or replace function public.retirar_hallazgo_odontograma(odontograma_id bigint, hallazgo_id bigint, version_actual bigint)
returns bigint language plpgsql security definer set search_path = '' as $$
declare actor_id bigint := public.current_app_user_id(); item public.odontogramas; affected integer;
begin
  if actor_id is null or not public.has_permission('CLINICA_ESCRIBIR') then raise exception using errcode='42501', message='No autorizado para retirar hallazgos'; end if;
  item := public.validar_edicion_odontograma(odontograma_id,actor_id);
  update public.odontograma_hallazgos set activo=false,actualizado_por=actor_id,actualizado_en=now(),version=version+1
  where id=hallazgo_id and odontograma_id=retirar_hallazgo_odontograma.odontograma_id and activo and version=version_actual;
  get diagnostics affected=row_count;
  if affected=0 then raise exception using errcode='P0001', message='Hallazgo no encontrado o modificado por otro usuario'; end if;
  update public.odontogramas set actualizado_por=actor_id,actualizado_en=now(),version=version+1 where id=odontograma_id returning * into item;
  perform public.guardar_version_odontograma(item,'Hallazgo retirado',actor_id);
  perform public.registrar_auditoria('RETIRAR_HALLAZGO_ODONTOGRAMA','ODONTOGRAMA',odontograma_id::text,'Hallazgo '||hallazgo_id::text);
  return odontograma_id;
end;
$$;

create or replace function public.aprobar_odontograma(odontograma_id bigint, version_actual bigint, confirmar_aprobacion boolean)
returns bigint language plpgsql security definer set search_path = '' as $$
declare actor_id bigint := public.current_app_user_id(); item public.odontogramas;
begin
  if actor_id is null or not public.has_permission('CLINICA_APROBAR') then raise exception using errcode='42501', message='No autorizado para aprobar odontogramas'; end if;
  if confirmar_aprobacion is not true then raise exception using errcode='P0001', message='Confirme la aprobación profesional'; end if;
  item := public.validar_edicion_odontograma(odontograma_id,actor_id);
  if item.version<>version_actual then raise exception using errcode='P0001', message='El odontograma fue modificado por otro usuario'; end if;
  update public.odontogramas set estado='APROBADO',aprobado_por=actor_id,aprobado_en=now(),actualizado_por=actor_id,actualizado_en=now(),version=version+1 where id=odontograma_id returning * into item;
  perform public.guardar_version_odontograma(item,'Odontograma aprobado por el profesional',actor_id);
  perform public.registrar_auditoria('APROBAR_ODONTOGRAMA','ODONTOGRAMA',odontograma_id::text,item.tipo_denticion);
  return odontograma_id;
end;
$$;

-- Completa la regla clínica ahora que la tabla de odontogramas ya existe.
create or replace function public.validar_odontogramas_aprobados(atencion_id bigint) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if exists(select 1 from public.odontogramas o where o.atencion_id=validar_odontogramas_aprobados.atencion_id and o.estado<>'APROBADO') then
    raise exception using errcode='P0001', message='Apruebe los odontogramas registrados antes de finalizar la atención';
  end if;
end;
$$;

create or replace function public.proteger_finalizacion_clinica() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.estado = 'FINALIZADA' and old.estado <> 'FINALIZADA' then
    perform public.validar_odontogramas_aprobados(new.id);
  end if;
  return new;
end;
$$;
create trigger validar_odontogramas_antes_finalizar
before update of estado on public.atenciones_clinicas
for each row execute function public.proteger_finalizacion_clinica();

revoke all on function public.odontograma_json(public.odontogramas) from public;
revoke all on function public.validar_edicion_odontograma(bigint,bigint) from public;
revoke all on function public.guardar_version_odontograma(public.odontogramas,text,bigint) from public;
revoke all on function public.listar_odontogramas(bigint) from public;
revoke all on function public.inicializar_odontograma(bigint,text,text) from public;
revoke all on function public.observar_odontograma(bigint,text,bigint) from public;
revoke all on function public.registrar_hallazgo_odontograma(bigint,jsonb) from public;
revoke all on function public.retirar_hallazgo_odontograma(bigint,bigint,bigint) from public;
revoke all on function public.aprobar_odontograma(bigint,bigint,boolean) from public;
revoke all on function public.validar_odontogramas_aprobados(bigint) from public;
revoke all on function public.proteger_finalizacion_clinica() from public;
grant execute on function public.listar_odontogramas(bigint) to authenticated;
grant execute on function public.inicializar_odontograma(bigint,text,text) to authenticated;
grant execute on function public.observar_odontograma(bigint,text,bigint) to authenticated;
grant execute on function public.registrar_hallazgo_odontograma(bigint,jsonb) to authenticated;
grant execute on function public.retirar_hallazgo_odontograma(bigint,bigint,bigint) to authenticated;
grant execute on function public.aprobar_odontograma(bigint,bigint,boolean) to authenticated;
