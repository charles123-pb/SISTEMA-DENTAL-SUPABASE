-- Todas las tablas expuestas en la fase 1 quedan con RLS. No existen políticas DELETE.

alter table public.roles enable row level security;
alter table public.permisos enable row level security;
alter table public.usuarios enable row level security;
alter table public.usuarios_roles enable row level security;
alter table public.roles_permisos enable row level security;
alter table public.auditoria enable row level security;
alter table public.pacientes enable row level security;
alter table public.paciente_contactos_emergencia enable row level security;
alter table public.paciente_antecedentes enable row level security;
alter table public.paciente_alergias enable row level security;
alter table public.paciente_medicamentos enable row level security;
alter table public.paciente_archivos enable row level security;

revoke all on all tables in schema public from anon, authenticated;
grant select on public.roles, public.permisos, public.usuarios, public.usuarios_roles, public.roles_permisos to authenticated;
grant select on public.auditoria to authenticated;
grant select, insert, update on public.pacientes, public.paciente_contactos_emergencia,
  public.paciente_antecedentes, public.paciente_alergias, public.paciente_medicamentos to authenticated;
grant select on public.paciente_archivos to authenticated;
grant usage, select on all sequences in schema public to authenticated;

create policy roles_read_authenticated on public.roles for select to authenticated using (public.current_app_user_id() is not null);
create policy permissions_read_authenticated on public.permisos for select to authenticated using (public.current_app_user_id() is not null);
create policy users_read_self_or_admin on public.usuarios for select to authenticated
  using (auth_user_id = auth.uid() or public.has_permission('USUARIO_LEER'));
create policy user_roles_read_self_or_admin on public.usuarios_roles for select to authenticated
  using (usuario_id = public.current_app_user_id() or public.has_permission('USUARIO_LEER'));
create policy role_permissions_read_authenticated on public.roles_permisos for select to authenticated
  using (public.current_app_user_id() is not null);
create policy audit_read_authorized on public.auditoria for select to authenticated
  using (public.has_permission('AUDITORIA_LEER'));

create policy patients_read_authorized on public.pacientes for select to authenticated
  using (public.has_permission('PACIENTE_LEER'));
create policy patients_insert_authorized on public.pacientes for insert to authenticated
  with check (public.has_permission('PACIENTE_ESCRIBIR') and creado_por = public.current_app_user_id() and actualizado_por = public.current_app_user_id());
create policy patients_update_authorized on public.pacientes for update to authenticated
  using (public.has_permission('PACIENTE_ESCRIBIR'))
  with check (public.has_permission('PACIENTE_ESCRIBIR') and actualizado_por = public.current_app_user_id());

create policy emergency_contacts_read on public.paciente_contactos_emergencia for select to authenticated
  using (public.has_permission('PACIENTE_LEER'));
create policy emergency_contacts_insert on public.paciente_contactos_emergencia for insert to authenticated
  with check (public.has_permission('PACIENTE_ESCRIBIR') and creado_por = public.current_app_user_id());
create policy emergency_contacts_update on public.paciente_contactos_emergencia for update to authenticated
  using (public.has_permission('PACIENTE_ESCRIBIR')) with check (public.has_permission('PACIENTE_ESCRIBIR'));

create policy histories_read_clinical on public.paciente_antecedentes for select to authenticated using (public.has_permission('CLINICA_LEER'));
create policy histories_insert_clinical on public.paciente_antecedentes for insert to authenticated with check (public.has_permission('CLINICA_ESCRIBIR') and creado_por = public.current_app_user_id());
create policy histories_update_clinical on public.paciente_antecedentes for update to authenticated using (public.has_permission('CLINICA_ESCRIBIR')) with check (public.has_permission('CLINICA_ESCRIBIR'));
create policy allergies_read_clinical on public.paciente_alergias for select to authenticated using (public.has_permission('CLINICA_LEER'));
create policy allergies_insert_clinical on public.paciente_alergias for insert to authenticated with check (public.has_permission('CLINICA_ESCRIBIR') and creado_por = public.current_app_user_id());
create policy allergies_update_clinical on public.paciente_alergias for update to authenticated using (public.has_permission('CLINICA_ESCRIBIR')) with check (public.has_permission('CLINICA_ESCRIBIR'));
create policy medications_read_clinical on public.paciente_medicamentos for select to authenticated using (public.has_permission('CLINICA_LEER'));
create policy medications_insert_clinical on public.paciente_medicamentos for insert to authenticated with check (public.has_permission('CLINICA_ESCRIBIR') and creado_por = public.current_app_user_id());
create policy medications_update_clinical on public.paciente_medicamentos for update to authenticated using (public.has_permission('CLINICA_ESCRIBIR')) with check (public.has_permission('CLINICA_ESCRIBIR'));
create policy patient_files_read_clinical on public.paciente_archivos for select to authenticated using (public.has_permission('CLINICA_LEER'));
