# Tanda 01 - procedencia nativa e identidad

Fecha de la intervencion: 2026-09-18. Rama exclusiva: `v1.5.0.1-PMM-reliability`.
Base inspeccionada: `df4b2417d3278096f9f66f115bd1237e8d908068`.

**Resultado: cierre de investigacion parcial, NO cierre de REL-01/REL-02.**
No se recuperaron fuentes exactas ni se aplico la identidad nueva al paquete.
No presentar este checkpoint como los dos asuntos resueltos.

## Evidencia concreta obtenida

- El historial de `Development/Source/Host/main.go`, `PMM/PMM.exe` y `PMM/Engine/PMMRuntime.exe`, consultado hasta la base, devuelve como unico cambio en cada ruta el commit `683a46df474c5f576e0bf5543d070da0dab7478a`, "PMM 1.2.1 Guided Flow stable baseline". No hay una revision posterior de esos archivos en la ascendencia consultada.
- El padre de ese commit es `bc04d18d677e8f6bf754518e342184761d6527a3`. Su estructura antigua contiene Host y Runtime, pero sus ejecutables son otros objetos Git: PMM.exe `e7a9ac42994291cf475487aa1fa1c6be14e3ad86` (2437632 bytes), PMMRuntime.exe `a227fc7dd71a76d336124c0356593f5e26e7c5ef` (6244864 bytes).
- El Host/main.go anterior tiene blob `806e15022bc7db6f2e41ec51c5774c9abdb58838` (15417 bytes). No se confunde con el snapshot posterior `c1d9482374640af6b44a00a7005dd5b767e4999e` (16228 bytes).
- El manifiesto heredado describe un splash con etapas workspace/security/runtime/dependencies/ui-bootstrap/ready y transferencia de primer plano desde `startup:UI-shell-ready:<HWND>`. Su propio campo `startupSplashSource` advierte que la fuente requiere reconciliacion; cita como referencia de fuente SHA-256 `91e7531d9018ba1cbf7a3cbe20ed4736df3210c1ebad467cc80536959404ded9`.
- El manifiesto describe tambien ajustes de creacion del proceso WPF. No se ha demostrado que el snapshot reproduzca esas funciones. Leer ese contrato no equivale a observarlas ejecutandose.
- `fixLabEngine.source` apunta a `Development/Source/FixLabEngine/`; no figura en el arbol de fuentes inspeccionado. Su procedencia necesita una comprobacion separada. No afirmar ausencia en todas las ramas o backups.
- VERSION.txt dice 1.5.0.0, mientras el manifiesto dice version 1.3.4.1, releaseName 1.3.4, releaseCandidate 1.3.4.1-chinese-translation y buildId PMM-v1.3.4-desktop-auat-rc2. Deben reconciliarse juntas estas identidades y el inventario.

## Limitacion que impidio cerrar los dos asuntos

El conector permitio leer texto e historial, pero la descarga raw de PMM.exe fue rechazada y la lectura base64 devolvio contenido vacio, aunque si identifico el blob. El contenedor no pudo clonar por falta de resolucion de github.com; tampoco se obtuvo el ZIP por las rutas de descarga disponibles. No se dispuso de los bytes completos del paquete ni de un entorno Windows.

Por tanto no se calculo aqui el SHA-256 real de los ejecutables, no se leyo su informacion de compilacion, no se hizo una comparacion binaria y no se verifico su paridad funcional. Los hashes de NATIVE_ARTIFACTS.json son **declaraciones heredadas del manifiesto**, no calculos nuevos.

La busqueda de codigo en la rama predeterminada y dos busquedas de archivos historicos no recuperaron las fuentes exactas. Se encontro un resumen historico de agosto, no un paquete fuente recuperable. No se afirma haber agotado todas las ramas, releases y respaldos.

## Codigo entregado

`session01_prepare.py` lee una copia Git local completa, solo en la rama reliability y con el paquete sin cambios pendientes. No cambia el checkout, no ejecuta PMM, no hace red, no modifica Git y no publica nada.

A partir de los bytes reales prepara:

- cuatro archivos de metadata: VERSION.txt, BUILD_ID.txt, RELEASE_MANIFEST.json y SHA256SUMS.txt;
- un inventario completo nuevo, sin autorreferencia, conservando todas las demas propiedades del manifiesto salvo los campos de identidad/estado indicados por el codigo;
- un paquete de evidencia con los tres ejecutables, sus metadatos originales y las fuentes/scripts de build disponibles;
- `report.json`, distinguiendo hashes comprobados de la paridad fuente/binario, que sigue sin demostrarse.

Antes de generar salidas, rechaza un nativo cuyo SHA-256 o blob Git no coincida con la base prevista, o una dependencia cuyo hash no coincida con sus pins. No actualiza pins para silenciar discrepancias. No incluye Workspace, credenciales, .git ni logs personales. No firma binarios.

La herramienta genera una **propuesta de metadata**, no la aplica. En particular, la representacion de fecha de release no publicada (`releaseDate: null`) y los consumidores de ese campo deben revisarse con el paquete completo antes de integrar el parche. No copiar solamente VERSION.txt: se revisan y aplican los cuatro archivos juntos.

## Validacion realizada

Compilacion de sintaxis Python y 12 tests locales con fixtures sinteticos: identidad coherente, preservacion de versiones de componentes y propiedades ajenas, cobertura del checksum sobre bytes finales, ausencia de autorreferencia, idempotencia, rechazo de nativos/dependencias/runtime alterados, claves JSON duplicadas, version no prevista, rutas inseguras y symlinks.

Los tests sustituyen los tres nativos por datos de prueba y sus pins correspondientes. **No validan los binarios de PMM, su GUI, los idiomas, el flujo CLI completo ni el paquete real.** No se ejecutaron Actions, tests remotos, PMM ni antivirus.

## Continuacion exacta

Leer NEXT_SESSION.md. Con los bytes del paquete real disponibles, cerrar primero la identidad y el inventario en una tanda acotada. Recuperar/comparar Host, Runtime y FixLab en tandas separadas, conservando los binarios actuales hasta la aceptacion local correspondiente.
