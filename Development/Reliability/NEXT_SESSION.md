# Retomar exactamente aqui - despues de 02A

Rama: `v1.5.0.1-PMM-reliability`.
**01B y 02A cerradas en sus alcances. No repetirlas ni pedir el ZIP otra vez.**
Paquete: 1.5.0.1, build `PMM-v1.5.0.1-reliability-s01b`, sin cambios en 02A.
Fuente candidata: `Development/Reliability/NativeCandidates/Host/`.

Leer AGENTS.md -> este archivo -> STATUS.md -> SESSION02A_FINDINGS.md ->
NativeCandidates/Host/README.md y evidence/build-report.json.
Development/Source/SOURCE_STATUS.md sigue vigente para los binarios distribuidos.

## Siguiente tanda 02B - SOLO comparar Host y fijar aceptacion

Entradas guardadas:

- Original PMM/PMM.exe: 010c4f656dbe68f0bcf667610accf6cc4e248872120c6acd299f0fca7c209c2d.
- Candidato S02A: 62fc4b234ea145c6e3dadcc51366c0ebbca109f7b5a11dcb17deda32e927257f.
- Go 1.23.2. Receta build.py, .go completos, diff y hashes en la carpeta candidata.
- Cinco tests Go de estados y nueve tests Python; NO se ejecuto el candidato.
- Dos builds en directorios distintos fueron identicos entre si. Original y
  candidato NO son identicos. No hay paridad de secciones ni de Windows afirmada.

## Trabajo acotado

1. Verificar HEAD y los hashes de entrada. Regenerar candidato en carpeta nueva
   fuera del checkout con build.py; no copiarlo sobre PMM/PMM.exe.
2. Preparar comparacion reproducible del original y candidato: PE/buildinfo,
   contratos CLI, rutas, variables de sesion, codigos de salida, errores,
   monitor de estado, cierre y handoff. Distinguir strings de funciones de
   codigo real, y evidencia de build de evidencia de ejecucion.
3. Revisar especialmente origen del HWND, carreras ready/close, estados parciales,
   fallo de UI/splash y cierre temprano. Si hay una correccion imprescindible,
   hacerla solo en la candidata, explicar el delta y regenerar sus hashes.
   No convertir esta tanda en la migracion de PowerShell/dependencias.
4. Guardar un informe de comparacion y una lista concreta de pruebas Windows:
   arranque/cierre, splash, foco, tarea visible, errores, diagnosticos y retorno.
   Las pruebas reales de escritorio pertenecen a 05 o a una tanda autorizada;
   no fingirlas ni instalar el candidato sin aceptacion.
5. Comprobar PMM/ intacto, actualizar STATUS/NEXT_SESSION y evidencia. Un commit
   silencioso [skip ci], sin Actions, PR, tags, release ni cambios en idiomas.

Salida: comparacion y gate Windows explicitados, no un certificado de equivalencia.
Despues corresponde 03 (Runtime), conservando el Host original hasta su aceptacion.
La fuente candidata es RECONSTRUCTION, nunca ORIGINAL_RECOVERED sin evidencia nueva.

## Comandos

Desde la raiz del repositorio:

```text
python -B Development/Reliability/NativeCandidates/Host/build.py --out ../PMM-Host-S02B
python Development/Reliability/verify_identity.py --expected-build PMM-v1.5.0.1-reliability-s01b
```

La primera ruta de salida debe ser nueva. La segunda orden necesita checkout Git;
para una distribucion extraida usar --package PMM y el mismo expected-build.

## Prompt de continuacion

"Completa solo 02B en v1.5.0.1-PMM-reliability. Lee AGENTS.md y NEXT_SESSION.md.
Parte del Host S02A guardado, prepara comparacion reproducible y gate Windows.
No sustituyas binarios, no modifiques Runtime/idiomas y no repitas 01B.
Guarda codigo e informes de cualquier correccion, registra limites y la entrada
exacta de 03. Un commit [skip ci], sin Actions, PR, tags ni release."
