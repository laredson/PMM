# PMM v1.5.0.1 - fiabilidad independiente

Rama v1.5.0.1-PMM-reliability. Ultimo cierre: **04A-5B, captura y dossier**.
CaptureCore verifica bytes de entradas y documentos en snapshots privados. Esto
no convierte PLAN_VALID en TRANSFORM_READY ni prueba pertenencia a archives.

55 tests Go Linux/20 Python, race y dos escenarios sinteticos con oracle Python.
Windows: adaptador y harness compilados, NO ejecutados. Schemas reales y motor
completo pendientes. No se cambia el paquete: 1.5.0.1/s01b, 629 archivos/628 hashes.

Retomar [NEXT_SESSION](Development/Reliability/NEXT_SESSION.md),
[STATUS](Development/Reliability/STATUS.md) y
[hallazgos 04A-5B](Development/Reliability/SESSION04A5B_FINDINGS.md).
Codigo/contrato: [CoreR1](Development/Reliability/NativeCandidates/FixLab/CoreR1/README.md).
REL-01 y gates anteriores abiertos. Sin reemplazos, release, PR, tag o CI nuevo.
