# UIBridge Windows acceptance - all NOT_RUN

Includes the 02C-2A adapters and the 02C-2B candidate integration. All Windows
results remain NOT_RUN; none are inferred from compilation, Linux race tests or
the user's successful launch of the unchanged application. Use only an expressly
authorized disposable test copy, never the working installation.

The opt-in tests in pipe_windows_test.go are scaffolding, not evidence of passing.
They exercise a deliberately spawned child TEST executable, not PowerShell/PMM.
Run only in an explicitly authorized Windows test session. No CI workflow added.

| ID | Case / required evidence | Status |
| --- | --- | --- |
| IPC-01 | Live controlled direct child connects; both peer IDs match retained process identities | NOT_RUN |
| IPC-02 | Another process or wrong creation time cannot authenticate; no window action | NOT_RUN |
| IPC-03 | Another logon/remote client denied; inspect DACL, no inherited server handle | NOT_RUN |
| IPC-04 | Name collision/second server instance fails; never attach to an existing foreign endpoint | NOT_RUN |
| IPC-05 | Header/body stalls, abrupt disconnect and short reads revoke coordination within requested bounds | NOT_RUN |
| IPC-06 | Cancel overlapped connect/read/write; caller returns, Done eventually closes, no freed pending buffers | NOT_RUN |
| IPC-07 | Controlled WPF-like child and native Runtime owner verified by handle/time/parent, not names | NOT_RUN |
| IPC-08 | Foreign HWND, destroyed HWND and recycled PID rejected; access denied stays fail-closed | NOT_RUN |
| IPC-09 | Gate cannot focus before ACK, after EXIT/FAILED/CLOSE or after pipe revocation | NOT_RUN |
| IPC-10 | Same-process HWND reuse and exit between last validation and foreground action characterized honestly | NOT_RUN |
| IPC-11 | Real integration: early ready, fresh per-generation state, repeated WPF button and native -> WPF | NOT_RUN |
| IPC-12 | Real integration: idle/slow startup heartbeat, user changes foreground, optional coordination failure | NOT_RUN |

Three top-level Windows adapter tests plus one child dispatcher are supplied.
They cover parts of IPC-01/02/05/06; this table is NOT fully automated. In the
Windows session use Go1.23.2 and explicit PMM_UIBRIDGE_WINDOWS_TESTS=1, then
`go test -count=1 -timeout=30s -run '^TestWindows' .` within the UIBridge folder.
Unset the variable afterwards. Collect exit status, exact source/executable
hashes and actual results; a skipped test is not PASS. The child-dispatcher env
must not be set manually. Do not run test executables received from unverified
sources, and do not remove OS security protections to obtain a passing result.

Host and Runtime acceptance tables remain applicable after wiring. A failure or
inability to run a Windows case does not become success because the library
model accepted an analogous fake-process fixture.

## Integracion C2B - casos adicionales, todos NOT_RUN

Usar SOLO copia desechable con candidatas exactas y permiso expreso. No utilizar
la instalacion de trabajo ni interpretar este listado como ejecucion autorizada.
Hashes/gates del paquete y otros bloqueos deben revisarse antes de ese ensayo.

| ID | Caso | Evidencia requerida | Estado |
| --- | --- | --- | --- |
| UI2B-01 | Host -> Runtime -> WPF normal | PIDs/creacion obtenidos por SO, REGISTER_ACK antes de READY, una accion respetando foreground | NOT_RUN |
| UI2B-02 | Inicio largo antes de UI | Heartbeat durante dependencias/sondeo; no timeout falso de pipe; sin llamadas de reparacion no autorizadas | NOT_RUN |
| UI2B-03 | Native ready y boton WPF repetido | HWND nativo real; EXIT native; nueva generacion; exactamente una WPF hija | NOT_RUN |
| UI2B-04 | Fallo de pipe/captura/ACK/directorio | UI util sin coordinacion; cero fallback de HWND desde archivo; diagnostico | NOT_RUN |
| UI2B-05 | WPF termina antes de registro/ready y cierre simultaneo | Capture antes de Wait; ninguna activacion despues de salida observada; handles/canal liberados | NOT_RUN |
| UI2B-06 | Estado parcial/antiguo/ventana de otro proceso | Registros rechazados; carpeta nueva; owner ajeno nunca activado | NOT_RUN |
| UI2B-07 | Inspeccion de entorno de hijos | Locators solo Host -> Runtime; ausentes en sondeos/herramientas/WPF; Runtime conserva HostSession propia | NOT_RUN |
| UI2B-08 | Cambiar a otra app durante carga, DPI, idioma | No robar foco; WPF sigue usable; splash WPF desaparece incluso sin READY tras plazo; activacion propia WPF evaluada aparte | NOT_RUN |

La perdida de coordinacion solo retira el foco del Host. No termina familias,
no controla la activacion que el script WPF ya hacia y no garantiza atomicidad
contra reciclado de HWND en el mismo proceso. Conservar logs con hashes de ambos
candidatos y registrar NOT_RUN/BLOCKED, nunca PASS por lectura de fuentes.
