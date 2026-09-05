-- Alinea los tipos SQL con los campos Integer/int del modelo JPA.
ALTER TABLE atenciones_clinicas
    ALTER COLUMN presion_sistolica TYPE INTEGER,
    ALTER COLUMN presion_diastolica TYPE INTEGER,
    ALTER COLUMN pulso TYPE INTEGER,
    ALTER COLUMN frecuencia_respiratoria TYPE INTEGER;

ALTER TABLE horarios_profesionales
    ALTER COLUMN dia_semana TYPE INTEGER;
