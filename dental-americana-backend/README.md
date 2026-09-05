# Sistema Web Integral Dental Americana — Backend

API REST del sistema clínico y administrativo del Consultorio Dental Americana. Está construida con Java 17, Spring Boot 3.5, PostgreSQL 16, Flyway, JWT y control de acceso por permisos.

## Módulos implementados

- Autenticación, rol único de odontólogo, permisos y auditoría.
- Pacientes, responsables, antecedentes, alergias, medicamentos y archivos.
- Agenda, disponibilidad, citas, reprogramaciones y estados.
- Historia clínica completa, versiones, conformidad y aprobación profesional.
- Odontograma permanente e infantil por pieza y superficie.
- Tratamientos, presupuestos, evoluciones y cuentas por cobrar.
- Caja, pagos, gastos, conciliación, cierres y reportes administrativos.
- WhatsApp mediante plantillas Meta, cola con reintentos, webhook firmado, recordatorios y seguimiento postconsulta.
- Copiloto supervisado con fuente, campos faltantes, aprobación y rechazo.
- Configuración institucional, auditoría consultable y reporte CSV.
- Solicitudes públicas de cita que recepción debe revisar antes de agendar.

## Requisitos

- Java 17 o superior.
- Maven 3.6.3 o superior.
- PostgreSQL 16; alternativamente, Docker Desktop con Compose.
- Node.js 20 o superior para el frontend Angular.

## Ejecución local

1. Copie `.env.example` como `.env` y cambie todas las claves.
2. Inicie PostgreSQL con `docker compose up -d postgres`.
3. Exporte las variables de `.env` según su terminal.
4. Ejecute `mvn spring-boot:run -Dspring-boot.run.profiles=local`.
5. Verifique `http://localhost:8080/actuator/health`.

El perfil `local` crea el administrador configurado solo cuando no existe. En producción, `BOOTSTRAP_ADMIN_ENABLED` debe permanecer en `false` después de crear las cuentas autorizadas.

## Migraciones

Flyway ejecuta automáticamente `V1` a `V11`. Hibernate usa `ddl-auto: validate`: el código no modifica el esquema por su cuenta. No edite una migración ya aplicada; cree una nueva versión.

## Integración WhatsApp

Por defecto, `WHATSAPP_ENABLED=false`. Para habilitar Meta WhatsApp Business complete el identificador, token, secreto de aplicación, token de verificación y nombres de plantillas. Consulte `docs/PUESTA_EN_PRODUCCION.md`. Nunca guarde el token real en Git.

## Reglas críticas

- El backend valida los permisos aunque Angular oculte acciones.
- El modelo operativo usa un único rol activo: `ODONTOLOGO`, con acceso integral a los módulos.
- Diagnóstico, odontograma, historia final e indicaciones requieren aprobación profesional.
- La IA solo prepara borradores; no escribe ni firma la historia clínica.
- Pagos, gastos y cierre de caja exigen confirmación y quedan auditados.
- El formulario público genera una solicitud, no una cita automática.
- Los envíos automáticos requieren autorización de WhatsApp registrada en la ficha del paciente.
- Los reportes financieros son administrativos y deben validarse con el contador.

## Pruebas y compilación

```bash
mvn test
mvn clean package
```

En esta entrega el frontend fue validado con 17 pruebas y compilación de producción. El backend fue validado con 9 pruebas automatizadas.

## Despliegue con contenedores

```bash
docker compose -f compose.full.yaml up --build -d
```

La web quedará en `http://localhost`, la API se servirá internamente por `/api` y PostgreSQL no debe exponerse públicamente en producción.

Consulte `docs/arquitectura.md` y `docs/api-local.http` para la estructura y ejemplos de endpoints.
