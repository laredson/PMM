# CoreR1 - planificador y requisitos, 04A-5A

Biblioteca Go aislada, RECONSTRUCTION. No contiene main ni executor de FixLab.
No lee archivos del juego, no ejecuta las primitivas, no construye PAK y no instala.
La receta y los inventarios son bytes JSON aportados por el caller con SHA-256
esperado externo. Ver CONTRACT.md antes de interpretar un resultado.

## API

`PlanCore(ctx, Request) (*Plan, error)` valida receta e inventarios DECLARADOS,
selecciona uno de los donantes permitidos, resuelve destinos, minimos, soporte,
exclusiones, colisiones y referencias de nombres. Devuelve un plan determinista.
Un requisito necesario para planificar ausente/ambiguo devuelve nil y error con
Code/Subject/Detail. No produce un prefijo de plan aparentemente correcto.

PLAN_VALID significa coherencia del plan sobre metadatos. NO significa que el
archivo PAK, su extraccion o los assets existan o coincidan con sus hashes.
InputBytesVerified, TransformReady, BuildReady, Validated e Installed son false.
No hay flag del caller para convertir una declaracion en permiso de ejecucion.
Requisitos faltantes permanecen en Requirements. Todo consumidor debe recalcular
el plan y establecer sus propias verificaciones, no confiar en booleans de JSON.

## Alcance

- Receta PMM_FIXLAB_RECIPE_V1, version 1, mount ../../../, seed 0.
- Inventarios PMM_R1_INVENTORY_V1; rutas PAK ASCII relativas seguras para Windows.
- Seleccion por coincidencia TOTAL y sensible a mayusculas del targetRegex Go.
- Minimo obligatorio; knownBaselineCount es referencia, no maximo ni prueba.
- Familias .uasset + .uexp; .ubulk/.uptnl se enumeran pero siguen UNSUPPORTED
  para relocalizacion. Referencias para hashes de nombres requieren solo header.
- Soporte por raiz con frontera '/' y archivos explicitos; exclusiones con
  precedencia, salvo conflicto con archivo explicito, que se rechaza.
- Cada raiz debe seleccionar datos; familias parciales, ejecutables de soporte,
  outputs prohibidos y colisiones archivo/directorio/case se rechazan.
- El build actual declarado debe coincidir EXACTAMENTE con targetBuild. Otras
  versiones requieren revision: no se infiere compatibilidad hacia delante.

Claims opcionales de procedencia de schema se vinculan a receta, donante y
proveedor actual; se guardan como DECLARED_UNVERIFIED, nunca como aprobacion.
No se cargan los bytes del schema/layout ni del review record referenciados.
El schema real de SkeletalMesh y el executor completo siguen pendientes.

## Reproduccion

Go1.23.2 instalado; GOPROXY=off, GOSUMDB=off, GOTOOLCHAIN=local, GOWORK=off.
Desde esta carpeta:

```text
go test -count=1 -v ./...
go test -race -count=1 ./...
python -B -m unittest -v test_tools
```

28 tests Go por defecto; dos tests opt-in quedan SKIP, no PASS, sin variables.
PMM_R1_PLAN_OUTPUT=<directorio NUEVO externo> activa cuatro planes artificiales.
PMM_R1_PACKAGE=<ruta absoluta PMM> activa lectura SOLO de la receta pinneada,
con inventarios completamente simulados, nunca assets ni el PAK donante.
PMM_R1_TOOL_FIXTURES=<salida anterior> activa cinco pruebas negativas del oracle.

`python -B verify_fixtures.py <salida>` compara planes con un escenario manual
independiente; no es otro planificador general ni verificador de archivos reales.
`python -B build.py --out <directorio NUEVO externo>` genera CoreR1-tests.exe,
receta/hashes/source. No lo ejecuta ni construye PMMFixLab.exe. No instalarlo.

En 04A-5A: 30 tests Go y 10 Python con opt-ins, race Linux y vet Windows correctos.
Dos builds TEST iguales. Fuzz acotado: 173539 entradas. Ninguna prueba Windows,
Unreal/Palworld, reparacion real ni antivirus. Logs completos en ZIP de evidencia;
resumen y hashes en evidence/. Proximo bloque: captura/procedencia de inputs,
schemas y precondiciones, no un executor de relleno.
