CREATE TABLE tipos_cita (
    id BIGSERIAL PRIMARY KEY,
    codigo VARCHAR(40) NOT NULL UNIQUE,
    nombre VARCHAR(100) NOT NULL,
    duracion_minutos INTEGER NOT NULL,
    color VARCHAR(10) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_tipo_cita_duracion CHECK (duracion_minutos BETWEEN 10 AND 480)
);

INSERT INTO tipos_cita (codigo, nombre, duracion_minutos, color) VALUES
('CONSULTA', 'Consulta y evaluación', 30, '#4A90A4'),
('LIMPIEZA', 'Profilaxis / limpieza', 45, '#41A77C'),
('RESTAURACION', 'Restauración dental', 60, '#7B61B3'),
('ENDODONCIA', 'Endodoncia', 90, '#D28B36'),
('EXTRACCION', 'Extracción', 60, '#D05B66'),
('PROTESIS', 'Prótesis / control', 45, '#3C77B6'),
('CONTROL', 'Control postratamiento', 20, '#6D8A99');

CREATE TABLE horarios_profesionales (
    id BIGSERIAL PRIMARY KEY,
    profesional_id BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    dia_semana SMALLINT NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    intervalo_minutos INTEGER NOT NULL DEFAULT 15,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_horario_dia CHECK (dia_semana BETWEEN 1 AND 7),
    CONSTRAINT chk_horario_horas CHECK (hora_fin > hora_inicio),
    CONSTRAINT chk_horario_intervalo CHECK (intervalo_minutos BETWEEN 5 AND 120),
    UNIQUE (profesional_id, dia_semana, hora_inicio, hora_fin)
);
CREATE INDEX idx_horario_profesional_dia ON horarios_profesionales(profesional_id, dia_semana, activo);

CREATE TABLE bloqueos_agenda (
    id BIGSERIAL PRIMARY KEY,
    profesional_id BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    inicio TIMESTAMPTZ NOT NULL,
    fin TIMESTAMPTZ NOT NULL,
    motivo VARCHAR(250) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_bloqueo_rango CHECK (fin > inicio)
);
CREATE INDEX idx_bloqueo_agenda_rango ON bloqueos_agenda(profesional_id, inicio, fin) WHERE activo = TRUE;

CREATE TABLE citas (
    id BIGSERIAL PRIMARY KEY,
    paciente_id BIGINT NOT NULL REFERENCES pacientes(id) ON DELETE RESTRICT,
    profesional_id BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    tipo_cita_id BIGINT NOT NULL REFERENCES tipos_cita(id) ON DELETE RESTRICT,
    inicio TIMESTAMPTZ NOT NULL,
    fin TIMESTAMPTZ NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE_CONFIRMACION',
    motivo VARCHAR(500) NOT NULL,
    notas VARCHAR(1000),
    origen VARCHAR(30) NOT NULL DEFAULT 'RECEPCION',
    motivo_cancelacion VARCHAR(500),
    confirmacion_enviada BOOLEAN NOT NULL DEFAULT FALSE,
    recordatorio_programado BOOLEAN NOT NULL DEFAULT FALSE,
    creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    actualizado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_cita_rango CHECK (fin > inicio),
    CONSTRAINT chk_cita_estado CHECK (estado IN ('PENDIENTE_CONFIRMACION','CONFIRMADA','EN_ESPERA','EN_ATENCION','COMPLETADA','CANCELADA','NO_ASISTIO')),
    CONSTRAINT chk_cita_origen CHECK (origen IN ('RECEPCION','WHATSAPP','WEB','ODONTOLOGO','SISTEMA'))
);
CREATE INDEX idx_cita_agenda ON citas(profesional_id, inicio, fin);
CREATE INDEX idx_cita_paciente ON citas(paciente_id, inicio DESC);
CREATE INDEX idx_cita_estado_inicio ON citas(estado, inicio);

CREATE TABLE cita_historial_estados (
    id BIGSERIAL PRIMARY KEY,
    cita_id BIGINT NOT NULL REFERENCES citas(id) ON DELETE RESTRICT,
    estado_anterior VARCHAR(30),
    estado_nuevo VARCHAR(30) NOT NULL,
    motivo VARCHAR(500),
    creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_cita_historial ON cita_historial_estados(cita_id, creado_en DESC);
