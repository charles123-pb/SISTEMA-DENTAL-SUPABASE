# Mejoras del sistema Dental Americana por fases

El sistema en uso es `dental-americana-supabase` (Angular) con Supabase y las funciones Edge en `supabase/`. Los antiguos proyectos de backend/frontend no forman parte de este plan.

## Revisión transversal — primera entrega en el frontend actual

Esta entrega modifica Angular y documentación local. No despliega funciones, no cambia datos
remotos ni envía mensajes a pacientes. Conserva el diseño existente y utiliza Angular CDK, ya
instalado, para compartir comportamiento en lugar de añadir otro framework.

- [x] Corregir reprogramación: cambiar fecha, odontólogo o tipo exige elegir un nuevo horario;
  editar solamente el motivo conserva el horario de la cita.
- [x] Corregir «Cancelar» al registrar contacto: ya no marca la solicitud como contactada.
- [x] Invalidar búsquedas de pacientes anteriores al abrir/cerrar otra cita o seleccionar
  manualmente un paciente; las respuestas tardías de una solicitud no pisan la selección actual.
- [x] Añadir `shared/ui/modal/ModalDirective` a agenda, revisión de duplicados y los dos diálogos
  de WhatsApp: foco contenido, retorno del foco, Escape y protección durante el guardado.
- [x] Evitar peticiones simultáneas del QR y desuscribir al salir del módulo. Una respuesta
  tardía no reabre el diálogo; cerrar detiene la renovación y reabrir la reanuda.
- [x] Mostrar errores de selección/envío dentro de «Nuevo mensaje», con `role="alert"`,
  conservando el borrador cuando falla el envío.
- [x] Verificar 62 pruebas automatizadas en 19 archivos, incluidas 24 regresiones nuevas respecto
  a la base de 38 pruebas. Los servicios externos se simulan únicamente en pruebas.
- [x] Compilar el frontend con la configuración de producción.
- [ ] Revisar en navegador real móvil/escritorio y con lector de pantalla. Las pruebas con jsdom
  comprueban comportamiento y DOM, no certifican apariencia ni una conexión real con WhatsApp.

Guía de reutilización: `dental-americana-supabase/src/app/shared/ui/README.md`.

### Próximas entregas y criterios de cierre

1. **Fiabilidad de WhatsApp (prioridad alta):** corregir los dos hallazgos de backend de la fase 1
   y cubrirlos sin red con pruebas de persistencia, consentimiento y destinatario vigente.
2. **Formularios y diseño compartido:** errores específicos por campo en login/pacientes,
   `aria-invalid`/`aria-describedby`, sustituir progresivamente `prompt`/`confirm` por diálogos
   del sistema; conservar estilos y comprobar móvil/teclado antes de migrar más pantallas.
3. **Flujos por módulo:** reserva web → paciente → cita, historia clínica/odontograma,
   tratamientos/pagos, administración y DentalIA. Cubrir validación, permisos, errores de red
   y concurrencia con datos sintéticos; no dar un módulo por validado solo porque compila.
4. **Publicación:** completar separación de entornos, revisión de políticas RLS, privacidad
   de IA, respaldos/restauración y pruebas controladas antes de declarar producción lista.

## Fase 1 — Entrega fiable de WhatsApp (en curso)

- [x] Verificar que el cron de `whatsapp-dispatch` está activo. Se ejecuta cada minuto.
- [x] Corregir el límite HTTP predeterminado de 5 segundos de `pg_net`, que provocaba respuestas nulas intermitentes. El cron usa ahora 120 segundos; verificar su tendencia durante varios días.
- [x] Evitar el reenvío automático cuando Evolution API pudo haber recibido el mensaje pero falló la respuesta o la escritura en Supabase. Estos casos quedan en `FALLIDO` para verificar en WhatsApp antes de pulsar «Reintentar».
- [x] Validar que la cita sigue requiriendo confirmación/recordatorio justo antes de enviar.
- [x] Procesar la cola por fecha programada e ID, hasta 5 mensajes por ejecución.
- [ ] **Hallazgo prioritario:** `supabase/functions/whatsapp-webhook/index.ts` registra en consola
  el error de `registrar_evento_whatsapp` pero devuelve HTTP 200; también hay escrituras de estado
  sin comprobar. Verificado con ejecución local y persistencia simulada fallida. Propagar el
  fallo sin confirmar una escritura perdida y probar entrega duplicada/lotes parciales.
- [ ] **Hallazgo prioritario:** `whatsapp-dispatch` y el camino de reintento de `whatsapp-send`
  no revalidan consentimiento, actividad y celular vigente antes de contactar al proveedor.
  Confirmado por inspección del flujo local; no demuestra un incidente en producción. Revalidar
  cada envío y derivar a revisión si cambió el destinatario. Probar revocación/cambio de celular.
- [ ] Confirmar con una prueba controlada, usando un número propio, el circuito cita → mensaje → respuesta → estado de la cita. No probar con pacientes reales sin autorización.

Comprobaciones de solo lectura en el SQL Editor de Supabase:

```sql
select jobname, schedule, active from cron.job
where jobname = 'dental-whatsapp-dispatch';

select status_code, count(*) as ejecuciones
from net._http_response
where created > now() - interval '24 hours'
group by status_code order by status_code nulls first;

select estado, count(*) as mensajes
from public.mensajes_whatsapp
group by estado order by estado;
```

`cron.job_run_details.status = 'succeeded'` indica que el trabajo SQL terminó; **no garantiza** que la llamada HTTP a la función Edge haya funcionado. Revisar `net._http_response` por separado. Un `status_code` nulo es una petición sin respuesta y debe investigarse si se repite.

## Fase 2 — Bandeja de WhatsApp (en curso)

- [x] Paginar conversaciones (30 por página) y mensajes (50 por página), con cursores estables y botones para cargar más.
- [x] Corregir el buscador de texto para que una consulta sin números no coincida accidentalmente con todos los teléfonos.
- [x] Evitar que respuestas de búsquedas o chats anteriores sobrescriban la selección actual.
- [x] Marcar como leídos los mensajes nuevos que llegan mientras el chat está abierto y conservar la posición al cargar historial anterior.
- [x] Restringir los nuevos RPC de paginación a usuarios autenticados con `SEGUIMIENTO_LEER`.
- [ ] Comprobar en navegador la recepción en tiempo real y la reconexión tras perder Internet; el sondeo de respaldo sigue activo cada 30 segundos.
- [ ] Revisar el flujo de contactos nuevos y la asociación paciente–conversación–cita.
- [ ] Probar la interfaz en móvil, tablet y escritorio.

## Fase 3 — Infraestructura y seguridad

- [x] Preparar Compose de producción separado, sin puertos públicos para PostgreSQL/Redis/Evolution y con túnel nombrado, imágenes por digest y preflight de secretos.
- [x] Añadir CSP y fuentes locales al frontend; comprobar el build Docker y `/healthz`.
- [x] Comprobar en la revisión anterior que RLS estaba habilitado en 40/40 tablas públicas,
  además de tipos de Edge Functions, dependencias y CI. Tener RLS habilitado no demuestra
  que todas sus políticas sean correctas; falta validar accesos por rol y pruebas negativas.
- [ ] Configurar en Cloudflare el dominio/túnel estables y Access; el túnel temporal `trycloudflare.com` aún no se ha sustituido en el servicio en uso.
- [ ] Separar Supabase de desarrollo y producción, configurar Auth/SMTP y activar secretos de producción.
- [ ] Definir y probar respaldos/restauración de base de datos, Storage y datos de Evolution.
- [ ] Rotar credenciales que se hayan expuesto y hacer una prueba de seguridad autorizada antes del lanzamiento.

## Fase 4 — DentalIA

- [x] Exigir `EXTERNAL_AI_ENABLED=true` antes de enviar datos clínicos a Gemini u otro proveedor, y excluir identificadores estructurados del contexto externo.
- Validar la integración Gemini con credenciales solo en funciones Edge.
- Añadir límites de uso y revisar la privacidad de texto libre, consentimiento y condiciones del proveedor antes de habilitar IA externa.
- Probar respuestas con casos reales anonimizados y supervisión humana.

## Fase 5 — Calidad y operación

- Añadir pruebas automatizadas de reserva/cancelación/confirmación y de mensajería.
- Ejecutar build y pruebas en CI; monitorizar errores de funciones, cron y cola.
- Preparar una lista de verificación antes de publicar cambios en producción.
