# PMM: desarrollo de fiabilidad v1.5.0.1

> NUEVO PROYECTO / NUEVO CHAT: leer primero `START_HERE_NEW_PROJECT.md`.
> `Development/Reliability/NEW_PROJECT_HANDOFF.md` y `NEW_PROJECT_STATE.json`
> concentran el estado actual y evitan depender de conversaciones o ZIPs antiguos.
> Las reglas de seguridad/GitHub de este archivo siguen siendo obligatorias.

Esta rama es `v1.5.0.1-PMM-reliability`, derivada de `v1.5.0.0-PMM-translated` en el commit `38bd5a934488ac11a6200d3142b889ca86a82f57`.

## Leer primero

1. `START_HERE_NEW_PROJECT.md`.
2. `Development/Reliability/NEW_PROJECT_HANDOFF.md`, `NEW_PROJECT_STATE.json` y `HISTORY_INDEX.md`.
3. `RELIABILITY.md`.
4. `Development/Reliability/NEXT_SESSION.md`, `STATUS.md` y el ultimo registro; BASELINE.json es historico.
5. `Development/Reliability/IMPLEMENTATION_PLAN.md`.
6. `Development/Reliability/TRANSLATION_INTEGRATION.md`.
7. `Development/Source/SOURCE_STATUS.md` antes de cualquier compilacion nativa; despues, los handoffs historicos de `Development/AI/` como contexto, no como estado de esta nueva linea.

## Limites de esta linea

- La rama de traducciones sigue su desarrollo independiente. No escribir alli, no cambiar su version y no fusionar de vuelta cambios de fiabilidad por iniciativa propia.
- Mantener ancestro comun. La integracion futura es traducciones -> fiabilidad, revisada por diferencias; nunca copiar una carpeta antigua sobre el programa nuevo.
- La tanda 01B alinea la identidad a 1.5.0.1 y regenera el inventario; los otros 625 archivos de PMM quedan intactos. No afirmar que esto significa hardening terminado o release publicada.
- Mantener version, build y hashes coherentes en cada tanda. No renumerar componentes ni hacer sustituciones globales. No repetir 01B, ya cerrada.
- Host/Runtime reconstruidos y el research FixLab viven en `Development/Reliability/NativeCandidates/`. Consultar el handoff actual antes de usar indicaciones historicas de una sesion concreta.
- Los fuentes Host/Runtime tienen advertencias de procedencia/paridad. No sobreescribir ejecutables sin una integracion identificable, hashes, rollback y prueba incremental del usuario.
- Preservar contratos de Workspace, casos, CKL, merge y recuperacion; cualquier migracion debe ser explicita, reversible y probada.
- No renombrar masivamente rutas compartidas mientras se traducen. Mantener claves de catalogos, placeholders, nativeName, fallback, activacion y RTL/LTR. El contrato heredado de localizacion requiere Windows PowerShell 5.1 hasta que exista una migracion real verificada.
- Las mejoras buscan seguridad, fiabilidad y procedencia verificable: no ocultar funciones al antivirus, no desactivar protecciones, no pedir exclusiones y no restaurar automaticamente archivos puestos en cuarentena.

## GitHub y comprobaciones

No hay autorizacion permanente para escrituras remotas. Solicitar autorizacion explicita para cada intervencion que no la tenga ya. Agrupar cambios relacionados en un commit coherente. Los commits de desarrollo llevan `[skip ci]` y no deben disparar Actions, CI ni tests remotos. No crear PR, tag, release ni cambiar Latest por iniciativa propia. Revisar los triggers antes de publicar: `[skip ci]` no es una garantia universal para todos los eventos.

No ejecutar workflows para esta rama. Las pruebas funcionales de desarrollo las realiza el usuario localmente salvo peticion expresa. Separar inspeccion estatica de pruebas funcionales y de analisis antivirus reales; documentar exactamente lo realizado. La autorizacion para preparar esta rama no autoriza subidas de muestras a terceros ni compra/emision de certificados.

Actualizar `Development/Reliability/STATUS.md` al completar un paso. No marcar pendientes como implementados ni prometer cero detecciones o aprobacion automatica de Nexus.

C1 usa el modulo LOCAL NativeCandidates/Supervision desde Host/Runtime. Conservar sus hashes y staging en ambas recetas. Ver SESSION_PLAN.md para orden real; IDs 02/03 son areas, no cronologia.
