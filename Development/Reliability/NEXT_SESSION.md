# Retomar - I02 en prueba, 04A-6C Win10 validado

Punto de entrada obligatorio: `START_HERE_NEW_PROJECT.md`.

Este handoff hace que el contexto necesario viva en GitHub. No pedir al usuario un
ZIP de chats anteriores antes de leer `NEW_PROJECT_HANDOFF.md`,
`NEW_PROJECT_STATE.json` y `HISTORY_INDEX.md`.

## Estado inmediato

La rama contiene toda la fuente, research, builders, contratos y evidencias hasta
04A-6C (Win10 NTFS e interfaz candidata; matriz entre entornos parcial).
SESSION_I01B reconstruyo localmente e integro los DOS EXE I01 junto con
sus tres metadatos. La limitacion de transferencia anterior esta cerrada.

I02 integrado:
- Host C2B SHA-256: a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c
- Runtime C2B SHA-256: b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f
- I02 PMM tree esperado: 9ef22d5815943ce50413dfa7e09b474b06a22860
- Build: PMM-v1.5.0.1-reliability-i02
- Proyecto/configuracion Desktop: Workspace / Workspace/.codex/config.toml
- FixLab permanece original.

## Primera accion

1. Comprobar rama, HEAD y `git status`. No pisar trabajo local del usuario.
2. Confirmar que `PMM/Resources/Metadata/BUILD_ID.txt` identifica I02 y que el
   arbol PMM coincide con `9ef22d5815943ce50413dfa7e09b474b06a22860`.
3. Recoger el resultado de la prueba I02 que el propietario esta realizando.
4. Esperar/priorizar feedback real antes de otra integracion grande:
   ventana visible, UI utilizable, cierre, segundo inicio, tiempos y logs si falla.
5. Registrar el resultado sin convertir una compilacion correcta en aceptacion
   funcional. Ante una regresion, corregirla antes de integrar otro bloque grande.

## Siguiente bloque

El propietario autorizo continuar el laboratorio mientras prueba I01. 04A-6C
ya corrigio publicacion Windows y agrego ExecuteAndPublishCandidate; NO repetir.
Leer SESSION04A6C_FINDINGS/CHECKS e INTEGRATION_CONTRACT.md. Las siguientes
acciones son delimitar la orquestacion V2/CLI candidato-only (sin instalar) y
completar la matriz en otros entornos cuando esten disponibles. No afirmar
schemas reales/paridad completa ni sustituir FixLab por este harness.

- Corregir regresiones y medir/optimizar startup sin quitar verificaciones a ciegas.
- Completar matriz Windows pendiente de 6C; Win10 NTFS ya tiene evidencia real.
- Completar schemas/serializers/relocalizacion/V2-CLI antes de sustituir FixLab.
- Cerrar Host/Runtime gates restantes.
- Integrar idiomas mas adelante segun TRANSLATION_INTEGRATION.md.
- Packaging/firma/preflight al final; no prometer Nexus verde.

Research completado NO se repite. Consultar HISTORY_INDEX.md para cada tanda.
