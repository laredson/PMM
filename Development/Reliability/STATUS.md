# Estado actual - I04 actualizaciones Nexus seguras / I03 idiomas conservados

## Paquete de trabajo

`PMM/` esta preparado como I04, aun sin commit/push:
- version `1.5.0.1`;
- BUILD_ID `PMM-v1.5.0.1-reliability-i04-nexus-updates`;
- 637 archivos / 636 checksums / 0 mismatches;
- inventario SHA-256 `41dcf96d70be3dbd433d97e90d02c858845eb85d43d8cb839978ee75b1dae5e2`;
- 30 idiomas registrados / 23 habilitados / 7 reservas;
- Host, Runtime y FixLab byte-identicos a I03.

La rama remota continua en I03 hasta autorizacion expresa del propietario.

## Actualizaciones Nexus I04

Updates es una subpestaña propia dentro de Mods & Merge. Check Updates produce un plan de solo lectura ligado al fingerprint. AUTO descarga e instala solo cadenas FileId unicas con un unico PAK seguro, hash instalado intacto, analisis suficiente, cero bloqueos nuevos, cero retiradas pendientes y ningun parche desplegado que quede obsoleto.

La credencial personal se cifra con DPAPI en `Workspace/State`. Premium usa descarga directa. Free abre Nexus y reanuda solo cuando recibe el `nxm://` exacto, vigente y no repetido correspondiente al plan pendiente. El registro del protocolo es opt-in y restaura la asociacion anterior.

La descarga controla HTTPS, cada redireccion, espacio, tiempo, tamaño, cancelacion y hash. La extraccion bloquea traversal, ADS, enlaces, colisiones, ejecutables y archivos anidados peligrosos. La sustitucion archiva indefinidamente la version anterior y coordina la biblioteca con la transaccion de despliegue existente; fallos e interrupciones revierten biblioteca, `~mods` y estado. Un lote avanza su fingerprint solo tras verificar el cambio propio; si Palworld esta abierto, conserva el candidato ya descargado/analizado y lo reanuda automaticamente cuando el juego se cierra.

Deep Analysis consume el plan de Updates y ya no consulta proveedores por separado.

Correccion posterior I04: el arranque ya no evalua botones de Updates antes de que WPF los cree. ColorFlow espera esos controles y se recalcula tras inicializarlos; la regresion de orden de inicio lo cubre.

## Validacion

PASS local: parser PowerShell 5.1, módulos, Nexus/NXM, rollback post-despliegue, recuperación tras reinicio, workers, persistencia, analisis, compatibilidad semantica y WPF EN/ES (27 aserciones por idioma). Localizacion I03: 1.292 claves, 23/23 cargas PS5.1 y smoke zh-CN/ar/vi/uk/cs/ga.

Pendiente: cuenta Nexus real, modalidad Premium/Free no disponible, SSO tras registro de PMM, Palworld real y aceptacion visual del propietario. La regresion RC28 heredada busca funciones ya modularizadas en un archivo antiguo y falla tambien contra la base I03.

## Research conservado

04A-6E permanece candidato-only y no sustituye PMMFixLab. No release, tag, PR, workflow ni Actions.