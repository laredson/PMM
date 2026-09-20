# Que version estas ejecutando - primera integracion I01

| Ubicacion | Programa real |
| --- | --- |
| PMM/ en GitHub desde la entrega I01B | Aplicacion REAL I01 con Host/Runtime C2B nuevos |
| PMM/ del ZIP PMM_v1.5.0.1_I01_TEST_APPLICATION.zip | Aplicacion REAL con Host/Runtime C2B nuevos |
| PMM/ tras aplicar los cinco archivos de PMM_I01_APPLY_TO_CHECKOUT.zip | Misma aplicacion I01 en tu checkout local |
| CoreR1-tests.exe | Solo pruebas FixLab, NO PMM |

I01 = PMM-v1.5.0.1-reliability-i01 en Resources/Metadata/BUILD_ID.txt.
s01b = PMM-v1.5.0.1-reliability-s01b. La etiqueta 1.5.0.1 sola no distingue ambos.

I01 cambia PMM.exe, PMMRuntime.exe y tres metadatos; mantiene FixLab original,
traducciones, scripts y recetas. Supervision/UIBridge SI quedan dentro de los
EXE nuevos del ZIP de prueba. No hace falta Go/Python para abrirlo.

La limitacion de transferencia de SESSION_I01 quedo resuelta en SESSION_I01B:
los dos EXE y los tres metadatos se reconstruyeron, verificaron e integraron juntos.
Tras hacer Pull de esa entrega, `PMM/PMM.exe` SI corresponde a I01. Verificar
`BUILD_ID.txt` antes de probar para no confundir un checkout antiguo con I01.

Abrir I01 por primera vez prueba la integracion; no completa Windows, FixLab,
optimizacion de inicio, firma o antivirus. Conservar la carpeta anterior como
retorno seguro. No usar el paquete como release de Nexus ni copiar kits de tests
sobre los EXE. Ver Integration/I01/README.md para instrucciones y hashes.
