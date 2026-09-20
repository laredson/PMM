# I01 - integracion ejecutable de prueba, entrega local real

Base remota: 96287f98f59b7387a00b29cec7c9316800bde098.
El usuario autoriza incorporar las piezas existentes a una aplicacion para probar
antes de proseguir. Eso autoriza esta integracion experimental, NO la aprobacion
Windows/antivirus ni la sustitucion del motor FixLab incompleto.

## Resultado concreto

Se ensamblaron Host y Runtime C2B como PMM/PMM.exe y PMM/Engine/PMMRuntime.exe
reales, junto al paquete conservado. Incluyen Supervision/UIBridge, sin modificar
su codigo. Se mantiene PMMFixLab.exe original. Tambien permanecen los 624 archivos
no afectados del paquete, incluidos UI, traducciones, scripts, DLL y recetas.
Build nuevo PMM-v1.5.0.1-reliability-i01, producto 1.5.0.1, 629 archivos/628 hashes.
Cambian exactamente DOS binarios y TRES metadatos. El manifiesto identifica la
reconstruccion experimental y no reutiliza hashes de fuentes historicas como
identidad de la reconstruccion. Las versiones internas de componentes se conservan.

## Estado de transferencia, importante

El ZIP de prueba SI contiene esos dos EXE nuevos. No es un kit de tests.
La conexion GitHub permite escrituras de texto/blob mediante contenido inline,
pero no ofrece una accion de subida por ruta local montada para estos EXE grandes.
No hay gh/credenciales Git configuradas ni resolucion de codeload desde el contenedor.
Se consulto el plugin disponible sin encontrar otro transporte instalado adecuado.
No se usan Actions, datos codificados en fuentes ni cargadores autoextraibles para
sortear esa limitacion. No se han transferido los EXE al repositorio remoto.

La rama conserva la receta reproducible, tests y evidencia. PMM/ REMOTO sigue en
s01b, coherente con sus binarios y hashes. El overlay descargable de CINCO archivos
permite actualizar la copia local de esa misma rama y publicarlos con GitHub Desktop.
No afirmar que hacer Pull basta para ejecutar I01. No publicar metadatos nuevos en
PMM remoto mientras los EXE correspondientes no esten alli.

## Verificaciones de esta intervencion

PMM/.github/Development/Source del ZIP anterior se recalcularon como arboles Git;
coinciden con los IDs conservados. Los fuentes de compilacion C2B provienen del ZIP
con checksum, y sus nuevas compilaciones reproducen los DOS hashes C2B publicados
en IntegrationEvidence/s02c2b/build-summary.json, leido de HEAD. No se afirma que el
checkout parcial sea toda la rama actual. No se reescriben otras candidatas.

Dos builds offline Go1.23.2 por componente fueron identicos a C2B y entre si.
91 pruebas Go con aserciones de modelos/helpers pasaron; la prueba opcional del
inventario real se ejecuto ademas contra el paquete I01 y paso: 92 en total.
12 tests Python nuevos del ensamblador pasaron. Cuatro modulos pasan vet Windows.
No se repitio race ni fuzz en esta intervencion. No originales o candidatos Windows
se ejecutaron; las pruebas de logica/procesos sinteticos ocurrieron en Linux.
La verificacion de checksum del paquete final cubre todos los bytes, no es AV.

## Lo que no esta terminado

I01 es apta para intentar la prueba del usuario, no una version estable aceptada.
El funcionamiento en Windows, UI real, foco, cancelacion, compatibilidad completa,
velocidad y AV siguen sin comprobarse aqui. Las rutas heredadas de argumentos
PowerShell y reparacion automatica siguen presentes: no atribuirles una mejora AV.
La reconstruccion FixLab, sus schemas reales y fases 04A/06/07 restantes NO se
promueven ni se instalan. No se acopla ese trabajo incompleto a las reparaciones.

No se implementa optimizacion adicional del inicio sin medir primero este conjunto.
La siguiente intervencion debe leer el resultado del usuario de I01; no seguir
acumulando piezas ni repetir 6B. Si se publica el overlay por Desktop, fijar ese
nuevo HEAD y verificar que PMM tree sea 12e01ba3a24a2c0ce5e74d681b4931307c845a56.
Si no se publico, seguir distinguiendo paquete de prueba local y PMM remoto.
