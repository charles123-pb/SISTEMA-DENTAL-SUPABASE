-- Normalización y protección contra duplicados en solicitudes públicas de cita.

create or replace function public.normalizar_celular_solicitud_cita()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.celular := public.normalizar_telefono_whatsapp(new.celular);
  return new;
end;
$$;

drop trigger if exists normalizar_celular_solicitud_cita on public.solicitudes_cita_web;
create trigger normalizar_celular_solicitud_cita
before insert or update of celular on public.solicitudes_cita_web
for each row execute function public.normalizar_celular_solicitud_cita();

update public.solicitudes_cita_web
set celular = public.normalizar_telefono_whatsapp(celular),
    actualizado_en = now()
where celular is distinct from public.normalizar_telefono_whatsapp(celular);

create or replace function public.crear_solicitud_cita(datos jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  item public.solicitudes_cita_web;
  mobile_value text;
  shift_value text;
  full_name_value text;
  service_value text;
  document_value text;
  email_value text;
  message_value text;
  preferred_date_value date;
begin
  if datos is null or jsonb_typeof(datos) <> 'object' then
    raise exception using errcode = 'P0001', message = 'Los datos de la solicitud no son válidos';
  end if;
  if coalesce(datos ->> 'privacyConsent', 'false') <> 'true' then
    raise exception using errcode = 'P0001', message = 'Debe aceptar el tratamiento de datos para solicitar contacto';
  end if;

  full_name_value := regexp_replace(btrim(coalesce(datos ->> 'fullName', '')), '\s+', ' ', 'g');
  service_value := btrim(coalesce(datos ->> 'service', ''));
  document_value := nullif(upper(btrim(coalesce(datos ->> 'documentNumber', ''))), '');
  email_value := nullif(lower(btrim(coalesce(datos ->> 'email', ''))), '');
  message_value := nullif(btrim(coalesce(datos ->> 'message', '')), '');
  mobile_value := public.normalizar_telefono_whatsapp(datos ->> 'mobile');
  shift_value := coalesce(nullif(datos ->> 'preferredShift', ''), 'INDIFERENTE');

  if char_length(full_name_value) not between 3 and 150 then
    raise exception using errcode = 'P0001', message = 'Ingrese un nombre válido';
  end if;
  if char_length(service_value) not between 2 and 120 then
    raise exception using errcode = 'P0001', message = 'Ingrese el servicio solicitado';
  end if;
  if mobile_value !~ '^[0-9]{10,15}$' then
    raise exception using errcode = 'P0001', message = 'Celular inválido';
  end if;
  if document_value is not null and char_length(document_value) > 20 then
    raise exception using errcode = 'P0001', message = 'Documento inválido';
  end if;
  if email_value is not null and (
    char_length(email_value) > 150 or email_value !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
  ) then
    raise exception using errcode = 'P0001', message = 'Correo electrónico inválido';
  end if;
  if message_value is not null and char_length(message_value) > 800 then
    raise exception using errcode = 'P0001', message = 'El mensaje supera los 800 caracteres';
  end if;
  if shift_value not in ('MANANA', 'TARDE', 'INDIFERENTE') then
    raise exception using errcode = 'P0001', message = 'Turno preferido inválido';
  end if;

  begin
    preferred_date_value := nullif(datos ->> 'preferredDate', '')::date;
  exception when invalid_datetime_format or datetime_field_overflow then
    raise exception using errcode = 'P0001', message = 'Fecha preferida inválida';
  end;
  if preferred_date_value < current_date then
    raise exception using errcode = 'P0001', message = 'La fecha preferida no puede estar en el pasado';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('solicitud-cita:' || mobile_value, 0)
  );
  if exists (
    select 1 from public.solicitudes_cita_web s
    where s.celular = mobile_value
      and s.estado = 'PENDIENTE'
      and s.creado_en > now() - interval '2 minutes'
  ) then
    raise exception using errcode = 'P0001',
      message = 'Ya recibimos una solicitud con este celular. Espere un momento antes de enviarla nuevamente';
  end if;

  insert into public.solicitudes_cita_web(
    nombre_completo, numero_documento, celular, email, servicio,
    fecha_preferida, turno_preferido, mensaje, consentimiento_privacidad
  ) values (
    full_name_value, document_value, mobile_value, email_value, service_value,
    preferred_date_value, shift_value, message_value, true
  ) returning * into item;

  insert into public.auditoria(
    usuario_id, username, accion, recurso, recurso_id, resultado, detalle
  ) values (
    null, null, 'CREAR_SOLICITUD_WEB', 'SOLICITUD_CITA', item.id::text,
    'EXITO', 'Solicitud pública recibida'
  );
  return public.solicitud_cita_json(item);
end;
$$;

revoke all on function public.normalizar_celular_solicitud_cita() from public;
revoke all on function public.crear_solicitud_cita(jsonb) from public;
grant execute on function public.crear_solicitud_cita(jsonb) to anon, authenticated;
