# Retomar despues de 04A-3 (PAK v11)

Rama exclusiva v1.5.0.1-PMM-reliability. **04A-3 cerrada como componente aislado.**
04A completa y REL-01 siguen abiertas. No pasar todavia a comparacion 04B.
Leer AGENTS -> este archivo -> STATUS -> SESSION04A3_FINDINGS/CHECKS ->
NativeCandidates/FixLab/PAKV11/README.md y FORMAT.md.

## Conservado, no repetir

PMMDLT1 ya esta reconstruido, testeado y separado. PAKV11 tiene Build/Read/Verify,
lector Python independiente y golden manual. No volver a programarlos desde el chat.
No repetir la busqueda del overlay invalido ni pedir el ZIP del programa otra vez.
No se ha recuperado el source original. No existen aun core UAsset/V2/CLI completos.

PAK perfil: v11, mount ../../../, ASCII, registros compactos 32-bit, PHI y FDI
completos, sin compresion/cifrado. 20 tests Go/13 Python, 17 fixtures/240 archivos
releidos en Python, race Linux y dos fuzz acotados. Windows harness compilado,
NO ejecutado: 6563b0a5e888e6709025dff239464e7f7e00fa37764808db1a6fa724ca74f21f.
No es PMMFixLab.exe; no copiarlo sobre binarios distribuidos.

Paquete intacto: 629 archivos, 628 checksums, 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b.
PMM tree: 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa.
Host/Runtime/UIBridge/Supervision C2B siguen como estaban. No usar viejos ZIP como
autoridad de esas candidatas; aplicar solo rutas de la intervencion al HEAD remoto.

## Siguiente tanda 04A-4 - SOLO UAsset: lectura y estructura

1. Verificar HEAD y leer FixLab/SOURCE_CONTRACT y evidence/binary-map.json de 04A.
   Original PMMFixLab.exe: 8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe.
2. Determinar el subconjunto UAsset que requieren las recetas core R1 mediante
   contratos de CKL, documentacion primaria y metadata/disassembly estatica.
   No deducir un layout solo por los nombres de readHeader/readNames/readExports.
3. Implementar una lectura acotada y explicitamente limitada con offsets/rangos/
   nombres/imports/exports y fixtures sinteticos. Version no soportada = error,
   nunca adivinar offsets ni saltar validacion para aceptar un asset.
4. No aplicar recetas reales, ejecutar juego/original, importar datos propietarios,
   integrar PMMDLT1/PAK con un main ficticio ni alterar CKL productivo.
5. Conservar source, tests, receta/hashes y limites como componente parcial.
   Las transformaciones/serializacion/core R1 pueden requerir subtanda 04A-4B;
   si hace falta dividir, fijar alcance antes de implementar, sin llamar terminado
   al motor completo. Despues orquestacion V2/CLI; solo entonces 04B.
6. Guardar estado y siguiente accion exacta; commit [skip ci] autorizado para esta
   intervencion, sin Actions/PR/tag/release ni sustitucion de ejecutables.

Los gates reales Windows/Unreal/Palworld siguen NOT_RUN. Siguen pendientes familias/
Job Objects, manifiestos/pins/rutas R03B-02/04 y reparacion 06/07. La prueba informal
de abrir PMM original no valida estos componentes nuevos ni elimina falsos positivos.
