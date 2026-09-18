# PMM v1.5.0.1 - linea de fiabilidad

Rama: v1.5.0.1-PMM-reliability. Ultima entrega: **02B, comparacion del Host y
gate Windows guardados**. No es release ni aprobacion de sustitucion.

Paquete sin cambios desde 01B: 1.5.0.1, build PMM-v1.5.0.1-reliability-s01b.
Los 629 archivos del programa conservan sus bytes; idiomas y rama donante intactos.

## Continuar

[Development/Reliability/NEXT_SESSION.md](Development/Reliability/NEXT_SESSION.md):
03A, SOLO Runtime candidato. No repetir las entregas cerradas ni pedir el ZIP.

[STATUS.md](Development/Reliability/STATUS.md),
[SESSION02B_FINDINGS.md](Development/Reliability/SESSION02B_FINDINGS.md),
[SESSION02B_CHECKS.json](Development/Reliability/SESSION02B_CHECKS.json) y
[WINDOWS_HOST_ACCEPTANCE.md](Development/Reliability/WINDOWS_HOST_ACCEPTANCE.md)
conservan lo hecho, lo no probado y los bloqueos.

La fuente Host S02B esta en Development/Reliability/NativeCandidates/Host/.
Su compilacion es repetible en el entorno registrado pero no equivalente al
original por demostracion. No copiar el EXE candidato sobre el programa.
Faltan validacion del origen HWND, revision del sondeo/drenaje y aceptacion
Windows antes de promocion. REL-01 sigue abierto; no afirmar cero detecciones.

Los registros 01B/02A son historicos. BASELINE.json conserva el ancestro comun;
TRANSLATION_INTEGRATION.md y SESSION_PLAN.md conservan el plan de integracion.
Toda tanda guarda fuentes e informes antes de cerrar y requiere su autorizacion
de escritura, sin activar CI de desarrollo, PR, tags o releases por iniciativa propia.
