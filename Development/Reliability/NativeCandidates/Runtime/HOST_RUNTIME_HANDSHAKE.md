# Acuerdo de instancia UI para 02C - especificacion S03B

Estado: PROPUESTO, NO conectado al Host/Runtime/WPF. Ninguna prueba de IPC Windows
se ha ejecutado. El modelo describe requisitos, no un canal ya autenticado.

## Limite de confianza

Se busca evitar foco en una ventana ajena, mensajes de otra sesion y reutilizacion
de PID/HWND. Se confia en el Host y Runtime lanzados desde codigo/artefactos
verificados y en el SO. No se promete aislamiento frente a administrador/kernel,
inyeccion en esos procesos o duplicacion de sus handles por un atacante con acceso
suficiente. Un archivo o un secreto en disco accesible al mismo usuario no crea
esa frontera. No hay servicio elevado, cambio de politica ni exclusion antivirus.

## Canal Host <-> Runtime (decision propuesta)

- Host crea antes de lanzar Runtime una named pipe LOCAL, con DACL explicita para
  el logon pertinente, PIPE_REJECT_REMOTE_CLIENTS y FILE_FLAG_FIRST_PIPE_INSTANCE.
  Nombre unico evita colisiones, NO autentica. Una colision falla sin usar otra
  pipe ya existente. Acceso minimo; no heredar el handle de servidor a otros hijos.
- Host conserva el handle/identidad de Runtime desde Start, con PID, tiempo de
  creacion y observacion de salida. GetNamedPipeClientProcessId debe corresponder
  al Runtime vivo conocido, no a un PID contenido en el mensaje ni a su nombre.
- Runtime contrasta GetNamedPipeServerProcessId con el Host esperado y su identidad
  temporal. Un SID comun o AppUserModelID no bastan. No validar por titulo de UI.
- Lectura/escritura/cancelacion acotadas; propuesta inicial: handshake 5 segundos,
  mensajes de hasta 4096 bytes con longitud explicita, sin comandos ejecutables.
  Timeout/EOF/acceso denegado invalidan la capacidad de dar foco, no autorizan
  eludir controles. El programa debe explicar que no pudo coordinar el splash.
- Version del protocolo y sesion fijadas al handshake. Enteros de identidad/FILETIME
  en decimal como strings, sin float; secuencia monotona. Rechazar duplicados,
  campos desconocidos, tipos incorrectos, overflow y mensajes fuera de estado.
  Son requisitos pendientes de parser/implementacion, no de los JSON actuales.

## Identidad y ciclo de UI

Clave de instancia: (sesion, RuntimePID, RuntimeCreationTime, generation).
Propietario: (UIPID, UICreationTime, ruta native/WPF). Una generation nunca se
reutiliza. Host/Runtime deben mantener handles abiertos y comprobar vida, no
hacer un lookup nuevo por PID y confiar en que sea el mismo proceso.

1. En ruta nativa, owner es Runtime. En WPF, Runtime captura el PID/handle del
   hijo DIRECTO creado por Start; no acepta un PID enviado por state.txt.
2. Runtime envia REGISTER con esos datos. Host abre/valida la instancia indicada
   frente al Runtime autenticado, guarda su handle y contesta REGISTER_ACK.
3. READY solo puede habilitar handoff tras ACK y comprobar, con el SO, que el
   HWND pertenece a esa UI viva. GetWindowThreadProcessId se compara con UIPID;
   GetProcessTimes y el handle retenido desambiguan reutilizacion. Revalidar
   inmediatamente antes de actuar; los HWND no son referencias atomicas eternas.
4. No forzar foreground: si el usuario esta en otra aplicacion o Windows deniega
   foco, dejar la ventana accesible normalmente y no simular teclas/clics.
5. EXIT/CLOSE/FAILED o salida observada por handle gana sobre READY. Descartar
   pendientes, cerrar handles/canal y retirar registro; no activar despues de cierre.

state.txt sigue siendo un indicio de progreso/renderizado, no identidad. Para
no mezclar generaciones, 02C debe asignar un directorio de estado nuevo a cada UI
(via entorno heredado y contrato de rutas), inicialmente vacio, sin restaurar
ready antiguo. Runtime observa ese indicio y verifica su owner antes de enviar
READY autenticado al Host. No afirmar que un archivo modificado por otro proceso
pruebe ContentRendered. La prueba visual Windows valida renderizado real.
El canal a Host no se comparte como stdin/stdout de herramientas ni logs.

## Carreras y multiples ventanas

| Secuencia | Comportamiento requerido |
| --- | --- |
| READY antes de REGISTER_ACK | Retener a lo sumo un indicio por generation; no foco; validar de nuevo despues del ACK |
| REGISTER repetido identico | ACK idempotente, sin crear otro owner ni renovar generation |
| REGISTER distinto mientras hay owner activo | Rechazar; requiere transicion explicita de retirada antes de una generation nueva |
| READY de generation anterior / otro Runtime | Descartar y registrar motivo; nunca activar |
| EXIT y READY simultaneos | EXIT observado gana, incluso si READY se recibio antes |
| PID igual, creation time distinto | Rechazar como instancia diferente |
| HWND pertenece a otro PID | Rechazar, incluso si comparte nombre/titulo/SID |
| UI sale entre validacion y accion | No reintentar contra un nuevo proceso por PID; actuar best-effort sin garantia atomica |
| Pipe cerrada / parse invalido / limite excedido | Invalidar handoff, conservar diagnostico y cierre acotado |
| Boton WPF repetido en shell nativa | No crear varios owners de foco; aplicar exclusividad de instancia y revisar experiencia Windows |
| Native -> WPF | Retirar registro de foco nativo, crear nueva generation; la ventana nativa puede seguir viva sin ser owner de handoff |

No usar esta tabla como resultados PASS. 02C implementara el transporte/adaptador
Windows y fixtures con acceso denegado/EOF; 05 comprobara procesos y ventanas reales.

## Coordinacion con otros bloqueos

H02B-05/R03A-01: seleccion de Windows PowerShell compatible, sondeo con plazo y
salida acotada. No sondear indefinidamente antes de mostrar la shell de reserva.
H02B-06/R03A-05: drenar salida de helpers sin memoria ilimitada; preservar salida
o declarar fallo/incompletitud, manejar EOF tardio, errores de escritura y vida
de descendientes. Un timeout de CommandContext por si solo no cierra toda familia.
No mezclar con la reforma de descargas/reparaciones de 06/07.

## Fuentes primarias consultadas el 2026-09-18

https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-createnamedpipea
https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipe-security-and-access-rights
https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getnamedpipeclientprocessid
https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getnamedpipeserverprocessid
https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowthreadprocessid
https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes
https://pkg.go.dev/os/exec

Las funciones del SO aportan piezas para una verificacion; ninguna constituye
por si sola un certificado de origen de la UI ni una defensa contra procesos
privilegiados. La documentacion no sustituye la implementacion y pruebas Windows.
