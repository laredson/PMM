# Estado actual - I02 en prueba / 04A-6C validado en Win10 NTFS

El contexto necesario para continuar en un proyecto/chat nuevo esta ahora
centralizado en:
- `START_HERE_NEW_PROJECT.md`
- `NEW_PROJECT_HANDOFF.md`
- `NEW_PROJECT_STATE.json`
- `HISTORY_INDEX.md`
- `NEW_PROJECT_PROMPT.md`.

No se necesita el historial de esta conversacion para entender el estado.

## Paquete de la rama

`PMM/` ya es I02:
- 1.5.0.1 / `PMM-v1.5.0.1-reliability-i02`
- tree `9ef22d5815943ce50413dfa7e09b474b06a22860`
- 629 archivos / 628 checksums / 0 mismatches
- Host y Runtime C2B nuevos; FixLab ejecutable original conservado.

I02 conserva byte-identicos los ejecutables I01 y corrige el alcance privado de
Desktop: el proyecto local es `Workspace`, la configuracion generada queda en
`Workspace/.codex/config.toml` y las opciones preexistentes se conservan. PMM ya
no genera `PMM/.codex/config.toml`; no borra automaticamente un archivo legado.
Las regresiones locales pasan con 14 aserciones de routing y 32 de binding.

## I01

Fuentes, builders, receta, evidencia y los dos EXE C2B estan en Git. SESSION_I01B
cerro la limitacion de transferencia del chat anterior mediante reconstruccion
local verificable, sin cambiar pins.

Esperados:
- Host `a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c`
- Runtime `b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f`
- PMM tree I01 `12e01ba3a24a2c0ce5e74d681b4931307c845a56`
- Build `PMM-v1.5.0.1-reliability-i01`.

Los cinco cambios del paquete ya estan integrados juntos. La siguiente accion es
que el propietario haga Pull y pruebe el programa real en Windows: ventana visible,
UI utilizable, cierre, segundo arranque, tiempos y logs ante fallo.

## Research conservado

04A-6C corrige el guardado candidato en Windows e implementa la interfaz
ExecuteAndPublishCandidate. NO se integra al FixLab original.
Ultima evidencia: 141 Test Go + 4 targets Fuzz con seeds PASS; 50 Python PASS,
2 symlink SKIP; harness Windows independiente 40 PASS; dos builds identicos.
Win10 19045 / NTFS / token no elevado. 25 rondas de cuatro publicaciones
concurrentes PASS. Vet Windows/Linux y cross-build Linux PASS; no ejecucion
Linux ni race nuevos. Ver SESSION04A6C_FINDINGS.md y SESSION04A6C_CHECKS.json.
Aceptacion entre entornos PARCIAL: Win11, AV concurrente y disco lleno real no
probados. No implica aceptacion Unreal/Palworld ni schemas/serializers reales.
El propietario autorizo avanzar este laboratorio mientras prueba I01, sin otra
integracion PMM. Proximo research: contrato V2/CLI candidato-only y pendientes
de matriz Windows cuando haya entorno; priorizar cualquier regresion I01.

Host/Runtime C2B estan integrados en I01 pero no aceptados aun en Windows real.
Optimizar inicio queda planificado despues de medir I01.

Traducciones continuan separadas y se integraran de forma controlada mas adelante.

No release, no tag, no PR, no workflow. No garantia antivirus/Nexus.
