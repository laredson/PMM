# Retomar: esperar/comprobar primera integracion ejecutable I01

Rama exclusiva v1.5.0.1-PMM-reliability. Base de I01: 96287f9.
Leer AGENTS, RUNNING_VERSION, SESSION_I01_FINDINGS/CHECKS e Integration/I01/README.
El usuario pide probar ya piezas completas. No repetir 04A-6B ni continuar el
motor FixLab a ciegas antes de revisar el primer arranque Host/Runtime integrados.

## Estado que NO se debe confundir

Se entrego un ZIP de APLICACION REAL con Host/Runtime C2B en sus rutas ejecutables.
No es CoreR1-tests.exe. Build de esa aplicacion: PMM-v1.5.0.1-reliability-i01.
FixLab, scripts, UI, idiomas y recetas siguen conservados. Son 5 archivos cambiados.
Los EXE no se subieron por el conector: GitHub conserva receta, pruebas y registros.
PMM/ remoto continua s01b hasta que se importen los 5 archivos con un transporte
binario adecuado. Un overlay permite al usuario copiarlos a su checkout y subirlos
con Desktop. No afirmar que el Pull por si solo actualiza el programa.

## Siguiente accion

1. Leer HEAD actual. Si el usuario importo el overlay, verificar arbol/hash/build:
   I01 PMM tree 12e01ba3a24a2c0ce5e74d681b4931307c845a56.
   Host a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c.
   Runtime b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f.
   FixLab original 8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe.
2. Preguntar/leer SOLO evidencia real de I01: arranque, ventana utilizable, cierre,
   segundo arranque y tiempos. Si hay error, revisar PMMHost.log/sesion/PalModMerger.log.
   Abrir el s01b original no es probar esta integracion; comprobar identidad primero.
3. Corregir fallos reproducibles de integracion en alcance acotado y nueva build.
   Para velocidad medir etapas primero; no suprimir controles de integridad.
4. Mantener FixLab original hasta completar/aceptar su reemplazo. Research 04A6C
   (guardado Windows) y el resto siguen pendientes, pero no bloquean esta prueba de
   Host/Runtime. No marcar gates como PASS por compilar o tener hashes coincidentes.
5. La siguiente entrega funcional debe registrar si modifica PMM/ remoto, solo
   fuentes o un ZIP local. No publicar manifesto/hash de EXE que no se haya subido.

Sin release/tag/PR/Actions. La identidad del producto no es garantia antivirus.
No pedir que se desactiven protecciones. Los builder C2B historicos conservan el
pin s01b: para reconstruirlos usar una copia de esa base, no quitar los guards.
