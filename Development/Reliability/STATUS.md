# Estado actual - PMM v1.5.0.2

## Rama

`v1.5.0.2`

Base de origen:
`2586b4c3999ccc094344bc65710d6559f4858871`
(`v1.5.0.1-PMM-reliability`, I04).

Estado de este bootstrap: **documentacion/continuidad solamente**. El paquete `PMM/` no se modifica en este paso.

## Baseline heredado

La rama contiene todo lo presente en I04:
- version empaquetada 1.5.0.1;
- BUILD_ID `PMM-v1.5.0.1-reliability-i04-nexus-updates`;
- 30 idiomas registrados, 23 habilitados, 7 reservas;
- I04 Nexus Updates;
- Host y Runtime C2B;
- FixLab original en distribucion y candidatas 04A-6E fuera del paquete;
- Workspace, despliegue, rollback, Deep Analysis y flujos existentes.

1.5.0.2 es la version objetivo y se aplicara a metadata/checksums junto con la primera integracion funcional.

## Incidencia abierta: STARTUP-PRE-UI-2026-09

Se mantiene como prioridad de fiabilidad:
- fallo despues de la barra de carga y antes de UI;
- propietario: una ocurrencia en primer arranque de 1.5.0.1, segundo arranque correcto;
- usuario chino: mismo tipo de fallo reportado posteriormente y persistente segun su reporte;
- el propietario no puede reproducirlo con instalacion nueva ni borrando Workspace;
- mensaje exacto/stack aun no disponibles.

Estado: **OPEN / NOT REPRODUCED / CAUSE UNKNOWN**.

No vincularlo al idioma chino ni a otra causa sin evidencia.

## Hardening Nexus/antivirus

Trabajo heredado que sigue pendiente o parcial:
- argumentos de politica PowerShell heredados;
- rutas de reparacion automatica de dependencias;
- broker `Modules/Operations/OperationWorker.ps1` aun presente;
- migracion a subcomandos nativos no cerrada;
- recursos PE/build reproducible por cerrar;
- firma de codigo no provisionada;
- preflight y matriz de escaneos reales no realizados para 1.5.0.2.

## Paso actual

**V1502-S00 - BOOTSTRAP: CERRADO con esta rama/documentacion.**

Siguiente:
**V1502-S01 - Startup diagnosable + inventario de superficie de ejecucion.**

Objetivo de S01:
1. hacer que cualquier fallo entre splash y UI deje etapa y error accionables;
2. inventariar exactamente PowerShell, procesos, repair y red en startup;
3. fijar un baseline de artefactos/hashes antes de modificar el comportamiento;
4. no perder ninguna feature heredada.

Despues:
S02 procesos/PowerShell -> S03 check/repair -> S04 broker -> S05 build/PE -> S06 firma -> S07 preflight/escaneos -> S08 falsos positivos de vendors si siguen existiendo.

Ver `V1502_PLAN.md`.
