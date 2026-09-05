# Entrega técnica — Sistema Dental Americana

## Estado

Las fases 1 a 12 están implementadas en código fuente: arquitectura y seguridad; pacientes; agenda; historia clínica; odontograma; tratamientos; finanzas; WhatsApp; copiloto; administración; web pública; pruebas y despliegue.

## Carpetas

- `dental-americana-frontend`: Angular 21.
- `dental-americana-backend`: Spring Boot, migraciones y despliegue.

## Verificación realizada

- `npm run test:ci`: 17/17 pruebas aprobadas.
- `npm run build`: compilación de producción aprobada sin advertencias.
- Revisión estática de permisos, migraciones V1–V17, rutas públicas y estados sensibles.
- `mvn test`: 9/9 pruebas aprobadas y compilación del backend aprobada.

## Configuración pendiente para un entorno real

- Credenciales seguras de PostgreSQL y JWT.
- Usuarios reales y contraseñas temporales.
- Datos institucionales definitivos y RUC.
- Token, identificadores, secreto de aplicación y plantillas aprobadas de Meta WhatsApp Business.
- Dominio y HTTPS; el respaldo y la verificación operativa ya incluyen scripts automatizables.
- Política de privacidad, consentimiento y conservación de datos.
- Validación del contador si se integra comprobante electrónico o SUNAT.

Los fuentes están preparados para la prueba integral final con PostgreSQL y para desplegar mediante `compose.full.yaml`. Consulte `dental-americana-backend/docs/PUESTA_EN_PRODUCCION.md`.
