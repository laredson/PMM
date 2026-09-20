# 04A-6B - publicacion transaccional de resultados candidatos

## Alcance preciso

PublishCandidate(ctx, *MemoryResult, PublicationRequest) guarda el resultado privado
que devuelve ExecuteBounded. No acepta JSON externo como un resultado ejecutado,
no recompila PMM, no instala mods y no escribe en los archivos de entrada.
InspectCandidate(ctx, directorio, SHA256-manifiesto) es SOLO lectura/verificacion;
no devuelve MemoryResult ni convierte datos del disco en autorizacion de ejecucion.

La carpeta publicada contiene exactamente cuatro archivos creados por esta API:
- candidate.pak: los bytes producidos por el ejecutor acotado, sin extraerlos.
- execution.json: informe original conservado sin promover sus flags.
- MANIFEST.json: identidad del bundle, hashes/tamanos, receta y plan.
- COMPLETE.json: vinculo al hash del manifiesto y al nombre final.

Los archivos individuales de assets quedan dentro del PAK, no se escriben a rutas
extraidas de un documento. El candidato es un RESULTADO de FixLab, no un EXE nuevo
de PMM. Un bundle completo no significa reparacion aceptada en Unreal/Palworld.

## Entrada y aislamiento

PublicationRequest exige Parent, RepositoryRoot, GameRoot y WorkspaceRoot:
directorios locales existentes, absolutos y canonicos. El integrador debe aportar
las ubicaciones REALES y controlar el namespace padre durante la operacion.
Se abren por handles con el capturador existente y se comparan identidades de los
ancestros del padre contra cada raiz protegida. Se rechaza un destino dentro
del repositorio/PMM, juego o Workspace declarados; no se adivinan otras instalaciones.
Ni una cadena falsa aportada por el caller ni un hash autentican una politica.

Se crea SOLO un nuevo hijo aleatorio de 128 bits en el padre autorizado. No hay
nombre elegido por el documento, sobreescritura, reintento tras colision o copia
sobre una candidata anterior. Linux: mkdirat 0700, ficheros 0600 y O_EXCL/NOFOLLOW.
Windows: NtCreateFile relativo con FILE_CREATE/OPEN_REPARSE_POINT y DACL protegida
heredable para usuario del proceso/SYSTEM; API de archivo documentada, sin elevar
privilegios, tocar procesos, cambiar antivirus o usar syscalls directas Windows.
Las hojas Windows permiten lectura/borrado compartidos, no escritura compartida.
La identidad se comprueba de nuevo antes de commit. Windows exige cerrar las
hojas para renombrar el directorio: se sellan inmediatamente antes del rename,
reteniendo identidades de volumen/archivo y los handles de los directorios.
Ante fallo se reabren SOLO para rollback y se comparan identidades; una hoja
ajena, enlazada o inaccesible no se borra y se informa posible residuo.

Los checks no son un sandbox frente a otro proceso hostil con el MISMO usuario,
root/administrador, cambios de mounts o un namespace padre fuera de control.
Los handles no congelan la ascendencia si terceros mueven directorios. Rechazar
reparse/symlinks y detectar intercalaciones probadas NO elimina todas las carreras.
La API debe usarse en un padre privado/controlado. No hay fallback path-based.

## Transaccion y errores

1. Revalidar MemoryResult, limites, todos los outputs y PAKV11.Verify en memoria.
2. Crear .pmm-stage-<id> nuevo por handles. MaxBundleBytes <=288 MiB, solo reducible;
   maximos previos del executor/PAK permanecen. No es una cota RSS.
3. Crear las cuatro hojas exclusivamente. Escribir por bloques, comprobar cada
   retorno, File.Sync, volver a leer longitud/EOF/hash y comprobar identidad.
4. Releer y comprobar de nuevo todas las hojas. Sincronizar el directorio donde
   este soportado. Sellar hojas Windows y comprobar cancelacion ANTES del commit.
5. Renombrar a PMM-candidate-<id> sin reemplazar nada: renameat2/RENAME_NOREPLACE
   en Linux amd64; NtSetInformationFile/FileRenameInformation (clase 10)
   via ntdll documentada en Windows, con destino relativo al handle padre.
   NO existe fallback a rename con reemplazo. El rename exitoso es el commit.
6. Comprobar identidad final y sincronizar el padre en Linux; cerrar handles.

6C corrige el adapter Windows tras ejecutarlo en Win10: NtCreateFile no acepta
el pseudocomponente "." para reabrir el padre; se usa su basename real relativo
al ancestro retenido y se compara identidad. El padre existente no pide DELETE,
pero sigue denegando compartir DELETE. La API Win32 de rename devolvia parametro
invalido con el destino anclado en este entorno; la llamada nativa conserva ese
anclaje y el modo no-replace. Ver SESSION04A6C_FINDINGS para evidencia y limites.

Antes del commit: error/cancelacion devuelve nil y revierte solo los archivos
creados y todavia identificados. No usa RemoveAll ni borra archivos ajenos. Fallos
de limpieza conservan PublicationError.ResidueName como nombre RELATIVO de posible
residuo; nunca se ocultan como rollback correcto. No hay bucle de reparacion.

Despues del commit: la publicacion gana una cancelacion tardia. Si falla sync/cierre
se devuelve recibo NO NULO junto a PublicationError{Committed:true}. El caller debe
informar que ya existe una candidata y no tratarla como borrada ni reintentar sobre
el mismo nombre. Un fallo de recheck final marca ListedBytesVerified=false.

Windows vacia buffers de archivos pero no afirma un flush de directorio/volumen
no demostrado; DirectorySyncCompleted=false. En Linux solo es true cuando los
fsync requeridos retornan exito. CrashDurabilityGuaranteed siempre false: no se
simularon cortes electricos ni fallos de hardware/controlador. Cancelacion es
cooperativa y no interrumpe I/O kernel bloqueada.

## Interrupcion y lectura posterior

Un cierre abrupto ANTES del rename puede dejar staging incluso con COMPLETE.json.
InspectCandidate rechaza SIEMPRE el prefijo de staging. No renombrarlo manualmente
para aprobarlo ni eliminarlo recursivamente por encontrar ese nombre.
Despues del rename puede existir un resultado completo aunque el llamador no
recibiera respuesta. Un recibo/pin retenido externamente permite comprobarlo sin
reescribirlo. Sin pin confiable se podra investigar, no declarar origen autentico.

InspectCandidate exige nombre final y pin de manifiesto externo. Comprueba los
cuatro archivos, PAK/outputs e identidades del informe; no ejecuta ni procesa
archivos extra no listados. ListedBytesVerified NO significa directorio inmutable,
lista completa de lo que terceros puedan anadir, ni ausencia de malware.
No se auto-promueve un staging. Una llamada nueva genera un ID nuevo.

El informe execution.json original conserva el bloqueo historico sobre guardado
porque ExecuteBounded sigue sin hacer I/O. El manifiesto/recibo de esta etapa
acredita solo el guardado actual; no reescribe pruebas de etapas anteriores.
Todos los flags de aceptacion de juego/instalacion siguen false.

## Estado de pruebas y fuentes

Linux amd64 probado con archivos artificiales, fallos inyectados, salidas abruptas
y carreras controladas. Windows solo compilado/vet; ver WINDOWS_PUBLICATION_ACCEPTANCE.
No se ejecutaron originales, juego, antivirus, build/deploy productivo ni CI remoto.
Fuentes primarias consultadas 2026-09-19:
https://man7.org/linux/man-pages/man2/rename.2.html
https://man7.org/linux/man-pages/man2/fsync.2.html
https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_rename_info
https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_disposition_info
https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-flushfilebuffers
