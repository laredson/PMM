# Estado de la linea v1.5.0.1

## Entregado en la inicializacion

Rama independiente desde `38bd5a934488ac11a6200d3142b889ca86a82f57`, ancestro comun registrado, instrucciones para continuacion, plan de fiabilidad, contrato de integracion de idiomas y herramienta de inventario de diferencias en modo solo lectura.

No se modifican los archivos de `PMM/`, los fuentes anteriores ni los workflows. No se hace merge, no se crea tag/release y no se selecciona Latest. La version objetivo se registra en BASELINE.json; todavia no cambia la version que muestra el programa heredado.

## Trabajo pendiente

| ID | Entrega | Estado |
| --- | --- | --- |
| REL-00 | Inventario de artefactos, SHA-256 real y correspondencia del informe de VirusTotal | Pendiente; no se ha establecido la identidad del archivo reportado |
| REL-01 | Fuentes nativas actuales recuperadas/reconciliadas y paridad documentada | Prioridad maxima; la advertencia de SOURCE_STATUS.md sigue vigente |
| REL-02 | Identidad 1.5.0.1 coherente en VERSION, BUILD_ID, manifiesto, UI e inventarios | Pendiente; VERSION heredado 1.5.0.0 y manifiesto heredado 1.3.4.1 |
| REL-03 | Invocaciones y permisos revisados, sin Bypass innecesario y con contratos de herramientas | Pendiente; no se ha modificado el arranque ni eliminado PowerShell |
| REL-04 | Arranque local verificable, reparacion explicita y transaccional, respeto a cuarentena | Pendiente; comportamiento actual conservado |
| REL-05 | Compilacion repetible, recursos estandar y procedencia completa | Pendiente; depende de REL-01 |
| REL-06 | Firma de codigo y scripts cuando corresponda | Pendiente; certificado/servicio no seleccionado ni provisionado |
| REL-07 | Preflight de distribucion, pruebas locales Windows y evidencia de escaneos reales | Pendiente; no equivale a un emulador de Nexus |
| LOC-MERGE | Integracion de las traducciones posteriores al punto de partida | Preparada documentalmente; no ejecutada |

## Evidencia y limites de esta entrega

- Inspeccion por lectura de la rama, fuentes de referencia, metadatos, contrato de localizacion y triggers de los tres workflows presentes.
- Los filtros push leidos no incluyen `v1.5.0.1-PMM-reliability`. No se solicita workflow_dispatch ni se abre un PR. El commit de preparacion incluye `[skip ci]`.
- La sintaxis Python de `plan_translation_integration.py` se ha analizado localmente con AST. No se ha ejecutado sobre una copia local completa de PMM ni se presenta como herramienta funcionalmente validada.
- No se han ejecutado compilaciones, PMM, pruebas funcionales ni antivirus. La comprobacion del commit y su diff por la API de GitHub es inspeccion del repositorio, no CI.
- La conservacion del arbol `PMM/` se verifica por identidad Git al cerrar la inicializacion. Esto demuestra ausencia de cambios de contenido, no ausencia de malware ni ausencia de errores preexistentes.

## Siguiente intervencion

REL-00 y REL-01: identificar artefactos y recuperar fuentes nativas actuales antes de reconstruir. Registrar hallazgos con rutas/commits y distinguir hechos, hipotesis y comportamiento verificado en Windows. Si la recuperacion exige otros ZIP o backups, detallar exactamente que se necesita; no sustituir ejecutables funcionales por una reconstruccion incompleta.
