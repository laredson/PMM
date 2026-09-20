# Estado actual - handoff Git autosuficiente / I01 pendiente de EXE remotos

El contexto necesario para continuar en un proyecto/chat nuevo esta ahora
centralizado en:
- `START_HERE_NEW_PROJECT.md`
- `NEW_PROJECT_HANDOFF.md`
- `NEW_PROJECT_STATE.json`
- `HISTORY_INDEX.md`
- `NEW_PROJECT_PROMPT.md`.

No se necesita el historial de esta conversacion para entender el estado.

## Paquete remoto

`PMM/` sigue s01b, no I01:
- 1.5.0.1 / `PMM-v1.5.0.1-reliability-s01b`
- tree `09df5c45aee3390c6b8ea235c8afa4e149a9f1fa`
- 629 archivos / 628 checksums / 0 mismatches
- Host, Runtime y FixLab ejecutables originales.

## I01

Fuentes, builders, receta y evidencia SI estan en Git. Los dos EXE C2B que forman
I01 no pudieron transferirse desde el sandbox del chat anterior.

Esperados:
- Host `a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c`
- Runtime `b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f`
- PMM tree I01 `12e01ba3a24a2c0ce5e74d681b4931307c845a56`
- Build `PMM-v1.5.0.1-reliability-i01`.

El nuevo entorno debe reconstruir/verificar y publicar directamente esos cinco
cambios si tiene acceso local/Git, sin pedir ZIPs anteriores de entrada.

## Research conservado

04A-6B esta implementado en NativeCandidates/FixLab pero NO integrado al FixLab
original. Ultima evidencia: 130 Go PASS, 52 Python PASS, race enfocado 26 PASS;
Windows-specific compilado, no ejecutado. Siguiente research: 04A-6C.

Host/Runtime C2B estan preparados para I01 pero no aceptados aun en Windows real.
Optimizar inicio queda planificado despues de medir I01.

Traducciones continuan separadas y se integraran de forma controlada mas adelante.

No release, no tag, no PR, no workflow. No garantia antivirus/Nexus.
