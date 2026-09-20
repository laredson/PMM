# START HERE - PMM reliability / nuevo proyecto

Este archivo es el punto de entrada autoritativo para cualquier chat, proyecto, Work o Codex nuevo que deba continuar el desarrollo de PMM.

Repositorio: `laredson/PMM`  
Rama de trabajo: `v1.5.0.1-PMM-reliability`  
Base de integracion I01B: `e83b191e56c916b4de12c34a9d054f4bd6bbd485`

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
11. `Development/Reliability/Integration/I01/README.md`
12. Ultimos `SESSION*_FINDINGS.md` / `SESSION*_CHECKS.json` relevantes al bloque que se vaya a tocar.

Despues leer el contrato de la candidata concreta antes de modificarla.

## Estado ejecutivo en una frase

La rama contiene todo el research y las reconstrucciones Host/Runtime/FixLab hasta 04A-6B. Host y Runtime C2B ya estan integrados en `PMM/` como la aplicacion I01 reproducible; FixLab reconstruido sigue aislado en `Development/Reliability/NativeCandidates/FixLab/` y NO sustituye al FixLab original. La aceptacion funcional Windows de I01 sigue pendiente del propietario.

## Objetivo inmediato

1. comprobar que la rama/checkout corresponden a este handoff;
2. confirmar BUILD_ID I01, hashes y arbol PMM esperado;
3. pedir al usuario que haga Pull con GitHub Desktop y pruebe el programa real;
4. registrar arranque, cierre, segundo arranque, ventana visible, UI utilizable y tiempos;
5. corregir cualquier regresion antes de otra integracion grande;
6. despues continuar 04A-6C y el resto del plan;
7. no crear PR, tag, release ni ejecutar Actions.

No modificar pins para conseguir que una compilacion distinta pase.

## Identidades importantes

Paquete actual I01:
- build: `PMM-v1.5.0.1-reliability-i01`
- PMM tree esperado: `12e01ba3a24a2c0ce5e74d681b4931307c845a56`
- 629 archivos / 628 filas de checksum / 0 mismatches.
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
