# Gate Windows del Host - NO EJECUTADO

Estado inicial de TODOS los casos: NOT_RUN. Candidata S02B no aprobada.
SHA original: 010c4f656dbe68f0bcf667610accf6cc4e248872120c6acd299f0fca7c209c2d.
SHA candidata S02B: a5f50c5677608c9875eefb65fe75fd7efb3460808be2f53df7ea3ec6db195d97.
Paquete de referencia: 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b.

## Preparacion para una tanda de pruebas expresamente autorizada

No realizar estas pruebas sobre la instalacion de uso diario. Crear dos copias
DESECHABLES del paquete versionado, sin Workspace ni datos privados. Verificar
los 629 archivos antes de agregar utilidades de prueba. La copia A ejecuta su
PMM.exe original. La copia B conserva PMM.exe y agrega la candidata con otro
nombre EN LA RAIZ DE ESA COPIA: executableRoot depende de la ubicacion del EXE.
No ejecutar desde el directorio de evidencia esperando que encuentre Engine.
No reemplazar ningun binario de produccion ni tocar mods/saves reales.

Mantener protecciones activas y usuario sin elevar. No modificar politicas de
PowerShell, antivirus, AppLocker/WDAC o exclusiones para conseguir un PASS.
Una denegacion se registra como tal; solo el administrador del entorno puede
proporcionar un entorno de prueba permitido. No restaurar cuarentenas.

Registrar build de Windows, arquitectura, monitores/DPI, version de PowerShell,
politicas efectivas, hashes de A/B, caso, accion, salida/exit code, proceso hijo,
logs y resultado observado. Logs sanitizados antes de compartir. Un fallo de A
no legitima automaticamente el mismo fallo de B: distinguir regresion de defecto
heredado. Usar un arnes de prueba local para escenarios de error/estado; no
inventar un PASS porque no existe todavia ese arnes.

| Caso | Accion controlada | Aceptacion requerida / evidencia |
| --- | --- | --- |
| H05-01 | Inicio sin argumentos y start; UI fria y caliente, cerrar normalmente | Una UI operativa, sin bucle de splash; codigos/fin de sesion y video/timestamps; 5 repeticiones por variante |
| H05-02 | doctor --json, security status --json, handoff create en sandbox | Sin splash; JSON y protocolos correctos; ZIP abre e incluye la sesion; codigos comparados A/B |
| H05-03 | Falta runtime/rutas, ruta desconocida, hijo con exit no cero, carpeta no escribible | Diagnostico claro, exit y contexto conservados, sin reparar/instalar por sorpresa ni proceso huerfano; mock sin tocar archivos reales |
| H05-04 | Readiness dividido entre :4 y 2+CRLF, vacio, BOM, registro excesivo/multiple, UI-window-created | Ninguna activacion desde registros incompletos; solo ready completo retira splash; no aceptar NUL/overflow |
| H05-05 | HWND ajeno, destruido, reciclado, invalido; UI-ready sin HWND | NO mostrar/activar una ventana ajena. Origen validado o rechazo sin accion. Actualmente BLOCKED por H02B-04; IsWindow solo no basta |
| H05-06 | Alt+Tab durante inicio; cerrar hijo justo antes/despues de ready; fallo posterior a ready | Stop/fallo no provoca activacion tardia; sin robar foco; handoff valido solo best-effort. Ejecutar al menos 10 repeticiones de la carrera |
| H05-07 | Fallo al crear splash/control/timer; cerrar splash manualmente; inicializacion lenta | Supervision continua; cierre de splash no mata proceso; sin hilo/ventana residual; registrar tiempos de Close, no asumir timeout total 2s |
| H05-08 | Sondeo PowerShell bloqueado, PS ausente, PS5.1/pwsh instalados, politica restrictiva | Arranque/error acotado y coherente; no evasiones ni cambio de politica. BLOCKED hasta H02B-05/02C |
| H05-09 | Stub produce stdout/stderr concurrente, linea >4 MiB, cierra temprano, descendiente retiene pipes | Salida/errores completos o truncacion declarada, sin bloqueo y sin perdida silenciosa; BLOCKED hasta H02B-06/02C |
| H05-10 | Ruta con espacios/Unicode, DPI 100/150/200%, multiples monitores | UI y splash visibles/utilizables, version correcta y taskbar/foco estables; capturas y errores |
| H05-11 | Disco/cuota llena durante logs/handoff; salida antes de crear UI | No informar ZIP valido si falla escritura/cierre; error original preservado; no destruir evidencia existente |
| H05-12 | Idiomas habilitados y fallback nativo; UI con configuracion aislada | No regresiones PS5.1, selecciones y RTL preservados; textos nuevos del candidato revisados antes de release |

## Decisiones permitidas

- PASS: evidencia real del caso con el artefacto identificado.
- FAIL: resultado no aceptable, bug/regresion enlazado y reproduccion.
- BLOCKED: falta arnes, entorno, correccion o permiso; NO cuenta como PASS.
- NOT_RUN: prueba no realizada.

No hay aprobacion hasta resolver H02B-04/05/06, revisar H02B-07, completar los
casos aplicables y recibir aceptacion del propietario. Si cambia el candidato,
registrar el nuevo hash y repetir los casos afectados. Ni el hash del original,
ni una compilacion repetible, ni cero detecciones AV sustituyen esta decision.

## Anexo C1 - todos NOT_RUN en Windows

Verificar PS5.1 Desktop por ruta del sistema con PATH/pwsh/WINDIR manipulados;
CLM, error de sondeo y plazo conservan reserva nativa. Medir presupuesto agregado,
no anunciar 5s como tiempo maximo de toda la aplicacion. Probar linea >4MiB,
limite de salida, disco lleno/permiso denegado/Close fallido y EOF retenido por
nieto incluso con exit 7 del hijo. ExitCode 125 debe bloquear el uso de datos
incompletos. Verificar eco de consola vs raw logs y consumidores CLI. Confirmar
que cerrar splash NO se presenta como cancelacion de familia. Job Objects/canal
no implementados ni validados en C1. Host sin plazo global durante sesion normal.
