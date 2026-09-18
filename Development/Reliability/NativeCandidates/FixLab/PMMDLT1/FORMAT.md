# PMMDLT1 - formato reconstruido y evidencia, S04A-2

Base: 1b15621cf988bd7e582af19e46ea7ad81796fad8. No se recupero delta.go original.
La reconstruccion combina documentacion de producto, lectura estatica de la
funcion original y dos decodificadores independientes sobre el corpus distribuido.

## Layout observado

| Ubicacion | Campo | Representacion |
| --- | --- | --- |
| Archivo, bytes 0..7 | Magic | ASCII PMMDLT1 seguido de LF (8 bytes) |
| Resto del archivo | Instrucciones comprimidas | Un stream zlib (RFC 1950) completo |
| Cuerpo, bytes 0..7 | Longitud final declarada | uint64 little-endian |
| Cuerpo, bytes 8..11 | Numero de instrucciones | uint32 little-endian |
| Instruccion | Opcode | uint8: 0=COPY, 1=LITERAL |
| COPY despues del opcode | Indice de referencia, offset, longitud | uint16 LE + uint64 LE + uint64 LE |
| LITERAL despues del opcode | Longitud, bytes literales | uint64 LE + exactamente N bytes |

Las salidas se concatenan en orden; el total debe ser igual a la longitud final.
Las referencias son externas y ordenadas por la receta. El payload NO incorpora
una tabla de hashes de assets: identidad de payload/referencias/salida viene de
la receta/caller. Cero instrucciones solo describe salida vacia. Los rangos COPY
se validan por resta, sin suma que pueda desbordar. COPY no apunta a la salida.

## Evidencia exacta, no equivalencia de programa

PMMFixLab.exe, SHA-256 8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe.
Go pclntab localiza main.applyDeltaPatch en VA 0x527020..0x528940; su rango tiene
SHA-256 c08a7cc1075a0c778bbae01aa766e41563e399a71e519eae936d88b1b22db917.
Inspeccion con objdump, SIN ejecutar ni cargar ese EXE:

- 0x527100: lectura de 8 bytes de magic; 0x5271e4: llamada a zlib.NewReaderDict.
- 0x5275d0 y 0x5276b4: lecturas binary.Read para longitud y numero de operaciones.
- 0x52792e..0x527938: bifurcaciones para opcode 0 y 1.
- 0x527ab5..0x527b89: COPY usa campo de 16 bits y dos campos de 64 bits.
- 0x527970 y 0x527a90: LITERAL lee longitud y bytes completos.
- 0x527680: comparacion de longitud contra 0x80000000; 0x527764: contador contra
  0x989680. No se adopta ese techo de 2 GiB/10 millones como perfil por defecto.

Los anchos/sentido LE quedan contrastados por los 137 payloads: un segundo lector
Python, independiente del Go, consume exactamente los cuerpos y obtiene las mismas
operaciones, longitudes e indices. El digest de registros canonicos de ambos es
35cf1b8d2ca57b3063c577d2372ed3d2b0d93db820297f5e15728fadc191b4fe.
Esto NO valida la transformacion de assets ausentes ni todos los casos del original.

Corpus: 5 recetas, 260 referencias a 137 payloads unicos; 4.425 instrucciones
(2.547 COPY y 1.878 LITERAL). Maximos observados: 390.781 bytes por parche,
1.441.794 descomprimidos, 4.509.003 de salida declarada y 480 instrucciones.
No se guardan literales ni assets como fixtures nuevos: solo metadatos y hashes.

## Politicas propias de la reconstruccion

Se exige consumir zlib hasta EOF para comprobar su checksum. Close por si solo
no basta. bytes.Reader ofrece ReadByte, evitando que el lector comprimido oculte
un sufijo; los bytes comprimidos restantes y los bytes de cuerpo tras la ultima
instruccion se rechazan. El codigo usa compress/zlib de la biblioteca estandar.

El perfil de limites es mas conservador que los techos observados en el binario.
Los errores, API en memoria, hash obligatorio a tres niveles y cancelacion son
decisiones de ingenieria nuevas. No se afirma reproducir los errores o la
aceptacion de entradas malformadas del original. No generar parches productivos
ni cambiar pins/recetas para acomodar el codec.

## Referencias

- PMM/Documentation/FIX_LAB_RECIPE_ENGINE.md (base fijada).
- PMM/CKL/FixLab/Cases/FIXLAB-CASE-001-GAWR-GURA/recipe-*-v2.json y payload-v2.
- https://pkg.go.dev/compress/zlib y https://pkg.go.dev/io (documentacion consultada).
- Go1.23.2 local: src/compress/zlib/reader.go, NewReader, Read y Close;
  src/encoding/binary/binary.go, lectura little-endian.

Las paginas de versiones antiguas no se pudieron abrir; los detalles del
Go1.23.2 utilizado se contrastaron directamente con sus fuentes locales.
