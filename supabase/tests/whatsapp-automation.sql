-- Ejecutar después de las migraciones en una base de pruebas vacía.
begin;
create function pg_temp.assert_true(ok boolean, message text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAIL: %', message; end if; end $$;

do $$
declare u bigint; p bigint; a bigint; b bigint; conversation bigint; message_id bigint; count_before bigint; rejected boolean;
begin
  perform pg_temp.assert_true(public.clasificar_respuesta_whatsapp('CONFIRMO') = 'CONFIRMAR', 'Confirmación explícita');
  perform pg_temp.assert_true(public.clasificar_respuesta_whatsapp('Cancelar mi cita.') = 'CANCELAR', 'Cancelación explícita');
  perform pg_temp.assert_true(public.clasificar_respuesta_whatsapp('No quiero cancelar') = 'NO_ENTENDIDO', 'No cancelar por coincidencia parcial');
  perform pg_temp.assert_true(public.clasificar_respuesta_whatsapp('¿Cómo puedo confirmar?') = 'NO_ENTENDIDO', 'Las preguntas requieren revisión');
  perform pg_temp.assert_true(public.clasificar_respuesta_whatsapp('QUIERO OTRA FECHA') = 'REPROGRAMAR', 'Cambio de fecha');
  perform pg_temp.assert_true(public.clasificar_respuesta_whatsapp('HUMANO') = 'NO_ENTENDIDO', 'Derivación humana');
  insert into public.usuarios(username,nombre_completo) values('automation-test','Prueba') returning id into u;
  insert into public.pacientes(numero_historia,tipo_documento,nombres,apellido_paterno,fecha_nacimiento,sexo,
    celular,creado_por,actualizado_por,whatsapp_autorizado,whatsapp_autorizado_en,whatsapp_autorizado_por)
    values('TEST-AUTO','SIN_DOCUMENTO','Prueba','Automatización','1990-01-01','FEMENINO',
    '999111222',u,u,true,now(),u) returning id into p;
  insert into public.citas(paciente_id,profesional_id,tipo_cita_id,inicio,fin,motivo,creado_por,actualizado_por)
    values(p,u,1,now()+interval '23 hours',now()+interval '23 hours 30 minutes','Prueba',u,u) returning id into a;
  select id,conversacion_id into message_id,conversation from public.mensajes_whatsapp where cita_id=a and tipo='CITA_CONFIRMACION';
  perform pg_temp.assert_true(message_id is not null, 'Crear cita programa confirmación');
  perform pg_temp.assert_true((select max_intentos=4 from public.mensajes_whatsapp where id=message_id), 'Avisos nuevos permiten tres reintentos limitados');
  insert into public.mensajes_whatsapp(conversacion_id,paciente_id,cita_id,direccion,contenido,estado,tipo)
    values(conversation,p,a,'SALIENTE','Duplicado','PENDIENTE','CITA_CONFIRMACION');
  perform pg_temp.assert_true((select count(*)=1 from public.mensajes_whatsapp where cita_id=a and tipo='CITA_CONFIRMACION'), 'No duplicar automatización');
  update public.mensajes_whatsapp set estado='EN_PROCESO' where id=message_id;
  perform pg_temp.assert_true(public.validar_envio_whatsapp(message_id)='51999111222', 'Validar destinatario actual');
  update public.pacientes set whatsapp_autorizado=false where id=p;
  rejected := false;
  begin perform public.validar_envio_whatsapp(message_id); exception when others then rejected:=true; end;
  perform pg_temp.assert_true(rejected,'Revocación bloquea un mensaje ya programado');
  update public.pacientes set whatsapp_autorizado=true,celular='999111223' where id=p;
  rejected := false;
  begin perform public.validar_envio_whatsapp(message_id); exception when others then rejected:=true; end;
  perform pg_temp.assert_true(rejected,'Cambio de celular bloquea el destino antiguo');
  update public.pacientes set celular='999111222' where id=p;
  update public.mensajes_whatsapp set estado='ENVIADO',proveedor_id='out-test',creado_en=now()-interval '3 hours' where id=message_id;
  perform public.preparar_recordatorios_whatsapp();
  perform public.preparar_recordatorios_whatsapp();
  perform pg_temp.assert_true((select count(*)=1 from public.mensajes_whatsapp where cita_id=a and tipo='CITA_RECORDATORIO'), 'Recordatorio 24h único');
  perform public.registrar_evento_whatsapp(jsonb_build_object('phone','999111222','content','No quiero cancelar','providerId','in-1'));
  perform pg_temp.assert_true((select estado='PENDIENTE_CONFIRMACION' from public.citas where id=a), 'Negación no cambia la cita');
  perform public.registrar_evento_whatsapp(jsonb_build_object('phone','999111222','content','CONFIRMO','providerId','in-2'));
  perform pg_temp.assert_true((select estado='CONFIRMADA' from public.citas where id=a), 'Respuesta confirma en agenda');
  select count(*) into count_before from public.mensajes_whatsapp;
  perform public.registrar_evento_whatsapp(jsonb_build_object('phone','999111222','content','CONFIRMO','providerId','in-2'));
  perform pg_temp.assert_true((select count(*)=count_before from public.mensajes_whatsapp), 'Webhook repetido no repite acciones');
  perform pg_temp.assert_true((select count(*)=1 from public.mensajes_whatsapp where cita_id=a and tipo='CITA_CONFIRMADA'), 'Acuse de confirmación');
  insert into public.citas(paciente_id,profesional_id,tipo_cita_id,inicio,fin,motivo,creado_por,actualizado_por)
    values(p,u,1,now()+interval '3 days',now()+interval '3 days 30 minutes','Prueba',u,u) returning id into b;
  perform public.registrar_evento_whatsapp(jsonb_build_object('phone','999111222','content','REPROGRAMAR','providerId','in-3'));
  perform pg_temp.assert_true((select estado='CONFIRMADA' from public.citas where id=a), 'Varias citas requieren contexto');
  perform public.registrar_evento_whatsapp(jsonb_build_object('phone','999111222','content','REPROGRAMAR','providerId','in-4','contextProviderId','out-test'));
  perform pg_temp.assert_true((select estado='SOLICITUD_REPROGRAMACION' from public.citas where id=a), 'Reprogramación vinculada a cita citada');
  perform pg_temp.assert_true(exists(select 1 from public.solicitudes_cita_web where celular='51999111222'), 'Solicitud visible en recepción');
  update public.citas set inicio=now()+interval '90 minutes',fin=now()+interval '120 minutes',estado='CONFIRMADA',version=version+1 where id=a;
  perform pg_temp.assert_true(exists(select 1 from public.mensajes_whatsapp where cita_id=a and tipo='CITA_REPROGRAMACION' and estado='PENDIENTE'), 'Nuevo horario notificado');
  perform public.preparar_recordatorios_whatsapp();
  perform pg_temp.assert_true(not exists(select 1 from public.mensajes_whatsapp where cita_id=a and tipo='CITA_RECORDATORIO_2H'), 'No acumular avisos recientes');
  update public.mensajes_whatsapp set creado_en=now()-interval '3 hours' where cita_id=a;
  perform public.preparar_recordatorios_whatsapp();
  perform public.preparar_recordatorios_whatsapp();
  perform pg_temp.assert_true((select count(*)=1 from public.mensajes_whatsapp where cita_id=a and tipo='CITA_RECORDATORIO_2H'), 'Recordatorio 2h único');
  perform public.registrar_evento_whatsapp(jsonb_build_object('phone','999111222','content','CANCELAR','providerId','in-old-context','contextProviderId','out-test'));
  perform pg_temp.assert_true((select estado='CONFIRMADA' from public.citas where id=a), 'Respuesta a horario anterior no modifica nueva cita');
  update public.mensajes_whatsapp set proveedor_id='out-new-time' where cita_id=a and tipo='CITA_REPROGRAMACION';
  perform public.registrar_evento_whatsapp(jsonb_build_object('phone','999111222','content','CANCELAR','providerId','in-5','contextProviderId','out-new-time'));
  perform pg_temp.assert_true((select estado='CANCELADA' from public.citas where id=a), 'Cancelación reflejada en agenda');
  perform pg_temp.assert_true(exists(select 1 from public.mensajes_whatsapp where cita_id=a and tipo='CITA_CANCELACION' and estado='PENDIENTE'), 'Aviso de cancelación');
  update public.citas set estado='CANCELADA' where id=a;
  perform pg_temp.assert_true(exists(select 1 from public.mensajes_whatsapp where cita_id=a and tipo='CITA_CANCELACION' and estado='PENDIENTE'), 'Guardar mismo estado conserva aviso de cancelación');
  perform pg_temp.assert_true(not exists(select 1 from public.mensajes_whatsapp where cita_id=a and tipo in ('CITA_RECORDATORIO','CITA_RECORDATORIO_2H') and estado='PENDIENTE'), 'Cancelar retira recordatorios');
  insert into public.citas(paciente_id,profesional_id,tipo_cita_id,inicio,fin,estado,motivo,creado_por,actualizado_por)
    values(p,u,1,now()+interval '5 days',now()+interval '5 days 30 minutes','CONFIRMADA','Prueba',u,u) returning id into b;
  perform pg_temp.assert_true(exists(select 1 from public.mensajes_whatsapp where cita_id=b and tipo='CITA_CONFIRMADA'), 'Cita creada confirmada también avisa');
  raise notice 'WhatsApp: todas las comprobaciones de automatización aprobadas';
end;
$$;
rollback;
