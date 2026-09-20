# I01B - reconstruccion Windows e integracion Git del paquete ejecutable

Entrada: `e83b191e56c916b4de12c34a9d054f4bd6bbd485`, con `PMM/` rastreado aun en
s01b. El usuario autorizo continuar el handoff, compilar localmente y publicar los
binarios directamente en `v1.5.0.1-PMM-reliability`.

## Resultado

Se reconstruyeron Host y Runtime C2B desde las fuentes y recetas versionadas, sin
cambiar pins. Los hashes obtenidos coinciden exactamente con I01:

- Host: `a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c`.
- Runtime: `b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f`.

El ensamblador I01 produjo el arbol PMM esperado
`12e01ba3a24a2c0ce5e74d681b4931307c845a56`. Se integraron juntos exactamente
cinco archivos del paquete: los dos EXE, BUILD_ID, RELEASE_MANIFEST y
SHA256SUMS. PMMFixLab conserva el hash original
`8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe`.

## Entorno y verificaciones

- Python 3.10.6.
- Go 1.23.2 Windows/amd64 portatil, descargado desde `go.dev` fuera del repo.
- SHA-256 del ZIP oficial Go verificado antes de extraer:
  `bc28fe3002cd65cec65d0e4f6000584dacb8c71bfaff8801dfb532855ca42513`.
- Builders Host y Runtime ejecutados offline con sus guards originales.
- Suite Python del ensamblador: 11 PASS y 1 SKIP; el caso symlink se omitio porque
  el entorno Windows no permitio crear el enlace. Los otros 11 casos pasaron.
- Primer ensamblado contra el checkout de trabajo: rechazo esperado porque el
  estado local no rastreado `PMM/.codex/` cambia el arbol. No se borro ni incluyo.
- Ensamblado final contra una base limpia creada con `git archive HEAD PMM`.
- Inventario final: 629 archivos, 628 filas, 0 mismatches.
- Workflows inspeccionados: los eventos `push` existentes no incluyen esta rama.
  El commit de desarrollo conserva `[skip ci]` y no se ejecuto ningun workflow.

## Limites

Los ejecutables se compilaron en Windows, pero NO se ejecutaron. No hay aun prueba
de splash, UI, cierre, segundo inicio, rendimiento, flujos reales o antivirus.
I01 sigue siendo experimental y no es release, tag, PR ni aceptacion funcional.
FixLab reconstruido continua aislado; el EXE distribuido sigue siendo el original.

Siguiente gate: el propietario debe hacer Pull con GitHub Desktop y probar I01 en
una carpeta segura, registrando ventana visible, UI utilizable, cierre, segundo
arranque, tiempos y logs ante fallo. No acumular otra integracion grande antes de
revisar ese resultado.
