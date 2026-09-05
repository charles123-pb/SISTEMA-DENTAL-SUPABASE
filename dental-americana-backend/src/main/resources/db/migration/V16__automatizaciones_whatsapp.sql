ALTER TABLE citas
    ADD COLUMN recordatorio_enviado BOOLEAN NOT NULL DEFAULT FALSE;

-- Versiones anteriores usaban este indicador al encolar la confirmacion inicial.
-- Desde esta migracion representa exclusivamente el recordatorio previo a la cita.
UPDATE citas SET recordatorio_programado = FALSE;

ALTER TABLE mensajes_whatsapp
    ADD COLUMN tipo VARCHAR(40) NOT NULL DEFAULT 'MANUAL',
    ADD COLUMN plantilla_nombre VARCHAR(120),
    ADD COLUMN parametros_plantilla JSONB NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN intentos INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN max_intentos INTEGER NOT NULL DEFAULT 3,
    ADD COLUMN ultimo_intento_en TIMESTAMPTZ;

UPDATE mensajes_whatsapp
SET tipo = CASE
    WHEN direccion = 'ENTRANTE' THEN 'ENTRANTE'
    WHEN cita_id IS NOT NULL THEN 'CITA_CONFIRMACION'
    WHEN atencion_id IS NOT NULL THEN 'POSTCONSULTA'
    ELSE 'MANUAL'
END;

ALTER TABLE mensajes_whatsapp
    ADD CONSTRAINT chk_mensaje_tipo CHECK (tipo IN (
        'ENTRANTE', 'CITA_CONFIRMACION', 'CITA_RECORDATORIO', 'POSTCONSULTA', 'MANUAL'
    )),
    ADD CONSTRAINT chk_mensaje_intentos CHECK (
        intentos >= 0 AND max_intentos BETWEEN 1 AND 10 AND intentos <= max_intentos
    );

CREATE UNIQUE INDEX uq_mensaje_proveedor
    ON mensajes_whatsapp(proveedor_id)
    WHERE proveedor_id IS NOT NULL;

CREATE INDEX idx_cita_recordatorio
    ON citas(recordatorio_programado, inicio)
    WHERE estado IN ('PENDIENTE_CONFIRMACION', 'CONFIRMADA');
