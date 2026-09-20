# I01 - primera aplicacion de prueba con Host y Runtime nuevos

Autorizacion: el propietario pide incorporar ahora las piezas existentes y probar
el programa antes de seguir desarrollando. I01 es una prueba EXPERIMENTAL, no una
aceptacion Windows, release publica, ni promesa antivirus. No cambia la rama de idiomas.

## Que cambia de verdad en el paquete integrado

PMM/PMM.exe = Host C2B reconstruido.
PMM/Engine/PMMRuntime.exe = Runtime C2B reconstruido.
Ambos incluyen Supervision y UIBridge. NO son ejecutables de tests.
PMMFixLab.exe sigue siendo el original; CoreR1 y las otras reconstrucciones FixLab
no estan completas ni se conectan para reemplazar funciones que ya funcionaban.
El resto de scripts, DLL, interfaz, idiomas y recetas queda byte-identico.

Build identificable: PMM-v1.5.0.1-reliability-i01. Version de producto 1.5.0.1.
Solo cinco archivos de PMM cambian: los dos EXE, BUILD_ID.txt,
RELEASE_MANIFEST.json y SHA256SUMS.txt. VERSION.txt no necesita cambiar.
Los internos nativos conservan la version 1.2.1; distinguir I01 por BUILD_ID y hashes.

## Entrega remota y local: estado actual

La entrega inicial SESSION_I01 publico solo receta/evidencia porque su conector no
podia transferir los EXE. SESSION_I01B resolvio ese bloqueo desde un checkout local:
reconstruyo los hashes C2B e integro los cinco archivos juntos. El arbol PMM de la
rama es ahora `12e01ba3a24a2c0ce5e74d681b4931307c845a56`.

La entrega descargable PMM_v1.5.0.1_I01_TEST_APPLICATION.zip contiene la aplicacion
REAL ensamblada, con dependencias, lista para abrir PMM/PMM.exe. El ZIP
PMM_I01_APPLY_TO_CHECKOUT.zip contiene los cinco archivos para aplicarlos a una
copia local limpia de esta rama, con PMM cerrado y backup anterior conservado.
Hacer Pull de SESSION_I01B SI instala I01. Verificar BUILD_ID y mantener los cinco
archivos coordinados; actualizar solo el manifiesto sin sus EXE rompe la integridad.

## Reproducir sin red ni alterar el checkout

Go 1.23.2 ya instalado. Desde la base 96287f9 cuyo paquete PMM aun es s01b:

```text
python -B Development/Reliability/NativeCandidates/Host/build.py --out <HOST_OUT_NUEVO_EXTERNO>
python -B Development/Reliability/NativeCandidates/Runtime/build.py --out <RUNTIME_OUT_NUEVO_EXTERNO>
```

Copiar PMMHost-candidate.exe y PMMRuntime-candidate.exe a un directorio de binarios.
Luego, desde la raiz del checkout con Python 3.9+:

```text
python -B Development/Reliability/Integration/I01/assemble.py --binaries <BINARIOS> --out <SALIDA_NUEVA_EXTERNA>
```

El ensamblador exige el arbol exacto de s01b y ambos hashes C2B; no cambia pins para
aceptar resultados diferentes. Copia solo el paquete, omitiendo Workspace y Oodle
local. Regenera identidad/checksums sobre los bytes finales. No ejecuta PMM, no
hace red ni modifica Git. No es un instalador transaccional sobre datos existentes.
Se usa en un workspace de mantenimiento controlado, no como sandbox frente a un
atacante concurrente. Salida incompleta sin ASSEMBLY_COMPLETE.txt no se debe usar.

## Primera prueba Windows del usuario

Cerrar toda instancia PMM. Empezar preferiblemente en una carpeta nueva con el
ZIP completo; no copiar Workspace productivo inicialmente. Ejecutar PMM/PMM.exe,
no CoreR1-tests.exe ni los EXE desde Engine. Comprobar splash, ventana, idioma,
pestanas, cierre limpio y segundo inicio. Medir aproximadamente segundos hasta
ventana visible y hasta poder usarla. No afirmar optimizacion de tiempo sin medir.
No ejecutar deploy/reparaciones sobre datos importantes en esta primera prueba.
Si se necesita probar flujos con estado previo, usar una COPIA de Workspace.
Ante aviso antivirus/politica detener la prueba y conservar el mensaje; no agregar
exclusiones ni ejecutar como administrador para forzarla.

Volver a la version anterior: cerrar I01 y abrir la carpeta anterior que no se ha
modificado. Si se aplico el overlay en un checkout, restaurar los CINCO archivos
juntos desde el backup/s01b con PMM cerrado, sin borrar Workspace ni un stash.

Aportar resultado de inicio/cierre, duracion y, ante fallo, PMMHost.log y el log
principal (revisando datos personales antes de compartir). Solo entonces decidir
si se mantiene esta integracion y que bloqueo resolver. No continuar a ciegas con
mas modificaciones mientras el primer arranque integrado no se haya probado.
