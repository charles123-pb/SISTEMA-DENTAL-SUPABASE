CREATE TABLE configuracion_sistema (
    clave VARCHAR(80) PRIMARY KEY,
    valor VARCHAR(500) NOT NULL,
    descripcion VARCHAR(250) NOT NULL,
    actualizado_por BIGINT REFERENCES usuarios(id),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0
);

INSERT INTO configuracion_sistema (clave,valor,descripcion) VALUES
('clinica.nombre','Consultorio Dental Americana','Nombre comercial mostrado en documentos y pantallas'),
('clinica.ruc','','RUC del consultorio; completar antes de emitir documentos'),
('clinica.direccion','Av. Mariscal Cáceres N.° 1072, 2.° nivel, Ayacucho','Dirección pública del establecimiento'),
('clinica.telefono','940 577 075','Número principal de contacto'),
('clinica.horario','Lunes a sábado, previa cita','Horario público de atención'),
('clinica.zona_horaria','America/Lima','Zona horaria usada por agenda y recordatorios');
