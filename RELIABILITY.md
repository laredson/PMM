# PMM v1.5.0.1 - fiabilidad independiente

Rama v1.5.0.1-PMM-reliability. Ultima tanda **04A-3: PAK v11/readback**.
PMMDLT1 y PAKV11 son componentes reconstruidos separados, no un motor FixLab completo.
No se ha sustituido ningun ejecutable del programa distribuido.

PAKV11 agrega escritor/lector/Verify, indices y hashes, rutas seguras y limites.
20 tests Go, 13 Python, race Linux; 17 paquetes sinteticos/240 archivos contrastados
con lector Python independiente y un golden manual. Dos builds del harness Windows
identicos; Windows/Unreal/Palworld NO ejecutados. No hay escaneo antivirus.

Paquete conserva 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b, 629 archivos y 628 hashes.
Host/Runtime/UIBridge/Supervision C2B, PMMDLT1, traducciones y recetas intactos.
REL-01, recuperacion source original, UAsset/core/V2/CLI y gates reales pendientes.

Retomar [NEXT_SESSION](Development/Reliability/NEXT_SESSION.md): 04A-4 estructura
UAsset aislada. [STATUS](Development/Reliability/STATUS.md),
[hallazgos](Development/Reliability/SESSION04A3_FINDINGS.md) y
[checks](Development/Reliability/SESSION04A3_CHECKS.json) conservan el cierre.
No rehacer componentes desde el chat ni reinstalar viejos binarios de los ZIP.
