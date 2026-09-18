# Estado v1.5.0.1 - cierre acotado 04A-4B

04A-4B CERRADA como reescritor de nombres/offsets, no como core R1 completo.
Entrada e8608cf0f0283180d99a1c88e085e1a78cfae295. Fecha 2026-09-18.
04A completa y REL-01 siguen ABIERTAS; no hay motor FixLab candidato completo.

| Area | Estado | Pendiente |
| --- | --- | --- |
| PMM distribuido | 629 archivos / 628 hashes; 1.5.0.1/s01b intacto | Mantener |
| Host/Runtime/UIBridge/Supervision | C2B conservado | Windows y bloqueos previos |
| PMMDLT1/PAKV11 | Componentes conservados, sin cambios | Integracion futura |
| UAsset Read | 04A-4 intacto | Aceptacion con datos autorizados |
| RewriteNames | Pins, copia de nombres/hashes, offsets y roundtrip probados | No relocaliza payloads opacos |
| Core R1/postProcess/V2/CLI | No implementados por esta tanda | 04A-4C y siguientes |

39 tests Go (23 previos + 16 nuevos, exports opt-in activados), 20 Python,
race Linux y 19849 entradas finales de FuzzRewritePinned. Doce reescrituras
sinteticas comparadas byte a byte con Python independiente. Dos builds finales
del harness TEST Windows identicos. No Windows/Unreal/juego/original/AV ejecutados.

Restriccion deliberada: si cambia el ancho de un nombre, se rechazan cabeceras
con regiones opacas, .uexp no vacio o BulkDataStart no cero. Sin override.
Las sustituciones de igual ancho mantienen esos bytes en su misma posicion;
no prometen por ello semantica valida del juego. No source original recuperado.

SESSION04A4B_FINDINGS/CHECKS, UAsset/REWRITE_CONTRACT y evidence/s04a4b conservan
el trabajo. NEXT_SESSION define 04A-4C. No repetir codecs ni publicar binarios.
