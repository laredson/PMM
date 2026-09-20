# CoreR1 - candidato de desarrollo, NO motor instalado en PMM

04A-6C corrige PublishCandidate en Windows real y agrega ExecuteAndPublishCandidate.
04A-6D agrega un job V2 pinneado y un CLI separado, ambos candidato-only.
El paquete PMM/ ya contiene Host/Runtime I01; FixLab permanece original.
Este modulo y su harness siguen aislados y NO sustituyen PMMFixLab.exe.
Leer ../../../RUNNING_VERSION.md e INTEGRATION_CONTRACT.md.

## Recorrido disponible

PlanCore (declaraciones) -> CaptureCore (bytes) -> VerifyMembership (entradas PAK)
-> ExecuteBounded (transformaciones/PAK en memoria) -> PublishCandidate (bundle
nuevo aislado). Ninguna etapa significa aceptacion por Unreal o juego instalado.
InspectCandidate verifica posteriormente un bundle frente a un pin de manifiesto;
no devuelve un objeto ejecutable ni admite importar JSON como MemoryResult.
`RunCandidateJobV2` reconstruye toda la evidencia privada en un proceso; ver
[JOB_V2_CONTRACT](JOB_V2_CONTRACT.md). El CLI no instala ni despliega.

6A reutiliza UAsset para nombres de igual ancho y postProcess escalar. No cambian
layouts opacos, schemas reales/no escalares o hashes productivos. 6B conserva
exactamente el PAK/informe, agrega manifiesto/completion y commit sin reemplazo.
Antes del commit intenta rollback limitado a objetos propios; despues informa
receipt.Published=true incluso si un error posterior acompana al recibo.

[PUBLICATION_CONTRACT](PUBLICATION_CONTRACT.md) detalla API, limites, aislamiento,
precondiciones del caller y errores. [EXECUTION_CONTRACT](EXECUTION_CONTRACT.md),
[CAPTURE_CONTRACT](CAPTURE_CONTRACT.md) y [MEMBERSHIP_CONTRACT](MEMBERSHIP_CONTRACT.md)
siguen vigentes. La nueva capa no cambia retrospectivamente sus flags.

## Pruebas y build

Go1.23.2 instalado separadamente; GOPROXY=off, GOSUMDB=off, GOTOOLCHAIN=local,
GOWORK=off. Modulos locales ../UAsset y ../PAKV11: deben conservarse al compilar.

```text
go test -count=1 ./...
go test -race -count=1 -run 'Test(Publication|Candidate)' ./...
python -B -m unittest -v test_tools test_capture_reference test_membership_reference test_execution_reference test_publication_reference test_job_v2_reference
python -B build.py --out <directorio-nuevo-externo>
```

Evidencia historica 6B (Linux): 130 Test Go PASS con seis opt-ins; helper de cierre
abrupto no se cuenta. Sin exportaciones son menos PASS y seis SKIP adicionales.
52 tests Python con sus cinco directorios de fixtures. Esta tanda paso race sobre
las 26 pruebas nuevas; dos intentos de race COMPLETO se interrumpieron en un test
previo costoso de cancelacion y NO se cuentan como PASS. No se cambio ese test.

Opt-ins Go: PMM_R1_PLAN_OUTPUT, PMM_R1_CAPTURE_OUTPUT, PMM_R1_MEMBERSHIP_OUTPUT,
PMM_R1_EXECUTION_OUTPUT, PMM_R1_PUBLICATION_OUTPUT y PMM_R1_JOB_V2_OUTPUT
requieren destinos NUEVOS.
PMM_R1_PACKAGE solo habilita lectura de receta con metadata artificial.
Opt-ins Python: PMM_R1_TOOL_FIXTURES, PMM_R1_CAPTURE_FIXTURES,
PMM_R1_MEMBERSHIP_FIXTURES, PMM_R1_EXECUTION_FIXTURES, PMM_R1_PUBLICATION_FIXTURES
y PMM_R1_JOB_V2_FIXTURES.
verify_publication.py usa el lector Python PAK y expectativas propias predefinidas.
verify_job_v2.py verifica independientemente el pin del job, las capacidades
negativas, documentos, resultado, bundle y PAK sintetico.

6D en Win10 NTFS: 152 tests Go top-level PASS con seis opt-ins, 4 targets Fuzz
con seeds PASS, 54 Python PASS / 2 symlink SKIP y seis verificadores independientes.
Stress: 2.000 publicaciones secuenciales y 500 rondas de cuatro concurrentes.
Harness completo `-test.count=3`, vet Windows/Linux y cross-build Linux PASS;
sin ejecucion Linux ni race. Win11/AV/disco lleno real siguen pendientes.

El builder produce CoreR1-tests.exe y CoreR1-candidate.exe, no PMMFixLab.exe.
El segundo solo acepta jobs V2 candidato-only; ambos se construyen fuera del repo.
Dos builds 6D de ambos EXE fueron identicos. Harness SHA-256
`7d09da6c001d926d077fd32863f2fd31c6708fd98330106d35a4f0caeebd2d8c`;
CLI SHA-256 `0464e503a96f467e96501d0e71367027501640b7433bb1bd76cb1e159cd781bc`.
El kit separado incluye RUN_WINDOWS_PUBLICATION_TESTS.cmd para probar los cambios
reales de esta tanda en TEMP, no el PMM.exe sin actualizar. Ver
WINDOWS_PUBLICATION_ACCEPTANCE.md antes de ejecutarlo. No pedir exclusiones AV.

Estado/evidencia actual: ../../../STATUS.md, ../../../NEXT_SESSION.md y evidence/s04a6d/.
No mezclar el commit de fuentes con una release, instalacion o aprobacion Nexus.
