CREATE TABLE solicitudes_cita_web (
    id BIGSERIAL PRIMARY KEY,
    nombre_completo VARCHAR(150) NOT NULL,
    numero_documento VARCHAR(20),
    celular VARCHAR(20) NOT NULL,
    email VARCHAR(150),
    servicio VARCHAR(120) NOT NULL,
    fecha_preferida DATE,
    turno_preferido VARCHAR(20),
    mensaje VARCHAR(800),
    consentimiento_privacidad BOOLEAN NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE',
    observacion_interna VARCHAR(500),
    cita_id BIGINT REFERENCES citas(id),
    atendido_por BIGINT REFERENCES usuarios(id),
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0
);
CREATE INDEX idx_solicitudes_web_estado ON solicitudes_cita_web(estado, creado_en DESC);
