# Estado - I01: primera aplicacion de prueba preparada

Host/Runtime C2B se ensamblaron en un ZIP de APLICACION REAL con build
PMM-v1.5.0.1-reliability-i01. Incluye Supervision/UIBridge. FixLab original conservado.
El propietario ha autorizado esta prueba incremental; Windows aun PENDING_USER.

IMPORTANTE: los EXE compilados no se transfirieron por el conector a GitHub.
Esta rama registra receta, tests y evidencia; PMM/ remoto sigue s01b coherente.
El ZIP completo permite probar ya; el overlay de 5 archivos permite actualizar
la copia local de esta misma rama y subir los binarios con GitHub Desktop.
No hacer afirmaciones de que Pull instala I01 mientras ese paso no haya ocurrido.

I01: 629 archivos/628 hashes; 5 cambian y 624 permanecen byte-identicos.
Tree integrado 12e01ba3a24a2c0ce5e74d681b4931307c845a56.
Tree remoto conservado 09df5c45aee3390c6b8ea235c8afa4e149a9f1fa.
No se cambio logica nativa ni se ejecuto una nueva reescritura: integra C2B existente.
Dos builds/componentes identicos a los hashes conservados. 92 pruebas Go con
aserciones (incluida una lectura de inventario real), 12 Python de empaquetado;
vet Windows correcto. No Windows real, race nuevo, antivirus o velocidad medidos.

04A-6B y anteriores permanecen en Research: no estan conectados a FixLab original.
REL-01, schemas reales, V2/CLI, family/Job Objects, manifests/pins/rutas, repair
06/07, firma y preflight siguen abiertos. No se cancela ni se pierde ese trabajo.

Siguiente accion: feedback I01 y correccion/medicion del arranque real, NO seguir
una nueva tanda de reconstruccion antes de comprobar que la integracion arranca.
NEXT_SESSION.md y RUNNING_VERSION.md precisan como distinguir las entregas.
