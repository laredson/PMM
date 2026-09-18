# Tanda 02C-2A - protocolo y transporte de instancia UI

Fecha 2026-09-18. Rama exclusiva v1.5.0.1-PMM-reliability.
Entrada remota: 054e16404e1e45fcc614e24645c7fb651db80afb.
Arbol remoto: 8802a856394f19cafac31f9e31465add91fbe588.

## Alcance cerrado

02C-2 se dividio ANTES de implementar en 2A (biblioteca/modelo/transporte) y
2B (conexion real de Host/Runtime). 2A entrega codigo ejecutable como biblioteca,
pruebas del protocolo/modelo y adaptadores Win32 compilados. **NO integrado en
las candidatas, NO ejecutado en Windows, NO cierra H02B-04 ni REL-01.**
No se sustituye ni recompila el programa distribuido.

## Base correcta y observacion del usuario

Se confirmo que C1 ya estaba publicada en 054e164. La copia C1 descargable de la
charla anterior no coincide con esas fuentes candidatas; no se ha copiado sobre
la rama. Este cambio solo agrega UIBridge y actualiza documentos especificos,
con el arbol remoto como base. Se conserva TODO Host/Runtime/Supervision remoto.
El paquete PMM del ZIP previo reproduce el subarbol remoto
09df5c45aee3390c6b8ea235c8afa4e149a9f1fa y pasa verificacion de sus 628 checksums.
Esto no afirma que todo el ZIP antiguo reproduzca el repositorio remoto actual.

El usuario informa que PMM arranca y parece funcionar bien. Se registra como
prueba manual informal del paquete actual, no como aceptacion de las candidatas
nuevas: los ejecutables distribuidos todavia son los originales. No se recibieron
logs ni se observo remotamente la ejecucion Windows.

## Implementado

NativeCandidates/UIBridge es un modulo local sin dependencias externas:

- Mensajes acotados (4096 bytes) con longitud explicita, esquema cerrado y numeros
  decimales como strings. Se rechazan duplicados, campos desconocidos, null,
  desbordamientos, datos posteriores y mensajes fuera de secuencia/sesion.
- Gate con HELLO, REGISTER/ACK, generation no reutilizable, una sola instancia,
  un indicio READY pendiente y retirada EXIT/FAILED/CLOSE. Registro identico con
  secuencia nueva no reactiva un foco ya consumido. ACK debe corresponder al
  request exacto y debe haber sido escrito antes de permitir la accion.
- WinProcess retiene handles no heredables y FILETIME. La ruta nativa solo acepta
  Runtime como propietario; WPF requiere proceso vivo con identidad exacta y
  parentesco directo contrastado por Toolhelp. HWND se contrasta con su owner,
  vida del proceso y condicion de ventana superior, no con titulo o nombre.
- Named pipe local con DACL del logon, instancia unica, rechazo de remoto y de
  colision; identidad de endpoints consultada al SO. Dial comprueba tambien el
  parentesco del cliente con el Host vivo esperado. No hay fallback TCP/archivo.
- Un worker I/O por conexion y cola sin buffer; operaciones con plazo solicitado
  de 5 segundos o menor plazo del caller. Revocacion inmediata; cancelacion
  overlapped sin liberar buffers antes de completar. Done separa revocacion de
  limpieza real. Un driver defectuoso puede retener el unico worker en limpieza;
  no se promete cierre absoluto del kernel ni se crea un bucle de reintentos.
- NewAuthenticatedGate conecta identidad comprobada del endpoint y revocacion
  del canal al modelo. Revalida justo antes de entregar el HWND a un callback
  corto; la integracion debera respetar foreground en el hilo del splash.

La biblioteca no cambia politicas Windows, no fuerza foco, no ejecuta PowerShell,
no descarga payloads, no toca antivirus y no termina familias de procesos.
Su existencia NO hace que PMM este usando ya este canal.

## Comprobaciones y limites

25 funciones de test Go de modelos/protocolo superadas, ademas de subcasos y dos
semillas de fuzz. Linux race detector sin incidencias en esa suite. FuzzDecode
recorrio 60527 entradas en una ejecucion acotada: no son 60527 pruebas Windows.
Tambien se comprobo compilacion/vet del codigo Windows y el builder rechazo
salidas existentes y salidas dentro del repositorio.

Dos builds offline en carpetas distintas generaron el MISMO ejecutable de TEST
Windows (no PMM): SHA-256
8d76336d55ef814c6fbdbcb852939b91ca8bf42884399baf96911f3b239b8414.
Las pruebas Win32 opt-in y su dispatcher se compilaron pero no se ejecutaron.
El numero de tests no incluye ese dispatcher ni cuenta skips Windows como PASS.
Evidencia compacta y stdout real quedan en UIBridge/evidence; logs JSONL completos
y el EXE de pruebas quedan en el ZIP de evidencia. build.py permite reproducirlos.

No hay pruebas de named pipes reales, ACL efectivas, GetProcessTimes real ni
ventanas Windows en esta sesion Linux. No hay equivalencia funcional certificada,
certificado de firma ni escaneo AV. Tampoco hay promesa de eliminar carreras:
Windows no tiene una operacion atomica de validar HWND y dar foco; el reciclado
de HWND dentro del MISMO proceso sigue siendo una limitacion explicita.

## Continuidad

Siguiente: 02C-2B, conectar el modulo a las candidatas C1 ACTUALES de GitHub.
INTEGRATION.md detalla captura antes de Wait, conexion temprana, heartbeat,
transacciones serializadas, directorios nuevos por UI, ACK/READY, salida,
exclusividad y eliminacion de todo handoff directo desde state.txt.
WINDOWS_UIBRIDGE_ACCEPTANCE.md deja 12 casos NOT_RUN; no sustituye los otros gates.
No volver a implementar la biblioteca ni importar las antiguas candidatas del ZIP.

PMM/, idiomas, snapshot, FixLab, Host/Runtime/Supervision y workflows quedan
intactos por la base remota y el alcance de archivos del commit. Version/build
siguen 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b. Sin release/tag/PR/instalacion.
