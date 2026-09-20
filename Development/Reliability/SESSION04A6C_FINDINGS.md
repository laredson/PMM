# SESSION04A6C - Windows real e interfaz de publicacion

Entrada: 91f643614142283b50b9c1b1be6178fa796138a1, v1.5.0.1-PMM-reliability.
El propietario autorizo continuar mientras prueba I01. Alcance: CoreR1 aislado
y handoff; la aplicacion PMM y su BUILD_ID I01 NO cambiaron ni se ejecutaron.

## Resultado y defectos

Validado en Windows 10 19045 / amd64 / NTFS, token no elevado. Aceptacion entre
entornos PARCIAL: Win11, disco lleno real, AV concurrente y corte electrico no
probados. La prueba inicial encontro 13 tests top-level fallidos; sus nombres y
hash del log permanecen en evidence/s04a6c/test-summary.json.

- NtCreateFile sobre "." devolvia STATUS_OBJECT_NAME_INVALID (0xc0000033).
  Ahora reabre el basename real relativo al ancestro retenido y compara identidad.
- El padre pedia DELETE mientras denegaba compartir DELETE, bloqueando concurrencia.
  Ya no pide DELETE para un padre existente que nunca se borra.
- SetFileInformationByHandle rechazaba el rename anclado con parametro invalido.
  Se usa NtSetInformationFile clase 10 por ntdll, buffer ABI completo,
  RootDirectory retenido y Replace=false; sin fallback path-based.
- Renombrar con hojas abiertas fallaba con STATUS_ACCESS_DENIED (0xc0000022).
  Windows sella/cierra las hojas despues de flush/readback y antes del commit;
  Linux conserva sus handles. Cancelacion tras sellado tambien revierte.
- Rollback tras sellado reabre solo con identidad volumen/file-ID original.
  Una hoja inaccesible/ajena conserva el objeto y genera posible ResidueName;
  nunca se hace borrado recursivo.

El test end-to-end demuestra que el handle de stage impide un rename independiente
de una hoja. El rechazo de identidad ajena se prueba ademas unitariamente con un
padre que SI comparte delete; no se afirma haber eludido el lock de produccion.
La prueba DACL consulta acceso real en carpeta y cuatro hojas con READ_CONTROL,
no solo el descriptor suministrado a la creacion.

## Interfaz implementada

ExecuteAndPublishCandidate compone ExecuteBounded y una sola PublishCandidate.
Seis tests de interfaz con subcasos: rechazo de ejecucion/publicacion, posible
residuo, exito, recibo committed con error y frontera de cancelacion.
Ver INTEGRATION_CONTRACT.md. No se implemento V2/CLI, UI, deploy, autenticacion de
review ni schemas reales bajo otro nombre. No hay retry ni limpieza automatica.

## Evidencia real

- 141 Test Go PASS + 4 targets Fuzz con seeds PASS; 0 fallos. Solo helper SKIP.
- 50 Python PASS + 2 SKIP por privilegio symlink; 0 fallos.
- Cinco verificadores independientes: planes, captura, membership, ejecucion,
  publicacion. Tres bundles con 10 entradas comparadas cada uno.
- Tests Windows nuevos: DACL, permiso real denegado, junction, hardlink, Unicode,
  destino vacio, sellado/rollback y sharing violation.
- Dos builds identicos de CoreR1-tests.exe, 6762496 bytes:
  4ac6f890581fb7a95fc07bf421d92b1b6bfdab4d79db69960da9a872f208fc07.
  Ejecucion del EXE independiente: 40 Test PASS, dos SKIP opt-in/helper.
- 25 repeticiones de cuatro publicaciones concurrentes: PASS.
- go vet Windows y Linux PASS; Linux cross-compile PASS, NO ejecutado.
- No race (sin compilador C); no fuzz aleatorio ni pruebas de fallo electrico.
- I01 conserva 629 archivos tracked, 628 checksums, 0 diferencias.
  PMM/.codex/ del propietario se conserva sin versionar.

Build/logs/fixtures: C:/GPT-Local/Releases/PMM/s04a6c-20260920/.
El binario es harness, NO PMMFixLab.exe. No release/tag/PR/Actions, cambios en
traducciones, privilegios, AV o archivos del juego. Los pins antiguos no cambian.
Los informes originales del builder dicen windowsExecuted=false porque preceden
la ejecucion; el nuevo build-summary agrega el recibo de ejecucion posterior.

## Reproduccion

Go 1.23.2 exacto en PATH; GOTOOLCHAIN=local, GOPROXY=off, GOSUMDB=off,
GOWORK=off, GOENV=off, CGO_ENABLED=0, GOOS=windows, GOARCH=amd64, GOAMD64=v1.
Desde CoreR1, los cinco PMM_R1_*_OUTPUT de README apuntan a directorios NUEVOS
externos. PMM_R1_PACKAGE apunta al PMM solo para receta con inventarios sinteticos.

```text
go test -json -count=1 -timeout=180s .
python -B -m unittest -v test_tools test_capture_reference test_membership_reference test_execution_reference test_publication_reference
go vet ./...
python -B build.py --out <nuevo-externo-a>
python -B build.py --out <nuevo-externo-b>
go test -json -count=25 -run=^TestPublicationConcurrentIndependentCandidates$ .
```

Asignar los cinco PMM_R1_*_FIXTURES Python a los exports correspondientes.
Correr verify_fixtures.py, verify_capture.py, verify_membership.py,
verify_execution.py y verify_publication.py con el directorio como unico argumento.
El .cmd del kit limpia opt-ins; no necesita Go ni elevar permisos.

## Referencias Windows

- [NtCreateFile](https://learn.microsoft.com/en-us/windows/win32/api/winternl/nf-winternl-ntcreatefile)
- [FILE_RENAME_INFORMATION](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/ns-ntifs-_file_rename_information)
- [NtSetInformationFile](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/nf-ntifs-ntsetinformationfile)
- [GetSecurityInfo / READ_CONTROL](https://learn.microsoft.com/en-us/windows/win32/api/aclapi/nf-aclapi-getsecurityinfo)

Las referencias describen las APIs; los PASS proceden de ejecucion local.
Prioridad siguiente: feedback I01, completar matriz en otros entornos cuando
esten disponibles y contrato V2/CLI candidato-only; no sustituir FixLab todavia.
