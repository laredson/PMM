# PMM v1.5.0.1 - fiabilidad independiente

Rama: v1.5.0.1-PMM-reliability. **Ultimo cierre 02C-2B; siguiente 04A (FixLab).**
Los IDs son areas de trabajo; no implican volver a pasos ya cerrados.

UIBridge ya esta integrado en las FUENTES CANDIDATAS de Host y Runtime: identidad
por SO, captura antes de Wait, ACK/heartbeat, generacion, directorio nuevo por UI,
y handoff validado en el hilo del splash. El state.txt del Host es solo progreso.
No se modifican los 629 archivos del programa instalado: build 1.5.0.1/s01b.

91 tests Go de modelos/fixtures con aserciones y cuatro suites race Linux; 18 tests
Python; compilacion/vet de cuatro modulos Windows. Dos builds iguales por candidata
en el entorno registrado. **No IPC/GUI/PowerShell/PMM/antivirus Windows ejecutados.**
Estas comprobaciones no autorizan reemplazar ejecutables ni cierran REL-01.

Leer [NEXT_SESSION](Development/Reliability/NEXT_SESSION.md),
[STATUS](Development/Reliability/STATUS.md),
[hallazgos C2B](Development/Reliability/SESSION02C2B_FINDINGS.md),
[checks](Development/Reliability/SESSION02C2B_CHECKS.json) e
[integracion](Development/Reliability/NativeCandidates/UIBridge/INTEGRATION.md).
Fuentes completos y recetas offline bajo NativeCandidates; evidencia en
IntegrationEvidence/s02c2b. No utilizar los ZIP C1 antiguos como fuente de HEAD.

Quedan Windows real, familias de procesos, manifiesto/pins/rutas, FixLab,
dependencias/reparacion y traducciones finales. No release/tag/PR ni cambios en
main o rama de idiomas. La version visible no significa hardening terminado.
