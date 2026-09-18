# 04A-5A - planificador y requisitos core R1

Fecha: 2026-09-18. Rama: v1.5.0.1-PMM-reliability.
Entrada 4d8b0ca142dc55fbf066b1a18fac1658dfd6b87b,
arbol bc26b473f020d3fe56fd811f9cb8b758f0c139d1.
CERRADA solo en planificador puro y expediente declarativo. No executor core R1,
motor completo, source original recuperado ni permiso para sustituir binarios.

## Fuente y alcance

HEAD, AGENTS, NEXT_SESSION y receta core R1 se leyeron por el conector GitHub.
El ZIP 03B aporta solo PMM/.github/Development/Source, recalculados como arboles
Git y concordantes con los IDs de esta linea. Los ZIPs 04A..04A4C se verificaron
por SHA-256 para leer contratos recientes. No son un checkout completo de HEAD.
La publicacion aplica solo las rutas de esta tanda sobre el arbol remoto actual.
No se repitio investigacion del overlay corrupto ni reconstruccion anterior.

## Implementacion

CoreR1/PlanCore recibe receta, dos inventarios y claims opcionales como JSON
pinneado. Comprueba identidad de documentos, forma estricta, rutas, un donante
permitido alternativo, build actual exacto, familias, grupos/minimos, fuentes de
nombres, soporte/exclusiones y colisiones/outputs prohibidos. Devuelve metadata
ordenada y requisitos. No lee los archivos declarados, transforma ni escribe.

PLAN_VALID es validez del plan sobre DECLARACIONES. Los hashes por archivo son
expectativas del inventario, no calculos sobre assets. InputBytesVerified,
TransformReady, BuildReady, Validated e Installed siempre false en esta version.
No existe opcion para convertir un claim o una lista de rutas en autorizacion.
Los schemas faltantes NO invalidan una seleccion coherente: quedan bloqueantes.

El expediente PMM_R1_SCHEMA_PROVENANCE_V1 vincula receta, header/export donantes,
proveedor actual, clase/perfil y origen/revision, con referencias hash a schema
layout/review. Se comprueba la vinculacion pero NO se leen esos dos documentos.
Queda DECLARED_UNVERIFIED; un 'approved:true' no pertenece al formato. No confundir
identidad de JSON con autenticidad, layout correcto o evidencia de codigo cargado.

Soporte mantiene fronteras de directorio y exclusiones. Familias parciales y
conflicto explicit/exclusion se rechazan. Sidecars bulk se enumeran con requisito
UNSUPPORTED, no se ignoran ni transforman. Los minimos son obligatorios y el
baseline es orientativo: mas destinos no se descartan para igualar el baseline.
Regex target usa coincidencia total; no se renombra ni normaliza nada del paquete.

## Verificaciones realizadas

30 funciones Test Go con aserciones, incluidas dos opt-in: export de cuatro planes
artificiales y lectura de receta productiva con inventarios SIMULADOS. 10 tests
Python (cinco de filesystem/build y cinco del oracle sobre export) con opt-in.
Race Linux PASS; vet Windows/amd64 PASS. FuzzPinnedRecipe: 173539 entradas en
corrida acotada de 8 segundos solicitados. No es escaneo AV ni ejecucion Windows.

La prueba de receta productiva enumera 93 targets ficticios que cumplen sus reglas
(30 cuerpo, 26 cabeza, 37 pelo), cuatro fuentes de nombres y 190 outputs previstos
con cuatro ficheros de soporte artificial. Prueba ambas firmas como alternativas
DECLARADAS; no usa ningun byte de los PAK donantes ni comprueba que existan.
El resultado permanece PLAN_VALID/TransformReady=false. No aceptar esta prueba
como reparacion de Gura ni como verificacion del contenido de un donante real.

Cuatro escenarios pequenos se contrastaron en Python contra un listado manual
independiente: 3 tareas cada uno, 10/10/12/10 outputs. Se verifican identidades JSON,
rutas, soporte, exclusiones y bloqueos. No es otro planificador general ni un
oracle de Unreal. Se probaron tambien errores de pins/JSON/rutas, minima, ambiguedad,
claims cruzados, limites, cancelacion en cada frontera y ausencia de mutacion.

Dos builds offline Go1.23.2 del TEST Windows coinciden byte por byte:
d6aa9bed438be03e9856cd85f30cf9eb842817301337e7980368c39463957efa.
No se compilo motor FixLab. CoreR1-tests.exe NO es una actualizacion instalable.

## Conservacion y continuidad

629 archivos PMM/628 checksums correctos, cero discrepancias, version 1.5.0.1,
build PMM-v1.5.0.1-reliability-s01b; subarbol Git
09df5c45aee3390c6b8ea235c8afa4e149a9f1fa. No modificaciones a UAsset/PMMDLT1/PAKV11,
Host/Runtime/UIBridge/Supervision, fuentes historicos, recetas, traducciones o CI.
No originales, Windows, juego, reparaciones, antivirus ni bootstrap ejecutados.
Commit [skip ci]; sin Actions, PR, tag, release ni binarios en Git.

Siguiente 04A-5B: captura/verificacion de entradas y expediente de schemas antes
del executor. El planificador no resuelve el schema real ni relocalizacion opaca.
Adquirir snapshots y evidencia local verificable, conservando distincion entre
bytes comprobados, procedencia declarada y layout validado. No implementar una
CLI build de relleno. Gates Windows y REL-01 siguen abiertos.
