# Core R1 - pertenencia de entradas a PAK, 04A-5C

## API y alcance

VerifyMembership(ctx, captured, request) recibe UN CapturedInputs devuelto por
CaptureCore. No existe importador de un supuesto snapshot desde JSON. Devuelve
MembershipEvidence con ReportJSON por copia, o nil,error. No transforma, extrae,
instala, ejecuta comandos ni envia archivos. El informe es evidencia, no permiso.
El planner y CaptureCore conservan exactamente su comportamiento anterior.

MembershipRequest contiene ArchivesRoot, DonorArchive, CurrentProviderSet,
Profile, CurrentOwnership y Limits. Los documentos deben ser inmutables durante
la llamada. Se comprueba la vinculacion con el plan/informe guardados y todos
los buffers donor/current retenidos, no solo los seleccionados por la receta.
Los documentos schema mantienen la evidencia de 5B, sin promocion semantica.

El perfil debe ser PAKV11_ASCII_COMPACT32_PHI_FDI_UNCOMPRESSED_V1. Se reutiliza
PAKV11.Read SIN modificarlo: v11, mount virtual ../../../, ASCII, registros
compactos de 32 bits, PHI/FDI completos, datos contiguos sin compresion/cifrado.
No es soporte general de PAK v11, PAK enormes, Oodle, otros mounts ni IoStore.
Un PAK fuera del perfil produce error, no una prueba parcial o un fallback.
El seed admitido es el que el lector PAKV11 ya acepta; no se ignoran sus indices.

## Archivos que realmente se leen

La captura 5B no conservaba los archives, solo sus hashes de lectura. Esta API
los vuelve a abrir por el adaptador anclado de 5B y COMPRUEBA otra vez tamano,
EOF, SHA-256 esperado e identidad antes/despues. Un pin nuevo en la solicitud no
puede sustituir al descriptor del snapshot. No se reutiliza ciegamente una ruta
que fuera correcta durante 5B. Los roots de assets no se reabren: se comparan los
buffers privados capturados, no archivos que podrian haber cambiado despues.

Cada archive se materializa y parsea completamente antes de consultar entradas.
No basta buscar una cadena, validar la extension o verificar el hash del PAK.
Todas las entradas de ese archive pasan las comprobaciones estructurales de
PAKV11; las entradas declaradas se comparan byte a byte con su snapshot. Se
registran rol, ruta exacta/case, size/hash, archive propietario y ordinal.
No se concatenan mount/rutas internas a rutas de extraccion en disco.

## Proveedores actuales y ambiguedad

CurrentProviderSet debe ser exactamente el JSON pinneado por CaptureCore, con
la misma lista y orden. El ordinal se registra solo como identidad del listado:
NO significa prioridad ni orden de montaje del motor. CurrentOwnership debe ser
UNIQUE_OWNER_ONLY_V1. No existe first-wins, last-wins o preferencia por hash.

Para CADA ruta declarada actual se inspeccionan TODOS los proveedores listados.
Debe haber una unica entrada con esa ruta y sus bytes exactos. Dos propietarios
son ambiguos incluso con bytes identicos; una variante de mayusculas tambien
bloquea. Una entrada ausente o diferente es error. Un proveedor sin entradas
seleccionadas sigue teniendo que ser un PAK valido del perfil.
El donante se comprueba por separado contra el archive permitido del plan.

Se permiten otras entradas no declaradas, pero no se afirma que sus propietarios
sean unicos ni que el inventario de carpetas sea completo. Tampoco se demuestra
que la lista de proveedores incluya todos los PAK montados por Palworld. Otros
proveedores, precedencias reales o casos comprimidos necesitan otro contrato
implementado y validado, no relajar este para obtener un resultado positivo.

## Que significa el resultado

PMM_R1_MEMBERSHIP_REPORT_V1 usa LISTED_ENTRIES_VERIFIED_NOT_TRANSFORM_READY.
ListedEntriesMembershipVerified: todos los donor/current DECLARADOS coinciden
con entradas del conjunto exacto de PAK comprobados bajo el perfil indicado.
AllListedProvidersParsed y UniqueCurrentOwners se limitan a ese mismo alcance.
CaptureReportSHA256, PlanSHA256 y ProviderSetSHA256 unen los tres expedientes.

Esto prueba una relacion de bytes, NO la historia del proceso de extraccion,
autenticidad del autor, correspondencia de build declarada con el juego real,
completitud del universo de proveedores ni semantica del schema. Esos flags y
TransformReady/BuildReady/Validated/Installed siguen false. Ni el Plan JSON ni el
CaptureReport JSON se reescriben para decir que una fase anterior hizo mas.
Un caller sigue teniendo que proporcionar pins externos confiables. No se
inventan outputs esperados ni se elimina el rechazo de relocalizacion opaca.

## Limites y sistema operativo

256 MiB por archive, 1 GiB total leido por comprobacion, 64 proveedores actuales
mas un donante. Solo pueden reducirse. PAKV11 conserva 64 MiB/entrada, 16384
entradas/archive, 32 MiB de indices y sus limites de rutas. Se procesa un archive
por vez, sin retenerlo en el informe; la captura de assets ya tiene sus limites.
No son un techo de RSS: PAKV11 copia contenidos, el GC y llamadas concurrentes
pueden aumentar la memoria residente. La cancelacion es cooperativa y se comprueba
al leer/hash/comparar y despues de cerrar; no interrumpe una llamada de kernel
bloqueada. Los errores de cierre tambien invalidan el resultado.

Se conserva el contrato de apertura 5B (Linux/Windows). Las pruebas ejecutadas
son Linux con datos artificiales; Windows se compila pero no esta aceptado aun.
No hay garantia de instantanea atomica entre archives, ni de que las rutas no
cambien despues. La evidencia se refiere a los bytes leidos y capturados.

## Dependencia local y comprobacion independiente

CoreR1/go.mod usa require/replace LOCAL a ../PAKV11. build.py conserva ambos
modulos, hashes y layout en source/CoreR1 y source/PAKV11, sin red ni cambio de
la biblioteca PAK. El EXE resultante es un harness de TEST, no PMMFixLab.exe.
verify_membership.py usa el lector Python PAKV11 de 04A-3 y compara los bytes de
los PAK sinteticos, snapshots y filas de informe. No invoca Go o repak. Sigue
siendo contraste entre implementaciones propias, no aceptacion por Unreal.

Referencia primaria de la integracion de modulos:
https://go.dev/ref/mod#go-mod-file-replace (consulta 2026-09-18).
El contrato de formato esta en ../PAKV11/FORMAT.md y sus referencias fijadas;
no se ha deducido ni cambiado ningun layout PAK en esta tanda.
