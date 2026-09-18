# Supervision compartida de candidatas - S02C-1

Modulo LOCAL pmm.local/supervision. Host y Runtime lo referencian con replace
../Supervision; no hay paquetes externos ni descargas del compilador. Es codigo
candidato, no componente distribuido ni fuente original recuperada.

## Seleccion/sondeo

Solo la ruta WindowsPowerShell/v1.0/powershell.exe bajo GetSystemDirectoryW del SO
(ambos candidatos son amd64). Sin prioridad pwsh, PATH ni WINDIR, sin confiar en
PMM_HOST_POWERSHELL como prueba. Confirma version 5.1, edicion Desktop y un modo
reconocido. Compatible NO significa FullLanguage: CLM sigue llevando a reserva
nativa. Error, version distinta o salida ambigua deja la ruta utilizable vacia.
Cada proceso comprueba por si mismo; no hay cache en disco presentado como confianza.

ProbeTimeout=5s, 4096 bytes por canal, 250ms para EOF despues de salir el hijo y
hasta 2s para observar su salida tras cancelarlo. El presupuesto del sondeo no es
un limite total de 5s de todo el inicio: Host y Runtime sondean por separado y la
shell nativa puede volver a sondear. No se cambia politica de ejecucion, CLM ni AV.
El comando del sondeo no usa Bypass; el argumento heredado de lanzamiento WPF y
Runner permanece para la futura tanda de politicas. No afirmar retirarlo aqui.

## Procesos/salida

Run administra DOS os.Pipe propios y copia en bloques de 32KiB. Cmd recibe los
extremos de escritura; Wait no puede cerrar nuestros lectores prematuramente.
Lectores concurrentes y espera del hijo son independientes. No usa Scanner ni
CombinedOutput, ni crea goroutines os/exec para copiar un stdin arbitrario.
Solo acepta stdin nil o *os.File.

Runtime conserva stdout/stderr como texto hasta 16MiB por canal. El exceso o texto
UTF8 invalido da salida incompleta y codigo 125, nunca exito con datos recortados.
Los strings/JSON pueden necesitar memoria adicional a los bytes capturados. Host
almacena bytes exactos en archivos exclusivos de sesion de hasta 256MiB por canal;
no modifica CRLF/LF/NUL ni exige fin de linea. El exceso/error de escritura cancela
al hijo directo y queda registrado. No hay log ilimitado por proceso.

Host deja de reflejar sincronicamente la salida de hijos en la consola: esos bytes
estan en runner.stdout.log/runner.stderr.log. Es un cambio visible para clientes
CLI que antes esperaban ese eco; doctor/security propios siguen imprimiendo JSON.
La aceptacion Windows debe revisar esos consumidores. No declarar misma CLI sin
esa prueba. Los mensajes propios del Host y el ZIP diagnostico conservan limites
heredados de I/O; no estan incluidos en una garantia universal de tiempo real.

Tras salida del hijo, EOF dispone de 2s; si un descendiente retiene el pipe, se
cierran nuestros lectores y el resultado declara DrainTimedOut/OutputComplete=false,
incluso si el hijo devolvio un error distinto de cero. Se permite 100ms de salida
del copiador tras cerrar el lector. Si sigue pendiente, el resultado lo comunica
sin acceder al buffer que ese copiador todavia podria usar.

Context cancelado -> 130, deadline -> 124, salida incompleta -> 125, fallo de inicio
-> 127 en Runtime y 22 en Host. ChildExitCode se conserva por separado. Un codigo
no cero del hijo se conserva cuando no hay fallo de supervision. La cancelacion
mata SOLO al hijo directo; ReapTimeout=2s. ChildReaped=false comunica que no se ha
confirmado su salida. No se promete terminar nietos ni se ha implementado Job Object.
Run no cancela por cerrar el splash. El Host no aplica un plazo global a una sesion
interactiva normal; helpers Runtime tienen 5min por defecto, CLI 1..86400s y reg.exe
3s por consulta. Se rechazan opciones CLI ambiguas/duplicadas/desbordadas antes de
multiplicar segundos. Los parametros posteriores a -- se conservan separados.

Limites: syscall de inicio/kill y operaciones locales de disco deben responder.
Go no puede terminar una escritura bloqueada en kernel o un callback bloqueado;
un copiador pendiente no se anuncia como drenado. No usar rutas de red como
almacenamiento para reclamar estos presupuestos. Windows real queda NOT_RUN.

## Comprobaciones

Desde esta carpeta: GOTOOLCHAIN=local GOPROXY=off GOSUMDB=off GOWORK=off go test -v ./...
En Linux tambien se ejecuto go test -race; no se encontraron carreras en esos casos.
Los hijos son el binario del test con una unica funcion-fixture seleccionada:
linea de 5MiB, texto sin LF, archivo exacto, exceso, error de escritura/cierre,
cancelacion/plazo y nieto finito que conserva stdout/stderr. No son PMM ni PS.
El harness TestFixtureProcess no se cuenta como test de comportamiento.

Referencias consultadas el 2026-09-18:
https://pkg.go.dev/os/exec#Cmd
https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getsystemdirectoryw
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_exe?view=powershell-5.1
Se contrasto os/exec con Go1.23.2 instalado; no se actualiza toolchain en esta tanda.
