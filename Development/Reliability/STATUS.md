# Estado de la linea v1.5.0.1

**02A cerrada: fuente candidata del Host, build y evidencia guardados.**
Fecha: 2026-09-18. Entrada: a0c74b8fe2210ba55b1c0eed47eb6c701e3de330.
Retomar [NEXT_SESSION.md](NEXT_SESSION.md): 02B, solo comparacion del Host.

01B sigue cerrada: version/build/inventario coherentes. En 02A los 629 archivos
de PMM/ permanecen identicos, con build PMM-v1.5.0.1-reliability-s01b.
La candidata vive fuera del paquete, bajo NativeCandidates/Host/.

| ID | Estado real | Proxima accion |
| --- | --- | --- |
| REL-00 | Identidades binarias conocidas; relacion del hash VT con ZIP RC30 documentada | Tabla de motores y superficie funcional/red pendientes |
| REL-01 / Host | Candidata reconstruida, compilada y conservada; NO equivalencia certificada | 02B comparacion; 05 aceptacion Windows antes de reemplazar |
| REL-01 / Runtime y FixLab | Pendientes, sin cambios | 03 y 04 |
| REL-02 | CERRADO desde 01B; preservado en 02A | Mantener version/hashes coherentes |
| REL-03 a REL-07 | Pendientes | SESSION_PLAN.md |
| LOC-MERGE | No realizado; traducciones intactas | Integracion posterior autorizada |

El candidato tiene SHA-256 62fc4b234ea145c6e3dadcc51366c0ebbca109f7b5a11dcb17deda32e927257f.
Dos builds en rutas distintas fueron byte-identicos en el entorno usado.
Cinco tests Go de estados (incluidos 16 subcasos HWND) y nueve tests Python
pasaron. No prueban Win32: no se ejecutaron PMM, candidato, WPF, Runtime,
FixLab ni antivirus. El helper de icono ejecutado es una herramienta de build.

El original y candidato difieren; la fuente es RECONSTRUCTION, no recuperacion
del original. No se ha reemplazado, firmado o publicado ningun ejecutable.
La advertencia SOURCE_STATUS.md se conserva. Los campos de verificacion
historicos no se reescriben como si hubiese habido paridad Windows.

SESSION02A_FINDINGS.md, SESSION02A_CHECKS.json y NativeCandidates/Host/evidence/
conservan los hechos, hashes, comandos, diff y logs de esta tanda. Los fuentes
estan en Git y pueden recompilarse; no dependen solo de temporales del chat.
