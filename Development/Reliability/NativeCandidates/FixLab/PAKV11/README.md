# PAKV11 - componente 04A-3

Biblioteca Go reconstruida: Build, Read y Verify sobre bytes en memoria.
No contiene main de FixLab, no transforma UAsset ni aplica recetas productivas.
PMMDLT1 permanece separado e intacto. Leer FORMAT.md para el perfil limitado.

- Build produce todos los headers/indices/hashes y un footer v11 determinista.
- Read comprueba el paquete entero; no acepta un prefijo valido como archivo completo.
- Verify compara los nombres y bytes releidos con expectativas del caller.
- Ninguna funcion extrae archivos, instala mods, descarga componentes o ejecuta procesos.

## Contrato y limites

Entradas deben permanecer inmutables durante cada llamada. Se devuelven copias de
contenido, no aliases del archivo original. Contexto obligatorio, cancelacion
cooperativa durante validacion/hash/copia y error sin resultado parcial.

Defaults/techos: archivo PAK 256 MiB; por archivo 64 MiB; indices agregados 32 MiB;
16384 archivos; 1024 bytes por ruta; profundidad 32, componente 255. Limits permite
reducir techos, no elevarlos. Se valida crecimiento de indices antes de crear sus
buffers. Estos limites NO son un techo de RSS ni un plazo absoluto de CPU.
El caller sigue siendo responsable de leer inputs confiables/inmutables y de
publicar resultados de manera transaccional; esa capa no existe en esta tanda.

Se rechazan traversal, ADS, nombres de dispositivos, caracteres Windows reservados,
colisiones de mayusculas y conflictos archivo/directorio. El mount virtual del
PAK no se concatena a una ruta de disco por esta biblioteca.

## Repetir pruebas

Desde esta carpeta, Go1.23.2 instalado y sin acceso de modulos a red:

```text
go test -count=1 ./...
python -B -m unittest -v test_reference
```

19 tests Go por defecto y un test de exportacion opt-in (SKIP sin variable).
Las dos funciones Fuzz y sus semillas se contabilizan aparte, no como tests Windows.
En 04A-3 se ejecutaron los 20 tests con PMM_PAKV11_EXPORT apuntando a una carpeta
absoluta NUEVA y externa al repositorio. Esa opcion exporta solo fixtures sinteticos:

```text
python -B verify_reference.py --corpus <carpeta-de-fixtures>
```

El lector Python compara sus resultados y los bytes esperados con el informe Go.
No llama a Go, repak, FixLab o UnrealPak. La suite race Linux paso; tambien dos
fuzz acotados del archivo y de indices re-sellados sinteticamente para llegar a
validaciones internas. Ver Development/Reliability/SESSION04A3_CHECKS.json desde la raiz del repositorio.

## Build de pruebas, NO del motor

Desde raiz del repositorio:

```text
python -B Development/Reliability/NativeCandidates/FixLab/PAKV11/build.py --out ../PMM-PAKV11-tests
```

Salida nueva externa obligatoria. Compila un harness Windows/amd64, copia codigo
y fixtures, deja hashes/receta y no ejecuta ese EXE. Dos compilaciones fueron
identicas en Linux/amd64 Go1.23.2; no demuestra reproducibilidad entre toolchains.
El harness necesita su carpeta source/testdata para sus tests de golden.
**No copiar pakv11-tests.exe sobre PMMFixLab.exe. No es una actualizacion.**

Evidencia compacta en evidence/. Evidencia completa: logs JSONL, corpus sintetico,
disassembly estatico y build-report del ZIP de la tanda. No contiene datos del juego.
Motor FixLab completo, equivalencia original y aceptacion Windows/Palworld pendientes.
