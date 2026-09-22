-- Base de pruebas exclusivamente. El rollback retira datos y el sustituto de auth.uid.
begin;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.report_user',true),'')::uuid
$$;
create function pg_temp.assert_report(ok boolean, message text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAIL: %',message; end if; end $$;
do $$
declare actor bigint; patient bigint; other bigint; approved bigint; draft bigint; role_id bigint;
  report jsonb; denied boolean; uid uuid := '9ad8269c-75b5-499f-96dd-a9f4879b0001';
begin
  insert into auth.users(id,email,raw_user_meta_data) values(uid,'report-test@example.invalid','{"username":"report-test"}');
  select id into actor from public.usuarios where auth_user_id=uid;
  insert into public.roles(codigo,nombre) values('REPORT_TEST','Rol temporal de prueba') returning id into role_id;
  insert into public.roles_permisos(rol_id,permiso_id) select role_id,id from public.permisos where codigo in ('PACIENTE_LEER','CLINICA_LEER');
  insert into public.usuarios_roles(usuario_id,rol_id) values(actor,role_id);
  insert into public.pacientes(numero_historia,tipo_documento,nombres,apellido_paterno,fecha_nacimiento,sexo,creado_por,actualizado_por)
    values('REPORT-1','SIN_DOCUMENTO','Paciente','Uno','1990-01-01','FEMENINO',actor,actor) returning id into patient;
  insert into public.pacientes(numero_historia,tipo_documento,nombres,apellido_paterno,fecha_nacimiento,sexo,creado_por,actualizado_por)
    values('REPORT-2','SIN_DOCUMENTO','Paciente','Dos','1990-01-01','FEMENINO',actor,actor) returning id into other;
  insert into public.atenciones_clinicas(paciente_id,odontologo_id,estado,motivo_consulta,examen_odontologico,diagnostico,plan_trabajo,consentimiento_paciente,aprobado_por,aprobado_en,creado_por,actualizado_por)
    values(patient,actor,'FINALIZADA','Motivo','Examen','Diagnóstico aprobado','Plan',true,actor,now(),actor,actor) returning id into approved;
  insert into public.atenciones_clinicas(paciente_id,odontologo_id,diagnostico,creado_por,actualizado_por)
    values(patient,actor,'Diagnóstico en borrador',actor,actor) returning id into draft;
  insert into public.atenciones_clinicas(paciente_id,odontologo_id,estado,motivo_consulta,examen_odontologico,diagnostico,plan_trabajo,consentimiento_paciente,aprobado_por,aprobado_en,creado_por,actualizado_por)
    values(other,actor,'FINALIZADA','Motivo','Examen','Diagnóstico de otro paciente','Plan',true,actor,now(),actor,actor);
  insert into public.odontogramas(atencion_id,paciente_id,tipo_denticion,estado,aprobado_por,aprobado_en,creado_por,actualizado_por)
    values(approved,patient,'PERMANENTE','APROBADO',actor,now(),actor,actor),
      (draft,patient,'PERMANENTE','APROBADO',actor,now(),actor,actor);
  denied := false;
  begin perform public.obtener_historia_clinica_paciente(patient); exception when insufficient_privilege then denied:=true; end;
  perform pg_temp.assert_report(denied,'Sin sesión no obtiene historia');
  perform set_config('test.report_user',uid::text,true);
  report := public.obtener_historia_clinica_paciente(patient);
  perform pg_temp.assert_report((report->>'patientId')::bigint=patient,'Paciente correcto');
  perform pg_temp.assert_report(jsonb_array_length(report->'encounters')=1,'Solo atención finalizada de este paciente');
  perform pg_temp.assert_report(report->'encounters'->0->>'diagnosis'='Diagnóstico aprobado','Incluye diagnóstico original');
  perform pg_temp.assert_report((report->>'excludedEncounters')::integer=1,'Informa borradores excluidos');
  perform pg_temp.assert_report(jsonb_array_length(report->'odontograms')=1,'Solo odontograma de atención finalizada');
  perform pg_temp.assert_report(not (report->>'treatmentsIncluded')::boolean and not (report->>'appointmentsIncluded')::boolean,'Respeta permisos de secciones opcionales');
  insert into public.roles_permisos(rol_id,permiso_id) select role_id,id from public.permisos where codigo in ('TRATAMIENTO_LEER','CITA_LEER');
  report := public.obtener_historia_clinica_paciente(patient);
  perform pg_temp.assert_report((report->>'treatmentsIncluded')::boolean and (report->>'appointmentsIncluded')::boolean,'Incluye secciones autorizadas');
  delete from public.roles_permisos where rol_id=role_id and permiso_id=(select id from public.permisos where codigo='CLINICA_LEER');
  denied := false;
  begin perform public.obtener_historia_clinica_paciente(patient); exception when insufficient_privilege then denied:=true; end;
  perform pg_temp.assert_report(denied,'PACIENTE_LEER por sí solo no permite informe clínico');
  raise notice 'Informe clínico: permisos, aislamiento de paciente y registros aprobados verificados';
end;
$$;
rollback;
