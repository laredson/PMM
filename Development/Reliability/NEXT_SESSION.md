# Retomar despues de 02C-2A

Rama exclusiva: v1.5.0.1-PMM-reliability.
**02C-2A cerrada como biblioteca aislada; 02C-2 completa todavia NO.**
Siguiente: **02C-2B - conectar Host/Runtime a UIBridge**.
Leer AGENTS -> este archivo -> STATUS -> SESSION02C2A_FINDINGS ->
NativeCandidates/UIBridge/README.md e INTEGRATION.md.

## Base real, no reconstruir desde la conversacion

La rama ya tenia C1 publicada en 054e16404e1e45fcc614e24645c7fb651db80afb.
El viejo ZIP C1 no contiene las mismas candidatas; NO sobreescribir con el.
Conservar las fuentes de HEAD remoto, incluyendo Supervision y sus recetas.
Host C1: 96e6e6b024207257e7777d7ad72711bf8f8c0966c86929d6f5528ec177ddb059.
Runtime C1: db39fb942ebf9ba2c8d78c71abf4df43ec918a4040fe09dfaad65cba9a97ac77.
PMM/: 629 archivos, 628 hashes, build PMM-v1.5.0.1-reliability-s01b.
No volver a pedir el ZIP ni repetir 01B/02A/02B/03A/03B/02C-1.

## Entrega guardada

NativeCandidates/UIBridge/: protocolo, Gate y adapters Windows con transporte
local y referencias vivas de procesos. build.py offline Go1.23.2; 25 tests del
modelo/protocolo y race Linux; Windows test EXE compilado, NO ejecutado.
SHA-256 de ese EXE: 8d76336d55ef814c6fbdbcb852939b91ca8bf42884399baf96911f3b239b8414.
NO es una candidata PMM instalable, NO importar como PMM.exe/PMMRuntime.exe.

## Alcance 02C-2B

1. Verificar HEAD, leer fuentes C1 remotas y UIBridge. Agregar dependencia LOCAL
   y staging/hashes de UIBridge en ambos builds. No cambiar el paquete PMM.
2. Capturar identidades/handles inmediatamente tras Start y ANTES de Wait; revisar
   el orden de callbacks del Supervision actual. Host crea pipe antes de Start.
   Runtime conecta antes de tareas largas y serializa send/ACK mas heartbeat.
3. Usar Accept/Dial y NewAuthenticatedGate, no NewGate con PID de state.txt.
   Ante errores, retirar la coordinacion del foco sin activar fallback inseguro.
4. Cablear REGISTER/ACK/READY/EXIT para WPF y ruta nativa, con un directorio NUEVO
   por UI/generation. Resolver readiness temprano y repeticion del boton WPF.
   El fichero de estado es indicio, no prueba de identidad ni renderizado.
5. El monitor Host de state.txt pasa a progreso solamente. La entrega de foco usa
   Gate.TryHandoff desde el hilo propietario y respeta foreground del usuario.
   Captura/ACK/cierre concurrentes deben tener pruebas reproducibles con stubs.
6. Preservar limites de supervision C1 y output_complete. No redisenar repair,
   manifiestos o traducciones en esta integracion. No afirmar kill-tree Windows.
7. Compilar candidatas separadas, conservar codigo/evidencia/hashes. Windows IPC
   y GUI siguen NOT_RUN hasta su sesion real autorizada. Ningun PASS de Linux
   permite sustituir ejecutables. Commit [skip ci], sin Actions/PR/tag/release.

El usuario indico que el paquete actual arranca y parece funcionar; eso NO
acepta las candidatas aun no instaladas. H02B-04/REL-01 siguen abiertos.

## Prompt

"Completa 02C-2B en reliability: lee NEXT_SESSION e integra el modulo UIBridge
ya guardado en las candidatas C1 de HEAD remoto, con vida/registro/ACK/READY/cierre
y pruebas acotadas. No uses las viejas candidatas del ZIP, no sustituyas PMM/, no
modifiques idiomas ni dependencias de red. Guarda pruebas reales, limites Windows,
hashes y siguiente paso. Un commit [skip ci], sin Actions, PR, tags ni release."
