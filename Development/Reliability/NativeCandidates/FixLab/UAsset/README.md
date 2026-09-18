# UAsset - componentes reconstruidos de FixLab

Read (04A-4), RewriteNames (04A-4B) y PatchPostProcess (04A-4C) permanecen aislados.
No es PMMFixLab.exe ni source original recuperado. No instalar el harness de tests.

- FORMAT.md define el perfil de lectura cooked-ue4-522-ue5-1008.
- REWRITE_CONTRACT.md limita la reescritura de nombres y mantiene el rechazo de
  movimientos con header/export opaco. No se ha ampliado ese permiso.
- POSTPROCESS_CONTRACT.md define la nueva operacion fija: precarga stale->safe,
  propiedad PostProcessAnimBlueprint stale->null. No reemplazos globales.

PatchPostProcess requiere snapshots, pins externos de entrada Y salida, identidad
completa de imports/export y un schema escalar externo revisado. No autodetecta
el schema ni lo extrae de la receta. No soporta arrays/structs/custom serializers;
no se ha validado un schema real de SkeletalMesh. Los schemas de tests son ficticios.
Todos los API de transformacion devuelven memoria, no instalan ni escriben archivos.

## Reproduccion

Desde esta carpeta, Go1.23.2 local y Python 3.9+:

    go test -count=1 ./...
    python -B -m unittest -v test_reference test_rewrite_reference test_postprocess_reference

PMM_UASSET_FIXTURE_OUTPUT, PMM_UASSET_REWRITE_OUTPUT y PMM_POSTPROCESS_FIXTURE_OUTPUT
activan exports sinteticos a directorios NUEVOS; sin ellos tres tests se saltan.
No sumar SKIP como PASS. Verificadores independientes:

    python -B verify_reference.py <reader-packets>
    python -B verify_rewrite.py <rewrite-packets>
    python -B verify_postprocess.py <postprocess-packets>

    python -B build.py --out <directorio nuevo fuera del repositorio>

El builder offline conserva hashes de fuentes y genera un harness TEST Windows,
no el motor. No descarga toolchain/dependencias y nunca ejecuta el EXE generado.
56 tests Go/31 Python y las regresiones pasaron en Linux; Windows/Unreal siguen
NOT_RUN. Evidencia nueva en evidence/s04a4c; evidencia previa preservada aparte.
