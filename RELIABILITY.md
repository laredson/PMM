# PMM v1.5.0.1 - fiabilidad independiente

Rama v1.5.0.1-PMM-reliability. **04A-6A publicada en esta rama.**
El commit portador de Development/Reliability/SESSION04A6A_PUBLICATION.json
incorpora la entrega conservada sobre 587b4ed, sin nuevos cambios funcionales.
Los indicadores PENDING en FINDINGS/CHECKS corresponden al cierre local anterior;
el registro de publicacion actualiza ese estado, no la evidencia de pruebas.

CoreR1 agrega ExecuteBounded: plan/revision, snapshot/membership, transformaciones
acotadas y PAK verificado en memoria. Sin escritura en juego/PMM ni instalacion.
104 Test Go/44 Python, race Linux y tres PAK artificiales verificados por Python.
No equivale a core general ni aceptacion Windows/Unreal/Palworld. REL-01 abierta.

[Continuar](Development/Reliability/NEXT_SESSION.md),
[estado](Development/Reliability/STATUS.md),
[hallazgos](Development/Reliability/SESSION04A6A_FINDINGS.md) y
[comprobaciones](Development/Reliability/SESSION04A6A_CHECKS.json).
Siguiente: guardado transaccional aislado 04A-6B. No repetir la publicacion de 6A.

Paquete intacto: 1.5.0.1/s01b, 629 archivos/628 hashes. Otras candidatas y codecs
conservados. No copiar CoreR1-tests.exe sobre PMMFixLab.exe. Sin release, PR o tag.
