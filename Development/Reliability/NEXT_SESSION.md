# Retomar - I04 Nexus preparado / pendiente de prueba real y publicacion

## Estado actual

El worktree contiene I04 sin commit/push:
- BUILD_ID `PMM-v1.5.0.1-reliability-i04-nexus-updates`;
- 637 archivos / 636 checksums / 0 mismatches;
- inventario `8c996734234ba200c2a198be92fe5c178fe1102839a2d1790ac7641afe7cc456`;
- 51 módulos;
- 23 idiomas habilitados;
- binarios Host/Runtime/FixLab sin cambios.

## Primera accion

1. Confirmar rama, HEAD y `git status`; no perder el diff I04.
2. Abrir PMM y revisar el orden de las siete subpestañas de Mods & Merge.
3. Probar Check Updates sin credencial y confirmar que no modifica mods.
4. Conectar la API key personal de Nexus desde Updates y verificar usuario/tipo/cuotas.
5. Probar un mod vinculado exacto. En Free, habilitar PMM para `nxm://`, pulsar Download en Nexus y confirmar que PMM continua solo.
6. Confirmar archivo anterior, sustitucion, `~mods`, Restore previous version y segundo arranque.
7. Con PMM cerrado y tras revisar el diff, autorizar si procede un unico commit/push `[skip ci]`.

No probar SSO hasta registrar PMM. No incluir credenciales en capturas, logs, Git o informes. No PR, tag, release ni Actions.

Despues se puede retomar SESSION04A6E sin repetir arrays escalares V2, job/CLI ni el commit Windows por marcador.