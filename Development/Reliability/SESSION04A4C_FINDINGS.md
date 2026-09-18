# 04A-4C - contenido de exports: postProcess con precondiciones

Fecha 2026-09-18. Entrada 7b0a030ec3f5dd38249a6c47582d8f8c72cd1900,
arbol 0f1043c8924000afc9bebb8f41f812d60229878d. Rama reliability exclusiva.

CERRADA solo en el componente PatchPostProcess con esquema escalar externo.
El core R1 COMPLETO, relocalizacion de meshes reales y motor FixLab siguen pendientes.
No source original recuperado ni compatibilidad Unreal/Windows/Palworld demostrada.

## Evidencia y decision de alcance

Se fijaron HEAD/AGENTS/NEXT_SESSION y se releyo la receta core R1 de GitHub.
Sus bytes locales coinciden con blob b5ae925ba9b955177bf4d52084d6b2ed4b9039c2,
SHA-256 3f08c8da1dbc799b0c47a8a00d88819280e14ad7e21dce9f0622c7974a0c4f9c.
Los fuentes UAsset actuales proceden de ZIP 04A4B verificado y sus hashes de
entrega; PMM/.github/snapshot del ZIP anterior se compararon por subarbol Git.
No se usa un checkout viejo como autoridad de todas las candidatas remotas.

Los cuatro rangos estaticos conservados se volvieron a comprobar contra el EXE
original fijado. En patchPostProcess hay DOS operaciones distintas: el import
safe se escribe en una entrada de header, y se escribe NULO en las referencias
serializadas aprobadas. El contrato de precarga concuerda con ese recorrido.
No se ejecuto el original. No hay recuperacion de codigo a partir de esos nombres.

FFragment/FUnversionedHeader/NormalExport/ObjectPropertyData de UAssetAPI se
leyeron como referencia al commit 3228c1e. Epic documenta el tipo de la propiedad
y la existencia de offsets de bulkdata, no el layout de un mesh particular.
Por ello se decidio NO habilitar relocalizacion opaca ni escribir a ciegas en 120.

## Implementacion nueva

fixed_properties.go interpreta el prefijo unversioned bajo un esquema JSON
externo fijado por SHA-256: fragmentos, skips, zero mask, campos escalares y sus
rangos. Calcula la posicion; el offset esperado solo comprueba ese resultado.
El esquema requiere clase SkeletalMesh, lista ordenada aplanada, nombres unicos
y tipos soportados. No hay .usmap reader ni autodeteccion por bytes. JSON ambiguo,
arrays/structs/custom serializers o campos no demostrados se rechazan.

postprocess.go toma snapshots .uasset/.uexp con pins, valida nombre/clase/export,
resuelve imports por ruta/Outer/clase y exige un unico stale en precarga, propiedad
de ese export y grupo. Cambia SOLO cuatro bytes de precarga stale->safe y cuatro
de ClassProperty stale->0. Nombres, longitudes, offsets, otras propiedades y bytes
opacos se mantienen exactamente. Una coincidencia stale en native tail no se
busca/reemplaza globalmente: diferencia deliberada frente a la busqueda historica.

Se releen estructura/prefijo y se exigen dos hashes de resultado proporcionados
externamente. Errores/cancelacion devuelven nil. No-op/replay no se autoacepta.
La fuente no hace I/O de archivos, procesos, juego, red ni instalacion.

## Limite que no debe ocultarse

Un esquema fijado por hash NO se autentica por eso ni se vuelve correcto para un
mesh. Su procedencia, completitud y correspondencia son responsabilidad del caller.
Los esquemas probados son SINTETICOS. La receta actual no aporta ese esquema ni
los pins por familia. No se puede procesar Gura real automaticamente con esta pieza.
Schemas reales con serializers complejos siguen UNSUPPORTED. No simplificarlos
artificialmente a escalares ni generar pins de resultados para silenciar un error.
RewriteNames y su rechazo de movimientos con payload opaco siguen intactos.

## Comprobaciones ejecutadas

56 tests Go: 39 previos +17 nuevos, con tres exports opt-in activados. 31 tests
Python: 20 previos +11 nuevos. Race Linux PASS. FuzzFixedPostProcess final:
190277 entradas en 10 segundos; prueba de parser/transformacion, no antivirus.
Las 7 fixtures nuevas se compararon byte a byte por Python independiente, incluidas
mask, skips, tipos mixtos, Unicode, regiones opacas y coincidencia no objetivo.
Las 6 lecturas y 12 reescrituras anteriores se verificaron nuevamente.

Se prueban pins obligatorios, offset en coordenadas correctas, identidad completa,
precarga compartida/duplicada, schema invalido, zero masks 1..1024 campos, todas
las truncaciones de la fixture, cancelacion en cada frontera y no alias/mutacion.
Las fixtures almacenadas compactamente contienen solo bytes artificiales; su
hash decodificado se verifica en tests. No se redistribuyen datos de juego/donante.

Dos builds finales TEST Windows/amd64 Go1.23.2 son byte-identicos:
c6cb6cd0d2ac37005fb07f62648d34f88c63e3dad7711e8c3e17a0287660a361 (5878272 bytes).
Go vet Windows correcto. Harness NO ejecutado en Windows y NO es PMMFixLab.exe.
Los builds intermedios no se usan como evidencia final. No original/PMM/PS/.NET/
repak/Unreal/Palworld/antivirus ni reparaciones reales ejecutadas.

## Conservacion y continuidad

629 archivos / 628 checksums / cero discrepancias; PMM 1.5.0.1 y build s01b.
Subarbol 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa; .github/snapshot intactos.
Sin cambios en Read, RewriteNames, PMMDLT1, PAKV11, Host/Runtime/UIBridge/Supervision,
recetas o traducciones. Registros anteriores conservados. Un commit [skip ci],
sin workflows, PR, tag o release ni sustitucion de ejecutables.

Siguiente 04A-5A: requisitos/planificador core R1 y procedencia de schemas. No CLI
ficticia. Deberan distinguirse planificable, transformable, validado e instalado;
los requisitos no satisfechos deben quedar bloqueados. 04B requiere motor completo.
