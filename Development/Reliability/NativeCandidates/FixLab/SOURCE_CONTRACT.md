# FixLab: contrato que debe conservar una fuente recuperada o reconstruida

Estado 04A: fuente NO recuperada, motor candidato NO construido. Este documento
combina lecturas del paquete con metadatos del EXE; no constituye equivalencia.
Base: 7d8b5265c881746aefd8ffae9ba592bb0e6ce589, paquete s01b intacto.

## Seis unidades identificadas en metadatos Go

| Archivo compilado | Entradas main.* | Responsabilidad inferida de nombres y contratos |
| --- | ---: | --- |
| main.go | 2 | CLI/errores: main y failf |
| delta.go | 4 | applyDeltaPatch y SHA-256; PMMDLT1 segun documentacion de recetas |
| pakv11.go | 11 | escritura PAK v11, indices, hash de rutas y readback |
| recipe.go | 16 | nucleo R1, proveedores, nombres actuales, soporte y restricciones |
| uasset.go | 19 | cabecera/nombres/imports/exports, serializacion y relocalizacion |
| variant.go | 11 | seleccion de base, operaciones V2, validacion y requirements |

63 incluye funciones auxiliares generadas por Go. Los limites/lineas estan en
evidence/binary-map.json; los nombres NO contienen los cuerpos originales.
El ejecutable declara Go1.23.2, windows/amd64 y modulo
`github.com/laredson/pmm/fixlabengine`, sin dependencias de modulos externos
registradas. Eso no descarta uso de DLL o comportamiento no observado.

## Contrato del llamador real

`PMM/Modules/FixLab/FixLabService.ps1`, lineas 1384-1460 de esta base, invoca:

```text
PMMFixLab.exe requirements --recipe <recipePath>
PMMFixLab.exe build --recipe <recipePath> --source-root <sourceRoot> --game-reference <gameRefRoot> --output <output> --report <report>
```

El primer resultado debe ser JSON utilizable con `referenceFamilies`.
El segundo necesita salida cero, PAK creado, informe JSON creado y
`validation.readback`/`validation.byteExact` verdaderos segun el llamador.
No se ejecutaron esas invocaciones en 04A. Otros comandos del EXE no se infieren
solo por strings; documentarlos al disponer de fuente o ejecucion autorizada.

El llamador ya selecciona un donante exacto, requiere Game Reference Current,
extrae la fuente a un Workshop del job y valida el sufijo de nombre `_P.pak`.
No debe eliminarse ninguno de esos controles para acomodar una candidata.
La ruta AUAT `auat-property-upgrade` es independiente: probarla no acepta el
motor nativo de recetas Gura. No se cambia AUAT ni su fuente en esta tanda.

## Datos disponibles, no ejecutados

Cinco recetas V2 comparten `recipe-core-r1.json`. Su auditoria confirma 260
referencias SHA-256 a 137 payloads unicos distribuidos, sin aplicar parches.
Las operaciones presentes son remove, copy y patch; los nombres y minimos de
familias se conservan en las recetas, no se trasladan a constantes del motor.
Los dos donantes exactos son alternativas admitidas: no exigir ambos por una
interpretacion equivocada del contrato.

La documentacion de producto especifica PMMDLT1 COPY/LITERAL, reconstruccion
core R1, escritura PAK v11 y lectura independiente con igualdad por entrada.
Estos son requisitos para la reconstruccion, NO primitivas implementadas aqui.
Una comprobacion correcta de hashes de payload no prueba sus transformaciones.

## Camino acotado de continuacion

No saltar a 04B mientras no haya motor candidato completo.

1. Recuperacion: una copia verificable de main.go, delta.go, pakv11.go, recipe.go,
   uasset.go, variant.go y go.mod (mas cualquier archivo requerido por el build).
   Registrar origen, version y hashes, revisar antes de compilar. No existe
   garantia de que los seis sean todos los archivos fuente a partir de pclntab.
2. Si no aparece una fuente nueva, reconstruir por contratos EN SUBTANDAS:
   primero codec PMMDLT1 con fixtures sinteticos; despues PAK v11/readback;
   despues UAsset/core R1 y orquestacion V2/CLI. Cada parte se etiqueta como
   reconstruccion parcial; no se instala ni simula un motor completo.
3. Solo una candidata completa recibe build reproducible y comparacion 04B.
   Cambiar un hash esperado, saltar una validacion o reutilizar PAK reparados no
   prueba paridad. No distribuir datos del juego ni del donante como fixtures.

El overlay R2 actual no es entrada utilizable: Base64 invalido; agregar padding
no produce el hash esperado ni un XZ valido. No ejecutarlo ni reintentar bootstrap.
Si aparece una copia autentica, primero comparar su SHA-256 con
39622b989a4b4a1056f3efc6b527828c3325359c90e5f7ffe399776c6536fcbb;
extraer SOLO codigo como datos en una carpeta aislada y comprobar su version.
No se ha demostrado que R2 sea ya el codigo de 0.2.0-variant-recipes.

## Referencias de metodo

- https://docs.python.org/3/library/base64.html : decodificacion estricta/padding.
- https://pkg.go.dev/debug/gosym#Table.PCToLine : archivo/linea del contador de programa.
- https://pkg.go.dev/debug/buildinfo#Read : lectura de metadatos sin ejecutar el binario.

Consultadas 2026-09-18 y contrastadas con el Go1.23.2 local usado. Estos metodos
no recuperan cuerpos fuente ni reemplazan pruebas funcionales Windows/Palworld.
