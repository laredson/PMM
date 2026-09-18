# Retomar despues de 04A-4C - postProcess acotado

Rama exclusiva v1.5.0.1-PMM-reliability. Leer AGENTS -> este archivo -> STATUS ->
SESSION04A4C_FINDINGS/CHECKS -> UAsset/POSTPROCESS_CONTRACT.md.
04A-4C cerrada como componente, NO core R1/motor completo. REL-01 sigue abierta.

## Conservado y no repetir

PMMDLT1/PAKV11 y Read/RewriteNames UAsset intactos. PatchPostProcess agrega DOS
operaciones: precarga stale->safe y propiedad serializada stale->null. No escribir
safe dentro de la propiedad ni hacer reemplazos globales del int32 antiguo.

El offset 120 de la receta es relativo a .uexp, no al export. Se exige derivarlo
con un schema externo de propiedades unversioned antes de escribir. Inputs y outputs
estan fijados por hashes. Imports se identifican por paquete/Outer/clase, no solo
por nombre. La precarga pertenece a un unico export/grupo y debe tener un solo stale.

El schema admitido es SOLO escalar y explicito; no parser .usmap ni arrays/structs.
Schemas sinteticos disponibles, schema SkeletalMesh real NO disponible/validado.
El caller debe establecer autenticidad/completitud del schema. No crearlo a partir
de la posicion esperada o bytes deseados ni falsear las identidades de salida.
No ampliar RewriteNames para mover payload opaco sin conocer offsets internos.

56 tests Go/31 Python, 7 fixtures nuevas con segunda verificacion byte a byte,
6 lecturas y 12 reescrituras previas, race Linux y fuzz. Harness TEST Windows
compilado, NO ejecutado. Leer CHECKS para hashes finales. No es PMMFixLab.exe.
PMM tree 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa, 629 archivos/628 hashes,
1.5.0.1 / PMM-v1.5.0.1-reliability-s01b. Candidatas C2B no se tocaron.

## Siguiente 04A-5A - planificador y requisitos del core R1

1. Fijar HEAD. Leer receta core R1, SOURCE_CONTRACT y todos los contratos de
   primitivas. No repetir la busqueda del overlay roto ni pedir el mismo ZIP.
2. Implementar un planificador sin escrituras sobre archivos de juego: comprobar
   donante permitido, rutas/grupos de destinos, minimos, soporte y exclusiones,
   familias actuales e identidades de referencia; entradas/fixtures sinteticas.
3. Distinguir PLAN_VALID de TRANSFORM_READY. La receta sola no aporta un schema
   de props ni pins por familia antes/despues: debe informar requisitos faltantes,
   nunca declarar una reparacion utilizable ni usar 120 como layout automatico.
4. La procedencia de schemas y las transformaciones no escalares/relocalizacion
   real deben resolverse antes de ejecutar core R1 completo. Si aparece una fuente
   original NUEVA, verificarla en lugar de seguir reconstruyendo innecesariamente.
5. No conectar una CLI que anuncie build completo con placeholders. No modificar
   CKL/pins/traducciones/Host/Runtime ni el paquete distribuido. No ejecutar mods,
   motor original, juego, bootstrap o reparaciones. 04B requiere motor completo.
6. Documentar salida autoconclusiva y el siguiente requisito concreto; commit
   [skip ci] autorizado, sin Actions, PR, tags, releases ni sustitucion de binarios.

## Pruebas

UAsset: go test -count=1 ./... ; python -B -m unittest -v test_reference
 test_rewrite_reference test_postprocess_reference (una sola linea).
PMM_POSTPROCESS_FIXTURE_OUTPUT=<nuevo directorio> exporta las siete fixtures;
verify_postprocess.py compara cada byte. Sin variables de export se saltan tres
tests de entrega; no contarlos como PASS. build.py solo genera harness TEST.
Los gates Windows/Unreal/Palworld, familias/Job Objects, manifests/pins/rutas
R03B-02/04 y repair 06/07 siguen pendientes. No afirmar cero falsos positivos.
