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

Contexto inmediato: todo el research/codigo esta en Git. La excepcion es que los dos EXE I01 compilados en la sesion anterior no pudieron transferirse al remoto por limitacion del conector. NO necesitamos esos ZIPs para reconstruirlos: las fuentes, hashes y recetas estan versionados. Si tu entorno puede compilar y hacer push binario, reproduce I01, verifica los hashes exactos y publica los cinco archivos del paquete I01 en esta misma rama. No cambies pins para forzar resultados.

Esta rama SI puede quedar temporalmente rota: es una rama experimental para que el propietario pruebe cambios reales mediante GitHub Desktop. Mantener `Development/Reliability/NativeCandidates/` como laboratorio/historial, pero integrar en `PMM/` los bloques suficientemente cerrados.

Despues de publicar I01, pedirme que haga Pull y probar: arranque, ventana visible, UI utilizable, cierre, segundo arranque y tiempos. No sigas acumulando integraciones antes de revisar esa prueba.

Luego retomar 04A-6C y el roadmap documentado. No crear PR/tag/release ni ejecutar Actions por iniciativa propia. Commits de desarrollo con `[skip ci]`. No desactivar antivirus ni pedir exclusiones.

Antes de responderme que falta contexto, demuestra que has leido el handoff y resume:
- que ejecutables remotos siguen siendo originales;
- hashes Host/Runtime I01;
- que hace 04A-6B;
- cual es la siguiente prueba Windows;
- que queda pendiente para FixLab;
- como se integraran los idiomas.

---
