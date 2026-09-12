# Sistema Web Integral Dental Americana — Supabase

Aplicación Angular 21 independiente conectada directamente a Supabase Auth, PostgreSQL/RPC, Storage,
Realtime y Edge Functions. No necesita el backend Spring ni un proxy `/api`.

Incluye página pública, agenda y solicitudes, pacientes, historia clínica, odontograma, tratamientos,
presupuestos, caja, WhatsApp/seguimientos, copiloto supervisado y administración.

## Desarrollo local

Desde la raíz del repositorio:

```bash
npx supabase start
npx supabase db reset
cd dental-americana-supabase
npm ci
npm start
```

Abra `http://localhost:4200`. Para probar Edge Functions, copie
`../supabase/functions/.env.example` como `../supabase/functions/.env` y ejecute desde la raíz:

```bash
npx supabase functions serve
```

## Validación

```bash
npm run test:ci -- --coverage=false
npm run build
```

Estado verificado: 9 archivos de prueba, 17 pruebas aprobadas y compilación de producción correcta.

## Producción

Sustituya `YOUR_PROJECT_REF` y `YOUR_SUPABASE_ANON_KEY` en
`src/environments/environment.ts`, despliegue el bundle o la imagen Docker y registre el dominio en las
URL permitidas de Supabase Auth. No coloque `service_role`, credenciales de Evolution API ni claves de IA en Angular.

Consulte `../GUIA_CONEXION_SUPABASE_WHATSAPP.md` para el despliegue y la conexión de WhatsApp.
