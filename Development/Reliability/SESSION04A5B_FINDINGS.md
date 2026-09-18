# 04A-5B - verificacion de entradas y expediente schema

Fecha 2026-09-18. Rama exclusiva v1.5.0.1-PMM-reliability.
Entrada a97966e351a307902d6d66ecd012a017ad6febb1,
arbol 80d8a5fdc29798855dc44ee7153e6cd170493997.
CERRADA en captura de bytes y comprobacion de dossiers; NO executor core R1.
Los gates Windows, pertenencia a archives y semantica real siguen abiertos.

## Entrada

Se consultaron HEAD, AGENTS, NEXT_SESSION y el listado CoreR1 por GitHub.
Fuentes CoreR1 de ZIP 04A5A verificado por SHA-256 y recibo Git; PMM/.github/
snapshot del ZIP 03B comparados por arbol Git con la base remota. No se afirma
que ese checkout parcial sea HEAD completo de Host/Runtime/UIBridge. El commit
se aplica como delta sobre HEAD remoto, no copia de carpetas antiguas.
No se repite recuperacion del overlay invalido ni de las primitivas previas.

## Implementacion

CaptureCore recalcula PlanCore sin cambiar su logica. Valida metadata/capacidades
antes de I/O, abre directorios por handles y captura TODOS los archivos declarados
en los inventarios. Verifica longitud exacta/EOF, SHA-256 esperado, objeto y
metadata antes/despues, segunda resolucion desde raiz retenida y errores de cierre.
Devuelve buffers privados, accesores por copia y report JSON sin bytes de assets
ni rutas absolutas. No escribe en roots ni transforma/repara/instala nada.

Los archives se comprueban por streaming. PMM_R1_PROVIDER_SET_V1 fija los bytes
JSON del conjunto actual y su lista de proveedores; ese hash es el providerSHA256
del inventario current. Se comprueba el donante permitido real por bytes, pero
NO la relacion entre sus entradas y los assets de la carpeta. Tampoco se autentica
el build, la fuente de los pins o la completitud del inventario de disco.

Linux usa openat/O_NOFOLLOW y handles anclados; rechaza enlaces, archivos con
multiples links, dispositivos, FIFOs y FS fuera del perfil local. Windows usa
NtCreateFile relativo a directorio con FILE_OPEN_REPARSE_POINT, informacion de
archivo por handle y consulta de volumen; rechaza reparse/remote y comparte hojas
solo para lectura. No se usan privilegios, direct syscalls ni acceso a procesos.
El adaptador Windows esta COMPILADO, no validado por ejecucion. Otros SO fallan
cerrado. Diez casos Windows quedan NOT_RUN, incluyendo dos tests compilados.

No se promete snapshot atomico de todos los archivos ni que las rutas sigan
apuntando al mismo objeto despues. Renombrar una raiz no redirige su handle.
Los pins protegen los bytes capturados, no autentican su origen. Cancelacion
cooperativa no interrumpe I/O bloqueada por kernel. Ver CAPTURE_CONTRACT.md.

## Expediente

Cada claim exige documentos layout/review reales con size y hashes vinculados.
Se verifica JSON estricto, perfil/clase, nombres/tipos escalares y bindings del
review con receta/donante/provider/layout/origen/revision. Se conserva el formato
PMM_FIXED_UNVERSIONED_SCHEMA_V1; no se importan ni debilitan primitivas UAsset.
Un review correcto por bytes queda BYTES_AND_BINDINGS_CHECKED_NOT_AUTHENTICATED.
No autentica al revisor ni valida que el layout describa una malla real. Arrays,
structs y serializers no demostrados quedan UNSUPPORTED; no se deducen desde 120.

PLAN_VALID sigue siendo declarativo. El nuevo report solo afirma listedAssetBytes
/listedArchiveBytesVerified. TransformReady/BuildReady/Validated/Installed,
ExtractionMembershipVerified, AtomicFilesystemSnapshot, CompleteFilesystemInventory
BuildAuthenticated y la verificacion semantica del schema permanecen false.
Los hashes de salida de transformaciones no se inventan ni se generan para aprobar.

## Evidencia ejecutada

55 funciones Test Go Linux PASS (30 previas +25 nuevas); opt-ins activados, cero
SKIP en esa ejecucion. 20 tests Python PASS. Race Linux con opt-ins PASS.
FuzzDossierDocuments: 106633 entradas en corrida acotada de 8 segundos solicitados;
solo JSON/bindings del dossier, no prueba del filesystem ni antivirus.

Se probaron archivos sinteticos realmente escritos/leidos: longitudes/hashes,
EOF, limites, cancelacion, doble cierre, handles cerrados, schemas cruzados,
claves ambiguas, paths, symlinks, hardlinks y FIFO. Una goroutine cambia archivo
/padre durante la captura bajo sincronizacion reproducible; se comprueban rechazo
y ausencia de salida parcial. El caso raiz renombrada confirma no redireccion.
No se presume probar todas las carreras posibles con estas intercalaciones.

Dos escenarios completos (sin/con dossier) se verificaron en Python independiente:
19 assets artificiales por escenario, 2 archivos .pak DE TEXTO SINTETICO cada uno,
y 2 documentos extra en el caso con schema. Se comparan cobertura/hashes/bytes/
bindings y ausencia de readiness. Deliberadamente no son PAK validos: esta capa
comprueba bytes, no formato/membership. Los cuatro planes previos conservan su oracle.

Dos builds FINALES TEST Go1.23.2 Windows/amd64 son identicos. Hash/tamano en CHECKS.
Vet Windows PASS. Los builds intermedios no se usan como finales. Los dos tests
Windows exclusivos solo se compilaron; no se incluyeron entre los 55 PASS Linux.
No motor FixLab construido, ni originales/Windows/PS/.NET/juego/reparaciones/AV
 ejecutados. Los assets reales del usuario nunca se adquirieron en estas pruebas.

## Conservacion y continuidad

629 archivos PMM /628 checksums correctos/cero discrepancias; version 1.5.0.1/s01b.
PMM tree 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa. .github/snapshot identicos.
PlanCore/json.go/validate.go/go.mod permanecen byte-identicos; types.go solo cambia
el comentario del paquete para distinguir las dos APIs. Contratos/codecs UAsset,
PMMDLT1/PAKV11 y otras candidatas/recetas/traducciones intactos.
Un commit [skip ci] sin workflows/PR/tag/release ni reemplazo de ejecutables.

Siguiente 04A-5C: prueba de pertenencia archive->archivos en perfil declarado y
procedencia verificable. No convertir hashes coincidentes separados en extraccion
probada. Schemas reales/serializers, relocalizacion y executor siguen separados.
