-- Protección de acceso: bloqueo temporal, contador atómico y auditoría de intentos.

alter table public.usuarios
  add column if not exists bloqueado_hasta timestamptz,
  add column if not exists ultimo_intento_fallido timestamptz;

alter table public.usuarios
  add constraint chk_usuario_intentos_fallidos
  check (intentos_fallidos between 0 and 100) not valid;

alter table public.usuarios
  validate constraint chk_usuario_intentos_fallidos;

create or replace function public.registrar_intento_login(
  p_usuario_id bigint,
  p_exitoso boolean,
  p_ip text default null,
  p_user_agent text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario public.usuarios;
  v_intentos integer;
  v_bloqueado_hasta timestamptz;
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'Operación reservada al servicio de autenticación';
  end if;

  select * into v_usuario
  from public.usuarios
  where id = p_usuario_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'Usuario no encontrado';
  end if;

  if p_exitoso then
    update public.usuarios
    set intentos_fallidos = 0,
        bloqueado_hasta = null,
        ultimo_acceso = now(),
        actualizado_en = now()
    where id = p_usuario_id;
    v_intentos := 0;
    v_bloqueado_hasta := null;
  else
    v_intentos := least(v_usuario.intentos_fallidos + 1, 100);
    v_bloqueado_hasta := case
      when v_intentos >= 5 then now() + interval '15 minutes'
      else v_usuario.bloqueado_hasta
    end;
    update public.usuarios
    set intentos_fallidos = v_intentos,
        ultimo_intento_fallido = now(),
        bloqueado_hasta = v_bloqueado_hasta,
        actualizado_en = now()
    where id = p_usuario_id;
  end if;

  insert into public.auditoria(
    usuario_id, username, accion, recurso, recurso_id, resultado, ip, user_agent, detalle
  ) values (
    v_usuario.id,
    v_usuario.username,
    case when p_exitoso then 'LOGIN_EXITOSO' else 'LOGIN_FALLIDO' end,
    'AUTENTICACION',
    v_usuario.id::text,
    case when p_exitoso then 'EXITO' else 'ERROR' end,
    left(nullif(btrim(p_ip), ''), 64),
    left(nullif(btrim(p_user_agent), ''), 300),
    case
      when not p_exitoso and v_bloqueado_hasta is not null
        then 'Acceso bloqueado temporalmente por intentos fallidos'
      else null
    end
  );

  return jsonb_build_object(
    'attempts', v_intentos,
    'lockedUntil', v_bloqueado_hasta
  );
end;
$$;

revoke all on function public.registrar_intento_login(bigint, boolean, text, text)
  from public, anon, authenticated;
grant execute on function public.registrar_intento_login(bigint, boolean, text, text)
  to service_role;

create index if not exists idx_usuario_bloqueo_temporal
  on public.usuarios(bloqueado_hasta)
  where bloqueado_hasta is not null;
