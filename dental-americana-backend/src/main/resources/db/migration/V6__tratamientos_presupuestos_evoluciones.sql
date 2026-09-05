CREATE TABLE servicios (
    id BIGSERIAL PRIMARY KEY, codigo VARCHAR(40) NOT NULL UNIQUE, nombre VARCHAR(150) NOT NULL,
    categoria VARCHAR(80) NOT NULL, descripcion VARCHAR(500), precio_base NUMERIC(12,2) NOT NULL,
    sesiones_sugeridas INTEGER NOT NULL DEFAULT 1, activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0, CONSTRAINT chk_servicio_precio CHECK(precio_base>=0),
    CONSTRAINT chk_servicio_sesiones CHECK(sesiones_sugeridas BETWEEN 1 AND 50)
);
INSERT INTO servicios(codigo,nombre,categoria,precio_base,sesiones_sugeridas)VALUES
('CONSULTA','Consulta odontológica','Diagnóstico',50,1),('PROFILAXIS','Profilaxis dental','Prevención',100,1),
('BLANQUEAMIENTO','Blanqueamiento dental','Estética',450,2),('RESTAURACION_SIMPLE','Restauración simple','Restauradora',120,1),
('RESTAURACION_COMPUESTA','Restauración compuesta','Restauradora',180,1),('ENDODONCIA_ANTERIOR','Endodoncia anterior','Endodoncia',450,2),
('ENDODONCIA_MOLAR','Endodoncia molar','Endodoncia',650,3),('EXTRACCION_SIMPLE','Extracción simple','Cirugía',150,1),
('EXTRACCION_COMPLEJA','Extracción compleja','Cirugía',350,1),('CORONA','Corona dental','Prótesis',850,3),
('PROTESIS_PARCIAL','Prótesis parcial','Prótesis',1200,4),('RADIOGRAFIA','Radiografía dental','Diagnóstico',40,1);

CREATE TABLE planes_tratamiento (
    id BIGSERIAL PRIMARY KEY, paciente_id BIGINT NOT NULL REFERENCES pacientes(id) ON DELETE RESTRICT,
    atencion_id BIGINT REFERENCES atenciones_clinicas(id) ON DELETE RESTRICT, codigo VARCHAR(30) NOT NULL UNIQUE,
    estado VARCHAR(20) NOT NULL DEFAULT 'BORRADOR', descuento NUMERIC(12,2) NOT NULL DEFAULT 0,
    subtotal NUMERIC(12,2) NOT NULL DEFAULT 0, total NUMERIC(12,2) NOT NULL DEFAULT 0,
    observaciones VARCHAR(1000), aceptado_por_paciente BOOLEAN NOT NULL DEFAULT FALSE,
    aceptado_en TIMESTAMPTZ, creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    actualizado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0, CONSTRAINT chk_plan_estado CHECK(estado IN('BORRADOR','PRESENTADO','ACEPTADO','RECHAZADO','EN_PROCESO','COMPLETADO','CANCELADO')),
    CONSTRAINT chk_plan_montos CHECK(descuento>=0 AND subtotal>=0 AND total>=0 AND total=subtotal-descuento)
);
CREATE INDEX idx_plan_paciente ON planes_tratamiento(paciente_id,creado_en DESC);

CREATE TABLE plan_tratamiento_items (
    id BIGSERIAL PRIMARY KEY, plan_id BIGINT NOT NULL REFERENCES planes_tratamiento(id) ON DELETE RESTRICT,
    servicio_id BIGINT NOT NULL REFERENCES servicios(id) ON DELETE RESTRICT, pieza VARCHAR(3), descripcion VARCHAR(500) NOT NULL,
    cantidad INTEGER NOT NULL DEFAULT 1, precio_unitario NUMERIC(12,2) NOT NULL, sesiones INTEGER NOT NULL DEFAULT 1,
    estado VARCHAR(20) NOT NULL DEFAULT 'PROPUESTO', activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    actualizado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0, CONSTRAINT chk_item_cantidad CHECK(cantidad BETWEEN 1 AND 99),
    CONSTRAINT chk_item_precio CHECK(precio_unitario>=0),CONSTRAINT chk_item_sesiones CHECK(sesiones BETWEEN 1 AND 50),
    CONSTRAINT chk_item_estado CHECK(estado IN('PROPUESTO','ACEPTADO','EN_PROCESO','COMPLETADO','CANCELADO'))
);
CREATE INDEX idx_plan_item ON plan_tratamiento_items(plan_id,activo,estado);

CREATE TABLE evoluciones_tratamiento (
    id BIGSERIAL PRIMARY KEY, plan_item_id BIGINT NOT NULL REFERENCES plan_tratamiento_items(id) ON DELETE RESTRICT,
    atencion_id BIGINT REFERENCES atenciones_clinicas(id) ON DELETE RESTRICT, fecha TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    procedimiento_realizado TEXT NOT NULL, observaciones TEXT, proxima_sesion DATE,
    aprobado_por BIGINT NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_evolucion_item ON evoluciones_tratamiento(plan_item_id,fecha DESC);
