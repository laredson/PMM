# Retomar despues de 04A-4 - lectura UAsset

Rama exclusiva v1.5.0.1-PMM-reliability. 04A-4 cerrada en componente de lectura;
04A completa/REL-01 siguen abiertas. No pasar todavia a comparacion 04B.
Leer AGENTS -> este archivo -> STATUS -> SESSION04A4_FINDINGS/CHECKS ->
NativeCandidates/FixLab/UAsset/README.md y FORMAT.md.

## Conservado

PMMDLT1, PAKV11 y UAsset son bibliotecas separadas con codigo/fixtures/recetas,
NO un motor FixLab completo. No repetirlos ni reabrir la busqueda del overlay
invalido sin una pista nueva. No usar ZIP viejos como autoridad de Host/Runtime.
Paquete 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b, 629 archivos/628 hashes.
PMM tree 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa. Candidatas C2B intactas.

UAsset admite el perfil explicito cooked-ue4-522-ue5-1008. 0/0 solo por afirmacion
externa AllowUnversioned; nunca adivinar. Imports 32/exports 96 bytes, names,
summary/offsets, depends/preload, comprobacion de rangos .uexp cuando se suministra.
AssetRegistry y gaps/tail son OPACOS. Propiedades/bulkdata no decodificados.
Metadata read no equivale a transformacion o carga valida por Unreal.

23 tests Go con aserciones (export fixture opt-in incluido), 12 Python, seis
fixtures comparadas con lector independiente y race Linux. Dos builds TEST
Windows iguales: 12a8a4e96d739061389cb61d934f78b2da749d0cd6ed963c03c88c8c69a98feb.
NO es PMMFixLab.exe; no reemplazar binarios. Go1.23.2 local/offline.

## Siguiente 04A-4B - serializacion y relocalizacion acotadas

1. Fijar HEAD y leer SOURCE_CONTRACT, la receta core R1 original y mapa estatico
   de serializeSummary/encodeNameEntry/relocatePackage/patchPostProcess. Original
   FixLab pin 8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe.
2. Definir ANTES un alcance terminado: reconstruir header/names y ajustar offsets
   en fixtures sinteticos, con las invariantes de lector 04A-4. Si las operaciones
   postProcess/core no caben, registrarlas como proximo bloque, no fingir motor.
3. Conservar todos los bytes opacos o rechazar el asset si no se conoce como
   relocalizarlos. Un span reportado como opaco NO significa que no contenga
   offsets internos. No sustituir CRC/name hashes actuales por valores inventados.
4. Verificar identidad inmutable de entradas, expected deltas/offsets, no cambios
   fuera del alcance, roundtrip sin cambios y lectura independiente del resultado.
   Ajustar SerialOffset con respecto a TotalHeaderSize, no a posiciones deducidas.
5. Solo fixtures propios. No leer/redistribuir assets donantes/juego ni ejecutar
   original, reparaciones, Unreal o repak. No tocar CKL, pins, traducciones,
   PMMDLT1/PAKV11 o Host/Runtime/UIBridge/Supervision en esa tanda.
6. Guardar codigo, evidencia y siguiente paso. Commit [skip ci] autorizado,
   sin Actions/PR/tag/release ni sustitucion. 04B requiere motor completo V2/CLI.

## Reproduccion actual

En UAsset: go test -count=1 ./... ; python -B -m unittest -v test_reference.
PMM_UASSET_FIXTURE_OUTPUT=<directorio nuevo> activa la exportacion sintetica;
python -B verify_reference.py <directorio> realiza la segunda lectura.
python -B build.py --out <directorio nuevo EXTERNO> compila harness sin ejecutarlo.

Gates Windows/Unreal/Palworld NOT_RUN; source original NO recuperado. Siguen
familias/Job Objects, manifests/pins/rutas R03B-02/04 y repair 06/07. No confundir
arranque del PMM original o fixtures correctas con aceptacion de las candidatas.
