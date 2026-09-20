# PMM v1.5.0.1 - desarrollo de fiabilidad

**El programa PMM/ sigue usando los ejecutables originales.** La version visible
1.5.0.1 y build s01b se alinearon en 01B; no indican candidatas instaladas.
Los cambios de desarrollo estan en Development/Reliability/NativeCandidates/
DENTRO de esta misma rama. Pull no recompila PMM.exe automaticamente.
Ver [Que estas ejecutando](Development/Reliability/RUNNING_VERSION.md).

04A-6B agrega guardado transaccional aislado del resultado acotado de FixLab:
PAK/informe/manifiesto/completion, verificacion de bytes y commit sin reemplazo.
No modifica el juego, no es una release de PMM ni una garantia antivirus.
Windows implementado/compilado pero su aceptacion real sigue pendiente.

[STATUS](Development/Reliability/STATUS.md),
[NEXT_SESSION](Development/Reliability/NEXT_SESSION.md),
[hallazgos 6B](Development/Reliability/SESSION04A6B_FINDINGS.md) y
[checks 6B](Development/Reliability/SESSION04A6B_CHECKS.json) conservan el avance.
CoreR1 incluye un runner de pruebas Windows para usar con el harness separado,
NO con el ejecutable del programa. Siguiente: 04A-6C, aceptacion Windows del guardado.
