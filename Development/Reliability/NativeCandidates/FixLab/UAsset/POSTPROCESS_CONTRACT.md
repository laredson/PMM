# 04A-4C: postProcess de tamano fijo, con esquema externo

Estado: reconstruccion PARCIAL del core R1. No motor FixLab completo. No soporte
productivo declarado para Gura. No se ha recuperado el source original.

## Operacion implementada

`PatchPostProcess(ctx, header, exportData, options, request)` realiza exactamente
DOS escrituras int32 LE, despues de comprobar todas las precondiciones:

1. Una referencia de precarga del export cambia de import stale a import safe.
2. El valor serializado de `PostProcessAnimBlueprint` cambia de stale a NULO (0).

Safe NO se escribe en la propiedad. Esta distincion se observa en la funcion
original fijada: 0x539a21..0x539a2c prepara/escribe -(safeIndex+1) en el header;
0x539e67 escribe cero en los offsets serializados comprobados. El recorrido previo
busca la referencia stale y contrasta offsets; no se ha ejecutado esa funcion.

La candidata NO reproduce la busqueda global del int32 dentro de .uexp. Interpreta
el prefijo de propiedades de UN export concreto, encuentra el campo por su schema
y modifica solo ese valor. Un patron identico en un tail opaco queda intacto.
Es una diferencia deliberada, no equivalencia demostrada con el motor historico.

## Esquema: frontera de confianza, no deteccion automatica

Es obligatorio aportar bytes JSON y SHA-256 esperado de un esquema externo
revisado `PMM_FIXED_UNVERSIONED_SCHEMA_V1`, perfil cooked-ue4-522-ue5-1008,
clase `/Script/Engine.SkeletalMesh`, lista ordenada de campos aplanados, nombres
unicos y tipos escalares soportados. Esta lista incluye indices heredados.
NO se obtiene el esquema de los propios valores ni del numero 120 de la receta.
NO se lee .usmap en esta entrega. Un hash comprueba identidad, no legitimidad:
el caller es responsable de autenticar/proveer schema, inputs y resultados esperados.

El lector entiende los fragmentos unversioned de 16 bits (skip 7, zero-mask 1,
last 1, count 7) y el zero mask (1/2 bytes o multiplos de 4). Los indices determinan
los campos y sus longitudes determinan la posicion serializada. Se comprueba toda
la lista presente, incluido lo que viene DESPUES del campo objetivo. Zero-mask
sin valor fisico/propiedad omitida no puede usarse para esta transformacion.
Padding de mask distinto de cero no esta admitido por este perfil acotado.

Tipos: Bool/Byte (1), Int/UInt32/Float/Object/Class (4), Int64/Double/Name (8).
Bool, FName y FPackageIndex se validan. Arrays, estructuras, mapas, strings,
serializadores especiales y tagged properties son UNSUPPORTED. El contrato exige
un esquema completo, pero su completitud no se demuestra a partir de los bytes.
La API no admite skipBytes, un offset forzado ni flags que eliminen sus controles. JSON nulo, claves duplicadas/alternativas
con mayusculas, miembros desconocidos y contenido sobrante se rechazan.

No existe un esquema real de SkeletalMesh validado aqui. Los siete esquemas de
fixtures son ARTIFICIALES. No anunciarlos como schemas Palworld ni reducir uno
real a escalares para que pase. La receta actual por si sola es insuficiente para
invocar esta API: no aporta schemas ni los hashes de cada familia antes/despues.

## Identidad y coordenadas

Inputs .uasset y .uexp obligatorios, snapshoteados con pins antes de leer. Tambien
son obligatorios los dos hashes externos del resultado previsto. El request fija
el indice y nombre del export, imports completos (ruta de paquete/Outer y clase),
indice de precarga y uno de sus cuatro grupos de dependencias. Imports ambiguos,
opcionales, outers exportados y export CDO/no top-level quedan fuera del perfil.

La referencia stale debe aparecer una vez en precarga, dentro del grupo indicado
y pertenecer solo al export seleccionado. La propiedad debe contener esa misma
referencia antes de escribir. Nombre corto coincidente no prueba identidad.

ExpectedSerializedOffset se expresa desde el inicio del .uexp: es comprobacion,
NO la posicion usada a ciegas. Se deriva desde SerialOffset - TotalHeaderSize
mas el recorrido de propiedades. La fixture base tiene export en .uexp+6 y campo
a +114 dentro del export: la posicion absoluta es 120, no 114 ni header+120.

## Preservacion, errores y limites

No se cambian tamanos, tablas, nombres, contadores, layout, GUIDs o offsets.
Los datos nativos/bulkdata posteriores y otras regiones desconocidas permanecen
byte-identicos y en la MISMA posicion. Nunca se relocalizan ni se declaran leidos.
Las restricciones de RewriteNames permanecen sin una sola modificacion.

Tras las escrituras se releen tablas/prefijo, se verifica null/preload y se exige
igualdad con los hashes de salida externos. Error/cancelacion => nil, no objeto
parcial ni mutacion del input. No filesystem, procesos, red, juego o instalacion.
Inputs y planes deben ser inmutables durante la llamada. Limites de Read vigentes,
schema <=128 KiB, <=1024 campos/fragmentos, cadena import <=64. No limites de RSS
ni plazos absolutos de SO declarados. No afirma validez semantica de native tail.

## Pruebas y alcance de la evidencia

56 tests Go: 39 anteriores +17 nuevos, incluidos tres exports opt-in. 31 Python:
20 anteriores +11 nuevos. Siete transformaciones sinteticas contrastadas byte a
byte con resultados esperados y lector Python independiente. Se mantienen las
6 lecturas y 12 reescrituras previas. Race Linux y fuzz acotado del nuevo camino.
El corpus de fixtures se guarda comprimido SOLO para evitar duplicar sus bytes;
se comprueba el hash de los datos decodificados antes de leerlo en los tests.
No es un empaquetado/ofuscacion del programa ni un mecanismo antivirus.

Hay pruebas de offsets equivocados, schema falso/incompleto, cambios fuera del
campo, coincidencias opacas, grupos compartidos, referencias duplicadas, hashes,
zero masks, truncaciones, cancelacion y rechazo de replay. Ninguna prueba usa
assets propietarios. Ni Unreal, Windows ni PMMFixLab original se ejecutaron.

## Referencias primarias de formato

UAssetAPI fijado a commit 3228c1e86261aa08131f7ec0ff1a395f5d0b2a84:
- UAssetAPI/Unversioned/FFragment.cs
- UAssetAPI/Unversioned/FUnversionedHeader.cs
- UAssetAPI/ExportTypes/NormalExport.cs
- UAssetAPI/PropertyTypes/Objects/ObjectPropertyData.cs

Se consultaron como referencia de formato; no se compilo la biblioteca ni se
copio su implementacion. Epic documenta USkeletalMesh.PostProcessAnimBlueprint
como TSubclassOf<UAnimInstance>, y FBulkData expone offsets internos. Eso no
especifica un esquema 522/1008 para un mesh concreto. Ver evidence/s04a4c/static-origin.json.
