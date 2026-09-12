alter table public.odontogramas enable row level security;
alter table public.odontograma_hallazgos enable row level security;
alter table public.odontograma_versiones enable row level security;
revoke all on public.odontogramas, public.odontograma_hallazgos, public.odontograma_versiones from anon, authenticated;
grant select on public.odontogramas, public.odontograma_hallazgos, public.odontograma_versiones to authenticated;
create policy odontograms_read on public.odontogramas for select to authenticated using (public.has_permission('CLINICA_LEER'));
create policy odontogram_findings_read on public.odontograma_hallazgos for select to authenticated using (public.has_permission('CLINICA_LEER'));
create policy odontogram_versions_read on public.odontograma_versiones for select to authenticated using (public.has_permission('CLINICA_LEER'));
-- Sin DELETE ni escritura directa: los cambios clínicos pasan por RPC auditado.
