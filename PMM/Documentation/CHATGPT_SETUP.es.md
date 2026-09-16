# Vincular ChatGPT Desktop con PMM

ChatGPT Desktop es un cliente opcional. Cada caso puede elegir **ChatGPT Desktop**, **Otro cliente MCP** o **Codex por consola**. Desktop y otros clientes usan `Transport=MCP`; solo el destino por consola necesita Codex CLI. Unreal y Wwise siguen siendo herramientas opcionales para determinados trabajos de creación y cocinado.

## Primera vinculación

1. En **Settings > Instalaciones**, detecta o instala ChatGPT. Al pulsar **Enviar a ChatGPT** sin la aplicación, PMM también ofrece instalarla mediante el servicio de instalaciones existente. Solicita modo silencioso a WinGet; los permisos, el inicio de sesión y cualquier paso del instalador oficial siguen bajo tu control. ChatGPT no va incluido en el ZIP de PMM.
2. En **Settings > IA / MCP**, pulsa **Conectar ChatGPT**. Inicia sesión en el cliente. El diálogo muestra qué aplicación y versión detectó; una versión antigua que no registra `codex://` requiere actualizarse para abrir chats locales.
3. Selecciona o crea en el cliente un proyecto local cuya carpeta sea la instalación que contiene `PMM.exe`. PMM utiliza su subcarpeta `Workspace` para casos y trabajo temporal. No crea otra ubicación fija en C:. Puedes elegir una carpeta adicional; debes conceder su acceso por separado en el cliente.
4. Pulsa **Configuración MCP**. La configuración generada está en `Workspace/MCP/codex-mcp.toml` y `mcp-config.json`. Importa o añade la entrada PMM mediante los ajustes MCP del cliente, conservando las entradas de otros servidores, y reinícialo. PMM genera ejemplos; no sobrescribe tu configuración de cliente. Agregar la carpeta del proyecto no configura MCP por sí solo.
5. Pulsa **Abrir chat de sincronización** y envía el texto preparado. Pide a la IA que ejecute `pmm_desktop_pair` con el código mostrado. El código es de un solo uso y caduca a los 30 minutos. Si caduca, usa **Volver a vincular**.
6. Pulsa **Comprobar conexión**. Solo una llamada MCP correcta verifica la vinculación. Abrir la aplicación no demuestra que haya sesión iniciada o MCP conectado. La llamada tampoco certifica la marca del cliente, su plan ni sus permisos de archivos.

La vinculación se guarda por instalación en `Workspace/MCP/Desktop/binding.json`, sin credenciales. Después de verificarla, los casos nuevos de la interfaz usan ChatGPT por defecto; los casos existentes conservan su destino. Si mueves PMM, regenera la configuración y vuelve a vincularlo. La carpeta guardada anteriormente no verifica la instalación nueva.

## Enviar y continuar un caso

- Selecciona el caso, elige **ChatGPT Desktop** en **Cliente** y pulsa **Enviar a ChatGPT**. PMM guarda y publica la solicitud antes de abrir el cliente. El botón AUTO de ese caso utiliza el mismo destino; no arranca Codex CLI.
- PMM abre el enlace oficial `codex://threads/new` con `path` y el mensaje que identifica el caso y la solicitud. El enlace prepara el texto; **no lo envía**. Si falta el proyecto, selecciona o crea el proyecto local en el cliente: PMM no consulta bases de datos internas ni afirma haberlo creado.
- Un adaptador de accesibilidad intenta enviar solo si verifica la aplicación, la ventana activa, la carpeta seleccionada y el texto exacto, y encuentra un único botón Enviar. No acepta permisos ni utiliza coordenadas. **El envío automático real aún no está validado.** Si no puede verificarlo, el mensaje queda preparado para que pulses Enviar; el estado de PMM lo indica. Volver a pulsar el botón muestra también la solicitud para copiarla.
- La primera solicitud exige investigar, presentar el plan y esperar tu aprobación antes de editar, construir, instalar o desplegar. Es una instrucción de trabajo, no una activación comprobada del modo Plan nativo del cliente.
- La IA reclama la solicitud mediante `pmm_request_claim` y comunica su fase con `pmm_desktop_case_link`. Si dispone de un identificador real del chat, puede asociarlo al caso. PMM reabre ese chat para continuar; si no conoce su identificador, ofrece la solicitud preparada y la apertura asistida. No puede descubrir chats arbitrarios.
- Un doble clic no abre automáticamente otro chat. Una solicitud en proceso bloquea otro ejecutor. Para continuar después de un resultado, edita el caso y crea el seguimiento; si hay chat asociado, se abre y el texto nuevo se copia/envía de forma asistida.
- **Cancelar** cancela la solicitud pendiente en PMM. Un mensaje ya enviado permanece en ChatGPT: detén también ese chat si está trabajando. No se cierran a la fuerza el cliente ni los instaladores.

PMM distingue texto preparado, mensaje enviado pendiente de recepción, solicitud recibida, investigación, espera de aprobación y resultado. Una ventana abierta o un paquete construido no son prueba de trabajo de la IA ni de funcionamiento del mod.

## Alcance del acceso y pruebas

Dar al cliente acceso a toda la carpeta PMM también puede darle acceso a su código. El texto solicita trabajar en `Workspace` y usar MCP. PMM valida las operaciones y rutas de su servidor, pero no restringe la consola, los archivos ni el control de Windows que concedas a otras herramientas del cliente. Inicio de sesión, confianza y permisos siguen siendo decisiones tuyas.

Prueba los candidatos con guardados aislados y conserva el despliegue anterior. Separa siempre «construido» de «probado en Palworld». El control visual es opcional y depende de un escritorio disponible y de la accesibilidad del cliente. Se mantiene la alternativa de informar manualmente «funciona», «crashea» y aportar evidencias.

Las pruebas locales cubren contratos MCP, códigos de vinculación, destinos, cancelación, reapertura mediante identificador conocido, doble clic, persistencia y controles en español/inglés. La instalación real desde cero, el envío por accesibilidad y el recorrido completo con una cuenta Free siguen **pendientes**. Free no garantiza autonomía ilimitada. Tampoco se da por validado el mod de inventario.

## Fuentes oficiales

- [Enlaces y comandos de chats](https://learn.chatgpt.com/docs/reference/commands#chats)
- [MCP](https://learn.chatgpt.com/docs/extend/mcp)
- [Proyectos locales](https://learn.chatgpt.com/docs/projects)
- [Instalación en Windows](https://learn.chatgpt.com/docs/enterprise/windows-deployment)
- [Planes](https://learn.chatgpt.com/docs/pricing)
- [Control del ordenador](https://learn.chatgpt.com/use-cases/use-your-computer-with-codex)
