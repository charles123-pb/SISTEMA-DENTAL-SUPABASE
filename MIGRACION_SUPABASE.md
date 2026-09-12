# Arquitectura Supabase — Sistema Dental Americana

## Resultado

`dental-americana-supabase/` es una aplicación Angular 21 independiente. Usa Supabase Auth como única
sesión, PostgreSQL/RPC para reglas transaccionales, RLS para autorización, Storage para archivos,
Realtime para agenda/seguimientos y Edge Functions para operaciones que necesitan secretos. No consume
Spring ni rutas `/api`.

```text
Angular
  ├─ Supabase Auth ── usuarios / roles / permisos
  ├─ PostgREST + RPC ── pacientes, agenda, clínica, tratamientos, caja y auditoría
  ├─ Storage privado ── patient-files
  ├─ Realtime ── citas, mensajes y seguimientos
  └─ Edge Functions
       ├─ whatsapp-send / whatsapp-dispatch / whatsapp-webhook ── Meta Cloud API
       ├─ copilot-generate ── proveedor IA opcional
       └─ admin-create-user ── Supabase Admin Auth
```

La clave pública de Supabase es la única credencial presente en el bundle Angular. `service_role`, el
token y secreto de Meta y la clave de IA solo existen como secretos de Edge Functions.

## Modelo conservado

Se conservaron las claves numéricas y relaciones de las migraciones originales. `auth.users` se enlaza
1─1 con `public.usuarios.auth_user_id`; los profesionales son usuarios con rol `ODONTOLOGO`; el
presupuesto es `planes_tratamiento` más sus ítems.

| Dominio | Tablas principales |
|---|---|
| Seguridad | `usuarios`, `roles`, `permisos`, asignaciones y `auditoria` |
| Pacientes | `pacientes`, contactos, antecedentes, alergias, medicamentos y archivos |
| Agenda | tipos, horarios, bloqueos, `citas`, historial y solicitudes web |
| Clínica | `atenciones_clinicas`, versiones, odontogramas y hallazgos |
| Tratamientos | servicios, planes, ítems y evoluciones |
| Finanzas | cuentas, caja, pagos, gastos y movimientos |
| Mensajería | plantillas, conversaciones, mensajes y seguimientos postconsulta |
| IA / administración | borradores supervisados y configuración del sistema |

## Reglas críticas implementadas

- RLS está activa en las tablas funcionales y las operaciones sensibles pasan por RPC con permiso.
- No existe borrado físico normal de pacientes, historias, pagos o auditoría.
- Citas, historias, odontogramas, planes, caja, seguimientos y borradores usan versionado o transacciones.
- Una atención solo finaliza con consentimiento y aprobación profesional; la IA solo crea borradores.
- WhatsApp exige autorización registrada y celular válido, cancela mensajes al reprogramar o finalizar,
  genera recordatorios 24 horas antes y deriva respuestas ambiguas o alertas a revisión.
- El webhook valida la firma HMAC de Meta y normaliza estados `sent/delivered/read/failed`.
- Los mensajes automáticos usan plantillas aprobadas; los secretos nunca llegan al navegador.

## Migraciones y funciones

Las 24 migraciones ejecutables están en `supabase/migrations/`. Las cinco funciones están en
`supabase/functions/`. Para reconstruir el entorno local:

```bash
npx supabase start
npx supabase db reset
npx supabase functions serve
```

## Verificación realizada

- Las 24 migraciones se aplicaron desde cero en PostgreSQL 17 local.
- La prueba integral recorrió pacientes, agenda, historia, odontograma, tratamientos, cuenta por cobrar,
  caja/pago, seguimiento, copiloto y administración.
- La prueba de WhatsApp verificó confirmación, recordatorio, reprogramación e intención `CONFIRMO`.
- Las cinco Edge Functions iniciaron en Supabase Edge Runtime sin errores de carga.
- Angular: 9 archivos de prueba, 17/17 pruebas aprobadas y build de producción correcto.

Un envío real a Meta y un despliegue remoto requieren las cuentas y credenciales del propietario. Esas
acciones se explican en `GUIA_CONEXION_SUPABASE_WHATSAPP.md` y no deben automatizarse con claves de
ejemplo.
