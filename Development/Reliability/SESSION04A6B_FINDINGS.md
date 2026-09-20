# 04A-6B - guardado candidato transaccional aislado

Fecha local 2026-09-19. Rama exclusiva v1.5.0.1-PMM-reliability.
Entrada fe239c33d1a77c47afa08502656f6e2cbe4f913d,
arbol c75cb2ec022ba88339ba3726c3861d5018a3f562.
CERRADA en implementacion/fixtures de guardado. Windows solo compilado, NO aceptado.
No es motor FixLab completo ni programa PMM actualizado; se explico al usuario.

## Procedencia

HEAD, AGENTS y handoff se leyeron en GitHub. Fuentes desde el ZIP 6A verificado,
con dos documentos de publicacion reconciliados con sus hashes del commit.
Se recalculo CoreR1 completo de entrada y coincide con
ccba5d50ac723302bdbdd62761702dd5de947a33. PAKV11 y UAsset coinciden con sus trees
remotos sin modificarlos. PMM/.github/snapshot del ZIP previo solo se usan tras
comprobar trees; NO se presenta ese checkout parcial como todas las candidatas.

## Implementacion

PublishCandidate admite exclusivamente MemoryResult privado. Revalida outputs,
PAK/report y contratos; no acepta un JSON como objeto ejecutado. Boundaries reales
obligatorios, handles anclados, hijo nuevo aleatorio, escritura exclusiva y DACL
Windows protegida. Guarda PAK, informe intacto, manifiesto y completion; no extrae
assets ni copia archivos sobre candidatos anteriores. Bytes/EOF/identidad se
releen antes de rename sin reemplazo. Inspeccion posterior exige pin externo.

Antes del commit: rollback solo de objetos propios identificados, sin RemoveAll.
Si cleanup falla se informa residuo posible; no se oculta. Despues del commit:
receipt NO NULO mas error Committed=true; no declarar rollback ni borrar el resultado.
La cancelacion tardia no revoca un commit realizado. Staging no se auto-promueve,
aunque ya contenga COMPLETE.json. No reintentos para vencer bloqueos antivirus.

Las funciones Windows fueron contrastadas con documentacion Microsoft, Linux con
man-pages de rename/fsync. Archivos se sincronizan; directorios solo se afirman
sincronizados en Linux cuando retorna exito. Ninguna garantia de corte electrico,
I/O kernel acotada o resistencia frente a un actor hostil con mismo privilegio.
El caller debe controlar el namespace padre y declarar ubicaciones protegidas
reales: no se descubren instalaciones desconocidas ni se congela ascendencia.

## Verificaciones reales

130 Test Go PASS (104 existentes +26 nuevos), 52 Python PASS, opt-ins de fixtures
activados. Helper de salida abrupta se omite como entrada independiente y no se
cuenta; lo invocan dos pruebas subprocess. Cuatro tests Windows-only COMPILADOS,
NO ejecutados ni incluidos en los PASS Linux.
Race sobre las 26 pruebas nuevas PASS. Dos intentos de race COMPLETO terminaron
por limite de ejecucion de herramienta en el test previo costoso de cancelacion;
no son PASS ni se altero el test previo. Se conservan logs de la tentativa y del
run enfocado. El suite completo SIN race paso. No nuevo fuzz filesystem fingido.

Casos: flujo completo e inspeccion, rechazo de MemoryResult vacio/alterado,
boundaries, colisiones incluidas carpetas vacias, permisos, symlinks, sustitucion
ajena, corrupcion, fallo de escritura/flush, short-write, cleanup fallido,
cancelacion antes/despues, error de cierre real, publicaciones concurrentes y
terminacion abrupta sin defers. Todos los inputs son artificiales. Disco lleno
se inyecta, no se lleno un disco real; os.Exit no simula perdida electrica.

Python verifica tres bundles, 30 entradas PAK byte a byte usando el parser
independiente y expectativas pre-autorizadas del generador sintetico. Plan,
captura, membership y ejecucion previos conservan sus cuatro oracles sin cambios.
Dos compilaciones TEST Windows Go1.23.2 identicas; comandos/hashes en CHECKS.
No se ejecutaron Windows, originales, juegos, reparaciones reales o antivirus.

## Programa lanzable y registro

PMM/ permanece exactamente s01b: 629 archivos, 628 hashes correctos, tree
09df5c45aee3390c6b8ea235c8afa4e149a9f1fa. Codecs, otros nativos, traducciones,
CKL, fuentes historicos y .github intactos. No se modifica la logica previa de
Plan/Capture/Membership/Execute; build.py solo identifica el nuevo harness.
RUNNING_VERSION.md y las portadas aclaran que la rama contiene fuentes nuevas
pero PMM.exe aun no las ejecuta. El kit Windows prueba ESTA capa, no el programa.

No release/tag/PR ni Actions. Un commit de desarrollo [skip ci] preserva codigo,
tests, evidencia y la continuacion. La API de publicacion no confiere game acceptance.
Siguiente 04A-6C: aceptar el guardado en Windows y cerrar su interfaz de integracion;
core real, schemas/serializers, relocalizacion, V2/CLI y gates previos siguen abiertos.
