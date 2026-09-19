# CoreR1 - plan, captura, pertenencia y ejecucion acotada

04A-6A publicada desde la entrega preservada (base 587b4ed).
Ver ../../../SESSION04A6A_PUBLICATION.json para el cierre de publicacion.
No es PMMFixLab.exe completo ni source original recuperado. PMM/ queda intacto.

APIs existentes sin cambios:
- PlanCore: plan declarativo, no verifica assets ni autoriza transformacion.
- CaptureCore: snapshots locales pinneados y dossiers, no semantica de malla.
- VerifyMembership: correspondencia con entradas PAK en perfil limitado.

Nueva API ExecuteBounded: consume objetos de captura/membership existentes y un
plan/review explicitos pinneados. Reutiliza RewriteNames y PatchPostProcess de
UAsset; exige nombres del mismo ancho, preserva bytes ajenos, copia soporte y
produce/valida un PAK en memoria. No lee rutas ni publica archivos. No se suman
ready flags a las etapas previas. Ver [EXECUTION_CONTRACT](EXECUTION_CONTRACT.md).

Las expectativas de salida y revision vienen de evidencia externa, no de aprobar
el resultado que acabamos de producir. El reporte no autentica al revisor ni el
schema. Un PAK consistente no prueba que una malla sea valida en Unreal/Palworld.
No se aceptan cambios de tamano, serializers no escalares ni bulk sidecars.

## Modulos y pruebas

Go1.23.2 local. Dependencias exclusivamente locales ../PAKV11 y ../UAsset, sin
copias divergentes ni downloads. Conservar los tres directorios al compilar.
PMMDLT1 no participa en esta ruta R1; se integrara donde V2 requiera sus parches.

Desde CoreR1, con GOPROXY=off/GOSUMDB=off/GOTOOLCHAIN=local/GOWORK=off:

```text
go test -count=1 ./...
go test -race -count=1 ./...
python -B -m unittest -v test_tools test_capture_reference test_membership_reference test_execution_reference
python -B build.py --out <directorio-nuevo-fuera-del-repositorio>
```

Los exports opt-in requieren directorios NUEVOS: PMM_R1_PLAN_OUTPUT,
PMM_R1_CAPTURE_OUTPUT, PMM_R1_MEMBERSHIP_OUTPUT y PMM_R1_EXECUTION_OUTPUT.
PMM_R1_PACKAGE apunta a PMM solo para leer receta con inventarios SIMULADOS.
Sin esas variables se omiten cinco tests de entrega; no contar SKIP como PASS.

Los oracles Python usan PMM_R1_TOOL_FIXTURES, PMM_R1_CAPTURE_FIXTURES,
PMM_R1_MEMBERSHIP_FIXTURES y PMM_R1_EXECUTION_FIXTURES, apuntando a esos exports.
`python -B verify_execution.py <execution-output>` comprueba tres escenarios,
30 outputs y sus tres PAK, sin importar Go ni ejecutar herramientas externas.
La especificacion propia `testdata/make_execution.py` conserva los bytes esperados;
su reproduccion usa el generador sintetico existente de UAsset, no datos de juego.

build.py solo compila CoreR1-tests.exe con fuentes/fixtures/dependencias fijadas
en la salida y un informe de hashes. No lo ejecuta, firma o instala. NO copiarlo
sobre PMMFixLab.exe. Los tests Windows exclusivos de captura siguen NOT_RUN.

## Registro

Resultados locales 6A en evidence/s04a6a; historia 5A/5B/5C permanece intacta.
Leer ../../../NEXT_SESSION.md para continuar con 04A-6B; no rehacer
las primitivas ni usar un ZIP antiguo como estado completo de otras candidatas.
