# FixLab - reconstruccion por componentes

**04A-2 completada solo para PMMDLT1. No hay motor FixLab completo compilable.**
La fuente original sigue sin recuperarse; los ocho fragmentos del overlay historico
continuan invalidados por la auditoria 04A. No repetir esa busqueda sin una pista
nueva ni modificar su hash esperado. PMMFixLab.exe original permanece intacto.

## Componente nuevo

[PMMDLT1/README.md](PMMDLT1/README.md) contiene el lector/aplicador en memoria,
API, limites y pruebas. [FORMAT.md](PMMDLT1/FORMAT.md) documenta el layout derivado
de datos y evidencia estatica, no de una fuente original recuperada.
22 tests Go, 10 Python y race Linux pasaron. Los metadatos de los 137 payloads
coinciden con un parser independiente; no se transformaron assets reales.
El EXE generado por su build.py es un harness de pruebas, NO PMMFixLab.

## Procedencia anterior conservada

`audit_source.py` sigue comprobando el EXE, recetas y el overlay como datos. Su
resultado BLOCKED/codigo 2 para el overlay NO invalida la reconstruccion aislada,
ni equivale a un fallo funcional del programa. `inspect_binary.py` compila un
lector de metadata en una salida externa; nunca ejecuta PMMFixLab.exe.
`SOURCE_CONTRACT.md` y evidence/ conservan el mapa/contratos historicos de 04A.

## Siguiente

04A-3: PAK v11/readback; despues UAsset/core R1 y orquestacion V2/CLI. Solo una
candidata completa permite iniciar comparacion 04B. Leer ../../NEXT_SESSION.md.
No sustituir binarios, alterar CKL o anunciar aceptacion Windows/Palworld.
