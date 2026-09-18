# PAK v11 - perfil reconstruido de 04A-3

No es especificacion completa de Unreal Pak ni fuente original recuperada.
Las cantidades son little-endian. El escritor usa seed 0; el lector verifica
cualquier seed uint64. Mount virtual fijo `../../../` NO es destino de extraccion.
La biblioteca no escribe al sistema de archivos.

## Perfil admitido

Version 11, datos sin comprimir/sin cifrar, GUID cero, tabla de compresores cero,
entradas compactas de 32 bits con flags 0xe0000000. Rutas relativas ASCII,
con separador `/`, componentes Windows seguros y FStrings positivos terminados
en NUL. Incluye indices PHI y FDI completos, todos los directorios padre y raiz `/`.
No admite firmas, delete records, entradas no codificadas, UTF-16 FString,
compresion, cifrado, offsets/longitudes de 64 bits en registros compactos, indices
podados, padding/gaps ni otras versiones. Rechazar un PAK valido fuera de este
perfil es intencional: no es un lector universal ni un reemplazo de repak.

La seleccion ASCII evita afirmar compatibilidad no verificada de normalizacion
Unicode entre sistemas. No limita los idiomas de la UI ni cambia catalogos.

## Bytes serializados

1. Por archivo: header de 53 bytes y datos. Header = u64(0), u64(tamano),
   u64(tamano), u32(compresion=0), SHA-1(datos)[20], u8(flags=0), u32(blocksize=0).
   El offset cero es LOCAL al header; el offset absoluto esta en el registro.
2. Indice primario: FString(mount), u32(file count), u64(seed); dos descriptores
   {u32(presente=1),u64(offset),u64(tamano),SHA-1[20]} para PHI y FDI; u32(tamano
   array compacto), array, u32(numero de registros no codificados=0).
   Cada registro compacto es {u32(0xe0000000),u32(offset header),u32(tamano datos)}.
3. PHI: u32(count), pares {u64(hash ruta),i32(offset EN array compacto)},
   u32(directorios podados=0). Hash = FNV-1a sobre ruta lowercase UTF-16LE sin NUL,
   inicializado a 0xcbf29ce484222325 + seed, multiplicador 0x100000001b3, modulo 2^64.
4. FDI: u32(numero de directorios); por directorio FString(dir),u32(file count),
   pares {FString(nombre sin ruta),i32(offset EN array compacto)}. Los padres sin
   archivos tambien aparecen. `dir/` lleva slash final; raiz se representa `/`.
5. Footer de 221 bytes: GUID[16]=0,u8(encrypted=0),u32(0x5a6f12e1),u32(11),
   u64(offset PRIMARIO),u64(tamano PRIMARIO),SHA-1(PRIMARIO)[20],5*32 ceros.
   Footer.IndexSize NO incluye PHI ni FDI: cada uno tiene su propio descriptor/hash.

El escritor ordena archivos, directorios y nombres por bytes ASCII. PHI sigue
orden de ruta, no orden numerico de hash. El lector no exige ese orden, pero
exige cada registro exactamente una vez, coincidencia PHI/FDI, cobertura completa,
headers/tamanos concordantes y ninguna superposicion ni region sin referenciar.

## Validacion e independencia

SHA-1 es requisito del formato para corrupcion, NO firma ni garantia de origen.
Read devuelve nil/error ante fallo. Verify vuelve a leer y compara nombres Y
bytes con inputs esperados proporcionados por el caller; reporta SHA-256 ademas.
Su campo ByteExact no prueba ejecucion en el juego ni autenticidad de esos inputs.

verify_reference.py es una segunda implementacion, sin importar codigo Go ni
utilizar Build/Read como oraculo. El vector congelado golden.json tiene 649 bytes:
data=165, primary=150, PHI=44, FDI=69, footer=221. make_golden.py calcula ese vector
con offsets explicitos sin ejecutar el escritor Go. Es sintetico propio, no salida
de UnrealPak. 17 paquetes Go/240 archivos se releen en Python y se comparan con
bytes sinteticos suministrados aparte, no solo con checksums incrustados.
Dos implementaciones coincidentes aun pueden compartir una interpretacion erronea
del formato. La aceptacion independiente de Unreal/Palworld sigue NO realizada.

## Fuentes de contraste (consultadas 2026-09-18)

- Epic FPakInfo: version 11/Fnv64BugFix, magic, indices y SHA-1:
  https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/PakFile/FPakInfo
  https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/PakFile/FPakInfo_2
  https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/PakFile/FPakInfo_1
- Implementacion primaria repak, fijada al commit 355b5f62f51959c7cc6dd5a51708646ef483065d:
  https://github.com/trumank/repak/blob/355b5f62f51959c7cc6dd5a51708646ef483065d/repak/src/entry.rs
  https://github.com/trumank/repak/blob/355b5f62f51959c7cc6dd5a51708646ef483065d/repak/src/pak.rs
  https://github.com/trumank/repak/blob/355b5f62f51959c7cc6dd5a51708646ef483065d/repak/src/footer.rs
- Inspeccion ESTATICA del PMMFixLab original fijado: entryDataHeader, encodedEntry,
  fnv64Path, generatePHI/FDI, writePakV11 y validatePakV11. Rangos/hashes y limites
  de inferencia en evidence/static-origin.json; disassembly completo en evidencia.

Codigo nuevo escrito para este componente, sin vendorizacion ni ejecucion de repak.
No se reclasifica como fuente original recuperada por coincidir constantes/layout.
