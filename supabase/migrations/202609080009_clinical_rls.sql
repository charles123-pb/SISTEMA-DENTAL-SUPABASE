alter table public.atenciones_clinicas enable row level security;
alter table public.atencion_versiones enable row level security;

revoke all on public.atenciones_clinicas, public.atencion_versiones from anon, authenticated;
grant select on public.atenciones_clinicas, public.atencion_versiones to authenticated;

create policy clinical_encounters_read on public.atenciones_clinicas for select to authenticated
  using (public.has_permission('CLINICA_LEER'));
create policy clinical_versions_read on public.atencion_versiones for select to authenticated
  using (public.has_permission('CLINICA_LEER'));

-- Las escrituras clínicas solamente se realizan por RPC con validación, bloqueo y auditoría.
