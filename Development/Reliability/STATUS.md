# Estado v1.5.0.1 - 04A-6B

**6B implementada como guardado de resultados candidatos; NO incorporada a PMM.exe.**
Version del paquete: 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b.
Leer RUNNING_VERSION.md: fuentes en Development/, EXE originales en PMM/.

6A publicada en fe239c3; 6B agrega PublishCandidate/InspectCandidate, bundle de
cuatro archivos, commit sin reemplazo y error que distingue antes/despues del
commit. Rechaza boundaries protegidos, enlaces/reparse y resultados no verificados.
Reutiliza sin cambios CaptureCore/PlanCore/VerifyMembership/ExecuteBounded y codecs.

130 Test Go PASS con opt-ins (104 previas +26 nuevas); 52 Python PASS; race sobre
las 26 nuevas PASS. Race total se intento pero se interrumpio en prueba previa
costosa; no contado como PASS ni se modifico el test para ocultarlo.
Tres escenarios/30 entradas de PAK comprobadas por Python tras guardado.
Dos builds TEST Windows iguales; Windows/NTFS/DACL reales NO ejecutados aqui.

PMM/ mantiene 629 archivos, 628 hashes y tree
09df5c45aee3390c6b8ea235c8afa4e149a9f1fa. No cambios funcionales al programa
distribuido, traducciones, CKL, fuentes historicos u otros candidatos.
No originales, juego, reparaciones reales, antivirus, Actions, PR, tag o release.

REL-01/engine completo siguen ABIERTOS. Schemas reales/no escalares, relocalizacion
opaca, V2/CLI, Windows y restantes gates no resueltos. Siguiente 6C: aceptacion
Windows del guardado y cierre de interfaz con la futura integracion, no deploy.
SESSION04A6B_FINDINGS/CHECKS registra evidencia y limites. No confundir el bundle
PAK candidato con una compilacion nueva y lista para Nexus de la aplicacion PMM.
