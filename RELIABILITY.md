# PMM v1.5.0.1 - fiabilidad independiente

Rama v1.5.0.1-PMM-reliability. Ultima tanda **04A-4: lectura/estructura UAsset**.
PMMDLT1, PAKV11 y UAsset son bibliotecas aisladas, no motor FixLab completo.
El programa distribuido sigue intacto: 1.5.0.1 / build s01b, 629 archivos/628 hashes.

UAsset agrega perfil explicito, summary/names/imports/exports/dependencias,
limites, rangos y referencias, con secciones opacas identificadas. Header-only no
prueba que exista .uexp. No se decodifican propiedades ni se reescriben assets.
23 tests Go, 12 Python, seis fixtures leidas independientemente, race Linux y
fuzz acotado. Harness TEST Windows reproducido; Windows/game/AV NO ejecutados.

Host/Runtime/UIBridge/Supervision C2B, PMMDLT1/PAKV11, recetas, pins y traducciones
no cambian. Source original, motor completo, REL-01 y gates reales pendientes.

Retomar [NEXT_SESSION](Development/Reliability/NEXT_SESSION.md): 04A-4B,
serializacion/relocalizacion acotadas. [STATUS](Development/Reliability/STATUS.md),
[hallazgos](Development/Reliability/SESSION04A4_FINDINGS.md) y
[checks](Development/Reliability/SESSION04A4_CHECKS.json) registran el cierre.
No reinstalar harnesses como PMM.exe/PMMRuntime.exe/PMMFixLab.exe.
