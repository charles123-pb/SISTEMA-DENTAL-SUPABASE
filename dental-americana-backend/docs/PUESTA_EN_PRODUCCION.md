# Puesta en producción y automatizaciones

## Automatizaciones incluidas

| Evento | Acción automática | Control de seguridad |
|---|---|---|
| Se crea o reprograma una cita | Encola confirmación por WhatsApp | Solo pacientes con autorización vigente |
| Faltan 24 horas para la cita | Encola un recordatorio | Evita duplicados y cancela mensajes de horarios anteriores |
| El paciente responde `CONFIRMO` | Confirma la cita del mensaje respondido; sin contexto, la próxima pendiente | Un teléfono compartido entre pacientes se deriva para revisión |
| Se abre la historia desde la agenda | Inicia la atención vinculada | El cierre de la cita exige historia finalizada y aprobada |
| Cambia el teléfono o se revoca la autorización | Cancela mensajes pendientes al despacharlos | Verifica el contacto y consentimiento otra vez antes del envío |
| El paciente solicita cancelar o cambiar | Deriva la conversación para revisión | No cambia la agenda automáticamente |
| Se finaliza una atención | Programa seguimiento postconsulta a 24 horas | No diagnostica; el odontólogo revisa las respuestas |
| Se detectan palabras de alarma | Marca seguimiento como alerta | Nunca responde ni diagnostica automáticamente |
| Meta informa entrega o lectura | Actualiza el estado del mensaje | Webhook firmado con el secreto de la aplicación |
| Meta o la red fallan temporalmente | Reintenta a 1 y 5 minutos con el máximo predeterminado de 3 intentos | Si se aumenta el máximo, los siguientes reintentos esperan 30 minutos |

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

## Operación en este equipo

Desde `dental-americana-backend`:

```bash
./ops/system.sh start
./ops/system.sh status
./ops/system.sh check http://localhost
./ops/system.sh stop
```

Para continuar las pruebas sobre la base local que ya contiene la migración de demostración `V13`, use `./ops/system.sh start-demo`. Este comando conserva los volúmenes existentes, incluye `V13` y deshabilita WhatsApp. `start` usa el perfil de producción sin datos demo: una base con migraciones locales necesita un plan de transición validado antes de cambiarla a ese perfil; no borre el historial Flyway para forzar el arranque.

Si el usuario no puede acceder al socket de Docker, estos comandos necesitan un usuario autorizado. En este equipo `sudo` pide la contraseña de administrador: ejecute `sudo ./ops/system.sh start` desde su terminal. El asistente no ha podido arrancar ni inspeccionar los contenedores por ese motivo. `stop` conserva los volúmenes y libera los recursos de los contenedores dentales.

La dirección predeterminada es `http://localhost/sistema/login`; si cambió `WEB_PORT`, añada ese puerto. El odontograma se abre desde **Atención → paciente → Examen → Odontograma conectado**. Al seleccionar una pieza aparecen su nombre y lado del paciente.

Cambiar la contraseña invalida las sesiones anteriores y vuelve al inicio de sesión. Esta actualización también requiere volver a iniciar sesión para reemplazar tokens emitidos antes de incorporar la versión de credenciales.

## Verificación de módulos por API

Con el sistema arrancado, exporte `DENTAL_USERNAME` y `DENTAL_PASSWORD` en su terminal y ejecute:

```bash
DENTAL_BASE_URL=http://localhost node ops/smoke-api.mjs
```

El script consulta pacientes, agenda, historias, cuentas, caja, mensajes, seguimientos, solicitudes y configuración. Para odontograma, tratamiento y copiloto utiliza una atención reciente; avisa si no hay datos. No muestra datos clínicos ni tokens y solo produce el evento normal de auditoría del login. No verifica envíos externos ni registra cobros.

La compilación Angular no descarga fuentes; el navegador conserva las fuentes alternativas del sistema cuando Google Fonts no está disponible. Pruebas y compilaciones usan menos procesos para reducir el consumo de memoria.

## Alcance pendiente de la puesta en servicio

El copiloto actual genera borradores desde datos estructurados locales; no hay un proveedor de IA generativa conectado. Las constancias descargables son administrativas. La representación del odontograma y los registros clínicos requieren validación del odontólogo responsable antes del uso asistencial; esta entrega no acredita conformidad normativa integral. La prueba de restauración, HTTPS, credenciales reales y prueba Meta de envío/respuesta siguen pendientes hasta disponer del entorno autorizado.
