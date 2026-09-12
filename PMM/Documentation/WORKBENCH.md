# PMM — Jugar y Crear

Guia del circuito local implementado en septiembre de 2026. Los ejecutables conservan su version anterior; este cambio actualiza los modulos y recursos editables.

## Jugar

La Biblioteca conserva por separado mods activos, mods desactivados, cambios preparados y estado instalado. Auto avanza por el mismo estado que ColorFlow y se detiene cuando hacen falta decisiones o investigacion. Reparaciones, Partidas e Historial estan disponibles en el lateral.

Un analisis completado registra los assets no soportados como casos persistentes. Usa **Abrir caso en Crear** para investigarlos. Tambien puedes seleccionar uno o varios mods y utilizar **Caso de reparacion**, **Caso de compatibilidad** o **Consultar seleccion**, en la barra o en el menu contextual. La creacion captura archivos, versiones y hashes en segundo plano; no envia solicitudes a una IA.

## Crear

**Casos** contiene todos los tipos de caso. El titulo y el objetivo se guardan al navegar; la busqueda y seleccion se conservan. Las referencias y los pasos historicos siguen vinculados a su revision. Ctrl+1 abre Jugar, Ctrl+2 abre Crear y Ctrl+F enfoca la busqueda. Cambiar entre ZIP, MCP o cliente conserva el caso. **Exportar contexto ZIP** es una operacion dentro del caso.

**Recursos** abre archivos, candidatos, referencia del juego y apariencia. **Herramientas** muestra capacidades y requisitos: el editor estructurado prepara e inspecciona assets, edita propiedades numericas/booleanas admitidas y construye un candidato. Conserva el borrador por caso. El taller Unreal requiere motor y kit configurados y verificacion real del proyecto; su adaptador acota el trabajo a texturas. Modelos, animaciones y logica general no se anuncian como soportados.

**Conocimiento** separa candidatos locales y procedimientos importados. Validacion tecnica, observacion, confirmacion del usuario, revision humana y aplicabilidad son dimensiones diferentes. Una aprobacion no sustituye la comprobacion de las entradas actuales ni convierte automaticamente un procedimiento en receta de produccion para Auto.

Los candidatos construidos aparecen desactivados en Biblioteca con su caso de origen. **Probar candidato**, en Conocimiento, verifica las entradas y el productor en segundo plano, muestra las evidencias y solicita una decision explicita. Activar un generado directamente desde una casilla no evita ese control. Despues se usa Analizar y el despliegue normal.

## Recuperacion, recarga y pruebas

PMM conserva un diario durable de despliegue. Si hubo una interrupcion, intenta recuperar al arrancar; una recuperacion pendiente bloquea nuevos despliegues. Ante cambios ajenos o backups corruptos conserva los datos y el diagnostico para resolverlos, en lugar de sobrescribirlos.

**Recargar modulos** valida y prepara cambios compatibles. Si hay una operacion activa, espera hasta quedar libre. Una carga invalida conserva las funciones anteriores. La presentacion inicial y los componentes nativos requieren reinicio; temas y cabecera pueden refrescarse sin reconstruir los editores. No se recarga una construccion en curso.

Mientras PMM este abierto puede observar la ejecucion de la instalacion seleccionada. Al cerrar una sesion con al menos diez minutos observados pregunta una vez por candidato si funciono, fallo o no se probo. Las preguntas pueden desactivarse en Preferencias de Conocimiento. El tiempo en el menu no prueba gameplay: se informa **ejecucion observada**, y la ausencia de un informe se expresa **sin crash detectado**. La cobertura actual de crashes comprende los informes dentro de la instalacion; no se afirma cobertura completa de todos los informes de Windows.

## Intercambio local

Exporta contribuciones JSON versionadas con el procedimiento permitido, referencias, hashes, versiones y resultados. La exportacion excluye rutas personales, partidas, conversaciones, credenciales y bytes del juego. Indica si el procedimiento declarado basta para reproducirlo: un hash identifica una entrada pero no proporciona su contenido.

Las importaciones se validan, deduplican y permanecen pendientes. La preferencia futura de contribucion automatica se conserva, pero el modo actual es **Intercambio local**: no existe receptor ni se realizan envios.

## Alcance de la validacion

Se prueban servicios y ventanas WPF reales con fixtures aislados en Windows PowerShell 5.1. Las pruebas de cierres forzados no equivalen a una prueba de fallo fisico de disco. El escalado de layout simulado no sustituye la revision visual en cada monitor/DPI. La compatibilidad dentro de Palworld, la coccion real con Unreal y la correspondencia de fuentes con binarios nativos se registran por separado y siguen pendientes de validacion real.