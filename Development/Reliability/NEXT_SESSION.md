# Retomar despues de 04A-2 (codec PMMDLT1)

Rama exclusiva v1.5.0.1-PMM-reliability. 04A-2 CERRADA EN EL COMPONENTE;
04A completa y REL-01 siguen ABIERTAS. No pasar aun a 04B.
Leer AGENTS -> este archivo -> STATUS -> SESSION04A2_FINDINGS/CHECKS ->
NativeCandidates/FixLab/PMMDLT1/README.md y FORMAT.md.

## Lo que ya no se repite

La recuperacion original de FixLab sigue bloqueada (source ausente/overlay
invalido); 04A dejo evidencia. No volver a decodificar el mismo overlay ni
pedir otra copia del ZIP del programa. No hay pista nueva de source en esta tanda.
PMMDLT1 ya tiene fuente reconstruida y tests, no debe rehacerse desde el chat.
Go1.23.2 offline, 22 tests Go (21 sinteticos + corpus), 10 Python, race Linux,
dos fuzz acotados. Harness Windows compilado, no ejecutado; NO es PMMFixLab.

PMM conserva 629 archivos, 628 hashes, 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b.
Subarbol: 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa.
Host/Runtime/UIBridge/Supervision C2B no se modificaron. No usar ZIP antiguos
como fuente de esas candidatas, ni copiar harnesses sobre ejecutables originales.

## Siguiente entrega 04A-3 - SOLO PAK v11 y readback

1. Verificar HEAD y mantener intactos PMM/, recetas/payloads/pins, snapshot,
   idiomas y las otras candidatas. Original FixLab:
   8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe.
2. Partir del mapa de pakv11.go conservado en FixLab/evidence/binary-map.json
   y SOURCE_CONTRACT. Obtener detalles de formato mediante referencias primarias
   y evidencia estatica; no inventar layout por el nombre de una funcion.
3. Implementar solo un escritor/lector de PAK v11 de alcance declarado (p.ej.
   entradas sin cifrar/sin comprimir si ese es el contrato demostrado), con
   limites, rutas Windows seguras, indices y verificacion independiente.
   Fixtures sinteticos propios, no assets ni PAK propietarios. Sin invocar repak
   o PMM original/juego ni reconstruir un mod real en esta tanda.
4. Comprobar bytes y readback de fixtures; los limites del formato soportado
   y la independencia del lector deben ser explicitos. No alterar hashes
   productivos ni llamar 'byteExact' a una comparacion circular sin evidencia.
5. Guardar componente aislado, receta/pruebas/evidencia. Sin integrar PMMDLT1
   con UAsset ni simular CLI completa. Despues UAsset/core R1 y orquestacion V2/CLI;
   una candidata de motor completa habilitara 04B.
6. Actualizar registros y subir un commit [skip ci] autorizado para la tanda,
   sin Actions, PR, tag, release o sustitucion de ejecutables.

## Pruebas existentes

Desde NativeCandidates/FixLab/PMMDLT1/: go test -count=1 ./...
PMM_FIXLAB_PACKAGE=<ruta absoluta a PMM> activa SOLO inspeccion del corpus.
No tener assets donantes impide probar salidas reales, no los fixtures del codec.
Los hashes obligatorios deben venir de recetas confiables; no autoaceptar datos.

Todos los gates Windows anteriores siguen NOT_RUN. Permanecen familias/Job Objects,
manifiestos/pins/rutas R03B-02/04 y reparacion 06/07. Abrir el PMM original no acepta
las nuevas candidatas. No declarar source original recuperada ni cero detecciones AV.
