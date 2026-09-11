# Puente MCP de PMM — preview local 0.5.0

PMM funciona como servidor MCP local mediante STDIO. Una IA puede consultar y
crear casos AIIO y enviar/recibir datos sin mover ZIPs manualmente entre ventanas.
PMM conserva la propiedad de los archivos y del flujo de revisión. Esta preview
todavía no es el sistema completo de modding autónomo.

## Conectar desde PMM

1. Abrir **Settings → AI / MCP → Puente MCP local**.
2. Pulsar **Habilitar y preparar conexión**. Comparte resúmenes de todos los casos
   de esta instalación, sus artefactos MCP y la referencia Vanilla preparada.
3. Abrir **Conexión y archivos recibidos**. En Workspace/MCP, PMM genera
   codex-mcp.toml para Codex y mcp-config.json para clientes STDIO compatibles.
4. Incorporar esa entrada al cliente una vez y reiniciar su conexión MCP.
   Regenerar los archivos si se mueve la instalación portable.

**Deshabilitar MCP** rechaza llamadas posteriores incluso en conexiones abiertas.
Una operación iniciada puede terminar. Cerrar PMM no deshabilita el servidor:
el cliente inicia su propio proceso local. No se abren puertos.

También se puede preparar la conexión con Windows PowerShell 5.1:

~~~powershell
& .\PMM\Modules\MCP\Export-PMMMCPConfig.ps1 -Enable
~~~

No requiere Node ni Python. No modifica automáticamente ajustes personales de
otros programas. Este HQ puede usar una entrada de proyecto en .codex/config.toml.
Una conversación ya iniciada puede necesitar reinicio/reconexión del cliente.

La conexión desde una nube necesita un transporte remoto autenticado. Esta
preview no implementa HTTP, OAuth, túneles ni publicación de datos.
Fuentes: [MCP en Codex](https://learn.chatgpt.com/docs/extend/mcp?surface=cli) y
[transportes MCP](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports).

## Publicar un caso por MCP

En AIIO cases, seleccionar **Transport → MCP** y pulsar **Publish to MCP**.
AUTO también respeta ese transporte. Se publica el título y objetivo actuales,
sin generar ZIP ni copiar automáticamente adjuntos. La evidencia se solicita
mediante las herramientas acotadas del puente.

El estado **AVAILABLE_VIA_MCP** significa disponible, no entregado ni atendido.
Un cliente conectado debe consultar pmm_cases_list y pmm_case_get. El campo
mcpRequest identifica una petición publicada vigente; null significa que no
hay publicación vigente. Editar el caso invalida la petición anterior.
Publicar el mismo caso sin cambios no añade pasos ni peticiones duplicadas.
MCP deshabilitado produce un error, nunca una conversión silenciosa a ZIP.

PMM no puede iniciar por sí solo un turno en este chat mediante este servidor
STDIO. El cliente local opcional inicia una ejecución independiente de Codex. En modo externo el usuario
puede indicar a la IA que consulte los casos publicados. Agent server (legacy)
no es la opción MCP; Manual ZIP conserva el intercambio manual.

## Operaciones implementadas

| Herramienta | Resultado |
|---|---|
| pmm_status | Estado y presencia de herramientas en las rutas empaquetadas |
| pmm_cases_list / pmm_case_get | Resúmenes sin rutas de proveedores ni logs |
| pmm_case_create | Caso AIIO real e inactivo de compatibilidad, reparación, creación o investigación |
| pmm_artifacts_list | Artefactos del área MCP de un caso |
| pmm_artifact_put | Datos inertes, hasta 4 MiB por archivo |
| pmm_artifact_read | Lectura base64 en bloques de hasta 64 KiB |
| pmm_reference_search | Búsqueda literal en familias hidratadas de Game Reference vigente |
| pmm_reference_export | Copia verificada por SHA-256 de una familia hidratada, hasta 64 MiB |

Los casos aparecen en AIIO al actualizar su lista. Los artefactos se guardan por ID
en Workspace/MCP/Artifacts/<caseId>/. No son automáticamente candidatos válidos.
Los ZIP se revisan/importan mediante la recepción normal de PMM y sus validaciones.
El puente asigna nombres: nunca utiliza un nombre proporcionado por la IA como
destino. La exportación de Vanilla incluye el mapa de IDs a rutas lógicas.

Preparar **Game Reference** desde PMM Settings antes de consultar Vanilla.
La preview reutiliza familias hidratadas y verifica identidad vigente, topología,
tamaños y los bytes exactos entregados. No inicia extracciones completas ni ofrece
todavía extracción bajo demanda de cualquier entrada del PAK.

## Límite de seguridad

- Herramientas y argumentos enumerados, sin comandos libres.
- Rechazo de rutas absolutas, traversal, ADS, dispositivos y junctions/enlaces.
- IDs estrictos; 128 MiB/256 artefactos por caso y máximo 1.000 casos para creación MCP.
- Mensajes limitados a 6.000.000 caracteres; cierre al exceder ese tamaño.
- Archivo de bloqueo para serializar clientes MCP.
- Registro de intentos en audit.jsonl, con una rotación de 1 MiB; sin prompts,
  contenidos ni rutas del juego. FINISHED_ATTEMPT indica fin del intento, no éxito.
- Habilitación local; no existe herramienta que permita al cliente habilitarse.
- Sin scripts recibidos, shell, URLs, descargas, guardados, activación ni Deploy.
- ZIPs guardados sin extracción. Todo contenido sigue siendo no confiable.

Es una frontera de capacidades, no una sandbox del sistema operativo.
No protege contra otro proceso local que pueda reescribir PMM, sus ajustes o
cambiar archivos/enlaces durante una operación. No exponer esta preview a
usuarios remotos no confiables.

## Pendiente para la visión completa

1. Seleccionar mods por identidad y consultar evidencia de Analyze y familias
   exactas de proveedores, con autorización por caso.
2. Adaptadores supervisados de repak/AssetReader: progreso, cancelación, timeout,
   límites de salida y verificación de hashes.
3. Hidratación Vanilla bajo demanda con presupuesto de extracción y entrega.
4. Propuestas/decisiones directamente al validador AIIO; artefactos enlazados a
   pasos del caso y control de concurrencia entre interfaz y MCP.
5. Adaptador de Unreal Editor/UnrealPak/UAssetGUI según instalación y versión.
   PMM administra rutas y ofrece operaciones concretas; nunca comandos libres.
6. Ampliar el cliente Codex local con conversación continua y otros proveedores.
   El servidor MCP por sí solo no proporciona un modelo ni chat.
7. Streamable HTTP autenticado y permisos por cliente/caso para acceso remoto.

El acceso del desarrollador al repositorio y al juego en este PC es independiente
del MCP distribuido. El MCP de producto no concede autoridad para editar PMM mismo.

## Validación

Development/Tests/mcp_bridge_regression.ps1 inicia Windows PowerShell 5.1 real:
protocolo, casos 0/1/N, transferencia, entrada hostil, revocación, junctions y
exportación hash-bound con referencia sintética.
Development/Tests/wpf_xaml_runtime_regression.ps1 materializa las tres ventanas WPF.

No son pruebas de compatibilidad entre mods reales, funcionamiento del juego,
automatización de Unreal. La conexión local Codex se validó aparte, como se describe abajo.


## Procesamiento automático y respuesta

En **AI & Help → Settings**, **Use local Codex** detecta codex.exe en PATH y
guarda la conexión local. Requiere Codex instalado y sesión iniciada; utiliza
el uso disponible de esa cuenta. No copia credenciales ni modifica la
configuración personal del cliente. **External client only** desactiva el
inicio automático de futuras ejecuciones.

Al publicar o pulsar AUTO, el worker inicia una ejecución Codex independiente,
limitada al caso y a las herramientas PMM. No envía mensajes a una conversación
de escritorio ya abierta. Deshabilita shell, plugins, agentes adicionales y
búsqueda web en ese cliente. La configuración MCP personalizada solo se aplica
a esa ejecución, con duración máxima de cuarenta minutos y salidas limitadas.

El panel **AI response** se actualiza cada segundo sin recargar el editor.
Muestra PROCESSING, RESPONSE_RECEIVED, NEEDS_INPUT, FAILED o INTERRUPTED. La
respuesta es texto de consulta; no se ejecuta ni se convierte automáticamente
en candidato. El caso conserva su paso publicado, y el resultado se guarda
aparte en Workspace/MCP/Requests. Editar y publicar el objetivo crea una nueva
solicitud; republicar el mismo objetivo con respuesta no consume otra ejecución.

Para clientes externos:
1. Consultar pmm_cases_list y pmm_case_get; comprobar mcpRequest.
2. Llamar pmm_request_claim con caseId y requestId y conservar el token.
3. Usar pmm_request_progress con el token para informar progreso y renovar
   la reserva de diez minutos.
4. Devolver texto mediante pmm_request_complete: status RESPONSE_RECEIVED,
   NEEDS_INPUT o FAILED, message y response (máximo 32.000 caracteres).
5. Leer aiReply mediante pmm_case_get. Ese campo no revela el token.

Una segunda reserva simultánea, un token incorrecto, una reserva vencida o una
respuesta a una versión antigua se rechazan. Una ejecución interrumpida puede
volver a reservarse después del vencimiento. CANCEL detiene el árbol de
procesos del worker local. Las evidencias y los archivos siguen sujetos a los
límites del puente.

Validado el 2026-09-09 con Codex real: lectura MCP del caso super inventory,
consulta de referencias y respuesta persistida como RESPONSE_RECEIVED.
Esa primera consulta detectó Game Reference ausente. La versión 0.4.0 ya lo prepara automáticamente y permite inspección estructurada.
Las pruebas mcp_exchange_regression.ps1 verifican entrega por STDIO, reservas,
versiones antiguas, aislamiento por caso y presentación WPF.

## Recursos preparados por la IA (0.3.0)

pmm_status identifica Palworld, el estado de Game Reference y las capacidades
disponibles. El cliente debe obtener de PMM lo que PMM ya conoce y preparar sus
recursos mediante herramientas antes de pedir una acción al usuario.

- pmm_reference_prepare inicia el worker existente en segundo plano; reutiliza
  una referencia vigente o una preparación en curso.
- pmm_reference_status permite esperar hasta 20 segundos y consultar progreso.
  Al llegar a Current, el cliente continúa la búsqueda en la misma ejecución.
- El worker MCP usa rutas de PMM y la instalación ya configurada; no admite rutas,
  comandos ni opciones de extracción enviados por la IA. Evita Initialize-PMM y
  la migración de carpetas. Usa el bloqueo de construcción del servicio existente.
- Se supervisa hasta 30 minutos, se detiene si MCP se deshabilita o quedan menos
  de 2 GiB libres, y se limitan los diagnósticos a 8 MiB por archivo. El cliente
  dispone de hasta 40 minutos para preparar recursos y completar la consulta.
- La preparación es compartida por la instalación. CANCEL del caso detiene la
  consulta local; la preparación compartida puede seguir hasta finalizar.
  Deshabilitar MCP detiene su worker supervisado. Una interrupción puede dejar
  staging dentro de Workspace/GameReference; no modifica el PAK de origen.

Validación real: Codex solicitó la preparación, esperó y continuó sin intervención
humana. Resultado: Current, 3.566 familias, 7.136 archivos, 70.531.561 bytes.
La consulta super inventory exportó BP_PlayerBase y DT_PalPlayerParameter como
evidencia original. No se generó un mod. La ampliación 0.4.0 expone inspección estructurada y un adaptador opcional de edición/cocinado.

mcp_reference_regression.ps1 valida el worker con repak real y un PAK sintético:
preparación, progreso, reutilización, PAK intacto, rechazo de rutas y revocación.

## Inspección estructurada y Unreal opcional (0.4.0)

La base añade pmm_asset_inspect: caseId y logicalPath exacto de una familia actual,
mode properties o datatable, query opcional, offset y limit (1–100).
Devuelve hojas JSON con ruta, nombre y valor, nextOffset y hashes de procedencia.
Consulta primero pmm_status; si falta Game Reference, usa pmm_reference_prepare
y pmm_reference_status. No delegues al usuario una operación que estas herramientas
ya pueden ejecutar. No se requiere Unreal ni Python para inspeccionar.

La inspección limita familias a 64 MiB, JSON a 32 MiB y 250.000 valores; conserva
caché por contenido, modo, lector y mappings. Revalida las partes originales en
cada llamada, incluso al reutilizar caché. Los valores muy largos se señalan como
truncados. El volcado es evidencia, no un script para ejecutar.

Validación real: super inventory consultó BP_PlayerBase y DT_PalPlayerParameter
mediante AssetReader. Encontró referencias a PalPlayerInventoryData y
GetLocalInventoryData, pero esas consultas no identificaron una propiedad de
capacidad modificable. No se construyó ni probó el mod de 100 espacios.

Los 22 tools incluyen además estado, preparación, texturas, cocinado, trabajos,
cancelación y candidatos del adaptador Unreal. Está desactivado por defecto.
Su presencia en tools/list no implica que el editor esté instalado o verificado.
Consulta pmm_unreal_status con caseId y espera el resultado real de preparación.
La instalación y los límites están en [UNREAL_SETUP.md](UNREAL_SETUP.md).

Los candidatos nuevos de Unreal son originales, con fuentes y receta registradas,
y usan PMM_GENERATED_MOD_CANDIDATE_V1. El PAK se valida con AssetReader y repak;
permanece fuera del juego y runtime UNPROVEN.

La base portable se distribuye con el adaptador inactivo: no contiene Workspace,
casos, credenciales, Vanilla, Unreal, Wwise ni el kit comunitario. Conserva los
ejecutables originales y el runtime .NET portable de PMM. Los checksums cubren
también los módulos, scripts y perfiles incluidos.


## Preview 0.5: espacios de trabajo y candidatos
Mod Creation aloja NEW_MOD; FIX LAB, FIX_MOD; Mods & Merge, COMPATIBILITY.
Help mantiene los restantes casos. Los archivos e identificadores se conservan;
el editor compartido recuerda la selección de cada sección.

pmm_archive_search busca en el índice completo del PAK configurado.
pmm_asset_prepare extrae una familia exacta (máximo cuatro partes, 64 MiB).
La inspección declara exportaciones opacas; no examina código nativo.

pmm_asset_edit acepta un JSON pointer de modo properties, un valor escalar
esperado y otro nuevo (como strings JSON). Solo modifica propiedades numéricas
o booleanas interpretadas, en una copia aislada. Rechaza exportaciones opacas.
pmm_candidate_build empaqueta y vuelve a leer el PAK para comparar hashes.
pmm_candidates_list distingue candidatos construidos de integridad fallida.
Un PAK construido sigue UNPROVEN hasta una prueba real en juego.

Herramientas opcionales: pmm_dependencies_status, pmm_dependency_install,
pmm_dependency_job y pmm_dependency_cancel. La IA no puede concederse
consentimiento. PMM muestra la propuesta; cerrar o cancelar no autoriza.
Settings permite revocar la autorización persistente. Los launchers oficiales
conservan sus pasos de cuenta/licencia. Detección no equivale a verificación UE.

Los diálogos de decisiones y errores usan los recursos del tema, igual que
Nuevo caso. Los formularios heredados reciben la misma paleta. Selectores
nativos de archivos, UAC y ventanas de instaladores siguen perteneciendo a Windows
o al fabricante.

Limitación conocida: la prueba de edición empaqueta una DataTable aislada;
no constituye el mod super inventory ni valida espacios utilizables o guardados.
