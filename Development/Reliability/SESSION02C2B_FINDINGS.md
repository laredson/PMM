# 02C-2B - integracion candidata de Host / Runtime / UIBridge

Fecha: 2026-09-18. Rama exclusiva: v1.5.0.1-PMM-reliability.
Entrada: 318666ca8beb828529b49d7ce245c0652b616d28.
Arbol remoto: 1a9fa47d134575c91d342268f9ade17606996441.

**CERRADA para integracion de fuentes candidatas, modelos y compilacion.**
Windows/IPC/GUI siguen NOT_RUN; no equivalencia funcional ni permiso para
reemplazar ejecutables distribuidos. REL-01 sigue abierto.

## Procedencia real

No se uso el viejo ZIP C1 como autoridad de fuentes. Se recuperaron del conector
los fuentes C1 actuales que diferian; los blobs de los archivos de produccion,
recetas y fixtures recuperados se contrastaron con GitHub. La recompilacion de
Host C1 reprodujo 96e6e6b024207257e7777d7ad72711bf8f8c0966c86929d6f5528ec177ddb059;
Runtime C1 reprodujo db39fb942ebf9ba2c8d78c71abf4df43ec918a4040fe09dfaad65cba9a97ac77.
Los fuentes UIBridge de entrada coinciden con los hashes del registro 02C-2A.
El paquete local reproduce el subarbol PMM remoto 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa.

Esto NO afirma que todo el ZIP antiguo coincida con HEAD. La publicacion aplica
solamente las rutas enumeradas sobre el arbol remoto, conservando los otros
archivos. Por esa razon se entrega ZIP de cambios, no un repositorio completo
reconstruido a partir de documentos antiguos.

## Conexiones implementadas

- Host crea la named pipe antes de Start, solo para start del Runtime esperado.
  La nueva llamada Capture de Supervision corre antes de que comience Cmd.Wait;
  captura una referencia viva del proceso real. No espera mensajes ni hace logs
  dentro de ese hook. Los lectores de stdout/stderr mantienen los limites C1.
- Accept comprueba el Runtime capturado; Host construye NewAuthenticatedGate,
  nunca un Gate autenticado con PID de state.txt. Runtime deriva su padre del SO,
  contrasta su instancia con el localizador y usa Dial antes de dependencias/UI.
- El localizador viaja en entorno deduplicado sin distincion de mayusculas.
  Runtime lo elimina antes de lanzar herramientas. El entorno WPF vuelve a
  eliminar todos los campos PMM_UIBRIDGE_ y recibe su directorio nuevo de estado.
  El localizador NO es una credencial ni sustituye la comprobacion del endpoint.
- Client serializa transacciones completas Send/ACK con plazo de 3 segundos,
  secuencia monotona y heartbeat cada segundo. El servidor confirma el registro
  solo DESPUES de escribir su ACK. Fallo de mensaje/canal/ACK revoca coordinacion.
- WPF se lanza directamente y su identidad se captura antes de Wait. Se permite
  una WPF por coordinador; el boton repetido no crea un segundo proceso. Cada
  intento dispone de un directorio nuevo Workspace/State/UIInstances/ui-*.
  Los estados del Runtime siguen en su HostSession, no en el directorio de WPF.
- READY temprano se conserva como indicio en ese directorio, leido despues de
  REGISTER/ACK. Se revalida vida, instancia y propietario de la ventana. EXIT y
  FAILED retiran generaciones; antes de registrar una nueva se retira la anterior.
- La ruta nativa comunica su HWND real despues de ShowWindow/UpdateWindow y
  registra al Runtime. Su cierre revoca el canal sin esperar I/O en el callback
  Win32. Native -> WPF hace EXIT y una generacion nueva; la ventana nativa puede
  permanecer visible sin conservar autorizacion de foco.
- Host solo interpreta su state.txt como progreso. No existe el antiguo camino
  de entrega de foco basado en su HWND. La notificacion nueva guarda Gate y
  generacion, no un HWND para usar mas tarde. TryHandoff se ejecuta en el hilo
  del splash; su callback vuelve a comprobar stop y respeta el foreground actual.
  Los logs quedan fuera del bloqueo de Gate.

## Fallos y limites

Fallo de canal/captura/estado desactiva coordinacion, no permite otra fuente de
identidad ni impide deliberadamente la UI. Si no puede crearse directorio nuevo,
WPF recibe SESSION_DIR vacio, sin reutilizar un estado anterior. Sin HWND util o
con terminalidad se retira el splash sin activacion. En la ruta WPF, tras
30 segundos de vigilancia sin READY util se revoca coordinacion; la aplicacion puede seguir cargando y usarse a mano.
Este plazo NO es un timeout de la aplicacion ni detiene trabajos de dependencias.

No se han cambiado la politica de descargas, manifests/pins, rutas historicas,
ExecutionPolicy Bypass, traducciones ni la activacion propia del script WPF.
La proteccion implementada se refiere a la activacion solicitada por Host, no a
prohibir toda activacion que WPF o Windows puedan decidir por su cuenta.

Los handles/PID se comprueban con el SO, pero validar una ventana y activarla no
es una transaccion atomica Win32. Sigue pendiente comprobar carreras reales y
reciclado de HWND dentro del MISMO proceso. El canal no protege frente a codigo
ya comprometido dentro de los procesos autenticados. El archivo de estado sigue
siendo modificable y no prueba renderizado; nunca autoriza por si solo el foco.

C1 sigue sin terminar familias de procesos con Job Objects. Cerrar Runtime puede
dejar una WPF hija fuera de su vida; el canal y Gate se revocan, no se declara
kill-tree. I/O del kernel bloqueado y logs heredados siguen teniendo limitaciones.
No hubo ejecucion Windows, PowerShell, .NET, PMM, antivirus ni reparaciones.

## Comprobaciones realizadas

91 funciones Test con aserciones: UIBridge 36, Supervision 18, Host 10, Runtime 27.
Se excluyen los dos dispatchers de procesos-fixture y el nombre FuzzDecode;
sus semillas se ejecutaron, no se hizo una nueva campana de fuzz. Las cuatro
suites tambien pasaron con el detector de carreras en Linux. 18 pruebas Python
(9 por receta) comprobaron inspeccion PE y proteccion del directorio de salida.

Los casos nuevos cubren conversacion por frames, ACK demorado/fallido, READY
previo al registro, transacciones concurrentes, heartbeat, transicion native/WPF,
close durante ACK, aislamiento de entorno, directorios nuevos, HWND ajeno,
proceso ya terminado, boton WPF repetido y Capture antes de Wait con salida real
del proceso-fixture. Las pruebas de proceso solo ejecutan nuestros fixtures Go.

Compilacion y go vet Windows correctos en los cuatro modulos. Un aviso inicial
de vet sobre dos literales de struct en un test se corrigio; el resultado final
conservado es posterior a esa correccion. Cuatro harnesses Windows compilados,
NO ejecutados. Dos builds finales por candidata fueron byte-identicos entre si:

| Candidata | SHA-256 | Bytes |
| --- | --- | --- |
| Host S02C2B | a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c | 2744832 |
| Runtime S02C2B | b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f | 6506496 |

Entorno: Linux/amd64, Go1.23.2, target Windows/amd64, dependencias locales offline.
Repetibilidad en este entorno no significa equivalencia con el binario original.
Los dos builds incluyen hashes de Supervision/UIBridge y no cambian PMM/.

## Conservacion y continuidad

Los 629 archivos del paquete permanecen iguales; 628 checksums correctos, cero
discrepancias, version 1.5.0.1 / build PMM-v1.5.0.1-reliability-s01b. Snapshot,
FixLab, traducciones, workflows y ramas externas no se modifican. No se publican
binarios en Git ni release/tag/PR; un commit de desarrollo [skip ci].

IntegrationEvidence/s02c2b conserva resultados reales compactos y hashes de build.
Los logs JSONL, informes completos y delta de codigo se conservan en el ZIP de
evidencia y pueden regenerarse desde los fuentes/recetas de este commit.
WINDOWS_UIBRIDGE_ACCEPTANCE.md mantiene las 12 pruebas de SO anteriores y agrega
la aceptacion integrada. Siguiente 04A: procedencia/fuente de FixLab, aislada.
La aceptacion Windows de Host/Runtime/UIBridge sigue siendo un requisito previo
a cualquier promocion; los bloqueos R03B-02/04 y dependencias 06/07 no se cierran.
