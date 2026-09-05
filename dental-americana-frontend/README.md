# Sistema Web Integral Dental Americana — Frontend

Aplicación Angular 21 standalone, responsive y orientada primero a PC. Contiene la página pública del consultorio y el panel privado para recepción, odontólogo, caja y administración.

## Pantallas

- Página pública, servicios, contacto y solicitud de cita.
- Inicio de sesión y shell responsive.
- Agenda visual y bandeja de solicitudes web.
- Pacientes, ficha completa y archivos.
- Atención clínica e historia completa.
- Odontograma permanente e infantil.
- Tratamientos, presupuestos y evoluciones.
- Caja, cuentas por cobrar, pagos, gastos y cierre.
- WhatsApp y seguimiento postconsulta.
- Copiloto clínico supervisado.
- Usuarios, configuración, auditoría y reportes.

## Ejecución

```bash
npm ci
npm start
```

La aplicación abre en `http://localhost:4200`; `proxy.conf.json` envía `/api` a `http://localhost:8080`.

## Validación

```bash
npm run test:ci
npm run build
```

Estado de esta entrega: 9 archivos de prueba, 17 pruebas aprobadas y compilación de producción sin advertencias.

## Producción

El `Dockerfile` genera el bundle y lo sirve con Nginx. `nginx.conf` mantiene las rutas de Angular y reenvía `/api` al servicio `backend`. El despliegue completo está en `../dental-americana-backend/compose.full.yaml`.
