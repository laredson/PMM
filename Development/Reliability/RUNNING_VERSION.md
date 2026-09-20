# Que programa se esta ejecutando realmente

Estado al cierre de 04A-6B. Rama: v1.5.0.1-PMM-reliability.

| Lo que abres | Lo que contiene |
| --- | --- |
| PMM/PMM.exe | Host ORIGINAL del paquete; las candidatas no estan incorporadas |
| PMM/Engine/PMMRuntime.exe | Runtime ORIGINAL |
| PMM/Engine/PMMFixLab.exe | FixLab ORIGINAL |
| Development/Reliability/NativeCandidates/ | Fuentes y pruebas de los reemplazos en desarrollo |
| CoreR1-tests.exe del kit separado | Pruebas con archivos artificiales; NO aplicacion PMM |

VERSION.txt dice 1.5.0.1 y BUILD_ID.txt dice PMM-v1.5.0.1-reliability-s01b desde
01B. Esa tanda alineo CUATRO metadatos; los otros 625 archivos del paquete no
cambiaron. No se reconstruyen ejecutables automaticamente al hacer Pull.

Por tanto, probar ahora PMM.exe confirma comportamiento del paquete conservado,
NO valida nuevos procesos, escritor de candidatos, ni reduccion de falsos positivos.
El avance si esta en esta misma rama: esta separado dentro de Development/.
Los ZIP de evidencia no son instaladores. No copiar harnesses sobre PMM.exe.

Las futuras entregas que SI cambien el programa lanzable deben indicar explicitamente
el nuevo BUILD_ID, hashes de EXE, ubicacion de lanzamiento y pruebas requeridas.
Hasta entonces: estado de programa instalado = SIN CAMBIOS FUNCIONALES DESDE 01B.
No publicar este desarrollo como una version antivirus/Nexus terminada.

6B escribe el RESULTADO candidato de una reparacion (un PAK/informe/manifiesto),
no una nueva version de la aplicacion. Concluir esa pieza no cierra el motor real,
los gates Windows, firma, dependencias ni el preflight sobre la distribucion final.
