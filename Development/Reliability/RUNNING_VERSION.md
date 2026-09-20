# Que version estas ejecutando - primera integracion I01

| Ubicacion | Programa real |
| --- | --- |
| PMM/ en GitHub, mientras solo conste esta entrega de receta | s01b, ejecutables originales |
| PMM/ del ZIP PMM_v1.5.0.1_I01_TEST_APPLICATION.zip | Aplicacion REAL con Host/Runtime C2B nuevos |
| PMM/ tras aplicar los cinco archivos de PMM_I01_APPLY_TO_CHECKOUT.zip | Misma aplicacion I01 en tu checkout local |
| CoreR1-tests.exe | Solo pruebas FixLab, NO PMM |

I01 = PMM-v1.5.0.1-reliability-i01 en Resources/Metadata/BUILD_ID.txt.
s01b = PMM-v1.5.0.1-reliability-s01b. La etiqueta 1.5.0.1 sola no distingue ambos.

I01 cambia PMM.exe, PMMRuntime.exe y tres metadatos; mantiene FixLab original,
traducciones, scripts y recetas. Supervision/UIBridge SI quedan dentro de los
EXE nuevos del ZIP de prueba. No hace falta Go/Python para abrirlo.

En esta intervencion no se pudieron transferir los EXE grandes mediante el
conector al repositorio remoto. Por eso hacer Pull SOLO no instala I01. La receta
se ha guardado y se entrega un overlay binario para GitHub Desktop, sin CI.
No se disfraza una subida documental como una actualizacion de PMM remoto.

Abrir I01 por primera vez prueba la integracion; no completa Windows, FixLab,
optimizacion de inicio, firma o antivirus. Conservar la carpeta anterior como
retorno seguro. No usar el paquete como release de Nexus ni copiar kits de tests
sobre los EXE. Ver Integration/I01/README.md para instrucciones y hashes.
