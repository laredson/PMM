# 04A-2 - componente PMMDLT1 reconstruido

Fecha 2026-09-18. Rama exclusiva v1.5.0.1-PMM-reliability.
Entrada remota 1b15621cf988bd7e582af19e46ea7ad81796fad8,
arbol cab305c53cc6acbb039841f4c6452c104602e55b.

**04A-2 CERRADA EN SU ALCANCE: lector/aplicador de parches en memoria.**
04A completa y REL-01 siguen ABIERTAS. No hay motor FixLab completo compilable,
fuente original recuperada, integracion en PMM ni aceptacion Windows/Palworld.

## Entrada y alcance

HEAD no incorporaba una fuente nueva de FixLab. No se repitio la busqueda del
overlay invalido. Se usan bytes de PMM/.github/snapshot del ZIP 03B, cuyos tres
subarboles Git se recalcularon y coinciden con la base remota. Los documentos y
herramientas FixLab de 04A vienen de su ZIP verificado; el resto de candidatas
remotas se preserva por el arbol base, no copiando carpetas antiguas sobre ellas.
No se afirma que la copia local completa sea una copia de HEAD.

## Evidencia del formato

Documentacion FIX_LAB_RECIPE_ENGINE.md, metadatos Go del original fijado y
lectura estatica de main.applyDeltaPatch (VA 0x527020..0x528940) respaldan el
layout de FORMAT.md: magic de 8 bytes, zlib, longitud uint64 LE, contador uint32
LE, COPY con indice uint16 y offset/longitud uint64, LITERAL con longitud uint64.
No se ejecuto el motor para descubrirlo. El rango de codigo original conserva
hash c08a7cc1075a0c778bbae01aa766e41563e399a71e519eae936d88b1b22db917.

Un parser Python independiente y el nuevo Go consumen exactamente los 137
payloads distribuidos y coinciden en TODOS sus metadatos de instrucciones/rangos.
Agregado SHA-256: 35cf1b8d2ca57b3063c577d2372ed3d2b0d93db820297f5e15728fadc191b4fe.
5 recetas verificadas por hash contienen 260 referencias a esos payloads.
Hay 4425 operaciones: 2547 COPY y 1878 LITERAL. Maximo observado de salida
DECLARADA: 4509003 bytes. Los assets donantes/core no estan disponibles en este
trabajo: no se verifican sus bytes ni los outputs de transformaciones reales.

## Implementacion aislada

NativeCandidates/FixLab/PMMDLT1 es un modulo Go sin dependencias externas.
Inspect comprueba hash de parche y sintaxis completa. Apply verifica tambien
TODAS las referencias y el resultado final; devuelve nil en cualquier fallo.
El archivo de patch no es codigo ejecutable: solo COPY/LITERAL sobre slices.
No escribe archivos, no aplica recetas ni ejecuta subprocessos o descargas.

Controles: magic, checksum/trailer zlib hasta EOF, rechazo de streams/sufijos
extra, cantidades e indices, desbordamiento por resta, tamaño total y hashes
obligatorios. Cancelacion cooperativa al leer/hash/copiar por bloques y al
interpretar cada instruccion. No se acepta un prefijo valido como salida completa.

Los limites por llamada son deliberadamente conservadores: 16 MiB de patch,
64 MiB inflados, 256 MiB output, un millon de operaciones, 1024 referencias,
256 MiB por referencia y 512 MiB agregados. Un caller puede reducirlos, no
saltarselos. No se anuncian como los limites del original ni como un techo del
RSS del proceso. Las futuras capas deben proteger la adquisicion inmutable de
inputs y el guardado transaccional; esta API no reemplaza esos requisitos.

El source es RECONSTRUCTION. No se llama delta.go original a nuestro codigo.
No hay main.go de relleno que anuncie un motor completo sin implementarlo.
No se han alterado CKL, recetas, hashes esperados ni ejecutables para pasar pruebas.

## Pruebas y compilacion

22 funciones Test Go con aserciones: 21 sinteticas y una lectura opt-in de corpus.
La suite incluye cien programas sinteticos aleatorios deterministas, todas las
truncaciones de un fixture, referencias multifuente/binary/uint16, longitudes cero,
hashes incorrectos, zlib corrupto/sufijos, salida incompleta, limites y cancelacion
por distintos puntos. El corpus opt-in coincide con el lector Python independiente.
Sin PMM_FIXLAB_PACKAGE esa prueba es SKIP; no sumar un skip como PASS.

10 tests Python prueban el segundo parser y la proteccion de salida del builder.
Race Linux: PASS en la suite del codec. Dos fuzz acotados: 52004 entradas de
instrucciones y 182201 de envoltura; no son pruebas de SO ni escaneos antivirus.
Compilacion y vet Windows/amd64 correctos, pero Windows NO ejecutado.

Dos compilaciones offline Go1.23.2 del harness TEST Windows son byte-identicas:
3883008 bytes, SHA-256 7ac6f7647b4ade31e8c623cdcaea157e54b6b3422631fd61d2097ad5476459e7.
Ese EXE ejecuta pruebas del codec; NO es PMMFixLab.exe ni actualizacion instalable.
La receta fija toolchain local y bloquea descarga de modulos. No hubo build del
motor completo, reparacion de mod, ejecucion de PMM/FixLab/PS/.NET/repak/Palworld o AV.

## Conservacion y continuidad

PMM: 629 archivos, 628 checksums, cero discrepancias, version 1.5.0.1 / s01b.
Arbol 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa; .github y Development/Source
siguen identicos. Las escrituras remotas se limitan al codec y documentos de
esta tanda. No se modifica Host/Runtime/UIBridge/Supervision ni traducciones.
Los registros 04A originales permanecen historicos; el overlay sigue bloqueado.

Se conserva fuente, formato, herramientas, evidencia compacta y siguiente paso
04A-3 PAK v11/readback. El ZIP de evidencia contiene informes completos, disassembly
estatico y harness de pruebas, no datos fuente del juego. No se pasa a 04B aun.
Sin Actions/PR/tag/release. La publicacion es un commit [skip ci] separado.
