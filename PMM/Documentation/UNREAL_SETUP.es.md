# Instalación opcional de herramientas para crear mods

## 1. Decide si tu mod necesita estas herramientas

PMM no exige Unreal, Wwise ni Python instalado por separado para gestionar mods, investigar la referencia del juego, inspeccionar propiedades y DataTables, extraer familias acotadas, realizar las ediciones compatibles que ofrece o reempaquetar assets ya cocinados. Merge y FIX LAB tampoco requieren por sí mismos todo este entorno.

Unreal se utiliza cuando el trabajo requiere crear o importar contenido con el editor y cocinarlo para Windows. La primera integración de PMM está limitada a texturas y duplicación/configuración de plantillas verificadas: instalar Unreal no permite automáticamente cualquier modificación de Blueprint.

Wwise es el sistema de audio del que depende AkAudio en el kit completo de Palworld utilizado. Puede ser necesario para compilar ese kit aunque el mod no cambie sonidos. No es un requisito universal de los mods de Palworld ni de todos los proyectos Unreal. El perfil ligero sin Wwise no está implementado ni validado en este adaptador.

El caso «super inventory», 100 espacios adicionales en el inventario principal mediante PAK, todavía no está probado en el juego. Instalar estas herramientas no demuestra que ese cambio sea posible.

## 2. Abre las herramientas de PMM

Ve a Mod Creation → Tools (Herramientas). Usa Detectar herramientas instaladas antes de instalar. Cada componente tiene estado propio; Localizar permite indicar una carpeta, ejecutable o paquete compatible.

Aceptar la propuesta de instalación inicia los componentes indicados. Puedes autorizar instalaciones futuras del catálogo o preguntar cada vez; Cancelar no concede permiso. La autorización se puede revocar. Los pasos oficiales de cuenta, licencia y permisos de Windows siguen correspondiendo al usuario.

## 3. Unreal Engine 5.1.1

Necesitamos el editor y el cocinador, no solamente un «UE SDK».

1. Abre Epic Games Launcher desde PMM.
2. En Unreal Engine → Biblioteca, añade una versión con el botón +.
3. Abre el selector de versión y elige exactamente 5.1.1. El launcher puede proponer la versión más nueva; no aceptes esa selección por defecto para este kit.
4. Pulsa Instalar y conserva las herramientas necesarias para Windows. Quixel Bridge es opcional y PMM no lo requiere.
5. Al terminar, vuelve a PMM y pulsa Detectar herramientas instaladas. Si no aparece, usa Localizar con la raíz UE_5.1 o UnrealEditor.exe.

El flujo habitual del launcher exige seleccionar la versión manualmente. PMM no promete una instalación silenciosa del motor. No necesitas instalar Python: PMM utiliza el integrado en Unreal para sus proyectos administrados.

## 4. Visual Studio y herramientas Microsoft

Instala Visual Studio 2022 con C++ y MSVC v143 x64/x86 14.38–17.8, Windows SDK y .NET Runtime 6 x64.

Tener Visual Studio 2022 actualizado no implica tener MSVC 14.38: se puede añadir ese compilador junto a versiones más nuevas. PMM distingue ambos estados y utiliza parámetros oficiales para completar los componentes pendientes. No hace falta quitar VS 2019, 2022 o versiones posteriores.

Si usas el instalador manual: Visual Studio 2022 → Modificar → Componentes individuales → MSVC v143 — VS 2022 C++ x64/x86 (v14.38–17.8).

No abras varias instancias del instalador. Si hay una instalación activa, deja que termine. Si solamente está abierto el panel del instalador, ciérralo antes de volver a solicitar la modificación desde PMM. No reinicies el equipo únicamente porque aparezca install.lock; espera a que termine el trabajo y consulta su estado.

## 5. Wwise SDK: descargar y después instalar

La descarga inicial se hace desde Audiokinetic Launcher conectado, con tu cuenta. La copia offline permite reutilizar los paquetes después; no elimina las condiciones de licencia.

1. En Wwise, selecciona 2021.1.11.7933, no Latest.
2. Elige Create offline installer para conservar los paquetes.
3. Incluye SDK (C++). En Microsoft → Windows, selecciona Visual Studio 2022 y las bibliotecas Win32/x64 vc170.
4. Game Core, UWP, consolas, otras plataformas y complementos de audio adicionales no son necesarios para este entorno. Authoring es opcional para este recorrido de PMM; no necesitas añadir Wwise a Unity.
5. Guarda en la carpeta que abre PMM con Abrir carpeta offline de Wwise: Workspace/Dependencies/Offline/Wwise-2021.1.11. El launcher puede añadir Wwise_2021.1.11.7933 como subcarpeta; consérvala con su carpeta bundle.
6. Espera a que termine la descarga. Crear el paquete offline NO instala el SDK.
7. Ejecuta el launcher incluido en el paquete, o usa Use offline installer seleccionando la carpeta bundle dentro del paquete descargado, y confirma Install. Una carpeta vacía o la carpeta de una instalación no sustituye al paquete offline.
8. Vuelve a PMM y detecta las herramientas. Si es necesario, Localizar acepta la raíz de Wwise, SDK o Wwise.exe. PMM comprueba la versión y las bibliotecas, no solamente la existencia de una carpeta.

## 6. Integración Wwise para Unreal: descarga separada

El SDK instalado y la integración Unreal son dos componentes distintos.

1. Cierra completamente el launcher offline. Su indicador naranja y Download/Sign in desactivados indican ese modo.
2. Abre el Audiokinetic Launcher instalado desde el menú Inicio. No ejecutes otra vez la copia del paquete offline.
3. Con el launcher conectado, abre Unreal Engine → Download → Offline integration files.
4. Selecciona 2021.1.11, integración 2021.1.11.2437, y descarga en la carpeta que abre PMM con Abrir carpeta de descarga de integración.
5. Conserva bundle.json, install-entry.json y Unreal.5.0.tar.xz. PMM también reconoce la descarga dentro de la carpeta offline de Wwise.
6. En PMM pulsa Detectar herramientas instaladas. Si hace falta, Localizar puede seleccionar Unreal.5.0.tar.xz directamente.

No necesitas crear un proyecto para descargar esos archivos. Para la revisión fijada del kit se usa el archivo Unreal.5.0.tar.xz con la adaptación a UE 5.1 en la copia administrada; no cambies la instalación del motor a 5.0. PMM usa el Python de Unreal para descomprimir XZ cuando el tar de Windows no puede hacerlo.

## 7. Kit comunitario y comprobación real

PMM fija PalworldModdingKit a e6632458b97af0083eb81715775651b08104ef6a. La URL y SHA-256 están en Resources/Unreal/profile.json. Instalar/completar obtiene esa revisión y la comprueba; los proyectos existentes no deben actualizarse silenciosamente.

SHA-256 del ZIP fijado: 9a13bf315b5e11587c9706ba9c6f4a370bfbbdde29509540b2d992665c79e993.

Detectado significa que PMM encontró el componente. No significa que haya compilado el proyecto, cocinado un candidato o probado el mod en Palworld. La integración viene desactivada; las comprobaciones reales se realizan en proyectos aislados. No uses tu guardado habitual para las primeras pruebas.

## 8. Recuperar tu copia offline privada

El mantenedor conserva los paquetes en una Release del repositorio privado PMM-setup-backup. Los usuarios de la distribución pública siguen la adquisición oficial; ese respaldo personal no forma parte del ZIP público.

1. Descarga PMM-offline-2021.1.11.zip, su archivo .sha256 y OFFLINE_INVENTORY.json desde la misma Release autenticada. Descarga también esta rama de PMM.
2. Comprueba que el hash usado procede de esa Release. En PowerShell, desde la carpeta PMM, ejecuta primero una comprobación:

    & ./Resources/Unreal/Restore-OfflineBackup.ps1 -Archive 'D:/Descargas/PMM-offline-2021.1.11.zip' -ExpectedSha256 'HASH_DEL_ARCHIVO_SHA256' -VerifyOnly

3. Repite el comando sin -VerifyOnly para restaurar en Workspace/Dependencies/Offline.
4. El script valida nombres, tamaños y hashes; reutiliza archivos idénticos y rechaza diferencias sin sobrescribirlas. No instala ni ejecuta nada y no aplica permisos o rutas del equipo original a la configuración de PMM.
5. Pulsa Detectar herramientas instaladas. Si el SDK ya existe, se reutiliza. Si solamente hay paquetes offline, usa Instalar/completar para instalar el SDK.

Los metadatos originales del fabricante pueden conservar la ubicación de descarga original. PMM localiza los archivos restaurados en su nueva carpeta; no importa esa ubicación como configuración. No se respalda Unreal ni una instalación completa de Visual Studio. La configuración de cada equipo se obtiene con autodetección o Localizar.

## 9. Si algo falla

- Error 1639: argumentos rechazados por Windows Installer. Usa esta rama corregida de PMM; abrir Epic Store no corrige ese error.
- Get-FileHash no reconocido: usa la versión corregida y PowerShell de Windows disponible; no desactives las comprobaciones de integridad.
- Otro instalador abierto / install.lock: consulta el trabajo activo y evita solicitudes duplicadas. No borres bloqueos mientras haya un instalador trabajando.
- Offline package ready: todavía falta instalar el SDK.
- Error loading bundles: selecciona un paquete offline completo, no una carpeta vacía.
- Download desactivado: cierra el launcher offline y abre el launcher instalado conectado.
- Integración no detectada: el SDK no incluye esa descarga; selecciona su Unreal.5.0.tar.xz.
- Una ruta seleccionada se rechaza: revisa versión y componentes; no cambies archivos para simular compatibilidad.
- Todos detectados: sigue pendiente verificar el proyecto real. Un PAK construido tampoco demuestra funcionamiento en el juego.

## Fuentes

- [Instalación oficial de Unreal](https://dev.epicgames.com/documentation/en-us/unreal-engine/installing-unreal-engine?application_version=5.1)
- [Parámetros de Visual Studio Installer](https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2022)
- [Instaladores offline de Audiokinetic](https://www.audiokinetic.com/en/public-library/launcher_2025.3.3.5754/?id=working_with_offline_installers&source=InstallGuide)
- [Integración Unreal en Audiokinetic Launcher](https://www.audiokinetic.com/en/public-library/Launcher_2025.2.0.5346/?id=unreal_engine&source=InstallGuide)
- [Requisitos del kit](https://pwmodding.wiki/docs/developers/palworld-modding-kit/prerequisites)
- [Instalación del kit](https://pwmodding.wiki/docs/developers/palworld-modding-kit/installation)
