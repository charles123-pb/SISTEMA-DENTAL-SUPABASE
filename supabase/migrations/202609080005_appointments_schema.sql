-- Fase 6: adaptación de V3, V11 y la columna de recordatorio de V16.

create table public.tipos_cita (
  id bigserial primary key,
  codigo varchar(40) not null unique,
  nombre varchar(100) not null,
  duracion_minutos integer not null,
  color varchar(10) not null,
  activo boolean not null default true,
  constraint chk_tipo_cita_duracion check (duracion_minutos between 10 and 480)
);

insert into public.tipos_cita(codigo, nombre, duracion_minutos, color) values
  ('CONSULTA', 'Consulta y evaluación', 30, '#4A90A4'),
  ('LIMPIEZA', 'Profilaxis / limpieza', 45, '#41A77C'),
  ('RESTAURACION', 'Restauración dental', 60, '#7B61B3'),
  ('ENDODONCIA', 'Endodoncia', 90, '#D28B36'),
  ('EXTRACCION', 'Extracción', 60, '#D05B66'),
  ('PROTESIS', 'Prótesis / control', 45, '#3C77B6'),
  ('CONTROL', 'Control postratamiento', 20, '#6D8A99')
on conflict (codigo) do nothing;

create table public.horarios_profesionales (
  id bigserial primary key,
  profesional_id bigint not null references public.usuarios(id) on delete restrict,
  dia_semana smallint not null,
  hora_inicio time not null,
  hora_fin time not null,
  intervalo_minutos integer not null default 15,
  activo boolean not null default true,
  creado_en timestamptz not null default current_timestamp,
  actualizado_en timestamptz not null default current_timestamp,
  version bigint not null default 0,
  constraint chk_horario_dia check (dia_semana between 1 and 7),
  constraint chk_horario_horas check (hora_fin > hora_inicio),
  constraint chk_horario_intervalo check (intervalo_minutos between 5 and 120),
  unique (profesional_id, dia_semana, hora_inicio, hora_fin)
);
create index idx_horario_profesional_dia on public.horarios_profesionales(profesional_id, dia_semana, activo);

create table public.bloqueos_agenda (
  id bigserial primary key,
  profesional_id bigint not null references public.usuarios(id) on delete restrict,
  inicio timestamptz not null,
  fin timestamptz not null,
  motivo varchar(250) not null,
  activo boolean not null default true,
  creado_por bigint not null default public.current_app_user_id() references public.usuarios(id) on delete restrict,
  creado_en timestamptz not null default current_timestamp,
  constraint chk_bloqueo_rango check (fin > inicio)
);
create index idx_bloqueo_agenda_rango on public.bloqueos_agenda(profesional_id, inicio, fin) where activo = true;

create table public.citas (
  id bigserial primary key,
  paciente_id bigint not null references public.pacientes(id) on delete restrict,
  profesional_id bigint not null references public.usuarios(id) on delete restrict,
  tipo_cita_id bigint not null references public.tipos_cita(id) on delete restrict,
  inicio timestamptz not null,
  fin timestamptz not null,
  estado varchar(30) not null default 'PENDIENTE_CONFIRMACION',
  motivo varchar(500) not null,
  notas varchar(1000),
  origen varchar(30) not null default 'RECEPCION',
  motivo_cancelacion varchar(500),
  confirmacion_enviada boolean not null default false,
  recordatorio_programado boolean not null default false,
  recordatorio_enviado boolean not null default false,
  creado_por bigint not null default public.current_app_user_id() references public.usuarios(id) on delete restrict,
  actualizado_por bigint not null default public.current_app_user_id() references public.usuarios(id) on delete restrict,
  creado_en timestamptz not null default current_timestamp,
  actualizado_en timestamptz not null default current_timestamp,
  version bigint not null default 0,
  constraint chk_cita_rango check (fin > inicio),
  constraint chk_cita_estado check (estado in ('PENDIENTE_CONFIRMACION','CONFIRMADA','EN_ESPERA','EN_ATENCION','COMPLETADA','CANCELADA','NO_ASISTIO')),
  constraint chk_cita_origen check (origen in ('RECEPCION','WHATSAPP','WEB','ODONTOLOGO','SISTEMA'))
);
create index idx_cita_agenda on public.citas(profesional_id, inicio, fin);
create index idx_cita_paciente on public.citas(paciente_id, inicio desc);
create index idx_cita_estado_inicio on public.citas(estado, inicio);
create index idx_cita_recordatorio on public.citas(recordatorio_programado, inicio)
  where estado in ('PENDIENTE_CONFIRMACION', 'CONFIRMADA');

create table public.cita_historial_estados (
  id bigserial primary key,
  cita_id bigint not null references public.citas(id) on delete restrict,
  estado_anterior varchar(30),
  estado_nuevo varchar(30) not null,
  motivo varchar(500),
  creado_por bigint not null default public.current_app_user_id() references public.usuarios(id) on delete restrict,
  creado_en timestamptz not null default current_timestamp
);
create index idx_cita_historial on public.cita_historial_estados(cita_id, creado_en desc);

create table public.solicitudes_cita_web (
  id bigserial primary key,
  nombre_completo varchar(150) not null,
  numero_documento varchar(20),
  celular varchar(20) not null,
  email varchar(150),
  servicio varchar(120) not null,
  fecha_preferida date,
  turno_preferido varchar(20),
  mensaje varchar(800),
  consentimiento_privacidad boolean not null,
  estado varchar(20) not null default 'PENDIENTE',
  observacion_interna varchar(500),
  cita_id bigint references public.citas(id) on delete restrict,
  atendido_por bigint references public.usuarios(id) on delete restrict,
  creado_en timestamptz not null default current_timestamp,
  actualizado_en timestamptz not null default current_timestamp,
  version bigint not null default 0,
  constraint chk_solicitud_estado check (estado in ('PENDIENTE','CONTACTADO','AGENDADO','DESCARTADO')),
  constraint chk_solicitud_turno check (turno_preferido in ('MANANA','TARDE','INDIFERENTE')),
  constraint chk_solicitud_consentimiento check (consentimiento_privacidad)
);
create index idx_solicitudes_web_estado on public.solicitudes_cita_web(estado, creado_en desc);
