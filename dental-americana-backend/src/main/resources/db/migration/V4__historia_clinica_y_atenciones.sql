CREATE TABLE atenciones_clinicas (
    id BIGSERIAL PRIMARY KEY,
    paciente_id BIGINT NOT NULL REFERENCES pacientes(id) ON DELETE RESTRICT,
    cita_id BIGINT UNIQUE REFERENCES citas(id) ON DELETE RESTRICT,
    odontologo_id BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    fecha_atencion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(20) NOT NULL DEFAULT 'BORRADOR',
    motivo_consulta VARCHAR(1000),
    tiempo_enfermedad VARCHAR(250),
    signos_sintomas VARCHAR(1500),
    relato_cronologico TEXT,
    presion_sistolica SMALLINT,
    presion_diastolica SMALLINT,
    pulso SMALLINT,
    temperatura NUMERIC(4,1),
    frecuencia_respiratoria SMALLINT,
    peso_kg NUMERIC(5,2),
    talla_cm NUMERIC(5,2),
    examen_general TEXT,
    examen_odontologico TEXT,
    diagnostico TEXT,
    plan_trabajo TEXT,
    pronostico VARCHAR(500),
    evolucion TEXT,
    indicaciones TEXT,
    fecha_proximo_control DATE,
    alta_paciente BOOLEAN NOT NULL DEFAULT FALSE,
    observacion_alta VARCHAR(1000),
    consentimiento_paciente BOOLEAN NOT NULL DEFAULT FALSE,
    aprobado_por BIGINT REFERENCES usuarios(id) ON DELETE RESTRICT,
    aprobado_en TIMESTAMPTZ,
    creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    actualizado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_atencion_estado CHECK (estado IN ('BORRADOR','FINALIZADA','ANULADA')),
    CONSTRAINT chk_atencion_pa CHECK (presion_sistolica IS NULL OR presion_sistolica BETWEEN 40 AND 300),
    CONSTRAINT chk_atencion_pad CHECK (presion_diastolica IS NULL OR presion_diastolica BETWEEN 20 AND 200),
    CONSTRAINT chk_atencion_pulso CHECK (pulso IS NULL OR pulso BETWEEN 20 AND 250),
    CONSTRAINT chk_atencion_temperatura CHECK (temperatura IS NULL OR temperatura BETWEEN 30 AND 45),
    CONSTRAINT chk_atencion_fr CHECK (frecuencia_respiratoria IS NULL OR frecuencia_respiratoria BETWEEN 5 AND 80),
    CONSTRAINT chk_atencion_aprobacion CHECK (
        (estado = 'FINALIZADA' AND aprobado_por IS NOT NULL AND aprobado_en IS NOT NULL)
        OR estado <> 'FINALIZADA'
    )
);
CREATE INDEX idx_atencion_paciente_fecha ON atenciones_clinicas(paciente_id, fecha_atencion DESC);
CREATE INDEX idx_atencion_odontologo_fecha ON atenciones_clinicas(odontologo_id, fecha_atencion DESC);
CREATE INDEX idx_atencion_estado_fecha ON atenciones_clinicas(estado, fecha_atencion DESC);

CREATE TABLE atencion_versiones (
    id BIGSERIAL PRIMARY KEY,
    atencion_id BIGINT NOT NULL REFERENCES atenciones_clinicas(id) ON DELETE RESTRICT,
    numero_version BIGINT NOT NULL,
    accion VARCHAR(30) NOT NULL,
    resumen TEXT,
    datos JSONB NOT NULL,
    creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (atencion_id, numero_version, accion)
);
CREATE INDEX idx_atencion_version ON atencion_versiones(atencion_id, creado_en DESC);
