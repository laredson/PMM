# PMM v1.5.0.1 - linea independiente de fiabilidad

Rama: `v1.5.0.1-PMM-reliability`. Rama de idiomas: `v1.5.0.0-PMM-translated`, independiente.
Base comun: `38bd5a934488ac11a6200d3142b889ca86a82f57`. Preparacion inicial: `df4b2417d3278096f9f66f115bd1237e8d908068`.

## Estado actual

**Tanda 01 parcial.** Investigacion de procedencia y herramienta de preparacion entregadas; fuentes exactas y cambios efectivos de identidad todavia pendientes. El contenido funcional de PMM no se ha cambiado. VERSION.txt sigue 1.5.0.0 y el manifiesto sigue 1.3.4.1. 1.5.0.1 es el objetivo de esta linea, no una release publicada.

## Continuar

Leer primero [NEXT_SESSION.md](Development/Reliability/NEXT_SESSION.md). Contiene el bloqueo, la entrada necesaria, el alcance de 01B y un prompt de continuacion.

[STATUS.md](Development/Reliability/STATUS.md) registra el estado real; [SESSION01_FINDINGS.md](Development/Reliability/SESSION01_FINDINGS.md) contiene evidencia y limites; [SESSION_PLAN.md](Development/Reliability/SESSION_PLAN.md) divide el trabajo en entregas verificables para sesiones acotadas.

[BASELINE.json](Development/Reliability/BASELINE.json), [IMPLEMENTATION_PLAN.md](Development/Reliability/IMPLEMENTATION_PLAN.md) y [TRANSLATION_INTEGRATION.md](Development/Reliability/TRANSLATION_INTEGRATION.md) conservan la base y los contratos generales. [AGENTS.md](AGENTS.md) establece las instrucciones de trabajo.

## Herramienta de la tanda 01

`Development/Reliability/session01_prepare.py` se ejecuta en una copia Git completa de esta rama. Sin cambiar el checkout ni hacer red, comprueba los pins nativos/dependencias y genera un paquete de evidencia y una propuesta conjunta de VERSION, BUILD_ID, RELEASE_MANIFEST y SHA256SUMS. Su funcionamiento puro tiene 12 tests sinteticos; no se ha ejecutado sobre el paquete real ni se han probado PMM/Windows/antivirus.

No sobrescribir ejecutables con el snapshot de fuentes antiguo, no cambiar pins para aceptar archivos inesperados y no afirmar que se emulo Nexus. No hay sincronizacion automatica con idiomas ni permiso permanente para publicar cambios. Cada tanda registra sus propias verificaciones y pendientes.
