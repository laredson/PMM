# PMMDLT1 - componente reconstruido, tanda 04A-2

**Biblioteca funcional aislada; NO motor FixLab completo ni fuente original recuperada.**
No modifica PMM/, no ejecuta archivos, no hace red y no escribe resultados en disco.
`Apply` entrega bytes solo despues de todas las comprobaciones. El codec no esta
integrado en PMMFixLab.exe; no sustituir ningun ejecutable distribuido.

## API y frontera de confianza

`Inspect(ctx, patch, expectedPatchSHA256, limits)` valida identidad y estructura
completa. Devuelve dimensiones, operaciones y limites minimos de referencias.
Sin assets fuente NO puede certificar sus hashes ni el contenido transformado.

`Apply(ctx, Request)` verifica el SHA-256 del parche, TODOS los datos de referencia
(incluso referencias no utilizadas), los rangos y el SHA-256 esperado de salida.
En cualquier error devuelve nil. COPY indexa la lista ordenada de referencias;
LITERAL copia datos incorporados en el parche. No hay rutas, comandos ni scripts.

El llamador debe aportar hashes de una receta confiable, no calcularlos sobre datos
arbitrarios para hacerlos pasar. Debe conservar los slices inmutables durante la
llamada. Adquisicion segura de archivos, confianza de receta, concurrencia de datos,
staging/commit/rollback y escritura PAK pertenecen a capas futuras. No hay garantia
ante un proceso ya comprometido o falta global de memoria.

## Limites de esta candidata

Por llamada: parche 16 MiB, datos descomprimidos 64 MiB, salida 256 MiB,
1.000.000 instrucciones, 1.024 referencias, 256 MiB por referencia y 512 MiB
sumando referencias. `Limits{}` usa esos valores; valores no cero solo pueden
reducirlos. Son un perfil de seguridad de la reconstruccion, NO limites universales
del formato ni prueba de equivalencia con el motor original. Un caso futuro mayor
requiere revision explicita, no elevarlos automaticamente.

La lectura/hash/copia comprueba cancelacion por bloques de 32 KiB y por operacion.
Es cancelacion cooperativa; no promete latencia absoluta, RSS exacto ni ocultar
fallos del SO. Los slices del llamador, crecimiento de buffers, runtime Go y otras
llamadas pueden ocupar memoria adicional a estos limites individuales.

Se rechazan cuerpos/trailers incompletos, checksum zlib incorrecto, datos sobrantes
comprimidos o descomprimidos, multiples streams, opcode desconocido, referencias
fuera de rango, cantidades imposibles y hashes ausentes/invalidos/no coincidentes.
Instrucciones de longitud cero y salida vacia estan definidas y probadas.

## Pruebas reproducibles (Go1.23.2 y Python 3.9+)

Desde esta carpeta, sin descargar dependencias:

```text
go test -count=1 -v ./...
go test -race -count=1 ./...
python -B -m unittest -v test_audit_corpus
python -B audit_corpus.py --package <ruta-absoluta-a-PMM> --summary
```

Los tres primeros usan datos sinteticos. Para activar ademas la lectura del corpus
real, establecer `PMM_FIXLAB_PACKAGE` a la carpeta absoluta PMM antes de go test.
Sin esa variable la prueba del corpus se marca SKIP, no PASS. El auditor Python
verifica cinco recetas por pin y sus 260 referencias; el test Go compara un digest
canonico de TODOS los metadatos de los 137 parches con el lector Python independiente.
Ninguno aplica esos parches a datos de juego/donantes. Ver FORMAT.md.

Desde la raiz del repositorio:

```text
python -B Development/Reliability/NativeCandidates/FixLab/PMMDLT1/build.py --out ../PMM-PMMDLT1-S04A2
```

Salida NUEVA y externa. Solo compila un ejecutable Windows de TEST, sin ejecutarlo.
No construye PMMFixLab.exe. La receta fija Go1.23.2, GOTOOLCHAIN=local, GOPROXY=off,
GOSUMDB=off, GOENV=off y GOWORK=off. La carpeta source de salida sirve para compilar
los tests Go; para ejecutar el auditor Python, usar el arbol FixLab completo,
pues importa las rutinas de lectura seguras de ../audit_source.py.

## Estado

22 funciones Test con aserciones (21 sinteticas + 1 corpus) y 10 tests Python
pasaron; detector de carreras Linux correcto. Dos campanas fuzz acotadas del
codec pasaron, no equivalen a aceptacion Windows. Dos builds del test Windows
fueron identicos. No motor original/Windows/juego/reparacion/antivirus ejecutados.
La fuente completa necesita PAK v11/readback, UAsset/core R1 y orquestacion V2/CLI.
04A sigue abierta; siguiente 04A-3. Los registros de 04A original se conservan.
