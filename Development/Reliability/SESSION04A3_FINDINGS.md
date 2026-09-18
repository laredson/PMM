# 04A-3 - PAK v11 y lectura de verificacion

Fecha 2026-09-18. Rama exclusiva v1.5.0.1-PMM-reliability.
Entrada f7c8359a8e0f089311cc01a6133bdfd9790e702a.
Arbol base 3fa17245aa30d4e4777d445686f85e2d846a23d6.

**04A-3 CERRADA en el componente aislado PAKV11.** 04A completa y REL-01 siguen
abiertas. No hay motor FixLab completo ni reemplazo del ejecutable original.
Fuente RECONSTRUCTION; no se ha recuperado el codigo original ausente.

## Procedencia y formato

Se fijaron HEAD/NEXT_SESSION y se conservaron los componentes anteriores. El viejo
ZIP 03B solo aporta PMM/.github/Development/Source, cuyos subarboles se recalcularon
y coinciden con HEAD. Los documentos actuales FixLab proceden de ZIPs 04A/04A-2
verificados. No se presenta esta copia parcial como checkout completo de HEAD.
El commit se construye sobre el arbol remoto y solo incluye rutas de esta tanda.

Contraste primario: Epic FPakInfo y codigo repak entry.rs/pak.rs/footer.rs fijado
al commit 355b5f62f51959c7cc6dd5a51708646ef483065d. Se inspeccionaron ademas once
funciones pakv11.go del binario original 8807635a...316bc0afe mediante objdump,
sin ejecutarlo. Las constantes/estructuras observadas respaldan el perfil de
FORMAT.md; no demuestran equivalencia completa ni recuperan cuerpos originales.
No se ejecuto repak ni UnrealPak ni se reutilizo el overlay roto.

## Implementado

Modulo local NativeCandidates/FixLab/PAKV11, sin dependencias de terceros.
Build construye PAK v11 en memoria con SHA-1 requeridos por formato, registros
compactos, path-hash index (PHI), full directory index (FDI) y footer. Read valida
cada estructura y devuelve contenido copiado; Verify compara nombres y bytes con
expectativas externas y calcula SHA-256 para el informe. Error implica nil/sin
informe de exito; no hay extraccion a disco ni API de instalacion.

Alcance deliberado: ASCII, mount virtual ../../../, seed escritor cero, datos
contiguos sin compresion/cifrado, flags compactos 0xe0000000 y padres FDI completos.
El lector permite otros seeds pero no otros perfiles/versiones/formatos de registro.
No se inventa soporte de UTF-16 FString, delete records, compresion o cifrado.
Rutas peligrosas, duplicadas, colisiones de mayusculas, rangos superpuestos,
referencias a mitad de registro y regiones no referenciadas se rechazan.

Limites API: PAK 256 MiB, archivo 64 MiB, indices 32 MiB, 16384 entradas, ruta
1024 bytes/profundidad 32. Se pueden reducir, no elevar. El crecimiento de indices
se comprueba antes de crear sus buffers. No son limites del original ni garantia
de RSS; los inputs deben ser inmutables durante la llamada. Hash/copia/lectura
comprueban cancelacion por bloques. La futura adquisicion de inputs y publicacion
transaccional quedan separadas; un buffer verificado no es un mod instalado.

## Evidencia de lectura no circular

Se congelo un vector manual de 649 bytes, con offsets calculados en un generador
Python que no usa Go. El escritor Go reproduce todos esos bytes y ambos lectores
lo verifican. No es una muestra producida por UnrealPak ni por PMMFixLab original.

17 paquetes sinteticos (incluido el caso golden), 240 archivos en conjunto, fueron escritos
por Go y releidos por verify_reference.py, implementacion independiente sin
imports del codec Go ni llamadas externas. En TODOS coinciden nombres, longitudes,
SHA-256 y bytes esperados suministrados aparte. Incluye archivo vacio, archivo
binario, raiz, directorios anidados, espacios, orden de entrada y datos de 3 MiB.
No se usan assets del juego ni mod donante. El informe completo esta en el ZIP;
evidence/independent-readback.json conserva resumen, hashes y limite de inferencia.

Esto es evidencia de consistencia de formato y datos. Dos implementaciones pueden
compartir un error de interpretacion; NO se declara compatibilidad con Unreal/
Palworld validada. SHA-1 no prueba autenticidad. Un test cambia bytes y recalcula
su hash interno: Read acepta la estructura, pero Verify RECHAZA frente a la
expectativa original. No reutilizar ByteExact de estas fixtures como gate productivo.

## Pruebas realizadas

20 funciones Test Go con aserciones, incluida exportacion opt-in. 13 tests Python.
Suite race Linux pasada, con los 20 tests activados. FuzzRead: 233063 entradas;
FuzzResealedIndexes: 236260, con checksums sinteticos recalculados para alcanzar
comprobaciones semanticas. Esas entradas no son pruebas Windows ni analisis AV.
Todas las truncaciones del golden se rechazan. Tests adicionales: limites,
FStrings malformados, flags/cifrado/version, offset uint64 extremo, duplicados,
indices incoherentes, contenido corrupto, context nil/cancelacion y output no alias.

Dos builds offline Go1.23.2 Windows/amd64 del harness de TEST son identicos:
SHA-256 6563b0a5e888e6709025dff239464e7f7e00fa37764808db1a6fa724ca74f21f,
5658624 bytes. Go vet Windows correcto. EXE Windows NO ejecutado; no es FixLab.
No PMM/FixLab/PowerShell/.NET/repak/UnrealPak/Palworld/AV ni reparaciones ejecutadas.

## Conservacion y siguiente

PMM: 629 archivos, 628 hashes, cero discrepancias, version 1.5.0.1 / build s01b.
Subarbol 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa. .github y snapshot intactos.
No se modifica PMMDLT1, Host, Runtime, UIBridge, Supervision, traducciones, recetas
ni hashes productivos. Registros anteriores historicos, sin reescritura de evidencia.
Un commit [skip ci]; no Actions, PR, tag, release ni sustitucion de ejecutables.

Siguiente 04A-4: estructura/lectura UAsset con fixtures y limites, aislada. Despues
transformaciones core R1 y orquestacion V2/CLI. No empezar comparacion 04B hasta
contar con motor completo; los gates Windows y bloqueos previos siguen abiertos.
