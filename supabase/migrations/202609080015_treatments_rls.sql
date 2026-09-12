alter table public.servicios enable row level security;
alter table public.planes_tratamiento enable row level security;
alter table public.plan_tratamiento_items enable row level security;
alter table public.evoluciones_tratamiento enable row level security;
revoke all on public.servicios,public.planes_tratamiento,public.plan_tratamiento_items,public.evoluciones_tratamiento from anon,authenticated;
grant select on public.servicios,public.planes_tratamiento,public.plan_tratamiento_items,public.evoluciones_tratamiento to authenticated;
create policy services_read on public.servicios for select to authenticated using(public.has_permission('TRATAMIENTO_LEER'));
create policy plans_read on public.planes_tratamiento for select to authenticated using(public.has_permission('TRATAMIENTO_LEER') or public.has_permission('FINANZA_LEER'));
create policy plan_items_read on public.plan_tratamiento_items for select to authenticated using(public.has_permission('TRATAMIENTO_LEER') or public.has_permission('FINANZA_LEER'));
create policy treatment_evolutions_read on public.evoluciones_tratamiento for select to authenticated using(public.has_permission('TRATAMIENTO_LEER'));
-- Cálculos y escrituras quedan exclusivamente en RPC transaccional.
