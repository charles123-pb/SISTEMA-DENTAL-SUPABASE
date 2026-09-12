-- Sincronización inicial del historial guardado por Evolution API.

alter table public.conversaciones_whatsapp
  add column if not exists nombre_contacto varchar(150),
  add column if not exists proveedor_chat_id varchar(180);

create unique index if not exists uq_conversacion_proveedor_abierta
  on public.conversaciones_whatsapp(proveedor_chat_id)
  where proveedor_chat_id is not null and estado <> 'CERRADA';

create or replace function public.conversacion_whatsapp_json(c public.conversaciones_whatsapp)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id,
    'patientId', c.paciente_id,
    'patientName', coalesce(
      nullif(concat_ws(' ', p.nombres, p.apellido_paterno, p.apellido_materno), ''),
      nullif(c.nombre_contacto, ''), c.telefono),
    'patientHistoryNumber', p.numero_historia,
    'phone', c.telefono,
    'status', c.estado,
    'lastMessage', coalesce(c.ultimo_mensaje, ''),
    'lastMessageDirection', c.ultimo_mensaje_direccion,
    'lastMessageAt', c.ultimo_mensaje_en,
    'unreadCount', c.no_leidos,
    'appointment', case when a.id is null then null else jsonb_build_object(
      'id', a.id, 'start', a.inicio, 'end', a.fin, 'status', a.estado,
      'reason', a.motivo, 'professionalName', u.nombre_completo
    ) end
  )
  from (values (1)) as base(dummy)
  left join public.pacientes p on p.id = c.paciente_id
  left join lateral (
    select x.* from public.citas x
    where x.paciente_id = c.paciente_id and x.inicio > now()
      and x.estado not in ('COMPLETADA','CANCELADA','NO_ASISTIO')
    order by x.inicio limit 1
  ) a on true
  left join public.usuarios u on u.id = a.profesional_id
$$;

create or replace function public.importar_chat_whatsapp(datos jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_chat public.conversaciones_whatsapp;
  v_patient_id bigint;
  v_jid text := nullif(btrim(datos ->> 'providerChatId'), '');
  v_phone text := regexp_replace(coalesce(datos ->> 'phone', split_part(v_jid, '@', 1)), '\D', '', 'g');
  v_name text := nullif(left(btrim(coalesce(datos ->> 'contactName', '')), 150), '');
  v_last text := nullif(btrim(coalesce(datos ->> 'lastMessage', '')), '');
  v_direction text := case when datos ->> 'lastMessageDirection' = 'SALIENTE' then 'SALIENTE' else 'ENTRANTE' end;
  v_last_at timestamptz := coalesce(nullif(datos ->> 'lastMessageAt', '')::timestamptz, now());
  v_unread integer := greatest(coalesce((datos ->> 'unreadCount')::integer, 0), 0);
begin
  if v_jid is null or length(v_phone) < 7 or v_jid ~ '@(g\.us|broadcast|newsletter)$' then
    return null;
  end if;

  select p.id into v_patient_id from public.pacientes p
  where p.activo and p.celular is not null
    and regexp_replace(p.celular, '\D', '', 'g') = v_phone
  limit 1;

  select * into v_chat from public.conversaciones_whatsapp c
  where c.estado <> 'CERRADA' and (c.proveedor_chat_id = v_jid or c.telefono = v_phone)
  order by (c.proveedor_chat_id = v_jid) desc limit 1 for update;

  if not found then
    insert into public.conversaciones_whatsapp(
      paciente_id, telefono, nombre_contacto, proveedor_chat_id, ultimo_mensaje,
      ultimo_mensaje_direccion, ultimo_mensaje_en, no_leidos)
    values (v_patient_id, v_phone, v_name, v_jid, v_last, v_direction, v_last_at, v_unread)
    returning * into v_chat;
  else
    update public.conversaciones_whatsapp set
      paciente_id = coalesce(paciente_id, v_patient_id),
      nombre_contacto = coalesce(v_name, nombre_contacto),
      proveedor_chat_id = coalesce(proveedor_chat_id, v_jid),
      ultimo_mensaje = coalesce(v_last, ultimo_mensaje),
      ultimo_mensaje_direccion = case when v_last is null then ultimo_mensaje_direccion else v_direction end,
      ultimo_mensaje_en = greatest(coalesce(ultimo_mensaje_en, v_last_at), v_last_at),
      no_leidos = v_unread,
      actualizado_en = now()
    where id = v_chat.id returning * into v_chat;
  end if;
  return v_chat.id;
end;
$$;

create or replace function public.importar_mensaje_whatsapp(datos jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_chat public.conversaciones_whatsapp;
  v_message_id bigint;
  v_jid text := nullif(btrim(datos ->> 'providerChatId'), '');
  v_provider_id text := nullif(left(btrim(coalesce(datos ->> 'providerId', '')), 150), '');
  v_content text := btrim(coalesce(datos ->> 'content', ''));
  v_direction text := case when datos ->> 'direction' = 'SALIENTE' then 'SALIENTE' else 'ENTRANTE' end;
  v_status text := upper(coalesce(datos ->> 'status', ''));
  v_created_at timestamptz := coalesce(nullif(datos ->> 'createdAt', '')::timestamptz, now());
begin
  if v_jid is null or v_provider_id is null or v_content = ''
     or v_jid ~ '@(g\.us|broadcast|newsletter)$' then return null; end if;

  select id into v_message_id from public.mensajes_whatsapp where proveedor_id = v_provider_id;
  if found then return v_message_id; end if;

  select * into v_chat from public.conversaciones_whatsapp c
  where c.proveedor_chat_id = v_jid and c.estado <> 'CERRADA' limit 1;
  if not found then
    perform public.importar_chat_whatsapp(jsonb_build_object('providerChatId', v_jid));
    select * into v_chat from public.conversaciones_whatsapp c
    where c.proveedor_chat_id = v_jid and c.estado <> 'CERRADA' limit 1;
  end if;
  if v_chat.id is null then return null; end if;

  if v_direction = 'ENTRANTE' then v_status := 'RECIBIDO';
  elsif v_status not in ('ENVIADO','ENTREGADO','LEIDO','FALLIDO') then v_status := 'ENVIADO';
  end if;

  insert into public.mensajes_whatsapp(
    conversacion_id, paciente_id, direccion, contenido, estado, proveedor_id,
    requiere_revision, tipo, plantilla_nombre, creado_en, enviado_en, intentos)
  values (v_chat.id, v_chat.paciente_id, v_direction, v_content, v_status, v_provider_id,
    false, case when v_direction = 'ENTRANTE' then 'ENTRANTE' else 'MANUAL' end,
    'IMPORTADO_EVOLUTION', v_created_at,
    case when v_direction = 'SALIENTE' then v_created_at else null end,
    case when v_direction = 'SALIENTE' then 1 else 0 end)
  returning id into v_message_id;
  return v_message_id;
exception when unique_violation then
  select id into v_message_id from public.mensajes_whatsapp where proveedor_id = v_provider_id;
  return v_message_id;
end;
$$;

create or replace function public.marcar_solicitud_reprogramacion_whatsapp()
returns trigger language plpgsql security definer set search_path = '' as $$
declare cita_actual public.citas;
begin
  if new.plantilla_nombre = 'IMPORTADO_EVOLUTION' then return new; end if;
  if new.direccion <> 'ENTRANTE' or new.paciente_id is null or not (
    new.intencion = 'REPROGRAMAR' or lower(new.contenido) ~ 'otra fecha|cambi(ar|o).*fecha|mover.*cita'
  ) then return new; end if;
  if new.intencion <> 'REPROGRAMAR' then
    update public.mensajes_whatsapp set intencion = 'REPROGRAMAR', requiere_revision = true where id = new.id;
    insert into public.solicitudes_cita_web(nombre_completo, numero_documento, celular, email,
      servicio, turno_preferido, mensaje, consentimiento_privacidad)
    select concat_ws(' ', p.nombres, p.apellido_paterno, p.apellido_materno), p.numero_documento,
      regexp_replace(p.celular, '\D', '', 'g'), p.email, 'Solicitud de reprogramación',
      'INDIFERENTE', new.contenido, true from public.pacientes p where p.id = new.paciente_id
    and not exists(select 1 from public.solicitudes_cita_web s
      where s.celular = regexp_replace(p.celular, '\D', '', 'g') and s.mensaje = new.contenido
        and s.creado_en > now() - interval '15 minutes');
  end if;
  select * into cita_actual from public.citas
  where paciente_id = new.paciente_id and inicio > now()
    and estado in ('PENDIENTE_CONFIRMACION','CONFIRMADA')
  order by inicio limit 1 for update;
  if cita_actual.id is null then return new; end if;
  update public.citas set estado = 'SOLICITUD_REPROGRAMACION', actualizado_en = now(), version = version + 1
  where id = cita_actual.id;
  update public.mensajes_whatsapp set cita_id = cita_actual.id where id = new.id;
  insert into public.cita_historial_estados(cita_id, estado_anterior, estado_nuevo, motivo, creado_por)
  values (cita_actual.id, cita_actual.estado, 'SOLICITUD_REPROGRAMACION',
    'Paciente solicitó otra fecha por WhatsApp', cita_actual.actualizado_por);
  insert into public.auditoria(usuario_id, username, accion, recurso, recurso_id, resultado, detalle)
  values (null, null, 'SOLICITAR_REPROGRAMACION_WHATSAPP', 'CITA', cita_actual.id::text,
    'EXITO', 'Recepción debe contactar al paciente para definir una nueva fecha');
  return new;
end;
$$;

revoke all on function public.importar_chat_whatsapp(jsonb),
  public.importar_mensaje_whatsapp(jsonb) from public;
grant execute on function public.importar_chat_whatsapp(jsonb),
  public.importar_mensaje_whatsapp(jsonb) to service_role;
