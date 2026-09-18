# Tanda 02C-1 - plazos, PowerShell y supervision

Fecha 2026-09-18. Rama exclusiva v1.5.0.1-PMM-reliability.
Entrada 54a2a8224822431e24fb740d6b6bc1d2fa42a177, arbol
25748d0c3bb86fd9bdd19beee433630b5ed22ece.

CERRADA para implementacion candidata, tests locales con stubs y builds.
NO es paridad del original ni aceptacion Windows; REL-01 sigue abierto.

## Por que 02C despues de 03B

Los IDs agrupan componentes, no son un orden cronologico: 02 trata Host y 03
Runtime. 03A/B era requisito para conocer el nieto WPF y la supervision que 02C
comparte. La cola de ejecucion explicita queda en SESSION_PLAN.md. No reabrir
01B/02A/02B/03A/03B ni renombrar su evidencia historica.

## Implementacion real

1. Modulo local Supervision compartido por candidatas, sin dependencias externas.
   GetSystemDirectoryW fija el ejecutable de Windows PowerShell; se comprueba 5.1
   Desktop y LanguageMode, sin PATH/pwsh. Probe acotado y resultado diferenciado:
   UNAVAILABLE, START_FAILED, TIMEOUT, CANCELLED, OUTPUT_INCOMPLETE,
   PROCESS_FAILED, INVALID_RESPONSE, UNSUPPORTED_VERSION u OK.
2. Dos pipes propios, copia concurrente en bloques, espera del proceso separada
   de EOF. Error/exceso cancela hijo directo; no convierte un Wait no-cero en
   excusa para ocultar un cierre incompleto de canales.
3. Host deja los bytes de hijos en logs exclusivos/capados y reporta supervision
   dentro de session.json. Error de guardar ese resumen fuerza fallo 125. El eco
   sincrono a consola de esos bytes se retira; se documenta como cambio de contrato,
   no como reproduccion del original. Los diagnosticos directos siguen con JSON.
4. Runtime limita la captura y marca datos incompletos con codigo 125 y campos
   output_complete/run_error/child_exit_code. commandOutput propaga el error, no
   presenta un prefijo de un merge como resultado correcto. Se comprueba UTF8 al
   representar texto. La politica de datos completos prevalece sobre continuar.
5. CLI valida rango 1..86400 segundos antes de multiplicar; rechaza flags repetidos,
   desconocidos, decimales, negativos, overflow y valores ausentes. Argumentos tras
   -- permanecen separados. Registro Steam: consultas reg.exe de hasta 3s con captura
   de 4096 bytes y aviso si el sondeo termina incompleto; no se ejecutaron aqui.
6. Recetas Host/Runtime copian, fijan hashes y comprueban el nuevo modulo comun.
   Los comparadores tambien exigen cobertura/hashes de esa dependencia local.

Plazos, limites por canal, codigos y casos de bloqueo del SO se detallan en
NativeCandidates/Supervision/README.md. No se introduce IPC, identificacion de
ventanas, firma, alteracion de antivirus ni redisenyo de descargas.

## Evidencia y limites

El ZIP de 03B coincide con su sha256 publicado; sus archivos reproducen exactamente
el arbol Git remoto. Se verifican los originales y las candidatas archivadas
Host S02B/Runtime S03B. No se afirma haber recuperado los fuentes originales.

Dos builds nuevos de CADA candidata fueron iguales en rutas de salida distintas,
con Go1.23.2 en Linux/amd64, destino Windows/amd64. Los hashes nuevos y fuentes
estan en SESSION02C1_CHECKS.json; reportes compactos, comandos y pruebas quedan
en SupervisionEvidence/s02c1. Reportes completos se regeneran con las recetas y
se incluyen en el ZIP de evidencia. Original y candidata son diferentes; no se
persigue cambiar su hash como mecanismo para evitar antivirus.

Tests contabilizados sin los dispatchers-fixture: Supervision 16, Runtime 23
(incluida lectura del inventario real de .NET, sin ejecutarlo), Host 9. Son 48
funciones de test de comportamiento/modelo, no 48 pruebas de PMM en Windows.
Hay subcasos adicionales que no se suman de nuevo. Python: 13 Host + 16 Runtime.
Supervision pasa tambien con detector de carreras en Linux. La suite de tests de
Supervision se compila para Windows, pero NO se ejecuta alli.

No hubo PMM, candidatos Windows, PowerShell, .NET, WPF, reg.exe ni AV en ejecucion.
Solo herramientas de compilacion/lectura y stubs propios. Nada de game runtime,
reparacion, reinstalacion de cuarentena, peticiones de exclusiones o envio de muestras.

## Que se cierra y que NO

H02B-05/R03A-01: seleccion/sondeo corregidos en fuente candidata; comportamiento
real de PS5.1, CLM y ruta del SO pendiente de Windows. No hay fallback a otro motor
cuando el compatible falla. El sondeo se repite en ambos procesos, no hay cache
confiable ni presupuesto unico de startup; una shell nativa puede volver a sondear.

H02B-06/R03A-05: mecanismos de captura/espera corregidos y probados con stubs.
Terminar TODA una familia de procesos Windows sigue sin implementar/probar y
bloquea promocion. Los limites de EOF no garantizan ausencia de I/O bloqueado en
kernel, ni cancelacion de la UI al cerrar splash. Evitar frases como "timeout
absoluto de toda la aplicacion" o "todos los descendientes finalizan".

R03B-03: overflow/CLI y espera de reg.exe tratados en candidata. R03B-02 (validacion
completa de manifiesto/pins), R03B-04 (rutas heredadas), reparacion transaccional,
HWND H02B-04 y fallos del handoff diagnostico permanecen abiertos. La arquitectura
legacy WPF/Runner conserva Bypass; no se ha sustituido por otro modo de elusion.

Los 629 archivos de PMM, snapshot, FixLab, recursos/traducciones y workflows siguen
byte-identicos. Build distribuido s01b; no sustituir ninguno de los EXE candidatos.
Los registros de tandas previas permanecen historicos. Commit silencioso [skip ci].

## Continuacion

02C-2: implementar acuerdo de instancia UI/canal y origen de HWND segun
HOST_RUNTIME_HANDSHAKE.md. Partir de las candidatas C1 guardadas, no S02B/S03B.
Cerrar por separado transporte/modelos y aceptacion Windows si no cabe en una sola
intervencion. No colocar un JSON/nonce en disco y afirmar que autentica el emisor.
El gestor de familia (Job Object o alternativa validada) y gates Windows siguen
requisitos de promocion, aunque se realicen en una tanda posterior especifica.
