# Estado v1.5.0.1 - cierre 04A-5A

04A-5A CERRADA: planificador de requisitos core R1 aislado, NO executor.
Entrada 4d8b0ca142dc55fbf066b1a18fac1658dfd6b87b; fecha 2026-09-18.
Siguiente 04A-5B: entradas/snapshots y expediente schema, ver NEXT_SESSION.

| Area | Estado | Pendiente |
| --- | --- | --- |
| Identidad | 1.5.0.1/s01b; 629 archivos y 628 hashes correctos | Mantener |
| Host/Runtime/UIBridge/Supervision | C2B intacto | Gates Windows y bloqueos previos |
| PMMDLT1/PAKV11/UAsset | Primitivas previas intactas | Integracion y paridad reales |
| CoreR1 planner | PLAN_VALID sobre metadata, grupos/minimos/soporte y requisitos | Verificacion de assets/executor |
| Schema provenance | Claim ligado a hashes, DECLARED_UNVERIFIED | Leer/revisar layout real y su procedencia |
| Core completo/V2/CLI | No implementado | No iniciar comparacion 04B aun |
| Traducciones/recetas | Intactas, sin merge | Integracion posterior autorizada |

30 tests Go y 10 Python con opt-ins pasados, race Linux, vet Windows, fuzz 173539.
Dos builds TEST Windows byte-identicos; NO ejecutados. Cuatro planes artificiales
contrastados con oracle Python manual. Receta productiva: 93 destinos SIMULADOS,
no reparacion real. Assets/inputBytesVerified y TRANSFORM_READY siguen false.

No PMM/FixLab original/Windows/juego/AV ni reparaciones ejecutados. Sin sustitucion
de binarios, firma, release/tag/PR. REL-01/gates anteriores permanecen abiertos.
SESSION04A5A_FINDINGS/CHECKS y CoreR1/evidence conservan resultados reales y limites.
