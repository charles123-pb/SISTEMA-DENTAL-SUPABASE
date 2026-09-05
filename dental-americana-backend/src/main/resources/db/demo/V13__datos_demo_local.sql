-- Datos de demostración. Solo se incluye en el perfil local; producción usa db/migration.
INSERT INTO solicitudes_cita_web
    (nombre_completo, numero_documento, celular, email, servicio, fecha_preferida,
     turno_preferido, mensaje, consentimiento_privacidad, estado)
VALUES
    ('Ana Torres', '70000001', '999111222', 'ana.torres.demo@example.com',
     'Evaluación general', CURRENT_DATE + 3, 'TARDE',
     'Primera consulta de evaluación.', TRUE, 'PENDIENTE'),
    ('Luis Mendoza', '70000002', '999333444', 'luis.mendoza.demo@example.com',
     'Profilaxis dental', CURRENT_DATE + 5, 'MAÑANA',
     'Desea limpieza y revisión preventiva.', TRUE, 'PENDIENTE'),
    ('Carla Quispe', '70000003', '999555666', 'carla.quispe.demo@example.com',
     'Consulta odontológica', CURRENT_DATE + 7, 'TARDE',
     'Consulta por sensibilidad dental.', TRUE, 'PENDIENTE');
