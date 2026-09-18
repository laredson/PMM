# Tanda 02B - comparacion del Host y gate de aceptacion

Fecha: 2026-09-18. Rama exclusiva: v1.5.0.1-PMM-reliability.
Entrada: baa063933c8940a7654d3350f728a81ed967f92c.
Arbol de entrada: a634d69b64b02ef54247311e2d11615a90fab690.

**CERRADA en su alcance: comparacion reproducible, correcciones acotadas de la
candidata y criterios de aceptacion. NO equivalencia ni permiso de sustitucion.**
El paquete PMM y su build s01b permanecen intactos. REL-01 sigue abierto.

## Evidencia de entrada y metodo

El ZIP de cierre 02A coincide con su SHA-256 publicado y reproduce el arbol Git
remoto completo (1003 archivos). La reconstruccion S02A se volvio a compilar con
Go 1.23.2; su SHA-256 coincide con el candidato archivado. No se repitio la busqueda
historica de fuentes y no se recupero el original del splash.

compare_host.py compila un lector nativo de metadatos, tools/hostmeta.go, que lee
PE, debug/buildinfo y la tabla Go pclntab. El lector NO ejecuta el EXE inspeccionado.
Las funciones listadas son entradas de esa tabla con rangos dentro de .text, no
solo strings encontrados. No se decompilo todo el programa ni se demostro su
semantica a partir de nombres. Los limites del metodo se guardan en comparison.json.

| Artefacto | SHA-256 | Bytes | Funciones main.* (incluye wrappers) |
| --- | --- | --- | --- |
| Original | 010c4f656dbe68f0bcf667610accf6cc4e248872120c6acd299f0fca7c209c2d | 2567168 | 42 |
| S02A reproducido | 62fc4b234ea145c6e3dadcc51366c0ebbca109f7b5a11dcb17deda32e927257f | 2577920 | 56 |
| S02B corregido | a5f50c5677608c9875eefb65fe75fd7efb3460808be2f53df7ea3ec6db195d97 | 2579456 | 56 |

Los tres son AMD64, subsistema GUI=2, Go1.23.2 y mismo module path/settings
registrados. La tabla de certificados tiene tamano cero; no es una validacion de
cadena Authenticode ni un veredicto antivirus. Original y S02B NO son identicos.
Solo .symtab coincide en bytes crudos; las otras secciones difieren, incluida
.rsrc (los recursos pueden contener direcciones dependientes del layout).
Se conserva el mismo ICO verificado. No inferir semantica ni nivel de seguridad
por el numero de funciones, tamano del archivo o diferencias de relocacion.

## Comparacion de contratos

La tabla separa contrato del snapshot/candidata, observacion binaria y ejecucion.
El snapshot sigue sin ser una prueba de lo que hace exactamente el original.

| Area | Fuente candidata / contrato revisado | Original: evidencia y limite |
| --- | --- | --- |
| CLI | Sin argumentos -> start. doctor [--json], security status [--json], handoff create [--reason], y operaciones encaminadas por routes.json | Tabla confirma main, doctor, securityStatus, createHandoff y resolveChild; resultados CLI NO ejecutados |
| Rutas | start y cuatro runtime-* van a Runtime por routes.json; otras operaciones usan Runner. Args se pasan por argv. El fallback Bypass se conserva, no se declara endurecido | Manifiesto/rutas presentes; rutas efectivas y argumentos del EXE NO certificados |
| Sesion | PMM_HOST_SESSION_ID, DIR, ROOT y POWERSHELL, cwd de la app; estado en Workspace/State/HostSessions/<id>/state.txt | Nombres/contrato y funciones newHost/writeSummary presentes; contenido real por ejecucion pendiente |
| Salidas | 250 fallo inicial; 12 doctor sin runtime/rutas; 20 dispatch; 22 Start; 23 error Wait no ExitError; exit del hijo propagado | No afirmar igualdad de codigos con original solo por el snapshot; gate H05-02/03 |
| PowerShell | Se sondea LanguageMode ANTES de resolver la ruta nativa; findPowerShell prefiere pwsh. La UI completa sigue por PowerShell/WPF | La ruta nativa no demuestra arranque sin PowerShell. Seleccion/sondeo son riesgo a revisar en 02C/03 |
| Logs/handoff | JSON de sesion, stdout/stderr, clasificacion de fallos y ZIP diagnostico. Mantiene codigo heredado del snapshot | Existen funciones correspondientes en pclntab; integridad de logs/ZIP al fallar o disco lleno no verificada |
| Readiness | WPF publica LF/CRLF, UI-shell-ready:<decimal> tras dispatcher/ContentRendered, UI-ready de respaldo; UI-window-created no es ready | Se leyo el escritor WPF real; no se observo el original ejecutando la secuencia |
| Cierre/foco | Cierre del splash no cancela al hijo; handoff best-effort, no fuerza foreground. S02B prioriza cierre observado sobre ready | HandoffTo/monitor/splash presentes en original, pero no se certifica el mismo algoritmo |

## Hallazgos y correcciones dentro de la candidata

H02B-01, ALTA: el lector aceptaba un prefijo numerico durante WriteAllText (p.ej.
:4 antes de terminar :42). Ahora exige un unico registro terminado en LF/CRLF,
rechaza varios registros, NUL y mas de 64 KiB. Esto reduce lecturas parciales;
NO convierte el archivo local en IPC atomico ni autenticado.

H02B-02, ALTA: el timer atendia Ready antes de stop y el modelo ignoraba un
cierre/fallo posterior a Ready. Ahora close/failure invalidan el HWND guardado,
stop gana si se observa en el mismo tick y se detiene el monitor al retornar
Wait, antes de esperar el drenaje de logs. No se afirma ausencia de todas las
carreras Win32: falta ejecutar el cierre simultaneo y la destruccion del HWND.

H02B-03, MEDIA: ShowWindowAsync(SW_SHOW) ocurria antes de comprobar si el usuario
habia dejado el splash. La comprobacion de foreground ahora precede tambien a
esa accion, no solo a SetForegroundWindow. Las restricciones y carreras del SO
siguen vigentes; no se fuerza el foco ni se simulan teclas.

Las correcciones solo afectan main.go, splash_state.go y splash_windows.go de
NativeCandidates/Host. Se amplian pruebas del modelo y se identifica la receta
como S02B. evidence/s02b/from-s02a.patch conserva el delta exacto. Los informes
02A son historicos: no se reescriben para parecer resultados de S02B.

## Bloqueos que la comparacion deja abiertos antes de promocionar el Host

H02B-04, ALTA: IsWindow no acredita quien creo la ventana; el archivo es
modificable por el usuario y los HWND se reciclan. Falta una validacion de origen
vinculada al proceso supervisado y a su UI (posiblemente descendiente de Runtime)
y una politica de rechazo que no active ventanas ajenas. No se improvisa esa
cadena antes de comparar Runtime. H05-05 debe fallar cerrado. Bloquea promocion.

H02B-05, ALTA: securityStatus usa CombinedOutput sin timeout y prefiere pwsh.
Un sondeo bloqueado puede detener el inicio; pwsh no demuestra compatibilidad
con la UI PS5.1. Heredado del snapshot/candidata, no demostrado en el original.
Resolver en una tanda acotada de supervision 02C coordinada con 03.

H02B-06, ALTA: el snapshot/candidata usa StdoutPipe/StderrPipe y Wait antes de
terminar lectores; Scanner tiene limite 4 MiB y no informa Err. Puede perderse
salida o bloquear un hijo productor. No se cambia toda la supervision en esta
comparacion. 02C debe disenar drenaje limitado/cancelable, manejo de errores y
pruebas con un stub (no modificar juego ni confundirlo con paridad Windows).

H02B-07, MEDIA: cierre del splash no es cancelacion; Close puede esperar 2s por
llamada, hay textos ingleses nuevos y no hay comparacion visual/DPI. Ademas el
empaquetado heredado de diagnosticos ignora algunos errores de escritura/cierre.
Verificar estos casos antes de release y no publicar una candidata sin etiquetas
de idioma o diagnosticos honestos. No son bugs demostrados del original.

## Comprobaciones realizadas y pendientes

- S02A regenerado con el mismo hash del archivo conservado.
- Dos builds S02B en salidas distintas, byte-identicos en Linux/amd64 Go1.23.2.
- Nueve funciones de tests Go del modelo, con los 16 subcasos HWND previos,
  framing (9 casos), terminalidad (4), prioridad de stop y salidas incompletas.
- Trece tests Python (9 anteriores + 4 del comparador); logs guardados.
- Comparacion estatica de tres EXE, sin ejecutarlos; identidad del paquete valida:
  629 archivos / 628 checksums / cero discrepancias / build s01b conservado.
- No se ejecutaron PMM, candidato Windows, Runtime, FixLab, WPF o antivirus.
  Los unicos binarios auxiliares ejecutados fueron lectores/herramientas de build
  locales; no se hicieron descargas, instalaciones ni envios de muestras.

## Referencias primarias y consecuencia practica

https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-iswindow
La existencia de un HWND no autentica su origen y puede cambiar tras la consulta.
https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setforegroundwindow
Windows puede denegar foreground; no usar trucos para forzarlo.
https://pkg.go.dev/os/exec
StdoutPipe/StderrPipe requieren terminar las lecturas antes de Wait; el codigo
heredado de la candidata requiere revision especifica, no ocultar la perdida de logs.

## Continuidad

03A es la siguiente tanda: SOLO candidato Runtime y evidencia reproducible,
aislados del paquete. Despues 02C resuelve los bloqueos del Host/contrato con UI;
04 trata FixLab y 05 ejecuta la aceptacion real autorizada en Windows.
WINDOWS_HOST_ACCEPTANCE.md define las pruebas y evidencia necesaria. Ningun
PASS estatico o de fixtures autoriza instalar el candidato.
