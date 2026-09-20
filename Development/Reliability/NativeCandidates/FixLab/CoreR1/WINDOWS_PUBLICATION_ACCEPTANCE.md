# Aceptacion Windows de publicacion - 04A-6C/6D, parcial entre entornos

Ejecucion real: Windows 10 build 19045, amd64, NTFS, token NO elevado.
Go 1.23.2. Fixtures artificiales en TEMP; no PMM, juego ni mod real ejecutado.
Ver ../../../SESSION04A6D_CHECKS.json y evidence/s04a6d/. La evidencia 6C se
conserva como historial del protocolo anterior de rename de directorio.

El ejecutable CoreR1-tests.exe es un harness autocontenido, NO PMMFixLab.exe.
RUN_WINDOWS_PUBLICATION_TESTS.cmd selecciona publicacion, integracion y captura
Windows. Limpia opt-ins en el proceso hijo. El test de junction usa cmd.exe
mklink /J exclusivamente sobre carpetas temporales. El test de acceso cambia y
restaura SOLO la DACL de su fixture temporal; no modifica privilegios/politicas.

| Caso | Criterio | Resultado 6D |
| --- | --- | --- |
| W6B-01 | DACL protegida usuario/SYSTEM y ABI | PASS; descriptor y DACL real de carpeta/cuatro hojas |
| W6B-02 | Crear/flush/releer/commit/reabrir bundle | PASS; Windows hace commit atomico de COMPLETE y tres vectores se contrastan tambien con Python |
| W6B-03 | Rutas protegidas, hardlinks, reparse, remoto | PARTIAL: roots, hardlink y junction PASS; UNC/device rechazo sintactico; SMB real no probado |
| W6B-04 | Destino vacio/ocupado no reemplazado | PASS; identidad del destino vacio preservada |
| W6B-05 | Cancelacion antes de commit y rollback propio | PASS, incluido sealed-before-commit |
| W6B-06 | Error posterior conserva recibo committed | PASS, errores inyectados y cierre real; no fallo fisico de flush |
| W6B-07 | Cierre abrupto distingue incompleto/completo | PASS: antes de sellar, sellado y despues de marcador; no corte electrico |
| W6B-08 | Disco lleno/permisos/antivirus | PARTIAL: acceso denegado y sharing violation reales PASS; ENOSPC inyectado; disco lleno real/AV no probados |
| W6B-09 | Espacios/Unicode/concurrencia | PASS; Unicode, 2.000 publicaciones secuenciales y 500 repeticiones de cuatro concurrentes |
| W6B-10 | Win10/Win11/NTFS sin inferir paridad | PARTIAL: Win10 NTFS ejecutado; Win11 no disponible |

152 tests Go top-level PASS + 4 targets Fuzz con seeds PASS, seis opt-ins activos;
3 eventos SKIP (helpers/opt-in historico). No es una sesion de fuzz aleatorio.
54 Python PASS, 2 SKIP por privilegio symlink; junction/hardlink Go SI ejecutados.
Race no ejecutado en esta tanda: sin compilador C disponible. Linux compilado/vet,
NO ejecutado aqui; la evidencia Linux 6B es historica, no una nueva ejecucion.

Dos builds 6D byte-identicos: harness
`7d09da6c001d926d077fd32863f2fd31c6708fd98330106d35a4f0caeebd2d8c`
(6860288 bytes) y CLI candidato-only
`0464e503a96f467e96501d0e71367027501640b7433bb1bd76cb1e159cd781bc`
(4353536 bytes). El harness completo paso con `-test.count=3`; el CLI publico
un fixture, rechazo pin falso y no instala/despliega.

## Repetir sin Go

Usar el kit separado fuera de PMM/ y del juego, sin elevar privilegios:
CoreR1-tests.exe + RUN_WINDOWS_PUBLICATION_TESTS.cmd. El .cmd guarda el log al lado.
No desbloquear ni excluir archivos del antivirus para forzar un PASS. Registrar
cualquier bloqueo real. Conservar hash del harness y log junto al entorno.

DirectorySyncCompleted=false y CrashDurabilityGuaranteed=false en Windows.
No declarar la matriz completa PASS por compilar o por probar una sola maquina.
La aceptacion funcional de I01 y de Unreal/Palworld sigue siendo independiente.
