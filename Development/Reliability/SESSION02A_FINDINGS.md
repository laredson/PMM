# Tanda 02A - fuente candidata del Host conservada

Fecha: 2026-09-18. Rama: `v1.5.0.1-PMM-reliability`.
Entrada remota: `a0c74b8fe2210ba55b1c0eed47eb6c701e3de330`.
Arbol de entrada: `6e8ae56b487558d73e168ab371441118c20555b6`.

**CERRADA para fuente candidata, receta y evidencia. REL-01 sigue abierto.**
No se ha recuperado la fuente original ni certificado equivalencia funcional.

## Entrada y procedencia

El ZIP de cierre 01B se extrajo y su arbol completo, calculado como objetos Git,
coincidio con la rama remota. El paquete paso el verificador estatico: 629
archivos, 628 checksums, version 1.5.0.1 y build s01b. No se repitio la
investigacion de ramas historicas, porque no habia una pista nueva.

El original PMM.exe conserva SHA-256
`010c4f656dbe68f0bcf667610accf6cc4e248872120c6acd299f0fca7c209c2d`.
`go version -m` permite leer Go 1.23.2 sin ejecutarlo. Sus bytes contienen nombres
como monitorStartupSplash, parseStartupWindowHandle, setPMMAppUserModelID,
startupSplash.HandoffTo y el nombre de archivo splash_windows.go. Esos nombres
no son codigo recuperado ni demuestran la implementacion interna.

El bootstrap WPF existente publica `startup:UI-shell-ready:<HWND>` despues de
ContentRendered y trabajo en el dispatcher, o `startup:UI-ready` como fallback.
Ese es el contrato usado; UI-window-created no se trata como readiness.
La referencia historica de fuente 91e7531d... sigue sin asociarse a un original.

## Implementacion guardada

`Development/Reliability/NativeCandidates/Host/` contiene main.go, splash_state.go,
splash_windows.go y go.mod, mas tests, build.py, inspect_pe.py, README y evidencia.
Es una RECONSTRUCTION, aislada del snapshot y del programa distribuido.

La candidata incluye pasos de arranque, lectura acotada del estado de esta
sesion, parser HWND decimal, tarea Win32 en su propio hilo, cierre solicitado al
hilo propietario y handoff de primer plano antes de retirar el splash. Conserva
las rutas/supervision del snapshot; solo start abre el splash. Las llamadas al
sistema y su resultado visual no se han probado en Windows.

Los nuevos textos, geometria, temporizador y decisiones ante fallos son decisiones
de reconstruccion, no una reproduccion demostrada del splash historico. El
README enumera diferencias y riesgos pendientes, incluido el origen del HWND,
la seleccion de PowerShell, el timeout de seguridad y la invocacion Bypass
heredada. Este paso no introduce ni declara completado el hardening antivirus.

## Compilacion y comprobaciones reales

Se compilo con Go 1.23.2 para Windows/amd64, CGO=0, trimpath y subsistema GUI.
Se uso el inyector de iconos existente SOLO como helper de build del candidato;
no se ejecuto PMM, PowerShell, Runtime ni FixLab. La herramienta de build rechaza
escribir dentro del checkout y no modifica un directorio de salida existente.

Dos builds independientes en rutas de salida distintas produjeron un archivo
identico de 2577920 bytes, SHA-256
`62fc4b234ea145c6e3dadcc51366c0ebbca109f7b5a11dcb17deda32e927257f`.
Esto demuestra repetibilidad en ESTE entorno, no equivalencia con el original.
El `.text` del original y el de la candidata son diferentes.

Pasaron cinco tests Go del modelo puro de estados (16 subcasos del parser) y
nueve tests Python del inspector PE/guardas de salida. Los logs se conservan.
No son pruebas funcionales del Host en Windows. Los informes no contienen datos
de Workspace, credenciales ni rutas de usuario; comandos normalizados a OUT/REPO.

## Preservacion

Los 629 archivos de PMM/ permanecen byte-identicos a la entrada, incluidos los
cuatro metadatos de 01B. Por ello el build del PAQUETE sigue siendo s01b; S02A
identifica la candidata separada. La carpeta Development/Source/ tambien queda
intacta. No se cambian Runtime, FixLab, idiomas, CI ni la rama donante.

No se instala/firma/publica el candidato. No se hace escaneo ni subida de muestras.
La rama se actualiza con un unico commit [skip ci], sin abrir PR, tag o release.

## Continuidad

NEXT_SESSION.md fija 02B: comparar solo el Host y elaborar la lista de aceptacion
Windows sin exigir que una recompilacion parcial autorice reemplazar binarios.
Los .go, receta y reportes de este paso se guardan en Git, no solo en un temporal.
El EXE de build queda ademas en un ZIP de evidencia descargable, pero no se
incluye en el paquete de usuario ni en el repositorio. Se puede regenerar desde
el codigo conservado. No reutilizar afirmaciones de paridad de chats anteriores.
