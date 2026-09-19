# 04A-6A - ejecucion acotada EN MEMORIA

Estado: implementada y publicada desde la entrega local preservada.
Registro: ../../../SESSION04A6A_PUBLICATION.json. Pruebas previas no repetidas.
No es source original recuperado, motor FixLab completo, instalador o autorizacion
para reparar meshes reales. No cambia el paquete PMM/ ni sus ejecutables.

## API y secuencia

`ExecuteBounded(ctx, captured, membership, request)` recibe los objetos privados
producidos por CaptureCore y VerifyMembership. No admite reconstruirlos importando
un JSON ni tratar un bool supplied por el caller como prueba de pertenencia.
Devuelve `*MemoryResult` o nil,error. Sus accessors Bytes(path), PAKBytes() y
ReportJSON() entregan copias; no exponen los buffers retenidos. No se abren rutas,
se ejecutan procesos, se escribe al disco ni se accede a la red en esta API.

El caller mantiene inmutables request.Plan.Data y request.Review.Data durante la
llamada. Conserva los objetos originales de captura/membership, no informes
editados. La encapsulacion NO es sandbox frente a codigo hostil dentro del proceso.

1. Verificar JSON/pins/limites de plan y revision; no hay defaults de campos.
2. Comprobar binding a receta, PlanCore, CaptureCore y MembershipEvidence exactos;
   verificar de nuevo TODOS los buffers retenidos y su cobertura con el informe.
3. Comprobar cobertura exacta de tareas/salidas, identidades donante/destino,
   capacidades y presupuesto antes de construir resultados de familias.
4. Usar UAsset.Read/RewriteNames EXISTENTES. Importar entradas crudas solo de
   las currentNameHashSources del plan. Cualquier cambio de ancho se rechaza,
   incluso compensado por otros cambios. Cantidad/orden de slots no varian.
5. Verificar hashes intermedios; aplicar PatchPostProcess EXISTENTE donde la
   receta lo exige. La precarga cambia stale->safe; la propiedad stale->null.
6. Copiar soporte sin cambiar bytes. Comparar cada salida con tamano/SHA-256
   esperado externamente ANTES de construir PAKV11.Build y PAKV11.Verify.
7. Solo despues de todos los pasos entregar buffers y reporte. Error tardio,
   cancelacion o hash incorrecto => nil, no una lista de salidas parciales.

El PAK vuelve a leerse y compararse con los archivos ya contrastados con pins
externos. Su SHA-256 se calcula como IDENTIDAD DEL RESULTADO, no como firma,
expected hash autoaceptado o demostracion de compatibilidad con Unreal.

## Documentos

ExecutionRequest contiene Plan y Review (PinnedJSON), y limites opcionales que
solo se pueden reducir. ExecutionPlan: schema PMM_R1_BOUNDED_EXECUTION_V1,
profile SAME_WIDTH_NAMES_SCALAR_POSTPROCESS_PAKV11_V1, recipeSHA256, planSHA256,
captureSHA256, membershipSHA256, uassetProfile, allowUnversioned, families, outputs.

Cada familia vincula group/targetPath, cuatro pins de entrada (donante y destino,
header/export), nameEdits por indice y sourcePath/sourceIndex, hashes tras nombres
y postProcess opcional. No se puede omitir ni agregar postProcess respecto a la
receta. Postprocess vincula claimSHA256, identidad de export/imports y posiciones
esperadas; estas ultimas son COMPROBACIONES derivadas por el parser, no offsets
que permitan escribir a ciegas. Solo se admite una posicion prevista por receta.

Los schemas/layout/review se toman del dossier CAPTURADO de ese donante/receta/
provider. Se vuelven a comprobar sus bytes y bindings. No se aportan schemas
alternativos inline, ni se fabrican desde el offset 120. El plan de ejecucion
puede referirse al hash de header intermedio tras nombres, pero el claim conserva
la identidad del donante original; ambos estan vinculados por los pasos/pins.

ExecutionReview: schema PMM_R1_EXECUTION_REVIEW_V1, executionPlanSHA256, reviewer,
origin, revision, method, findings. Es obligatorio y pinneado. No contiene approved
ni firma implicita. La API comprueba bytes y vinculacion, NO identidad del revisor,
exactitud del juicio o semantica del schema. El caller debe justificar su revision
y los pins con evidencia independiente; la ejecucion explicita no los autentica.

Outputs es el conjunto COMPLETO de rutas/tamanos/hashes esperados: familias y
soporte. Las expectativas se establecen antes; no se calculan del resultado del
executor para aprobarlo. Soporte requiere exactamente el descriptor del donante.
No se cambia ningun pin de receta o inventario productivo.

## Perfil, errores y memoria

Solo UAsset cooked-ue4-522-ue5-1008; unversioned necesita afirmacion explicita.
Solo nombres del mismo ancho y postProcess escalar ya admitido. Arrays, serializers
complejos, cambio de layout y familias/soporte con .ubulk/.uptnl son UNSUPPORTED.
Regiones opacas se conservan en la misma posicion; eso NO prueba semantica correcta.
Ninguna proteccion de UAsset, PMMDLT1, PAKV11 o captura anterior se elimina.

Techos propios: plan 2 MiB, review 16 KiB, 256 familias, 1024 outputs, 256 cambios
de nombre/familia, 512 MiB de snapshot, 128 MiB de datos de salida. Cada archivo de
salida <=64 MiB; PAKV11 conserva sus limites y perfil sin compresion/cifrado.
Son presupuestos de datos, NO una cota RSS total: las copias, metadata e indices
se suman. El caller limita concurrencia. Context se comprueba por documento,
buffer y operaciones; JSON de informes privados tiene limite de 32 MiB y algunas
comprobaciones acotadas no son preemptivas. No se promete deadline de CPU exacto.

Faltan datos/bindings/capacidad => error explicito (EVIDENCE, BINDING, OUTPUT,
DOSSIER, UNSUPPORTED o error envuelto de la primitiva). No existe fallback al
binario original, eliminacion de checks, subshell ni CLI de build ficticia.

## Lo que demuestra el reporte

MEMORY_OUTPUTS_VERIFIED_NOT_GAME_ACCEPTED significa que los pasos acotados y
los pins aportados coinciden, y el PAK tiene readback byte-exact. Los flags globales
TransformReady/BuildReady/Validated/Installed, CoreR1Complete, SchemaSemanticsVerified
y ReviewerAuthenticated SIGUEN FALSE. No se modifican los reportes anteriores:
sus bloqueos son evidencia historica de cada etapa, no se borran retrospectivamente.

Pruebas SOLO con datos artificiales. Tres escenarios: cada uno tiene 3 familias,
2 postProcess, 4 archivos de soporte y 10 outputs. Un generador Python independiente
especifica los bytes antes/despues; otro lector Python comprueba todos los outputs
y el PAK. No hay aceptacion Unreal, esquema de SkeletalMesh real o PAK de juego.

## Proximo bloque

Guardar el MemoryResult de forma transaccional en una carpeta candidata aislada,
con manifiesto, cancelacion/errores/rollback en fixtures. No instalarlo en el juego.
La semantica/revision real, relocalizacion variable, V2/CLI y aceptacion del motor
completo siguen siendo trabajos distintos. La siguiente tanda es 04A-6B.
