# Retomar despues de 04A-4B - nombres y offsets UAsset

Rama exclusiva v1.5.0.1-PMM-reliability. Leer AGENTS -> este archivo -> STATUS ->
SESSION04A4B_FINDINGS/CHECKS -> UAsset/REWRITE_CONTRACT.md.
04A-4B cerrada solo en su alcance; 04A completa y REL-01 siguen abiertas.

## Lo ya conservado

PMMDLT1/PAKV11 y Read UAsset no cambiaron. RewriteNames agrega reconstruccion de
la tabla por entradas crudas de referencias con hash esperado, preservando hashes,
encoding, indices y contadores. Summary se preserva salvo offsets conocidos.
Los nombres NO se regeneran desde texto ni se calculan CRC de sustitucion.

No-op e inversa son byte-exactos en fixtures. Reemplazos de igual ancho conservan
todos los offsets y bytes ajenos. Si cambia cualquier ancho (incluso delta total 0),
se rechazan regiones opacas en header, .uexp no vacio y BulkDataStart != 0.
No hay flag de bypass: no copiar un payload opaco con offsets antiguos por comodidad.
Esta restriccion impide todavia relocalizar meshes reales por esta API.

39 tests Go/20 Python; doce reescrituras sinteticas comparadas en Python independiente.
Windows harness compilado dos veces con igualdad, no ejecutado. Ninguna muestra
real de juego/donante se leyo o reparo. Recetas y pins productivos intactos.
PMM conserva arbol 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa (629 archivos/628 hashes),
1.5.0.1 / PMM-v1.5.0.1-reliability-s01b. Candidatas C2B no tocadas.

## Siguiente 04A-4C - export payload/core R1, no V2/CLI ficticio

1. Fijar HEAD y releer core recipe R1 (hash en registro 04A-4B), SOURCE_CONTRACT y
   mapas estaticos originales de patchPostProcess/relocatePackage. No repetir la
   busqueda del overlay invalido ni pedir otra copia del mismo ZIP.
2. Delimitar ANTES una transformacion de payload verificable. La receta menciona
   staleClass ABP_Gura_C, safeClass Body y expectedSerializedOffsets [120]. Ese
   numero NO autoriza escribir bytes sin establecer formato, identidad, longitud,
   campo, valor previo y referencias. No hacer reemplazos globales de strings.
3. Investigar que offsets pueden vivir dentro de exports/bulkdata, usando fuentes
   primarias y evidencia estatica. Implementar el subconjunto demostrado con
   fixtures sinteticos; lo desconocido sigue UNSUPPORTED. No retirar la proteccion
   de RewriteNames porque un buffer vuelva a pasar el lector de cabecera.
4. Conservar bytes no afectados y verificar pre/post-condiciones externas,
   cancelacion, errores, rangos y rechazo. No modificar recetas ni sus pins,
   PMMDLT1/PAKV11 o candidatos Host/Runtime. No integrar una CLI de relleno.
5. Solo despues conectar el core R1 a las primitivas verificadas y construir V2/CLI;
   04B requiere motor completo. Si una evidencia concreta falta, registrarla sin
   inventar compatibilidad. Guardar codigo y proxima entrada exacta en la rama.
6. Un commit [skip ci] autorizado por la intervencion. Sin Actions, PR, tag,
   release, fuentes originales sobrescritas ni ejecutables distribuidos reemplazados.

## Reproduccion

En UAsset: go test -count=1 ./... y python -B -m unittest -v test_reference test_rewrite_reference.
PMM_UASSET_FIXTURE_OUTPUT y PMM_UASSET_REWRITE_OUTPUT activan exports a directorios
nuevos; sin ellos sus tests SKIP. verify_rewrite.py compara doce packets sinteticos.
El builder offline genera UAsset-tests.exe, NO PMMFixLab.exe. No instalarlo.
Todos los gates Windows/Unreal/Palworld siguen NOT_RUN; familias/Job Objects,
manifiestos/pins/rutas R03B-02/04 y repair 06/07 permanecen pendientes.
