# Tanda 03B - comparacion Runtime y gate de aceptacion

Fecha: 2026-09-18. Rama: v1.5.0.1-PMM-reliability.
Entrada: 4182b4937bf446e41d9a6a937ac122a499d20b90.
Arbol: 50da4357aa638381f7b59262cb3cddadc276ebfa.

CERRADA en comparacion, correccion minima del inventario y gate. REL-01 sigue
ABIERTO. No se recupero fuente original ni se demostro equivalencia Windows.

## Entrada y comparacion reproducible

ZIP 03A verificado: 3fc9ff7c958a4978c34712b1c11097c1606398026a4d32949b95dc7d60d87497.
Sus 1051 archivos reproducen el arbol Git remoto. S03A se recompilo en una salida
nueva fuera del checkout y reprodujo su hash. No se repitieron busquedas historicas.

| Artefacto | SHA-256 | Bytes | Funciones main.* en pclntab |
| --- | --- | --- | --- |
| Original | e90341d8449b485cb04af3c00d357bc8c67e87070644ff6bf7d27121a00c422a | 6365184 | 80 |
| S03A reproducido | 10effcaf7a5d02836104a5bb2bd90eeb52c755ac78fc4670b5eea11b235b938f | 6366208 | 81 |
| S03B | 45e017190c379774afd24557084e7fa532bbef58b6ead6869294943bb72ed0be | 6366720 | 81 |

compare_runtime.py verifica pins/receta/fuentes y regenera PE/buildinfo/pclntab con
un lector compilado LOCAL. Nunca ejecuta los EXE inspeccionados. Los tres son
AMD64, subsistema consola=3, Go1.23.2. Original/S03B comparten .idata/.rsrc/.symtab/
.xdata crudas; .text difiere. Ocho funciones comunes tienen el mismo hash de bytes
crudos; las otras diferencias pueden incluir direcciones/relocaciones/padding.
Nombres o secciones coincidentes NO prueban semantica de todo el programa.
comparison.json conserva resumen y hashes; los informes completos original.json/s03a.json/s03b.json
van en el ZIP de evidencia y se regeneran con el comparador.

## Contratos revisados: fuente, no ejecucion del original

main.go/util.go/nativeui.go/process.go/doctor.go/shell nativa de la candidata se
contrastaron con snapshot y archivos de contrato/WPF del paquete. El binario solo
aporta metadata y tabla de funciones. Esta tabla NO afirma que el original ejecute
cada rama exactamente igual; esa equivalencia queda para pruebas reales.

| Area | Contrato de fuente candidata | Evidencia / limite |
| --- | --- | --- |
| CLI | Sin args -> doctor --json; version/--version/-v -> 1.2.1; doctor/security imprimen JSON | main.go intacto; no se ejecuto CLI Windows |
| Errores CLI | root=250; knowledge invalido=2; game no encontrado=3; deps.status no listo=4; ensure/start deps fallo=5; hash fallo=6; uso=64; fail()=1 | Pueden existir fallos antes del switch; no inferir salida por nombres de funciones |
| self-test | manifest error=2, knowledge error=3, BUILD_ID ausente=4, ok=0 | Lee archivos, no reemplaza aceptacion funcional |
| Root | PMM_ROOT no vacio domina (Abs); si EXE esta en Engine usa padre; si no, su carpeta | PMM_HOST_ROOT no participa; ruta no validada/autenticada por este algoritmo |
| Start | state -> ensureDependencies(ifNeeded=true) -> UI -> closed/runtime-exit | Puede escribir Workspace, borrar/reparar dependencias y hacer red; NO se ejecuto |
| Doctor/status | inspectDependencies puede ejecutar dotnet --list-runtimes, PMMCore y AssetReader; doctor tambien PS y deteccion del juego | No son lectores estaticos puros; doctor descarta error de manifest |
| PowerShell | Prioriza pwsh en PATH, despues WINDIR WindowsPowerShell y PATH powershell; probe CombinedOutput sin timeout | Native forzado tambien sondea; modo FullLanguage no prueba PS5.1 |
| UI | WPF si shell+FullLanguage; demas/nativa forzada -> Win32 | Modelo de ruta probado; no apariencia/rendimiento Windows |
| WPF argv/entorno | STA, NoProfile, ExecutionPolicy Bypass, File script; cwd=root; env nil; streams heredados | Contrato S03A preservado, no hardening Bypass ni aislamiento |
| Retornos UI | Exito=0, ExitError del hijo propagado; falta/no inicio=30; shell nativa fallida=31 | cmd.Run espera hijo directo; no vida coordinada de todos los descendientes |
| Processes | default 5min; timeout=124; error inicio/no ExitError=127; exit hijo propagado | bytes.Buffer sin limite, WaitDelay sin fijar; deadline no garantiza retorno si quedan pipes abiertos |
| Sesion/ready | Runtime/WPF escriben mismo state.txt; WPF tras ContentRendered emite HWND; fallback nativo no emite ready | No atomico ni autenticado; multiples WPF pueden competir; acuerdo propuesto separado |
| Dependencias | Verificaciones de pins antes de uso en recorrido sano; repair online/sibling y reemplazos heredados | Parser de inventario corregido abajo; NO redisenadas reparaciones |

## R03B-01 - defecto demostrado y corregido SOLO en candidata

El lector testRuntimeInventory ignoraba Scanner.Err(). Con veinte archivos validos
seguidos de una linea de 70 KiB, Scan terminaba por error y se certificaba el prefijo
valido. Tambien se aceptaba repetir un registro de ruta. Dos tests nuevos fallan
contra S03A y pasan tras corregirlo; evidence/s03b/inventory-before.txt conserva
la reproduccion. El manifiesto del fixture fija el hash de esos bytes a proposito:
esto no muestra como burlar el pin de un inventario autentico ni comprometer el SO.

Ahora se exige lectura completa sin error, cada ruta unica (clave case-insensitive)
y recorrido de archivos sin errores. Una entrada extra falla explicitamente en vez
de usar un contador sentinel. No se cambia el pin, minimo de 20 entradas, red,
reparacion, selector PowerShell, root, UI ni contratos de salida.

El inventario REAL distribuido de .NET (188 archivos) se comprobo por lectura,
mediante el mismo testRuntimeInventory corregido, sin ejecutar dotnet ni PMM.
Sigue aceptado. No se ha simulado fallo de disco/Walk Windows: queda en R05-09.
Esto es un bug probado de la fuente candidata, no del EXE original sin ejecutarlo.

## Riesgos que siguen abiertos

R03A-01..06 permanecen salvo la correccion local del parser, que no cierra la
politica completa de dependencias. Host H02B-04/05/06 sigue bloqueado.

- R03B-02: doctor/native refresh ignoran error de loadReleaseManifest; el loader
  valida schema pero no todos los pins/rutas. hashMatches con pin vacio acepta
  existencia; contrato vacio y rutas no confinadas no deben autorizar ejecucion.
  Resolver antes de promocion con validacion local, sin cambiar pins para aceptar
  bytes inesperados. Estado: OPEN; solo revision de fuente en esta tanda.
- R03B-03: processCommand multiplica segundos por time.Second sin controlar
  overflow; opciones invalidas pueden ignorarse. reg.exe en game.go tampoco
  tiene plazo. Estado: OPEN para supervision/CLI; no se lanzaron esos comandos.
- R03B-04: rutas heredadas Data/config.json, Tools/dotnet y Mods no cambian y no son una
  migracion probada a Workspace/Engine. saveDotnetSelection compara Tools aunque
  inspectDependencies selecciona Engine. Revisar consumidor Common.ps1 antes
  de cambiar; no confundir rutas del snapshot con comportamiento original.
- Los buffers no acotados y pipes heredados implican que un timeout de proceso
  no es limite completo de tiempo/memoria. CommandContext mata hijo directo,
  no certifica cierre de familia ni EOF. 02C/08 necesitan stubs controlados.
- Los mensajes ready y el PID en un JSON no autentican ventanas. Se fija en
  HOST_RUNTIME_HANDSHAKE.md un canal local con identidad de proceso comprobada
  por SO, generation, ACK y cierre terminal. Es una propuesta, NO implementacion.

## Pruebas y limites

18 funciones de test Go pasaron: 13 anteriores y 5 nuevas (4 fixtures de inventario
mas 1 lectura explicita del inventario distribuido). Incluyen los 9 subcasos UI
previos. 15 tests Python pasaron (9 previos + 6 del comparador). Los logs incluyen
los casos realmente ejecutados; no se cuentan intentos sin tests seleccionados.
Dos builds S03B en salidas distintas son identicos en Linux/amd64 Go1.23.2.
No es prueba entre sistemas ni equivalencia con original. No se ejecutaron
PMM/candidatas Windows, PS, WPF, .NET, reparaciones ni AV; no se enviaron muestras.
La lectura de metadata del binario original no lanza ese binario.

WINDOWS_RUNTIME_ACCEPTANCE.md deja 18 casos NOT_RUN. Incluye estados adversos,
root, efectos de diagnosticos, instancias, cierre, logs, PS5.1 y rollback.
El cierre de esta tanda no autoriza sustituir Engine/PMMRuntime.exe.

## Preservacion y siguiente tanda

PMM/ (629 archivos, 628 hashes), Host S02B, snapshot, FixLab, idiomas y workflows
siguen identicos. Build distribuido s01b preservado. Un commit [skip ci], sin
PR/tag/release. Evidence de 03A/02B permanece historica e intacta.

02C se divide para no volver a una sesion enorme: 02C-1 plazos/sondeos/supervision
con stubs; 02C-2 canal de instancia/handoff con adapters Windows. Empezar por
02C-1 segun NEXT_SESSION.md, no reabrir 01B ni volver a pedir el ZIP.

Referencias primarias (2026-09-18): https://pkg.go.dev/bufio#Scanner.Err,
https://pkg.go.dev/os/exec#Cmd y las API Windows de HOST_RUNTIME_HANDSHAKE.md.
Se contrasto tambien bufio/scan.go y os/exec/exec.go del Go1.23.2 local utilizado.
