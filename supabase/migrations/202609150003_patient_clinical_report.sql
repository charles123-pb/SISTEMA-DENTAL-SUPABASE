-- Consulta consolidada de un solo paciente. No crea ni modifica atenciones.
create or replace function public.obtener_historia_clinica_paciente(paciente_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if not (public.has_permission('PACIENTE_LEER') and public.has_permission('CLINICA_LEER')) then
    raise exception using errcode = '42501', message = 'No autorizado para consultar la historia clínica completa';
  end if;
  if paciente_id is null or paciente_id <= 0 or not exists(select 1 from public.pacientes where id = paciente_id) then
    raise exception 'Paciente no encontrado';
  end if;
  select jsonb_build_object(
    'patientId', paciente_id, 'generatedAt', now(),
    'encounters', coalesce((select jsonb_agg(public.atencion_json(a) order by a.fecha_atencion, a.id)
      from public.atenciones_clinicas a where a.paciente_id = obtener_historia_clinica_paciente.paciente_id
      and a.estado = 'FINALIZADA'), '[]'::jsonb),
    'excludedEncounters', (select count(*) from public.atenciones_clinicas a
      where a.paciente_id = obtener_historia_clinica_paciente.paciente_id and a.estado <> 'FINALIZADA'),
    'odontograms', coalesce((select jsonb_agg(public.odontograma_json(o) order by o.creado_en, o.id)
      from public.odontogramas o join public.atenciones_clinicas a on a.id = o.atencion_id
      where o.paciente_id = obtener_historia_clinica_paciente.paciente_id and a.paciente_id = o.paciente_id
      and o.estado = 'APROBADO' and a.estado = 'FINALIZADA'), '[]'::jsonb),
    'treatmentsIncluded', public.has_permission('TRATAMIENTO_LEER'),
    'plans', case when public.has_permission('TRATAMIENTO_LEER') then
      coalesce((select jsonb_agg(public.plan_json(p) order by p.creado_en, p.id) from public.planes_tratamiento p
        where p.paciente_id = obtener_historia_clinica_paciente.paciente_id and p.estado <> 'BORRADOR'), '[]'::jsonb)
      else '[]'::jsonb end,
    'appointmentsIncluded', public.has_permission('CITA_LEER'),
    'appointments', case when public.has_permission('CITA_LEER') then
      coalesce((select jsonb_agg(public.cita_json(c) order by c.inicio, c.id) from public.citas c
        where c.paciente_id = obtener_historia_clinica_paciente.paciente_id), '[]'::jsonb)
      else '[]'::jsonb end
  ) into result;
  return result;
end;
$$;
revoke all on function public.obtener_historia_clinica_paciente(bigint) from public, anon;
grant execute on function public.obtener_historia_clinica_paciente(bigint) to authenticated;
