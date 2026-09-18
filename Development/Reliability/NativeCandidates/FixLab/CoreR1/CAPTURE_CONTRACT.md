# CoreR1: snapshots de entrada y expediente schema - 04A-5B

## Alcance cerrado

CaptureCore(ctx, CaptureRequest) es una capa separada de PlanCore. Recalcula el
plan con documentos pinneados, valida todos los descriptores/capacidades antes
abrir archivos y adquiere copias en memoria de TODOS los archivos declarados en
los dos inventarios, no solo los seleccionados. No lista archivos adicionales.
Los documentos de entrada deben permanecer inmutables durante la llamada.

El resultado CapturedInputs conserva buffers privados. Bytes(role,path),
ReportJSON() y PlanJSON() devuelven copias. No hay API de escritura, extraccion,
reparacion, PAK build, instalacion o envio de datos. El llamador no debe volver
abrir las rutas para transformar: los snapshots solo identifican los bytes
capturados. Un cambio posterior del disco no modifica esas copias.

## Archivos y proveedores

CaptureRoots contiene Donor, Current, Archives y Schemas. Son directorios existentes,
absolutos y canonicos elegidos por el llamador. No aceptar rutas relativas,
normalizacion silenciosa, UNC o namespaces de dispositivos Windows. Los paths de
inventario usan las reglas ASCII/Windows-safe del planner; la raiz puede contener
Unicode. Maximo 64 componentes en la raiz; paths internos hasta 32.

DonorArchive es File{Path,SHA256,SizeBytes}, relativo a Archives. Su SHA debe ser
la alternativa aceptada por PlanCore. CurrentProviderSet aporta JSON pinneado:
PMM_R1_PROVIDER_SET_V1 con build y providers [{path,sha256,sizeBytes}]. El hash de
ESOS BYTES JSON debe ser CurrentInventory.ProviderSHA256. No se sustituye por un
hash de concatenacion sin contrato. Cada proveedor debe tener extension .pak.
Se verifican bytes/tamanos de esos archivos por streaming, sin retenerlos.

Esto NO demuestra que un archivo sea un PAK valido ni que los assets capturados
procedan de sus entradas. Tampoco autentica el nombre del build. En las pruebas,
los archivos .pak contienen texto sintetico: prueba deliberada de esa frontera.
La prueba de pertenencia/extraccion corresponde a 04A-5C. No emitir readiness
basandose en que un PAK declarado y una carpeta por separado tienen hashes.

## Apertura y limites de la garantia

Linux: componentes abiertos con openat sobre directorios retenidos y O_NOFOLLOW;
O_NONBLOCK permite rechazar FIFO/dispositivos sin consumirlos. Perfil de FS local:
ext2/3/4, XFS, Btrfs, tmpfs, ramfs y overlayfs. Otros tipos quedan UNSUPPORTED.
Windows: apertura relativa a HANDLE de directorio mediante NtCreateFile con
FILE_OPEN/FILE_OPEN_REPARSE_POINT. Se rechazan reparse points por handle, archivos
no regulares y links multiples. Leaves permiten solo FILE_SHARE_READ; no se
piden privilegios, escritura, borrado ni acceso a procesos. La consulta del volumen
por handle rechaza FILE_REMOTE_DEVICE y respuestas desconocidas/incompletas.
Son APIs documentadas de apertura/consulta de archivos, no direct syscalls ni
tecnicas para evitar instrumentacion. El adaptador Windows solo esta COMPILADO.

Se exige un unico enlace en cada archivo, mismo volumen que la raiz retenida,
tamano inicial correcto, lectura exacta hasta EOF y SHA-256 esperado. Tras leer
se comparan identidad/metadata del handle y una segunda resolucion desde la MISMA
raiz retenida. Los errores de lectura, reapertura o cierre invalidan el resultado.
No existe fallback a Lstat-then-Open que pueda seguir enlaces por una carrera.

Renombrar la raiz despues de abrirla no redirige su handle: la captura puede usar
el directorio original. No se afirma que su antigua ruta siga apuntandole. No hay
snapshot atomico de todo el sistema de archivos ni deteccion de todos los cambios
concurrentes posibles; hay snapshots por archivo con pins externos. Hash correcto
no autentica quien eligio el pin. Se confia en el SO/driver y en un caller honesto.
Linux no bloquea escritores: integridad se exige sobre los bytes efectivamente
leidos. Windows sharing/ABI/carreras reales siguen pendientes de aceptacion.
Cancelacion es cooperativa entre lecturas; no interrumpe I/O bloqueada en kernel.

## Dossiers de schemas

Cada SchemaClaim del plan debe tener exactamente un DossierFiles, ligado por
ClaimSHA256, con Layout y Review como File pinneados dentro de Schemas. Se leen
sus bytes reales y se comprueban tamanos/hashes. JSON estricto rechaza claves
duplicadas, desconocidas, mal capitalizadas, nulos o valores ambiguos.

Layout: PMM_FIXED_UNVERSIONED_SCHEMA_V1, perfil/clase ligados al claim, 1..1024
campos con nombres unicos y tipos escalares del contrato UAsset 04A-4C. Debe
incluir PostProcessAnimBlueprint ClassProperty. Colecciones/structs/custom
serializers no se convierten a campos simples ni se aceptan por omision.

Review: PMM_R1_SCHEMA_REVIEW_V1 liga recipeSHA256, donorHeaderSHA256,
donorExportSHA256, currentProviderSHA256, layoutSHA256, profile, classPath,
origin y revision al claim. Requiere reviewer, method y findings (1..64 textos).
No admite approved/verified. El autor y sus afirmaciones NO se autentican.
No se deduce el layout desde offset 120, ni se crean hashes de salida deseados.

Resultado: BYTES_AND_BINDINGS_CHECKED_NOT_AUTHENTICATED. BytesVerified y
BindingsChecked son true, pero LayoutSemanticsVerified y ReviewerAuthenticated
son false. Se comprueba sintaxis/vinculacion, no que el schema describa una malla.
El schema real no escalar, su procedencia y los outputs revisados siguen faltando.

## Informe y techos

PMM_R1_CAPTURE_REPORT_V1 enumera role/path/hash/size/retencion, hashes de plan y
provider-set y dossier results. No incluye rutas absolutas ni contenido de assets.
ListedAssetBytesVerified y ListedArchiveBytesVerified describen SOLO la lectura.
CompleteFilesystemInventory, AtomicFilesystemSnapshot, ExtractionMembershipVerified,
BuildAuthenticated, TransformReady, BuildReady, Validated e Installed siguen false.
El Plan JSON previo queda sin promocion: sus flags no se reescriben como permisos.

Techos reducibles: 256 MiB por asset, 512 MiB de snapshots (assets+documentos),
64 GiB por archive, 128 GiB agregados, 64 proveedores actuales, JSON de provider-set
/layout/review hasta 128 KiB cada uno. Los 64 claims del planner siguen vigentes.
No son techos de RSS ni plazos absolutos de disco. No se cambian pins ante errores.

## Referencias primarias

Consultadas 2026-09-18; implementacion Go1.23.2 local sin modulos externos.
https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntcreatefile
https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getfileinformationbyhandle
https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/nf-ntifs-ntqueryvolumeinformationfile
https://go.dev/src/syscall/syscall_linux.go
Los contratos de documentos anteriores y las primitivas UAsset permanecen como
referencia; no se importaron ni alteraron para evitar sus restricciones.
