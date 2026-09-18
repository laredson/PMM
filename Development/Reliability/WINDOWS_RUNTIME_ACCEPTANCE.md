# Gate Windows de Runtime - S03B

Estado de TODOS los casos: NOT_RUN. Ningun caso se ejecuta automaticamente.
Candidata: 45e017190c379774afd24557084e7fa532bbef58b6ead6869294943bb72ed0be.
Original: e90341d8449b485cb04af3c00d357bc8c67e87070644ff6bf7d27121a00c422a.
Host candidato S02B: a5f50c5677608c9875eefb65fe75fd7efb3460808be2f53df7ea3ec6db195d97.
La aprobacion requiere codigo corregido de 02C y posteriores, hash de CADA
artefacto probado y consentimiento del usuario. Compilar no autoriza instalar.

## Preparacion obligatoria

Usar Windows de prueba y COPIAS desechables, nunca Workspace/juego del usuario.
No desactivar antivirus, CLM/App Control o firma. Capturar estado efectivo, version
Windows/PowerShell, version de producto/componentes, SHA-256, exit codes, stdout,
stderr, tiempos, procesos observados y resultado visual. Red bloqueada/controlada
para los casos que no la necesitan; reparacion online solo con autorizacion aparte.

No ejecutar start/doctor/dependencies status suponiendo que son lectores de hashes:
pueden lanzar PowerShell/.NET/helpers; start/ensure puede ademas reparar archivos.
La inyeccion de estados/errores aqui es SOLO en fixtures o copias aisladas.

| ID | Caso y resultado requerido | Bloqueo / evidencia necesaria |
| --- | --- | --- |
| R05-01 | version/--version/-v informan componente 1.2.1; producto 1.5.0.1 no debe confundirse | CLI real, stdout/codigo y metadatos |
| R05-02 | doctor sin argumentos y security: resultado explicable, sondeos acotados, sin cuelgue | R03A-01/05; registrar todos los hijos |
| R05-03 | Root: Engine, CWD diferente, ruta Unicode/espacios, PMM_ROOT valido/invalido y PMM_HOST_ROOT distinto | R03A-06; no ejecutar scripts de una raiz no validada; fijar precedencia soportada |
| R05-04 | WPF bajo PS5.1 compatible: visible sin consola transitoria, streams y sesion correctos | R03A-01; no sustituir por pwsh sin validacion |
| R05-05 | PS ausente/CLM/sondeo fallido y ui-native: shell nativa accesible, readiness y splash resueltos | R03A-01/02; restricciones intactas |
| R05-06 | UI hijo retorna 0/no-cero/no inicia: propagacion, error claro y estado final coherente | Codigos 0/30/31 o exit hijo segun caso; nunca PASS tras fallo |
| R05-07 | Perder manifest o JSON/schema invalido: error explicito, sin lanzar dependencias sobre contrato vacio | R03B-02; doctor no debe ocultar fallo |
| R05-08 | Dependencias sanas: hashes correctos y sin reparacion de red; faltantes/alteradas: no restauracion silenciosa | R03A-04, 06/07; log/fs/red antes y despues |
| R05-09 | Inventario con linea larga/duplicada/no legible: rechazo; inventario real de 188 archivos aceptado | R03B-01 corregido en fuente; repetir adaptacion Windows |
| R05-10 | process.run: argv con espacios/Unicode, stdout/stderr, 0/no-cero/no-exe; plazo valido e invalido | R03A-05/R03B-03; no comandos arbitrarios del juego |
| R05-11 | Helper muy locuaz o descendiente retiene pipe; timeout/cancelacion y disco sin espacio | R03A-05/H02B-06; salida completa o error explicito, nunca cuelgue/memoria ilimitada |
| R05-12 | UI ready antes de registro, generacion vieja, registro duplicado, dos Runtime simultaneos | H02B-04/R03A-03; owner correcto por SO/canal, sin foco ajeno |
| R05-13 | PID/HWND reutilizado o ajeno, consulta denegada, owner sale durante entrega | Rechazo seguro; trazas de handles/vida, no solo JSON |
| R05-14 | Cierre Runtime/Host/UI en cada orden; boton WPF repetido desde nativa | R03A-02/05/06; sin procesos perdidos ni state compartido entre instancias |
| R05-15 | Alt-Tab durante carga, minimizado, DPI/monitores y cierre del splash | Sin robo de foco; Windows puede negar SetForegroundWindow |
| R05-16 | Idiomas habilitados/RTL y rutas tecnicas, logs/errores largos | No regresar PS5.1 ni traducir nativeName/IDs; textos nuevos localizados antes de release |
| R05-17 | Hash/archive/knowledge/game detect con fixtures y paths validos/invalidos | No cambios fuera de staging; reg.exe tambien debe tener limite; revisar rutas Data/Tools heredadas |
| R05-18 | Actualizacion/rollback del conjunto Host+Runtime aceptado | Integridad de Workspace/paquete; nunca mezclar protocolos incompatibles |

Para cada caso registrar: hash, pasos, esperado, observado, evidencia saneada,
PASS/FAIL/BLOCKED/NOT_RUN y limitaciones. No publicar datos de usuario, rutas
personales, saves, logs crudos o secretos en Git. Comparar baseline/candidata solo
cuando sea seguro; una diferencia intencional de fiabilidad se documenta, no se
convierte en supuesto fallo probado del original. Todos siguen NOT_RUN en S03B.

## Anexo C1 - todos NOT_RUN en Windows

Verificar PS5.1 Desktop por ruta del sistema con PATH/pwsh/WINDIR manipulados;
CLM, error de sondeo y plazo conservan reserva nativa. Medir presupuesto agregado,
no anunciar 5s como tiempo maximo de toda la aplicacion. Probar linea >4MiB,
limite de salida, disco lleno/permiso denegado/Close fallido y EOF retenido por
nieto incluso con exit 7 del hijo. ExitCode 125 debe bloquear el uso de datos
incompletos. Verificar eco de consola vs raw logs y consumidores CLI. Confirmar
que cerrar splash NO se presenta como cancelacion de familia. Job Objects/canal
no implementados ni validados en C1. Host sin plazo global durante sesion normal.
