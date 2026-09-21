# START HERE - PMM reliability / nuevo proyecto

Este archivo es el punto de entrada autoritativo para cualquier chat, proyecto, Work o Codex nuevo que deba continuar el desarrollo de PMM.

Repositorio: `laredson/PMM`  
Rama de trabajo: `v1.5.0.1-PMM-reliability`  
Base de integracion I01B: `e83b191e56c916b4de12c34a9d054f4bd6bbd485`
Base de la tanda 04A-6E: `4763e6834c9a797b3fece6b6b0517b65f2881b2a`
Base del paquete I03: `fcd4b5ef8401ada4b6b8c2d79b9477738e15a3ee`
Donante de traducciones I03: `681f7994474ebfd6c2538775767d2002014170f7`

## Regla principal

NO pedir al usuario un ZIP de conversaciones anteriores como primer paso.

El estado de desarrollo, las decisiones, las evidencias y la historia necesaria estan versionados en GitHub. Si el entorno dispone de un checkout local, usar ese checkout y Git directamente. Si solo dispone de GitHub remoto, leer esta rama y reconstruir desde fuentes/pins documentados.

La excepcion anterior de DOS binarios I01 sin transferir quedo cerrada en SESSION_I01B: se reconstruyeron localmente desde las fuentes versionadas, se verificaron sus hashes y se integraron en `PMM/` junto con los tres metadatos I01.

## Cargar estos archivos primero, en este orden

1. `AGENTS.md`
2. `Development/Reliability/NEW_PROJECT_HANDOFF.md`
3. `Development/Reliability/NEW_PROJECT_STATE.json`
4. `Development/Reliability/HISTORY_INDEX.md`
5. `Development/Reliability/NEXT_SESSION.md`
6. `Development/Reliability/STATUS.md`
7. `Development/Reliability/RUNNING_VERSION.md`
8. `Development/Reliability/IMPLEMENTATION_PLAN.md`
9. `Development/Reliability/TRANSLATION_INTEGRATION.md`
10. `Development/Reliability/SESSION_PLAN.md`
11. `Development/Reliability/Integration/I03/README.md`
12. `Development/Reliability/SESSION_I03_TRANSLATION_FINDINGS.md`
13. `Development/Reliability/SESSION_I03_TRANSLATION_CHECKS.json`
14. `Development/Reliability/Integration/I01/README.md`
15. Ultimos `SESSION*_FINDINGS.md` / `SESSION*_CHECKS.json` relevantes al bloque que se vaya a tocar.

Despues leer el contrato de la candidata concreta antes de modificarla.

## Estado ejecutivo en una frase

La rama contiene research hasta 04A-6E y el paquete I03. Host y Runtime C2B de I01 siguen integrados; I02 movio el proyecto/configuracion privada de Codex a `Workspace`; I03 integra 30 idiomas registrados y 23 habilitados sin cambiar los ejecutables. FixLab candidato/CLI sigue aislado y NO sustituye al original.

## Objetivo inmediato

1. comprobar que la rama/checkout corresponden a este handoff;
2. confirmar BUILD_ID I03, hashes y arbol PMM esperado;
3. probar I03 en Windows: selector, aplicar, cierre, segundo arranque y persistencia;
4. revisar al menos English, Español, العربية y varios idiomas importados;
5. conservar el resultado previo: I02 arranca y funciona; vi/uk/cs/ga funcionaron en el donante;
6. corregir cualquier regresion I03 antes de otra integracion grande;
7. continuar despues con SESSION04A6E sin repetir trabajo;
8. no crear PR, tag, release ni ejecutar Actions.

No modificar pins para conseguir que una compilacion distinta pase.

## Identidades importantes

Paquete actual I03:
- build: `PMM-v1.5.0.1-reliability-i03`
- PMM tree esperado: `e0c394997f1dbc172fef3cfc1a755f80f63e1692`
- 631 archivos / 630 filas de checksum / 0 mismatches.
- 30 idiomas registrados / 23 habilitados / 7 reservas.
- proyecto Desktop y configuracion privada: `Workspace` y `Workspace/.codex/config.toml`.
- Host SHA-256: `a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c`
- Runtime SHA-256: `b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f`
- FixLab original conservado SHA-256: `8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe`.

## Filosofia de integracion acordada con el propietario

`Development/Reliability/NativeCandidates/` se conserva como laboratorio, evidencia e historial. Pero esta rama SI es la rama de prueba ejecutable: cuando un bloque este suficientemente cerrado, se integra tambien en `PMM/` para que el propietario pueda probarlo mediante GitHub Desktop. No es necesario mantener la rama siempre funcional durante el desarrollo.

Evitar acumular todos los reemplazos hasta el final. Preferir:

`candidata -> pruebas -> integracion PMM -> prueba Windows del usuario -> siguiente bloque`.

El snapshot aprobado de traducciones ya esta integrado en I03. La rama donante sigue separada para cambios futuros; cualquier delta posterior requiere otra revision controlada.

## Seguridad y AV

El objetivo es fiabilidad, procedencia y un paquete auditable; no ocultar comportamiento a antivirus. No desactivar protecciones, no pedir exclusiones y no restaurar automaticamente archivos en cuarentena. No prometer check verde de Nexus. Los escaneos reales y envios externos requieren autorizacion.

Continua en `Development/Reliability/NEW_PROJECT_HANDOFF.md`.
