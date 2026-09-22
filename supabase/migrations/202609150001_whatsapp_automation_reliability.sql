-- Identidad de cada aviso y horario al que corresponde. No modifica el historial anterior.
alter table public.mensajes_whatsapp drop constraint chk_mensaje_tipo;
alter table public.mensajes_whatsapp add constraint chk_mensaje_tipo check(tipo in (
  'ENTRANTE','CITA_CONFIRMACION','CITA_RECORDATORIO','POSTCONSULTA','MANUAL',
  'CITA_CANCELACION','CITA_REPROGRAMACION','CITA_CONFIRMADA','CITA_RECORDATORIO_2H'
));
alter table public.mensajes_whatsapp add column automatizacion_clave text;
alter table public.mensajes_whatsapp add column cita_inicio_original timestamptz;
alter table public.mensajes_whatsapp add column cita_agenda_revision bigint;
alter table public.citas add column whatsapp_agenda_revision bigint not null default 0;
create or replace function public.versionar_agenda_whatsapp() returns trigger
language plpgsql set search_path = '' as $$
begin
  if old.inicio is distinct from new.inicio or old.fin is distinct from new.fin then
    new.whatsapp_agenda_revision := old.whatsapp_agenda_revision + 1;
  end if;
  return new;
end;
$$;
create trigger versionar_agenda_whatsapp before update of inicio,fin on public.citas
for each row execute function public.versionar_agenda_whatsapp();
revoke all on function public.versionar_agenda_whatsapp() from public, anon, authenticated;
create unique index mensajes_automatizacion_clave_unique
  on public.mensajes_whatsapp(automatizacion_clave) where automatizacion_clave is not null;

create or replace function public.identificar_automatizacion_whatsapp() returns trigger
language plpgsql security definer set search_path = '' as $$
declare cita public.citas;
begin
  if new.direccion <> 'SALIENTE' or new.cita_id is null or new.tipo not like 'CITA_%' then return new; end if;
  select * into cita from public.citas where id = new.cita_id;
  new.cita_inicio_original := cita.inicio;
  new.cita_agenda_revision := cita.whatsapp_agenda_revision;
  new.max_intentos := greatest(new.max_intentos, 4);
  new.automatizacion_clave := concat(cita.id, ':', new.tipo, ':', cita.whatsapp_agenda_revision, ':', extract(epoch from cita.inicio),
    case when new.tipo in ('CITA_CANCELACION','CITA_REPROGRAMACION','CITA_CONFIRMADA')
      then ':' || cita.version::text else '' end);
  -- Serializa también las inserciones concurrentes del mismo aviso.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.automatizacion_clave, 0));
  if exists(select 1 from public.mensajes_whatsapp where automatizacion_clave = new.automatizacion_clave) then
    return null;
  end if;
  return new;
end;
$$;
create trigger identificar_automatizacion_whatsapp before insert on public.mensajes_whatsapp
for each row execute function public.identificar_automatizacion_whatsapp();

create or replace function public.validar_envio_whatsapp(mensaje_id bigint) returns text
language plpgsql security definer set search_path = '' as $$
declare m public.mensajes_whatsapp; p public.pacientes; c public.conversaciones_whatsapp; a public.citas; telefono text;
begin
  select * into m from public.mensajes_whatsapp where id = mensaje_id;
  if not found or m.direccion <> 'SALIENTE' or m.estado <> 'EN_PROCESO' then
    raise exception 'El mensaje no está reservado para envío';
  end if;
  select * into p from public.pacientes where id = m.paciente_id;
  if not found or not p.activo or not p.whatsapp_autorizado then
    raise exception 'Paciente inactivo o sin autorización vigente para WhatsApp';
  end if;
  telefono := public.normalizar_telefono_whatsapp(p.celular);
  if telefono !~ '^[1-9][0-9]{9,14}$' or not public.telefono_whatsapp_es_unico(p.id, telefono) then
    raise exception 'Celular inválido o compartido por varios pacientes; revise la ficha';
  end if;
  select * into c from public.conversaciones_whatsapp where id = m.conversacion_id;
  if not found or c.estado = 'CERRADA' or c.paciente_id is distinct from p.id
    or public.normalizar_telefono_whatsapp(c.telefono) <> telefono then
    raise exception 'La conversación no corresponde al celular actual del paciente';
  end if;
  if m.cita_id is not null and m.tipo like 'CITA_%' then
    select * into a from public.citas where id = m.cita_id;
    if not found or a.paciente_id <> p.id then raise exception 'La cita no corresponde al paciente'; end if;
    if m.cita_inicio_original is not null and m.cita_inicio_original <> a.inicio then
      raise exception 'El aviso corresponde a un horario anterior; revise la cita';
    end if;
    if m.cita_agenda_revision is not null and m.cita_agenda_revision <> a.whatsapp_agenda_revision then
      raise exception 'El aviso pertenece a una programación anterior de la cita';
    end if;
    if m.cita_inicio_original is null and jsonb_array_length(m.parametros_plantilla) >= 3 and
      (m.parametros_plantilla->>1 <> to_char(a.inicio at time zone 'America/Lima', 'DD/MM/YYYY') or
       m.parametros_plantilla->>2 <> to_char(a.inicio at time zone 'America/Lima', 'HH24:MI')) then
      raise exception 'El aviso corresponde a un horario anterior';
    end if;
    if m.tipo = 'CITA_CANCELACION' then
      if a.estado <> 'CANCELADA' then raise exception 'La cita ya no está cancelada'; end if;
    elsif a.inicio <= now() or a.estado not in ('PENDIENTE_CONFIRMACION','CONFIRMADA') then
      raise exception 'La cita ya no requiere este aviso';
    end if;
    if m.tipo = 'CITA_CONFIRMACION' and a.estado <> 'PENDIENTE_CONFIRMACION' then
      raise exception 'La cita ya fue confirmada';
    end if;
  end if;
  return telefono;
end;
$$;
revoke all on function public.validar_envio_whatsapp(bigint) from public, anon, authenticated;
grant execute on function public.validar_envio_whatsapp(bigint) to service_role;
revoke all on function public.identificar_automatizacion_whatsapp() from public, anon, authenticated;

insert into public.plantillas_mensaje(codigo,nombre,categoria,contenido) values
('CITA_CANCELACION','Cita cancelada','CITAS','Hola {{paciente}}, su cita del {{fecha}} a las {{hora}} fue cancelada. Si desea otra cita, responda RESERVAR.'),
('CITA_REPROGRAMACION','Nuevo horario de cita','CITAS','Hola {{paciente}}, su cita ahora será el {{fecha}} a las {{hora}}. Responda CONFIRMO, CANCELAR o REPROGRAMAR.'),
('CITA_CONFIRMADA','Confirmación registrada','CITAS','Hola {{paciente}}, su cita del {{fecha}} a las {{hora}} está confirmada. Le esperamos en Dental Americana.'),
('CITA_RECORDATORIO_2H','Recordatorio cercano','CITAS','Hola {{paciente}}, le esperamos hoy a las {{hora}} en Dental Americana. Si necesita cambiar su cita, responda REPROGRAMAR.')
on conflict(codigo) do nothing;

create or replace function public.notificar_cambio_cita_whatsapp() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_codigo text; contenido text; p public.pacientes; conversacion bigint;
begin
  if tg_op = 'INSERT' then
    if new.estado = 'CONFIRMADA' and new.inicio > now() then v_codigo := 'CITA_CONFIRMADA';
    else return new; end if;
  else
  if old.inicio is distinct from new.inicio or old.fin is distinct from new.fin
    or (old.estado is distinct from new.estado and new.estado in ('CANCELADA','COMPLETADA','NO_ASISTIO','SOLICITUD_REPROGRAMACION')) then
    update public.mensajes_whatsapp set estado = 'CANCELADO', error_detalle = 'La cita cambió; aviso pendiente cancelado'
      where cita_id = new.id and estado = 'PENDIENTE' and tipo like 'CITA_%';
  end if;
  if new.estado = 'CANCELADA' and old.estado <> 'CANCELADA' then v_codigo := 'CITA_CANCELACION';
  elsif new.inicio > now() and new.estado in ('PENDIENTE_CONFIRMACION','CONFIRMADA') then
    if old.inicio is distinct from new.inicio or old.fin is distinct from new.fin then v_codigo := 'CITA_REPROGRAMACION';
    elsif new.estado = 'CONFIRMADA' and old.estado <> 'CONFIRMADA' then v_codigo := 'CITA_CONFIRMADA';
    end if;
  end if;
  if v_codigo is null then return new; end if;
  end if;
  select * into p from public.pacientes where id = new.paciente_id and activo and whatsapp_autorizado;
  if not found or public.normalizar_telefono_whatsapp(p.celular) !~ '^[1-9][0-9]{9,14}$'
    or not public.telefono_whatsapp_es_unico(p.id,p.celular) then return new; end if;
  select replace(replace(replace(t.contenido,'{{paciente}}',p.nombres),
    '{{fecha}}',to_char(new.inicio at time zone 'America/Lima','DD/MM/YYYY')),
    '{{hora}}',to_char(new.inicio at time zone 'America/Lima','HH24:MI')) into contenido
    from public.plantillas_mensaje t where t.codigo = v_codigo and t.activo;
  if contenido is null then return new; end if;
  conversacion := public.asegurar_conversacion_whatsapp(p.id,p.celular);
  insert into public.mensajes_whatsapp(conversacion_id,paciente_id,cita_id,direccion,contenido,estado,programado_para,tipo,plantilla_nombre)
    values(conversacion,p.id,new.id,'SALIENTE',contenido,'PENDIENTE',now(),v_codigo,v_codigo);
  return new;
end;
$$;
-- Se ejecuta después de mensajes_automaticos_cita y reemplaza su aviso antiguo al reprogramar.
create trigger notificar_cambio_cita_whatsapp after insert or update of inicio,fin,estado on public.citas
for each row execute function public.notificar_cambio_cita_whatsapp();
revoke all on function public.notificar_cambio_cita_whatsapp() from public, anon, authenticated;

create or replace function public.preparar_recordatorios_whatsapp() returns integer
language plpgsql security definer set search_path = '' as $$
declare a public.citas; p public.pacientes; v_codigo text; contenido text; conversacion bigint; total integer := 0; inserted integer;
begin
  for a in select * from public.citas where estado in ('PENDIENTE_CONFIRMACION','CONFIRMADA')
    and inicio > now() and inicio <= now() + interval '24 hours' order by inicio for update skip locked
  loop
    v_codigo := case when a.inicio <= now() + interval '2 hours' then 'CITA_RECORDATORIO_2H' else 'CITA_RECORDATORIO' end;
    -- Evita repetir los recordatorios anteriores a esta migración y acumular avisos de última hora.
    if exists(select 1 from public.mensajes_whatsapp m where m.cita_id = a.id and m.tipo = v_codigo
      and ((m.cita_inicio_original = a.inicio and m.cita_agenda_revision = a.whatsapp_agenda_revision)
        or (m.cita_inicio_original is null and a.recordatorio_programado and a.whatsapp_agenda_revision = 0))
      and m.estado <> 'CANCELADO') then continue; end if;
    if exists(select 1 from public.mensajes_whatsapp m where m.cita_id = a.id and m.direccion = 'SALIENTE'
      and m.tipo like 'CITA_%' and m.estado <> 'CANCELADO' and m.creado_en > now() - interval '2 hours') then continue; end if;
    select * into p from public.pacientes where id = a.paciente_id and activo and whatsapp_autorizado;
    if not found or public.normalizar_telefono_whatsapp(p.celular) !~ '^[1-9][0-9]{9,14}$'
      or not public.telefono_whatsapp_es_unico(p.id,p.celular) then continue; end if;
    select replace(replace(replace(t.contenido,'{{paciente}}',p.nombres),
      '{{fecha}}',to_char(a.inicio at time zone 'America/Lima','DD/MM/YYYY')),
      '{{hora}}',to_char(a.inicio at time zone 'America/Lima','HH24:MI')) into contenido
      from public.plantillas_mensaje t where t.codigo = v_codigo and t.activo;
    if contenido is null then continue; end if;
    conversacion := public.asegurar_conversacion_whatsapp(p.id,p.celular);
    insert into public.mensajes_whatsapp(conversacion_id,paciente_id,cita_id,direccion,contenido,estado,programado_para,tipo,plantilla_nombre)
      values(conversacion,p.id,a.id,'SALIENTE',contenido,'PENDIENTE',now(),v_codigo,v_codigo);
    get diagnostics inserted = row_count;
    total := total + inserted;
    if inserted > 0 then update public.citas set recordatorio_programado = true where id = a.id; end if;
  end loop;
  return total;
end;
$$;
revoke all on function public.preparar_recordatorios_whatsapp() from public, anon, authenticated;
grant execute on function public.preparar_recordatorios_whatsapp() to service_role;
