-- Paginación por cursor estable para la bandeja, sin devolver historiales completos.
create index if not exists idx_mensaje_whatsapp_conversacion_cursor
  on public.mensajes_whatsapp(conversacion_id, creado_en desc, id desc);

create index if not exists idx_conversaciones_whatsapp_cursor
  on public.conversaciones_whatsapp(ultimo_mensaje_en desc, id desc)
  where estado <> 'CERRADA';

create function public.listar_conversaciones_whatsapp_paginadas(
  busqueda text default null, antes_de timestamptz default null,
  antes_id bigint default null, tamano integer default 30)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare resultado jsonb; limite integer := least(greatest(coalesce(tamano, 30), 1), 100);
begin
  if not public.has_permission('SEGUIMIENTO_LEER') then
    raise exception using errcode = '42501', message = 'No autorizado para consultar conversaciones';
  end if;
  if (antes_de is null) <> (antes_id is null) then
    raise exception using errcode = '22023', message = 'Cursor de conversación incompleto';
  end if;
  with pagina as (
    select c as item, coalesce(c.ultimo_mensaje_en, c.creado_en) as orden
    from public.conversaciones_whatsapp c
    left join public.pacientes p on p.id = c.paciente_id
    where c.estado <> 'CERRADA'
      and (antes_de is null or (coalesce(c.ultimo_mensaje_en, c.creado_en), c.id) < (antes_de, antes_id))
      and (
        nullif(btrim(busqueda), '') is null
        or public.normalizar_busqueda(concat_ws(' ', p.nombres, p.apellido_paterno, p.apellido_materno))
          like '%' || public.normalizar_busqueda(busqueda) || '%'
        or public.normalizar_busqueda(coalesce(c.nombre_contacto, ''))
          like '%' || public.normalizar_busqueda(busqueda) || '%'
        or c.telefono like '%' || regexp_replace(busqueda, '\D', '', 'g') || '%'
        or public.normalizar_busqueda(coalesce(c.ultimo_mensaje, ''))
          like '%' || public.normalizar_busqueda(busqueda) || '%'
      )
    order by orden desc, c.id desc limit limite + 1
  ), numerada as (
    select item, orden, row_number() over (order by orden desc, (item).id desc) as fila
    from pagina
  )
  select jsonb_build_object(
    'items', coalesce(jsonb_agg(
      public.conversacion_whatsapp_json(item) || jsonb_build_object('lastMessageAt', orden)
      order by orden desc, (item).id desc
    ) filter (where fila <= limite), '[]'::jsonb),
    'hasMore', count(*) > limite
  ) into resultado from numerada;
  return resultado;
end;
$$;

create function public.listar_mensajes_conversacion_paginados(
  conversacion_id bigint, antes_de timestamptz default null,
  antes_id bigint default null, tamano integer default 50)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare resultado jsonb; limite integer := least(greatest(coalesce(tamano, 50), 1), 100);
begin
  if not public.has_permission('SEGUIMIENTO_LEER') then
    raise exception using errcode = '42501', message = 'No autorizado para consultar mensajes';
  end if;
  if not exists(select 1 from public.conversaciones_whatsapp c where c.id = conversacion_id) then
    raise exception using errcode = 'P0001', message = 'Conversación no encontrada';
  end if;
  if (antes_de is null) <> (antes_id is null) then
    raise exception using errcode = '22023', message = 'Cursor de mensaje incompleto';
  end if;
  with pagina as (
    select m as item, m.creado_en as orden
    from public.mensajes_whatsapp m
    where m.conversacion_id = $1
      and (antes_de is null or (m.creado_en, m.id) < (antes_de, antes_id))
    order by m.creado_en desc, m.id desc limit limite + 1
  ), numerada as (
    select item, orden, row_number() over (order by orden desc, (item).id desc) as fila
    from pagina
  )
  select jsonb_build_object(
    'items', coalesce(jsonb_agg(public.mensaje_json(item)
      order by orden, (item).id) filter (where fila <= limite), '[]'::jsonb),
    'hasMore', count(*) > limite
  ) into resultado from numerada;
  return resultado;
end;
$$;

revoke all on function public.listar_conversaciones_whatsapp_paginadas(text, timestamptz, bigint, integer),
  public.listar_mensajes_conversacion_paginados(bigint, timestamptz, bigint, integer) from public;
grant execute on function public.listar_conversaciones_whatsapp_paginadas(text, timestamptz, bigint, integer),
  public.listar_mensajes_conversacion_paginados(bigint, timestamptz, bigint, integer) to authenticated;
