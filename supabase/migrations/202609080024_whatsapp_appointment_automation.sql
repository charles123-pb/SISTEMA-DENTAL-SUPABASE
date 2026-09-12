-- Cierre de WhatsApp: confirmaciones, recordatorios e intenciones de cita.

update public.plantillas_mensaje
set contenido = 'Hola {{paciente}}, le recordamos su cita del {{fecha}} a las {{hora}} en Consultorio Dental Americana.',
    actualizado_en = now(), version = version + 1
where codigo = 'CITA_RECORDATORIO';

create or replace function public.telefono_whatsapp_es_unico(
  p_paciente_id bigint, p_telefono text
) returns boolean
language sql stable security definer set search_path = '' as $$
  select count(*) = 1 and max(id) = p_paciente_id
  from public.pacientes
  where activo and celular is not null
    and regexp_replace(celular, '\D', '', 'g') = p_telefono
$$;

create or replace function public.programar_mensaje(
  paciente_id bigint, contenido text, programado_para timestamptz default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_actor bigint := public.current_app_user_id();
  v_paciente public.pacientes;
  v_conversacion_id bigint;
  v_mensaje public.mensajes_whatsapp;
  v_telefono text;
begin
  if v_actor is null or not public.has_permission('SEGUIMIENTO_ESCRIBIR') then
    raise exception using errcode = '42501', message = 'No autorizado para programar mensajes';
  end if;
  if nullif(btrim(contenido), '') is null then
    raise exception using errcode = 'P0001', message = 'El mensaje no puede estar vacío';
  end if;
  select * into v_paciente from public.pacientes p where p.id = paciente_id and p.activo;
  if not found then raise exception using errcode = 'P0001', message = 'Paciente no encontrado'; end if;
  if not v_paciente.whatsapp_autorizado then
    raise exception using errcode = 'P0001', message = 'El paciente no autorizó comunicaciones por WhatsApp';
  end if;
  v_telefono := regexp_replace(coalesce(v_paciente.celular, ''), '\D', '', 'g');
  if length(v_telefono) < 7 then
    raise exception using errcode = 'P0001', message = 'El paciente no tiene un celular válido';
  end if;
  if not public.telefono_whatsapp_es_unico(v_paciente.id, v_telefono) then
    raise exception using errcode = 'P0001', message = 'El celular está asociado a más de un paciente; revise el destinatario antes de enviar';
  end if;

  v_conversacion_id := public.asegurar_conversacion_whatsapp(v_paciente.id, v_telefono);
  insert into public.mensajes_whatsapp(conversacion_id, paciente_id, direccion, contenido,
    estado, programado_para, creado_por, tipo)
  values (v_conversacion_id, v_paciente.id, 'SALIENTE', btrim(contenido), 'PENDIENTE',
    coalesce(programado_para, now()), v_actor, 'MANUAL') returning * into v_mensaje;
  update public.conversaciones_whatsapp set ultimo_mensaje_en = now(), actualizado_en = now()
  where id = v_conversacion_id;
  perform public.registrar_auditoria('PROGRAMAR_MENSAJE', 'SEGUIMIENTO', v_mensaje.id::text,
    'Paciente ' || v_paciente.numero_historia);
  return public.mensaje_json(v_mensaje);
end;
$$;

create or replace function public.asegurar_conversacion_whatsapp(
  p_paciente_id bigint, p_telefono text
) returns bigint
language plpgsql security definer set search_path = '' as $$
declare v_id bigint;
begin
  insert into public.conversaciones_whatsapp(paciente_id, telefono, ultimo_mensaje_en)
  values (p_paciente_id, p_telefono, now())
  on conflict (telefono) where estado <> 'CERRADA'
  do update set paciente_id = coalesce(public.conversaciones_whatsapp.paciente_id, excluded.paciente_id),
    actualizado_en = now()
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.automatizar_mensajes_cita() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_paciente public.pacientes;
  v_conversacion_id bigint;
  v_telefono text;
  v_contenido text;
  v_reprogramada boolean := false;
begin
  if tg_op = 'UPDATE' then
    v_reprogramada := old.inicio is distinct from new.inicio or old.fin is distinct from new.fin;

    if v_reprogramada or new.estado in ('COMPLETADA','CANCELADA','NO_ASISTIO') then
      update public.mensajes_whatsapp
      set estado = 'CANCELADO', error_detalle = case
        when v_reprogramada then 'Cita reprogramada; mensaje anterior cancelado'
        else 'Cita finalizada; mensaje pendiente cancelado'
      end
      where cita_id = new.id and estado = 'PENDIENTE'
        and tipo in ('CITA_CONFIRMACION','CITA_RECORDATORIO');
    elsif old.estado is distinct from new.estado and new.estado <> 'PENDIENTE_CONFIRMACION' then
      update public.mensajes_whatsapp set estado = 'CANCELADO',
        error_detalle = 'La cita ya no requiere confirmación'
      where cita_id = new.id and estado = 'PENDIENTE' and tipo = 'CITA_CONFIRMACION';
    end if;
  end if;

  if new.estado <> 'PENDIENTE_CONFIRMACION' or new.inicio <= now() then return new; end if;
  if tg_op = 'UPDATE' and not v_reprogramada
     and old.estado is not distinct from new.estado then return new; end if;

  select * into v_paciente from public.pacientes where id = new.paciente_id and activo;
  if not found or not v_paciente.whatsapp_autorizado then return new; end if;
  v_telefono := regexp_replace(coalesce(v_paciente.celular, ''), '\D', '', 'g');
  if length(v_telefono) < 7 then return new; end if;
  if not public.telefono_whatsapp_es_unico(v_paciente.id, v_telefono) then return new; end if;

  v_conversacion_id := public.asegurar_conversacion_whatsapp(v_paciente.id, v_telefono);
  select replace(replace(replace(contenido, '{{paciente}}', v_paciente.nombres),
    '{{fecha}}', to_char(new.inicio at time zone 'America/Lima', 'DD/MM/YYYY')),
    '{{hora}}', to_char(new.inicio at time zone 'America/Lima', 'HH24:MI'))
  into v_contenido from public.plantillas_mensaje where codigo = 'CITA_CONFIRMACION' and activo;

  if v_contenido is not null then
    insert into public.mensajes_whatsapp(
      conversacion_id, paciente_id, cita_id, direccion, contenido, estado,
      programado_para, creado_por, tipo, plantilla_nombre, parametros_plantilla)
    values (v_conversacion_id, v_paciente.id, new.id, 'SALIENTE', v_contenido,
      'PENDIENTE', now(), new.actualizado_por, 'CITA_CONFIRMACION', 'CITA_CONFIRMACION',
      jsonb_build_array(v_paciente.nombres,
        to_char(new.inicio at time zone 'America/Lima', 'DD/MM/YYYY'),
        to_char(new.inicio at time zone 'America/Lima', 'HH24:MI')));
  end if;
  return new;
end;
$$;

create trigger mensajes_automaticos_cita
after insert or update of inicio, fin, estado on public.citas
for each row execute function public.automatizar_mensajes_cita();

create or replace function public.programar_seguimiento_clinico() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_seguimiento public.seguimientos_postconsulta;
  v_conversacion_id bigint;
  v_mensaje public.mensajes_whatsapp;
  v_paciente public.pacientes;
  v_telefono text;
  v_programado timestamptz := now() + interval '24 hours';
begin
  if new.estado = 'FINALIZADA' and old.estado <> 'FINALIZADA' then
    insert into public.seguimientos_postconsulta(paciente_id, atencion_id, programado_para, creado_por)
    values (new.paciente_id, new.id, v_programado, new.aprobado_por)
    on conflict(atencion_id) do nothing returning * into v_seguimiento;
    select * into v_paciente from public.pacientes where id = new.paciente_id;

    if v_seguimiento.id is not null and v_paciente.whatsapp_autorizado and v_paciente.celular is not null then
      v_telefono := regexp_replace(v_paciente.celular, '\D', '', 'g');
      if length(v_telefono) >= 7 and public.telefono_whatsapp_es_unico(v_paciente.id, v_telefono) then
        v_conversacion_id := public.asegurar_conversacion_whatsapp(v_paciente.id, v_telefono);
        insert into public.mensajes_whatsapp(conversacion_id, paciente_id, atencion_id,
          direccion, contenido, estado, programado_para, creado_por, tipo,
          plantilla_nombre, parametros_plantilla)
        select v_conversacion_id, v_paciente.id, new.id, 'SALIENTE',
          replace(t.contenido, '{{paciente}}', v_paciente.nombres), 'PENDIENTE',
          v_programado, new.aprobado_por, 'POSTCONSULTA', t.codigo,
          jsonb_build_array(v_paciente.nombres)
        from public.plantillas_mensaje t where t.codigo = 'POSTCONSULTA' and t.activo
        returning * into v_mensaje;
        update public.seguimientos_postconsulta set mensaje_id = v_mensaje.id
        where id = v_seguimiento.id;
      else
        update public.seguimientos_postconsulta set estado = 'CERRADO',
          clasificacion = 'SIN_AUTORIZACION_O_CELULAR', actualizado_en = now()
        where id = v_seguimiento.id;
      end if;
    elsif v_seguimiento.id is not null then
      update public.seguimientos_postconsulta set estado = 'CERRADO',
        clasificacion = 'SIN_AUTORIZACION_O_CELULAR', actualizado_en = now()
      where id = v_seguimiento.id;
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.preparar_recordatorios_whatsapp() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_cita public.citas;
  v_paciente public.pacientes;
  v_conversacion_id bigint;
  v_telefono text;
  v_contenido text;
  v_total integer := 0;
begin
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' then
    raise exception using errcode = '42501', message = 'Operación reservada al servicio de WhatsApp';
  end if;

  for v_cita in
    select * from public.citas
    where estado in ('PENDIENTE_CONFIRMACION','CONFIRMADA')
      and not recordatorio_programado and inicio > now() and inicio <= now() + interval '24 hours'
    order by inicio for update skip locked
  loop
    select * into v_paciente from public.pacientes
    where id = v_cita.paciente_id and activo and whatsapp_autorizado;
    if not found then continue; end if;
    v_telefono := regexp_replace(coalesce(v_paciente.celular, ''), '\D', '', 'g');
    if length(v_telefono) < 7 then continue; end if;
    if not public.telefono_whatsapp_es_unico(v_paciente.id, v_telefono) then continue; end if;

    v_conversacion_id := public.asegurar_conversacion_whatsapp(v_paciente.id, v_telefono);
    select replace(replace(replace(contenido, '{{paciente}}', v_paciente.nombres),
      '{{fecha}}', to_char(v_cita.inicio at time zone 'America/Lima', 'DD/MM/YYYY')),
      '{{hora}}', to_char(v_cita.inicio at time zone 'America/Lima', 'HH24:MI'))
    into v_contenido from public.plantillas_mensaje where codigo = 'CITA_RECORDATORIO' and activo;
    if v_contenido is null then continue; end if;

    insert into public.mensajes_whatsapp(
      conversacion_id, paciente_id, cita_id, direccion, contenido, estado,
      programado_para, creado_por, tipo, plantilla_nombre, parametros_plantilla)
    values (v_conversacion_id, v_paciente.id, v_cita.id, 'SALIENTE', v_contenido,
      'PENDIENTE', now(), v_cita.actualizado_por, 'CITA_RECORDATORIO', 'CITA_RECORDATORIO',
      jsonb_build_array(v_paciente.nombres,
        to_char(v_cita.inicio at time zone 'America/Lima', 'DD/MM/YYYY'),
        to_char(v_cita.inicio at time zone 'America/Lima', 'HH24:MI')));
    update public.citas set recordatorio_programado = true where id = v_cita.id;
    v_total := v_total + 1;
  end loop;
  return v_total;
end;
$$;

create or replace function public.registrar_evento_whatsapp(datos jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_item public.mensajes_whatsapp;
  v_contexto public.mensajes_whatsapp;
  v_conversacion public.conversaciones_whatsapp;
  v_paciente public.pacientes;
  v_cita public.citas;
  v_phone text := regexp_replace(coalesce(datos ->> 'phone', ''), '\D', '', 'g');
  v_content text := btrim(coalesce(datos ->> 'content', ''));
  v_provider text := nullif(datos ->> 'providerId', '');
  v_context_provider text := nullif(datos ->> 'contextProviderId', '');
  v_patient_id bigint;
  v_appointment_id bigint;
  v_intent text;
  v_patient_count integer;
  v_appointment_count integer;
  v_requires_review boolean := true;
  v_action_applied boolean := false;
begin
  if v_provider is not null then
    select * into v_item from public.mensajes_whatsapp where proveedor_id = v_provider;
    if found then return public.mensaje_json(v_item); end if;
  end if;
  if length(v_phone) < 7 or v_content = '' then
    raise exception using errcode = 'P0001', message = 'Evento de WhatsApp incompleto';
  end if;

  select count(*), max(id) into v_patient_count, v_patient_id
  from public.pacientes where activo and celular is not null
    and regexp_replace(celular, '\D', '', 'g') = v_phone;
  if v_patient_count = 1 then select * into v_paciente from public.pacientes where id = v_patient_id; end if;

  if v_context_provider is not null then
    select * into v_contexto from public.mensajes_whatsapp where proveedor_id = v_context_provider;
  end if;
  select * into v_conversacion from public.conversaciones_whatsapp
    where telefono = v_phone and estado <> 'CERRADA';
  if not found then
    insert into public.conversaciones_whatsapp(paciente_id, telefono)
    values (v_paciente.id, v_phone) returning * into v_conversacion;
  end if;

  v_intent := case
    when lower(v_content) ~ 'sangrado abundante|no para de sangrar|fiebre|hinchaz(o|ó)n severa|dificultad para respirar|dolor insoportable|alergia' then 'ALERTA_CLINICA'
    when upper(v_content) ~ 'CONFIRM' then 'CONFIRMAR'
    when upper(v_content) ~ 'CANCEL' then 'CANCELAR'
    when upper(v_content) ~ 'REPROGRAM' then 'REPROGRAMAR'
    when upper(v_content) ~ 'RESERV|AGEND|QUIERO.*CITA' then 'RESERVAR'
    else 'NO_ENTENDIDO'
  end;

  if v_paciente.id is not null and v_intent in ('CONFIRMAR','CANCELAR') then
    if v_contexto.cita_id is not null then
      select * into v_cita from public.citas where id = v_contexto.cita_id
        and paciente_id = v_paciente.id and inicio > now()
        and estado in ('PENDIENTE_CONFIRMACION','CONFIRMADA');
    else
      select count(*), max(id) into v_appointment_count, v_appointment_id from public.citas
      where paciente_id = v_paciente.id and inicio > now()
        and estado in ('PENDIENTE_CONFIRMACION','CONFIRMADA');
      if v_appointment_count = 1 then select * into v_cita from public.citas where id = v_appointment_id; end if;
    end if;

    if v_cita.id is not null and v_intent = 'CONFIRMAR'
       and v_cita.estado = 'PENDIENTE_CONFIRMACION' then
      update public.citas set estado = 'CONFIRMADA', actualizado_en = now(), version = version + 1
      where id = v_cita.id;
      insert into public.cita_historial_estados(cita_id, estado_anterior, estado_nuevo, motivo, creado_por)
      values (v_cita.id, v_cita.estado, 'CONFIRMADA', 'Confirmación recibida por WhatsApp', v_cita.actualizado_por);
      insert into public.auditoria(usuario_id, username, accion, recurso, recurso_id, resultado, detalle)
      values (null, null, 'CONFIRMAR_CITA_WHATSAPP', 'CITA', v_cita.id::text, 'EXITO', 'Confirmación automática del paciente');
      v_requires_review := false; v_action_applied := true;
    elsif v_cita.id is not null and v_intent = 'CANCELAR' then
      update public.citas set estado = 'CANCELADA', motivo_cancelacion = 'Cancelación solicitada por WhatsApp',
        actualizado_en = now(), version = version + 1 where id = v_cita.id;
      insert into public.cita_historial_estados(cita_id, estado_anterior, estado_nuevo, motivo, creado_por)
      values (v_cita.id, v_cita.estado, 'CANCELADA', 'Cancelación solicitada por WhatsApp', v_cita.actualizado_por);
      insert into public.auditoria(usuario_id, username, accion, recurso, recurso_id, resultado, detalle)
      values (null, null, 'CANCELAR_CITA_WHATSAPP', 'CITA', v_cita.id::text, 'EXITO', 'Cancelación automática solicitada por el paciente');
      v_requires_review := false; v_action_applied := true;
    end if;
  elsif v_paciente.id is not null and v_intent in ('REPROGRAMAR','RESERVAR') then
    if not exists(select 1 from public.solicitudes_cita_web
      where celular = v_phone and mensaje = v_content and creado_en > now() - interval '15 minutes') then
      insert into public.solicitudes_cita_web(nombre_completo, numero_documento, celular, email,
        servicio, turno_preferido, mensaje, consentimiento_privacidad)
      values (concat_ws(' ', v_paciente.nombres, v_paciente.apellido_paterno, v_paciente.apellido_materno),
        v_paciente.numero_documento, v_phone, v_paciente.email,
        case when v_intent = 'REPROGRAMAR' then 'Solicitud de reprogramación' else 'Solicitud de cita por WhatsApp' end,
        'INDIFERENTE', v_content, true);
    end if;
  end if;

  insert into public.mensajes_whatsapp(conversacion_id, paciente_id, cita_id, direccion,
    contenido, estado, proveedor_id, intencion, requiere_revision, tipo)
  values (v_conversacion.id, v_paciente.id, v_cita.id, 'ENTRANTE', v_content, 'RECIBIDO',
    v_provider, v_intent, v_requires_review, 'ENTRANTE') returning * into v_item;

  update public.conversaciones_whatsapp set
    estado = case when v_requires_review then 'DERIVADA' when v_action_applied then 'ABIERTA' else estado end,
    ultimo_mensaje_en = now(), actualizado_en = now() where id = v_conversacion.id;

  if v_paciente.id is not null and (v_contexto.tipo = 'POSTCONSULTA' or
     (v_context_provider is null and v_intent in ('ALERTA_CLINICA','NO_ENTENDIDO'))) then
    update public.seguimientos_postconsulta set
      estado = case when v_intent = 'ALERTA_CLINICA' then 'ALERTA' else 'RESPONDIDO' end,
      respuesta = v_content,
      clasificacion = case when v_intent = 'ALERTA_CLINICA' then 'REQUIERE_REVISION' else 'RESPUESTA_RECIBIDA' end,
      motivo_alerta = case when v_intent = 'ALERTA_CLINICA' then 'Alerta clínica detectada en respuesta WhatsApp' end,
      actualizado_en = now(), version = version + 1
    where id = coalesce(
      (select id from public.seguimientos_postconsulta where mensaje_id = v_contexto.id),
      (select id from public.seguimientos_postconsulta where paciente_id = v_paciente.id and estado = 'ENVIADO' order by programado_para desc limit 1)
    );
  end if;
  return public.mensaje_json(v_item);
end;
$$;

revoke all on function public.telefono_whatsapp_es_unico(bigint,text),
  public.asegurar_conversacion_whatsapp(bigint,text),
  public.automatizar_mensajes_cita(), public.preparar_recordatorios_whatsapp() from public;
grant execute on function public.preparar_recordatorios_whatsapp() to service_role;
