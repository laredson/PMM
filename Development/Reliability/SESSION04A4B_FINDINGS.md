# 04A-4B - serializacion y relocalizacion acotadas

Fecha 2026-09-18. Entrada e8608cf0f0283180d99a1c88e085e1a78cfae295,
arbol abee2176c38a840fa67f33454a620ce6adafc659. Rama reliability exclusiva.
CERRADA en el reescritor de tabla de nombres y offsets conocidos. No core R1
completo, motor FixLab, source original recuperado ni equivalencia demostrada.

## Entrada verificada y decisiones

Se recuperaron los fuentes UAsset del ZIP 04A-4, comprobados con su recibo y
hashes de contenido de la entrega fijada. AGENTS y NEXT_SESSION se leyeron de
GitHub. PMM/.github/Development/Source se toman del ZIP anterior solo despues de
recalcular sus subarboles Git: coinciden con los IDs de la base remota. No se
presenta esa copia selectiva como HEAD de todos los candidatos. La publicacion
aplica exclusivamente el delta actual sobre el arbol remoto.

La receta core R1 exige nombres/hashes de referencias actuales y una operacion
postProcess especifica. Se conservaron su hash y cuatro rangos del original:
serializeSummary, encodeNameEntry, relocatePackage, patchPostProcess. Se leyeron
como datos con objdump y se recalcularon los hashes de sus bytes .text. No se
ejecutaron ni decompilaron como supuesta fuente recuperada. Epic documenta el
significado de TotalHeaderSize/SerialOffset; FORMAT fija el perfil 522/1008 previo.

## Implementacion y frontera de seguridad

RewriteNames valida pins de snapshot .uasset/.uexp y fuentes antes de analizar,
importa entradas serializadas completas por indice, conserva encoding/hash/raw
bytes y mantiene el numero y orden de slots. No genera hashes desde texto nuevo.
No-op retorna copias con identidad exacta, sin normalizar summary o strings.

Con anchos iguales, todo lo ajeno a los slots se conserva en la misma posicion.
Si cambia algun ancho, NO se acepta region opaca del header, .uexp no vacio ni
BulkDataStart no cero. Un delta total de cero tampoco elimina ese riesgo. No hay
flag de autorizacion que omita el rechazo. Esa decision permite probar la
relocalizacion de header/exports vacios sin fingir reescritura segura de meshes.

Se ajusta TotalHeaderSize y cada marcador posterior; interior ambiguo se rechaza,
ceros se conservan. SerialOffset se calcula respecto al nuevo TotalHeaderSize,
incluso si la tabla export esta antes de nombres. Se vuelve a leer todo y se
comprueban entradas crudas, cantidades y coordenadas. Errores => nil, no salida
parcial ni escritura a disco. Todo input/plan debe ser inmutable durante la llamada.

Esta NO es serializeSummary general ni relocatePackage/core R1 completo. No cambia
GUIDs, propiedades, imports o FNames por fuera de los slots, cache de nombres,
postProcess o bulkdata. El caller debe justificar semanticamente cada cambio y
los pins, que solos no autentican origen. El guardado transaccional queda pendiente.

## Evidencia real

39 funciones Test Go con aserciones: 23 anteriores y 16 nuevas; ambos exports
opt-in activados. 20 tests Python: 12 anteriores y 8 del verificador nuevo. Suite
race Linux pasada con exports. FuzzRewritePinned final: 19849 entradas en corrida
acotada (semillas/corpus local previos incluidos); no escaneo antivirus.

Doce packets sinteticos: 6 no-op, 3 sustituciones de ancho fijo (incluida region
opaca), crecimiento Unicode, reduccion y reflujo con delta cero. Python reconstruye
los bytes esperados sin importar Go y compara TODO el header y .uexp; segunda
lectura compara tablas/dependencias. Los seis casos del lector previo coinciden
tambien. Pruebas Go adicionales: orden de tablas distinto, sentinelas, marcadores
vacios, pins, indices, duplicados, limites, cancelacion en cada frontera, no alias,
inversa byte-exacta y todas las truncaciones del fixture basico.

Dos builds FINALES offline Go1.23.2 Windows/amd64 coinciden byte a byte. Hash y
comandos en CHECKS/evidence; UAsset-tests.exe NO es PMMFixLab.exe y NO se ejecuto.
Los primeros builds previos al endurecimiento del largo del pin no se presentan
como finales. Una llamada al verificador general no pudo operar sin .git: no se
conto como PASS. Se comprobo luego directamente cada uno de los 628 checksums,
cobertura de los 629 archivos y el subarbol Git del paquete.

## Conservacion y pendientes

No assets del juego/donante leidos o reparados; solo datos artificiales. No PMM,
FixLab original, Windows, PS, .NET, repak, Unreal ni antivirus ejecutados. PMM
permanece 1.5.0.1/s01b; arbol 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa.
Read/FORMAT originales, PMMDLT1/PAKV11, otros candidatos, snapshot, traducciones,
recetas/pins y workflows intactos. Un commit [skip ci]; sin release/tag/PR.

04A-4C abordara export payload/postProcess/core R1 con precondiciones verificables.
Generalizar la relocalizacion exige conocer las posiciones internas, no aceptar
un asset solo porque sus offsets de cabecera encajan. 04A completa/REL-01 y todos
los gates Windows/Unreal/Palworld siguen abiertos. 04B requiere motor completo.
