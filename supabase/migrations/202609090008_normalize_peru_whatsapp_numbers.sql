-- WhatsApp/Evolution exige el número internacional. Para Perú, un celular
-- local de 9 dígitos se almacena como 51 + celular.
create or replace function public.normalizar_telefono_whatsapp(valor text)
returns text
language sql
immutable
set search_path = ''
as $$
  with limpio as (
    select regexp_replace(coalesce(valor, ''), '[^0-9]', '', 'g') as numero
  ), internacional as (
    select case when numero like '00%' then substr(numero, 3) else numero end as numero
    from limpio
  )
  select case
    when numero ~ '^9[0-9]{8}$' then '51' || numero
    else numero
  end
  from internacional
$$;

create or replace function public.normalizar_celular_paciente_whatsapp()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.celular is not null then
    new.celular := nullif(public.normalizar_telefono_whatsapp(new.celular), '');
  end if;
  return new;
end;
$$;

drop trigger if exists normalizar_celular_paciente_whatsapp on public.pacientes;
create trigger normalizar_celular_paciente_whatsapp
before insert or update of celular on public.pacientes
for each row execute function public.normalizar_celular_paciente_whatsapp();

-- Corrige pacientes ya registrados.
update public.pacientes
set celular = public.normalizar_telefono_whatsapp(celular)
where celular is not null
  and celular is distinct from public.normalizar_telefono_whatsapp(celular);

-- Corrige conversaciones abiertas cuando no existe otra conversación abierta
-- para el mismo número internacional. Las posibles duplicadas quedan intactas
-- para no mezclar historiales de pacientes distintos.
update public.conversaciones_whatsapp c
set telefono = public.normalizar_telefono_whatsapp(c.telefono),
    actualizado_en = now()
where c.estado <> 'CERRADA'
  and c.telefono is distinct from public.normalizar_telefono_whatsapp(c.telefono)
  and not exists (
    select 1
    from public.conversaciones_whatsapp otra
    where otra.id <> c.id
      and otra.estado <> 'CERRADA'
      and otra.telefono = public.normalizar_telefono_whatsapp(c.telefono)
  );

-- Las funciones de automatización y del webhook comparan números ya
-- normalizados; esta versión también protege llamadas con formato local.
create or replace function public.telefono_whatsapp_es_unico(
  p_paciente_id bigint, p_telefono text
) returns boolean
language sql stable security definer set search_path = '' as $$
  select count(*) = 1 and max(id) = p_paciente_id
  from public.pacientes
  where activo and celular is not null
    and public.normalizar_telefono_whatsapp(celular)
      = public.normalizar_telefono_whatsapp(p_telefono)
$$;

create or replace function public.asegurar_conversacion_whatsapp(
  p_paciente_id bigint, p_telefono text
) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_telefono text := public.normalizar_telefono_whatsapp(p_telefono);
begin
  select id into v_id
  from public.conversaciones_whatsapp
  where telefono = v_telefono and estado <> 'CERRADA'
  order by id desc limit 1 for update;

  if v_id is null then
    insert into public.conversaciones_whatsapp(paciente_id, telefono, ultimo_mensaje_en)
    values (p_paciente_id, v_telefono, now())
    returning id into v_id;
  else
    update public.conversaciones_whatsapp
    set paciente_id = coalesce(paciente_id, p_paciente_id), actualizado_en = now()
    where id = v_id;
  end if;
  return v_id;
end;
$$;

revoke all on function public.normalizar_telefono_whatsapp(text),
  public.normalizar_celular_paciente_whatsapp(),
  public.telefono_whatsapp_es_unico(bigint, text),
  public.asegurar_conversacion_whatsapp(bigint, text) from public;
grant execute on function public.normalizar_telefono_whatsapp(text) to authenticated, service_role;
