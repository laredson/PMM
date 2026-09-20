# Retomar - I02 arranca, 04A-6D Win10 validado

Punto de entrada obligatorio: `START_HERE_NEW_PROJECT.md`.

Este handoff hace que el contexto necesario viva en GitHub. No pedir al usuario un
ZIP de chats anteriores antes de leer `NEW_PROJECT_HANDOFF.md`,
`NEW_PROJECT_STATE.json` y `HISTORY_INDEX.md`.

## Estado inmediato

La rama contiene toda la fuente, research, builders, contratos y evidencias hasta
04A-6D (job V2/CLI candidato-only y commit Windows estable; matriz parcial).
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
3. Conservar el resultado ya recibido: I02 arranca y funciona a nivel basico.
4. Recoger/priorizar el resto del feedback antes de otra integracion grande:
   UI detallada, cierre, segundo inicio, tiempos y logs si falla.
5. Registrar el resultado sin convertir una compilacion correcta en aceptacion
   funcional. Ante una regresion, corregirla antes de integrar otro bloque grande.

## Siguiente bloque

El propietario autorizo continuar el laboratorio mientras prueba I02. 04A-6D ya
implemento job V2/CLI candidato-only y sustituyo el rename Windows inestable por
commit de marcador; NO repetir. Leer SESSION04A6D_FINDINGS/CHECKS,
JOB_V2_CONTRACT e INTEGRATION_CONTRACT. Lo siguiente es ampliar semantica real
acotada y completar matriz cuando haya otros entornos. No afirmar paridad completa
ni sustituir FixLab por este harness/CLI.

- Corregir regresiones y medir/optimizar startup sin quitar verificaciones a ciegas.
- Completar matriz pendiente de 6D; Win10 NTFS ya tiene evidencia real amplia.
- Completar schemas/serializers/relocalizacion y V2 completo antes de sustituir FixLab.
- Cerrar Host/Runtime gates restantes.
- Integrar idiomas mas adelante segun TRANSLATION_INTEGRATION.md.
- Packaging/firma/preflight al final; no prometer Nexus verde.

Research completado NO se repite. Consultar HISTORY_INDEX.md para cada tanda.
