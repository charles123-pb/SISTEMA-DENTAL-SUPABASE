# Entrega técnica — Sistema Dental Americana

## Estado

Entrega de código verificada el 5 de septiembre de 2026. Los módulos están implementados y los paquetes compilados. La puesta en servicio no está completada: no se pudo acceder a Docker desde esta sesión y faltan las credenciales externas y la validación integral con la base real.

## Cambios de cierre

- Agenda conectada con historia clínica: iniciar atención abre el registro; completar exige historia aprobada. Se bloquea cancelar o reprogramar una cita con atención registrada.
- Tratamientos: se verifica que la atención pertenezca al paciente del plan; cada procedimiento requiere evolución antes de completarse y el plan exige procedimientos terminados para cerrarse.
- WhatsApp: autorización y teléfono se comprueban al enviar; los mensajes vencidos o de citas canceladas se cancelan. Los teléfonos compartidos se derivan a revisión. La confirmación contextual apunta a la cita del mensaje respondido.
- Sesiones: cambiar la contraseña o desactivar una cuenta invalida sus tokens; el cambio de contraseña vuelve al login.
- Interfaz: indicador clínico actualizado, constancia administrativa de pago descargable, cierre de procedimientos accesible y acceso funcional a seguimientos.
- Operación: comandos de arranque/parada, perfil demo compatible con V13, verificación API de módulos y ejecución de pruebas con menos procesos.

## Carpetas

- `dental-americana-frontend`: Angular 21.
- `dental-americana-backend`: Spring Boot, migraciones y despliegue.

## Verificación realizada

- `npm run test:ci`: 17/17 pruebas aprobadas.
- `npm run build`: compilación de producción aprobada sin advertencias.
- Revisión estática de permisos, migraciones V1–V17, rutas públicas y estados sensibles.
- `mvn package`: 17/17 pruebas del backend aprobadas y JAR generado.
- `docker compose config --quiet`: configuración de producción y demo válida.
- Scripts de operación: sintaxis Bash y JavaScript validada.

No se ejecutó una prueba integral de escritura con PostgreSQL, una revisión visual en navegador, una restauración ni un envío real a Meta en esta sesión. El script `ops/smoke-api.mjs` queda preparado para consultar los módulos cuando el sistema esté arrancado; no se presenta como una prueba ya ejecutada.

## Arranque para continuar las pruebas locales

Desde la raíz del proyecto:

```bash
cd dental-americana-backend
sudo ./ops/system.sh start-demo
```

Docker exige permisos sobre `/var/run/docker.sock`; la consulta normal devolvió `permission denied` y `sudo -n` devolvió `a password is required`. El usuario debe introducir su contraseña de administrador en su propia terminal. No se ha modificado la pertenencia a grupos, el servicio Docker ni sus volúmenes.

Después del arranque, abra `http://localhost/sistema/login` (o el puerto definido en `WEB_PORT`). Use la cuenta configurada en `.env` o la cuenta ya existente en su base. El perfil demo deshabilita envíos WhatsApp.

El odontograma se encuentra en **Atención → seleccionar paciente → Examen → Odontograma conectado**. Cada pieza muestra nombre y orientación del lado del paciente.

Para detener solo el sistema dental y conservar la información:

```bash
sudo ./ops/system.sh stop
```

Esta sesión no arrancó servidores persistentes del proyecto.

## Configuración pendiente para un entorno real

- Credenciales seguras de PostgreSQL y JWT.
- Usuarios reales y contraseñas temporales.
- Datos institucionales definitivos y RUC.
- Token, identificadores, secreto de aplicación y plantillas aprobadas de Meta WhatsApp Business.
- Dominio y HTTPS; el respaldo y la verificación operativa ya incluyen scripts automatizables.
- Política de privacidad, consentimiento y conservación de datos.
- Validación del contador si se integra comprobante electrónico o SUNAT.

Los fuentes están preparados para la prueba integral final con PostgreSQL y para desplegar mediante `compose.full.yaml`. Consulte `dental-americana-backend/docs/PUESTA_EN_PRODUCCION.md`. El copiloto actual prepara borradores con datos estructurados locales; no hay un proveedor de IA generativa conectado. Las constancias no son comprobantes SUNAT y el odontograma aún requiere validación clínica y normativa del responsable antes del uso asistencial.
