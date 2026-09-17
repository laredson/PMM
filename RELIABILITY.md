# PMM v1.5.0.1 - linea independiente de fiabilidad

**Rama:** `v1.5.0.1-PMM-reliability`  
**Estado:** base preparada; sin cambios funcionales ni release nueva.  
**Rama de idiomas:** `v1.5.0.0-PMM-translated`, independiente y no modificada por esta intervencion.

## Punto de partida

La nueva linea nace del commit `38bd5a934488ac11a6200d3142b889ca86a82f57`, observado como HEAD de la rama de traducciones al comenzar esta intervencion. Incluye lo que ya existia en ese commit; las traducciones posteriores se incorporaran cuando esten listas.

La inicializacion conserva identico el arbol completo `PMM/`, incluidos ejecutables, scripts, recursos, idiomas y metadatos. Solo se agregan documentos de mantenimiento y una herramienta de inventario en el repositorio; no se incluyen en el paquete de usuario.

**1.5.0.1 es la version objetivo de esta linea, no una afirmacion de que el trabajo de fiabilidad este terminado.** Al abrir el programa heredado, VERSION.txt sigue siendo 1.5.0.0. El manifiesto heredado contiene 1.3.4.1; esa inconsistencia se registra como trabajo prioritario. El cambio de identidad del paquete se hara junto con manifiestos, hashes y comprobacion de compatibilidad, no alterando solo la etiqueta visible.

## Navegacion

- [Base exacta y estado de inicializacion](Development/Reliability/BASELINE.json).
- [Estado y siguiente paso](Development/Reliability/STATUS.md).
- [Plan de implementacion y criterios de aceptacion](Development/Reliability/IMPLEMENTATION_PLAN.md).
- [Contrato para integrar los idiomas](Development/Reliability/TRANSLATION_INTEGRATION.md).
- [Inventario de diferencias de traduccion, solo lectura](Development/Reliability/plan_translation_integration.py).

## Siguiente paso tecnico

Recuperar o reconciliar las fuentes exactas de los ejecutables nativos actuales y demostrar paridad funcional antes de reemplazarlos. `Development/Source/SOURCE_STATUS.md` advierte que el snapshot Host/Runtime no contiene todos los cambios del paquete Guided Flow. La advertencia no se elimina por crear una rama nueva.

En paralelo pueden inventariarse el paquete, su identidad, hashes y contratos. Despues se abordaran ejecucion de procesos, dependencias y reparacion explicita, recursos de compilacion, firma y comprobaciones previas a publicacion. Las detecciones de antivirus son evidencia a investigar, no un motivo para ocultar comportamiento ni desactivar controles.

No se ha escaneado un ejecutable nuevo, no se ha emulado el sistema privado de Nexus y no se ha verificado que el hash de VirusTotal aportado corresponda a este paquete.
