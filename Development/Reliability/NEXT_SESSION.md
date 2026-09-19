# Retomar despues de 04A-6A - ejecutor acotado publicado

Rama exclusiva v1.5.0.1-PMM-reliability. El commit que incorpora
SESSION04A6A_PUBLICATION.json publica el delta conservado sobre
587b4ed0c026ff97bb043fad84bd16d09803b02c. No repetir la implementacion ni
volver a aplicar el ZIP original sobre esta rama.

Leer AGENTS -> este archivo -> STATUS -> SESSION04A6A_PUBLICATION.json ->
SESSION04A6A_FINDINGS/CHECKS -> CoreR1/EXECUTION_CONTRACT.md.
FINDINGS/CHECKS conservan el cierre local HISTORICO y su bloqueo de publicacion
anterior. El registro PUBLICATION resuelve solo ese bloqueo; no transforma
pruebas Linux en aceptacion Windows ni declara terminado el motor completo.
Esta intervencion es de publicacion, no una nueva tanda de desarrollo o tests.

## Que esta implementado y no repetir

ExecuteBounded usa objetos privados de CaptureCore/VerifyMembership. Plan y review
pinneados cubren todas las familias y outputs. Revalida snapshots/dossiers sin
abrir rutas. Reutiliza UAsset.Read/RewriteNames/PatchPostProcess para nombres del
mismo ancho y postProcess escalar; copia soporte; verifica hashes externos de
cada output; construye/verifica PAKV11 en memoria. Nada se instala o guarda.

MemoryResult expone copias. Fallo tardio/cancelacion devuelve nil. No nueva CLI,
no lectura de PAK reales, no schema inferido de 120. Review/identidad no prueba
semantica/autenticidad; los flags globales ready/validated/installed siguen false.
Regiones opacas no se mueven; arrays/bulk/serializers complejos quedan UNSUPPORTED.
PAKV11 y UAsset NO cambiaron. CoreR1/go.mod depende localmente de ambos; build.py
requiere los tres directorios y testdata/execution-vectors.json para embed.

104 Test Go Linux con aserciones, 44 Python, race completo, tres escenarios/30
outputs comparados en Python y PAK readback. Dos builds TEST Windows iguales:
fa92349e026e36cd85804c87f9dde045e5c4f217429dd1be5aae2dd510642b9f.
No contar semillas fuzz como tests ni pruebas Windows compiladas como PASS.
PMM/ sigue s01b, 629 archivos/628 hashes, arbol
09df5c45aee3390c6b8ea235c8afa4e149a9f1fa. No reemplazar originales.

## Siguiente: 04A-6B - guardado transaccional aislado

Definir la publicacion de MemoryResult ya verificado a un directorio candidato
NUEVO, separado del juego, PMM/ y Workspace productivo. Manifiesto de identidad,
escritura temporal y verificacion antes de exponer completion. Cancelacion, disco
lleno/errores, paths/symlinks/reparse y rollback en fixtures propios. No aceptar
un JSON externo como MemoryResult verificado ni leer entradas sin repinnearlas.

No modificar juego/donantes, no extraer a carpetas ajenas ni agregar deploy/CLI
completo. Es una capa de publicacion de candidatos, no aprobacion de juego.
Schema/review reales, serializers complejos, relocalizacion general, V2/CLI y
aceptacion Windows permanecen gates distintos. Actualizar estado con evidencias.

Reproduccion 6A: CoreR1/README.md explica opt-ins/fixtures y builder offline. Los
oracles Python y fuentes estan conservados. No volver al overlay historico roto.
