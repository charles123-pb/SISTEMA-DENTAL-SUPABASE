-- RPCs conservan las operaciones atómicas y validaciones del PatientService de Spring.

create or replace function public.validar_datos_paciente(datos jsonb) returns void
language plpgsql set search_path = '' as $$
declare
  tipo text := datos ->> 'documentType';
  documento text := nullif(upper(btrim(datos ->> 'documentNumber')), '');
  nacimiento date := (datos ->> 'birthDate')::date;
  celular text := nullif(regexp_replace(coalesce(datos ->> 'mobile', ''), '\D', '', 'g'), '');
begin
  if tipo = 'SIN_DOCUMENTO' and documento is not null then
    raise exception using errcode = 'P0001', message = 'SIN_DOCUMENTO no debe incluir número';
  end if;
  if tipo <> 'SIN_DOCUMENTO' and documento is null then
    raise exception using errcode = 'P0001', message = 'El número de documento es obligatorio';
  end if;
  if tipo = 'DNI' and coalesce(documento, '') !~ '^\d{8}$' then
    raise exception using errcode = 'P0001', message = 'El DNI debe tener ocho dígitos';
  end if;
  if nacimiento > current_date then
    raise exception using errcode = 'P0001', message = 'La fecha de nacimiento no puede ser futura';
  end if;
  if extract(year from age(current_date, nacimiento)) < 18 and
    (nullif(btrim(datos ->> 'responsibleName'), '') is null
     or nullif(btrim(datos ->> 'responsibleRelationship'), '') is null
     or nullif(regexp_replace(coalesce(datos ->> 'responsiblePhone', ''), '\D', '', 'g'), '') is null) then
    raise exception using errcode = 'P0001', message = 'Los menores de edad requieren responsable, parentesco y teléfono';
  end if;
  if coalesce((datos ->> 'whatsappConsent')::boolean, false) and celular is null then
    raise exception using errcode = 'P0001', message = 'Registre un celular antes de autorizar WhatsApp';
  end if;
end;
$$;

create or replace function public.crear_paciente(datos jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
declare actor_id bigint := public.current_app_user_id(); new_id bigint; contact jsonb := datos -> 'emergencyContact';
begin
  if actor_id is null or not public.has_permission('PACIENTE_ESCRIBIR') then
    raise exception using errcode = '42501', message = 'No autorizado para registrar pacientes';
  end if;
  perform public.validar_datos_paciente(datos);
  insert into public.pacientes(
    numero_historia, tipo_documento, numero_documento, nombres, apellido_paterno, apellido_materno,
    fecha_nacimiento, sexo, lugar_nacimiento, ocupacion, estado_civil, grado_instruccion, religion,
    autoidentificacion_etnica, celular, telefono, email, direccion, responsable_nombre,
    responsable_documento, responsable_parentesco, responsable_telefono, whatsapp_autorizado,
    whatsapp_autorizado_en, whatsapp_autorizado_por, creado_por, actualizado_por
  ) values (
    'HC-' || lpad(nextval('public.patient_history_number_seq')::text, 6, '0'),
    datos ->> 'documentType', case when datos ->> 'documentType' = 'SIN_DOCUMENTO' then null else nullif(upper(btrim(datos ->> 'documentNumber')), '') end,
    regexp_replace(btrim(datos ->> 'firstNames'), '\s+', ' ', 'g'), regexp_replace(btrim(datos ->> 'paternalSurname'), '\s+', ' ', 'g'),
    nullif(regexp_replace(btrim(datos ->> 'maternalSurname'), '\s+', ' ', 'g'), ''), (datos ->> 'birthDate')::date, datos ->> 'sex',
    nullif(btrim(datos ->> 'birthPlace'), ''), nullif(btrim(datos ->> 'occupation'), ''), nullif(btrim(datos ->> 'maritalStatus'), ''),
    nullif(btrim(datos ->> 'educationLevel'), ''), nullif(btrim(datos ->> 'religion'), ''), nullif(btrim(datos ->> 'ethnicSelfIdentification'), ''),
    nullif(regexp_replace(coalesce(datos ->> 'mobile', ''), '\D', '', 'g'), ''), nullif(regexp_replace(coalesce(datos ->> 'phone', ''), '\D', '', 'g'), ''),
    nullif(lower(btrim(datos ->> 'email')), ''), nullif(btrim(datos ->> 'address'), ''), nullif(btrim(datos ->> 'responsibleName'), ''),
    nullif(upper(btrim(datos ->> 'responsibleDocument')), ''), nullif(btrim(datos ->> 'responsibleRelationship'), ''),
    nullif(regexp_replace(coalesce(datos ->> 'responsiblePhone', ''), '\D', '', 'g'), ''), coalesce((datos ->> 'whatsappConsent')::boolean, false),
    case when coalesce((datos ->> 'whatsappConsent')::boolean, false) then now() end,
    case when coalesce((datos ->> 'whatsappConsent')::boolean, false) then actor_id end, actor_id, actor_id
  ) returning id into new_id;

  if contact is not null and jsonb_typeof(contact) = 'object' then
    insert into public.paciente_contactos_emergencia(paciente_id, nombre_completo, parentesco, telefono, principal, creado_por)
    values (new_id, btrim(contact ->> 'fullName'), btrim(contact ->> 'relationship'), btrim(contact ->> 'phone'),
      coalesce((contact ->> 'primary')::boolean, false), actor_id);
  end if;
  perform public.registrar_auditoria('CREAR_PACIENTE', 'PACIENTE', new_id::text, 'Paciente creado mediante Supabase RPC');
  return new_id;
exception when unique_violation then
  raise exception using errcode = 'P0001', message = 'Ya existe un paciente con ese documento o número de historia';
end;
$$;

create or replace function public.actualizar_paciente(paciente_id bigint, datos jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
declare actor_id bigint := public.current_app_user_id(); previous_consent boolean; affected integer;
begin
  if actor_id is null or not public.has_permission('PACIENTE_ESCRIBIR') then
    raise exception using errcode = '42501', message = 'No autorizado para actualizar pacientes';
  end if;
  perform public.validar_datos_paciente(datos);
  select whatsapp_autorizado into previous_consent from public.pacientes where id = paciente_id;
  if not found then raise exception using errcode = 'P0001', message = 'Paciente no encontrado'; end if;

  update public.pacientes set
    tipo_documento = datos ->> 'documentType',
    numero_documento = case when datos ->> 'documentType' = 'SIN_DOCUMENTO' then null else nullif(upper(btrim(datos ->> 'documentNumber')), '') end,
    nombres = regexp_replace(btrim(datos ->> 'firstNames'), '\s+', ' ', 'g'), apellido_paterno = regexp_replace(btrim(datos ->> 'paternalSurname'), '\s+', ' ', 'g'),
    apellido_materno = nullif(regexp_replace(btrim(datos ->> 'maternalSurname'), '\s+', ' ', 'g'), ''), fecha_nacimiento = (datos ->> 'birthDate')::date,
    sexo = datos ->> 'sex', lugar_nacimiento = nullif(btrim(datos ->> 'birthPlace'), ''), ocupacion = nullif(btrim(datos ->> 'occupation'), ''),
    estado_civil = nullif(btrim(datos ->> 'maritalStatus'), ''), grado_instruccion = nullif(btrim(datos ->> 'educationLevel'), ''),
    religion = nullif(btrim(datos ->> 'religion'), ''), autoidentificacion_etnica = nullif(btrim(datos ->> 'ethnicSelfIdentification'), ''),
    celular = nullif(regexp_replace(coalesce(datos ->> 'mobile', ''), '\D', '', 'g'), ''), telefono = nullif(regexp_replace(coalesce(datos ->> 'phone', ''), '\D', '', 'g'), ''),
    email = nullif(lower(btrim(datos ->> 'email')), ''), direccion = nullif(btrim(datos ->> 'address'), ''),
    responsable_nombre = nullif(btrim(datos ->> 'responsibleName'), ''), responsable_documento = nullif(upper(btrim(datos ->> 'responsibleDocument')), ''),
    responsable_parentesco = nullif(btrim(datos ->> 'responsibleRelationship'), ''), responsable_telefono = nullif(regexp_replace(coalesce(datos ->> 'responsiblePhone', ''), '\D', '', 'g'), ''),
    whatsapp_autorizado = coalesce((datos ->> 'whatsappConsent')::boolean, false),
    whatsapp_autorizado_en = case when coalesce((datos ->> 'whatsappConsent')::boolean, false) and not previous_consent then now() else whatsapp_autorizado_en end,
    whatsapp_autorizado_por = case when coalesce((datos ->> 'whatsappConsent')::boolean, false) and not previous_consent then actor_id when not coalesce((datos ->> 'whatsappConsent')::boolean, false) then null else whatsapp_autorizado_por end,
    whatsapp_revocado_en = case when not coalesce((datos ->> 'whatsappConsent')::boolean, false) and previous_consent then now() else whatsapp_revocado_en end,
    actualizado_por = actor_id, actualizado_en = now(), version = version + 1
  where id = paciente_id and version = (datos ->> 'version')::bigint;
  get diagnostics affected = row_count;
  if affected = 0 then raise exception using errcode = 'P0001', message = 'El paciente fue modificado por otro usuario'; end if;
  perform public.registrar_auditoria('ACTUALIZAR_PACIENTE', 'PACIENTE', paciente_id::text, 'Datos administrativos actualizados');
  return paciente_id;
exception when unique_violation then
  raise exception using errcode = 'P0001', message = 'Ya existe otro paciente con ese documento';
end;
$$;

create or replace function public.cambiar_estado_paciente(paciente_id bigint, nuevo_activo boolean, version_actual bigint) returns bigint
language plpgsql security definer set search_path = '' as $$
declare actor_id bigint := public.current_app_user_id(); affected integer;
begin
  if actor_id is null or not public.has_permission('PACIENTE_ESCRIBIR') then
    raise exception using errcode = '42501', message = 'No autorizado para cambiar el estado de pacientes';
  end if;
  update public.pacientes set activo = nuevo_activo, actualizado_por = actor_id, actualizado_en = now(), version = version + 1
  where id = paciente_id and version = version_actual;
  get diagnostics affected = row_count;
  if affected = 0 then raise exception using errcode = 'P0001', message = 'El paciente fue modificado por otro usuario o no existe'; end if;
  perform public.registrar_auditoria(case when nuevo_activo then 'REACTIVAR_PACIENTE' else 'DESACTIVAR_PACIENTE' end,
    'PACIENTE', paciente_id::text, null);
  return paciente_id;
end;
$$;

revoke all on function public.validar_datos_paciente(jsonb) from public;
revoke all on function public.crear_paciente(jsonb) from public;
revoke all on function public.actualizar_paciente(bigint, jsonb) from public;
revoke all on function public.cambiar_estado_paciente(bigint, boolean, bigint) from public;
grant execute on function public.crear_paciente(jsonb) to authenticated;
grant execute on function public.actualizar_paciente(bigint, jsonb) to authenticated;
grant execute on function public.cambiar_estado_paciente(bigint, boolean, bigint) to authenticated;
