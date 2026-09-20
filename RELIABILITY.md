# PMM 1.5.0.1 - reliability

**Nuevo proyecto/chat:** empezar por [START_HERE_NEW_PROJECT.md](START_HERE_NEW_PROJECT.md).

El repositorio contiene un handoff autosuficiente con el estado actual, historia,
identidades, fuentes, pruebas, limitaciones y siguientes pasos. No es necesario
recuperar el chat anterior ni pedir ZIPs antiguos para entender el proyecto.

Estado actual:
- rama `v1.5.0.1-PMM-reliability`;
- PMM remoto sigue `PMM-v1.5.0.1-reliability-s01b`;
- Host/Runtime C2B e integracion I01 son reproducibles desde Git;
- los dos EXE I01 aun no estan en `PMM/` remoto por una limitacion del conector anterior;
- FixLab research llega a 04A-6B pero el executable original sigue distribuido;
- siguiente objetivo ejecutable: publicar I01 realmente en la rama y probarlo en Windows;
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
