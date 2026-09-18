# 04A-4 - UAsset: lectura y estructura

Fecha 2026-09-18. Rama exclusiva v1.5.0.1-PMM-reliability.
Entrada a66cea06e673a169623b3c12821739b0fa6d0b9f.
Arbol base 1c703ca1a05ca306bce6882035a7e6c1b9137e49.

**CERRADA en lectura/estructura como componente aislado.** No hay motor FixLab
completo ni source original recuperado. 04A completa/REL-01 siguen ABIERTAS.

## Entrada y evidencia de formato

Se leyeron HEAD/AGENTS/NEXT_SESSION actuales. El ZIP 03B solo aporta PMM/.github/
Development/Source, cuyos tres subarboles Git se recalcularon y coinciden con los
IDs conservados en la rama actual. Documentos recientes FixLab provienen de sus
ZIP 04A/04A2/04A3, verificados por SHA-256. No se afirma que el viejo checkout sea
HEAD de todas las candidatas. La publicacion usa el arbol remoto como base y solo
modifica UAsset y documentos de continuacion. No se repite el overlay roto.

Perfil explicito cooked-ue4-522-ue5-1008: version 522/1008, legacy -8, cooked y
editor-filtered. Cabecera con contenedor custom vacio, soft-object slots y final
PayloadToc; imports 32 bytes/exports 96 bytes. Se contrastaron ReadHeader/Import/
Export y los umbrales ObjectVersion de UAssetAPI fijado a commit 3228c1e, ademas de
las descripciones oficiales Epic. No se compilo/importo la biblioteca externa.

Se inspeccionaron estaticamente readHeader/readNames/readImports/readExports,
fstring y parseUAssetBytes del original FixLab fijado a 8807635a...316bc0afe.
Los rangos y hashes estan en static-origin.json; disassembly completo en el ZIP.
Esto respalda el subconjunto, no demuestra que todo asset donante/current encaje.
Ningun asset del juego se uso para construir fixtures ni se leyo en esta tanda.

## Codigo entregado

NativeCandidates/FixLab/UAsset/ contiene modulo Go sin dependencias: API Read,
lector de primitives/FString, summary con version explicita, tablas, referencias,
spans y hashes. No hay main.go ficticio, escritor, reparacion, CLI de FixLab,
subprocessos, carga de objetos, red ni guardado de archivos en la biblioteca.

La version del archivo nunca se adivina: 0/0 solo con AllowUnversioned explicito
bajo el perfil seleccionado. Esa opcion es afirmacion del caller, no una prueba
extraida de dos ceros. Cualquier otra version se rechaza. Custom versions y
secciones no soportadas se rechazan; AssetRegistry/gaps/tail permanecen opacos,
identificados como tales. No se descarta contenido desconocido para facilitar
una futura reescritura. Las propiedades y bulkdata NO se interpretan.

Nombres ASCII o UTF16-LE estricto, FName por indice/numero, hashes guardados
conservados, imports/exports con offsets exactos. Se validan limites antes de
recorrer/crear colecciones, truncaciones, booleanos, offsets/tablas superpuestas,
indices con signo, slices de preload y ciclos en la cadena Outer. No se rechazan
por defecto grafos ciclicos de clases/dependencias, distintos de Outer.

Con solo .uasset se validan rangos logicos de exports, no existencia de .uexp.
Si se suministra .uexp, exportRangesChecked confirma rangos dentro de esos bytes;
no declara propiedades validas ni autenticidad. El hash de un input se calcula,
no se usa como pin autoaceptado. La API requiere inputs inmutables y devuelve
metadata sin alias y nil ante cualquier error, incluida cancelacion final.

## Comprobaciones

23 funciones Test Go con aserciones, incluido export opt-in; seis subcasos de
vectores base, truncaciones y otros casos internos no se inflan como tests nuevos.
Suite race Linux tambien completa. 12 tests Python del lector independiente,
reproduccion de vectores y protecciones del builder.

Seis fixtures artificiales: versionado, unversioned explicito, Unicode/astral,
mapas vacios, registro opaco y multiples exports. Generador y lector Python no
importan el codigo Go. Coinciden nombres/hashes, imports, exports, dependencias,
posiciones y campos summary comparados con las salidas Go. No son assets creados
por Unreal ni muestras del juego: ambas implementaciones pueden compartir una
interpretacion erronea. No se declara compatibilidad engine ni paridad original.

FuzzRead: 1464 entradas; FuzzTables: 21117 entradas en ejecuciones acotadas. Son
pruebas de parser, no Windows ni antivirus. No hubo errores detectados en ellas.
Go vet y compilacion Windows/amd64 correctos. Dos builds FINALES del harness TEST
coinciden: 5596672 bytes, SHA-256
12a8a4e96d739061389cb61d934f78b2da749d0cd6ed963c03c88c8c69a98feb.
Una llamada agrupada inicial agoto su plazo durante un build intermedio; no se
conto como build terminado. Los dos builds finales con COMPLETE.txt son los
registrados. Harness NO ejecutado en Windows; no es PMMFixLab.exe.

## Conservacion y siguiente

PMM: 629 archivos, 628 hashes correctos, cero discrepancias; build s01b/version
1.5.0.1 intactos. Arbol 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa.
PMMDLT1/PAKV11, Host/Runtime/UIBridge/Supervision, snapshot, recetas, traducciones
y workflows no se modifican. Sin PMM/FixLab/PowerShell/.NET/repak/Unreal/juego/AV
ni reparaciones ejecutadas. Un commit [skip ci], sin PR/tag/release.

04A-4B: serializacion/relocalizacion y transformaciones acotadas del core R1,
con spans opacos preservados o rechazo, nombres/offsets actualizados y fixtures.
Luego orquestacion V2/CLI antes de 04B. La API de lectura no autoriza reescritura
segura por si sola. Todos los gates Windows y bloqueos previos siguen pendientes.
