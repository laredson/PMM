# Retomar desde un nuevo proyecto - I01 pendiente de binarios remotos

Punto de entrada obligatorio: `START_HERE_NEW_PROJECT.md`.

Este handoff hace que el contexto necesario viva en GitHub. No pedir al usuario un
ZIP de chats anteriores antes de leer `NEW_PROJECT_HANDOFF.md`,
`NEW_PROJECT_STATE.json` y `HISTORY_INDEX.md`.

## Estado inmediato

La rama remota contiene toda la fuente, research, builders, contratos y evidencias
hasta 04A-6B, mas la receta I01. El paquete `PMM/` remoto aun sigue s01b porque
el conector del chat anterior no pudo transferir los DOS EXE I01 grandes.

I01 se puede reconstruir solo desde Git:
- Host C2B SHA-256: a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c
- Runtime C2B SHA-256: b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f
- I01 PMM tree esperado: 12e01ba3a24a2c0ce5e74d681b4931307c845a56
- Build: PMM-v1.5.0.1-reliability-i01
- FixLab permanece original.

## Primera accion para un entorno con checkout local

1. Comprobar rama, HEAD y `git status`. No pisar trabajo local del usuario.
2. Leer `Integration/I01/README.md` y builders Host/Runtime.
3. Si los binarios I01 ya existen localmente, aceptarlos SOLO si sus hashes coinciden.
   Si no existen, reconstruirlos desde las fuentes/versiones pinneadas; no pedir
   primero un ZIP antiguo al usuario.
4. Ensamblar/verificar I01 y actualizar juntos exactamente cinco archivos de PMM:
   Host EXE, Runtime EXE, BUILD_ID, RELEASE_MANIFEST y SHA256SUMS.
5. Commit/push con `[skip ci]`, sin Actions/PR/tag/release.
6. Confirmar al usuario que ahora SI puede hacer Pull por GitHub Desktop.
7. Esperar/priorizar feedback real Windows antes de otra integracion grande:
   ventana visible, UI utilizable, cierre, segundo inicio, tiempos y logs si falla.

## Despues de I01

- Corregir regresiones y medir/optimizar startup sin quitar verificaciones a ciegas.
- Retomar 04A-6C: aceptacion Windows de PublishCandidate/guardado transaccional.
- Completar schemas/serializers/relocalizacion/V2-CLI antes de sustituir FixLab.
- Cerrar Host/Runtime gates restantes.
- Integrar idiomas mas adelante segun TRANSLATION_INTEGRATION.md.
- Packaging/firma/preflight al final; no prometer Nexus verde.

Research completado NO se repite. Consultar HISTORY_INDEX.md para cada tanda.
