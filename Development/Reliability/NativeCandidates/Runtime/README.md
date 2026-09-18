# Runtime candidato S03A

Estado: RECONSTRUCTION_NOT_ORIGINAL_RECOVERED. No instalar ni sustituir
`PMM/Engine/PMMRuntime.exe`. REL-01 y la aceptacion Windows siguen abiertos.

Base: `Development/Source/Runtime/` en f52101800b92b696b0600bb3382f89292a926cc8.
Se conservan todos los .go y go.mod necesarios, no un parche incompleto.
Los wrappers BUILD_RUNTIME.cmd antiguos no se copian: usar solo build.py.

## Cambio limitado

- `ui_plan.go` separa decisiones de ruta, argv y presentacion para probarlas.
- `nativeui.go` construye el hijo WPF en `legacyUICommand` sin ejecutarlo durante
  los tests; conserva cwd, stdin/stdout/stderr, entorno heredado y retorno.
- `process_windows.go` separa UI de utilidades: ambas usan CREATE_NO_WINDOW,
  pero solo el hijo WPF deja de solicitar HideWindow/SW_HIDE. Reconstruye el
  contrato del manifiesto, no prueba que sea el codigo original.
- `process_other.go` permite probar la construccion sin ejecutar Win32.
- `ui_plan_test.go` prueba rutas, argv, entorno, streams y state.txt con fixtures.
- `main.go`, seguridad, dependencias, archivos y shell nativa se conservan.

No se retira Bypass, cambia PowerShell, elimina red o autentica HWND en S03A.
`UI_PROCESS_CONTRACT.md` delimita estos riesgos y las entradas para 03B/02C.

## Build y evidencia

Desde la raiz, con Python 3.9+ y Go **1.23.2 ya instalado**:

```text
python -B Development/Reliability/NativeCandidates/Runtime/build.py --out ../PMM-Runtime-S03A
```

La salida debe ser nueva y externa al checkout. No se descarga toolchain ni
modulos. El candidato es Windows/amd64, subsistema consola 3, CGO=0. Los unicos
binarios ejecutados por la receta son lectores PE y el helper de icono de build.
El candidato no se ejecuta. No hay firma, instalacion, antivirus ni publicacion.

SHA-256 S03A: `10effcaf7a5d02836104a5bb2bd90eeb52c755ac78fc4670b5eea11b235b938f`.
Tamano: 6366208 bytes. Dos builds en rutas distintas son identicos en
Linux/amd64 con Go1.23.2; no se afirma reproducibilidad entre sistemas.
Original: `e90341d8449b485cb04af3c00d357bc8c67e87070644ff6bf7d27121a00c422a`.
Original y candidata NO son identicos: .text difiere. Cuatro secciones crudas
coinciden, pero no demuestran equivalencia funcional.

`evidence/` conserva receta, hashes, diff y resultados resumidos. La receta
regenera original-go.json/candidate-go.json (pclntab) y ambos informes PE
completos, incluidos tambien en el ZIP descargable de evidencia. Esos nombres
son funciones de la tabla Go, no una recuperacion de codigo fuente original.

## Pruebas locales realizadas

Desde esta carpeta, en Linux/amd64 con Go1.23.2 y variables de build offline:
`go test -v -count=1 -timeout=60s ./...` y `python -B -m unittest -v test_tools`.
13 funciones Go pasaron (7 fixtures heredados + 6 nuevos; 9 subcasos de ruta),
mas 9 tests Python. No se inicio PowerShell, Runtime, WPF ni ningun EXE Windows.
Las pruebas de presentacion comprueban el modelo, no la apariencia real Win32.

Siguiente: 03B, comparacion detallada y gate de Runtime. No tocar Host aqui.
