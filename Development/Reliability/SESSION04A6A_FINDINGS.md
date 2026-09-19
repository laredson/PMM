# 04A-6A - ejecutor acotado en memoria

Fecha de sesion (El Salvador): 2026-09-18. Logs de ejecucion con hora UTC propia.
Base remota: 587b4ed0c026ff97bb043fad84bd16d09803b02c.
Arbol: 08ebd39c157a00846eed001baff6194dedc24788.
Rama objetivo exclusiva: v1.5.0.1-PMM-reliability.

IMPLEMENTACION LOCAL COMPLETA EN SU ALCANCE. PUBLICACION REMOTA PENDIENTE.
La conexion expone lecturas pero no create_tree/create_commit/update_ref/push.
Se comprobo la lista completa de acciones y el plugin GitHub instalado; no se
simulo un push, se uso un endpoint GET para escribir, ni se alteraron permisos.
El delta y su receta se conservan para aplicarse sobre esta base sin rehacerlo.

## Entrada y alcance

Se leyeron HEAD/AGENTS/NEXT_SESSION y se verificaron los ZIPs existentes. Los
arboles completos de CoreR1, PAKV11 y UAsset extraidos coinciden con la rama:
CoreR1 597e22cfb85abd112ac74c3e43a43dc5334e992a;
PAKV11 c2ce8ddd83583817611ca21798061c97ef2f8c82;
UAsset 5c718b7ef23cd84a1844608dae13438dc4752530.
No se usa un ZIP viejo como autoridad de Host/Runtime u otras candidatas.
PMM del ZIP anterior se comprueba solo por su arbol y todos sus hashes.

Nueva ExecuteBounded: plan+review pinneados, capture privado y membership privado
-> preflight -> nombres del mismo ancho -> postProcess escalar -> soporte copiado
-> todos los outputs contra expectativas externas -> Build/Verify PAK en memoria.
No se reimplementa ningun codec. No hay accesos a disco/red/procesos en el ejecutor;
las carpetas pueden eliminarse tras CaptureCore/VerifyMembership y el resultado
sigue procediendo de los buffers comprobados. Eso se prueba expresamente.

El plan de ejecucion cubre exactamente todas las tareas y outputs de PlanCore.
Vincula receta, plan, capture, membership, donante y destino por identidad. Solo
puede importar entradas de currentNameHashSources. Rechaza todo cambio de ancho,
sidecars bulk, operaciones postProcess omitidas/anadidas o dossier ajeno. Se
comprueban los hashes intermedios y finales. El dossier usa bytes ya capturados.
PostProcess conserva sus dos escrituras diferentes y no reemplaza patrones globales.

La revision del plan es un documento real con autor/metodo/revision declarados,
pero NO se autentica al autor ni se demuestra semantica por coincidir un hash.
Un plan arbitrario no se convierte en receta productiva solo por ejecutarlo. Los
schemas usados son artificiales. No se generan los pins esperados del resultado
que el propio executor acaba de producir para aprobarlo.

Los resultados se entregan solo al final. Cada error/cancelacion devuelve nil,
aunque una familia anterior haya terminado. Los accessors devuelven copias.
Los reportes de PlanCore/CaptureCore/VerifyMembership no se modifican; sus limites
historicos no se reescriben retrospectivamente. El nuevo reporte mantiene false
TransformReady, BuildReady, Validated, Installed, SchemaSemanticsVerified,
ReviewerAuthenticated y CoreR1Complete. OutputPinsChecked y PAKReadbackByteEqual
se refieren UNICAMENTE a la ruta acotada completada.

## Evidencia final

104 funciones Test Go con aserciones: 80 previas +24 nuevas. Cero SKIP con todos
los opt-ins activados. Cuatro funciones Fuzz ejecutan sus semillas en la suite,
pero NO se suman a esos 104 tests. 44 tests Python: 32 anteriores +12 nuevos.
Suite race Linux completa PASS. Dos tests exclusivos de Windows solo compilados.

Tres escenarios propios: basic/masked/decoy. Cada uno ejecuta tres familias,
dos postProcess, cuatro archivos de soporte y diez outputs (30 archivos totales,
tres PAK). Python construye los cambios esperados por posiciones de SUS fixtures
sin llamar a Go; el lector PAK Python vuelve a comprobar nombres y TODOS los
bytes. Se mantienen los oracles previos de cuatro planes, dos capturas y tres
pruebas de pertenencia. No assets de juego ni mods usados/redistribuidos.

Negativos incluyen pins/revision ausente o ajena, JSON ambiguo, evidencia vacia o
cruzada, bytes retenidos alterados, familia/output omitido/duplicado, source de
nombre no permitido, cambio de ancho, sidecars, error tardio de postProcess,
preload/offset/clase incorrectos, cancelacion por frontera y copias sin alias.
Cuatro llamadas concurrentes comparten el snapshot inmutable bajo race detector.

FuzzExecutionDocument: 92427 entradas, 5 segundos solicitados (log ~6 segundos).
Prueba solo decoding JSON previo a ejecucion, no filesystem, mesh real ni antivirus.
Go vet Windows PASS. Dos builds finales TEST Go1.23.2 Windows/amd64 byte-identicos:
fa92349e026e36cd85804c87f9dde045e5c4f217429dd1be5aae2dd510642b9f, 6511616 bytes.
El builder conserva CoreR1/PAKV11/UAsset y el fixture embed. go.mod declara 1.23.2
para satisfacer la dependencia UAsset ya fijada a esa version. Sin descargas.

Un runner agrupado previo excedio la ventana de espera durante la validacion race;
no se conto como terminado. El run final separado tiene exit 0 y log PASS.
Los primeros errores de compilacion por nombre del helper de tests se corrigieron
antes de la suite final y builds finales. No se ocultan como pruebas exitosas.

## Conservacion y limites

PMM: 629 archivos/628 checksums, cero discrepancias, version 1.5.0.1/build s01b.
Arbol 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa. Ningun archivo PMM/ cambia.
PAKV11 y UAsset conservan sus arboles exactos. Las APIs anteriores de CoreR1 y
adaptadores OS no cambian; solo go.mod/build.py agregan la dependencia local y
staging necesarios. PMMDLT1, otras candidatas, CKL, idiomas y workflows intactos.

No original/FixLab/Windows/Unreal/Palworld/repak/AV ejecutados. No reparaciones reales,
instalacion, firma, upload de muestras, PR, tag, release ni workflow solicitados.
El PAK artificial resultante NO es una reparacion Gura ni aceptacion de meshes.
No se ha recuperado source original o terminado el motor de la receta R1/V2.

Publicar el delta primero; despues 04A-6B: publicacion transaccional a directorio
candidato aislado, con manifiesto/errores/cancelacion en fixtures. No despliegue al
juego ni CLI que prometa core completo. Las revisiones/schema reales, serializers,
relocalizacion general y gates Windows siguen separados y pendientes.
