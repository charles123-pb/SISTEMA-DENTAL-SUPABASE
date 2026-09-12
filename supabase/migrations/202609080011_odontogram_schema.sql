-- Fase 8: odontograma clínico, preservando piezas, superficies y estados reales.
create table public.odontogramas (
  id bigserial primary key,
  atencion_id bigint not null references public.atenciones_clinicas(id) on delete restrict,
  paciente_id bigint not null references public.pacientes(id) on delete restrict,
  tipo_denticion varchar(20) not null,
  estado varchar(20) not null default 'BORRADOR',
  observacion_general text,
  aprobado_por bigint references public.usuarios(id) on delete restrict,
  aprobado_en timestamptz,
  creado_por bigint not null references public.usuarios(id) on delete restrict,
  actualizado_por bigint not null references public.usuarios(id) on delete restrict,
  creado_en timestamptz not null default current_timestamp,
  actualizado_en timestamptz not null default current_timestamp,
  version bigint not null default 0,
  constraint chk_odontograma_denticion check (tipo_denticion in ('PERMANENTE','INFANTIL')),
  constraint chk_odontograma_estado check (estado in ('BORRADOR','APROBADO')),
  unique (atencion_id, tipo_denticion)
);
create index idx_odontograma_paciente on public.odontogramas(paciente_id, creado_en desc);

create table public.odontograma_hallazgos (
  id bigserial primary key,
  odontograma_id bigint not null references public.odontogramas(id) on delete restrict,
  pieza varchar(3) not null,
  superficie varchar(30) not null,
  condicion varchar(40) not null,
  estado_tratamiento varchar(20) not null default 'EXISTENTE',
  observacion varchar(500),
  activo boolean not null default true,
  creado_por bigint not null references public.usuarios(id) on delete restrict,
  actualizado_por bigint not null references public.usuarios(id) on delete restrict,
  creado_en timestamptz not null default current_timestamp,
  actualizado_en timestamptz not null default current_timestamp,
  version bigint not null default 0,
  constraint chk_hallazgo_superficie check (superficie in ('GENERAL','OCLUSAL','INCISAL','MESIAL','DISTAL','VESTIBULAR','LINGUAL_PALATINA')),
  constraint chk_hallazgo_estado check (estado_tratamiento in ('EXISTENTE','INDICADO','REALIZADO')),
  constraint chk_hallazgo_condicion check (condicion in ('CARIES','RESTAURACION','CORONA','AUSENTE','EXTRACCION_INDICADA','ENDODONCIA','FRACTURA','SELLANTE','PROTESIS','IMPLANTE','MOVILIDAD','OTRO'))
);
create unique index uq_odontograma_hallazgo_activo on public.odontograma_hallazgos(odontograma_id, pieza, superficie, condicion) where activo;
create index idx_hallazgo_odontograma on public.odontograma_hallazgos(odontograma_id, activo, pieza);

create table public.odontograma_versiones (
  id bigserial primary key,
  odontograma_id bigint not null references public.odontogramas(id) on delete restrict,
  numero_version bigint not null,
  resumen varchar(500) not null,
  datos jsonb not null,
  creado_por bigint not null references public.usuarios(id) on delete restrict,
  creado_en timestamptz not null default current_timestamp
);
create index idx_odontograma_version on public.odontograma_versiones(odontograma_id, creado_en desc);
