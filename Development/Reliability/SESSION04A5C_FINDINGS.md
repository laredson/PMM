# 04A-5C - relacion entre snapshots y entradas PAK

Fecha 2026-09-18. Rama exclusiva v1.5.0.1-PMM-reliability.
Entrada d5af1bff255b94e0e47bf9b2ed6f3277712ae346,
arbol 4d10469bd76deaf37fed751ca65e0692d5aa7d5b.
CERRADA en pertenencia para el perfil PAKV11 declarado. No executor completo,
compatibilidad real del juego, fuente original recuperada ni binarios instalados.

## Entrada verificada

HEAD/AGENTS/NEXT_SESSION y las identidades CoreR1/PAKV11 se consultaron en GitHub.
Se verificaron ZIPs y se recalcularon sus arboles locales completos: CoreR1
ed836e4fa6d4672c52ce6ecaa7b00a82fabb85e4 y PAKV11
c2ce8ddd83583817611ca21798061c97ef2f8c82 coinciden con el HEAD inspeccionado.
PMM/.github/snapshot provienen del ZIP 03B SOLO tras recalcular y contrastar sus
tres arboles, todos intactos. No es un checkout completo de las otras candidatas.
La escritura se construye sobre HEAD remoto con exclusivamente las rutas nuevas
/de documentacion de esta tanda. No se vuelve al overlay roto ni se pide el juego.

## Codigo implementado

VerifyMembership consume el CapturedInputs privado de CaptureCore. Revalida la
vinculacion de report/plan/provider-set y los bytes donor/current retenidos. Abre
SOLO los archives con la captura anclada existente, recomprobando SHA-256/size/EOF
/identidad antes y despues. Un .pak con hash correcto pero estructura invalida
sigue rechazado. PAKV11.Read analiza completamente el archive antes de comparar
cada entrada pertinente contra el snapshot, byte por byte.

La politica UNIQUE_OWNER_ONLY_V1 es explicita. Todo proveedor actual declarado
se parsea, incluso si no aporta rutas seleccionadas. Si una ruta declarada aparece
en dos proveedores, se rechaza aunque ambas copias sean iguales; no se escoge la
que tenga el hash conveniente. Casing diferente tambien se rechaza. Se registra
el ordinal del listado sin atribuirle precedencia de montaje. No se ignoran
archivos declarados no seleccionados o excluidos del plan de reparacion.

El perfil y limites se heredan de PAKV11 sin modificarlo: PAK v11 compacto ASCII,
sin compresion/cifrado, PHI/FDI completos, mount ../../../, 256 MiB por archive.
Limite agregado nuevo 1 GiB leido y 64 proveedores mas donante. No son limites del
original ni de memoria residente. Memoria temporal del lector y concurrencia
siguen sumando. No hay extraccion a disco ni ejecucion de herramientas.

El informe solo demuestra correspondencia de bytes en los PAK especificados.
NO acredita proceso historico de extraccion, autor, build, proveedor omitido,
esquema de malla, relocalizacion opaca o readiness. Mantiene esos flags false y
vincula por hashes los informes anteriores, sin modificarlos. Los hashes de
resultado de transformacion no se inventan. Kernel I/O puede bloquear pese a
cancelacion cooperativa; Windows sigue pendiente de ejecucion/aceptacion.

## Pruebas y evidencia

Las cantidades/comandos/hashes finales estan en SESSION04A5C_CHECKS.json.
Fixtures crean PAK validos con datos propios y archivos capturados correspondientes.
Negativos: hash-bound no-PAK, miembro ausente (incluido archivo excluido), bytes
incorrectos dentro de PAK coherente, duplicados identicos/diferentes/case, provider
sin entradas utiles pero invalido, cambio de archivo despues de captura y cambio
de pin/lista/orden, cero/binary, limites, nil, cancelacion por frontera y no alias.
Linux prueba ademas enlaces/FIFO sustituidos tras captura; cuatro comprobaciones
concurrentes comparten el snapshot inmutable bajo detector de carreras.

Tres exports (single/split/extras) se comparan con el lector Python independiente
de PAKV11: cada byte seleccionado, propietario, descriptor y fila del informe.
Hay 19 assets declarados por escenario; los archives adicionales y entradas no
declaradas no generan una falsa afirmacion de completitud. El corpus contiene
solo bytes artificiales, no meshes o PAK del juego. No hay oracle Unreal externo.
El fuzz nuevo prueba binding/JSON previo a I/O, no carreras del filesystem ni AV.

Dos builds finales del harness TEST para Windows/amd64 conservan la dependencia
local PAKV11 y sus hashes. build.py cambia el staging a source/CoreR1 y source/PAKV11.
Las primeras ejecuciones de desarrollo detectaron un nombre de helper de tests
incorrecto y una expectativa de codigo de error; se corrigieron antes de los runs
finales. Los logs previos/build intermedio no se presentan como evidencia final.

## Conservacion

629 archivos PMM /628 hashes/cero discrepancias; 1.5.0.1, build s01b.
PMM tree 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa. PAKV11 no cambia, tampoco
PlanCore/CaptureCore/adaptadores/dossier existentes. go.mod/build.py incorporan la
dependencia local real; no se duplica ni se rebaja su lector. UAsset, PMMDLT1,
Host/Runtime/UIBridge/Supervision, CKL, idiomas, fuentes historicos y CI intactos.
No originales/Windows/repak/juego/reparaciones/antivirus ejecutados. Un commit
[skip ci], sin Actions, PR, tags, release o reemplazo de ejecutables.

## Continuacion

04A-6A: ejecutar un plan ACOTADO con las primitivas existentes y entradas probadas,
solo sobre fixtures, sin fingir compatibilidad con meshes reales. Los esquemas
reales/no escalares, procedencia/revision confiable de planes y relocalizacion
opaca son bloqueos independientes, no los resuelve la pertenencia al PAK.
Se deben emitir errores UNSUPPORTED precisos antes de cualquier output cuando
faltan capacidades. 04B espera un motor completo; no repetir 5C para avanzar.
