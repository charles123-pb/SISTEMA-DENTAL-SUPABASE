-- Solo órdenes inequívocas modifican una cita. Las demás pasan a revisión.
create or replace function public.clasificar_respuesta_whatsapp(contenido text) returns text
language sql immutable set search_path = '' as $$
  select case
    when lower(contenido) ~ 'sangrado abundante|no para de sangrar|fiebre|hinchaz(o|ó)n severa|dificultad para respirar|dolor insoportable|alergia' then 'ALERTA_CLINICA'
    when upper(btrim(contenido)) ~ '^(CONFIRMO|CONFIRMAR|CONFIRMO MI CITA)[.! ]*$' then 'CONFIRMAR'
    when upper(btrim(contenido)) ~ '^(CANCELAR|CANCELO|CANCELAR MI CITA|CANCELO MI CITA)[.! ]*$' then 'CANCELAR'
    when upper(btrim(contenido)) ~ '^(REPROGRAMAR|REPROGRAMAR MI CITA|QUIERO OTRA FECHA|OTRA FECHA)[.! ]*$' then 'REPROGRAMAR'
    when upper(btrim(contenido)) ~ '^(RESERVAR|AGENDAR|QUIERO UNA CITA|RESERVAR CITA)[.! ]*$' then 'RESERVAR'
    else 'NO_ENTENDIDO'
  end
$$;
revoke all on function public.clasificar_respuesta_whatsapp(text) from public, anon, authenticated;

create or replace function public.registrar_evento_whatsapp(datos jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_item public.mensajes_whatsapp;
  v_contexto public.mensajes_whatsapp;
  v_conversacion public.conversaciones_whatsapp;
  v_paciente public.pacientes;
  v_cita public.citas;
  v_phone text := public.normalizar_telefono_whatsapp(datos ->> 'phone');
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
  if v_provider is null then raise exception 'El evento requiere un identificador del proveedor'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('whatsapp:' || v_phone, 0));
  if v_provider is not null then
    select * into v_item from public.mensajes_whatsapp where proveedor_id = v_provider;
    if found then return public.mensaje_json(v_item); end if;
  end if;
  if length(v_phone) < 7 or v_content = '' then
    raise exception using errcode = 'P0001', message = 'Evento de WhatsApp incompleto';
  end if;

  select count(*), max(id) into v_patient_count, v_patient_id
  from public.pacientes where activo and celular is not null
    and public.normalizar_telefono_whatsapp(celular) = v_phone;
  if v_patient_count = 1 then select * into v_paciente from public.pacientes where id = v_patient_id; end if;

  if v_context_provider is not null then
    select * into v_contexto from public.mensajes_whatsapp where proveedor_id = v_context_provider
      and paciente_id = v_paciente.id and direccion = 'SALIENTE';
  end if;
  select * into v_conversacion from public.conversaciones_whatsapp
    where telefono = v_phone and estado <> 'CERRADA';
  if not found then
    insert into public.conversaciones_whatsapp(paciente_id, telefono)
    values (v_paciente.id, v_phone) returning * into v_conversacion;
  end if;

  v_intent := public.clasificar_respuesta_whatsapp(v_content);

  if v_paciente.id is not null and v_intent in ('CONFIRMAR','CANCELAR','REPROGRAMAR') then
    if v_context_provider is not null then
      select * into v_cita from public.citas where id = v_contexto.cita_id
        and paciente_id = v_paciente.id and inicio > now()
        and (v_contexto.cita_inicio_original is null or v_contexto.cita_inicio_original = inicio)
        and (v_contexto.cita_agenda_revision is null or v_contexto.cita_agenda_revision = whatsapp_agenda_revision)
        and estado in ('PENDIENTE_CONFIRMACION','CONFIRMADA') for update;
    else
      select count(*), max(id) into v_appointment_count, v_appointment_id from public.citas
      where paciente_id = v_paciente.id and inicio > now()
        and estado in ('PENDIENTE_CONFIRMACION','CONFIRMADA');
      if v_appointment_count = 1 then select * into v_cita from public.citas where id = v_appointment_id and estado in ('PENDIENTE_CONFIRMACION','CONFIRMADA') for update; end if;
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
  end if;
  if v_paciente.id is not null and v_intent in ('REPROGRAMAR','RESERVAR') then
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

-- Si hay varias citas, únicamente se usa la cita identificada por el mensaje citado.
create or replace function public.marcar_solicitud_reprogramacion_whatsapp()
returns trigger language plpgsql security definer set search_path = '' as $$
declare cita_actual public.citas;
begin
  if new.direccion <> 'ENTRANTE' or new.paciente_id is null or new.intencion <> 'REPROGRAMAR' then return new; end if;
  if new.cita_id is null then return new; end if;
  select * into cita_actual from public.citas where id = new.cita_id
    and paciente_id = new.paciente_id and inicio > now()
    and estado in ('PENDIENTE_CONFIRMACION','CONFIRMADA') for update;
  if not found then return new; end if;
  update public.citas set estado = 'SOLICITUD_REPROGRAMACION', actualizado_en = now(), version = version + 1
    where id = cita_actual.id;
  insert into public.cita_historial_estados(cita_id, estado_anterior, estado_nuevo, motivo, creado_por)
    values(cita_actual.id,cita_actual.estado,'SOLICITUD_REPROGRAMACION',
      'Paciente solicitó otra fecha por WhatsApp',cita_actual.actualizado_por);
  insert into public.auditoria(usuario_id,username,accion,recurso,recurso_id,resultado,detalle)
    values(null,null,'SOLICITAR_REPROGRAMACION_WHATSAPP','CITA',cita_actual.id::text,
      'EXITO','Contactar al paciente para definir una nueva fecha');
  return new;
end;
$$;
revoke all on function public.registrar_evento_whatsapp(jsonb),
  public.marcar_solicitud_reprogramacion_whatsapp() from public, anon, authenticated;
grant execute on function public.registrar_evento_whatsapp(jsonb) to service_role;
