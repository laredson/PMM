# PMM v1.5.0.1 - fiabilidad independiente

Rama v1.5.0.1-PMM-reliability. Ultima entrega: 04A-4B, reescritura acotada
UAsset de nombres/offsets con identidad fijada. No motor FixLab completo.

El paquete mantiene 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b y 629 archivos intactos.
Host/Runtime/UIBridge/Supervision, PMMDLT1, PAKV11 y recetas productivas conservados.

El componente importa nombres/hashes serializados desde headers de referencia
con SHA-256 esperado. Cambios de ancho solo sin regiones opacas, datos .uexp ni
bulk offsets; el resto se rechaza, no se simula soporte de relocalizacion general.
No hay sustitucion de ejecutables ni aceptacion Windows/Unreal/Palworld.

[Continuar](Development/Reliability/NEXT_SESSION.md),
[estado](Development/Reliability/STATUS.md),
[hallazgos](Development/Reliability/SESSION04A4B_FINDINGS.md),
[comprobaciones](Development/Reliability/SESSION04A4B_CHECKS.json).
Siguiente 04A-4C: contratos de payload/core R1 y postProcess; no comparar un motor
inexistente en 04B. REL-01 sigue abierto. No release/tag/PR ni workflows lanzados.
