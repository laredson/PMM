# Palworld Manager Merger v1.1 — Guía de usuario

## Qué hace PMM

PMM es a la vez un manager de mods PAK de Palworld y un merger de compatibilidad. Mantiene una biblioteca local, analiza assets compartidos por varios mods, construye un único overlay de compatibilidad y despliega explícitamente los source mods seleccionados + el overlay opcional.

## Flujo normal

1. Haz doble clic en `PMM.exe`. `Start.cmd` se conserva solo como lanzador de compatibilidad. El paquete público incluye las herramientas fijadas de PMM y las verifica antes de abrir la aplicación. PMM necesita .NET Runtime 8.0.30; si ese runtime exacto no está ya disponible, Setup descarga una vez el archivo win-x64 fijado de Microsoft, verifica su SHA-512 y lo instala de forma portátil dentro de la carpeta de PMM. PMM no se compila en el PC del usuario. repak también puede obtener su runtime Oodle más adelante cuando un PAK lo necesite.
2. Detecta/selecciona la instalación Steam de Palworld.
3. Importa PAK/ZIP/7Z/RAR o importa el `~mods` actual del juego.
4. Usa los checks **On** para activar/desactivar source mods. Los PAK desactivados se conservan en la biblioteca PMM.
5. Ordena la prioridad de merge si hace falta: **arriba se aplica antes / menor prioridad; abajo se aplica después / mayor prioridad**.
6. Pulsa **Analyze**.
7. Revisa **Analysis plan**. Las filas automáticas no requieren acción.
8. Si **Resolution & Review** se abre con `DECISION REQUIRED`, elige sólo el valor/provider de la modificación que realmente se solapa.
9. Si **Blocked shared assets** muestra Unsupported, desactiva uno de los mods implicados y vuelve a Analyze o usa **CREAR ENTREGA PARA IA** para el flujo avanzado.
10. Pulsa **BUILD MERGE**. Build es local; no despliega al juego.
11. Selecciona el patch deseado en **Compatibility patches** y pulsa **DEPLOY**.

## Modo sólo manager

Selecciona **No compatibility patch** para desplegar los source mods activos sin overlay PMM. Analyze es opcional. Si hay un overlay PMM desplegado, Deploy lo retira del juego sin borrar los patches guardados.

## Patches guardados

PMM puede guardar varios patches construidos con los mismos hashes de sources + mappings, por ejemplo diferentes decisiones de un conflicto. Los compatibles tienen radio button: selecciónalo y pulsa Deploy sin reconstruir. Los patches de otro source-set siguen visibles pero no son seleccionables.

## Source mods y prioridad

- **Import** copia mods a la biblioteca de PMM. Los PAK nuevos se añaden al final/mayor prioridad hasta que los muevas.
- Arrastra una fila para insertarla antes/después de otro mod, o escribe directamente su posición final (desde 1) en **Orden**. La lista siempre se normaliza a `1..N`; los números fuera de rango se limitan a la primera/última posición y los mods intermedios se desplazan automáticamente.
- **Antes / menos prioridad** y **Después / más prioridad** siguen disponibles para mover una posición cada vez.
- La prioridad decide conflictos a nivel de dato, no un ganador de archivo entero: los cambios independientes se combinan y sólo un valor realmente solapado usa por defecto el provider que esté más abajo.
- Una elección manual en **Resolution & Review** manda sobre la prioridad. Los casos estructurales Unsupported nunca se fuerzan mediante prioridad.
- Cambiar la prioridad requiere volver a Analyze antes de crear un Build nuevo. Los patches del mismo source-set con otro orden sólo quedan como rollback explícito.
- Desmarca **On** para desactivar/respaldar un mod sin borrarlo.
- Vuelve a marcarlo para reactivarlo.
- **Delete from library** elimina la copia gestionada y registra la retirada para el siguiente Deploy.
- Deploy no borra a ciegas PAK ajenos que PMM nunca haya gestionado.

## Guardado del mundo

La pestaña **Guardado del mundo** permite crear backups de mundos y restaurarlos. PMM crea un backup de seguridad antes de sustituir el mundo durante Restore. Mantén también copias independientes de los mundos importantes.

## Qué significa Unsupported

Unsupported significa que PMM todavía no puede demostrar una composición segura para ese asset cooked exacto. No significa necesariamente que los mods sean incompatibles por diseño. Puedes desactivar un provider o usar el flujo avanzado documentado en `AI_HANDOFF_Y_CONOCIMIENTO.md`.

## Logs y problemas

Empieza por `Documentation/TROUBLESHOOTING.md` y `Logs/PalModMerger.log`. Para soporte envía **ese único archivo de log**. v1.1.1 agrupa las repeticiones exactas con contador y horas inicial/final, conservando las líneas de diagnóstico distintas. Al reportar un problema incluye la versión de PMM, el error exacto y el AI_HANDOFF/review case relevante cuando exista.

## Game Reference Vanilla y AIIO

En **Configuración**, **Crear / actualizar Game Reference** sigue disponible como caché
local opcional para investigación. PMM lee material seleccionado de tu `Pal-Windows.pak`
instalado dentro de `Data/GameReference` y nunca modifica el juego.

AIIO no necesita esa caché para crear un handoff. Cuando creas uno explícitamente, AIIO
vuelve a extraer el archivo/familia Vanilla exacto en conflicto y sus equivalentes exactos
de cada PAK implicado, y los coloca por origen dentro de un único bundle.

Después de importar una solución IA/manual y comprobarla realmente dentro de Palworld,
Configuración -> **Crear contribución probada...** genera un único ZIP de evidencia para
enviarlo al mantenedor/revisión comunitaria. Confirma PASS únicamente para la solución
exacta que hayas probado.


## Operaciones largas en v1.1 Clean

Analizar, Build y Game Reference se ejecutan en procesos worker separados. La interfaz WPF consulta los archivos de progreso, por lo que la ventana debe seguir pudiendo moverse y usarse mientras se ejecuta el trabajo pesado. No inicies otro Analyze/Build hasta que termine el actual.

Los mods fuente originales nunca se consolidan en un MegaMerge. Build crea unicamente el parche de compatibilidad de PMM.
