# Retomar despues de la investigacion 04A

Rama exclusiva v1.5.0.1-PMM-reliability. **04A sigue PARCIAL, no pasar a 04B.**
Leer AGENTS -> este archivo -> STATUS -> SESSION04A_FINDINGS/CHECKS ->
NativeCandidates/FixLab/README.md y SOURCE_CONTRACT.md.

## Base conservada

Paquete 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b, 629 archivos, 628 hashes.
Subarbol PMM: 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa.
Host/Runtime/UIBridge C2B estan integrados en candidatas y quedan intactos.
Host: a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c.
Runtime: b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f.
No reimplementar canal ni restaurar candidatas antiguas de los ZIP.

## Bloqueo FixLab comprobado

Original: PMM/Engine/PMMFixLab.exe, 2790912 bytes, SHA-256
8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe.
Version 0.2.0-variant-recipes segun manifiesto. Go1.23.2, modulo
`github.com/laredson/pmm/fixlabengine`. La carpeta source referida no existe.
Los nombres/lineas de seis .go estan identificados, sus cuerpos NO recuperados.

Overlay .github/bootstrap: los ocho blobs coinciden con la rama historica,
pero Base64 es invalido. Agregar padding no alcanza el pin y XZ falla. No hay
codigo fuente validado que extraer. No lanzar workflows ni aplicar ese overlay,
no modificar su hash esperado y no reutilizar texto parcialmente decodificado.
No repetir esta misma busqueda ni solicitar otra copia del ZIP del paquete.

## Proximo bloque 04A-2 - completar fuente, no comparacion todavia

Primero comprobar HEAD y si existe una pista NUEVA de fuente. Una copia de
main.go, delta.go, pakv11.go, recipe.go, uasset.go, variant.go y go.mod puede
permitir recuperacion. Verificar origen, version, dependencias y hashes antes
de compilar. Los nombres de pclntab no prueban la lista completa ni equivalencia.

Sin una fuente nueva, la ruta es reconstruccion declarada y acotada:
- Empezar SOLO por codec PMMDLT1 y sus limites, lectura de datos y fixtures
  sinteticos; no tocar CKL productivo ni ejecutar el motor original/juego.
- Inferir el formato de especificaciones/datos y evidencia estatica documentada,
  no suponer que COPY/LITERAL y unos nombres equivalen a una implementacion.
- Persistir codigo/tests como componente parcial fuera de PMM; no anunciar
  una candidata completa ni inventar source original. Parar al cerrar ese codec.
- Dejar PAK/readback, UAsset/core y orquestacion CLI para subtandas siguientes;
  solo despues hay una candidata completa que comparar en 04B.

Un commit [skip ci] con la autorizacion de esa intervencion. No cambios en Host,
Runtime, UIBridge, Supervision, snapshot, binarios, recetas productivas o idiomas.
No subir datos de juego/donantes ni ejecutar bootstrap o reparaciones.

## Herramientas ya listas

Desde raiz:
python -B Development/Reliability/NativeCandidates/FixLab/audit_source.py
Devuelve 2 con informe BLOCKED para el overlay actual; no confundirlo con un test fallido del programa.

python -B Development/Reliability/NativeCandidates/FixLab/inspect_binary.py --out ../PMM-FixLab-inspection
Salida nueva/exterior; solo lector de metadatos, no motor FixLab. No se ha
construido un PMMFixLab candidato ni cambiado el original.

Gates Host/Runtime/UIBridge Windows siguen NOT_RUN. R03B-02/04, familias y
06/07 continuan abiertos. El arranque informal del usuario solo corresponde
al paquete original. Source parity no se declara por coincidencias de metadata.
