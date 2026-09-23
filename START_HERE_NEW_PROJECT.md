# START HERE - PMM v1.5.0.2

Este archivo es el punto de entrada autoritativo para continuar el desarrollo de PMM desde la linea 1.5.0.2.

Repositorio: `laredson/PMM`
Rama de trabajo: `v1.5.0.2`
Base exacta heredada: `2586b4c3999ccc094344bc65710d6559f4858871`
Linea de origen: `v1.5.0.1-PMM-reliability`

## Estado de arranque de 1.5.0.2

La rama nace directamente del HEAD real de la linea reliability. No se ha copiado una carpeta antigua ni se ha reconstruido desde un tag parcial.

Por ello conserva el paquete I04 completo:
- producto empaquetado actual: 1.5.0.1;
- BUILD_ID heredado: `PMM-v1.5.0.1-reliability-i04-nexus-updates`;
- I03 de localizacion: 30 idiomas registrados, 23 habilitados y 7 reservas;
- I04 de actualizaciones Nexus;
- Host y Runtime C2B integrados;
- FixLab original distribuido y research/candidatas 04A-6E aislados;
- Workspace, recuperacion, despliegue, Deep Analysis y demas funciones ya presentes en esa base.

**1.5.0.2 es la version objetivo de desarrollo.** No se cambia VERSION/BUILD_ID/manifiesto/checksums de forma cosmetica en este bootstrap. Esos metadatos se actualizaran juntos en la primera integracion funcional 1.5.0.2.

## Leer primero

1. `AGENTS.md`
2. `Development/Reliability/V1502_STATE.json`
3. `Development/Reliability/V1502_HISTORY.md`
4. `Development/Reliability/STATUS.md`
5. `Development/Reliability/NEXT_SESSION.md`
6. `Development/Reliability/V1502_PLAN.md`
7. `Development/Reliability/Incidents/STARTUP_PRE_UI_2026-09.md`
8. `Development/Reliability/HISTORY_INDEX.md`

Los documentos 1.5.0.1, FINDINGS, CHECKS y contratos anteriores siguen siendo evidencia historica valida. No deben reinterpretarse como estado actual si un documento 1.5.0.2 posterior los supera.

## Dos objetivos activos

### 1. Fallo de arranque previo a UI

Existe una incidencia real pero no reproducible de forma local:
- el propietario la vio una vez al abrir 1.5.0.1 por primera vez; el segundo arranque funciono;
- aproximadamente dos dias despues un usuario chino reporto un fallo del mismo tipo y no logra iniciar;
- ocurre despues de la barra de carga y antes de que aparezca la UI;
- el propietario no consigue reproducirlo ni con instalacion nueva ni borrando Workspace;
- no se conserva todavia el texto exacto del error.

No atribuirlo a idioma, pais, antivirus, carrera, Workspace ni ninguna otra causa sin evidencia.

### 2. Reduccion de falsos positivos / distribucion verificable

El objetivo es reducir causas legitimas de deteccion mediante ingenieria auditable, no ocultar comportamiento:
- diagnosticar y simplificar el arranque;
- retirar `ExecutionPolicy Bypass` donde ya no sea necesario;
- separar comprobacion de dependencias de reparacion;
- evitar reparaciones/descargas silenciosas al arrancar;
- estrechar el broker generico de procesos y migrar operaciones a contratos nativos cuando proceda;
- build reproducible y recursos PE estandar;
- firma real cuando el propietario la provisione;
- preflight del paquete y matriz de escaneo con hashes;
- usar canales de falsos positivos de fabricantes si quedan detecciones.

No desactivar protecciones, no pedir exclusiones y no introducir tecnicas de evasion.

## Regla de continuidad

A partir de este punto, el desarrollo nuevo se hace directamente sobre `v1.5.0.2`. La linea 1.5.0.1 queda como base historica.

No perder funcionalidades heredadas para reducir detecciones. Cada cambio debe conservar idiomas, Nexus Updates, Workspace y contratos existentes salvo cambio explicito y probado.

## Git/GitHub

- Lectura libre.
- Escrituras solo con autorizacion explicita del propietario para el bloque correspondiente.
- Desarrollo: commit/push silencioso con `[skip ci]`.
- Sin Actions/CI/tests remotos durante desarrollo salvo peticion expresa.
- No PR, tag, release ni cambio de Latest por iniciativa propia.
- Pruebas funcionales de desarrollo: locales por el propietario salvo peticion expresa.

Continua en `Development/Reliability/STATUS.md`.


## Plan arquitectonico aprobado para 1.5.0.2 (2026-09-23)

Antes de iniciar trabajo nuevo, leer:

`Development/Reliability/V1502_SINGLE_EXE_AND_NOFLAG_PLAN.md`

Ese documento **supera el orden anterior S01-S08** para la ejecucion activa de 1.5.0.2.

La direccion actual es:
- unificar los ejecutables propios de PMM en un solo `PMM.exe`;
- conservar procesos separados mediante worker modes del mismo ejecutable;
- mantener Modules/Resources/CKL abiertos y editables;
- no absorber ejecutables externos;
- despues hacer hardening startup/PowerShell/dependencias;
- despues cerrar el build PE;
- despues reparar/validar las funciones actuales del producto;
- al final validar el candidato real en Windows/Nexus.

La incidencia de startup pre-UI permanece registrada como watchpoint, pero no es el siguiente bloque mientras no sea reproducible.

La creacion de mods actual es **AI-directed**: la IA crea la solucion solicitada por el usuario usando las capacidades acotadas que PMM le proporciona. Un editor interno general no es requisito de esta version.


## Decision transcript

For the reasoning and product intent behind the current 1.5.0.2 architecture, read:

`Development/Reliability/V1502_DECISION_TRANSCRIPT_2026-09-23.md`

The transcript is contextual history. The authoritative execution requirements remain the single-EXE/noflag plan, STATUS and NEXT_SESSION.
