# Retomar despues de 04A-6B - guardado candidato aislado

Rama exclusiva v1.5.0.1-PMM-reliability. Entrada de esta tanda:
fe239c33d1a77c47afa08502656f6e2cbe4f913d. No repetir 6A ni 6B.
Leer AGENTS -> RUNNING_VERSION.md -> STATUS -> SESSION04A6B_FINDINGS/CHECKS ->
CoreR1/PUBLICATION_CONTRACT.md y WINDOWS_PUBLICATION_ACCEPTANCE.md.

## Aclaracion obligatoria para el usuario

Los cambios se guardan en Development/Reliability/NativeCandidates/ de ESTA rama.
Los EXE dentro de PMM/ siguen siendo los originales. 1.5.0.1/s01b es la identidad
alineada en 01B, no un indicador de que las candidatas esten integradas. Pull no
compila. No llamar pruebas de las candidatas al arranque del PMM.exe conservado.
Al cambiar por primera vez un binario lanzable, dar BUILD_ID/hash/ruta especificos.

## Conservado

Plan/Capture/Membership/Execute y codecs intactos. PublishCandidate valida el
MemoryResult privado, exige boundaries reales y crea un bundle nuevo de cuatro
archivos: candidate.pak, execution.json, MANIFEST.json, COMPLETE.json.
Writes/Sync/readback -> rename sin reemplazo. Stage SIEMPRE incompleto para los
lectores, aunque exista COMPLETE.json. Rollback no recursivo de objetos propios.
Despues del commit puede retornar receipt!=nil,error con Committed=true: no
asumir que se borro el candidato. Windows dir sync no demostrado; no garantia
contra perdida electrica. InspectCandidate solo verifica bytes con pin externo.
No hay deploy, CLI completa, schemas reales validados o motor R1/V2 general.

130 tests Go completos y 52 Python con opt-ins. Race SOLO 26 nuevas pruebas PASS;
los intentos de race total interrumpidos no son PASS. Windows compilado/vet,
cuatro tests exclusivamente Windows NO ejecutados. El kit contiene harness TEST
para escribir solo fixtures en TEMP; no reemplazar PMM.exe/PMMFixLab.exe.
PMM tree 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa; 629 archivos/628 hashes, s01b.

## Siguiente 04A-6C - aceptacion Windows del guardado y cierre de integracion

1. Fijar HEAD. Revisar el log del kit Windows SI el usuario lo aporta; no asumir
   que correr PMM original ejecuta esos tests. Confirmar SHA del harness en CHECKS.
2. Resolver errores reproducibles de NtCreateFile/DACL/rename/cierre y registrar
   los casos de WINDOWS_PUBLICATION_ACCEPTANCE con evidencia real. Si no existe
   entorno/log Windows, mantener NOT_RUN, no simular aprobacion ni reinstalar EXE.
3. Dejar cerrada la interfaz entre guardado y futura orquestacion V2/CLI: manejar
   receipt+error committed, revalidacion posterior y conservacion de staging sin
   borrados recursivos automaticos. No habilitar deploy al juego.
4. Antes de ampliar R1 productivo, los schemas/serializers reales y relocalizacion
   variable siguen bloqueos independientes. No crear hashes/offsets para forzar
   que pase Gura. No llamar al motor completo hasta que exista su contrato real.
5. Cada cambio autorizado se guarda en esta rama con [skip ci], sin Actions, PR,
   tags o release. Registrar al cierre si afecta SOLO fuentes o tambien PMM/.

El kit ya esta preparado; no rehacer las primitivas para poder probar el writer.
Los gates Host/Runtime, familia de procesos, manifiestos/rutas/pins, reparacion
06/07 y preflight antivirus no se cierran con esta tanda. No prometer check verde.
