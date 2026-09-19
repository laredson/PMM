# Retomar despues de 04A-5C - pertenencia PAK

Rama exclusiva v1.5.0.1-PMM-reliability. Leer AGENTS -> este archivo -> STATUS ->
SESSION04A5C_FINDINGS/CHECKS -> CoreR1/MEMBERSHIP_CONTRACT.md.
04A-5C cerrada en perfil PAK limitado. REL-01 y motor completo siguen abiertos.

## Conservado

PlanCore, CaptureCore y VerifyMembership son APIs distintas. La ultima reabre
archives con pins del snapshot, usa PAKV11.Read intacto y compara todos los bytes
de cada archivo declarado. Exige Profile=MembershipProfile y
CurrentOwnership=UniqueCurrentOwner. Orden registrado no significa prioridad.
Dos propietarios bloquean incluso con bytes iguales; no fallback por hash.
No se vuelve a abrir donor/current. No se promocionan report/plan previos.

Solo perfil v11 ASCII compacto sin compresion/cifrado, PHI/FDI completos, mount
../../../, maximo 256 MiB/archive y 1 GiB agregado. PAKV11 no es un lector universal.
Un proveedor fuera de perfil bloquea, aunque sus bytes tengan el SHA esperado.
Membership verificado no autentica build, schemas ni proceso de extraccion.
No demuestra que existan todos los proveedores del juego ni que no haya otras
entradas/carpetas. TransformReady/BuildReady/Validated/Installed siguen false.

CoreR1/go.mod depende LOCALMENTE de ../PAKV11. build.py conserva ambos modulos en
source/CoreR1 y source/PAKV11, con hashes. No copiar solo CoreR1 para compilar.
No modificar esa biblioteca para acomodar archives no soportados sin otra tanda.
Las fixtures son propias. Harness TEST Windows compilado, NO ejecutado; no es
PMMFixLab.exe. PMM/ intacto: 629 archivos/628 hashes, version 1.5.0.1/s01b,
arbol 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa. Otras candidatas intactas.

## Siguiente 04A-6A - ejecutor acotado con primitivas existentes

1. Fijar HEAD, leer contratos CoreR1, UAsset (RewriteNames/PatchPostProcess),
   PMMDLT1 y PAKV11. No reprogramar los lectores ni recuperar el mismo overlay.
2. Definir un plan de ejecucion explicito por familia unido a snapshot/membership,
   receta, fuentes de nombres y esquema/revision. Reutilizar buffers privados o
   copias verificadas, nunca reabrir rutas para aplicar cambios no revalidados.
3. Implementar UNA ruta completa y acotada de ejecucion en memoria con fixtures
   compatibles con las primitivas reales: cambios de nombres del mismo ancho y
   postProcess escalar cuando todas las precondiciones se cumplen. Sin main o
   CLI que anuncie funciones inexistentes. No claim TRANSFORM_READY por hashes
   solos: el caller debe justificar el plan y su schema; no aprobacion magica.
4. Preservar todos los rechazos existentes de regiones opacas y layouts no
   soportados. Mesh real con relocacion variable o serializer complejo sigue
   UNSUPPORTED. No inventar schema desde offset 120 o fabricar expected outputs.
5. Verificar inputs/outputs, pasos y bytes no afectados; errores/cancelacion sin
   salida parcial. Preparar evidencia externa con fixtures sinteticas propias.
   Guardado transaccional/UI/CLI/V2 quedan separados hasta definir sus contratos.
6. Registrar implementacion y bloqueo real de integracion productiva; commit
   [skip ci] autorizado para esa tanda. Sin cambios PMM/CKL/idiomas/otros nativos,
   originales ejecutados, Actions, PR, release o tags. 04B exige motor completo.

## Reproduccion

En CoreR1: go test -count=1 ./... ; go test -race -count=1 ./...
PMM_R1_PLAN_OUTPUT, PMM_R1_CAPTURE_OUTPUT, PMM_R1_MEMBERSHIP_OUTPUT activan exports
a directorios NUEVOS. PMM_R1_PACKAGE activa solo receta con metadata simulada.
Sin esos opt-ins los tests correspondientes se omiten, no contarlos como PASS.
verify_membership.py <membership-output> hace la segunda lectura Python de PAK.
PMM_R1_TOOL_FIXTURES, PMM_R1_CAPTURE_FIXTURES, PMM_R1_MEMBERSHIP_FIXTURES activan
los oracles de unittest (test_tools test_capture_reference test_membership_reference).
Ver CHECKS para recuentos y hashes finales, no reutilizar los historicos de 5B.
Windows real, schemas reales, familias/Job Objects, manifest/pins/rutas y repair
06/07 siguen pendientes. No pedir subir el juego completo para una prueba local.
