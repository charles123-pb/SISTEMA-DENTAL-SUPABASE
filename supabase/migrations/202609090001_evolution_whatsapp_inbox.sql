-- Bandeja WhatsApp operativa sobre Evolution API.

alter table public.conversaciones_whatsapp
  add column if not exists no_leidos integer not null default 0,
  add column if not exists ultimo_mensaje text,
  add column if not exists ultimo_mensaje_direccion varchar(10),
  add constraint chk_conversacion_no_leidos check (no_leidos >= 0),
  add constraint chk_conversacion_ultima_direccion
    check (ultimo_mensaje_direccion is null or ultimo_mensaje_direccion in ('ENTRANTE','SALIENTE'));

create table public.whatsapp_instancia_estado (
  id smallint primary key default 1 check (id = 1),
  estado varchar(20) not null default 'DESCONECTADO',
  numero varchar(30),
  nombre_instancia varchar(100),
  detalle varchar(500),
  actualizado_en timestamptz not null default now(),
  constraint chk_whatsapp_instancia_estado
    check (estado in ('CONECTADO','DESCONECTADO','CONECTANDO','ERROR'))
);
insert into public.whatsapp_instancia_estado(id) values (1) on conflict do nothing;
alter table public.whatsapp_instancia_estado enable row level security;
revoke all on public.whatsapp_instancia_estado from anon, authenticated;
grant select on public.whatsapp_instancia_estado to authenticated;
create policy whatsapp_instance_read on public.whatsapp_instancia_estado
  for select to authenticated using (public.has_permission('SEGUIMIENTO_LEER'));

alter table public.citas drop constraint chk_cita_estado;
alter table public.citas add constraint chk_cita_estado check (estado in (
  'PENDIENTE_CONFIRMACION','CONFIRMADA','SOLICITUD_REPROGRAMACION','EN_ESPERA',
  'EN_ATENCION','COMPLETADA','CANCELADA','NO_ASISTIO'
));

create index if not exists idx_conversaciones_whatsapp_ultimo
  on public.conversaciones_whatsapp(ultimo_mensaje_en desc);

create or replace function public.conversacion_whatsapp_json(c public.conversaciones_whatsapp)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id,
    'patientId', c.paciente_id,
    'patientName', coalesce(nullif(concat_ws(' ', p.nombres, p.apellido_paterno, p.apellido_materno), ''), c.telefono),
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

create or replace function public.marcar_solicitud_reprogramacion_whatsapp()
returns trigger language plpgsql security definer set search_path = '' as $$
declare cita_actual public.citas;
begin
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
create trigger solicitud_reprogramacion_whatsapp
after insert on public.mensajes_whatsapp for each row
execute function public.marcar_solicitud_reprogramacion_whatsapp();

create or replace function public.listar_conversaciones_whatsapp(busqueda text default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare resultado jsonb;
begin
  if not public.has_permission('SEGUIMIENTO_LEER') then
    raise exception using errcode = '42501', message = 'No autorizado para consultar conversaciones';
  end if;
  select coalesce(jsonb_agg(public.conversacion_whatsapp_json(c)
    order by c.ultimo_mensaje_en desc nulls last), '[]'::jsonb) into resultado
  from public.conversaciones_whatsapp c
  left join public.pacientes p on p.id = c.paciente_id
  where c.estado <> 'CERRADA' and (
    nullif(btrim(busqueda), '') is null
    or public.normalizar_busqueda(concat_ws(' ', p.nombres, p.apellido_paterno, p.apellido_materno))
       like '%' || public.normalizar_busqueda(busqueda) || '%'
    or c.telefono like '%' || regexp_replace(busqueda, '\D', '', 'g') || '%'
    or public.normalizar_busqueda(coalesce(c.ultimo_mensaje, ''))
       like '%' || public.normalizar_busqueda(busqueda) || '%'
  );
  return resultado;
end;
$$;

create or replace function public.listar_mensajes_conversacion(conversacion_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare resultado jsonb;
begin
  if not public.has_permission('SEGUIMIENTO_LEER') then
    raise exception using errcode = '42501', message = 'No autorizado para consultar mensajes';
  end if;
  if not exists(select 1 from public.conversaciones_whatsapp where id = conversacion_id) then
    raise exception using errcode = 'P0001', message = 'Conversación no encontrada';
  end if;
  select coalesce(jsonb_agg(public.mensaje_json(m) order by m.creado_en), '[]'::jsonb)
  into resultado from public.mensajes_whatsapp m where m.conversacion_id = conversacion_id;
  return resultado;
end;
$$;

create or replace function public.marcar_conversacion_leida(conversacion_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_permission('SEGUIMIENTO_LEER') then
    raise exception using errcode = '42501', message = 'No autorizado';
  end if;
  update public.conversaciones_whatsapp set no_leidos = 0, actualizado_en = now()
  where id = conversacion_id;
end;
$$;

create or replace function public.reintentar_mensaje_whatsapp(mensaje_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare item public.mensajes_whatsapp;
begin
  if not public.has_permission('SEGUIMIENTO_ESCRIBIR') then
    raise exception using errcode = '42501', message = 'No autorizado para reintentar mensajes';
  end if;
  update public.mensajes_whatsapp set estado = 'PENDIENTE', error_detalle = null,
    programado_para = now(), proveedor_id = null,
    max_intentos = greatest(max_intentos, intentos + 1)
  where id = mensaje_id and direccion = 'SALIENTE' and estado = 'FALLIDO'
  returning * into item;
  if not found then
    raise exception using errcode = 'P0001', message = 'El mensaje no puede volver a intentarse';
  end if;
  return public.mensaje_json(item);
end;
$$;

create or replace function public.actualizar_resumen_conversacion_whatsapp()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.conversaciones_whatsapp set
    ultimo_mensaje = new.contenido,
    ultimo_mensaje_direccion = new.direccion,
    ultimo_mensaje_en = new.creado_en,
    no_leidos = no_leidos + case when new.direccion = 'ENTRANTE' then 1 else 0 end,
    actualizado_en = now()
  where id = new.conversacion_id;
  return new;
end;
$$;
create trigger actualizar_resumen_conversacion
after insert on public.mensajes_whatsapp for each row
execute function public.actualizar_resumen_conversacion_whatsapp();

do $$ begin
  if not exists(select 1 from pg_publication_tables where pubname = 'supabase_realtime'
    and schemaname = 'public' and tablename = 'conversaciones_whatsapp') then
    alter publication supabase_realtime add table public.conversaciones_whatsapp;
  end if;
  if not exists(select 1 from pg_publication_tables where pubname = 'supabase_realtime'
    and schemaname = 'public' and tablename = 'whatsapp_instancia_estado') then
    alter publication supabase_realtime add table public.whatsapp_instancia_estado;
  end if;
end $$;

revoke all on function public.conversacion_whatsapp_json(public.conversaciones_whatsapp),
  public.listar_conversaciones_whatsapp(text), public.listar_mensajes_conversacion(bigint),
  public.marcar_conversacion_leida(bigint), public.reintentar_mensaje_whatsapp(bigint) from public;
grant execute on function public.listar_conversaciones_whatsapp(text),
  public.listar_mensajes_conversacion(bigint), public.marcar_conversacion_leida(bigint),
  public.reintentar_mensaje_whatsapp(bigint) to authenticated;
