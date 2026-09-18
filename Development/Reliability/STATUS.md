# Estado v1.5.0.1 - cierre 04A-4

**04A-4 CERRADA: lectura/estructura UAsset como componente aislado.**
Fecha 2026-09-18. Entrada a66cea06e673a169623b3c12821739b0fa6d0b9f.
04A completa/REL-01 siguen abiertas. No hay motor FixLab candidato completo.
Siguiente: 04A-4B serializacion/relocalizacion; leer NEXT_SESSION.md.

| Area | Estado real | Pendiente |
| --- | --- | --- |
| Identidad 01B | 1.5.0.1/s01b; 629 archivos/628 hashes intactos | Mantener |
| Host/Runtime/UIBridge/Supervision | C2B conservado | Windows/bloqueos previos |
| FixLab source original | Ausente; overlay no valido | Solo pistas nuevas |
| PMMDLT1 y PAKV11 | Componentes previos conservados | Integracion y gates engine |
| UAsset | Read perfil 522/1008 explicito, mapas/referencias/rangos | Serializacion/core; datos opacos y compatibilidad real |
| Core/V2/CLI | No es motor completo | Tandas siguientes antes de 04B |
| Familias/manifest/rutas/repair | Bloqueos anteriores abiertos | Antes de promocion |
| Traducciones | Intactas | Fusion posterior autorizada |

23 Test Go con aserciones y 12 Python pasaron. Seis fixtures artificiales con
lectura independiente; race Linux sin incidencias. FuzzRead 1464 entradas,
FuzzTables 21117. Dos builds TEST Windows identicos, vet correcto. Windows NO
executado. No datos reales de juego/donantes, reparaciones ni analisis AV.

UAsset header-only NO afirma presencia de .uexp. ExportRangesChecked con .uexp
solo valida extents, no propiedades; hashes calculados no prueban autenticidad.
Secciones opacas quedan etiquetadas, no descartadas. Versiones no soportadas se
rechazan; 0/0 requiere perfil externo explicitamente autorizado por el caller.

SESSION04A4_FINDINGS/CHECKS y UAsset/evidence conservan codigo y resultados.
Registros anteriores historicos, sin reescritura de supuestos PASS.
