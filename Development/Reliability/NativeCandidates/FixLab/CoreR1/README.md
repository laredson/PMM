# CoreR1 - plan, captura y pertenencia; cierre 04A-5C

Biblioteca aislada RECONSTRUCTION, no motor FixLab completo ni instalador.
Tres APIs separadas; sus informes no se convierten en autorizaciones automaticas.

PlanCore(ctx, Request): valida receta/inventarios declarados y produce PLAN_VALID.
CaptureCore(ctx, CaptureRequest): captura archivos por handles, verifica bytes y
expedientes de schemas; mantiene copias privadas con accesores que devuelven copias.
VerifyMembership(ctx, captured, MembershipRequest): vuelve a verificar los PAK,
usa PAKV11.Read y compara todas las entradas donor/current declaradas del snapshot.
No vuelve a abrir las carpetas de assets ni modifica sus datos.

Leer CONTRACT.md, CAPTURE_CONTRACT.md y MEMBERSHIP_CONTRACT.md. La ultima API
requiere Profile=MembershipProfile y CurrentOwnership=UniqueCurrentOwner: unico
propietario por ruta declarada actual. Duplicados bloquean incluso con bytes
iguales. El ordinal del provider-set no es prioridad; no existe last-wins.
Se comprueba el conjunto pinneado completo, incluidos proveedores sin entradas
seleccionadas. La biblioteca no extrae, transforma, ejecuta procesos o hace red.

ListedEntriesMembershipVerified es correspondencia de bytes SOLO dentro de los
archives listados y del perfil soportado, no historia de extraccion, build
autentico, schema correcto, lista completa de proveedores ni TRANSFORM_READY.
El perfil PAK es limitado, sin compresion/cifrado, 256 MiB/archive. No es un lector
de cualquier PAK del juego. Windows conserva adaptador compilado, no aceptado;
ver WINDOWS_CAPTURE_ACCEPTANCE.md. El guardado transaccional sigue separado.

## Reproducir

Go1.23.2 local, GOPROXY=off, GOSUMDB=off, GOTOOLCHAIN=local, GOWORK=off.
En esta carpeta: go test -count=1 ./... ; go test -race -count=1 ./...
CoreR1 depende LOCALMENTE de ../PAKV11, intacto. No copiar solo esta carpeta.
build.py prepara source/CoreR1 y source/PAKV11 con hashes, sin red.
python -B build.py --out <directorio NUEVO externo> genera CoreR1-tests.exe.
NO es PMMFixLab.exe ni debe instalarse sobre PMM; no ejecuta Windows.

PMM_R1_PLAN_OUTPUT: cuatro planes artificiales a directorio nuevo.
PMM_R1_CAPTURE_OUTPUT: dos capturas artificiales a directorio nuevo.
PMM_R1_MEMBERSHIP_OUTPUT: tres capturas con PAK del perfil a directorio nuevo.
PMM_R1_PACKAGE: solo lectura de receta productiva con inventarios simulados.
Sin opt-ins, cuatro tests de entrega se omiten: no contarlos como PASS.

python -B verify_fixtures.py <plan-output>
python -B verify_capture.py <capture-output>
python -B verify_membership.py <membership-output>

PMM_R1_TOOL_FIXTURES, PMM_R1_CAPTURE_FIXTURES y PMM_R1_MEMBERSHIP_FIXTURES activan
las verificaciones Python sobre esos directorios exportados:
python -B -m unittest -v test_tools test_capture_reference test_membership_reference
La verificacion nueva usa el lector Python PAKV11, no el codigo Go.

En 04A-5C: 80 Test Go Linux con opt-ins, 32 Python, race, vet Windows y dos builds
TEST identicos. Los dos tests Windows exclusivos se compilan, NO cuentan como
PASS. Tres escenarios contrastados en Python: 57 assets en ocho archives propios.
Ver SESSION04A5C_CHECKS.json y evidence/s04a5c/; evidencia previa sigue historica.
No PAK/mesh real, original FixLab, Windows, juego o antivirus ejecutados.
Siguiente 04A-6A: ejecutor acotado con primitivas existentes, sin prometer meshes
reales ni relocalizacion opaca. REL-01 y el motor completo siguen pendientes.
