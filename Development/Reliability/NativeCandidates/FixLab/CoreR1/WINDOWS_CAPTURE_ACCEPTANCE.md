# Aceptacion pendiente: captura CoreR1, Windows x64

TODOS los casos estan NOT_RUN. Cross-compilar no ejecuta estas operaciones.
Usar exclusivamente directorios/copias sinteticas al comenzar, cuenta sin elevar,
y protecciones del SO activas. No apuntar todavia al juego ni ejecutar reparaciones.
Registrar version Windows/FS y SHA de los fuentes/harness. No instalar el harness.

| ID | Caso | Resultado exigido | Estado |
| --- | --- | --- | --- |
| C01 | NTFS local, paths con espacios/Unicode y esquema sintetico | Captura exacta, buffers independientes, report sin readiness | NOT_RUN |
| C02 | ABI y aperturas relativas NtCreateFile | Estructuras AMD64 y lectura/cierre sin errores; test dedicado incluido | NOT_RUN |
| C03 | Reparse point/junction en raiz, padre o archivo | Rechazo sin seguir el enlace; no fallback | NOT_RUN |
| C04 | Hard links, ADS, dispositivos, UNC y drive remoto | Rechazo conforme al perfil; no lectura del destino remoto | NOT_RUN |
| C05 | Escritor ya abierto y writer/rename despues de abrir leaf | Sharing violation/rechazo; test dedicado de write/delete incluido | NOT_RUN |
| C06 | Renombrar raiz/padre durante captura | Datos solo del handle anclado o error; nunca redireccion por la ruta | NOT_RUN |
| C07 | Corrupcion/truncacion/crecimiento/bytes inesperados | nil,error; nunca reporte parcial de exito | NOT_RUN |
| C08 | Cancelacion y errores de I/O/cierre | Error propagado; no prometer interrupcion de driver bloqueado | NOT_RUN |
| C09 | Capturas repetidas y archivos cambiados despues | Mismos bytes -> mismo informe; snapshots previos no mutan | NOT_RUN |
| C10 | Claim correcto con review/layout de otro donante o provider | Rechazo, no autoaprobacion ni pins nuevos | NOT_RUN |

TestCaptureWindowsABISizes y TestCaptureWindowsLeafDeniesWriteAndDelete estan
incluidos en el harness compilado. No se contaron como PASS en Linux. Los demas
casos necesitan aceptacion Windows explicita. Falta igualmente validacion de
pertenencia al PAK, schemas reales y executor antes de promocionar un motor.
