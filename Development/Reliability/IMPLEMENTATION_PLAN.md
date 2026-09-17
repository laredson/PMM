# PMM v1.5.0.1: plan de fiabilidad y distribucion verificable

Estado: plan, no implementacion. La inicializacion de esta rama no modifica comportamiento del paquete.

## Objetivo

Conservar las funciones actuales de PMM, sus datos y sus traducciones mientras se hace verificable la cadena fuente -> build -> paquete -> ejecucion. Reducir causas legitimas de falsos positivos, sin alterar controles antivirus ni ocultar funciones a los analizadores. No se promete cero detecciones ni aprobacion automatica de Nexus.

## REL-00 - Establecer la evidencia

Inventariar PMM.exe, PMMRuntime.exe, PMMFixLab.exe, repak.exe, assemblies propios, dependencias y scripts que realmente se distribuyen. Calcular SHA-256 de cada archivo y del archivo comprimido final; registrar tamano, procedencia, version del componente y estado de firma. No confundir estos hashes con los SHA de objetos Git.

Relacionar el SHA-256 `5be86567f597aefb64f1645a9b924c7de213da49206d7591b9e4f7f685fbcade` con un archivo concreto antes de atribuirle las caracteristicas de esta rama. Obtener el informe real de motores, fecha y tipo de deteccion. Hasta entonces, el origen de los positivos sigue siendo una hipotesis.

No enviar automaticamente muestras, logs o datos de usuarios a terceros. Inventariar la superficie de escritura, procesos secundarios y accesos de red de cada accion. Distinguir arranque normal, diagnostico, descarga consentida y reparacion. No etiquetar toda invocacion de PowerShell, todo proceso sin consola o todo recurso PE como malicioso.

Aceptacion: tabla artefacto -> fuente/procedencia -> hash -> estado conocido, sin afirmar verificaciones que no se hayan hecho.

## REL-01 - Fuente nativa y base funcional

`Development/Source/SOURCE_STATUS.md` documenta un snapshot 1.2.1 que no reproduce todos los cambios de los binarios Guided Flow actuales. Recuperar los fuentes exactos desde historial, entregas o backups autorizados; verificar tambien PMMFixLab. Si se reconstruye una pieza desde su contrato, documentarlo como reconstruccion, no como recuperacion del original.

No cambiar la proteccion de los scripts BUILD_HOST/BUILD_RUNTIME que impide sobreescribir los binarios conocidos hasta demostrar paridad. Registrar toolchain, dependencias y parametros. Conservar binarios de referencia identificados por hash.

La prueba local de paridad debe cubrir inicio/cierre, supervision de procesos y errores, diagnosticos, rutas native/legacy realmente usadas, dependencias, GUI, cancelacion y codigos de salida. No asumir que una ruta llamada native elimina PowerShell del resto del recorrido.

Aceptacion: fuente y build identificables, diferencias explicadas y usuario confirmando las pruebas Windows pertinentes antes de sustituir ejecutables del paquete.

## REL-02 - Identidad de version e integridad

Hecho observado al bifurcar: `PMM/Resources/Metadata/VERSION.txt` contiene 1.5.0.0 y RELEASE_MANIFEST.json declara 1.3.4.1. La rama nueva no cambia solo una etiqueta para aparentar una release terminada.

Preparar un cambio coherente a 1.5.0.1 con estado de desarrollo explicito: VERSION, BUILD_ID, campos de version/build/releaseCandidate del manifiesto, presentacion y verificadores. Las versiones de componentes como PMMCore o .NET no se sustituyen por la version de producto.

Regenerar inventarios desde los bytes finales mediante la rutina canonica del repositorio, entendiendo que archivos incluyen y evitando autorreferencias de hashes. No cambiar hashes esperados para aceptar automaticamente una dependencia inesperada. Un archivo de checksums mutable junto al binario no es por si solo una raiz de confianza.

Aceptacion: identidad concordante, contratos de componentes preservados y manifiestos validos para el paquete concreto; sin publicar release.

## REL-03 - Arranque y ejecucion de procesos

Trazar el recorrido real PMM.exe -> Runtime -> UI/workers/herramientas. La fuente historica contiene invocaciones `-ExecutionPolicy Bypass` y ocultacion de consolas; verificar cuales siguen en uso antes de cambiarlas.

Retirar Bypass donde no haga falta, manteniendo un modelo soportado de scripts firmados o componentes compilados. Probar politicas efectivas y procedencia de los scripts. No reemplazarlo por otro metodo de elusion ni modificar politicas globales. Un bloqueo por politica debe producir un error claro, no una ruta alternativa que lo sortee.

Unificar contratos de herramientas: ejecutable esperado, argumentos estructurados, directorio de trabajo permitido, limites de tiempo, cancelacion, codigo de salida y logs. Revisar si la interfaz generica de process run es necesaria en distribucion; limitarla a operaciones reales sin romper los lanzamientos de juego, Unreal ni integraciones opcionales. No construir comandos de shell con texto no confiable.

Conservar una GUI sin parpadeos de consola donde sea apropiado: CREATE_NO_WINDOW no se elimina indiscriminadamente. El objetivo es reducir invocaciones innecesarias y mejorar visibilidad funcional y logs, no cambiar la apariencia del programa ante el antivirus.

Aceptacion: mismas funciones y errores mas claros, sin privilegios elevados por defecto, sin cambios en antivirus/politicas y con rutas de ejecucion verificables.

## REL-04 - Dependencias y reparacion segura

El paquete funcional debe incluir los componentes redistribuibles necesarios y sus licencias/procedencia. Preservar la verificacion local del arranque sano.

Separar comprobar de reparar: cuando falte o falle un componente, mostrar el diagnostico y una accion explicita de reparacion. No reinstalar silenciosamente un archivo posiblemente puesto en cuarentena ni repetir descargas para vencer un bloqueo. No concluir que un archivo falta por antivirus sin evidencia.

Para una reparacion autorizada: fuentes y versiones fijadas, HTTPS, limites de descarga/extraccion, comprobacion de hash/firma desde referencias confiables, staging, verificacion previa, reemplazo transaccional y rollback. La interrupcion no debe destruir la ultima instalacion util. No ejecutar bytes descargados antes de verificarlos.

Mantener integraciones de red que el usuario elija realmente utilizar, documentadas y aisladas del arranque offline. No mover componentes a descargas posteriores con el objetivo de sacarlos del escaneo del paquete. Las condiciones de distribucion y licencias se comprobaran antes de una release real.

Aceptacion: inicio sano sin reparaciones de red, fallos diagnosticables, reparacion consentida, integridad conservada y respuesta segura ante bloqueo/cuarentena.

## REL-05 - Build y paquete auditables

Definir una ruta de build repetible desde las fuentes reconciliadas, dependencias fijadas y toolchain conocido. Incorporar icono, VERSIONINFO y manifest de Windows mediante recursos de compilacion estandar. Conservar el icono y las funciones existentes.

El inyector de iconos del snapshot es una herramienta de build, no evidencia de inyeccion en procesos. Sustituirlo busca simplificar procedencia y mantenimiento; no se afirma que origine una deteccion. Tampoco se trata `-s -w` o el lenguaje Go como una causa demostrada.

Separar el paquete de usuario del repositorio de mantenimiento. Conservar contratos publicos y rutas durante la traduccion; cualquier reorganizacion grande requiere mapa de migracion y no se mezcla con la importacion de idiomas. Registrar licencias y procedencia de cada dependencia distribuida.

Aceptacion: construccion documentada, salida final verificable y actualizacion/rollback del paquete sin perdida de Workspace.

## REL-06 - Firma

Seleccionar con el propietario una identidad de publisher y un certificado o servicio apto para la distribucion. La firma requiere provisionamiento real; no esta realizada por escribir este plan. No autofirmar e instalar silenciosamente una raiz de confianza en los equipos de usuarios.

Firmar los ejecutables/assemblies propios y scripts pertinentes despues de cualquier cambio de contenido y recursos. Incorporar timestamp cuando proceda y comprobar cadena, validez e integridad en Windows. Conservar firmas originales de terceros; no atribuir a PMM codigo ajeno. Calcular el inventario distribuido despues de firmar los archivos correspondientes.

Aceptacion: evidencia de firmas verificadas y correspondencia con los artefactos distribuidos. Una firma acredita origen/integridad, no garantiza ausencia de defectos ni aprobacion de todos los motores.

## REL-07 - Comprobaciones y publicacion futura

El futuro preflight de distribucion inspeccionara paquete e inventarios, rutas de archivo, formatos, ejecutables/scripts incluidos, procedencia, firma y coherencia de version. Sus reglas de empaquetado deben basarse en requisitos de distribucion comprobados en ese momento. No es un clon del sistema privado de Nexus.

Las comprobaciones de ejecucion se hacen en Windows con las protecciones activas: usuario sin privilegios, rutas con espacios y Unicode, instalacion nueva y actualizacion de Workspace existente, dependencias faltantes/alteradas, cancelacion, rollback, merge/deploy y recuperacion. Usar copias de prueba para operaciones destructivas.

Validar idiomas habilitados, claves y placeholders, seleccion persistente, nombres nativos, RTL/LTR y campos tecnicos, reinicio para cambio de idioma y compatibilidad PowerShell 5.1 mientras siga vigente. No usar una reescritura como excusa para perder traducciones o funciones.

Los escaneos reales y envios a fabricantes se realizan con autorizacion y conservando fecha, motor, hash y resultado. Comparar antes/despues solo para valorar cambios de ingenieria justificados, no como bucle de mutaciones arbitrarias hasta lograr indetectabilidad. Resolver detecciones con evidencia y canales de falsos positivos cuando corresponda.

Aceptacion final: pruebas documentadas, traducciones integradas, fuentes y binarios concordantes, identidad/hashes coherentes, limitaciones conocidas declaradas y aprobacion del propietario para release. No activar CI de desarrollo; una validacion remota de release requiere autorizacion especifica.

## Orden de trabajo

REL-00 y REL-01 primero; despues REL-02 a REL-05 por cambios acotados y reversibles. REL-06 depende del provisionamiento de firma. REL-07 y LOC-MERGE cierran la candidata. Ningun paso se marca terminado por estar enumerado aqui.
