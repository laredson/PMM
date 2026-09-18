# Retomar despues de 03B

Rama exclusiva: v1.5.0.1-PMM-reliability.
01B/02A/02B/03A/03B cerradas EN SUS ALCANCES. REL-01 sigue abierto.
Paquete: 1.5.0.1 / PMM-v1.5.0.1-reliability-s01b, 629 archivos intactos.
Leer AGENTS.md -> este archivo -> STATUS.md -> SESSION03B_FINDINGS.md ->
NativeCandidates/Runtime/HOST_RUNTIME_HANDSHAKE.md.
No repetir sesiones cerradas ni pedir de nuevo el ZIP.

## Entradas conservadas

Runtime original: e90341d8449b485cb04af3c00d357bc8c67e87070644ff6bf7d27121a00c422a.
Runtime S03B: 45e017190c379774afd24557084e7fa532bbef58b6ead6869294943bb72ed0be.
Runtime S03A historico: 10effcaf7a5d02836104a5bb2bd90eeb52c755ac78fc4670b5eea11b235b938f.
Host S02B: a5f50c5677608c9875eefb65fe75fd7efb3460808be2f53df7ea3ec6db195d97.
Fuentes/recetas en NativeCandidates/Host y NativeCandidates/Runtime; evidence/s03b
conserva comparacion, build, diff y tests. Las tablas PE/Go completas estan en el
ZIP de evidencia y se regeneran con build.py/compare_runtime.py desde los fuentes.
No hay fuente original recuperada ni aceptacion Windows por coincidencia de hashes.

## Siguiente tanda 02C-1 - plazos y supervision, NO IPC todavia

1. Fijar HEAD y preservar PMM/, snapshot e idiomas. Trabajar SOLO en candidatas
   Host/Runtime y herramientas/evidencia de supervision.
2. Resolver H02B-05/R03A-01: seleccionar y comprobar el Windows PowerShell
   compatible con la UI actual (PS5.1), sin prioridad silenciosa a pwsh.
   Sondeo con plazo, salida acotada y errores distinguibles; no bloqueo infinito
   antes de la reserva nativa. No cambiar politicas ni Bypass mediante otro bypass.
3. Resolver H02B-06/R03A-05 en sus mecanismos de espera/salida: drenar sin Scanner
   que abandone una linea larga, comunicar errores, acotar memoria y espera por
   EOF. No confundir matar hijo directo con terminar familia de procesos.
   Preservar stdout/stderr completos en almacenamiento controlado o devolver
   error/incompletitud explicitos; no truncar silenciosamente datos de un merge.
4. Incluir validacion del timeout CLI (R03B-03) y documentar politica de salida
   para helpers/sondeos. No redisenar descargas, reparar dependencias ni ejecutar
   start/ensure como prueba. El manifesto incompleto/R03B-02 sigue un bloqueo
   separado a resolver antes de promocion, no cambiando hashes esperados.
5. Pruebas con stubs locales inocuos y fixtures: salida larga, plazo, hijo que
   retiene pipes, error de escritura y cancelacion. No ejecutar PMM/PowerShell/
   juego real en este entorno ni afirmar gestion de familias Windows probada.
6. Guardar codigo, tests, receta, hashes y estado real. Build candidato separado;
   no tocar binarios distribuidos. Commit [skip ci], sin Actions/PR/tag/release.

Salida: supervision y plazos implementados/probados con limites honestos. Si un
caso Windows necesita adapters, marcarlo BLOCKED hasta su implementacion/prueba;
no considerar una prueba Linux como validacion de ese comportamiento Windows.

Despues 02C-2: canal de instancia UI y handoff, segun HOST_RUNTIME_HANDSHAKE.md.
No autenticar HWND con un JSON, titulo o nonce en disco. Vida/identidad de procesos
conservadas por handles, generation, REGISTER/ACK y rechazo de owner ajeno.
04: FixLab. 05: aceptacion Windows. 06/07: dependencias/reparacion consentida.
Los gates WINDOWS_HOST_ACCEPTANCE.md y WINDOWS_RUNTIME_ACCEPTANCE.md siguen NOT_RUN.

## Comando para reproducir S03B

```text
python -B Development/Reliability/NativeCandidates/Runtime/build.py --out ../PMM-Runtime-S03B
python -B Development/Reliability/verify_identity.py --expected-build PMM-v1.5.0.1-reliability-s01b
```

Salida nueva y externa. Para ZIP sin Git, verificador con --package PMM.
No ejecutar la candidata para comprobar su hash.

## Prompt siguiente

"Completa solo 02C-1 en v1.5.0.1-PMM-reliability. Lee AGENTS/NEXT_SESSION.
Parte de Host S02B y Runtime S03B, implementa plazos/seleccion PS y supervision
con stubs, sin IPC/handoff nuevo ni reforma de descargas. No sustituyas binarios,
no toques traducciones; documenta limites Windows, evidencia y entrada de 02C-2.
Un commit silencioso [skip ci], sin Actions, PR, tags ni release."
