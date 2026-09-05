CREATE SEQUENCE patient_history_number_seq START WITH 1 INCREMENT BY 1;

CREATE TABLE pacientes (
    id BIGSERIAL PRIMARY KEY,
    numero_historia VARCHAR(20) NOT NULL UNIQUE,
    tipo_documento VARCHAR(20) NOT NULL,
    numero_documento VARCHAR(20),
    nombres VARCHAR(100) NOT NULL,
    apellido_paterno VARCHAR(80) NOT NULL,
    apellido_materno VARCHAR(80),
    fecha_nacimiento DATE NOT NULL,
    sexo VARCHAR(20) NOT NULL,
    lugar_nacimiento VARCHAR(150),
    ocupacion VARCHAR(120),
    estado_civil VARCHAR(30),
    grado_instruccion VARCHAR(60),
    religion VARCHAR(80),
    autoidentificacion_etnica VARCHAR(100),
    celular VARCHAR(20),
    telefono VARCHAR(20),
    email VARCHAR(150),
    direccion VARCHAR(250),
    responsable_nombre VARCHAR(150),
    responsable_documento VARCHAR(20),
    responsable_parentesco VARCHAR(60),
    responsable_telefono VARCHAR(20),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    actualizado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_paciente_documento CHECK (
        (tipo_documento = 'SIN_DOCUMENTO' AND numero_documento IS NULL)
        OR (tipo_documento <> 'SIN_DOCUMENTO' AND numero_documento IS NOT NULL)
    )
);

CREATE UNIQUE INDEX uq_paciente_numero_documento
    ON pacientes (numero_documento)
    WHERE numero_documento IS NOT NULL AND btrim(numero_documento) <> '';
CREATE INDEX idx_paciente_nombre ON pacientes (lower(apellido_paterno), lower(apellido_materno), lower(nombres));
CREATE INDEX idx_paciente_celular ON pacientes (celular);
CREATE INDEX idx_paciente_activo_creado ON pacientes (activo, creado_en DESC);

CREATE TABLE paciente_contactos_emergencia (
    id BIGSERIAL PRIMARY KEY,
    paciente_id BIGINT NOT NULL REFERENCES pacientes(id) ON DELETE RESTRICT,
    nombre_completo VARCHAR(150) NOT NULL,
    parentesco VARCHAR(60) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    principal BOOLEAN NOT NULL DEFAULT FALSE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT
);
CREATE INDEX idx_contacto_emergencia_paciente ON paciente_contactos_emergencia(paciente_id, activo);

CREATE TABLE paciente_antecedentes (
    id BIGSERIAL PRIMARY KEY,
    paciente_id BIGINT NOT NULL REFERENCES pacientes(id) ON DELETE RESTRICT,
    tipo VARCHAR(30) NOT NULL,
    descripcion VARCHAR(500) NOT NULL,
    estado VARCHAR(30) NOT NULL DEFAULT 'ACTIVO',
    observacion VARCHAR(1000),
    fecha_informada DATE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    version BIGINT NOT NULL DEFAULT 0
);
CREATE INDEX idx_antecedente_paciente ON paciente_antecedentes(paciente_id, activo, creado_en DESC);

CREATE TABLE paciente_alergias (
    id BIGSERIAL PRIMARY KEY,
    paciente_id BIGINT NOT NULL REFERENCES pacientes(id) ON DELETE RESTRICT,
    sustancia VARCHAR(150) NOT NULL,
    reaccion VARCHAR(300),
    severidad VARCHAR(20) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVA',
    observacion VARCHAR(1000),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_alergia_severidad CHECK (severidad IN ('LEVE','MODERADA','SEVERA')),
    CONSTRAINT chk_alergia_estado CHECK (estado IN ('ACTIVA','INACTIVA','DESCARTADA'))
);
CREATE INDEX idx_alergia_paciente ON paciente_alergias(paciente_id, activo, estado);

CREATE TABLE paciente_medicamentos (
    id BIGSERIAL PRIMARY KEY,
    paciente_id BIGINT NOT NULL REFERENCES pacientes(id) ON DELETE RESTRICT,
    medicamento VARCHAR(180) NOT NULL,
    dosis VARCHAR(100),
    frecuencia VARCHAR(100),
    motivo VARCHAR(250),
    fecha_inicio DATE,
    fecha_fin DATE,
    vigente BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_medicamento_fechas CHECK (fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio)
);
CREATE INDEX idx_medicamento_paciente ON paciente_medicamentos(paciente_id, activo, vigente);

CREATE TABLE paciente_archivos (
    id BIGSERIAL PRIMARY KEY,
    paciente_id BIGINT NOT NULL REFERENCES pacientes(id) ON DELETE RESTRICT,
    categoria VARCHAR(30) NOT NULL,
    nombre_original VARCHAR(255) NOT NULL,
    nombre_interno VARCHAR(255) NOT NULL UNIQUE,
    tipo_contenido VARCHAR(100) NOT NULL,
    tamano_bytes BIGINT NOT NULL,
    ubicacion VARCHAR(500) NOT NULL,
    descripcion VARCHAR(300),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    CONSTRAINT chk_archivo_tamano CHECK (tamano_bytes > 0 AND tamano_bytes <= 10485760)
);
CREATE INDEX idx_archivo_paciente ON paciente_archivos(paciente_id, activo, creado_en DESC);
