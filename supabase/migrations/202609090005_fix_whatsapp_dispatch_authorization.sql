-- PostgREST reciente entrega el rol en una configuración de sesión que puede no
-- estar disponible dentro de una función SECURITY DEFINER. La ACL de esta RPC es
-- la barrera de seguridad: se revocó para PUBLIC y solo service_role puede ejecutarla.
create or replace function public.preparar_recordatorios_whatsapp() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_cita public.citas;
  v_paciente public.pacientes;
  v_conversacion_id bigint;
  v_telefono text;
  v_contenido text;
  v_total integer := 0;
begin
  for v_cita in
    select * from public.citas
    where estado in ('PENDIENTE_CONFIRMACION','CONFIRMADA')
      and not recordatorio_programado and inicio > now() and inicio <= now() + interval '24 hours'
    order by inicio for update skip locked
  loop
    select * into v_paciente from public.pacientes
    where id = v_cita.paciente_id and activo and whatsapp_autorizado;
    if not found then continue; end if;
    v_telefono := regexp_replace(coalesce(v_paciente.celular, ''), '\\D', '', 'g');
    if length(v_telefono) < 7 then continue; end if;
    if not public.telefono_whatsapp_es_unico(v_paciente.id, v_telefono) then continue; end if;

    v_conversacion_id := public.asegurar_conversacion_whatsapp(v_paciente.id, v_telefono);
    select replace(replace(replace(contenido, '{{paciente}}', v_paciente.nombres),
      '{{fecha}}', to_char(v_cita.inicio at time zone 'America/Lima', 'DD/MM/YYYY')),
      '{{hora}}', to_char(v_cita.inicio at time zone 'America/Lima', 'HH24:MI'))
    into v_contenido from public.plantillas_mensaje where codigo = 'CITA_RECORDATORIO' and activo;
    if v_contenido is null then continue; end if;

    insert into public.mensajes_whatsapp(
      conversacion_id, paciente_id, cita_id, direccion, contenido, estado,
      programado_para, creado_por, tipo, plantilla_nombre, parametros_plantilla)
    values (v_conversacion_id, v_paciente.id, v_cita.id, 'SALIENTE', v_contenido,
      'PENDIENTE', now(), v_cita.actualizado_por, 'CITA_RECORDATORIO', 'CITA_RECORDATORIO',
      jsonb_build_array(v_paciente.nombres,
        to_char(v_cita.inicio at time zone 'America/Lima', 'DD/MM/YYYY'),
        to_char(v_cita.inicio at time zone 'America/Lima', 'HH24:MI')));
    update public.citas set recordatorio_programado = true where id = v_cita.id;
    v_total := v_total + 1;
  end loop;
  return v_total;
end;
$$;

revoke all on function public.preparar_recordatorios_whatsapp() from public;
grant execute on function public.preparar_recordatorios_whatsapp() to service_role;
