alter table public.tipos_cita enable row level security;
alter table public.horarios_profesionales enable row level security;
alter table public.bloqueos_agenda enable row level security;
alter table public.citas enable row level security;
alter table public.cita_historial_estados enable row level security;
alter table public.solicitudes_cita_web enable row level security;

revoke all on public.tipos_cita, public.horarios_profesionales, public.bloqueos_agenda,
  public.citas, public.cita_historial_estados, public.solicitudes_cita_web from anon, authenticated;
grant select on public.tipos_cita, public.horarios_profesionales, public.bloqueos_agenda,
  public.citas, public.cita_historial_estados, public.solicitudes_cita_web to authenticated;
grant insert, update on public.horarios_profesionales, public.bloqueos_agenda, public.citas to authenticated;
grant usage, select on all sequences in schema public to authenticated;

create policy appointment_types_read on public.tipos_cita for select to authenticated
  using (public.has_permission('CITA_LEER'));
create policy professional_schedules_read on public.horarios_profesionales for select to authenticated
  using (public.has_permission('CITA_LEER'));
create policy professional_schedules_write on public.horarios_profesionales for all to authenticated
  using (public.has_permission('CITA_ESCRIBIR')) with check (public.has_permission('CITA_ESCRIBIR'));
create policy schedule_blocks_read on public.bloqueos_agenda for select to authenticated
  using (public.has_permission('CITA_LEER'));
create policy schedule_blocks_write on public.bloqueos_agenda for all to authenticated
  using (public.has_permission('CITA_ESCRIBIR'))
  with check (public.has_permission('CITA_ESCRIBIR') and creado_por = public.current_app_user_id());
create policy appointments_read on public.citas for select to authenticated
  using (public.has_permission('CITA_LEER'));
create policy appointments_insert on public.citas for insert to authenticated
  with check (public.has_permission('CITA_ESCRIBIR') and creado_por = public.current_app_user_id() and actualizado_por = public.current_app_user_id());
create policy appointments_update on public.citas for update to authenticated
  using (public.has_permission('CITA_ESCRIBIR'))
  with check (public.has_permission('CITA_ESCRIBIR') and actualizado_por = public.current_app_user_id());
create policy appointment_history_read on public.cita_historial_estados for select to authenticated
  using (public.has_permission('CITA_LEER'));
create policy booking_requests_read on public.solicitudes_cita_web for select to authenticated
  using (public.has_permission('CITA_LEER'));

-- No hay políticas DELETE. Las solicitudes públicas solo entran por un RPC validado.
