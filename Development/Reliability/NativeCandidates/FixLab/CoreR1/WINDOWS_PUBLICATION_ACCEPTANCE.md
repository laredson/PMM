# Aceptacion Windows del guardado candidato - NO EJECUTADA AQUI

El ejecutable CoreR1-tests.exe es un harness Go autocontenido de pruebas con datos
artificiales. NO es PMMFixLab.exe y no se copia dentro de PMM/ ni del juego.
El script RUN_WINDOWS_PUBLICATION_TESTS.cmd selecciona solo tests de esta etapa,
limpia sus variables opt-in en el proceso hijo y guarda el log junto al kit.
Las fixtures se crean en TEMP, incluyendo carpetas falsas repo/game/workspace.
No hace falta instalar Go/.NET, proporcionar el juego ni desactivar antivirus.

Ejecutar desde una carpeta independiente de prueba sin privilegios elevados.
No desbloquear ni excluir el archivo del antivirus para forzar que pase: registrar
un bloqueo real como incidencia. Conservar SHA-256 del harness y el log.

| Caso | Criterio | Estado |
| --- | --- | --- |
| W6B-01 | DACL protegida usuario/SYSTEM y ABI de FileRenameInfo correctas | NOT_RUN |
| W6B-02 | Crear/flush/releer/rename bundle de cuatro archivos y reabrirlo | NOT_RUN |
| W6B-03 | Denegar rutas protegidas, enlaces/reparse y padre remoto | NOT_RUN |
| W6B-04 | Destino existente vacio/ocupado no reemplazado | NOT_RUN |
| W6B-05 | Cancelacion antes del commit elimina solo archivos propios | NOT_RUN |
| W6B-06 | Error de sync/cierre despues del commit conserva recibo committed | NOT_RUN |
| W6B-07 | Cierre abrupto antes/despues del rename no confunde staging con final | NOT_RUN |
| W6B-08 | Disco realmente lleno/permisos/antivirus concurrente: sin falso exito | NOT_RUN |
| W6B-09 | Rutas de usuario con espacios/Unicode y cuatro publicaciones concurrentes | NOT_RUN |
| W6B-10 | Resultados reales de Win10/Win11/NTFS documentados sin elevar a engine parity | NOT_RUN |

El harness cubre algunos casos con inyecciones/control de intercalaciones; no
sustituye pruebas de disco lleno real, fallos electricos, ACL efectivas o todos
los comportamientos NTFS. DirectorySyncCompleted=false en Windows es intencional.
La matriz no queda PASS por compilar el harness. Guardar cualquier error observado.
