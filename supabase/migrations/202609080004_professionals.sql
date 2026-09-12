-- Fase 5: el modelo real no tiene tabla profesionales; son usuarios con rol ODONTOLOGO.
create or replace function public.listar_profesionales()
returns table(id bigint, full_name text)
language sql stable security definer set search_path = '' as $$
  select distinct u.id, u.nombre_completo::text
  from public.usuarios u
  join public.usuarios_roles ur on ur.usuario_id = u.id
  join public.roles r on r.id = ur.rol_id
  where public.has_permission('CITA_LEER')
    and r.codigo = 'ODONTOLOGO' and r.activo and u.activo and not u.bloqueado
  order by u.nombre_completo::text
$$;

revoke all on function public.listar_profesionales() from public;
grant execute on function public.listar_profesionales() to authenticated;
