-- Modelo operativo de la clínica: un único rol con acceso integral.
-- Se conservan los registros históricos, pero solo ODONTOLOGO queda activo.
INSERT INTO roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM roles r CROSS JOIN permisos p
WHERE r.codigo = 'ODONTOLOGO'
ON CONFLICT DO NOTHING;

-- Los usuarios existentes pasan a operar con el único rol habilitado.
INSERT INTO usuarios_roles (usuario_id, rol_id)
SELECT u.id, r.id
FROM usuarios u CROSS JOIN roles r
WHERE r.codigo = 'ODONTOLOGO'
ON CONFLICT DO NOTHING;

DELETE FROM usuarios_roles ur
USING roles r
WHERE ur.rol_id = r.id
  AND r.codigo <> 'ODONTOLOGO';

UPDATE roles
SET activo = (codigo = 'ODONTOLOGO');
