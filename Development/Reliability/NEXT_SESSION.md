# NEXT SESSION - PMM v1.5.0.2

## Bloque siguiente: V1502-S01

**Startup diagnosable + inventario de superficie de ejecucion**

No empezar por mutar binarios al azar para intentar bajar detecciones. Primero dejar el arranque observable y fijar la superficie real que puede estar contribuyendo tanto al fallo pre-UI como a falsos positivos.

## Entrada

Rama: `v1.5.0.2`.
Base funcional heredada: I04 del commit `2586b4c3999ccc094344bc65710d6559f4858871`.

El paquete inicial sigue identificado como 1.5.0.1/I04 hasta la primera integracion funcional de 1.5.0.2.

## Incidencia a conservar

`Development/Reliability/Incidents/STARTUP_PRE_UI_2026-09.md`

No intentar "arreglarla" borrando Workspace, añadiendo retries ciegos o tragando excepciones. La primera mejora debe aumentar observabilidad.

## Trabajo de S01

1. Trazar el recorrido real desde `PMM.exe` hasta ventana WPF utilizable.
2. Enumerar las etapas ya visibles en splash y relacionarlas con codigo real.
3. Garantizar un log de arranque acotado que sobreviva a un fallo pre-UI.
4. Capturar de forma segura:
   - etapa alcanzada;
   - componente/proceso;
   - codigo de salida o excepcion;
   - version/build;
   - arquitectura/Windows/PowerShell/.NET relevantes;
   - locale/cultura solo como dato diagnostico, nunca como diagnostico automatico;
   - sin credenciales, tokens ni datos personales.
5. Revisar manejadores de excepcion y handoff Host -> Runtime -> UI para evitar fallos silenciosos.
6. Inventariar, sin cambiar aun por conveniencia:
   - invocaciones PowerShell y argumentos de politica;
   - creacion de procesos ocultos/sin consola;
   - broker generico;
   - comprobacion/reparacion de dependencias;
   - descargas o red durante arranque;
   - ejecutables/scripts distribuidos.
7. Registrar hashes del baseline que se vaya a comparar en S02+.
8. Preparar la integracion 1.5.0.2 de metadata solo cuando exista un cambio funcional real; VERSION/BUILD_ID/manifiesto/checksums se actualizan juntos.

## Criterio de cierre S01

- un fallo entre splash y UI deja evidencia suficiente para localizar la etapa;
- un arranque sano no gana reparaciones o red silenciosas;
- existe inventario concreto de procesos/PowerShell/repair/startup;
- ninguna feature I03/I04 se elimina;
- queda definido el cambio exacto de S02;
- pruebas realizadas y no realizadas quedan separadas.

## S02 previsto

Reducir superficie de ejecucion:
- retirar `ExecutionPolicy Bypass` donde no sea necesario;
- conservar errores claros cuando la politica bloquee;
- estructurar argumentos;
- evitar shell generico cuando exista operacion concreta;
- mantener GUI sin consola donde sea normal, sin confundir eso con ocultacion maliciosa.

## GitHub

Commit/push silencioso con `[skip ci]` solo tras autorizacion del propietario para el bloque.
Sin Actions, PR, tag ni release.
