INSERT INTO permisos (codigo, descripcion) VALUES
('IA_LEER', 'Consultar borradores y verificaciones del copiloto'),
('IA_ESCRIBIR', 'Generar borradores con el copiloto'),
('IA_APROBAR', 'Aprobar o rechazar borradores clínicos del copiloto');

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permisos p
WHERE r.codigo = 'ADMINISTRADOR' AND p.codigo IN ('IA_LEER','IA_ESCRIBIR','IA_APROBAR');

INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permisos p
WHERE r.codigo = 'ODONTOLOGO' AND p.codigo IN ('IA_LEER','IA_ESCRIBIR','IA_APROBAR');

CREATE TABLE borradores_ia (
    id BIGSERIAL PRIMARY KEY,
    atencion_id BIGINT NOT NULL REFERENCES atenciones_clinicas(id),
    paciente_id BIGINT NOT NULL REFERENCES pacientes(id),
    tipo VARCHAR(40) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'BORRADOR',
    contenido TEXT NOT NULL,
    datos_fuente JSONB NOT NULL,
    campos_faltantes JSONB NOT NULL DEFAULT '[]'::jsonb,
    advertencia VARCHAR(500) NOT NULL,
    motivo_rechazo VARCHAR(500),
    generado_por BIGINT NOT NULL REFERENCES usuarios(id),
    generado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revisado_por BIGINT REFERENCES usuarios(id),
    revisado_en TIMESTAMPTZ,
    version BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_borradores_ia_atencion ON borradores_ia(atencion_id, generado_en DESC);
CREATE INDEX idx_borradores_ia_estado ON borradores_ia(estado, generado_en DESC);
