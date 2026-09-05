ALTER TABLE pacientes
    ADD COLUMN whatsapp_autorizado BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN whatsapp_autorizado_en TIMESTAMPTZ,
    ADD COLUMN whatsapp_autorizado_por BIGINT REFERENCES usuarios(id) ON DELETE RESTRICT,
    ADD COLUMN whatsapp_revocado_en TIMESTAMPTZ;

ALTER TABLE pacientes
    ADD CONSTRAINT chk_paciente_whatsapp_consentimiento CHECK (
        (whatsapp_autorizado = FALSE)
        OR (whatsapp_autorizado_en IS NOT NULL AND whatsapp_autorizado_por IS NOT NULL)
    );
