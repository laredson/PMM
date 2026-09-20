# Prompt de arranque para un nuevo chat/proyecto

Usar este texto si se crea un nuevo proyecto, Work o Codex. No hace falta copiar el historial del chat anterior.

---

Continua el desarrollo de PMM desde GitHub.

Repositorio: `laredson/PMM`  
Rama: `v1.5.0.1-PMM-reliability`

NO me pidas un ZIP del chat anterior antes de revisar el repositorio. El handoff es autosuficiente en Git.

Lee, en orden:

1. `START_HERE_NEW_PROJECT.md`
2. `AGENTS.md`
3. `Development/Reliability/NEW_PROJECT_HANDOFF.md`
4. `Development/Reliability/NEW_PROJECT_STATE.json`
5. `Development/Reliability/HISTORY_INDEX.md`
6. `Development/Reliability/NEXT_SESSION.md`
7. `Development/Reliability/STATUS.md`
8. `Development/Reliability/RUNNING_VERSION.md`
9. `Development/Reliability/IMPLEMENTATION_PLAN.md`
10. `Development/Reliability/TRANSLATION_INTEGRATION.md`
11. `Development/Reliability/SESSION_PLAN.md`
12. `Development/Reliability/Integration/I01/README.md`

Si tienes acceso a una carpeta local del repo, usala como fuente de trabajo y comprueba `git status`, rama y HEAD antes de cambiar nada. Si solo tienes GitHub remoto, inspecciona la rama antes de pedir archivos al usuario.

Contexto inmediato: todo el research/codigo esta en Git. La limitacion anterior de transferencia de los dos EXE I01 ya quedo cerrada en SESSION_I01B. `PMM/` es I02, conserva Host/Runtime C2B y usa Workspace para configuracion privada, con arbol `9ef22d5815943ce50413dfa7e09b474b06a22860`. No cambies pins ni reconstruyas I01 otra vez sin una razon nueva.

Esta rama SI puede quedar temporalmente rota: es una rama experimental para que el propietario pruebe cambios reales mediante GitHub Desktop. Mantener `Development/Reliability/NativeCandidates/` como laboratorio/historial, pero integrar en `PMM/` los bloques suficientemente cerrados.

I02 ya arranca y funciona a nivel basico. Recoger cierre, segundo arranque, UI detallada y tiempos. No acumular otra integracion grande antes de revisar ese feedback.

04A-6D ya implemento job V2/CLI candidato-only y commit Windows por marcador;
leer sus FINDINGS/CHECKS y contratos. La matriz sigue parcial (Win10 NTFS probado,
Win11/SMB/disco lleno real/AV/race pendientes). Continuar semantica real acotada
sin sustituir FixLab ni acumular integraciones PMM.
No crear PR/tag/release ni ejecutar Actions. Commits con `[skip ci]`.
No desactivar antivirus ni pedir exclusiones.

Antes de responderme que falta contexto, demuestra que has leido el handoff y resume:
- que Host/Runtime I01 estan integrados y FixLab sigue siendo el original;
- hashes Host/Runtime I01;
- que hacen 04A-6B/6C/6D y los limites de las pruebas Windows;
- cual es la siguiente prueba Windows;
- que queda pendiente para FixLab;
- como se integraran los idiomas.

---
