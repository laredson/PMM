# FixLab - procedencia, 04A parcial

**No contiene todavia la fuente del motor ni una candidata PMMFixLab compilable.**
Esta carpeta reserva su ubicacion y conserva herramientas de auditoria de lectura.
Estado: `BLOCKED_SOURCE_RECOVERY`; no reemplazar `PMM/Engine/PMMFixLab.exe`.

## Lo comprobado

El ejecutable original de 2.790.912 bytes coincide con SHA-256
`8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe`.
Sus metadatos dicen Go1.23.2, Windows/amd64 y modulo
`github.com/laredson/pmm/fixlabengine`. Las 63 entradas main.* incluyen wrappers.
PCToLine las vincula a main.go, delta.go, pakv11.go, recipe.go, uasset.go y variant.go.
Son nombres/lineas conservados por el compilador, NO codigo original recuperado.

La referencia `Development/Source/FixLabEngine/` no existe en el arbol inspeccionado.
Los ocho fragmentos del overlay R2 son los mismos blobs de la rama historica Fix Lab.
Su concatenacion de 155483 caracteres falla Base64 estricto. Agregar solamente
el padding en una copia tampoco repara el archivo: hash distinto y XZ corrupto.
No se adopta contenido parcial ni se cambia el hash esperado para aceptarlo.

## Herramientas

Desde la raiz del repositorio (Python 3.9+):

```text
python -B Development/Reliability/NativeCandidates/FixLab/audit_source.py
```

Solo stdout/lectura. Comprueba EXE contra pins, cinco recetas y las 260 referencias
a 137 payloads unicos, sin aplicar transformaciones ni leer el juego. Devuelve **2**
con informe BLOCKED mientras el overlay no pase; ese resultado es deliberado.
No ejecuta workflows, PMM, .NET, PowerShell, repak ni reparaciones.

Con Go1.23.2 YA instalado:

```text
python -B Development/Reliability/NativeCandidates/FixLab/inspect_binary.py --out ../PMM-FixLab-04A-inspection
```

La salida debe ser nueva y externa al repositorio. Compila y ejecuta UN LECTOR
LOCAL de metadatos, nunca el EXE que inspecciona. Produce original-go.json,
inspection-recipe.json y COMPLETE.txt. El lector no es el motor FixLab.
Las dependencias son de la biblioteca estandar; red y auto-descarga deshabilitadas.

Tests auxiliares, desde esta carpeta:

```text
python -B -m unittest -v test_audit_source
go test -v tools/fixlab_meta.go tools/fixlab_meta_test.go
```

Quince tests Python y cinco tests Go del lector pasaron en Linux. Las inspecciones
repetidas producen el mismo informe. No hay recompilacion del motor ni pruebas
funcionales Windows/Palworld. Los informes compactos viven en evidence/; el ZIP de
evidencia conserva las salidas completas y las herramientas para regenerarlas.

## Continuacion

Leer SOURCE_CONTRACT.md y ../../NEXT_SESSION.md. 04B no puede comparar una candidata
inexistente. Completar 04A por recuperacion verificable de los seis fuentes/go.mod,
o reconstruccion modular declarada y probada con fixtures. No reejecutar el bootstrap
ni repetir la misma busqueda sin una pista nueva. La referencia R2 puede pertenecer
a una revision anterior: ni un overlay reparado certificaria por si solo 0.2.0.
