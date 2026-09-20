# PMM 1.5.0.1 - reliability

**Nuevo proyecto/chat:** empezar por [START_HERE_NEW_PROJECT.md](START_HERE_NEW_PROJECT.md).

El repositorio contiene un handoff autosuficiente con el estado actual, historia,
identidades, fuentes, pruebas, limitaciones y siguientes pasos. No es necesario
recuperar el chat anterior ni pedir ZIPs antiguos para entender el proyecto.

Estado actual:
- rama `v1.5.0.1-PMM-reliability`;
- `PMM/` contiene `PMM-v1.5.0.1-reliability-i01`;
- Host/Runtime C2B se reprodujeron localmente desde Git con sus hashes fijados;
- los dos EXE I01 y sus tres metadatos ya estan integrados en la rama;
- FixLab research llega a 04A-6B pero el executable original sigue distribuido;
- siguiente objetivo ejecutable: probar I01 en Windows y registrar arranque/cierre/tiempos;
- siguiente research FixLab: 04A-6C.

Leer:
- [handoff completo](Development/Reliability/NEW_PROJECT_HANDOFF.md)
- [estado machine-readable](Development/Reliability/NEW_PROJECT_STATE.json)
- [historia por sesiones](Development/Reliability/HISTORY_INDEX.md)
- [siguiente sesion](Development/Reliability/NEXT_SESSION.md)
- [estado](Development/Reliability/STATUS.md)
- [version ejecutable](Development/Reliability/RUNNING_VERSION.md).

La rama es experimental y puede romperse temporalmente durante integraciones
controladas. `NativeCandidates/` se conserva como laboratorio/historial; las
piezas maduras se integran incrementalmente en `PMM/` para pruebas del usuario.

No prometer cero detecciones ni check verde de Nexus. No ocultar comportamiento,
desactivar protecciones, pedir exclusiones ni restaurar cuarentenas automaticamente.
