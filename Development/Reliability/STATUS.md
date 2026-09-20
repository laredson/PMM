# Estado actual - I02 funciona / 04A-6E arrays escalares V2

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

Los cinco cambios del paquete ya estan integrados juntos. El propietario informa
que el programa parece funcionar bien. Faltan registrar cierre, segundo arranque,
UI detallada, tiempos y logs si aparece una regresion.

## Research conservado

04A-6E agrega V2 para recorrer arrays de escalares de ancho fijo sin editarlos y
lo valida desde UAsset hasta job/CLI candidato-only. NO se integra al FixLab
original. UAsset: 63 tests Go top-level, 32 Python y tres verificadores. CoreR1:
154 tests Go top-level, 54 Python PASS / 2 symlink SKIP y seis verificadores.
Ambos harnesses Windows pasaron x3; builds repetidos identicos; vet/cross-build
Linux PASS sin ejecucion Linux ni race. El job `array` comparo 10 outputs y dejo
installed/gameAccepted false. Ver SESSION04A6E_FINDINGS/CHECKS y evidence/s04a6e.
La evidencia amplia de publicacion Win10/NTFS 6D (2.000 secuenciales y 500x4
concurrentes) permanece vigente; el codigo de publicacion no cambio ni se repitio
ese stress. Win11, AV concurrente y disco lleno real no probados.
No implica aceptacion Unreal/Palworld ni schema real autenticado. Proximo research:
fuente de schema real pinneada u otro serializer acotado con evidencia primaria,
ademas de matriz cuando haya otro entorno. Priorizar feedback I02.

Host/Runtime C2B estan integrados en I02 y su arranque basico fue confirmado en
Windows real; falta aceptacion detallada de cierre, segundo arranque, UI y tiempos.
Optimizar inicio queda planificado despues de medir I02.

Traducciones continuan separadas y se integraran de forma controlada mas adelante.

No release, no tag, no PR, no workflow. No garantia antivirus/Nexus.
