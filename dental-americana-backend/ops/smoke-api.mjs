// Read-only module checks, apart from the normal login audit event.
// DENTAL_BASE_URL=http://localhost DENTAL_USERNAME=... DENTAL_PASSWORD=... node ops/smoke-api.mjs
const base = (process.env.DENTAL_BASE_URL || 'http://localhost').replace(/\/$/, '');
const username = process.env.DENTAL_USERNAME;
const password = process.env.DENTAL_PASSWORD;
if (!username || !password) {
  console.error('Defina DENTAL_USERNAME y DENTAL_PASSWORD en el entorno. No se imprimen credenciales.');
  process.exit(2);
}
let token;
async function request(path, options = {}) {
  const response = await fetch(`${base}${path}`, {
    ...options,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...options.headers },
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}`);
  if (response.headers.get('content-type')?.includes('json')) return response.json();
  return response.text();
}
try {
  const health = await request('/actuator/health');
  if (health.status !== 'UP') throw new Error('El backend no está saludable');
  const login = await request('/api/v1/auth/login', {
    method: 'POST', body: JSON.stringify({ username, password }),
  });
  token = login.accessToken;
  if (!token) throw new Error('El login no devolvió un token');
  if (login.user.roles.length !== 1 || login.user.roles[0] !== 'ODONTOLOGO') {
    throw new Error('El usuario no tiene únicamente el rol ODONTOLOGO');
  }
  const from = new Date(Date.now() - 86400000).toISOString();
  const to = new Date(Date.now() + 86400000).toISOString();
  const range = new URLSearchParams({ from, to });
  const checks = [
    ['Sesión', '/api/v1/auth/me'],
    ['Pacientes', '/api/v1/patients?size=1'],
    ['Agenda', `/api/v1/appointments?${range}`],
    ['Profesionales', '/api/v1/appointments/professionals'],
    ['Tipos de cita', '/api/v1/appointment-types'],
    ['Atención clínica', `/api/v1/clinical-encounters?${range}`],
    ['Servicios', '/api/v1/services'],
    ['Finanzas', `/api/v1/finance/dashboard?${range}`],
    ['Cuentas', '/api/v1/finance/accounts'],
    ['Caja', '/api/v1/finance/cash/current'],
    ['Mensajes', '/api/v1/messaging/messages'],
    ['Seguimientos', '/api/v1/messaging/follow-ups'],
    ['Solicitudes web', '/api/v1/appointment-requests'],
    ['Configuración', '/api/v1/admin/settings'],
    ['Auditoría', `/api/v1/admin/audit?${range}`],
  ];
  let encounter;
  for (const [label, path] of checks) {
    const data = await request(path);
    if (label === 'Atención clínica') encounter = data[0];
    console.log(`OK ${label}`);
  }
  if (encounter) {
    for (const [label, path] of [
      ['Odontograma', `/api/v1/odontograms?encounterId=${encounter.id}`],
      ['Tratamientos', `/api/v1/treatment-plans?encounterId=${encounter.id}`],
      ['Copiloto', `/api/v1/copilot/drafts?encounterId=${encounter.id}`],
    ]) {
      await request(path);
      console.log(`OK ${label}`);
    }
  } else {
    console.log('SIN DATOS: odontograma, tratamiento y copiloto requieren una atención reciente.');
  }
  console.log('Consultas completadas. Esta prueba no crea historias, cobros ni mensajes.');
} catch (error) {
  console.error(`ERROR: ${error.message}`);
  process.exitCode = 1;
}
