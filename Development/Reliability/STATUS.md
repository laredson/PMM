# Estado de la linea v1.5.0.1

Ultimo checkpoint: tanda 01, 2026-09-18. **PARCIAL, con bloqueo de entrada.**
Entrada: df4b2417d3278096f9f66f115bd1237e8d908068.
Retomar: [NEXT_SESSION.md](NEXT_SESSION.md).

## Hecho

Rama independiente y ancestro comun conservados. Tanda 01: trazado el origen de Host/Runtime al commit Guided Flow y contrastada la estructura anterior; documentados los contratos de splash/primer plano y la referencia no localizada de FixLab. Preparada herramienta offline de captura nativa y generacion conjunta de cuatro metadatos. Sintaxis Python comprobada y 12 tests sinteticos locales superados.

## No hecho

No se recuperaron fuentes nativas exactas. No se obtuvieron los bytes completos del paquete en este entorno. No se reconstruyeron/reemplazaron binarios, ni se aplico la propuesta de identidad, ni se regenero el SHA256SUMS del paquete real. No se ejecutaron PMM, Windows/WPF, antivirus, Actions ni tests remotos. No se creo release/tag/PR.

El paquete de la rama sigue siendo el heredado: VERSION.txt = 1.5.0.0; RELEASE_MANIFEST.version = 1.3.4.1. **No presentar ambos asuntos como resueltos.** Las salidas de tests son de la herramienta y sus fixtures, no del paquete real.

| ID | Estado real | Siguiente entrega |
| --- | --- | --- |
| REL-00 | Investigacion parcial; objetos Git identificados, SHA-256 heredados aun no recalculados aqui | Obtener bytes y producir captura local verificable |
| REL-01 | BLOCKED: paridad fuente/binario no demostrada | Tandas 02/03/04; conservar binarios actuales |
| REL-02 | Preparador implementado y probado con fixtures; propuesta NO aplicada | Tanda 01B: identidad y checksums del paquete real |
| REL-03 a REL-07 | Pendientes; plan dividido en tandas acotadas | SESSION_PLAN.md |
| LOC-MERGE | No realizado; rama de traducciones intacta | Integrar solo tras autorizacion y revision semantica |

## Archivos de referencia

SESSION01_FINDINGS.md: evidencia, limitaciones y alcance exacto.
NATIVE_ARTIFACTS.json: tres artefactos, pins declarados y estado no verificado.
session01_prepare.py: preparacion local sin mutar checkout ni hacer red.
test_session01_prepare.py: 12 tests de la herramienta, no de PMM.
SESSION_PLAN.md: entradas y salidas de cada tanda.

## Regla al retomar

No repetir la busqueda inicial a ciegas ni reabrir toda la arquitectura. Leer el bloqueo concreto y cerrar 01B cuando los bytes esten disponibles. No reinterpretar una referencia de source, un hash heredado o un test sintetico como demostracion de paridad de los binarios.
