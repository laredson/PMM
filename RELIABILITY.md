# PMM v1.5.0.1 - fiabilidad independiente

Rama v1.5.0.1-PMM-reliability. **04A-2 cerrada: componente PMMDLT1 reconstruido.**
No es la fuente original ni un motor FixLab completo. 04A/REL-01 siguen abiertos.

PMMDLT1 lee/aplica parches en memoria con hashes obligatorios de entrada,
referencias y salida; lectura completa, limites y cancelacion. Las pruebas
sinteticas pasan y dos lectores independientes coinciden en la estructura
de los 137 payloads distribuidos. No se transformaron assets reales.

Los 629 archivos PMM/ conservan 628 hashes y build 1.5.0.1/s01b. Host/Runtime/
UIBridge/Supervision y traducciones no cambiaron. No hay ejecutable nuevo instalado,
release ni aceptacion Windows. Los nuevos EXE de prueba NO sustituyen PMMFixLab.

Leer [NEXT_SESSION](Development/Reliability/NEXT_SESSION.md),
[STATUS](Development/Reliability/STATUS.md),
[hallazgos](Development/Reliability/SESSION04A2_FINDINGS.md) y
[checks](Development/Reliability/SESSION04A2_CHECKS.json).
[PMMDLT1](Development/Reliability/NativeCandidates/FixLab/PMMDLT1/README.md)
guarda API, formato, limites, fuentes y recetas offline.
Siguiente 04A-3: PAK v11/readback, despues UAsset/core y orquestacion.
No repetir la busqueda fallida del overlay sin una pista nueva.
