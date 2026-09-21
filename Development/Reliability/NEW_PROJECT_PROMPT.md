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
12. `Development/Reliability/Integration/I03/README.md`
13. `Development/Reliability/SESSION_I03_TRANSLATION_FINDINGS.md`
14. `Development/Reliability/SESSION_I03_TRANSLATION_CHECKS.json`
15. `Development/Reliability/Integration/I01/README.md`

Si tienes acceso local, usalo y comprueba `git status`, rama, HEAD, BUILD_ID y
checksums antes de cambiar nada.

Contexto inmediato: `PMM/` es I03,
`PMM-v1.5.0.1-reliability-i03`, con tree
`e0c394997f1dbc172fef3cfc1a755f80f63e1692`, 631 archivos y 630 checksums.
Conserva Host/Runtime C2B, FixLab original y el routing I02 a Workspace. Integra
el commit de traducciones
`681f7994474ebfd6c2538775767d2002014170f7`: 30 idiomas registrados, 23
habilitados y siete reservas. English sigue default/fallback y el cambio requiere
Apply + reinicio.

El propietario informo que I02 arranca y funciona y que vi/uk/cs/ga funcionaban
en el donante. La siguiente prueba es ejecutar I03, confirmar selector,
persistencia tras cerrar/abrir, RTL arabe, pantallas representativas y tiempos.
Corregir cualquier regresion antes de otra integracion grande.

04A-6E ya implemento recorrido V2 de ArrayProperty con innerType escalar fijo,
sin mutar arrays, y lo probo de UAsset a job/CLI candidato-only. Struct/map/set/
string/nested arrays, schema real y relocalizacion siguen pendientes. Continuar
despues de la aceptacion I03 con una fuente de schema real pinneada u otro
serializer acotado, sin sustituir FixLab.

No crear PR/tag/release ni ejecutar Actions. Commits con `[skip ci]`. No
desactivar antivirus ni pedir exclusiones.

Antes de responder que falta contexto, resume:
- identidad, tree, idiomas y limites de I03;
- hashes Host/Runtime/FixLab conservados;
- resultado y pendientes de la prueba Windows I03;
- que hacen 04A-6B/6C/6D/6E y que falta para FixLab.

---
