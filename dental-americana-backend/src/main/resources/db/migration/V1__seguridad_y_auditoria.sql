CREATE TABLE roles (
    id BIGSERIAL PRIMARY KEY,
    codigo VARCHAR(40) NOT NULL UNIQUE,
    nombre VARCHAR(80) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE permisos (
    id BIGSERIAL PRIMARY KEY,
    codigo VARCHAR(60) NOT NULL UNIQUE,
    descripcion VARCHAR(250) NOT NULL
);

CREATE TABLE usuarios (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(60) NOT NULL UNIQUE,
    password_hash VARCHAR(100) NOT NULL,
    nombre_completo VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    bloqueado BOOLEAN NOT NULL DEFAULT FALSE,
    intentos_fallidos INTEGER NOT NULL DEFAULT 0,
    ultimo_acceso TIMESTAMPTZ,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE usuarios_roles (
    usuario_id BIGINT NOT NULL REFERENCES usuarios(id),
    rol_id BIGINT NOT NULL REFERENCES roles(id),
    PRIMARY KEY (usuario_id, rol_id)
);

CREATE TABLE roles_permisos (
    rol_id BIGINT NOT NULL REFERENCES roles(id),
    permiso_id BIGINT NOT NULL REFERENCES permisos(id),
    PRIMARY KEY (rol_id, permiso_id)
);

CREATE TABLE auditoria (
    id BIGSERIAL PRIMARY KEY,
    usuario_id BIGINT REFERENCES usuarios(id),
    username VARCHAR(60),
    accion VARCHAR(80) NOT NULL,
    recurso VARCHAR(80) NOT NULL,
    recurso_id VARCHAR(80),
    resultado VARCHAR(20) NOT NULL,
    ip VARCHAR(64),
    user_agent VARCHAR(300),
    detalle TEXT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_auditoria_usuario ON auditoria(usuario_id);
CREATE INDEX idx_auditoria_fecha ON auditoria(creado_en DESC);
CREATE INDEX idx_auditoria_recurso ON auditoria(recurso, recurso_id);

INSERT INTO roles (codigo, nombre, descripcion) VALUES
('ADMINISTRADOR', 'Administrador', 'Acceso completo y configuración del sistema'),
('RECEPCION', 'Recepción', 'Pacientes, agenda y seguimiento administrativo'),
('ODONTOLOGO', 'Odontólogo', 'Atención clínica, diagnóstico y tratamiento'),
('CAJA', 'Caja', 'Cobros, gastos, cierres y reportes financieros');

INSERT INTO permisos (codigo, descripcion) VALUES
('USUARIO_LEER', 'Consultar usuarios y roles'),
('USUARIO_ESCRIBIR', 'Crear y modificar usuarios y roles'),
('PACIENTE_LEER', 'Consultar pacientes'),
('PACIENTE_ESCRIBIR', 'Registrar y actualizar pacientes'),
('CITA_LEER', 'Consultar agenda y citas'),
('CITA_ESCRIBIR', 'Crear, confirmar, reprogramar y cancelar citas'),
('CLINICA_LEER', 'Consultar información clínica autorizada'),
('CLINICA_ESCRIBIR', 'Crear borradores y registros clínicos'),
('CLINICA_APROBAR', 'Finalizar y aprobar registros clínicos'),
('TRATAMIENTO_LEER', 'Consultar tratamientos y presupuestos'),
('TRATAMIENTO_ESCRIBIR', 'Crear tratamientos y presupuestos'),
('FINANZA_LEER', 'Consultar saldos, caja y reportes'),
('FINANZA_ESCRIBIR', 'Registrar pagos, gastos y cierres'),
('SEGUIMIENTO_LEER', 'Consultar mensajes y seguimientos'),
('SEGUIMIENTO_ESCRIBIR', 'Programar y responder seguimientos'),
('AUDITORIA_LEER', 'Consultar la trazabilidad del sistema'),
('AJUSTE_ESCRIBIR', 'Modificar la configuración general');

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permisos p WHERE r.codigo = 'ADMINISTRADOR';

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r JOIN permisos p ON p.codigo IN
('PACIENTE_LEER','PACIENTE_ESCRIBIR','CITA_LEER','CITA_ESCRIBIR','SEGUIMIENTO_LEER','SEGUIMIENTO_ESCRIBIR')
WHERE r.codigo = 'RECEPCION';

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r JOIN permisos p ON p.codigo IN
('PACIENTE_LEER','CITA_LEER','CLINICA_LEER','CLINICA_ESCRIBIR','CLINICA_APROBAR',
 'TRATAMIENTO_LEER','TRATAMIENTO_ESCRIBIR','SEGUIMIENTO_LEER','SEGUIMIENTO_ESCRIBIR')
WHERE r.codigo = 'ODONTOLOGO';

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r JOIN permisos p ON p.codigo IN
('PACIENTE_LEER','FINANZA_LEER','FINANZA_ESCRIBIR')
WHERE r.codigo = 'CAJA';
