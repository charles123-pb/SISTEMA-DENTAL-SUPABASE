# Estado de migración a Supabase

Actualizado: 2026-09-08. Rama: `migration/supabase-phase-1`.

| Módulo | Estado | Alcance implementado |
|---|---|---|
| Copia Angular independiente | COMPLETO | `dental-americana-supabase/`; el frontend original permanece separado |
| Supabase Client | COMPLETO | Cliente único tipado; el navegador solo recibe URL y clave pública |
| Auth / perfiles / roles | COMPLETO | Sesión, recuperación y cambio de contraseña, guards, roles y permisos reales |
| RLS | COMPLETO | Todas las tablas funcionales protegidas; sin borrado físico para usuarios normales |
| Pacientes | COMPLETO | Ficha, duplicados, anexos clínicos, consentimiento y archivos privados |
| Profesionales y agenda | COMPLETO | Disponibilidad, bloqueos, citas, solicitudes web, concurrencia y estados |
| Historia y odontograma | COMPLETO | Versiones, aprobación profesional, hallazgos y vínculo con la cita |
| Tratamientos y presupuestos | COMPLETO | Catálogo, planes, procedimientos, descuentos, aprobación y evolución |
| Pagos y caja | COMPLETO | Cuentas por cobrar, sesiones, pagos, gastos y resúmenes auditados |
| Storage | COMPLETO | Bucket privado `patient-files`, RLS, validación y descarga auditada |
| Seguimientos | COMPLETO | Programación postconsulta, respuestas, alertas y revisión profesional |
| WhatsApp | COMPLETO EN CÓDIGO | Envío, cola, reintentos, plantillas, webhook firmado, confirmación/cancelación y recordatorios |
| Copiloto IA | COMPLETO EN CÓDIGO | Contexto, generación, edición y aprobación; funciona con fallback sin proveedor externo |
| Administración | COMPLETO | Alta segura de odontólogos, usuarios, configuración, auditoría y resumen operacional |
| Realtime | COMPLETO | Agenda, mensajes y seguimientos publicados; centro de seguimiento suscrito |
| Pruebas | COMPLETO | 17/17 pruebas Angular, build, 24 migraciones limpias y prueba integral local |

El proyecto Supabase ya no consume la API Spring ni usa el JWT legado. Para operar en Internet solo
faltan acciones del propietario que no pueden incluirse en el código: crear el proyecto remoto, cargar
claves, registrar el número de WhatsApp Business, aprobar las tres plantillas y configurar dominio/HTTPS.
Siga `GUIA_CONEXION_SUPABASE_WHATSAPP.md`.
