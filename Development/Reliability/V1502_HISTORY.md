# Historial de arranque - PMM v1.5.0.2

Este archivo marca el inicio de la linea 1.5.0.2 y evita perder continuidad con el trabajo anterior.

## Origen exacto

Fecha de apertura de la linea: 2026-09-22.

Rama creada: `v1.5.0.2`.

Commit de origen:
`2586b4c3999ccc094344bc65710d6559f4858871`

Origen nominal:
`v1.5.0.1-PMM-reliability`.

El tag `v1.5.0.1` y la rama reliability apuntaban a ese mismo commit al fijar esta base.

## Que se hereda

No se parte de 1.5.0.0 ni de una release vieja. Se hereda todo el HEAD de reliability.

### I03 - Localizacion
- 30 idiomas registrados.
- 23 habilitados.
- 7 reservas.
- nativeName, RTL/LTR y compatibilidad heredada.
- traducciones integradas semanticamente sobre la linea de fiabilidad.

### I04 - Nexus Updates
- subpestana Updates;
- flujo de Check Updates;
- credencial Nexus personal protegida en Workspace;
- soporte Premium y flujo Free por `nxm://`;
- descarga/extraccion acotadas;
- analisis previo;
- archivo, rollback y recuperacion;
- binarios nativos conservados.

### Nativos y research
- Host C2B distribuido.
- Runtime C2B distribuido.
- PMMFixLab original distribuido.
- research/candidatas FixLab hasta 04A-6E conservados fuera del ejecutable distribuido salvo integraciones ya documentadas.

## Por que se abre 1.5.0.2

Dos lineas de trabajo deben converger sin seguir cargando cambios sobre 1.5.0.1:

1. reducir falsos positivos y mejorar la distribucion para Nexus/antivirus mediante hardening verificable;
2. investigar un fallo real de startup entre la barra de carga y la UI.

El objetivo no es cambiar el numero para "reiniciar" el proyecto; es congelar 1.5.0.1 como baseline y trabajar directamente en una nueva rama.

## Incidencia historica de arranque

Reporte del propietario:
- en su primer arranque de 1.5.0.1 aparecio un error despues de la barra de carga y antes de la UI;
- el segundo arranque funciono y desde entonces no ha conseguido reproducirlo.

Reporte posterior:
- aproximadamente dos dias despues, un usuario chino comunico un fallo del mismo tipo;
- segun el reporte, ese usuario no consigue que PMM llegue a iniciar.

Intentos del propietario:
- borrar Workspace;
- instalacion nueva;
- no reproducen actualmente el fallo.

No se conserva en este momento el texto exacto del error. No se afirma que ambos reportes sean byte/stack-identicos; se agrupan por el mismo punto aparente del startup hasta tener evidencia mejor.

Archivo autoritativo de la incidencia:
`Incidents/STARTUP_PRE_UI_2026-09.md`.

## Estado del paquete al crear la rama

El bootstrap de 1.5.0.2 no cambia `PMM/`.

Por tanto el paquete sigue mostrando:
- VERSION 1.5.0.1;
- BUILD_ID `PMM-v1.5.0.1-reliability-i04-nexus-updates`.

Esto evita romper manifiesto/checksums por una renumeracion cosmetica. La primera integracion funcional 1.5.0.2 cambiara VERSION, BUILD_ID, manifiesto y checksums juntos.

## Continuidad del plan anterior

El plan REL-00..REL-07 no se descarta. Se reagrupa en `V1502_PLAN.md`:

- S01: startup/evidencia;
- S02: procesos/PowerShell;
- S03: dependencias check/repair;
- S04: broker;
- S05: build/PE;
- S06: firma;
- S07: preflight/escaneos;
- S08: submissions de falsos positivos si aun hacen falta.

Los FINDINGS/CHECKS anteriores siguen siendo evidencia historica y no se reescriben.
