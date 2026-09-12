-- Fase 7: historia clínica y versionado, equivalente a Flyway V4/V12.
create table public.atenciones_clinicas (
  id bigserial primary key,
  paciente_id bigint not null references public.pacientes(id) on delete restrict,
  cita_id bigint unique references public.citas(id) on delete restrict,
  odontologo_id bigint not null references public.usuarios(id) on delete restrict,
  fecha_atencion timestamptz not null default current_timestamp,
  estado varchar(20) not null default 'BORRADOR',
  motivo_consulta varchar(1000),
  tiempo_enfermedad varchar(250),
  signos_sintomas varchar(1500),
  relato_cronologico text,
  presion_sistolica smallint,
  presion_diastolica smallint,
  pulso smallint,
  temperatura numeric(4,1),
  frecuencia_respiratoria smallint,
  peso_kg numeric(5,2),
  talla_cm numeric(5,2),
  examen_general text,
  examen_odontologico text,
  diagnostico text,
  plan_trabajo text,
  pronostico varchar(500),
  evolucion text,
  indicaciones text,
  fecha_proximo_control date,
  alta_paciente boolean not null default false,
  observacion_alta varchar(1000),
  consentimiento_paciente boolean not null default false,
  aprobado_por bigint references public.usuarios(id) on delete restrict,
  aprobado_en timestamptz,
  creado_por bigint not null references public.usuarios(id) on delete restrict,
  actualizado_por bigint not null references public.usuarios(id) on delete restrict,
  creado_en timestamptz not null default current_timestamp,
  actualizado_en timestamptz not null default current_timestamp,
  version bigint not null default 0,
  constraint chk_atencion_estado check (estado in ('BORRADOR','FINALIZADA','ANULADA')),
  constraint chk_atencion_pa check (presion_sistolica is null or presion_sistolica between 40 and 300),
  constraint chk_atencion_pad check (presion_diastolica is null or presion_diastolica between 20 and 200),
  constraint chk_atencion_pulso check (pulso is null or pulso between 20 and 250),
  constraint chk_atencion_temperatura check (temperatura is null or temperatura between 30 and 45),
  constraint chk_atencion_fr check (frecuencia_respiratoria is null or frecuencia_respiratoria between 5 and 80),
  constraint chk_atencion_aprobacion check (
    (estado = 'FINALIZADA' and aprobado_por is not null and aprobado_en is not null)
    or estado <> 'FINALIZADA'
  )
);
create index idx_atencion_paciente_fecha on public.atenciones_clinicas(paciente_id, fecha_atencion desc);
create index idx_atencion_odontologo_fecha on public.atenciones_clinicas(odontologo_id, fecha_atencion desc);
create index idx_atencion_estado_fecha on public.atenciones_clinicas(estado, fecha_atencion desc);

create table public.atencion_versiones (
  id bigserial primary key,
  atencion_id bigint not null references public.atenciones_clinicas(id) on delete restrict,
  numero_version bigint not null,
  accion varchar(30) not null,
  resumen text,
  datos jsonb not null,
  creado_por bigint not null references public.usuarios(id) on delete restrict,
  creado_en timestamptz not null default current_timestamp,
  unique (atencion_id, numero_version, accion)
);
create index idx_atencion_version on public.atencion_versiones(atencion_id, creado_en desc);
