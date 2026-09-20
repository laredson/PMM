# CoreR1 - candidato de desarrollo, NO motor instalado en PMM

04A-6B agrega PublishCandidate e InspectCandidate. El programa PMM/ sigue usando
sus ejecutables anteriores; cambiar de rama o hacer Pull no recompila esos EXE.
Leer ../../../RUNNING_VERSION.md. El build del paquete sigue siendo s01b.

## Recorrido disponible

PlanCore (declaraciones) -> CaptureCore (bytes) -> VerifyMembership (entradas PAK)
-> ExecuteBounded (transformaciones/PAK en memoria) -> PublishCandidate (bundle
nuevo aislado). Ninguna etapa significa aceptacion por Unreal o juego instalado.
InspectCandidate verifica posteriormente un bundle frente a un pin de manifiesto;
no devuelve un objeto ejecutable ni admite importar JSON como MemoryResult.

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
python -B -m unittest -v test_tools test_capture_reference test_membership_reference test_execution_reference test_publication_reference
python -B build.py --out <directorio-nuevo-externo>
```

130 Test Go PASS con los seis opt-ins de entrega activados; helper de cierre
abrupto no se cuenta. Sin exportaciones son menos PASS y seis SKIP adicionales.
52 tests Python con sus cinco directorios de fixtures. Esta tanda paso race sobre
las 26 pruebas nuevas; dos intentos de race COMPLETO se interrumpieron en un test
previo costoso de cancelacion y NO se cuentan como PASS. No se cambio ese test.

Opt-ins Go: PMM_R1_PLAN_OUTPUT, PMM_R1_CAPTURE_OUTPUT, PMM_R1_MEMBERSHIP_OUTPUT,
PMM_R1_EXECUTION_OUTPUT, PMM_R1_PUBLICATION_OUTPUT requieren destinos NUEVOS.
PMM_R1_PACKAGE solo habilita lectura de receta con metadata artificial.
Opt-ins Python: PMM_R1_TOOL_FIXTURES, PMM_R1_CAPTURE_FIXTURES,
PMM_R1_MEMBERSHIP_FIXTURES, PMM_R1_EXECUTION_FIXTURES, PMM_R1_PUBLICATION_FIXTURES.
verify_publication.py usa el lector Python PAK y expectativas propias predefinidas.

El builder produce CoreR1-tests.exe, no PMMFixLab.exe. Windows solo compilado/vet.
El kit separado incluye RUN_WINDOWS_PUBLICATION_TESTS.cmd para probar los cambios
reales de esta tanda en TEMP, no el PMM.exe sin actualizar. Ver
WINDOWS_PUBLICATION_ACCEPTANCE.md antes de ejecutarlo. No pedir exclusiones AV.

Estado/evidencia: ../../../STATUS.md, ../../../NEXT_SESSION.md y evidence/s04a6b/.
No mezclar el commit de fuentes con una release, instalacion o aprobacion Nexus.
