# Retomar despues de 02B

Rama: v1.5.0.1-PMM-reliability. 01B/02A/02B cerradas EN SUS ALCANCES.
Paquete intacto: 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b, 629 archivos.
Leer AGENTS.md -> este archivo -> STATUS.md -> SESSION02B_FINDINGS.md.
No repetir 01B/02A/02B ni pedir otra vez el ZIP.

## Siguiente tanda 03A - SOLO fuente candidata de Runtime

Entrada: HEAD de esta rama y PMM/Engine/PMMRuntime.exe, SHA-256
`e90341d8449b485cb04af3c00d357bc8c67e87070644ff6bf7d27121a00c422a`.
Snapshot: Development/Source/Runtime/, runtimeVersion=1.2.1.
La advertencia SOURCE_STATUS.md sigue vigente. No afirmar que fuentes/funciones
mencionadas por una charla anterior equivalen a codigo recuperado.

1. Verificar HEAD/hashes, leer runtime-contract.json, rutas, main.go, nativeui.go,
   process*.go y las notas de procedencia. No abrir trabajo de traducciones.
2. Aislar el candidato en NativeCandidates/Runtime/. Recuperar original solo con
   evidencia; de otro modo etiquetar RECONSTRUCTION. Conservar fuentes completos,
   receta offline Go1.23.2 y hashes. Nunca compilar sobre Engine/PMMRuntime.exe.
3. Revisar start, UI dispatch, seleccion de PowerShell/CLM y propagacion de sesion,
   cwd, cierre y exit codes. Registrar como riesgos las reparaciones de red;
   no redisenarlas ni ejecutarlas en esta tanda.
4. Delimitar como se identifica la UI descendiente del Runtime: informacion
   necesaria para H02B-04 (origen HWND). No editar Host en paralelo en 03A.
5. Compilar candidato separado si es posible, pruebas de modelos/fixtures y
   comparacion estatica basica; no ejecutar Windows ni declarar equivalencia.
6. Guardar fuentes, evidencia, limites y siguiente paso 03B. Verificar PMM/ y
   snapshot intactos. Un commit [skip ci] con autorizacion de esta intervencion;
   sin Actions, PR, tag, release o modificacion de idiomas.

## Evidencia Host ya conservada

Candidata S02B: a5f50c5677608c9875eefb65fe75fd7efb3460808be2f53df7ea3ec6db195d97.
Original: 010c4f656dbe68f0bcf667610accf6cc4e248872120c6acd299f0fca7c209c2d.
S02A historica: 62fc4b234ea145c6e3dadcc51366c0ebbca109f7b5a11dcb17deda32e927257f.
Codigo, build.py, compare_host.py, tools/hostmeta.go y evidence/s02b en
Development/Reliability/NativeCandidates/Host/.

S02B corrige framing de estados, prioridad cierre/fallo y orden de chequeo de
foreground. No recupera la fuente original ni acredita paridad Windows.
Bloqueos antes de promocion: origen HWND H02B-04, sondeo PS H02B-05, pipes/logs
H02B-06. Resolver en 02C tras 03A/03B. WINDOWS_HOST_ACCEPTANCE.md queda NOT_RUN.
No instalar la candidata ni interpretar la ausencia de cambios en PMM como
una validacion funcional del codigo nuevo.

## Prompt siguiente

"Completa solo 03A en v1.5.0.1-PMM-reliability. Lee AGENTS.md y NEXT_SESSION.md.
Prepara y guarda el Runtime candidato, receta/evidencia offline y mapa del
contrato con la UI. No sustituyas binarios, no modifiques Host ni traducciones.
Registra alcance, pruebas reales, limites y entrada de 03B. Un commit silencioso
[skip ci], sin Actions, PR, tags ni release."
