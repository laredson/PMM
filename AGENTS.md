# PMM v1.5.0.2 - reglas de desarrollo

Rama activa: `v1.5.0.2`.
Base heredada exacta: `2586b4c3999ccc094344bc65710d6559f4858871` de `v1.5.0.1-PMM-reliability`.

## Leer al entrar

1. `START_HERE_NEW_PROJECT.md`
2. `Development/Reliability/V1502_STATE.json`
3. `Development/Reliability/V1502_HISTORY.md`
4. `Development/Reliability/STATUS.md`
5. `Development/Reliability/NEXT_SESSION.md`
6. `Development/Reliability/V1502_PLAN.md`
7. El incidente o contrato concreto del bloque que se vaya a tocar.

`Development/Reliability/NEW_PROJECT_HANDOFF.md` y `NEW_PROJECT_STATE.json` describen la linea 1.5.0.1/I04 y son contexto historico, no el punto de entrada actual.

## Baseline funcional que no se puede perder accidentalmente

La rama hereda el paquete I04 completo:
- I03: 30 idiomas registrados, 23 habilitados y 7 reservas;
- selector/localizacion con nativeName, RTL/LTR y compatibilidad PowerShell 5.1 heredada;
- I04: Updates Nexus seguro, archivo/rollback y flujo Premium/Free preparado;
- Host/Runtime C2B;
- Workspace privado y contratos de recuperacion/despliegue;
- Deep Analysis, Mods & Merge y flujos ya existentes;
- PMMFixLab distribuido original; research 04A-6E sigue candidato-only hasta integracion expresa.

No copiar carpetas antiguas sobre PMM. No reemplazar binarios por candidatas solo porque compilen o tengan hash conocido.

## Incidencia de arranque obligatoria

Leer `Development/Reliability/Incidents/STARTUP_PRE_UI_2026-09.md`.

El fallo conocido sucede despues de la barra de carga y antes de UI. No es reproducible actualmente por el propietario. Debe mantenerse abierto hasta disponer de evidencia suficiente o una correccion que cubra una causa demostrada.

Toda modificacion del startup debe:
- conservar logs/diagnostico;
- distinguir etapa alcanzada;
- no esconder excepciones para aparentar un arranque correcto;
- no borrar Workspace automaticamente;
- no descargar/reinstalar dependencias en silencio;
- no asumir que el locale chino es la causa.

## Objetivo de hardening para Nexus/antivirus

Reducir falsos positivos mediante comportamiento mas claro y auditable:
- retirar Bypass donde exista una ruta soportada;
- argumentos estructurados y procesos delimitados;
- check separado de repair;
- arranque sano sin red;
- reparacion explicita, verificada y reversible;
- broker de operaciones estrecho/native cuando proceda;
- build reproducible;
- recursos PE estandar;
- firma real si se provisiona;
- preflight y escaneos comparables por hash.

No implementar tecnicas para ocultar ejecutables, evadir motores, desactivar seguridad o restaurar cuarentenas automaticamente.

## Version e integridad

La rama se llama 1.5.0.2 pero el paquete inicial sigue identificado como I04/1.5.0.1. Eso es deliberado.

En la primera integracion funcional 1.5.0.2 deben actualizarse de forma atomica:
- VERSION;
- BUILD_ID;
- RELEASE_MANIFEST;
- SHA256SUMS;
- cualquier estado/version visible que dependa de ellos.

No cambiar solo la etiqueta visible.

## Politica GitHub

- No hay permiso permanente de escritura.
- Cada bloque remoto requiere autorizacion del propietario.
- Desarrollo: un commit coherente con `[skip ci]`.
- No Actions, CI ni tests remotos salvo peticion expresa.
- No PR, tag, release ni Latest por iniciativa propia.
- No force push.
- Antes de publicar, confirmar HEAD y que el avance es fast-forward.

## Pruebas

Separar siempre:
- inspeccion estatica;
- tests de herramientas/fixtures;
- build Windows;
- ejecucion Windows real;
- escaneo antivirus real;
- prueba Nexus real.

No convertir una categoria en PASS de otra.
