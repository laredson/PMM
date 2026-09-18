# Estado actual: S02C-1

Esta candidata ahora depende del modulo local ../Supervision; build.py lo copia
fuera del checkout y verifica sus hashes. Ver ../../SESSION02C1_FINDINGS.md y
../Supervision/README.md para limites, comandos, cambios de consola/CLI y bloqueos.
Los apartados S02B/S03B que siguen son contexto historico, NO resultados C1.
Comparador actualizado a hashes C1; los informes historicos permanecen intactos.
No copiar el EXE sobre el programa distribuido. Windows/familias/HWND pendientes.

---

# Runtime candidato - cierre S03B

RECONSTRUCTION_NOT_ORIGINAL_RECOVERED. No instalar ni sustituir
PMM/Engine/PMMRuntime.exe. REL-01 y aceptacion Windows siguen abiertos.

S03A esta conservado en el commit 4182b49 y evidence/ historico. Se reprodujo su
hash antes de comparar. S03B cambia SOLO testRuntimeInventory en deps.go: rechazo
de lectura interrumpida, rutas duplicadas y errores de recorrido. No redisenar
reparaciones, politica PowerShell o UI a partir de este cierre.

Candidata S03B: 45e017190c379774afd24557084e7fa532bbef58b6ead6869294943bb72ed0be.
Bytes: 6366720. Dos builds en rutas distintas identicos en Linux/amd64 Go1.23.2.
Original: e90341d8449b485cb04af3c00d357bc8c67e87070644ff6bf7d27121a00c422a.
S03A: 10effcaf7a5d02836104a5bb2bd90eeb52c755ac78fc4670b5eea11b235b938f.
Original/S03B NO identicos; .text difiere. Secciones/funciones iguales no certifican
semantica. El componente sigue version 1.2.1; el producto es 1.5.0.1.

Desde la raiz del repositorio, con Python3.9+ y Go1.23.2 YA instalado:

```text
python -B Development/Reliability/NativeCandidates/Runtime/build.py --out ../PMM-Runtime-S03B
python -B Development/Reliability/NativeCandidates/Runtime/compare_runtime.py --candidate ../PMM-Runtime-S03B/PMMRuntime-candidate.exe --build-report ../PMM-Runtime-S03B/build-report.json --previous <S03A-EXE> --out ../PMM-Runtime-S03B-compare
```

Salidas nuevas y externas. La receta no descarga ni instala, no ejecuta Runtime;
solo ejecuta helpers locales de build/lectura. El comparador exige los tres pins
y comprueba que el reporte de build cubra los fuentes actuales. COMPLETE.txt
marca una salida terminada, nunca una aprobacion para distribucion.

Pruebas desde esta carpeta en Linux/amd64 Go1.23.2, GOTOOLCHAIN=local,
GOPROXY=off, GOSUMDB=off, GOWORK=off, GOENV=off y CGO_ENABLED=0:
`go test -v -count=1 -timeout=60s ./...`;
`python -B -m unittest -v test_tools test_compare_runtime`.
PMM_TEST_PACKAGE_ROOT debe apuntar al PMM distribuido para la prueba de lectura
real; sin esa variable se omite ese caso. No escribir dentro del paquete.

Resultados S03B: 18 tests Go (incluido inventario real por lectura), 9 subcasos UI,
15 tests Python. No PS/.NET/WPF/Windows/AV. Fallos de reproduccion S03A separados
de los resultados corregidos en evidence/s03b/; reports completos incluidos.

UI_PROCESS_CONTRACT.md conserva el analisis S03A. HOST_RUNTIME_HANDSHAKE.md
concreta el acuerdo propuesto para 02C, sin simular autenticacion en archivos.
SESSION03B_FINDINGS.md y WINDOWS_RUNTIME_ACCEPTANCE.md estan dos niveles arriba.
Siguiente: NEXT_SESSION.md -> 02C-1; no tocar binarios/idiomas del paquete.
