# Retomar desde un nuevo proyecto - I01 integrado, prueba Windows pendiente

Punto de entrada obligatorio: `START_HERE_NEW_PROJECT.md`.

Este handoff hace que el contexto necesario viva en GitHub. No pedir al usuario un
ZIP de chats anteriores antes de leer `NEW_PROJECT_HANDOFF.md`,
`NEW_PROJECT_STATE.json` y `HISTORY_INDEX.md`.

## Estado inmediato

La rama contiene toda la fuente, research, builders, contratos y evidencias hasta
04A-6B. SESSION_I01B reconstruyo localmente e integro los DOS EXE I01 junto con
sus tres metadatos. La limitacion de transferencia anterior esta cerrada.

I01 integrado:
- Host C2B SHA-256: a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c
- Runtime C2B SHA-256: b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f
- I01 PMM tree esperado: 12e01ba3a24a2c0ce5e74d681b4931307c845a56
- Build: PMM-v1.5.0.1-reliability-i01
- FixLab permanece original.

## Primera accion

1. Comprobar rama, HEAD y `git status`. No pisar trabajo local del usuario.
2. Confirmar que `PMM/Resources/Metadata/BUILD_ID.txt` identifica I01 y que el
   arbol PMM coincide con `12e01ba3a24a2c0ce5e74d681b4931307c845a56`.
3. Pedir al propietario que haga Pull por GitHub Desktop y pruebe I01 en Windows.
4. Esperar/priorizar feedback real antes de otra integracion grande:
   ventana visible, UI utilizable, cierre, segundo inicio, tiempos y logs si falla.
5. Registrar el resultado sin convertir una compilacion correcta en aceptacion
   funcional. Ante una regresion, corregirla antes de integrar otro bloque grande.

## Despues de la aceptacion I01

- Corregir regresiones y medir/optimizar startup sin quitar verificaciones a ciegas.
- Retomar 04A-6C: aceptacion Windows de PublishCandidate/guardado transaccional.
- Completar schemas/serializers/relocalizacion/V2-CLI antes de sustituir FixLab.
- Cerrar Host/Runtime gates restantes.
- Integrar idiomas mas adelante segun TRANSLATION_INTEGRATION.md.
- Packaging/firma/preflight al final; no prometer Nexus verde.

Research completado NO se repite. Consultar HISTORY_INDEX.md para cada tanda.
