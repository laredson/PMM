# CoreR1 - planificacion y captura, cierre 04A-5B

Biblioteca aislada, RECONSTRUCTION. No es el motor FixLab y no instala nada.
PlanCore conserva su contrato declarativo. CaptureCore agrega adquisicion por
handles, snapshots verificados y lectura de layout/review. No transforma assets.
Leer CONTRACT.md para el planner y CAPTURE_CONTRACT.md para captura/dossiers.

## APIs separadas

PlanCore(ctx, Request) produce PLAN_VALID con requisitos: no hace I/O.
CaptureCore(ctx, CaptureRequest) recalcula ese plan, lee archivos declarados,
verifica providers y documentos schema y retorna CapturedInputs o nil,error.
Bytes(role,path), ReportJSON y PlanJSON devuelven copias de buffers privados.
Los archives se hashean por streaming, no se retienen ni se extraen.

CaptureRequest incorpora Plan, Roots, DonorArchive, CurrentProviderSet, Dossiers
y Limits. Los roots deben existir, ser absolutos/canonicos/locales. Todos los
SHA-256 esperados se aportan externamente; no hay generador de pins autoaceptados.
Las structs/exported fields del codigo definen la API exacta. No hay CLI de build
ni main ficticio: la integracion de UI/command line corresponde al motor futuro.

Un snapshot correcto NO prueba pertenencia al PAK, build autentico, ausencia de
archivos extra, schema real correcto o aptitud para reparar. El informe conserva
esas limitaciones y readiness=false. Los schemas complejos siguen UNSUPPORTED.
Windows tiene adaptador compilado, sin pruebas reales; ver WINDOWS_CAPTURE_ACCEPTANCE.md.

## Reproducir

Go1.23.2 local, GOPROXY=off, GOSUMDB=off, GOTOOLCHAIN=local, GOWORK=off.
En esta carpeta: go test -count=1 ./... y go test -race -count=1 ./...
Las pruebas crean SOLO archivos sinteticos bajo carpetas temporales y los borran.
No leen el juego, ejecutables originales ni el Workspace.

PMM_R1_PLAN_OUTPUT=<nuevo directorio> activa cuatro exports de planner.
PMM_R1_PACKAGE=<ruta PMM> activa solo la receta productiva con inventarios simulados.
PMM_R1_CAPTURE_OUTPUT=<nuevo directorio> activa dos exports de captura SINTETICA.
Sin esas variables hay tres tests de entrega SKIP, no PASS.

python -B verify_fixtures.py <plan-output>
python -B verify_capture.py <capture-output>

PMM_R1_TOOL_FIXTURES=<plan-output> y PMM_R1_CAPTURE_FIXTURES=<capture-output>
activan todas las pruebas Python:
python -B -m unittest -v test_tools test_capture_reference

python -B build.py --out <directorio NUEVO externo> genera CoreR1-tests.exe y su
receta/hashes. NO lo ejecuta, ni construye PMMFixLab.exe. No instalarlo sobre PMM.

En 04A-5B pasaron 55 tests Go Linux (30 previos, 25 nuevos), 20 Python, race con
opt-ins y vet Windows. Dos builds finales TEST Windows iguales. Los dos tests
exclusivos Windows solo se compilaron, no cuentan como PASS. Ver evidence/s04a5b/.
Siguiente: vincular pertenencia de archivos a proveedores, no asumirla por hashes.
