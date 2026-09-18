# Estado de la linea v1.5.0.1

**01B cerrada para identidad e inventario estatico**, 2026-09-18.
Entrada: `74a47df7072f651c91ec114ff235e69bc8d1042a`.
Build: `PMM-v1.5.0.1-reliability-s01b`.
Retomar: [NEXT_SESSION.md](NEXT_SESSION.md).

VERSION, BUILD_ID y RELEASE_MANIFEST estan alineados; SHA256SUMS contiene
628 entradas para 629 archivos. Los otros 625 archivos de PMM no cambian.
El ZIP versionado reproduce el arbol Git de entrada. Los tres nativos coinciden
con sus pins reales. Oodle local no se incluye ni se publica.

| ID | Estado real | Proxima accion |
| --- | --- | --- |
| REL-00 | Hashes nativos verificados; hash reportado asociado al ZIP RC30 por metadata GitHub | Tabla VirusTotal y superficie funcional/red pendientes |
| REL-01 | PENDIENTE: fuente/paridad no certificadas | 02A: SOLO fuente candidata del Host |
| REL-02 | CERRADO: identidad 1.5.0.1 e inventario estatico | Mantener coherencia en cada tanda |
| REL-03 a REL-07 | Pendientes | SESSION_PLAN.md |
| LOC-MERGE | No realizado; traducciones no modificadas | Integracion posterior autorizada |

No se reemplazaron/recompilaron ejecutables del paquete ni se ejecutaron PMM,
Windows/WPF, antivirus o CI remoto. Los 20 tests locales son de herramientas,
no del programa. No hay release, tag ni PR. La identidad nueva no significa
hardening terminado ni aprobacion de Nexus.

Los candidatos Host/Runtime descritos en la charla anterior no persistieron
con codigo e informes; sus comparaciones quedan NO REPRODUCIDAS. No se aceptan
como evidencia de equivalencia. Development/Source/SOURCE_STATUS.md sigue vigente.

SESSION01B_FINDINGS.md, SESSION01B_CHECKS.json y NATIVE_ARTIFACTS.json documentan
los resultados. BASELINE.json y SESSION01_FINDINGS.md son registros historicos;
no se reescriben para aparentar que estos resultados ya existian entonces.
