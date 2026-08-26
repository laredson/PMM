# Palworld Manager Merger (PMM)

## Haz que mods de Palworld que entran en conflicto funcionen juntos

**Palworld Manager Merger analiza tus mods PAK y crea un parche de compatibilidad para que mods que normalmente se sobrescribirían entre sí puedan funcionar juntos.**

También funciona como un manager práctico: importar mods, activarlos o desactivarlos, conservar backups, desplegar tu configuración, cambiar entre merges guardados y hacer backup o restaurar tus mundos de Palworld.

### Todo el proceso

**Descomprime donde quieras -> Import -> Analyze -> Build -> Deploy -> Jugar.**

PMM intenta encargarse de la parte complicada. Si varios mods editan el mismo archivo pero sus cambios pueden convivir, los combina. Si realmente quieren valores diferentes para la misma cosa, te pregunta cuál quieres. Si no puede demostrar un merge seguro, te lo dice en lugar de generar a ciegas un parche roto.

**PMM es open source y transparente:** el código PowerShell/WPF de la aplicación y el código C# del merger/reader están incluidos en la descarga bajo licencia MIT.

También puedes seleccionar **Sin parche de compatibilidad** y usar PMM solamente como mod manager. En ese modo Deploy instala los source mods activos y retira del juego cualquier overlay de merge de PMM.

---

## Probado funcionando junto

Los siguientes se han probado correctamente dentro de Palworld como parte de la misma configuración grande de mods:

- **FlyMode**
- variantes finitas de **MultiJump**, incluyendo Double / Triple / Quad
- **WingPack - No Wing Cells / Visible Only While Flying**
- **Food Never Spoils**
- **Stack Size / Zero Weight**
- **Early Aquatic Construction Kit**
- **Easy Breeding**
- **No Collision Farms and Expeditions**
- **Free Enhance Player Ability**
- **Increased Player Stat Caps 1000**
- **RushRoar Leather Drop**
- muchos otros PAK que usan archivos independientes

Un buen ejemplo es **MultiJump + Fly + Wing**. PMM puede conservar el número de saltos finito elegido, mantener los cambios independientes de Fly y conservar a la vez el comportamiento compatible de Wing. En la configuración probada puedes hacer los saltos elegidos, entrar en Fly y ver las alas durante el vuelo mientras los demás mods fusionados siguen funcionando.

Lo importante es que PMM **no está limitado a esos nombres**. Analiza los archivos reales que le das.

---

## ¿Qué otros mods deberían funcionar?

En principio, cualquier PAK cuyos cambios PMM pueda combinar de forma segura es candidato.

Son especialmente interesantes los mods que normalmente se describen como incompatibles simplemente porque modifican la misma:

- DataTable de parámetros de Pals — velocidad de monturas, stamina, work suitability, stats, etc.
- Blueprint de opciones/settings — FOV, cámara, world settings y similares
- DataTables de items/recetas — crafting, recetas y cambios de items
- Blueprints de jugador o Pal donde distintos mods cambian comportamientos independientes
- diferentes versiones de un mismo mod donde sólo cambia un valor

Esas combinaciones **no se consideran probadas** salvo que aparezcan en la lista anterior. PMM analiza los archivos actuales y decide por su estructura, no por una lista fija de nombres compatibles.

---

# Uso rápido

1. Descomprime PMM donde quieras.
2. Haz doble clic en `PMM.exe` (la primera vez puede preparar/descargar las dependencias fijadas).
3. Detecta tu instalación de Palworld.
4. Importa tus PAK o usa **Import ~mods**.
5. Marca qué mods están On.
6. Pulsa **Analyze**.
7. Si PMM pide una decisión real, elige lo que quieres.
8. Pulsa **BUILD MERGE**.
9. Pulsa **DEPLOY**.
10. Juega.

Eso es todo para el uso normal.

Si no quieres usar ningún parche de compatibilidad, selecciona **Sin parche de compatibilidad** y pulsa Deploy. Analyze no es obligatorio en este modo de sólo manager.

---

# Funciones de mod manager

PMM también permite:

- importar una instalación existente de `~mods`;
- activar/desactivar source mods sin borrarlos;
- eliminar mods de la biblioteca PMM;
- conservar mods desactivados como backup;
- evitar desplegar copias redundantes byte-a-byte idénticas;
- guardar varios parches de compatibilidad;
- cambiar entre merges compatibles guardados y desplegarlos sin reconstruir;
- gestionar automáticamente el overlay PMM desplegado;
- hacer backup de mundos de Palworld;
- restaurar backups;
- usar la interfaz en inglés o español.

Import y Build normalmente no modifican Palworld. **Deploy** es el paso explícito que sincroniza la configuración seleccionada con el juego.

---

# Proyecto transparente / open source

PMM está diseñado para ser completamente inspeccionable.

La aplicación está construida alrededor de **scripts PowerShell + WPF/XAML** legibles, y se incluye el código C# de PMMCore y de las herramientas de lectura de assets. Las herramientas C# gestionadas se construyen a partir de ese código incluido durante el setup; PMM no oculta su lógica de merge dentro de una aplicación propietaria cerrada.

PMM sí utiliza herramientas/runtimes externos cuando hacen falta, como `repak` y dependencias de .NET. Sus avisos/licencias se documentan aparte.

La release pública final incluye la licencia open source del proyecto para que desarrolladores puedan inspeccionarlo, hacer forks y continuarlo bajo esos términos.

---

# Conflictos Unsupported y crecimiento comunitario

PMM ya incluye una **Knowledge Library** creciente basada en casos reales resueltos.

Si aparecen conflictos Unsupported, los usuarios avanzados pueden generar explicitamente **un unico paquete AI_HANDOFF** para la lista de mods actual. AIIO incluye el analisis y solo los archivos exactos en conflicto de cada mod implicado y Vanilla; nunca copia PAK fuente completos. Un desarrollador o una IA capaz puede investigar los casos y devolver soluciones en el formato documentado por PMM.

Las soluciones de la comunidad que funcionen pueden compartirse de vuelta con el proyecto para que futuras versiones amplíen la Knowledge Library y el soporte automático.

Palworld Manager Merger ha sido creado por **laredson con ayuda de GPT**, con **50+ horas de desarrollo práctico, debugging, investigación y pruebas dentro del juego** en la release v1.1.

La información para developers, contributors y flujos asistidos por IA está incluida dentro de **Documentation**.

---

# Posibles versiones futuras

Dependiendo del feedback y del desarrollo:

- integración con Nexus Mods y descargas directas
- comprobación de actualizaciones
- modlists/perfiles compartibles y automatizados
- soporte Steam Workshop
- gestión de PalSchema
- gestión de UE4SS
- soporte Game Pass
- análisis Blueprint/Kismet más profundo
- más Knowledge packs comunitarios y métodos automáticos de merge
- más herramientas de desarrollo de mods de Palworld asistidas por IA

---

## Créditos

**Palworld Manager Merger (PMM)**  
Creado por **laredson + desarrollo asistido por GPT**.

Gracias a los autores de mods de Palworld, la comunidad de modding y los desarrolladores/contribuidores de las herramientas y librerías utilizadas por PMM.

Apoya a los creadores de los mods originales. PMM no los reemplaza — **ayuda a que funcionen juntos**.
