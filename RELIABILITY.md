# PMM v1.5.0.1 - fiabilidad independiente

Rama: v1.5.0.1-PMM-reliability. **Ultima entrega 02C-1; siguiente 02C-2.**
Los IDs 02/03 agrupan Host/Runtime; SESSION_PLAN explica el orden de dependencias.

01B conserva identidad 1.5.0.1 y build PMM-v1.5.0.1-reliability-s01b. Las siguientes
tandas construyen candidatas EXTERNAS: los 629 archivos PMM permanecen intactos.
No son versiones instaladas ni fuente original recuperada; no promocionar sin gates.

C1 implementa sondeo PS5.1 del sistema con plazo, captura/EOF acotados, logs raw,
fallos explicitos y timeout CLI validado. Un modulo local Supervision comparte esa
logica entre candidatos sin descargas. 48 tests Go de modelos/stubs y 29 Python,
mas race Linux; dos builds iguales de cada candidata en el entorno registrado.
No Windows/WPF/PowerShell/PMM/antivirus ejecutados, no gestion de familias probada.

Leer [NEXT_SESSION](Development/Reliability/NEXT_SESSION.md),
[STATUS](Development/Reliability/STATUS.md),
[hallazgos](Development/Reliability/SESSION02C1_FINDINGS.md) y
[checks](Development/Reliability/SESSION02C1_CHECKS.json).
[Supervision](Development/Reliability/NativeCandidates/Supervision/README.md)
contiene limites/codigos y cambios visibles. Fuentes y recetas en NativeCandidates.

REL-01 sigue abierto: HWND/canal, familias, Windows, manifiesto/pins, rutas y
repair son requisitos pendientes. No tocar rama de traducciones, main o releases.
