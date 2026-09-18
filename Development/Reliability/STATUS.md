# Estado v1.5.0.1 - cierre acotado 04A-4C

04A-4C CERRADA solo en componente postProcess con schema escalar externo.
Entrada 7b0a030ec3f5dd38249a6c47582d8f8c72cd1900; 2026-09-18.
04A completa/REL-01 ABIERTAS. No motor FixLab completo ni promocion autorizada.

| Area | Estado real |
| --- | --- |
| Paquete PMM | 1.5.0.1/s01b, 629 archivos/628 hashes intactos |
| PMMDLT1/PAKV11 | Componentes previos conservados |
| UAsset Read/RewriteNames | Sin cambios; no relocalizacion de payload opaco |
| PostProcess | Prefijo unversioned escalar, schema externo, pins antes/despues, dos cambios int32 |
| Schema real/core R1/V2/CLI | Pendientes; receta actual sola no habilita esta API |
| Host/Runtime/UIBridge/Supervision | Candidatas C2B intactas; gates Windows pendientes |
| Traducciones/recetas | Intactas, sin fusion ni cambios de pins |

56 tests Go (39+17) / 31 Python (20+11), siete packets de transformacion y las
6 lecturas/12 reescrituras previas contrastados independientemente; race Linux PASS.
Fuzz y dos builds TEST Windows registrados en SESSION04A4C_CHECKS. Windows NO
ejecutado; schemas sinteticos, no reparaciones de juego. No analisis antivirus.

El original escribe null en el payload; safe solo sustituye la precarga.
Nuestra candidata deriva el campo mediante schema: no usa 120 como permiso de
escritura y no cambia coincidencias ajenas. No declara paridad con el original.
Siguiente 04A-5A: plan/requisitos core R1 y procedencia de schema; leer NEXT_SESSION.
