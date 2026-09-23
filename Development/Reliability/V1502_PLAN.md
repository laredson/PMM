# Plan v1.5.0.2 - fiabilidad y reduccion de falsos positivos

Objetivo: conservar todas las funciones heredadas y reducir causas legitimas de deteccion mediante una cadena fuente -> build -> paquete -> ejecucion mas simple, observable y verificable.

No es un plan de evasion de antivirus. No se desactivan protecciones, no se piden exclusiones y no se ocultan funciones a analizadores.

## Baseline

Origen: `2586b4c3999ccc094344bc65710d6559f4858871`.
Incluye I03 (23 idiomas habilitados) e I04 (Nexus Updates), Host/Runtime C2B y el resto de funciones de esa linea.

## V1502-S00 - Bootstrap de rama

Estado: **CERRADO**.

- Crear `v1.5.0.2` desde el HEAD real de reliability.
- No copiar carpetas antiguas.
- Registrar historial, estado, plan e incidencia pre-UI.
- Mantener el paquete I04 byte-identico durante el bootstrap.

## V1502-S01 - Startup observable + baseline

Estado: **SIGUIENTE**.

- Instrumentar de forma acotada el tramo splash -> UI.
- Preservar evidencia de excepcion/etapa.
- Inventariar procesos, PowerShell, repair, red y binarios/scripts del startup.
- Fijar hashes del baseline.
- Usar el fallo pre-UI como gate de fiabilidad, sin inventar su causa.

Relacion heredada: completa la parte de evidencia de REL-00/REL-01 y prepara los cambios de REL-03/04.

## V1502-S02 - Procesos y PowerShell

- Localizar cada uso real de PowerShell y `ExecutionPolicy Bypass`.
- Retirar Bypass donde exista una ruta soportada.
- No cambiar politicas globales.
- Argumentos estructurados y directorios permitidos.
- Timeouts, cancelacion, codigos de salida y logs.
- Conservar CREATE_NO_WINDOW cuando solo evita parpadeo de consola en una GUI legitima.
- No construir comandos de shell con texto no confiable.

Cruce historico: REL-03 / tanda 08.

## V1502-S03 - Check separado de Repair

- Arranque sano sin red.
- Check de dependencias de solo lectura.
- Falta/alteracion -> diagnostico claro.
- Repair solo por accion explicita.
- Descarga con origen fijado, HTTPS, limites, hash/firma cuando exista, staging y rollback.
- No reinstalar automaticamente algo que pudiera haber sido puesto en cuarentena.
- No repetir descargas para vencer un bloqueo.

Cruce historico: REL-04 / tandas 06-07.

## V1502-S04 - Broker de operaciones estrecho

Estado heredado:
`Modules/Operations/OperationWorker.ps1` sigue siendo broker actual; el objetivo historico es mover operaciones a subcomandos nativos PMMRuntime/PMMEngine cuando sea justificable.

- Definir operaciones concretas, no "ejecutar cualquier comando".
- Limitar rutas/argumentos/tiempo/cancelacion.
- Migrar gradualmente sin perder workflows.
- Mantener compatibilidad de UI y recuperacion.

Cruce historico: parte pendiente de REL-03.

## V1502-S05 - Build reproducible y recursos PE estandar

- Toolchain fijado.
- Fuente -> artefacto reproducible.
- VERSIONINFO, manifest e icono mediante recursos estandar.
- Metadata de publisher/producto coherente.
- Separar artefactos propios de terceros y conservar sus firmas/licencias.
- Regenerar inventarios desde bytes finales.

Cruce historico: REL-05 / tanda 09.

## V1502-S06 - Firma real

- Requiere identidad/certificado provisionados expresamente por el propietario.
- Authenticode/timestamp en artefactos propios pertinentes.
- Verificar cadena e integridad en Windows.
- No autofirmar instalando raices silenciosamente.
- Inventario final despues de firmar.

Cruce historico: REL-06 / tanda 10.

## V1502-S07 - Preflight y matriz de escaneos

- Paquete limpio y autocontenido.
- Verificacion de versiones, hashes, procedencia, firmas y rutas.
- Windows real con protecciones activas.
- Instalacion nueva y actualizacion.
- Defender y otros escaneos autorizados registrados por hash/fecha.
- VirusTotal solo con autorizacion expresa para subir la muestra.
- Nexus como prueba real de distribucion, no como API privada emulada.
- Comparar builds por hash y cambios de ingenieria, no mutar arbitrariamente hasta quedar "indetectable".

Cruce historico: REL-07 / tanda 12.

## V1502-S08 - Falsos positivos de vendors

Solo si persisten detecciones despues de S02-S07:
- identificar motor, nombre de deteccion, hash y fecha;
- comprobar si es heuristica/reputacion o hallazgo concreto;
- enviar falsos positivos por canales oficiales cuando proceda;
- conservar recibos/evidencia;
- no degradar la aplicacion solo para satisfacer una heuristica no explicada.

## Gates transversales

Cada etapa debe conservar:
- 23 idiomas habilitados y reservas I03;
- nativeName, RTL/LTR y persistencia;
- I04 Nexus Updates;
- Workspace y datos del usuario;
- rollback/despliegue;
- Deep Analysis y flujos Mods & Merge;
- binarios/candidatas FixLab solo segun sus gates existentes.

## Incidencia STARTUP-PRE-UI

El cierre de una etapa que toque startup debe comprobar que:
- un fallo sigue produciendo evidencia;
- no se esconde con retries infinitos;
- no se borra estado del usuario para arrancar;
- no se atribuye a idioma/locale sin prueba;
- si aparece una causa demostrada, se agrega una regresion especifica.
