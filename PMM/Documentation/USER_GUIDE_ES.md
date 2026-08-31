# Palworld Manager Merger v1.3.0 — Guía de usuario

**Flujo guiado:** PMM ilumina solo la siguiente etapa útil: **Importar -> Fix Lab cuando sea necesario -> Analizar -> Build -> Deploy -> Jugar**. El color depende del estado real. Durante Importar/Analizar/Build/Deploy el propio boton iluminado sirve tambien como progreso, mientras la barra persistente bajo Build/Deploy conserva el ultimo porcentaje/resultado hasta que empiece otra operacion.

## Qué hace PMM

PMM es a la vez un manager de mods PAK de Palworld y un merger de compatibilidad. Mantiene una biblioteca local, analiza assets compartidos por varios mods, construye un único overlay de compatibilidad y despliega explícitamente los source mods seleccionados + el overlay opcional.

## Flujo normal

1. Haz doble clic en `PMM.exe`. Es el lanzador normal y el unico archivo de aplicacion expuesto en la raiz portable. El paquete público incluye las herramientas fijadas de PMM y las verifica antes de abrir la aplicación. PMM necesita .NET Runtime 8.0.30; si ese runtime exacto no está ya disponible, Setup descarga una vez el archivo win-x64 fijado de Microsoft, verifica su SHA-512 y lo instala de forma portátil dentro de la carpeta de PMM. PMM no se compila en el PC del usuario. repak también puede obtener su runtime Oodle más adelante cuando un PAK lo necesite.
2. PMM intenta resolver Palworld automáticamente. La tarjeta de estado de instalación de la cabecera también es el botón **Detectar**. Permanece visible y solo se activa cuando hace falta actuar; al validar Palworld sigue visible, pero desactivada. Si una pulsación manual tampoco detecta Palworld, PMM abre un único selector para elegir una carpeta de Steam o de Palworld. Los controles para detectar o cambiar la instalación también siguen disponibles en **Opciones**.
3. Importa PAK/ZIP/7Z/RAR o importa el `~mods` actual del juego.
4. Usa los checks **On** para activar/desactivar source mods. Los PAK desactivados se conservan en la biblioteca PMM.
5. Ordena la prioridad de merge si hace falta: **arriba se aplica antes / menor prioridad; abajo se aplica después / mayor prioridad**.
6. Pulsa **Analyze**.
7. Revisa **Analysis plan**. Las filas automáticas no requieren acción.
8. Si **Resolution & Review** se abre con `DECISION REQUIRED`, elige sólo el valor/provider de la modificación que realmente se solapa.
9. Si **Blocked shared assets** muestra Unsupported, desactiva uno de los mods implicados y vuelve a Analyze o abre **IA y ayuda > Reparacion IA / AIIO** para una tarea persistente. La accion heredada **CREAR ENTREGA PARA IA** sigue disponible.
10. Pulsa **BUILD MERGE** cuando ColorFlow lo solicite. Si Analyze demuestra que un patch existente aun cubre el conjunto efectivo de conflictos, PMM omite Build automaticamente. Build es local; no despliega al juego.
11. Selecciona el patch deseado en **Compatibility patches** y pulsa **DEPLOY**.

## Cabecera y rutas de Palworld

La cabecera usa el icono PMM transparente ampliado, el nombre en tres líneas **PALWORLD / MANAGER / MERGER** y su subtítulo. En una ventana ancha, marca y acciones ocupan mitades iguales; con poco ancho, las acciones pasan debajo. La tarjeta de estado es también la acción Detectar: se activa cuando hace falta actuar y queda desactivada tras validar la instalación. Debajo están **Abrir carpeta del juego**, **Abrir carpeta de mods** e **Iniciar Palworld**; la última fila contiene **Auto ON**, **Ejecutar Palworld tras Deploy** y **AUTO** de una sola ejecución. La ruta completa, Detectar/cambiar instalación, **Elegir carpeta de Steam** / **Elegir carpeta de Palworld** y el diagnóstico siguen en **Opciones**. **Abrir carpeta de mods** abre o crea `Pal\Content\Paks\~mods`.

## Modo sólo manager

Selecciona **No compatibility patch** para desplegar los source mods activos sin overlay PMM. Analyze es opcional. Si hay un overlay PMM desplegado, Deploy lo retira del juego sin borrar los patches guardados.

## Patches guardados

PMM puede conservar varios patches, por ejemplo con decisiones distintas para un conflicto. Una coincidencia exacta del source-set se puede seleccionar inmediatamente. Despues de Analyze, PMM tambien puede reutilizar un patch cuando siguen coincidiendo todos los participantes efectivos de conflicto, hashes de providers, adapters, decisiones, mappings y la entrada Vanilla, aunque se hayan activado o desactivado mods unicos no relacionados. En ese caso se omite Build y Deploy solo sincroniza los PAK fuente modificados. Un patch cuya compatibilidad no este demostrada permanece visible, pero desactivado.

## Source mods y prioridad

- **Import** copia mods a la biblioteca de PMM. Los PAK nuevos se añaden al final/mayor prioridad hasta que los muevas.
- Arrastra una fila para insertarla antes/después de otro mod, o escribe directamente su posición final (desde 1) en **Orden**. La lista siempre se normaliza a `1..N`; los números fuera de rango se limitan a la primera/última posición y los mods intermedios se desplazan automáticamente.
- **Antes / menos prioridad** y **Después / más prioridad** siguen disponibles para mover una posición cada vez.
- La prioridad decide conflictos a nivel de dato, no un ganador de archivo entero: los cambios independientes se combinan y sólo un valor realmente solapado usa por defecto el provider que esté más abajo.
- Una elección manual en **Resolution & Review** manda sobre la prioridad. Los casos estructurales Unsupported nunca se fuerzan mediante prioridad.
- Cambiar la prioridad requiere volver a Analyze antes de crear un Build nuevo. Los patches del mismo source-set con otro orden sólo quedan como rollback explícito.
- Desmarca **On** para desactivar/respaldar un mod sin borrarlo.
- Vuelve a marcarlo para reactivarlo.
- La lista de mods permite seleccion multiple con **Ctrl/Shift** y **Ctrl+A**. Usa **Activar seleccionados**, **Desactivar seleccionados** o **Borrar seleccionados** para modificar un grupo. Los botones de prioridad requieren intencionadamente un solo mod seleccionado.
- **Importar...** abre un unico selector: **Importar mods...** permite elegir uno o varios PAK/ZIP/7Z/RAR, mientras **Importar carpeta...** importa todos los archivos compatibles contenidos directamente en una carpeta. Los comprimidos solo se usan como entrada temporal; a la biblioteca entran sus PAK extraidos. **Importar ~mods** es la opcion guiada cuando Palworld ya contiene PAK fuente que PMM necesita incorporar a su biblioteca.
- **Borrar seleccionados** es inmediato: elimina la copia importada de PMM y el mismo hash de Palworld `~mods` si esta desplegado alli. Un archivo con el mismo nombre pero SHA-256 diferente bloquea el borrado. Cualquier merge de compatibilidad PMM desplegado y su sidecar se conservan hasta que los cambies explicitamente en **Compatibility patches**; la vigencia de Analyze se invalida para que PMM explique el nuevo estado de fuentes.
- Deploy no borra a ciegas PAK ajenos que PMM nunca haya gestionado.

## Saves

La pestaña **Saves** permite crear backups de mundos y restaurarlos. PMM crea un backup de seguridad antes de sustituir el mundo durante Restore. Mantén también copias independientes de los mundos importantes.

## IA y ayuda y AIIO local

**IA y ayuda** separa Ayuda y diagnostico, Reparacion IA/AIIO, Feedback, Knowledge, el editor de esquemas y Opciones IA. Ayuda sirve para describir y conservar un problema; Reparacion IA prepara una tarea para razonamiento externo y mantiene sus respuestas/candidatos. **Preparar para IA** crea un ZIP local para que tu decidas donde enviarlo. PMM no tiene login de proveedor ni sube nada automaticamente. Un ZIP devuelto es dato no confiable: se rechazan scripts, ejecutables, rutas inseguras y archivos anidados, y cada candidato queda en staging hasta revisarlo.

Feedback crea JSON inspeccionable para un comentario general, una incidencia de PMM, un merge/validacion exacto o Knowledge/CKL. Compartir sigue siendo manual y el control de subida muestra una conexion futura desactivada. Validar normalmente o esperar una respuesta IA no enciende el contador principal; el contador se reserva para Unsupported, errores reales, operaciones interrumpidas o una respuesta que requiere revision. Los fallos identicos reutilizan un caso y cada diagnostico reutiliza su sesion activa.

Solo un candidato cooked-family `PMM_MANUAL_SOLUTION_V1` que coincida exactamente con el caso actual puede mostrar **Usar candidato en Merge**. Confirmarlo fuerza Analyze; nunca inicia Build ni Deploy. La validacion del build y los archivos de feedback son locales y deterministas. Consulta `AI_HANDOFF_AND_KNOWLEDGE.md`.

Opciones aplica a los temas la misma arquitectura que a los sonidos: once JSON fijados por hash mas Noche/Claro permanecen en oficiales; lo que añade el usuario aparece en una coleccion separada de `Workspace\Themes`. El editor de IA y ayuda ofrece color de respaldo e imagen local opcional para cada brush de paleta/ColorFlow.

## Qué significa Unsupported

Unsupported significa que PMM todavía no puede demostrar una composición segura para ese asset cooked exacto. No significa necesariamente que los mods sean incompatibles por diseño. Puedes desactivar un provider o usar el flujo avanzado documentado en `AI_HANDOFF_Y_CONOCIMIENTO.md`.

## Logs y problemas

Empieza por `Documentation/TROUBLESHOOTING.md` y `Logs/PalModMerger.log`. Para soporte envía **ese único archivo de log**. v1.1.1 agrupa las repeticiones exactas con contador y horas inicial/final, conservando las líneas de diagnóstico distintas. Al reportar un problema incluye la versión de PMM, el error exacto y el AI_HANDOFF/review case relevante cuando exista.

## Game Reference Vanilla y AIIO

En **IA y ayuda > Opciones IA**, **Crear / actualizar Game Reference** mantiene una caché local con identidad de versión. PMM lee material seleccionado de tu `Pal-Windows.pak` dentro de `Workspace/GameReference` y nunca modifica el juego. El análisis normal no necesita una referencia completa, mientras que las recetas de Fix Lab pueden pedir y conservar familias actuales adicionales bajo demanda.

AIIO no necesita esa caché para crear un handoff. Cuando creas uno explícitamente, AIIO
vuelve a extraer el archivo/familia Vanilla exacto en conflicto y sus equivalentes exactos
de cada PAK implicado, y los coloca por origen dentro de un único bundle.

Después de importar una solución IA/manual y comprobarla realmente dentro de Palworld,
IA y ayuda -> Feedback -> **Crear contribución probada...** genera un único ZIP de evidencia para
enviarlo al mantenedor/revisión comunitaria. Confirma PASS únicamente para la solución
exacta que hayas probado.


## Operaciones largas en PMM 1.3

Analizar, Build, Game Reference y Repair de Fix Lab se ejecutan en procesos worker supervisados. La ventana WPF sigue disponible para navegar, redimensionar, revisar el progreso y cancelar mientras una reparación larga está en curso. El progreso real se refleja tanto en el botón activo como en la barra universal persistente bajo Build/Deploy. Las barras determinadas muestran cada nuevo tramo confirmado de uno en uno durante unos tres segundos: pueden ir por detrás del worker, pero nunca muestran un porcentaje que el worker no haya alcanzado. Una actualizacion real al 100% salta inmediatamente a 100 y borra la animacion pendiente antes de la tarea siguiente. La barra conserva el ultimo 100% hasta que empiece otra operacion. Las operaciones correctas ya no abren popups de finalizacion; las confirmaciones, avisos que requieren una decision y los errores siguen apareciendo cuando es necesario.

Los cinco outputs completos de Gawr Gura Case 001 son variantes excluyentes. Si hay dos activas, Analyze se detiene antes de enumerar/extraer las familias grandes de modelo y pide elegir una en **Resolution & Review**. Tras elegir, vuelve a pulsar Analyze: la alternativa queda en la biblioteca local, pero se excluye del analisis y del siguiente Deploy.

Los mods fuente originales nunca se consolidan en un MegaMerge. Build crea unicamente el parche de compatibilidad de PMM.


### Gestion de mods importados y merges guardados

Los controles justo debajo de **Mod library** pertenecen a los mods importados. Ctrl/Shift/Ctrl+A permite seleccionar varias filas y **Activar seleccionados**, **Desactivar seleccionados** o **Borrar seleccionados** actua sobre el grupo. La zona **Compatibility patches** tiene **Validar merge** y **Borrar merge**. **UNDEPLOY** retira solamente el merge exacto seleccionado de `~mods` de Palworld y conserva el build guardado dentro de PMM. **Borrar merge** retira la copia desplegada exacta si existe, borra todas las copias/manifests guardados coincidentes, su seleccion y su registro de validacion; nunca borra mods fuente. PMM no recrea silenciosamente un build guardado solo porque detecte un merge PMM desplegado en `~mods`.


### Modo automatico y Cancelar

**ColorFlow y AUTO usan la misma máquina de estados.** El orden es `Detectar (solo si hace falta) -> Importar -> [Fix Lab si corresponde: Game Reference -> elegir output -> Repair -> Apply Fix] -> Analyze -> Build Merge -> Deploy -> listo para jugar`. **Auto ON** es la continuación persistente: si está marcado, una acción del flujo iniciada manualmente continúa por los pasos seguros restantes. El botón **AUTO** de la cabecera es distinto: ejecuta una vez el flujo restante sin activar Auto ON. AUTO puede importar directamente la fuente conocida `~mods` de Palworld; una importación arbitraria de archivos/carpeta sigue esperando que el usuario elija. Tras un despliegue actualizado, ColorFlow solo ilumina **Iniciar Palworld** como estado opcional disponible: no abre un aviso de accion requerida ni obliga a iniciar el juego. **Ejecutar Palworld tras Deploy** controla únicamente el inicio automático y sigue desactivado por defecto.

Si PMM reconoce la identidad exacta de un mod antiguo/roto soportado por Fix Lab, Fix Lab pasa a ser el siguiente estado de ColorFlow/AUTO **antes del Analyze normal**. Si la receta necesita Current Game Reference y no está actual, AUTO la construye directamente en background. Una sola salida puede seleccionarse automáticamente; con varias salidas se detiene en **elegir output**. Después de Repair y **Apply Fix**, Fix Lab queda resuelto y el siguiente estado común es **Analyze**. Ignorar este mod antiguo omite Fix Lab para ese hash exacto bajo responsabilidad del usuario.

**CANCELAR** funciona tanto en modo manual como automático. Los workers de Analyze/Build/Fix Lab/AIIO se detienen; Import cancela cooperativamente el extractor hijo; Deploy usa el rollback verificado normal si ya había comenzado a aplicar archivos gestionados.

En Fix Lab puedes usar Ctrl/Shift para seleccionar varias fuentes de la biblioteca en un mismo trabajo. La primera se guarda como fuente primaria y las demás como evidencia relacionada/histórica. Gura Case 001 puede generar localmente las cinco salidas documentadas desde la fuente v5 exacta **Normal** o **FullReplacement**, junto con Current Game Reference y recetas CKL compactas. Original Full Replacement, **Normal - Locked** (confirmado dentro del juego el 2026-08-27, pelvis incluida) y Hair2/Panties tienen evidencia runtime. Red/Evil y Hooded son reparaciones desplegables validadas estructuralmente cuya aceptación runtime aún no está registrada. Fix Lab muestra esta evidencia como un nivel de confianza en Built outputs y no presenta una ventana de aviso adicional antes de Apply Fix; `DeployAllowed` es el bloqueo real de despliegue. La página responsive de Fix Lab organiza Fuente, Configurar reparación, Construir y validar, Outputs, Backups y Advanced/AIIO como etapas colapsables. La navegación usa el panel en cache y programa la hidratacion periodica despues del cambio visual; **Actualizar Fix Lab** solicita un refresco inmediato. Apply Fix y Restaurar mod original nunca retiran ni sustituyen un merge de compatibilidad desplegado.


## Ciclo de vida de merges en PMM 1.3

- **Deploy**: instala/sincroniza en Palworld el merge compatible seleccionado.
- **Undeploy**: elimina solamente ese PAK exacto y su sidecar de `~mods`; conserva el build guardado en PMM.
- **Borrar merge**: hace undeploy del hash exacto si esta presente y borra las copias/manifests guardados coincidentes dentro de PMM. Nunca se borra un archivo del mismo nombre con otro hash.
- **Validar merge**: registra ese hash exacto como probado por el usuario dentro del juego.
- Ya no existe una operacion Archive visible para el usuario. `Builds\Previous` es solo historial interno.
- `Import ~mods` importa mods fuente, pero solo *reconoce* los PAK de merge generados por PMM; no vuelve a crear silenciosamente builds guardados que el usuario borro.
### Game Reference + eleccion de output en paralelo

Cuando un caso compatible de Fix Lab necesita Current Game Reference, PMM inicia/crea primero la referencia. Si el caso tiene varias salidas, elegir output es una decision humana paralela: ColorFlow la marca mientras Game Reference sigue creandose. AUTO permanece preparado mientras espera. Si eliges durante la creacion, AUTO continua a Repair en cuanto la referencia queda lista; si esperas, esa misma eleccion sigue siendo la accion requerida al terminar la referencia. La caja de fuente tambien ofrece **Ignorar este mod antiguo** y **Borrar este mod**; Delete usa la misma operacion exact-hash de borrado en todas partes que Imported Mods.

### AUTO mientras Fix Lab crea Game Reference

Si una reparacion detectada necesita Game Reference, AUTO invoca primero **el mismo comando canonico Crear / actualizar Game Reference que usa IA y ayuda > Opciones IA**, antes de cualquier cambio de pestana a Fix Lab. Asi no existe una segunda ruta de arranque exclusiva de AUTO. Cuando AUTO encuentra por primera vez ese caso, abre **Fix Lab una sola vez** para mostrar el caso y la eleccion de output. Despues de esa presentacion inicial, las pestanas vuelven a estar bajo control del usuario: si vas a otra pestana mientras Game Reference se crea, el watchdog no te devuelve a Fix Lab. El mismo estado/barra de progreso se muestra en Opciones IA y Fix Lab. Si la reparacion tiene varias salidas, puedes elegir una en cualquier momento mientras se crea la referencia; AUTO reanuda en cuanto esten listas tanto la referencia como tu eleccion. Una Game Reference iniciada manualmente tambien reanuda una cadena AUTO que ya estaba activa al terminar; con Auto ON, iniciar Game Reference manualmente arma la continuacion igual que cualquier otro paso del flujo.

Los pasos completados correctamente ya no muestran ventanas informativas de OK. **Opciones** permite configurar por separado el esquema de color y cada evento de sonido, con sonidos integrados o custom y volumen 0-100% (50% por defecto). Los dos perfiles de microondas siguen siendo distintos: **Final de microondas** y **3 pitidos**. Los pasos manuales usan el perfil Manual; AUTO/Auto ON usa los perfiles Auto/Semiauto configurados.


### Apariencia

PMM sigue usando WPF/XAML. La capa visual dispone ahora de una paleta completa Claro/Oscuro, tarjetas, tablas, inputs y pestanas tematizadas y una cabecera principal mas grande. El tema se aplica con **Aplicar cambios**, actualiza toda la interfaz sin reiniciar PMM y se guarda en `Workspace/State/config.json`. El modo Noche usa superficies neutras oscuras y botones neutros mas oscuros, conservando los colores semanticos de Fix Lab/ColorFlow.

### Comportamiento de ajustes RC14
La apariencia, duración del aviso, sonido y volumen se preparan en Ajustes y se confirman con **Aplicar cambios**. Los temas Claro/Noche usan recursos WPF dinámicos para que toda la interfaz cambie sin reiniciar PMM.

## RC17 apariencia, sonidos y navegador de backups

Las instalaciones nuevas usan **PMM Crystal** por defecto y conservan la eleccion valida de una instalacion existente. Configuracion separa **Esquema de color** y **Sonido de finalizacion** en listas independientes. **Agregar esquemas (JSON/ZIP)...** admite uno o varios JSON `PMM_COLOR_SCHEME_V1`, o un ZIP acotado, y guarda solo esquemas validados en `Workspace\Themes`; **Agregar sonido...** copia un WAV/MP3/WMA a `Workspace\Sounds`. Pulsa **Aplicar cambios** para aplicar tema, duración del aviso ColorFlow, sonido y volumen sin reiniciar PMM. **Restaurar valores**, situado junto a Aplicar en la esquina superior derecha, prepara PMM Crystal, aviso de 5 segundos, volumen 50% y los perfiles de sonido RC19 sin cambiar idioma, rutas, biblioteca ni datos del usuario; pulsa Aplicar para guardarlos.

La pestana Partidas tiene ahora dos paneles colapsables a la derecha: **Save seleccionado** y **Backups PMM creados**. Al seleccionar un backup se muestran fecha, tamano ZIP, tamano expandido, numero de archivos y una comparacion simple con el save actual. Restaurar utiliza el backup PMM seleccionado y crea antes un backup de seguridad.


### Eventos de sonido
Settings -> Eventos de sonido permite configurar Auto, Semiauto, Manual, Atencion requerida y Error por separado. Los sonidos integrados aparecen separados de los sonidos custom importados. `Sonido en cada paso de AUTO` esta activado por defecto y controla el aviso Semiauto; elegir un sonido Semiauto concreto lo activa, mientras que elegir `Ninguno` o desmarcar la casilla lo silencia. `Sonido cuando se requiera atencion` controla los avisos de decisiones. Iniciar Palworld manualmente es deliberadamente silencioso; el sonido Auto solo se reproduce cuando termina todo el flujo automatico.

RC22 conserva las asignaciones de sonido de RC19 y corrige el interruptor maestro de Semiauto: Auto = Final de microondas, Semiauto = OK, Manual = Good, Atención requerida = Alerta corta, Error = 3 pitidos. Las configuraciones de RC21 se migran una vez para que un sonido Semiauto asignado sea audible salvo que esté en `None`; la casilla sigue permitiendo silenciarlo. OK y Good son sonidos oficiales incluidos. El globo Action required de Configure repair usa un color de decision propio para contrastar con el panel ambar de Configure repair.
