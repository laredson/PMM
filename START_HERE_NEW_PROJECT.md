# START HERE - PMM reliability / nuevo proyecto

Este archivo es el punto de entrada autoritativo para cualquier chat, proyecto, Work o Codex nuevo que deba continuar el desarrollo de PMM.

Repositorio: `laredson/PMM`  
Rama de trabajo: `v1.5.0.1-PMM-reliability`  
Commit anterior a este handoff: `552a4562b53a7142dfc8c2e5a67abacd6b79b61e`

## Regla principal

NO pedir al usuario un ZIP de conversaciones anteriores como primer paso.

El estado de desarrollo, las decisiones, las evidencias y la historia necesaria estan versionados en GitHub. Si el entorno dispone de un checkout local, usar ese checkout y Git directamente. Si solo dispone de GitHub remoto, leer esta rama y reconstruir desde fuentes/pins documentados.

La unica excepcion actual son DOS binarios I01 que se compilaron localmente pero no pudieron transferirse por el conector del chat anterior. No son informacion perdida: las fuentes, builders, hashes y receta para reproducirlos estan en Git.

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
11. `Development/Reliability/Integration/I01/README.md`
12. Ultimos `SESSION*_FINDINGS.md` / `SESSION*_CHECKS.json` relevantes al bloque que se vaya a tocar.

Despues leer el contrato de la candidata concreta antes de modificarla.

## Estado ejecutivo en una frase

La rama contiene todo el research y las reconstrucciones Host/Runtime/FixLab hasta 04A-6B. Host y Runtime C2B ya se ensamblaron como una aplicacion I01 reproducible, pero los DOS EXE I01 no estan todavia en `PMM/` remoto; el paquete remoto continua s01b. FixLab reconstruido sigue aislado en `Development/Reliability/NativeCandidates/FixLab/` y NO sustituye al FixLab original.

## Objetivo inmediato

Si el nuevo entorno tiene acceso local completo al repositorio y puede escribir binarios:

1. comprobar que la rama/checkout corresponden a este handoff;
2. reconstruir I01 desde la base y las fuentes versionadas, o reutilizar binarios locales SOLO si coinciden exactamente con los hashes documentados;
3. integrar juntos los cinco archivos I01 en `PMM/`;
4. actualizar Git con un unico commit de desarrollo `[skip ci]`;
5. no crear PR, tag, release ni ejecutar Actions;
6. pedir al usuario que haga Pull con GitHub Desktop y pruebe el programa real;
7. registrar arranque, cierre, segundo arranque y tiempos;
8. despues continuar 04A-6C y el resto del plan.

No modificar pins para conseguir que una compilacion distinta pase.

## Identidades importantes

Paquete remoto actual s01b:
- build: `PMM-v1.5.0.1-reliability-s01b`
- PMM tree: `09df5c45aee3390c6b8ea235c8afa4e149a9f1fa`
- 629 archivos / 628 filas de checksum / 0 mismatches.

I01 reproducible:
- build: `PMM-v1.5.0.1-reliability-i01`
- PMM tree esperado: `12e01ba3a24a2c0ce5e74d681b4931307c845a56`
- Host SHA-256: `a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c`
- Runtime SHA-256: `b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f`
- FixLab original conservado SHA-256: `8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe`.

## Filosofia de integracion acordada con el propietario

`Development/Reliability/NativeCandidates/` se conserva como laboratorio, evidencia e historial. Pero esta rama SI es la rama de prueba ejecutable: cuando un bloque este suficientemente cerrado, se integra tambien en `PMM/` para que el propietario pueda probarlo mediante GitHub Desktop. No es necesario mantener la rama siempre funcional durante el desarrollo.

Evitar acumular todos los reemplazos hasta el final. Preferir:

`candidata -> pruebas -> integracion PMM -> prueba Windows del usuario -> siguiente bloque`.

Las traducciones siguen en una linea separada y se integraran de forma controlada mas adelante; no copiar carpetas completas ni traer binarios antiguos durante ese merge.

## Seguridad y AV

El objetivo es fiabilidad, procedencia y un paquete auditable; no ocultar comportamiento a antivirus. No desactivar protecciones, no pedir exclusiones y no restaurar automaticamente archivos en cuarentena. No prometer check verde de Nexus. Los escaneos reales y envios externos requieren autorizacion.

Continua en `Development/Reliability/NEW_PROJECT_HANDOFF.md`.
