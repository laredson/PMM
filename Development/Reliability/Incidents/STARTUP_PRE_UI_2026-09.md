# STARTUP-PRE-UI-2026-09

Estado: **OPEN**
Severidad: **High - puede impedir completamente iniciar PMM**
Reproducibilidad local actual: **NO**
Causa: **UNKNOWN**

## Sintoma

PMM muestra la barra de carga/splash y falla antes de que aparezca la UI principal.

El punto aparente es:
`Host/Runtime startup -> splash/loading -> [FALLO] -> UI WPF`.

No se conoce aun la subetapa exacta.

## Reporte 1 - propietario

- Version: 1.5.0.1.
- Contexto: primer arranque observado por el propietario.
- Resultado: aparecio un error despues de la barra de carga y antes de UI.
- Segundo arranque: funciono correctamente.
- Repeticion posterior: no conseguida.

## Reporte 2 - usuario chino

- Reportado aproximadamente dos dias despues.
- Sintoma descrito como el mismo tipo de fallo: no llega a UI despues de la carga.
- Segun el reporte, el usuario no logra hacer funcionar PMM.
- No hay en este registro texto exacto del error, stack, log ni captura.
- "Usuario chino" es contexto del reporte, **no una hipotesis causal**.

## Intentos de reproduccion del propietario

No reproducen el fallo:
- instalacion nueva;
- borrar Workspace;
- nuevos arranques posteriores.

## Lo que NO se sabe

No se sabe si la causa es:
- locale/cultura/idioma;
- PowerShell;
- .NET/WPF;
- Runtime/Host handoff;
- permisos;
- antivirus/cuarentena;
- archivo faltante;
- reparacion automatica;
- carrera/orden de inicializacion;
- estado de Workspace;
- Nexus/App Server/u otra integracion;
- otra condicion.

No priorizar una de estas como causa sin evidencia.

## Objetivo de diagnostico para 1.5.0.2

El startup debe dejar evidencia aun cuando la UI nunca llegue a crearse.

Captura minima deseada:
- version y BUILD_ID;
- etapa de startup;
- timestamp;
- proceso/componente;
- excepcion/codigo de salida;
- Windows build/arquitectura;
- PowerShell relevante si se invoco;
- .NET/runtime relevante;
- locale/cultura solo como contexto;
- rutas normalizadas sin exponer datos personales;
- presencia/estado de dependencias verificadas;
- sin API keys, tokens ni contenido privado de Workspace.

## Reglas de correccion

- No tragarse la excepcion para continuar como si nada.
- No añadir retries infinitos o ciegos.
- No borrar Workspace automaticamente.
- No reinstalar/descargar dependencias en silencio para "ver si arranca".
- No pedir desactivar antivirus.
- Si aparece una causa concreta, agregar una regresion que reproduzca esa condicion.
- Si una mejora general de startup elimina el fallo sin causa demostrada, cerrar solo cuando exista evidencia suficiente; no afirmar una causa inventada.

## Relacion con hardening

Este incidente se investiga junto con el hardening porque ambas lineas tocan el startup, procesos y dependencias. Sin embargo, una deteccion antivirus y este crash no se consideran la misma causa por defecto.
