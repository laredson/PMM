# PMM: desarrollo de fiabilidad v1.5.0.1

Esta rama es `v1.5.0.1-PMM-reliability`, derivada de `v1.5.0.0-PMM-translated` en el commit `38bd5a934488ac11a6200d3142b889ca86a82f57`.

## Leer primero

1. `RELIABILITY.md`.
2. `Development/Reliability/BASELINE.json` y `STATUS.md`.
3. `Development/Reliability/IMPLEMENTATION_PLAN.md`.
4. `Development/Reliability/TRANSLATION_INTEGRATION.md`.
5. `Development/Source/SOURCE_STATUS.md` antes de cualquier compilacion nativa; despues, los handoffs historicos de `Development/AI/` como contexto, no como estado de esta nueva linea.

## Limites de esta linea

- La rama de traducciones sigue su desarrollo independiente. No escribir alli, no cambiar su version y no fusionar de vuelta cambios de fiabilidad por iniciativa propia.
- Mantener ancestro comun. La integracion futura es traducciones -> fiabilidad, revisada por diferencias; nunca copiar una carpeta antigua sobre el programa nuevo.
- La inicializacion conserva TODOS los archivos de `PMM/` sin cambios. La version objetivo es 1.5.0.1; el paquete heredado todavia declara 1.5.0.0 en VERSION.txt. No afirmar que se ha publicado o implementado una nueva version funcional.
- El manifiesto heredado declara 1.3.4.1. Resolver la coherencia de version, build y hashes como un cambio atomico posterior, no mediante sustitucion global de numeros.
- Los fuentes Host/Runtime tienen una advertencia de desfase respecto a los binarios empaquetados. No sobreescribir ejecutables actuales compilando ese snapshot sin reconciliacion y pruebas locales de paridad. Verificar tambien la procedencia de PMMFixLab y dependencias.
- Preservar contratos de Workspace, casos, CKL, merge y recuperacion; cualquier migracion debe ser explicita, reversible y probada.
- No renombrar masivamente rutas compartidas mientras se traducen. Mantener claves de catalogos, placeholders, nativeName, fallback, activacion y RTL/LTR. El contrato heredado de localizacion requiere Windows PowerShell 5.1 hasta que exista una migracion real verificada.
- Las mejoras buscan seguridad, fiabilidad y procedencia verificable: no ocultar funciones al antivirus, no desactivar protecciones, no pedir exclusiones y no restaurar automaticamente archivos puestos en cuarentena.

## GitHub y comprobaciones

No hay autorizacion permanente para escrituras remotas. Solicitar autorizacion explicita para cada intervencion que no la tenga ya. Agrupar cambios relacionados en un commit coherente. Los commits de desarrollo llevan `[skip ci]` y no deben disparar Actions, CI ni tests remotos. No crear PR, tag, release ni cambiar Latest por iniciativa propia. Revisar los triggers antes de publicar: `[skip ci]` no es una garantia universal para todos los eventos.

No ejecutar workflows para esta rama. Las pruebas funcionales de desarrollo las realiza el usuario localmente salvo peticion expresa. Separar inspeccion estatica de pruebas funcionales y de analisis antivirus reales; documentar exactamente lo realizado. La autorizacion para preparar esta rama no autoriza subidas de muestras a terceros ni compra/emision de certificados.

Actualizar `Development/Reliability/STATUS.md` al completar un paso. No marcar pendientes como implementados ni prometer cero detecciones o aprobacion automatica de Nexus.
