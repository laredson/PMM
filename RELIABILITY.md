# PMM v1.5.0.1 - fiabilidad independiente

Rama v1.5.0.1-PMM-reliability. Ultimo cierre: **04A-5A, planificador core R1**.
PLAN_VALID comprueba metadatos; no autoriza transformacion ni instalacion.
Los ejecutables distribuidos y las traducciones siguen intactos.

CoreR1 enumera donante/destinos/minimos/soporte y requisitos de schemas/entradas.
30 tests Go, 10 Python, race Linux, fuzz y builds TEST; no ejecucion Windows/juego.
La simulacion de 93 destinos de la receta productiva no valida meshes reales.
PMM conserva 1.5.0.1/s01b, 629 archivos/628 hashes correctos.

Retomar [NEXT_SESSION](Development/Reliability/NEXT_SESSION.md),
[STATUS](Development/Reliability/STATUS.md) y
[hallazgos 04A-5A](Development/Reliability/SESSION04A5A_FINDINGS.md).
Codigo y contrato: [CoreR1](Development/Reliability/NativeCandidates/FixLab/CoreR1/README.md).
REL-01 y los gates previos siguen abiertos; no motor FixLab completo ni release nueva.
