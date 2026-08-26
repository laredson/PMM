# AI_HANDOFF, AIIO y Knowledge Library

Este es el flujo avanzado para conflictos que PMM todavía no puede demostrar de forma automática.

## Analyze y AIIO están separados

Analyze solo analiza el grafo de mods actual. Para cada elemento marcado como Unsupported guarda un caso exacto (`case.json`, hashes/tamaños de entrada y evidencia del análisis). Las familias cooked de Unreal conservan el contrato de solución manual; los archivos compartidos plain/no-Unreal se incluyen como evidencia para investigación sin fingir que PMM pueda importar automáticamente un reemplazo para esos formatos. Analyze **no** crea ZIP de AI handoff y **no** copia PAK fuente.

Cuando el usuario pulsa **CREAR ENTREGA PARA IA**, AIIO crea **un único** `AI_HANDOFF_<bundleId>.zip` con todos los casos Unsupported del análisis actual. Después de un Analyze normal con elementos Unsupported, PMM también puede preguntar si se quiere crear el paquete en ese momento.

El ZIP contiene:

- `cases/<caseId>/` — evidencia exacta de PMM para cada caso Unsupported;
- `sources/Vanilla/<ruta lógica del juego>` — el archivo/familia exacto de Vanilla cuando existe;
- `sources/<nombre del mod>/<ruta lógica del juego>` — solo el archivo/familia exacto extraído de cada mod implicado;
- `merge-plan.json`, `source-map.json` y el contexto/documentación de Knowledge de PMM.

Los PAK fuente completos nunca se incluyen.

## Política de tamaño

AIIO usa 512 MiB como tamaño objetivo del ZIP y 5 GiB como presupuesto normal máximo del paquete sin comprimir. La estimación previa considera un ratio de compresión conservador y AIIO vuelve a aplicar el límite mientras extrae. Si el paquete previsto supera el presupuesto normal, PMM pregunta si el usuario quiere crearlo de todas formas.

El staging temporal y los ZIP parciales se eliminan mediante `finally`. Al iniciar PMM también se limpian staging abandonados de Analyze/AIIO, archivos parciales y los antiguos handoff por caso creados por versiones previas.

## Soluciones devueltas

Un handoff de entrada puede contener muchos casos, pero PMM sigue validando las soluciones cooked por `caseId`. Por cada caso Unreal resuelto se devuelve un ZIP `PMM_MANUAL_SOLUTION_V1`. Así una IA/modder puede resolver todos, algunos o ninguno sin perder la validación exacta por hashes.

La semántica final se confirma dentro de Palworld. Los casos que funcionen pueden contribuirse como handoff + solución devuelta + resultado runtime para convertir la experiencia en reglas estructurales generales.
