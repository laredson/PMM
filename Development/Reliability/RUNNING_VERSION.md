# Que version estas ejecutando - integracion I02

| Ubicacion | Programa real |
| --- | --- |
| PMM/ en GitHub desde la entrega I02 | Aplicacion REAL I02 con Host/Runtime C2B nuevos y proyecto Desktop bajo Workspace |
| PMM/ del ZIP PMM_v1.5.0.1_I01_TEST_APPLICATION.zip | Aplicacion REAL con Host/Runtime C2B nuevos |
| PMM/ tras aplicar los cinco archivos de PMM_I01_APPLY_TO_CHECKOUT.zip | Misma aplicacion I01 en tu checkout local |
| CoreR1-tests.exe | Solo pruebas FixLab, NO PMM |
| CoreR1-candidate.exe | CLI candidato-only de laboratorio, NO PMMFixLab ni instalador |
| UAsset-tests.exe | Solo pruebas del parser/transformador aislado, NO PMM |

I02 = PMM-v1.5.0.1-reliability-i02 en Resources/Metadata/BUILD_ID.txt.
I01 = PMM-v1.5.0.1-reliability-i01, base binaria conservada por I02.
s01b = PMM-v1.5.0.1-reliability-s01b. La etiqueta 1.5.0.1 sola no distingue ambos.

I02 conserva los ejecutables I01, mantiene FixLab original y cambia los scripts
Desktop para abrir `Workspace` como proyecto y guardar alli la configuracion
privada. Supervision/UIBridge siguen dentro de los EXE I01. No hace falta
Go/Python para abrirlo.

La limitacion de transferencia de SESSION_I01 quedo resuelta en SESSION_I01B:
los dos EXE y los tres metadatos se reconstruyeron, verificaron e integraron juntos.
Tras hacer Pull de esa entrega, `PMM/PMM.exe` SI corresponde a I01. Verificar
`BUILD_ID.txt` antes de probar para no confundir un checkout antiguo con I01.

Abrir I02 prueba la integracion y el routing de Workspace; no completa Windows, FixLab,
optimizacion de inicio, firma o antivirus. Conservar la carpeta anterior como
retorno seguro. No usar el paquete como release de Nexus ni copiar kits de tests
sobre los EXE. Ver Integration/I01/README.md para instrucciones y hashes.
