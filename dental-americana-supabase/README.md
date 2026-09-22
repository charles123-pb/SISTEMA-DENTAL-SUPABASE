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

Las pruebas automatizadas usan dobles de los servicios; no sustituyen la validación con Supabase y WhatsApp conectados.

## Flujo de trabajo para un consultorio unipersonal

1. En **Inicio → Mi jornada**, revisa las citas pendientes de atender, solicitudes por agendar,
   conversaciones sin leer y envíos fallidos. Usa Actualizar para consultar los pendientes nuevamente.
   Si aparece «Información parcial», no asumas que los módulos que fallaron están al día.
2. Selecciona una cita y abre su atención. Guarda el borrador antes de ir al odontograma o al tratamiento.
   Los enlaces de regreso conservan el identificador de la atención, incluso si pertenece a otro día.
3. Desde la atención, **Ver saldo y cobrar** filtra las cuentas y pagos del paciente.
   Los indicadores generales siguen siendo del consultorio. No se registra ningún cobro automáticamente.
4. **Agendar control** precarga paciente y odontólogo; utiliza la fecha del próximo control si es válida
   y no está en el pasado. Selecciona un horario disponible y confirma para crear la cita.
5. Los borradores modificados de historia clínica y odontograma muestran una advertencia al salir,
   recargar o cerrar sesión. Esta protección no es autoguardado; guarda antes de cambiar de pantalla.

### Comprobación manual pendiente en el entorno conectado

Con un paciente de prueba, recorrer cita → atención → odontograma → atención → cuentas → atención → control.
Comprobar que siempre corresponde al mismo paciente; cancelar el descarte de un borrador y verificar
que sigue intacto. Verificar también el flujo en móvil y contrastar los contadores de Mi jornada con
la bandeja real. Esta actualización no despliega Edge Functions ni prueba envíos reales de WhatsApp.

## Historia clínica para imprimir

En **Pacientes → ficha del paciente → Historia clínica completa**, revisa el documento y pulsa
**Imprimir / Guardar PDF**. Para descargarlo, selecciona **Guardar como PDF** en el diálogo del navegador.
Requiere `PACIENTE_LEER` y `CLINICA_LEER`. Tratamientos y citas se incluyen según los permisos del usuario;
las secciones sin autorización se identifican en el documento.

El informe muestra la ficha actual, antecedentes, alergias, medicamentos, atenciones finalizadas,
odontogramas aprobados de esas atenciones, planes fuera de borrador y citas del paciente.
Las atenciones borrador/anuladas se cuentan como excluidas. Los archivos tienen descarga individual
auditada: el PDF contiene su relación, no el contenido de radiografías, fotografías o PDF adjuntos.
No se genera una firma digital ni se envía el documento a otra clínica automáticamente.

La consulta se instala con `202609150003_patient_clinical_report.sql`. Las pruebas de permisos,
aislamiento por paciente y aprobación están en `supabase/tests/patient-clinical-report.sql`.

## Producción

La ruta preparada para producción está en `../ops/production/README.md`. Requiere separar el proyecto
Supabase de desarrollo, configurar dominio y túnel estables, respaldos y pruebas controladas antes de
atender pacientes. No coloque `service_role`, credenciales de Evolution API ni claves de IA en Angular.

Consulte `../GUIA_CONEXION_SUPABASE_WHATSAPP.md` para el despliegue y la conexión de WhatsApp.
