# PMM 1.3.3 — Análisis profundo

El panel **Análisis profundo** está encima de **Analysis plan**. La biblioteca permanece visible y el análisis de merge conserva su función.

1. Revisa la selección activa y el parche. **Buscar actualizaciones** está activado inicialmente.
2. Pulsa **Analizar en profundidad**. El trabajo se ejecuta en segundo plano y genera JSON y HTML.
3. Filtra por mod, recurso, gravedad o confianza. Haz doble clic o pulsa Enter sobre un hallazgo para consultar su evidencia.
4. **Crear caso** permite usar los hallazgos seleccionados, todos, o vincularlos a un caso existente.
5. **Investigar con GPTD** inicia una investigación persistente. **Candidatos e intentos** muestra el historial y abre sus archivos.

## Qué demuestra el informe

Se registran hashes SHA-256 completos de mods, parche, mappings y herramientas analizadas; prioridades de biblioteca; inventario del directorio de despliegue configurado; identificador de compilación Steam y versión del ejecutable cuando están disponibles.

La identidad del gran contenedor del juego utiliza metadatos. Las familias extraídas se verifican por hash; no se calcula el hash de todo el contenedor del juego. El informe distingue biblioteca, selección activa y despliegue, y no da por demostrado un orden de carga ambiguo.

Se inspeccionan contenedores PAK, recursos cooked, mapas de objetos, referencias importadas y referencias opcionales. Los recursos de Vanilla preparados aportan referencias inversas. La cobertura indica el presupuesto, los datos opacos y la parte del juego que no se ha interpretado. UE4SS, cargadores externos y archivos situados fuera del árbol Paks/~mods requieren otros adaptadores.

Una sobrescritura, un cambio intencional, un lector parcial o una diferencia respecto a Vanilla no prueban un crash. Las incompatibilidades estructurales se separan de sospechas y resultados indeterminados.

## Actualizaciones

**Origen de actualizaciones** permite vincular el archivo instalado con Nexus (mod y archivo) o GitHub (repositorio, etiqueta instalada y nombre exacto del archivo de la variante). La clave Nexus opcional se cifra para el usuario de Windows.

Las importaciones nuevas conservan identidad del archivo y contenido. Para importaciones antiguas, una ruta o un nombre no bastan: PMM comprueba el contenido del ZIP cuando está disponible. Los resultados pueden indicar identidad desconocida, autenticación pendiente, límites del proveedor o falta de conexión.

Nexus sigue las sucesiones de archivos publicadas por el autor y bloquea ramificaciones ambiguas. GitHub compara versiones estables con el mismo nombre de archivo. Los cambios y requisitos requieren revisión: una publicación posterior no demuestra compatibilidad.

Las actualizaciones autorizadas se descargan a la sesión. Se conservan el original y los hashes, se leen los PAK y se analiza el conjunto propuesto antes de una aplicación. La selección de múltiples PAK y los formatos sin adaptador de extracción quedan pendientes. Un candidato preparado no sustituye automáticamente la biblioteca ni el despliegue.

## Investigación persistente y límites actuales

PMM guarda una conversación App Server por caso. Se han comprobado autenticación, creación, continuación tras desconexión, progreso, interrupción, conservación del historial y una llamada real al MCP acotada al caso.

**Solución automática está en preview.** En el runtime Windows validado, una conversación abierta por el escritorio puede quedar bajo su control exclusivo. El canal compartido del daemon no está disponible en Windows. PMM conserva la misma identidad, pausa y explica la intervención necesaria; no crea una conversación alternativa. Abrir el enlace no se considera confirmación de entrega.

La investigación utiliza los servicios de PMM para preparar actualizaciones, consultar conocimiento local y construir candidatos o merges. Las operaciones de modificación exigen revisión vigente y autorización de sesión. Los límites iniciales son 40 minutos activos, 6 candidatos distintos y 12 ejecuciones registradas; el estado se conserva al alcanzar un límite.

Las opciones de despliegue temporal, ejecución del juego, mundo temporal y aislamiento permanecen desactivadas y bloqueadas hasta validar un adaptador de aislamiento. Se conservan los modelos de ejecución y la planificación de subconjuntos con dependencias, pero no constituyen un ciclo de pruebas del juego terminado. La entrada supervisada al mundo y la comprobación de funciones aún requieren aceptación real del adaptador.

Las transacciones de despliegue disponen de recuperación duradera y bloqueo por instalación. Una recuperación incompleta bloquea otro despliegue y las modificaciones externas no se sobrescriben. El conocimiento se intercambia localmente; no existe un receptor remoto configurado.

No se ha ejecutado Palworld ni modificado los mods instalados para validar esta versión. La automatización completa no está aceptada.

## Nivel de IA y cuenta

**Nivel de IA** permite detectar la cuenta o elegir un perfil gratuito/conservador, de pago o de chat manual. La primera etapa utiliza gpt-5.6-luna, esfuerzo low y velocidad estándar. Los índices, hashes, comparaciones y comprobaciones deterministas los ejecuta PMM sin consultar un modelo.

El límite inicial permite solo consultas sencillas. Puede ampliarse a diagnóstico con Terra/medium y diseño complejo con Sol/high. El agente debe registrar el intento bloqueado y su motivo antes de solicitar otra etapa. PMM mantiene la misma conversación y respeta el límite de la sesión. Cada petición especifica modelo y esfuerzo; si no están disponibles o el servidor confirma otros valores, PMM pausa. No se heredan Astra ni velocidad rápida como alternativa silenciosa.

El plan detectado y el catálogo real prevalecen sobre una preferencia de cuenta de pago. Una cuota agotada pausa la investigación. Un resultado de cuota desconocido se muestra como desconocido. La facturación API requiere su opción independiente. Los archivos turn-request*.json y usage-*.json de la sesión conservan la selección, su confirmación y el consumo comunicado por el runtime; no prueban detalles internos de ejecución que el servidor no expone.

El chat manual prepara un texto para trasladarlo y devolver la respuesta al caso. PMM no controla el modelo elegido allí ni confirma automáticamente su entrega. Los chats también usan tokens y pueden tener límites; ChatGPT Work comparte uso con Codex. [Documentación oficial de uso](https://learn.chatgpt.com/docs/pricing).

**Continuar investigación** retoma las etapas pendientes con la misma identidad. Los cambios en la política afectan a las siguientes peticiones, sin alterar un turno activo.

## Desktop y la pestaña Chat IA

Elige **ChatGPT Desktop** o **Codex Desktop** como destino del caso y pulsa enviar/abrir. PMM prepara una petición para que el chat presente un informe inicial y puedas elegir el resultado: una versión actualizada del mod, una receta KL de Fix Lab u otro objetivo. Envía el mensaje preparado en Desktop; abrir un enlace no confirma su recepción por MCP. Si tu versión instalada de ChatGPT no admite enlaces a chats MCP locales, usa Codex Desktop o actualiza ChatGPT. PMM distingue las dos aplicaciones.

Las peticiones internas son opcionales: selecciona **Avanzado: agente interno**, abre **Chat IA > Avanzado**, habilítalas expresamente en los ajustes de cuenta, elige la etapa, revisa el modelo y esfuerzo indicados y escribe el prompt. La autorización para crear candidatos y descargar actualizaciones es independiente de ejecutar o desplegar en el juego. Cada envío inicia un único turno; subir de modelo queda como sugerencia. Cancelar conserva la conversación.

**Actualizar conversación** recupera el historial público existente sin iniciar inferencia. La carpeta Chat del caso conserva todos los eventos guardados; la interfaz muestra los últimos 300 junto con los registros de modelo y uso. Se guardan las operaciones públicas de las herramientas, no el razonamiento privado. Los contadores del proveedor pueden solaparse o reiniciarse; no se suman como si fueran una factura. No se garantiza un canal automático gratuito o sin consumo.
