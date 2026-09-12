-- Evita operaciones financieras duplicadas y valida los datos críticos en servidor.

alter table public.pagos add column if not exists solicitud_id uuid;
update public.pagos set solicitud_id = gen_random_uuid() where solicitud_id is null;
alter table public.pagos alter column solicitud_id set default gen_random_uuid();
alter table public.pagos alter column solicitud_id set not null;
create unique index if not exists uq_pago_solicitud on public.pagos(solicitud_id);

alter table public.gastos add column if not exists solicitud_id uuid;
update public.gastos set solicitud_id = gen_random_uuid() where solicitud_id is null;
alter table public.gastos alter column solicitud_id set default gen_random_uuid();
alter table public.gastos alter column solicitud_id set not null;
create unique index if not exists uq_gasto_solicitud on public.gastos(solicitud_id);

create or replace function public.cerrar_caja(
  caja_id bigint,
  monto_contado numeric,
  observacion text,
  version_actual bigint,
  confirmacion boolean
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor bigint := public.validar_finanza();
  item public.sesiones_caja;
  cash_method_id bigint;
  expected numeric(12,2);
  counted_value numeric(12,2) := monto_contado;
  clean_observation text := nullif(btrim(observacion), '');
begin
  if confirmacion is not true then
    raise exception using errcode = 'P0001', message = 'Confirme el cierre de caja';
  end if;
  if counted_value is null or counted_value < 0 then
    raise exception using errcode = 'P0001', message = 'El monto contado no puede ser negativo';
  end if;
  if char_length(coalesce(clean_observation, '')) > 1000 then
    raise exception using errcode = 'P0001', message = 'La observación de cierre supera los 1000 caracteres';
  end if;

  select * into item from public.sesiones_caja where id = caja_id for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'Caja no encontrada';
  end if;
  if item.estado <> 'ABIERTA' then
    raise exception using errcode = 'P0001', message = 'La caja ya está cerrada';
  end if;
  if item.version <> version_actual then
    raise exception using errcode = 'P0001', message = 'La caja fue modificada por otro usuario';
  end if;

  select id into cash_method_id from public.metodos_pago where codigo = 'EFECTIVO';
  select item.monto_apertura + coalesce(sum(case when tipo = 'INGRESO' then monto else -monto end), 0)
  into expected
  from public.movimientos_caja
  where sesion_caja_id = caja_id and metodo_pago_id = cash_method_id;

  if counted_value <> expected and clean_observation is null then
    raise exception using errcode = 'P0001', message = 'Explica la diferencia entre el efectivo esperado y el contado';
  end if;

  update public.sesiones_caja
  set estado = 'CERRADA', cerrada_por = actor, cerrada_en = now(),
      monto_esperado = expected, monto_contado = counted_value,
      diferencia = counted_value - expected, observacion_cierre = clean_observation,
      version = version + 1
  where id = caja_id
  returning * into item;
  perform public.registrar_auditoria('CERRAR_CAJA', 'FINANZAS', caja_id::text, 'Diferencia ' || item.diferencia);
  return public.caja_json(item);
end;
$$;

create or replace function public.registrar_pago(datos jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor bigint := public.validar_finanza();
  cash public.sesiones_caja;
  account public.cuentas_por_cobrar;
  method public.metodos_pago;
  item public.pagos;
  amount numeric(12,2);
  operation_text text := nullif(btrim(datos ->> 'operationId'), '');
  operation_id uuid;
  clean_reference text := nullif(btrim(datos ->> 'reference'), '');
begin
  if coalesce((datos ->> 'confirmation')::boolean, false) is not true then
    raise exception using errcode = 'P0001', message = 'Confirme el registro del pago';
  end if;
  if operation_text is null or operation_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'Identificador de operación inválido';
  end if;
  operation_id := operation_text::uuid;
  select * into item from public.pagos where solicitud_id = operation_id;
  if found then
    if item.registrado_por <> actor then
      raise exception using errcode = '42501', message = 'La operación pertenece a otro usuario';
    end if;
    return public.pago_json(item);
  end if;
  if jsonb_typeof(datos -> 'amount') <> 'number' then
    raise exception using errcode = 'P0001', message = 'Monto de pago inválido';
  end if;
  amount := (datos ->> 'amount')::numeric;
  if amount <= 0 then
    raise exception using errcode = 'P0001', message = 'El monto del pago debe ser mayor que cero';
  end if;
  if char_length(coalesce(clean_reference, '')) > 120 then
    raise exception using errcode = 'P0001', message = 'La referencia supera los 120 caracteres';
  end if;

  select * into cash from public.sesiones_caja where estado = 'ABIERTA' for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'Abra la caja antes de registrar operaciones';
  end if;
  select * into account
  from public.cuentas_por_cobrar
  where id = (datos ->> 'accountId')::bigint
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'Cuenta por cobrar no encontrada';
  end if;
  if account.estado in ('PAGADA', 'ANULADA') or amount > account.saldo then
    raise exception using errcode = 'P0001', message = 'El pago supera el saldo pendiente o la cuenta no admite pagos';
  end if;
  select * into method
  from public.metodos_pago
  where id = (datos ->> 'paymentMethodId')::bigint and activo;
  if not found then
    raise exception using errcode = 'P0001', message = 'Método de pago no encontrado';
  end if;
  if method.requiere_referencia and clean_reference is null then
    raise exception using errcode = 'P0001', message = 'El método de pago requiere referencia';
  end if;

  insert into public.pagos(
    cuenta_id, paciente_id, plan_id, sesion_caja_id, metodo_pago_id, monto,
    referencia, numero_constancia, registrado_por, confirmado_por, solicitud_id
  ) values (
    account.id, account.paciente_id, account.plan_id, cash.id, method.id, amount,
    clean_reference,
    'REC-' || extract(year from current_date)::text || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
    actor, actor, operation_id
  ) returning * into item;

  update public.cuentas_por_cobrar
  set monto_pagado = monto_pagado + amount, saldo = saldo - amount,
      estado = case when saldo - amount = 0 then 'PAGADA' else 'PARCIAL' end,
      actualizado_en = now(), version = version + 1
  where id = account.id;
  insert into public.movimientos_caja(
    sesion_caja_id, tipo, categoria, origen, origen_id, metodo_pago_id,
    monto, descripcion, creado_por
  ) values (
    cash.id, 'INGRESO', 'COBRO_TRATAMIENTO', 'PAGO', item.id, method.id,
    amount, 'Pago ' || item.numero_constancia, actor
  );
  perform public.registrar_auditoria('REGISTRAR_PAGO', 'FINANZAS', item.id::text, item.numero_constancia);
  return public.pago_json(item);
end;
$$;

create or replace function public.registrar_gasto(datos jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor bigint := public.validar_finanza();
  cash public.sesiones_caja;
  method public.metodos_pago;
  item public.gastos;
  amount numeric(12,2);
  operation_text text := nullif(btrim(datos ->> 'operationId'), '');
  operation_id uuid;
  category_value text := btrim(coalesce(datos ->> 'category', ''));
  description_value text := btrim(coalesce(datos ->> 'description', ''));
  provider_value text := nullif(btrim(datos ->> 'provider'), '');
  document_value text := nullif(btrim(datos ->> 'documentReference'), '');
begin
  if coalesce((datos ->> 'confirmation')::boolean, false) is not true then
    raise exception using errcode = 'P0001', message = 'Confirme el registro del gasto';
  end if;
  if operation_text is null or operation_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'Identificador de operación inválido';
  end if;
  operation_id := operation_text::uuid;
  select * into item from public.gastos where solicitud_id = operation_id;
  if found then
    if item.registrado_por <> actor then
      raise exception using errcode = '42501', message = 'La operación pertenece a otro usuario';
    end if;
    return public.gasto_json(item);
  end if;
  if jsonb_typeof(datos -> 'amount') <> 'number' then
    raise exception using errcode = 'P0001', message = 'Monto de gasto inválido';
  end if;
  amount := (datos ->> 'amount')::numeric;
  if amount <= 0 then
    raise exception using errcode = 'P0001', message = 'El monto del gasto debe ser mayor que cero';
  end if;
  if category_value not in ('Insumos', 'Servicios', 'Laboratorio', 'Mantenimiento', 'Personal', 'Otros') then
    raise exception using errcode = 'P0001', message = 'Categoría de gasto inválida';
  end if;
  if description_value = '' then
    raise exception using errcode = 'P0001', message = 'Describe el gasto';
  end if;
  if char_length(description_value) > 500 or char_length(coalesce(provider_value, '')) > 150
     or char_length(coalesce(document_value, '')) > 80 then
    raise exception using errcode = 'P0001', message = 'Uno de los datos del gasto supera el tamaño permitido';
  end if;

  select * into cash from public.sesiones_caja where estado = 'ABIERTA' for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'Abra la caja antes de registrar operaciones';
  end if;
  select * into method
  from public.metodos_pago
  where id = (datos ->> 'paymentMethodId')::bigint and activo;
  if not found then
    raise exception using errcode = 'P0001', message = 'Método de pago no encontrado';
  end if;
  if method.requiere_referencia and document_value is null then
    raise exception using errcode = 'P0001', message = 'El método de pago requiere documento o referencia';
  end if;

  insert into public.gastos(
    sesion_caja_id, categoria, descripcion, proveedor, documento_referencia,
    metodo_pago_id, monto, registrado_por, confirmado_por, solicitud_id
  ) values (
    cash.id, category_value, description_value, provider_value, document_value,
    method.id, amount, actor, actor, operation_id
  ) returning * into item;
  insert into public.movimientos_caja(
    sesion_caja_id, tipo, categoria, origen, origen_id, metodo_pago_id,
    monto, descripcion, creado_por
  ) values (
    cash.id, 'EGRESO', item.categoria, 'GASTO', item.id, method.id,
    item.monto, item.descripcion, actor
  );
  perform public.registrar_auditoria('REGISTRAR_GASTO', 'FINANZAS', item.id::text, item.categoria);
  return public.gasto_json(item);
end;
$$;

revoke all on function public.cerrar_caja(bigint, numeric, text, bigint, boolean) from public;
revoke all on function public.registrar_pago(jsonb) from public;
revoke all on function public.registrar_gasto(jsonb) from public;
grant execute on function public.cerrar_caja(bigint, numeric, text, bigint, boolean) to authenticated;
grant execute on function public.registrar_pago(jsonb) to authenticated;
grant execute on function public.registrar_gasto(jsonb) to authenticated;
