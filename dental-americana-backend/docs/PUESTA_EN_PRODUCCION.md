# Puesta en producción y automatizaciones

## Automatizaciones incluidas

| Evento | Acción automática | Control de seguridad |
|---|---|---|
| Se crea o reprograma una cita | Encola confirmación por WhatsApp | Solo pacientes con autorización vigente |
| Faltan 24 horas para la cita | Encola un recordatorio | Evita duplicados y cancela mensajes de horarios anteriores |
| El paciente responde `CONFIRMO` | Confirma su próxima cita pendiente | Registra el cambio en el historial de la cita |
| El paciente solicita cancelar o cambiar | Deriva la conversación para revisión | No cambia la agenda automáticamente |
| Se finaliza una atención | Programa seguimiento postconsulta a 24 horas | No diagnostica; el odontólogo revisa las respuestas |
| Se detectan palabras de alarma | Marca seguimiento como alerta | Nunca responde ni diagnostica automáticamente |
| Meta informa entrega o lectura | Actualiza el estado del mensaje | Webhook firmado con el secreto de la aplicación |
| Meta o la red fallan temporalmente | Reintenta a 1, 5 y 30 minutos | Máximo configurable; los errores definitivos quedan visibles |

## Datos necesarios para Meta WhatsApp Cloud API

La clínica debe crear o disponer de un portafolio empresarial de Meta, una cuenta de WhatsApp Business (WABA) y un número telefónico empresarial. Use un token de usuario del sistema con los permisos `whatsapp_business_management` y `whatsapp_business_messaging`.

Complete en `.env`:

```dotenv
WHATSAPP_ENABLED=false
WHATSAPP_GRAPH_BASE_URL=https://graph.facebook.com/VERSION_VIGENTE
WHATSAPP_PHONE_NUMBER_ID=
WHATSAPP_ACCESS_TOKEN=
WHATSAPP_APP_SECRET=
WHATSAPP_WEBHOOK_VERIFY_TOKEN=
WHATSAPP_DEFAULT_COUNTRY_CODE=51
WHATSAPP_TEMPLATE_LANGUAGE=es_PE
WHATSAPP_TEMPLATE_APPOINTMENT_CONFIRMATION=dental_cita_confirmacion
WHATSAPP_TEMPLATE_APPOINTMENT_REMINDER=dental_cita_recordatorio
WHATSAPP_TEMPLATE_FOLLOW_UP=dental_seguimiento_postconsulta
```

No active `WHATSAPP_ENABLED=true` hasta que las tres plantillas estén aprobadas en Meta. Plantillas sugeridas, categoría `UTILITY`:

- `dental_cita_confirmacion`: `Hola {{1}}, su cita está programada para el {{2}} a las {{3}}. Responda CONFIRMO o solicite reprogramación.`
- `dental_cita_recordatorio`: `Hola {{1}}, le recordamos su cita del {{2}} a las {{3}}.`
- `dental_seguimiento_postconsulta`: `Hola {{1}}, ¿cómo se siente después de su atención? Puede responder con sus propias palabras.`

Configure en Meta esta URL pública con HTTPS:

```text
https://SU_DOMINIO/api/v1/whatsapp/webhook
```

Use como token de verificación el mismo valor de `WHATSAPP_WEBHOOK_VERIFY_TOKEN`, suscriba el campo `messages` y use el secreto de la aplicación en `WHATSAPP_APP_SECRET`. El backend implementa el desafío GET, valida `X-Hub-Signature-256`, procesa mensajes y actualiza estados `sent`, `delivered`, `read` y `failed`.

## Primer arranque

1. Copie `.env.example` a `.env` y reemplace todas las claves de ejemplo.
2. Genere `JWT_SECRET` con al menos 32 bytes aleatorios codificados en Base64.
3. En el primer arranque de una base vacía, establezca temporalmente `BOOTSTRAP_ADMIN_ENABLED=true` y una contraseña fuerte. El usuario se crea con el único rol `ODONTOLOGO`.
4. Después de comprobar el acceso, cambie la contraseña desde **Ajustes** y establezca `BOOTSTRAP_ADMIN_ENABLED=false`.
5. Arranque: `docker compose -f compose.full.yaml up --build -d`.
6. Verifique: `./ops/verify-production.sh https://SU_DOMINIO`.

## Copias de seguridad

El respaldo incluye PostgreSQL y los archivos clínicos adjuntos:

```bash
./ops/backup.sh
```

Conserva 30 días de forma predeterminada. Para automatizarlo diariamente con cron:

```cron
15 2 * * * /ruta/dental-americana-backend/ops/backup.sh /ruta/segura/backups >> /ruta/segura/backup.log 2>&1
```

Guarde una segunda copia cifrada fuera del servidor y pruebe periódicamente la restauración. El respaldo no sustituye una política clínica y legal de conservación de historias.

## Validaciones humanas antes de atender pacientes reales

- Dominio y certificado HTTPS válidos.
- Nombre, RUC, dirección, teléfono y horario de la clínica revisados en **Ajustes**.
- Aviso de privacidad y formatos de consentimiento aprobados por asesoría local.
- Autorización de WhatsApp registrada individualmente en la ficha de cada paciente.
- Plantillas aprobadas y prueba real de envío, respuesta, entrega y lectura.
- Respaldo automático y restauración probada.
- Revisión clínica final del odontograma, historia, presupuesto y constancias por el odontólogo responsable.

Nunca almacene tokens, contraseñas ni respaldos en el repositorio.
