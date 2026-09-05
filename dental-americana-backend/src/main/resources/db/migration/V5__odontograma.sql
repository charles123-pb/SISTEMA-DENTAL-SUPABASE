CREATE TABLE odontogramas (
    id BIGSERIAL PRIMARY KEY,
    atencion_id BIGINT NOT NULL REFERENCES atenciones_clinicas(id) ON DELETE RESTRICT,
    paciente_id BIGINT NOT NULL REFERENCES pacientes(id) ON DELETE RESTRICT,
    tipo_denticion VARCHAR(20) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'BORRADOR',
    observacion_general TEXT,
    aprobado_por BIGINT REFERENCES usuarios(id) ON DELETE RESTRICT,
    aprobado_en TIMESTAMPTZ,
    creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    actualizado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_odontograma_denticion CHECK (tipo_denticion IN ('PERMANENTE','INFANTIL')),
    CONSTRAINT chk_odontograma_estado CHECK (estado IN ('BORRADOR','APROBADO')),
    UNIQUE (atencion_id, tipo_denticion)
);
CREATE INDEX idx_odontograma_paciente ON odontogramas(paciente_id, creado_en DESC);

CREATE TABLE odontograma_hallazgos (
    id BIGSERIAL PRIMARY KEY,
    odontograma_id BIGINT NOT NULL REFERENCES odontogramas(id) ON DELETE RESTRICT,
    pieza VARCHAR(3) NOT NULL,
    superficie VARCHAR(30) NOT NULL,
    condicion VARCHAR(40) NOT NULL,
    estado_tratamiento VARCHAR(20) NOT NULL DEFAULT 'EXISTENTE',
    observacion VARCHAR(500),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    actualizado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_hallazgo_superficie CHECK (superficie IN ('GENERAL','OCLUSAL','MESIAL','DISTAL','VESTIBULAR','LINGUAL_PALATINA')),
    CONSTRAINT chk_hallazgo_estado CHECK (estado_tratamiento IN ('EXISTENTE','INDICADO','REALIZADO'))
);
CREATE UNIQUE INDEX uq_odontograma_hallazgo_activo ON odontograma_hallazgos(odontograma_id, pieza, superficie, condicion) WHERE activo = TRUE;
CREATE INDEX idx_hallazgo_odontograma ON odontograma_hallazgos(odontograma_id, activo, pieza);

CREATE TABLE odontograma_versiones (
    id BIGSERIAL PRIMARY KEY,
    odontograma_id BIGINT NOT NULL REFERENCES odontogramas(id) ON DELETE RESTRICT,
    numero_version BIGINT NOT NULL,
    resumen VARCHAR(500) NOT NULL,
    datos JSONB NOT NULL,
    creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_odontograma_version ON odontograma_versiones(odontograma_id, creado_en DESC);
