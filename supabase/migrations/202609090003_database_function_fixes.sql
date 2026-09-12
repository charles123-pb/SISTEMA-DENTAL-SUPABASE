-- Corrige referencias ambiguas detectadas por plpgsql_check y habilita la búsqueda normalizada.

create or replace function public.normalizar_busqueda(valor text)
returns text language sql immutable set search_path = '' as $$
  select translate(lower(coalesce(valor, '')),
    'áéíóúüñàèìòùäëïöüÁÉÍÓÚÜÑÀÈÌÒÙÄËÏÖÜ',
    'aeiouunaeiouaeiouaeiouunaeiouaeiou')
$$;

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
    nullif(btrim($1), '') is null
    or public.normalizar_busqueda(concat_ws(' ', p.nombres, p.apellido_paterno, p.apellido_materno))
       like '%' || public.normalizar_busqueda($1) || '%'
    or public.normalizar_busqueda(coalesce(c.nombre_contacto, ''))
       like '%' || public.normalizar_busqueda($1) || '%'
    or c.telefono like '%' || regexp_replace($1, '\D', '', 'g') || '%'
    or public.normalizar_busqueda(coalesce(c.ultimo_mensaje, ''))
       like '%' || public.normalizar_busqueda($1) || '%'
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
  if not exists(select 1 from public.conversaciones_whatsapp c where c.id = $1) then
    raise exception using errcode = 'P0001', message = 'Conversación no encontrada';
  end if;
  select coalesce(jsonb_agg(public.mensaje_json(m) order by m.creado_en), '[]'::jsonb)
  into resultado from public.mensajes_whatsapp m where m.conversacion_id = $1;
  return resultado;
end;
$$;

create or replace function public.retirar_hallazgo_odontograma(
  odontograma_id bigint, hallazgo_id bigint, version_actual bigint)
returns bigint language plpgsql security definer set search_path = '' as $$
declare actor_id bigint := public.current_app_user_id(); item public.odontogramas; affected integer;
begin
  if actor_id is null or not public.has_permission('CLINICA_ESCRIBIR') then
    raise exception using errcode='42501', message='No autorizado para retirar hallazgos';
  end if;
  item := public.validar_edicion_odontograma($1, actor_id);
  update public.odontograma_hallazgos h set activo=false, actualizado_por=actor_id,
    actualizado_en=now(), version=h.version+1
  where h.id=$2 and h.odontograma_id=$1 and h.activo and h.version=$3;
  get diagnostics affected=row_count;
  if affected=0 then
    raise exception using errcode='P0001', message='Hallazgo no encontrado o modificado por otro usuario';
  end if;
  update public.odontogramas o set actualizado_por=actor_id, actualizado_en=now(), version=o.version+1
  where o.id=$1 returning o.* into item;
  perform public.guardar_version_odontograma(item, 'Hallazgo retirado', actor_id);
  perform public.registrar_auditoria('RETIRAR_HALLAZGO_ODONTOGRAMA','ODONTOGRAMA',$1::text,'Hallazgo '||$2::text);
  return $1;
end;
$$;

create or replace function public.actualizar_configuracion(clave text, valor text, version_actual bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor bigint:=public.current_app_user_id(); item public.configuracion_sistema;
begin
  if actor is null or not public.has_permission('AJUSTE_ESCRIBIR') then
    raise exception using errcode='42501',message='No autorizado para modificar configuración';
  end if;
  update public.configuracion_sistema c set valor=btrim($2), actualizado_por=actor,
    actualizado_en=now(), version=c.version+1
  where c.clave=$1 and c.version=$3 returning c.* into item;
  if not found then
    raise exception using errcode='P0001',message='La configuración fue modificada o no existe';
  end if;
  perform public.registrar_auditoria('ACTUALIZAR_CONFIGURACION','CONFIGURACION',$1,'Parámetro actualizado');
  return jsonb_build_object('key',item.clave,'value',item.valor,'description',item.descripcion,
    'updatedBy',item.actualizado_por,'updatedAt',item.actualizado_en,'version',item.version);
end;
$$;

create or replace function public.cerrar_caja(caja_id bigint, monto_contado numeric,
  observacion text, version_actual bigint, confirmacion boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor bigint:=public.validar_finanza(); item public.sesiones_caja;
  cash_id bigint; expected numeric(12,2);
begin
  if $5 is not true then raise exception using errcode='P0001',message='Confirme el cierre de caja'; end if;
  select * into item from public.sesiones_caja s where s.id=$1 for update;
  if not found then raise exception using errcode='P0001',message='Caja no encontrada'; end if;
  if item.estado<>'ABIERTA' then raise exception using errcode='P0001',message='La caja ya está cerrada'; end if;
  if item.version<>$4 then raise exception using errcode='P0001',message='La caja fue modificada'; end if;
  select mp.id into cash_id from public.metodos_pago mp where mp.codigo='EFECTIVO';
  select item.monto_apertura+coalesce(sum(case when m.tipo='INGRESO' then m.monto else -m.monto end),0)
  into expected from public.movimientos_caja m where m.sesion_caja_id=$1 and m.metodo_pago_id=cash_id;
  update public.sesiones_caja s set estado='CERRADA', cerrada_por=actor, cerrada_en=now(),
    monto_esperado=expected, monto_contado=$2, diferencia=$2-expected,
    observacion_cierre=nullif(btrim($3),''), version=s.version+1
  where s.id=$1 returning s.* into item;
  perform public.registrar_auditoria('CERRAR_CAJA','FINANZAS',$1::text,'Diferencia '||item.diferencia);
  return public.caja_json(item);
end;
$$;

create or replace function public.auditar_descarga_archivo(paciente_id bigint, archivo_id bigint)
returns text language plpgsql security definer set search_path = '' as $$
declare object_path text;
begin
  if not(public.has_permission('PACIENTE_LEER')or public.has_permission('CLINICA_LEER')) then
    raise exception using errcode='42501',message='No autorizado para descargar archivos';
  end if;
  select a.ubicacion into object_path from public.paciente_archivos a
  where a.id=$2 and a.paciente_id=$1 and a.activo;
  if object_path is null then raise exception using errcode='P0001',message='Archivo no encontrado'; end if;
  perform public.registrar_auditoria('DESCARGAR_ARCHIVO_PACIENTE','PACIENTE',$1::text,'Archivo '||$2::text);
  return object_path;
end;
$$;
