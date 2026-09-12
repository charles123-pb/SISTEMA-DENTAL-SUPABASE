create or replace function public.plan_json(item public.planes_tratamiento) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',item.id,'patientId',item.paciente_id,
  'patientName',concat_ws(' ',p.nombres,p.apellido_paterno,p.apellido_materno),'encounterId',item.atencion_id,
  'code',item.codigo,'status',item.estado,'discount',item.descuento,'subtotal',item.subtotal,'total',item.total,
  'observations',item.observaciones,'patientAccepted',item.aceptado_por_paciente,'acceptedAt',item.aceptado_en,
  'createdAt',item.creado_en,'updatedAt',item.actualizado_en,'version',item.version,
  'items',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'serviceId',s.id,'serviceName',s.nombre,
    'tooth',i.pieza,'description',i.descripcion,'quantity',i.cantidad,'unitPrice',i.precio_unitario,
    'subtotal',i.cantidad*i.precio_unitario,'sessions',i.sesiones,'status',i.estado,'version',i.version,
    'evolutions',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'itemId',e.plan_item_id,'encounterId',e.atencion_id,
      'date',e.fecha,'procedure',e.procedimiento_realizado,'observations',e.observaciones,'nextSession',e.proxima_sesion,
      'approvedBy',e.aprobado_por) order by e.fecha desc) from public.evoluciones_tratamiento e where e.plan_item_id=i.id),'[]'::jsonb)) order by i.id)
    from public.plan_tratamiento_items i join public.servicios s on s.id=i.servicio_id where i.plan_id=item.id and i.activo),'[]'::jsonb))
 from public.pacientes p where p.id=item.paciente_id
$$;

create or replace function public.listar_planes(paciente_id bigint default null, atencion_id bigint default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$ declare result jsonb; begin
 if not(public.has_permission('TRATAMIENTO_LEER') or public.has_permission('FINANZA_LEER')) then raise exception using errcode='42501',message='No autorizado para consultar tratamientos';end if;
 if paciente_id is null and atencion_id is null then raise exception using errcode='P0001',message='Indique paciente o atención';end if;
 select coalesce(jsonb_agg(public.plan_json(p) order by p.creado_en desc),'[]'::jsonb) into result from public.planes_tratamiento p
 where (listar_planes.paciente_id is not null and p.paciente_id=listar_planes.paciente_id) or
 (listar_planes.paciente_id is null and p.atencion_id=listar_planes.atencion_id);return result;end $$;

create or replace function public.obtener_plan(plan_id bigint) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;begin if not(public.has_permission('TRATAMIENTO_LEER') or public.has_permission('FINANZA_LEER'))then raise exception using errcode='42501',message='No autorizado para consultar tratamientos';end if;
select public.plan_json(p) into result from public.planes_tratamiento p where p.id=plan_id;if result is null then raise exception using errcode='P0001',message='Plan no encontrado';end if;return result;end $$;

create or replace function public.recalcular_plan(plan_id bigint,actor_id bigint) returns void language plpgsql security definer set search_path='' as $$
declare amount numeric(12,2);begin select coalesce(sum(i.cantidad*i.precio_unitario),0) into amount from public.plan_tratamiento_items i where i.plan_id=recalcular_plan.plan_id and i.activo;
update public.planes_tratamiento set subtotal=amount,descuento=least(descuento,amount),total=amount-least(descuento,amount),actualizado_por=actor_id,actualizado_en=now(),version=version+1 where id=plan_id;end $$;

create or replace function public.gestionar_plan(accion text,datos jsonb) returns bigint language plpgsql security definer set search_path='' as $$
declare actor_id bigint:=public.current_app_user_id();pid bigint:=nullif(datos->>'planId','')::bigint;iid bigint:=nullif(datos->>'itemId','')::bigint;
 p public.planes_tratamiento;i public.plan_tratamiento_items;s public.servicios;new_id bigint;target text;accepted boolean;subtotal_value numeric(12,2);
begin
 if actor_id is null or not public.has_permission('TRATAMIENTO_ESCRIBIR') or not exists(select 1 from public.usuarios_roles ur join public.roles r on r.id=ur.rol_id where ur.usuario_id=actor_id and r.codigo='ODONTOLOGO' and r.activo) then raise exception using errcode='42501',message='La acción requiere un odontólogo';end if;
 if accion='CREAR' then
  if not exists(select 1 from public.pacientes x where x.id=(datos->>'patientId')::bigint and x.activo)then raise exception using errcode='P0001',message='El paciente está inactivo';end if;
  if nullif(datos->>'encounterId','') is not null and not exists(select 1 from public.atenciones_clinicas a where a.id=(datos->>'encounterId')::bigint and a.paciente_id=(datos->>'patientId')::bigint)then raise exception using errcode='P0001',message='La atención no pertenece al paciente del plan';end if;
  if nullif(datos->>'encounterId','') is not null then select id into new_id from public.planes_tratamiento where atencion_id=(datos->>'encounterId')::bigint order by creado_en desc limit 1;if new_id is not null then return new_id;end if;end if;
  insert into public.planes_tratamiento(paciente_id,atencion_id,codigo,observaciones,creado_por,actualizado_por)values((datos->>'patientId')::bigint,nullif(datos->>'encounterId','')::bigint,'PT-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),nullif(btrim(datos->>'observations'),''),actor_id,actor_id)returning id into new_id;pid:=new_id;
 elsif accion='AGREGAR_ITEM' then
  select * into p from public.planes_tratamiento where id=pid for update;if not found then raise exception using errcode='P0001',message='Plan no encontrado';end if;if p.estado<>'BORRADOR'then raise exception using errcode='P0001',message='El plan ya no está en borrador';end if;
  select * into s from public.servicios where id=(datos->>'serviceId')::bigint and activo;if not found then raise exception using errcode='P0001',message='Servicio no encontrado';end if;
  insert into public.plan_tratamiento_items(plan_id,servicio_id,pieza,descripcion,cantidad,precio_unitario,sesiones,creado_por,actualizado_por)values(pid,s.id,nullif(btrim(datos->>'tooth'),''),coalesce(nullif(btrim(datos->>'description'),''),s.nombre),(datos->>'quantity')::integer,(datos->>'unitPrice')::numeric,(datos->>'sessions')::integer,actor_id,actor_id);perform public.recalcular_plan(pid,actor_id);
 elsif accion='RETIRAR_ITEM' then
  select * into p from public.planes_tratamiento where id=pid for update;if p.estado<>'BORRADOR'then raise exception using errcode='P0001',message='El plan ya no está en borrador';end if;
  update public.plan_tratamiento_items set activo=false,actualizado_por=actor_id,actualizado_en=now(),version=version+1 where id=iid and plan_id=pid and activo and version=(datos->>'version')::bigint;if not found then raise exception using errcode='P0001',message='El procedimiento fue modificado';end if;perform public.recalcular_plan(pid,actor_id);
 elsif accion='REVISAR' then
  select * into p from public.planes_tratamiento where id=pid for update;if not found or p.estado<>'BORRADOR'then raise exception using errcode='P0001',message='El plan ya no está en borrador';end if;if p.version<>(datos->>'version')::bigint then raise exception using errcode='P0001',message='El plan fue modificado por otro usuario';end if;
  subtotal_value:=(datos->>'discount')::numeric;if subtotal_value>p.subtotal then raise exception using errcode='P0001',message='El descuento no puede superar el subtotal';end if;
  update public.planes_tratamiento set descuento=subtotal_value,total=subtotal-subtotal_value,observaciones=nullif(btrim(datos->>'observations'),''),actualizado_por=actor_id,actualizado_en=now(),version=version+1 where id=pid;
 elsif accion='ESTADO' then
  select * into p from public.planes_tratamiento where id=pid for update;if not found then raise exception using errcode='P0001',message='Plan no encontrado';end if;if p.version<>(datos->>'version')::bigint then raise exception using errcode='P0001',message='El plan fue modificado por otro usuario';end if;target:=datos->>'status';accepted:=coalesce((datos->>'patientAcceptance')::boolean,false);
  if not((p.estado='BORRADOR'and target in('PRESENTADO','CANCELADO'))or(p.estado='PRESENTADO'and target in('ACEPTADO','RECHAZADO','CANCELADO'))or(p.estado='ACEPTADO'and target in('EN_PROCESO','CANCELADO'))or(p.estado='EN_PROCESO'and target in('COMPLETADO','CANCELADO')))then raise exception using errcode='P0001',message='Cambio de estado no permitido';end if;
  if target in('PRESENTADO','ACEPTADO')and not exists(select 1 from public.plan_tratamiento_items where plan_id=pid and activo)then raise exception using errcode='P0001',message='Agregue procedimientos antes de presentar o aceptar el plan';end if;
  if target='ACEPTADO'and not accepted then raise exception using errcode='P0001',message='Registre la aceptación expresa del paciente';end if;
  if target='COMPLETADO'and exists(select 1 from public.plan_tratamiento_items where plan_id=pid and activo and estado<>'COMPLETADO')then raise exception using errcode='P0001',message='Complete cada procedimiento antes de cerrar el plan';end if;
  update public.planes_tratamiento set estado=target,aceptado_por_paciente=case when target='ACEPTADO'then true else aceptado_por_paciente end,aceptado_en=case when target='ACEPTADO'then now()else aceptado_en end,actualizado_por=actor_id,actualizado_en=now(),version=version+1 where id=pid;
  if target='ACEPTADO'then update public.plan_tratamiento_items set estado='ACEPTADO',actualizado_por=actor_id,actualizado_en=now(),version=version+1 where plan_id=pid and activo;end if;
 elsif accion='ESTADO_ITEM' then
  select * into p from public.planes_tratamiento where id=pid for update;select * into i from public.plan_tratamiento_items where id=iid and plan_id=pid and activo for update;if not found then raise exception using errcode='P0001',message='Procedimiento no encontrado';end if;
  if i.version<>(datos->>'version')::bigint then raise exception using errcode='P0001',message='El procedimiento fue modificado';end if;if p.estado not in('ACEPTADO','EN_PROCESO')then raise exception using errcode='P0001',message='El plan debe estar aceptado';end if;target:=datos->>'status';if target not in('EN_PROCESO','COMPLETADO')then raise exception using errcode='P0001',message='Estado de procedimiento no permitido';end if;if target='COMPLETADO'and not exists(select 1 from public.evoluciones_tratamiento where plan_item_id=iid)then raise exception using errcode='P0001',message='Registre la evolución antes de completar el procedimiento';end if;
  update public.plan_tratamiento_items set estado=target,actualizado_por=actor_id,actualizado_en=now(),version=version+1 where id=iid;if target='EN_PROCESO'and p.estado='ACEPTADO'then update public.planes_tratamiento set estado='EN_PROCESO',actualizado_por=actor_id,actualizado_en=now(),version=version+1 where id=pid;end if;
 elsif accion='EVOLUCION' then
  select * into p from public.planes_tratamiento where id=pid for update;select * into i from public.plan_tratamiento_items where id=iid and plan_id=pid and activo for update;if p.estado not in('ACEPTADO','EN_PROCESO')then raise exception using errcode='P0001',message='El plan no está aceptado';end if;if i.estado in('COMPLETADO','CANCELADO')then raise exception using errcode='P0001',message='El procedimiento ya está cerrado';end if;
  if nullif(datos->>'encounterId','')is not null and not exists(select 1 from public.atenciones_clinicas a where a.id=(datos->>'encounterId')::bigint and a.paciente_id=p.paciente_id)then raise exception using errcode='P0001',message='La atención no pertenece al paciente del plan';end if;
  insert into public.evoluciones_tratamiento(plan_item_id,atencion_id,procedimiento_realizado,observaciones,proxima_sesion,aprobado_por)values(iid,nullif(datos->>'encounterId','')::bigint,btrim(datos->>'procedure'),nullif(btrim(datos->>'observations'),''),nullif(datos->>'nextSession','')::date,actor_id);update public.plan_tratamiento_items set estado='EN_PROCESO',actualizado_por=actor_id,actualizado_en=now(),version=version+1 where id=iid;if p.estado='ACEPTADO'then update public.planes_tratamiento set estado='EN_PROCESO',actualizado_por=actor_id,actualizado_en=now(),version=version+1 where id=pid;end if;
 else raise exception using errcode='P0001',message='Operación de tratamiento inválida';end if;
 perform public.registrar_auditoria(accion||'_PLAN','PLAN_TRATAMIENTO',pid::text,'Operación transaccional');return pid;
end $$;

revoke all on function public.plan_json(public.planes_tratamiento)from public;revoke all on function public.listar_planes(bigint,bigint)from public;revoke all on function public.obtener_plan(bigint)from public;revoke all on function public.recalcular_plan(bigint,bigint)from public;revoke all on function public.gestionar_plan(text,jsonb)from public;
grant execute on function public.listar_planes(bigint,bigint)to authenticated;grant execute on function public.obtener_plan(bigint)to authenticated;grant execute on function public.gestionar_plan(text,jsonb)to authenticated;
