# 04A - procedencia FixLab: investigacion entregada, fuente bloqueada

Fecha: 2026-09-18. Rama: v1.5.0.1-PMM-reliability.
Entrada remota: 7d8b5265c881746aefd8ffae9ba592bb0e6ce589.
Arbol remoto: a4fdedd955fb73e19ed8b8cad00ee19fa35a1ce6.

**04A PARCIAL. No hay fuente recuperada ni candidata de motor compilable.**
Se entregan auditor de procedencia, lector binario, mapa de fuentes y evidencia.
No marcar 04A/REL-01 como terminados ni continuar con 04B sin una candidata.

## Procedencia del material inspeccionado

El ZIP 03B disponible proporciona bytes del paquete, .github y snapshot; los
subarboles calculados como Git coinciden con los de la base remota actual:
PMM 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa;
.github cb881ba48502f8dcea8cead16f47f275069d5945;
Development/Source 0cfad865e6fd63663b29f5ec92b76618bc6e4a02.
Esto NO presenta el ZIP viejo como copia de todos los fuentes candidatos actuales.
Las escrituras de 04A se aplican solo a archivos nuevos FixLab y documentos de
estado sobre el arbol remoto; Host/Runtime/UIBridge/Supervision se conservan.

PMMFixLab.exe: 2790912 bytes, SHA-256
8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe,
blob e2a7c8269215f5f02db1408429ddee58fc445b52. Coincide con los dos pins del
manifiesto y el checkpoint nativo. La version 0.2.0-variant-recipes se toma del
manifiesto, no de ejecutar --version. Se leyo Go buildinfo/pclntab, no el proceso.

## Busqueda y bloqueo reproducible

La referencia Development/Source/FixLabEngine/ no existe en el snapshot actual.
Tampoco figura en la carpeta Source de la rama historica 1.3.0-fix-lab
(f04a17643f0e12525c4865ebb273083a4fc1859a); su historial filtrado por esa ruta
devuelve cero commits. La rama info inspeccionada contiene notas, no ese motor.
La busqueda de codigo/commits y tres busquedas de File Library no recuperaron
los seis .go. El resumen de agosto encontrado describe un executor aun pendiente;
no se adopto como fuente de 0.2.0. No se afirma haber agotado todos los backups.

Los ocho fragmentos .github/bootstrap/fixlab-r2-overlay.patch.xz.b64.part00..07
son byte-identicos a los de la rama historica Fix Lab. En reliability llegaron
con la importacion 50201fdb5ab867a10fe09bf0b8f18fb0182440f8. El primer fragmento
historico esta en d05df96d674231bdd35ff4fe42d128ba3d7a56e5.

Longitudes: 19998, 20000, 19999, 20000, 19999, 20000, 19999, 15488.
Total: 155483 caracteres, resto 3 modulo 4. Base64 estricto devuelve
`Incorrect padding`. El fallo existe en los bytes guardados, no solo en una
salida truncada del conector. Agregar un '=' en una COPIA produce hash
26909847792d8c4e0112bfcdec16f428fd10a9b2cc77a6b965e3e328648ba763,
distinto del pin historico 39622b989a4b4a1056f3efc6b527828c3325359c90e5f7ffe399776c6536fcbb,
y LZMA rechaza con `Corrupt input data`. No basta con agregar padding.
Un sondeo exploratorio de insercion tampoco obtuvo una copia verificada; los
fragmentos parciales se descartaron como fuente. No se editaron los originales,
no se repinneo el overlay, no se ejecuto bootstrap ni se aplico ningun parche.

## Entrega ejecutable auxiliar, no motor nuevo

NativeCandidates/FixLab/audit_source.py verifica el original y pins de recetas,
lee los ocho fragmentos y emite JSON en stdout. Falla cerrado con codigo 2 cuando
la recuperacion esta BLOCKED. No escribe archivos ni ejecuta procesos.

inspect_binary.py compila/ejecuta SOLO tools/fixlab_meta.go en salida nueva externa,
con toolchain local Go1.23.2 y red deshabilitada. Reutiliza el lector de Runtime
como fuente de referencia y agrega archivo/linea con PCToLine; no modifica Runtime.
El mapa identifica 63 funciones main.* (wrappers incluidos) en main.go, delta.go,
pakv11.go, recipe.go, uasset.go y variant.go. NO recupera sus cuerpos.

SOURCE_CONTRACT.md registra los argumentos que usa el llamador, el informe que
espera, las seis unidades y el camino de recuperacion/reconstruccion por etapas.
No se ha construido un main.go placeholder ni un motor que anuncie funciones que
no implementa. Las herramientas de inspeccion no son una candidata PMMFixLab.

## Comprobaciones realizadas

- 15 tests Python del auditor: pins, Base64 canonico, padding, partes, duplicados,
  limites, lectura acotada, rutas, symlinks, mismatch del original y payloads.
- 5 tests Go del lector: digest, ausencia, entradas malformadas, directorio y limite.
- Dos inspecciones independientes del original producen el mismo JSON completo.
- 5 recetas V2, 260 referencias a 137 payloads unicos: hashes correctos por lectura.
- Paquete: 629 archivos / 628 checksums / cero discrepancias; s01b intacto.
- No PMM, FixLab, PowerShell, .NET, repak, juego, reparaciones o antivirus ejecutados.
  No compilacion de motor, firma, instalacion, muestras, Actions, PR, tag o release.

No confundir los tests de herramientas con validacion de las reparaciones Gura.
Los datos de proveedores/current Game Reference no se leyeron ni se redistribuyen.

## Continuacion exacta

04A permanece abierta por entrada fuente invalida/ausente, no por una limitacion
de numero de tokens. No repetir busquedas identicas sin una pista nueva ni pedir
el mismo ZIP del paquete: ya se verifico y no contiene esa fuente.
Una copia fuente autentica permitiria recuperar y compilar; sin ella, el siguiente
bloque es reconstruccion declarada del codec PMMDLT1 con fixtures, no del motor
entero en una sola tanda. Ver NEXT_SESSION y SOURCE_CONTRACT.
El resto de candidatas queda como estaba; todos los gates Windows siguen NOT_RUN.
