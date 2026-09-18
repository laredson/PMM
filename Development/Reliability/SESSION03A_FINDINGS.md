# Tanda 03A - candidata Runtime y contrato UI conservados

Fecha: 2026-09-18. Rama: v1.5.0.1-PMM-reliability.
Entrada: f52101800b92b696b0600bb3382f89292a926cc8.
Arbol de entrada: 183cc346b14ca543d79059a0d74a18cd92453818.

**CERRADA para fuente candidata, build, evidencia basica y mapa UI.**
REL-01 sigue abierto; no se certifica equivalencia ni se instala la candidata.

## Entrada verificada

El ZIP de cierre 02B paso su SHA-256 y reprodujo el arbol Git remoto completo.
El original PMM/Engine/PMMRuntime.exe coincide con su pin
`e90341d8449b485cb04af3c00d357bc8c67e87070644ff6bf7d27121a00c422a`.
No se repitieron busquedas historicas sin pistas ni se uso como evidencia la
reconstruccion no conservada de chats anteriores.

Se leyeron main.go, nativeui.go, process*.go, doctor.go, util.go, contrato runtime,
rutas y el escritor WPF real. La candidata se basa en el snapshot 1.2.1 y el
contrato observable en archivos; NO se ha recuperado la fuente original.

## Implementacion acotada

`NativeCandidates/Runtime/` conserva los 18 .go del snapshot y go.mod, mas dos
.go nuevos, receta build.py, inspector PE, lector Go y pruebas. De los 19 archivos
originales copiados, 16 permanecen identicos (incluido go.mod); cambian solamente
nativeui.go y process_windows.go/process_other.go. No se copian wrappers de build
antiguos que pudieran apuntar al snapshot o al paquete.

La candidata separa decisiones de ruta/argv/presentacion en un modelo comprobable.
`legacyUICommand` construye el hijo sin iniciarlo. La configuracion WPF conserva
CREATE_NO_WINDOW pero no HideWindow/SW_HIDE, conforme al contrato distribuido.
Las utilidades CLI conservan la configuracion heredada. Es reconstruccion del
contrato; no se ha demostrado el efecto visual en Windows.

Se conservan start, diagnosticos, codigos de salida, root, entorno/streams,
seleccion/sondeo PowerShell, dependencias, shell nativa y version de componente.
La version del componente sigue 1.2.1; no se sustituye por la version de producto.
No se afirma que el snapshot sea equivalente al Runtime original.

## Resultado real

| Entrada/salida | SHA-256 | Bytes |
| --- | --- | --- |
| Runtime original | e90341d8449b485cb04af3c00d357bc8c67e87070644ff6bf7d27121a00c422a | 6365184 |
| Candidata S03A | 10effcaf7a5d02836104a5bb2bd90eeb52c755ac78fc4670b5eea11b235b938f | 6366208 |

Dos builds finales, en directorios distintos, fueron byte-identicos en
Linux/amd64 Go1.23.2, destino Windows/amd64 y subsistema consola 3. Se usaron
GOTOOLCHAIN=local, GOPROXY=off, GOSUMDB=off y buildvcs=false. No se descargaron
herramientas/dependencias para construir, ni se ejecuto el EXE resultante.
El helper de iconos existente y el lector PE/Go son herramientas locales de build.

13 funciones de test Go pasaron: 7 heredadas de rutas/archivos/ZIP y 6 de modelo
UI/construccion/entorno/estado, con 9 subcasos de seleccion. Nueve tests Python
del inspector/guardas de salida tambien pasaron. Solo fixtures y temporales;
no son pruebas de PowerShell, WPF, cancelacion Windows ni del juego.

La comparacion basica registra Go1.23.2 en ambos, las mismas opciones embebidas,
80 funciones main.* en original y 81 en candidata (anadida legacyUICommand).
Las tablas de funciones no recuperan codigo ni demuestran semantica. Coinciden
.xdata/.idata/.symtab/.rsrc crudas; difieren .text y otras secciones. No hay
identidad binaria total ni paridad funcional declarada. Certificado PE de tamano
cero en ambos; no se hizo validacion Authenticode ni un veredicto antivirus.

## Contrato y trabajo pendiente

`UI_PROCESS_CONTRACT.md` separa evidencia de fuente y propuesta de identificacion.
WPF es hijo directo del Runtime en el recorrido candidato normal; la shell nativa
vive en el Runtime. Host conoce el PID de Runtime, no el de WPF. El fichero de
estado compartido no autentica HWND ni procesos. El boton de shell nativa puede
abrir mas WPF y no existe un registro exclusivo de instancia.

Se registran R03A-01..06: sondeo PS sin timeout y preferencia pwsh, ausencia de
readiness en shell nativa, origen HWND no autenticado, reparacion de red durante
arranque, buffers/cancelacion de procesos y root/errores de estado. No se han
redisenado estas piezas ni ejecutado reparaciones para probarlas. No atribuir
estos hallazgos del snapshot/candidata al binario original sin evidencia.

03B comparara contratos y fijara el gate de Runtime. 02C abordara despues el
acuerdo Host/UI, origen HWND, sondeo y drenaje. 05 corresponde a aceptacion Windows.
No sustituir el original solo porque compila o repite el hash de la candidata.

## Preservacion y continuidad

Los 629 archivos PMM/ siguen identicos: 628 checksums correctos, 1.5.0.1 y build
PMM-v1.5.0.1-reliability-s01b. Host candidato S02B, snapshot Development/Source/,
FixLab, idiomas y workflows no cambian. No se publica Oodle local ni Workspace.

Codigo, receta, hashes, diff y resultados quedan en Git. Los informes PE/pclntab
completos y el EXE candidato se conservan adicionalmente en el ZIP de evidencia;
la receta permite regenerarlos sin depender de temporales de esta conversacion.
El ZIP completo de repositorio no contiene la candidata EXE ni .git/Workspace.
Un commit [skip ci], sin PR/tag/release ni workflows solicitados.
