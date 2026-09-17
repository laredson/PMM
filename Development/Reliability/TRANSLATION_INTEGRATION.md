# Integracion futura de idiomas: 1.5.0.0 -> 1.5.0.1

## Contrato entre las dos ramas

`v1.5.0.0-PMM-translated` sigue desarrollando idiomas sin recibir cambios de estructura, version o fiabilidad de esta linea. `v1.5.0.1-PMM-reliability` conserva su propia historia y recibe los idiomas cuando el propietario indique que estan listos.

Ancestro inicial fijo: `38bd5a934488ac11a6200d3142b889ca86a82f57`. No se recalcula a partir de un nombre de rama que se mueve. Todos los archivos del paquete existentes en ese punto ya estan en ambas lineas.

No hay merge automatico autorizado, ni PR creado, ni workflow de sincronizacion. El mismo repositorio y un ancestro comun permiten revisar las aportaciones nuevas sin copiar carpetas enteras ni reiniciar historia.

## No asumir que traducir solo modifica JSON

Los catalogos viven en `PMM/Resources/Localization/`, pero la carga de idiomas, XAML, controles dinamicos, disposicion RTL y excepciones LTR tambien pueden modificar scripts y UI compartidos. Incluso cambios en archivos distintos pueden interactuar funcionalmente.

| Zona | Regla de integracion |
| --- | --- |
| `PMM/Resources/Localization/` | Incorporar catalogos/registro revisando claves, placeholders, fallback, nativeName y activacion; un catalogo nuevo no implica habilitacion automatica |
| `Development/Localization/` | Conservar herramientas, plan e historial de traducciones, adaptando pruebas al contrato final |
| `PMM/Modules/Shared/Localization*`, `PMM/Resources/UI/MainWindow*`, `PMM/Resources/UI/strings.*` | Revision semantica conjunta; no resolver conflictos con una preferencia global por una rama |
| Otros `PMM/Modules/` | Integrar las partes traducibles sin recuperar invocaciones o comportamiento que fiabilidad haya sustituido |
| `PMM/Resources/Metadata/` | Reconciliar datos de idiomas y capacidades; mantener identidad objetivo 1.5.0.1 y regenerar hashes del resultado final |
| `PMM/Engine/`, `PMM/PMM.exe`, `Development/Source/`, scripts de build y `.github/` | No importar binarios antiguos ni revertir hardening como efecto secundario de una traduccion; toda diferencia requiere revision |
| `Development/AI/`, `Development/Reliability/`, `AGENTS.md`, `RELIABILITY.md` | Conservar contexto de ambos trabajos sin sustituir el estado real de esta linea por un handoff antiguo |

Durante el trabajo paralelo, no renombrar masivamente estas rutas. Si una migracion exige mover funciones o claves, documentar un mapa origen -> destino y transportar la traduccion a la implementacion nueva.

## Herramienta disponible

`plan_translation_integration.py` usa exclusivamente lecturas Git locales y escribe su informe JSON en stdout. No hace fetch, checkout, merge, commits, cambios de archivos, tests ni conexiones externas.

Tras actualizar manualmente las referencias locales, desde una copia de la rama de fiabilidad:

```text
python Development/Reliability/plan_translation_integration.py --translations origin/v1.5.0.0-PMM-translated
```

Tambien acepta el SHA exacto de la entrega de traducciones en lugar de la referencia de rama. El informe registra ambos commits resueltos, ancestros comunes actuales, archivos modificados por cada lado y grupos de revision. Si falta historia o una rama no desciende del punto de partida, falla con un diagnostico; no intenta arreglar el repositorio.

**Limites:** es un inventario acumulado desde la bifurcacion, no una simulacion de conflictos ni una aprobacion del merge. Los renombrados aparecen como baja/alta. Despues de una integracion anterior puede listar cambios ya incorporados; contrastar los ancestros comunes actuales. La ausencia de archivos compartidos no garantiza compatibilidad funcional. Solo se ha comprobado sintaxis Python en esta entrega.

## Procedimiento cuando las traducciones esten listas

1. Obtener autorizacion para la integracion y fijar el commit de traducciones terminado. Actualizar referencias mediante fetch de lectura, sin pull automatico ni cambios en la rama remota de idiomas.
2. Trabajar localmente sobre la rama de fiabilidad, con el arbol de trabajo limpio y un punto de recuperacion. Revisar el inventario y las diferencias reales.
3. Preparar una fusion de tres vias sin commit automatico. Conservar la ascendencia de ambas ramas. No usar copia completa de `PMM/`, reset duro ni una resolucion global ours/theirs.
4. Resolver por contrato las diferencias compartidas. Mantener las mejoras de fiabilidad y adaptar las traducciones a su implementacion actual. Revisar tambien interacciones sin conflicto textual.
5. Reconciliar VERSION, BUILD_ID, RELEASE_MANIFEST y cualquier metadata nueva de localizacion. Regenerar inventarios a partir de los archivos finales; no heredar SHA256SUMS antiguos. La identidad de la candidata integrada sera 1.5.0.1, no 1.5.0.0 ni 1.3.4.1.
6. Probar localmente idiomas habilitados, nombres nativos, persistencia/reinicio, RTL con rutas/IDs LTR, placeholders, errores y todos los flujos afectados de PMM. No ejecutar workflows de GitHub por iniciativa propia.
7. Registrar evidencia y limitaciones en STATUS.md. Con la autorizacion de escritura correspondiente, subir un commit de integracion silencioso con `[skip ci]`. Publicar una release es una decision posterior separada.

## Regla para nuevas cadenas en fiabilidad

Reutilizar claves existentes siempre que su significado se conserve. Para nuevos diagnosticos crear claves estables y una lista de pendientes, sin inventar traducciones ni cambiar la activacion de idiomas. Mantener el contrato actual hasta que las claves nuevas esten incorporadas y validadas; la candidata no se declara totalmente traducida mientras haya faltantes conocidos.
