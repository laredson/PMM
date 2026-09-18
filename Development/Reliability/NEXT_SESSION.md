# Retomar despues de 04A-5B - captura y dossier

Rama exclusiva v1.5.0.1-PMM-reliability. Leer AGENTS -> este archivo -> STATUS ->
SESSION04A5B_FINDINGS/CHECKS -> CoreR1/CAPTURE_CONTRACT.md.
04A-5B cerrada como capa de captura, NO executor ni motor completo. REL-01 abierta.

## Conservado

PlanCore sigue declarativo. CaptureCore recalcula el plan y captura todas las
entradas enumeradas desde roots locales por handles, con hash/size/EOF/metadata.
Buffers privados y accessors copian; archives solo streaming. ProviderSet JSON
versionado vincula inventario current a lista de archives. Dossiers cargan bytes
layout/review y comprueban bindings, pero no autentican autor ni semantica.
No volver a programar la captura ni cambiar los flags del planner a ready.

Snapshot verificado NO es extraccion verificada ni snapshot atomico del FS.
No se enumeran ficheros no declarados. Todo input esperado sigue necesitando pins
externos confiables. No se habilito relocalizacion opaca ni se genero schema real.
Las pruebas usan archivos realmente leidos, pero TODOS artificiales, no assets.

55 tests Go Linux/20 Python, race y dos escenarios comprobados en Python. Dos
builds TEST Windows iguales, no ejecutados. Ver CHECKS para hashes. Dos tests
Windows especificos estan compilados, no PASS. Diez casos Windows NOT_RUN.
No copiar CoreR1-tests.exe sobre PMMFixLab.exe. No hace falta aportar el juego.
PMM tree 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa, 629 archivos/628 hashes,
1.5.0.1 / PMM-v1.5.0.1-reliability-s01b. Otras candidatas y recetas intactas.

## Siguiente 04A-5C - pertenencia a proveedores y frontera de ejecucion

1. Fijar HEAD y leer contratos CoreR1/PAKV11 y expediente. No repetir tandas ni
   busqueda del overlay sin pista nueva. No usar un ZIP viejo como autoridad remota.
2. Disenar e implementar prueba de relacion entre bytes de un proveedor pinneado
   y cada path/size/hash capturado, para un perfil PAK DECLARADO y soportado.
   Reutilizar PAKV11 sin afirmar soporte de compresion/cifrado inexistente.
3. Un .pak con SHA correcto pero sintaxis no validada no prueba pertenencia. No
   reabrir paths sin recomprobar pins ni asumir que el archive no cambio desde 5B.
   Un conjunto de proveedores requiere orden/ownership/resolucion explicitos;
   rutas ambiguas deben bloquearse, no elegir silenciosamente un proveedor.
4. Fixtures sinteticas de PAK con sus bytes esperados, archivos omitidos,
   modificados y duplicados. Sin PAK/juego real ni datos propietarios subidos.
5. Mantener separados MembershipChecked, schema semanticamente validado,
   TransformReady y BuildReady. La pertenencia sola no habilita meshes opacos ni
   un executor completo. No implementar una CLI de build con placeholders.
6. Registrar codigo/evidencia/limites/siguiente paso. Un commit [skip ci] autorizado,
   sin Actions/PR/tag/release, sin alterar PMM/, traducciones u otras candidatas.

## Reproducir 5B

En CoreR1: go test -count=1 ./... y go test -race -count=1 ./...
PMM_R1_PLAN_OUTPUT, PMM_R1_CAPTURE_OUTPUT -> directorios NUEVOS de fixtures.
PMM_R1_PACKAGE -> solo receta empaquetada con metadata simulada. Sin opt-ins tres
Test de entrega se omiten; no sumar SKIP como PASS. verify_capture.py compara los
dos exports artificiales. Ver README para variables de los 20 tests Python.
build.py compila harness TEST offline Go1.23.2; no ejecuta Windows ni motor.
Los gates previos Windows/Unreal/Palworld, familias/Job Objects, manifests/pins/rutas
y repair 06/07 siguen pendientes. Schemas reales no escalares siguen sin validar.
