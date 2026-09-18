# Retomar despues de 04A-5A - planificador R1

Rama exclusiva v1.5.0.1-PMM-reliability. Leer AGENTS -> este archivo -> STATUS ->
SESSION04A5A_FINDINGS/CHECKS -> CoreR1/README y CONTRACT.
04A-5A cerrada como planificador, NO executor ni motor completo. REL-01 abierta.

## Ya conservado

CoreR1/PlanCore es biblioteca pura, no toca disco/juego. Recipe + donor/current
inventories JSON fijados por hash. Valida donante alternativo, build exacto,
familias, minimos, soporte/exclusiones, nombres, colisiones y outputs.
PLAN_VALID significa metadata coherente. No se comprobaron bytes de assets.
TransformReady/BuildReady/Validated/Installed/InputBytesVerified siguen false.
Los claims schema solo se vinculan y quedan DECLARED_UNVERIFIED; hashes de layout
/review no significan que se hayan leido o autenticado. No hay override de seguridad.

30 tests Go, 10 Python con opt-ins, race Linux, vet Windows, fuzz acotado y dos
builds TEST identicos. La prueba de receta real usa inventarios totalmente
SIMULADOS (93 destinos), no PAK/meshes reales. No convertirla en evidencia de juego.
CoreR1-tests.exe no es FixLab ni debe instalarse. PMM/ sigue 629 archivos/628 hashes,
1.5.0.1/s01b, arbol 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa. Otros componentes intactos.

## Siguiente 04A-5B - verificacion de entradas y expediente de schema

1. Fijar HEAD y mantener intactos paquete, recetas/pins, otras candidatas y codecs.
   No repetir el planificador ni la busqueda del mismo overlay roto.
2. Crear SOLO la capa offline acotada que adquiere/verifica snapshots de entradas
   y emite evidencia para los inventarios. Disenar procedencia del provider-set,
   pinning externo, enlaces/symlinks, limites, errores y cambios durante lectura.
   Debe decir exactamente cuales bytes se comprobaron; no declarar extraccion
   autenticada sin probar su relacion con el PAK donante fijado.
3. Implementar comprobacion del expediente schema (bytes layout/review y bindings)
   solo hasta donde exista evidencia; identidad no es autenticidad ni correccion.
   Antes de depender de un schema real, fijar un formato/revision verificable y
   conocer sus serializers. Los schemas reales no escalares siguen pendientes.
4. Fixtures sinteticas para IO y sustituciones concurrentes; no ejecutar PMM,
   original, juego o reparaciones, no publicar assets de terceros ni inventar
   expected outputs. Si la captura de un equipo Windows necesita datos reales,
   dejar comando local y reporte de metadata, sin pedir subir el juego completo.
5. No cambiar el planner para emitir TRANSFORM_READY solo porque haya hashes.
   La relocalizacion opaca y executor completo siguen gates distintos. No conectar
   CLI de build con placeholders. Separar alcance si la adquisicion y schema no
   caben en una entrega, documentando cual queda pendiente antes de implementarlo.
6. Guardar codigo/tests/evidencia y proxima entrada; un commit [skip ci] autorizado,
   sin Actions, PR, tags, release ni cambios en rama de traducciones.

## Reproduccion

En CoreR1: go test -count=1 ./... ; python -B -m unittest -v test_tools.
PMM_R1_PLAN_OUTPUT=<nuevo dir externo> activa export sintetico.
PMM_R1_PACKAGE=<ruta absoluta PMM> activa SOLO lectura de receta + inputs simulados.
PMM_R1_TOOL_FIXTURES=<export anterior> activa oracle Python y negativos.
Sin opt-ins son 28 Go y 5 Python PASS; los restantes SKIP, no contarlos como PASS.
Todos los gates Windows/Unreal/Palworld, familia/Job Objects, manifests/pins/rutas
y repair 06/07 siguen abiertos. El arranque original del usuario no los acepta.
