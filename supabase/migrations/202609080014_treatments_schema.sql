-- Fases 9 y 10: catálogo, planes de tratamiento, presupuestos y evoluciones (Flyway V6).
create table public.servicios (
  id bigserial primary key, codigo varchar(40) not null unique, nombre varchar(150) not null,
  categoria varchar(80) not null, descripcion varchar(500), precio_base numeric(12,2) not null,
  sesiones_sugeridas integer not null default 1, activo boolean not null default true,
  creado_en timestamptz not null default current_timestamp, actualizado_en timestamptz not null default current_timestamp,
  version bigint not null default 0, constraint chk_servicio_precio check(precio_base>=0),
  constraint chk_servicio_sesiones check(sesiones_sugeridas between 1 and 50)
);
insert into public.servicios(codigo,nombre,categoria,precio_base,sesiones_sugeridas) values
('CONSULTA','Consulta odontológica','Diagnóstico',50,1),('PROFILAXIS','Profilaxis dental','Prevención',100,1),
('BLANQUEAMIENTO','Blanqueamiento dental','Estética',450,2),('RESTAURACION_SIMPLE','Restauración simple','Restauradora',120,1),
('RESTAURACION_COMPUESTA','Restauración compuesta','Restauradora',180,1),('ENDODONCIA_ANTERIOR','Endodoncia anterior','Endodoncia',450,2),
('ENDODONCIA_MOLAR','Endodoncia molar','Endodoncia',650,3),('EXTRACCION_SIMPLE','Extracción simple','Cirugía',150,1),
('EXTRACCION_COMPLEJA','Extracción compleja','Cirugía',350,1),('CORONA','Corona dental','Prótesis',850,3),
('PROTESIS_PARCIAL','Prótesis parcial','Prótesis',1200,4),('RADIOGRAFIA','Radiografía dental','Diagnóstico',40,1);

create table public.planes_tratamiento (
  id bigserial primary key, paciente_id bigint not null references public.pacientes(id) on delete restrict,
  atencion_id bigint references public.atenciones_clinicas(id) on delete restrict, codigo varchar(30) not null unique,
  estado varchar(20) not null default 'BORRADOR', descuento numeric(12,2) not null default 0,
  subtotal numeric(12,2) not null default 0, total numeric(12,2) not null default 0,
  observaciones varchar(1000), aceptado_por_paciente boolean not null default false, aceptado_en timestamptz,
  creado_por bigint not null references public.usuarios(id) on delete restrict,
  actualizado_por bigint not null references public.usuarios(id) on delete restrict,
  creado_en timestamptz not null default current_timestamp, actualizado_en timestamptz not null default current_timestamp,
  version bigint not null default 0,
  constraint chk_plan_estado check(estado in('BORRADOR','PRESENTADO','ACEPTADO','RECHAZADO','EN_PROCESO','COMPLETADO','CANCELADO')),
  constraint chk_plan_montos check(descuento>=0 and subtotal>=0 and total>=0 and total=subtotal-descuento)
);
create index idx_plan_paciente on public.planes_tratamiento(paciente_id,creado_en desc);

create table public.plan_tratamiento_items (
  id bigserial primary key, plan_id bigint not null references public.planes_tratamiento(id) on delete restrict,
  servicio_id bigint not null references public.servicios(id) on delete restrict, pieza varchar(3), descripcion varchar(500) not null,
  cantidad integer not null default 1, precio_unitario numeric(12,2) not null, sesiones integer not null default 1,
  estado varchar(20) not null default 'PROPUESTO', activo boolean not null default true,
  creado_por bigint not null references public.usuarios(id) on delete restrict,
  actualizado_por bigint not null references public.usuarios(id) on delete restrict,
  creado_en timestamptz not null default current_timestamp, actualizado_en timestamptz not null default current_timestamp,
  version bigint not null default 0, constraint chk_item_cantidad check(cantidad between 1 and 99),
  constraint chk_item_precio check(precio_unitario>=0), constraint chk_item_sesiones check(sesiones between 1 and 50),
  constraint chk_item_estado check(estado in('PROPUESTO','ACEPTADO','EN_PROCESO','COMPLETADO','CANCELADO'))
);
create index idx_plan_item on public.plan_tratamiento_items(plan_id,activo,estado);

create table public.evoluciones_tratamiento (
  id bigserial primary key, plan_item_id bigint not null references public.plan_tratamiento_items(id) on delete restrict,
  atencion_id bigint references public.atenciones_clinicas(id) on delete restrict, fecha timestamptz not null default current_timestamp,
  procedimiento_realizado text not null, observaciones text, proxima_sesion date,
  aprobado_por bigint not null references public.usuarios(id) on delete restrict, creado_en timestamptz not null default current_timestamp
);
create index idx_evolucion_item on public.evoluciones_tratamiento(plan_item_id,fecha desc);
