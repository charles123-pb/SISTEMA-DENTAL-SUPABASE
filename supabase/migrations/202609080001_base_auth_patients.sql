-- Fase 1: adaptación fiel de V1, V2 y V17 del backend Spring/Flyway.
-- Las claves BIGINT se conservan. auth.users se enlaza mediante usuarios.auth_user_id.

create sequence if not exists public.patient_history_number_seq start with 1 increment by 1;

create table public.roles (
  id bigserial primary key,
  codigo varchar(40) not null unique,
  nombre varchar(80) not null,
  descripcion varchar(250),
  activo boolean not null default true
);

create table public.permisos (
  id bigserial primary key,
  codigo varchar(60) not null unique,
  descripcion varchar(250) not null
);

create table public.usuarios (
  id bigserial primary key,
  auth_user_id uuid unique references auth.users(id) on delete restrict,
  username varchar(60) not null unique,
  password_hash varchar(100),
  nombre_completo varchar(150) not null,
  email varchar(150) unique,
  activo boolean not null default true,
  bloqueado boolean not null default false,
  intentos_fallidos integer not null default 0,
  ultimo_acceso timestamptz,
  creado_en timestamptz not null default current_timestamp,
  actualizado_en timestamptz not null default current_timestamp
);

comment on column public.usuarios.password_hash is
  'Campo legado de Spring. Supabase Auth administra las contraseñas nuevas; nunca escribir hashes de auth.users aquí.';

create table public.usuarios_roles (
  usuario_id bigint not null references public.usuarios(id) on delete restrict,
  rol_id bigint not null references public.roles(id) on delete restrict,
  primary key (usuario_id, rol_id)
);

create table public.roles_permisos (
  rol_id bigint not null references public.roles(id) on delete restrict,
  permiso_id bigint not null references public.permisos(id) on delete restrict,
  primary key (rol_id, permiso_id)
);

create table public.auditoria (
  id bigserial primary key,
  usuario_id bigint references public.usuarios(id) on delete restrict,
  username varchar(60),
  accion varchar(80) not null,
  recurso varchar(80) not null,
  recurso_id varchar(80),
  resultado varchar(20) not null,
  ip varchar(64),
  user_agent varchar(300),
  detalle text,
  creado_en timestamptz not null default current_timestamp
);

create index idx_auditoria_usuario on public.auditoria(usuario_id);
create index idx_auditoria_fecha on public.auditoria(creado_en desc);
create index idx_auditoria_recurso on public.auditoria(recurso, recurso_id);

create table public.pacientes (
  id bigserial primary key,
  numero_historia varchar(20) not null unique,
  tipo_documento varchar(20) not null,
  numero_documento varchar(20),
  nombres varchar(100) not null,
  apellido_paterno varchar(80) not null,
  apellido_materno varchar(80),
  fecha_nacimiento date not null,
  sexo varchar(20) not null,
  lugar_nacimiento varchar(150),
  ocupacion varchar(120),
  estado_civil varchar(30),
  grado_instruccion varchar(60),
  religion varchar(80),
  autoidentificacion_etnica varchar(100),
  celular varchar(20),
  telefono varchar(20),
  email varchar(150),
  direccion varchar(250),
  responsable_nombre varchar(150),
  responsable_documento varchar(20),
  responsable_parentesco varchar(60),
  responsable_telefono varchar(20),
  activo boolean not null default true,
  creado_en timestamptz not null default current_timestamp,
  actualizado_en timestamptz not null default current_timestamp,
  creado_por bigint not null references public.usuarios(id) on delete restrict,
  actualizado_por bigint not null references public.usuarios(id) on delete restrict,
  version bigint not null default 0,
  whatsapp_autorizado boolean not null default false,
  whatsapp_autorizado_en timestamptz,
  whatsapp_autorizado_por bigint references public.usuarios(id) on delete restrict,
  whatsapp_revocado_en timestamptz,
  constraint chk_paciente_documento check (
    (tipo_documento = 'SIN_DOCUMENTO' and numero_documento is null)
    or (tipo_documento <> 'SIN_DOCUMENTO' and numero_documento is not null)
  ),
  constraint chk_paciente_whatsapp_consentimiento check (
    whatsapp_autorizado = false
    or (whatsapp_autorizado_en is not null and whatsapp_autorizado_por is not null)
  )
);

create unique index uq_paciente_numero_documento on public.pacientes(numero_documento)
  where numero_documento is not null and btrim(numero_documento) <> '';
create index idx_paciente_nombre on public.pacientes(lower(apellido_paterno), lower(apellido_materno), lower(nombres));
create index idx_paciente_celular on public.pacientes(celular);
create index idx_paciente_activo_creado on public.pacientes(activo, creado_en desc);

create table public.paciente_contactos_emergencia (
  id bigserial primary key,
  paciente_id bigint not null references public.pacientes(id) on delete restrict,
  nombre_completo varchar(150) not null,
  parentesco varchar(60) not null,
  telefono varchar(20) not null,
  principal boolean not null default false,
  activo boolean not null default true,
  creado_en timestamptz not null default current_timestamp,
  creado_por bigint not null references public.usuarios(id) on delete restrict
);
create index idx_contacto_emergencia_paciente on public.paciente_contactos_emergencia(paciente_id, activo);

create table public.paciente_antecedentes (
  id bigserial primary key,
  paciente_id bigint not null references public.pacientes(id) on delete restrict,
  tipo varchar(30) not null,
  descripcion varchar(500) not null,
  estado varchar(30) not null default 'ACTIVO',
  observacion varchar(1000),
  fecha_informada date,
  activo boolean not null default true,
  creado_en timestamptz not null default current_timestamp,
  creado_por bigint not null references public.usuarios(id) on delete restrict,
  version bigint not null default 0
);
create index idx_antecedente_paciente on public.paciente_antecedentes(paciente_id, activo, creado_en desc);

create table public.paciente_alergias (
  id bigserial primary key,
  paciente_id bigint not null references public.pacientes(id) on delete restrict,
  sustancia varchar(150) not null,
  reaccion varchar(300),
  severidad varchar(20) not null,
  estado varchar(20) not null default 'ACTIVA',
  observacion varchar(1000),
  activo boolean not null default true,
  creado_en timestamptz not null default current_timestamp,
  creado_por bigint not null references public.usuarios(id) on delete restrict,
  version bigint not null default 0,
  constraint chk_alergia_severidad check (severidad in ('LEVE', 'MODERADA', 'SEVERA')),
  constraint chk_alergia_estado check (estado in ('ACTIVA', 'INACTIVA', 'DESCARTADA'))
);
create index idx_alergia_paciente on public.paciente_alergias(paciente_id, activo, estado);

create table public.paciente_medicamentos (
  id bigserial primary key,
  paciente_id bigint not null references public.pacientes(id) on delete restrict,
  medicamento varchar(180) not null,
  dosis varchar(100),
  frecuencia varchar(100),
  motivo varchar(250),
  fecha_inicio date,
  fecha_fin date,
  vigente boolean not null default true,
  activo boolean not null default true,
  creado_en timestamptz not null default current_timestamp,
  creado_por bigint not null references public.usuarios(id) on delete restrict,
  version bigint not null default 0,
  constraint chk_medicamento_fechas check (fecha_fin is null or fecha_inicio is null or fecha_fin >= fecha_inicio)
);
create index idx_medicamento_paciente on public.paciente_medicamentos(paciente_id, activo, vigente);

create table public.paciente_archivos (
  id bigserial primary key,
  paciente_id bigint not null references public.pacientes(id) on delete restrict,
  categoria varchar(30) not null,
  nombre_original varchar(255) not null,
  nombre_interno varchar(255) not null unique,
  tipo_contenido varchar(100) not null,
  tamano_bytes bigint not null,
  ubicacion varchar(500) not null,
  descripcion varchar(300),
  activo boolean not null default true,
  creado_en timestamptz not null default current_timestamp,
  creado_por bigint not null references public.usuarios(id) on delete restrict,
  constraint chk_archivo_tamano check (tamano_bytes > 0 and tamano_bytes <= 10485760)
);
create index idx_archivo_paciente on public.paciente_archivos(paciente_id, activo, creado_en desc);

insert into public.roles(codigo, nombre, descripcion) values
  ('ADMINISTRADOR', 'Administrador', 'Acceso completo y configuración del sistema'),
  ('RECEPCION', 'Recepción', 'Pacientes, agenda y seguimiento administrativo'),
  ('ODONTOLOGO', 'Odontólogo', 'Atención clínica, diagnóstico y tratamiento'),
  ('CAJA', 'Caja', 'Cobros, gastos, cierres y reportes financieros')
on conflict (codigo) do nothing;

insert into public.permisos(codigo, descripcion) values
  ('USUARIO_LEER', 'Consultar usuarios y roles'), ('USUARIO_ESCRIBIR', 'Crear y modificar usuarios y roles'),
  ('PACIENTE_LEER', 'Consultar pacientes'), ('PACIENTE_ESCRIBIR', 'Registrar y actualizar pacientes'),
  ('CITA_LEER', 'Consultar agenda y citas'), ('CITA_ESCRIBIR', 'Crear, confirmar, reprogramar y cancelar citas'),
  ('CLINICA_LEER', 'Consultar información clínica autorizada'), ('CLINICA_ESCRIBIR', 'Crear borradores y registros clínicos'),
  ('CLINICA_APROBAR', 'Finalizar y aprobar registros clínicos'), ('TRATAMIENTO_LEER', 'Consultar tratamientos y presupuestos'),
  ('TRATAMIENTO_ESCRIBIR', 'Crear tratamientos y presupuestos'), ('FINANZA_LEER', 'Consultar saldos, caja y reportes'),
  ('FINANZA_ESCRIBIR', 'Registrar pagos, gastos y cierres'), ('SEGUIMIENTO_LEER', 'Consultar mensajes y seguimientos'),
  ('SEGUIMIENTO_ESCRIBIR', 'Programar y responder seguimientos'), ('AUDITORIA_LEER', 'Consultar la trazabilidad del sistema'),
  ('AJUSTE_ESCRIBIR', 'Modificar la configuración general')
on conflict (codigo) do nothing;

insert into public.roles_permisos(rol_id, permiso_id)
select r.id, p.id from public.roles r cross join public.permisos p where r.codigo = 'ADMINISTRADOR'
on conflict do nothing;
insert into public.roles_permisos(rol_id, permiso_id)
select r.id, p.id from public.roles r join public.permisos p on p.codigo in
  ('PACIENTE_LEER','PACIENTE_ESCRIBIR','CITA_LEER','CITA_ESCRIBIR','SEGUIMIENTO_LEER','SEGUIMIENTO_ESCRIBIR')
where r.codigo = 'RECEPCION' on conflict do nothing;
insert into public.roles_permisos(rol_id, permiso_id)
select r.id, p.id from public.roles r join public.permisos p on p.codigo in
  ('PACIENTE_LEER','CITA_LEER','CLINICA_LEER','CLINICA_ESCRIBIR','CLINICA_APROBAR',
   'TRATAMIENTO_LEER','TRATAMIENTO_ESCRIBIR','SEGUIMIENTO_LEER','SEGUIMIENTO_ESCRIBIR')
where r.codigo = 'ODONTOLOGO' on conflict do nothing;
insert into public.roles_permisos(rol_id, permiso_id)
select r.id, p.id from public.roles r join public.permisos p on p.codigo in
  ('PACIENTE_LEER','FINANZA_LEER','FINANZA_ESCRIBIR')
where r.codigo = 'CAJA' on conflict do nothing;

-- Vincula usuarios importados cuando auth.users incluye username o legacy_user_id en metadata.
create or replace function public.handle_auth_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  requested_username text := lower(coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)));
  requested_legacy_id bigint := nullif(new.raw_user_meta_data ->> 'legacy_user_id', '')::bigint;
begin
  if requested_legacy_id is not null then
    update public.usuarios set auth_user_id = new.id, actualizado_en = now()
    where id = requested_legacy_id and auth_user_id is null;
  end if;
  if not found then
    update public.usuarios set auth_user_id = new.id, actualizado_en = now()
    where lower(username) = requested_username and auth_user_id is null;
  end if;
  if not found then
    insert into public.usuarios(auth_user_id, username, nombre_completo, email)
    values (new.id, requested_username,
      coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), requested_username),
      case when new.email like '%@auth.dental-americana.invalid' then null else new.email end);
  end if;
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_auth_user();

-- También vincula auth.users creados antes de aplicar esta migración.
update public.usuarios u set auth_user_id = a.id, actualizado_en = now()
from auth.users a
where u.auth_user_id is null
  and (u.id::text = a.raw_user_meta_data ->> 'legacy_user_id'
       or lower(u.username) = lower(coalesce(a.raw_user_meta_data ->> 'username', split_part(a.email, '@', 1))));

create or replace function public.current_app_user_id() returns bigint
language sql stable security definer set search_path = '' as $$
  select id from public.usuarios
  where auth_user_id = auth.uid() and activo and not bloqueado
  limit 1
$$;

create or replace function public.has_permission(permission_code text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.usuarios u
    join public.usuarios_roles ur on ur.usuario_id = u.id
    join public.roles r on r.id = ur.rol_id and r.activo
    join public.roles_permisos rp on rp.rol_id = r.id
    join public.permisos p on p.id = rp.permiso_id
    where u.auth_user_id = auth.uid() and u.activo and not u.bloqueado and p.codigo = permission_code
  )
$$;

create or replace function public.current_user_context() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', u.id,
    'username', u.username,
    'fullName', u.nombre_completo,
    'roles', coalesce((select jsonb_agg(distinct r.codigo order by r.codigo)
      from public.usuarios_roles ur join public.roles r on r.id = ur.rol_id
      where ur.usuario_id = u.id and r.activo), '[]'::jsonb),
    'permissions', coalesce((select jsonb_agg(distinct p.codigo order by p.codigo)
      from public.usuarios_roles ur join public.roles r on r.id = ur.rol_id and r.activo
      join public.roles_permisos rp on rp.rol_id = r.id
      join public.permisos p on p.id = rp.permiso_id where ur.usuario_id = u.id), '[]'::jsonb)
  )
  from public.usuarios u where u.auth_user_id = auth.uid() and u.activo and not u.bloqueado
$$;

create or replace function public.registrar_auditoria(
  accion_value text, recurso_value text, recurso_id_value text, detalle_value text default null
) returns void language plpgsql security definer set search_path = '' as $$
declare actor_id bigint := public.current_app_user_id(); actor_username text;
begin
  select username into actor_username from public.usuarios where id = actor_id;
  insert into public.auditoria(usuario_id, username, accion, recurso, recurso_id, resultado, detalle)
  values (actor_id, actor_username, accion_value, recurso_value, recurso_id_value, 'EXITO', detalle_value);
end;
$$;

alter table public.pacientes alter column creado_por set default public.current_app_user_id();
alter table public.pacientes alter column actualizado_por set default public.current_app_user_id();
alter table public.paciente_contactos_emergencia alter column creado_por set default public.current_app_user_id();
alter table public.paciente_antecedentes alter column creado_por set default public.current_app_user_id();
alter table public.paciente_alergias alter column creado_por set default public.current_app_user_id();
alter table public.paciente_medicamentos alter column creado_por set default public.current_app_user_id();
alter table public.paciente_archivos alter column creado_por set default public.current_app_user_id();

revoke all on function public.current_app_user_id() from public;
revoke all on function public.has_permission(text) from public;
revoke all on function public.current_user_context() from public;
revoke all on function public.registrar_auditoria(text, text, text, text) from public;
grant execute on function public.current_app_user_id() to authenticated;
grant execute on function public.has_permission(text) to authenticated;
grant execute on function public.current_user_context() to authenticated;
