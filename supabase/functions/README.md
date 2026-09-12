# Edge Functions

- `whatsapp-session`: consulta la conexión y genera el QR de Evolution API; requiere usuario autenticado.
- `whatsapp-send`: envío manual y reintentos mediante Evolution API; requiere usuario autenticado.
- `whatsapp-dispatch`: cola, confirmaciones, recordatorios y reintentos; protegido por `x-cron-secret`.
- `whatsapp-webhook`: recibe estados, conexión y mensajes de Evolution API; protegido por secreto.
- `whatsapp-sync`: importa de forma idempotente chats y mensajes existentes de Evolution API.
- `copilot-generate`: generación de borradores; nunca aprueba ni modifica la historia clínica.
- `admin-create-user`: alta de un odontólogo mediante Admin Auth sin exponer la clave privilegiada.

Los secretos de producción se guardan en Supabase, no en Angular ni en Git. Para desarrollo local,
copie `.env.example` como `.env` y ejecute:

```bash
npx supabase functions serve
```

La guía de conexión completa está en `../../GUIA_CONEXION_SUPABASE_WHATSAPP.md`.
