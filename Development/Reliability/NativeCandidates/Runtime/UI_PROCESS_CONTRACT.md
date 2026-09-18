# Contrato Runtime -> UI, S03A

Revision estatica; NO evidencia de ejecucion Windows ni canal autenticado.
Fuentes: candidato y snapshot fijados; PMM/Engine/Runner/routes.json,
PMM/Resources/Metadata/runtime-contract.json y
PMM/Modules/Bootstrap/Start-PalModMerger.ps1. Esos archivos PMM no se modifican.

## Recorrido de procesos

| Ruta | Proceso que contiene la ventana | Evidencia / limite |
| --- | --- | --- |
| PMM.exe start -> Runtime start -> WPF | Hijo directo PowerShell del Runtime; nieto del Host | nativeui.go usa exec.Command y cmd.Run, no shell intermedia; pendiente observar Windows |
| ui-native / ui --native / shell de reserva | El propio proceso Runtime | native_shell_windows.go crea Win32 en hilo bloqueado |
| Boton Open current PMM interface de la shell nativa | Otro hijo directo PowerShell del mismo Runtime | Se lanza desde una goroutine; no existe registro exclusivo de una UI por sesion |

El PID que conoce Host al crear Runtime NO es el PID de WPF. Tampoco el nombre
powershell.exe, el titulo de la ventana o AppUserModelID prueban parentesco.
No se ha implementado en esta tanda un fichero de PID presentado como prueba.

## Arranque, seleccion y salida

- Sin argumentos Runtime ejecuta doctor --json, no start. Host usa la ruta start.
- start verifica/repara dependencias, luego llama launchUserInterface y al
  terminar comunica UI-closed-normally o UI-runtime-exit:<codigo>.
- runtimeSecurity se llama incluso con forceNative: se preserva el sondeo previo.
- WPF solo se elige si hay ruta de PowerShell y modo FullLanguage (sin distinguir
  mayusculas). Otros modos o salida vacia/ambigua eligen shell nativa.
- El selector heredado prefiere pwsh.exe en PATH; no garantiza PowerShell 5.1.
  PMM_HOST_POWERSHELL se hereda hacia WPF pero Runtime no lo usa como selector.
- WPF recibe argv separados: -STA, -NoProfile, -ExecutionPolicy, Bypass, -File,
  ruta a Modules/Bootstrap/Start-PalModMerger.ps1. Bypass es heredado, no eliminado.
- Env=nil conserva el entorno de Host: PMM_HOST_SESSION_ID, SESSION_DIR, ROOT y
  POWERSHELL. cmd.Dir=root; stdin/stdout/stderr son los ficheros del Runtime.
  Esto no es aislamiento del entorno ni validacion de sus valores.
- El root se determina en util.go: PMM_ROOT tiene prioridad; si el EXE esta en
  Engine se usa su padre. PMM_HOST_ROOT no controla ese algoritmo.
- cmd.Run espera al hijo directo; exito devuelve 0, ExitError propaga ExitCode,
  otro error o falta de PowerShell devuelve 30. No hay cancelacion explicita de
  toda una familia de procesos en este recorrido. No se ensayaron esos retornos
  con procesos Windows reales; solo la falta de shell se prueba sin lanzarla.

## Readiness existente

Runtime escribe state.txt solo si recibe PMM_HOST_SESSION_DIR. WPF escribe en el
mismo fichero con UTF-8 sin BOM y CRLF. Despues de ContentRendered y dispatcher
idle comunica startup:UI-shell-ready:<HWND decimal>; ante excepcion, UI-ready.
UI-window-created y UI-script-loading NO equivalen a lista para recibir foco.
WPF tambien intenta activar su ventana por su cuenta; el Host no es el unico
participante en la gestion de foreground. Debe observarse el conjunto en Windows.
Las escrituras WriteAllText/os.WriteFile no son IPC atomico ni autenticado y
algunos errores se descartan. Los writers pueden competir por el mismo fichero.

La shell Win32 del snapshot no publica UI-shell-ready/UI-ready. El flujo normal
WPF si lo hace, pero la reserva nativa necesita su propia revision con el splash.
No se atribuye esta falta al binario original por observarla en el snapshot.

## Contrato necesario para H02B-04 (propuesta, NO implementado)

Host debe conservar identidad y vida del Runtime que crea. Runtime debe registrar
al iniciar un hijo WPF SU PID real y un identificador de instancia/creacion,
mantener su vida controlada y transmitirlo al Host por un canal verificado,
vinculado a la sesion. Un JSON modificable o un nonce en disco no autentican
por si solos el emisor; no considerar resuelto el problema con otro archivo.

Antes de usar un HWND, verificar con el SO que pertenece al proceso UI vivo
registrado (o al Runtime vivo en ruta nativa), no a cualquier descendiente ni a
un PID reutilizado. Considerar GetWindowThreadProcessId y tiempos/handles de
proceso, acceso denegado, salida simultanea y reutilizacion. Volver a comprobar
antes de actuar; no existe una garantia atomica por consultar un HWND una vez.
Rechazo seguro: no activar una ventana ajena ni intentar forzar foreground.

La transicion Start -> registro -> Wait requiere resolver la carrera en la que
WPF publica ready antes de que Host conozca el hijo. Tambien deben definirse
reinicios y el boton de shell nativa, que actualmente puede abrir varias WPF.
03B fija requisitos/fixtures y 02C implementa el acuerdo con Host, por separado.

## Riesgos que bloquean promocion

| ID | Riesgo comprobado en fuente candidata | Entrega de resolucion |
| --- | --- | --- |
| R03A-01 | CombinedOutput del sondeo PS no tiene timeout; prioridad pwsh no acredita PS5.1 | 03B/02C |
| R03A-02 | Native shell sin readiness; varios hijos WPF pueden compartir state.txt | 03B/02C |
| R03A-03 | Origen HWND no autenticado; ninguna identidad de hijo llega al Host | H02B-04 / 02C |
| R03A-04 | start puede reparar/descargar antes de abrir UI; incluye eliminacion Oodle y reemplazos no transaccionales | 06/07; no ejecutado ni redisenado aqui |
| R03A-05 | process.run captura salida en buffers sin limite; timeout mata el hijo directo, no garantiza cerrar descendientes | 03B/08; coordinar H02B-06 |
| R03A-06 | Deteccion de root/env, errores de estado ignorados y closure parcial requieren prueba | 03B/05 |

Esto NO afirma bugs en el original ni que el candidato tenga menos detecciones AV.
No ejecutar start para verificar hashes: puede mutar Workspace/dependencias.

## Referencias primarias consultadas (2026-09-18)

- https://pkg.go.dev/os/exec : Env, Dir, Run/Start/Wait y CommandContext.
- https://learn.microsoft.com/en-us/windows/win32/procthread/process-creation-flags : CREATE_NO_WINDOW.
- https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/ns-processthreadsapi-startupinfow : wShowWindow/STARTF_USESHOWWINDOW.
- https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowthreadprocessid : PID del propietario de la ventana.
- https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes : identidad temporal del proceso.

La documentacion actual no sustituye el contraste con Go1.23.2 instalado ni la
aceptacion Windows. Los valores de presentacion se compilan, no se ejecutan aqui.
