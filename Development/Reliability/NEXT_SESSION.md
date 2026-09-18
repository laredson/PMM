# Retomar despues de 02C-1

Rama v1.5.0.1-PMM-reliability. Leer AGENTS -> este archivo -> STATUS ->
SESSION02C1_FINDINGS -> NativeCandidates/Supervision/README.md ->
NativeCandidates/Runtime/HOST_RUNTIME_HANDSHAKE.md.
No repetir sesiones cerradas, no pedir otra vez el ZIP. IDs 02/03 agrupan
componentes; el orden real esta en SESSION_PLAN.md.

## Siguiente: 02C-2 - instancia UI / canal / entrega de foco

Entrada: HEAD de nuestra rama y candidatas S02C1 conservadas:
Host 96e6e6b024207257e7777d7ad72711bf8f8c0966c86929d6f5528ec177ddb059.
Runtime db39fb942ebf9ba2c8d78c71abf4df43ec918a4040fe09dfaad65cba9a97ac77.
Modulo comun nuevo: NativeCandidates/Supervision/ (go.mod replace local obligatorio).
Fuentes/recetas/modelos y evidencia: NativeCandidates/Host, Runtime y
SupervisionEvidence/s02c1. No reconstruir desde un resumen del chat.

1. Fijar HEAD, verificar fuentes/hashes y conservar PMM/ intacto (629 archivos,
   628 hashes; 1.5.0.1/s01b). No sustituir EXE, ni tocar idiomas/snapshot/FixLab.
2. Revisar handshake propuesto y elaborar implementacion candidata con canal local
   y comprobacion de identidad por SO; no confiar en titulo, PID declarado o secreto
   guardado en disco. Host conoce al Runtime directo; WPF es otro proceso hijo.
3. Registro de instancia/generation, ACK, ready previo al registro, salida prioritaria
   y rechazo de PID/HWND reutilizados. Conservar handles/identidad temporal y revisar
   quien puede crear/abrir el canal. Un error degrada la coordinacion del foco, no
   autoriza debilitar politica ni ejecutar payloads.
4. Mantener supervision de C1. No convertir salida/logs en canal de control ni
   perder el marcado output_complete. Gestion de familia Windows no esta resuelta:
   si se requiere para el canal, implementarla en un subpaso especifico verificable.
5. Modelos y stubs primero; compilar adapters Windows sin afirmar haberlos ejecutado.
   Si la tanda no cabe, dividir ANTES en 02C-2A transporte/modelo y 02C-2B integracion;
   cerrar cada una con codigo y gate explicitos, no entregas solo prometidas.
6. Actualizar STATUS, NEXT_SESSION, CHECKS y hallazgos; un commit [skip ci] autorizado,
   sin workflows/PR/tag/release. Pruebas reales Windows requieren entorno y permiso.

## Reproduccion de C1

Desde raiz, Go1.23.2 instalado, salida nueva EXTERNA:
python -B Development/Reliability/NativeCandidates/Host/build.py --out ../PMM-Host-S02C1
python -B Development/Reliability/NativeCandidates/Runtime/build.py --out ../PMM-Runtime-S02C1
python -B Development/Reliability/verify_identity.py --package PMM --expected-build PMM-v1.5.0.1-reliability-s01b
Los builds copian Supervision y fijan sus hashes; no hay descarga ni instalacion.

## Bloqueos antes de promocion

HWND/canal, gestion de familias y aceptacion Windows NOT_RUN. Manifiesto/pins y
rutas heredadas R03B-02/04; dependencias/reparacion 06/07; salida de diagnosticos
ante disco bloqueado/error; compatibilidad del nuevo eco de consola/logs y nuevos
textos de error con idiomas. La source parity original NO esta certificada.

## Prompt

"Continua con 02C-2 en nuestra rama reliability. Lee NEXT_SESSION y la especificacion
de handshake. Parte de C1, implementa canal/identidad solo en candidatas, con stubs
limitados y evidencia; no instales binarios ni toques traducciones. Si necesitas
subdividir, define primero el alcance cerrado. Registra pendientes Windows y la
entrada exacta siguiente; un commit [skip ci], sin Actions/PR/tag/release."
