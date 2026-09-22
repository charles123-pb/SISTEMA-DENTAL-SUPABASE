-- Una búsqueda de texto sin dígitos no debe coincidir con todos los teléfonos ('%%').
create or replace function public.listar_conversaciones_whatsapp_paginadas(
  busqueda text default null, antes_de timestamptz default null,
  antes_id bigint default null, tamano integer default 30)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  resultado jsonb;
  limite integer := least(greatest(coalesce(tamano, 30), 1), 100);
  telefono_busqueda text := nullif(regexp_replace(coalesce(busqueda, ''), '[^0-9]', '', 'g'), '');
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
        or (telefono_busqueda is not null and c.telefono like '%' || telefono_busqueda || '%')
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
