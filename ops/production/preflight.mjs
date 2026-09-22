import { existsSync, readFileSync, statSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const directory = fileURLToPath(new URL('.', import.meta.url));
const envPath = resolve(directory, process.argv[2] ?? '.env');
const problems = [];

if (!existsSync(envPath)) {
  console.error('Falta ops/production/.env. Copia .env.example y completa los valores.');
  process.exit(1);
}
if (statSync(envPath).mode & 0o077) {
  problems.push('El archivo .env de producción debe tener permisos 0600');
}

const values = new Map();
for (const line of readFileSync(envPath, 'utf8').split(/\r?\n/)) {
  const match = line.match(/^([A-Z][A-Z0-9_]*)=(.*)$/);
  if (match) values.set(match[1], match[2].trim().replace(/^(['"])(.*)\1$/, '$2'));
}
const value = (name) => {
  const item = values.get(name) ?? '';
  if (!item || /REEMPLAZAR|YOUR_|su-dominio|example\.(com|org|net)|trycloudflare|localhost/i.test(item)) {
    problems.push(`${name}: falta un valor real de producción`);
    return '';
  }
  return item;
};

for (const name of ['NODE_IMAGE', 'NGINX_IMAGE', 'EVOLUTION_IMAGE',
  'POSTGRES_IMAGE', 'REDIS_IMAGE', 'CLOUDFLARED_IMAGE']) {
  const image = value(name);
  if (image && !/@sha256:[a-f0-9]{64}$/.test(image)) {
    problems.push(`${name}: fijar un digest sha256 válido, no una etiqueta móvil`);
  }
}

const origins = {};
for (const name of ['SUPABASE_ORIGIN', 'SUPABASE_WS_ORIGIN',
  'WEB_PUBLIC_ORIGIN', 'EVOLUTION_PUBLIC_ORIGIN']) {
  const raw = value(name);
  if (!raw) continue;
  try {
    const url = new URL(raw);
    const protocol = name === 'SUPABASE_WS_ORIGIN' ? 'wss:' : 'https:';
    if (url.protocol !== protocol || url.pathname !== '/' || url.search || url.hash || url.username || url.password) {
      problems.push(`${name}: usar solo el origen ${protocol}//dominio, sin ruta ni credenciales`);
    }
    origins[name] = url;
  } catch {
    problems.push(`${name}: URL inválida`);
  }
}
if (origins.SUPABASE_ORIGIN && origins.SUPABASE_WS_ORIGIN
  && origins.SUPABASE_ORIGIN.host !== origins.SUPABASE_WS_ORIGIN.host) {
  problems.push('SUPABASE_WS_ORIGIN debe usar el mismo dominio que SUPABASE_ORIGIN');
}
if (origins.WEB_PUBLIC_ORIGIN && origins.EVOLUTION_PUBLIC_ORIGIN
  && origins.WEB_PUBLIC_ORIGIN.host === origins.EVOLUTION_PUBLIC_ORIGIN.host) {
  problems.push('Web y Evolution deben usar hostnames distintos');
}

const apiKey = value('EVOLUTION_API_KEY');
if (apiKey && (apiKey.length < 32 || /\s/.test(apiKey))) {
  problems.push('EVOLUTION_API_KEY debe tener al menos 32 caracteres sin espacios');
}
const dbPassword = value('EVOLUTION_DB_PASSWORD');
if (dbPassword && !/^[A-Za-z0-9]{32,}$/.test(dbPassword)) {
  problems.push('EVOLUTION_DB_PASSWORD debe tener al menos 32 caracteres alfanuméricos');
}

const tunnelTokenFile = resolve(directory, 'secrets/cloudflare_tunnel_token');
if (!existsSync(tunnelTokenFile)) {
  problems.push('Falta secrets/cloudflare_tunnel_token para el túnel nombrado');
} else {
  const token = readFileSync(tunnelTokenFile, 'utf8').trim();
  if (token.length < 50) problems.push('El token del túnel parece incompleto');
  if (statSync(tunnelTokenFile).mode & 0o077) {
    problems.push('El token del túnel debe tener permisos 0600');
  }
}

const frontendPath = resolve(directory, '../../dental-americana-supabase/src/environments/environment.ts');
const frontend = readFileSync(frontendPath, 'utf8');
const frontendUrl = frontend.match(/supabaseUrl:\s*['"]([^'"]+)['"]/)?.[1];
const publicKey = frontend.match(/supabaseAnonKey:\s*['"]([^'"]+)['"]/)?.[1];
if (!/production:\s*true/.test(frontend)) problems.push('environment.ts debe tener production: true');
if (origins.SUPABASE_ORIGIN && frontendUrl !== origins.SUPABASE_ORIGIN.origin) {
  problems.push('SUPABASE_ORIGIN no coincide con environment.ts');
}
if (!publicKey || publicKey.length < 20 || /REEMPLAZAR|YOUR_/i.test(publicKey)) {
  problems.push('Falta la clave pública de Supabase en environment.ts');
}
const developmentPath = resolve(directory, '../../dental-americana-supabase/src/environments/environment.development.ts');
const development = readFileSync(developmentPath, 'utf8');
const developmentUrl = development.match(/supabaseUrl:\s*['"]([^'"]+)['"]/)?.[1];
if (origins.SUPABASE_ORIGIN && developmentUrl === origins.SUPABASE_ORIGIN.origin) {
  problems.push('Desarrollo y producción comparten Supabase: separar los proyectos antes del lanzamiento');
}

if (problems.length) {
  for (const problem of problems) console.error(`- ${problem}`);
  process.exit(1);
}
console.log('Preflight local aprobado: imágenes fijadas, URLs estables y secretos presentes.');
console.log('Faltan las verificaciones manuales de Supabase, Cloudflare, respaldos y prueba controlada.');
