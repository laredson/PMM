# Handoff completo para nuevo proyecto - PMM development

Este documento resume el contexto que antes vivia repartido entre conversaciones. La evidencia detallada sigue en los archivos de cada sesion; este documento NO sustituye sus contratos tecnicos, sino que indica que existe, que no repetir y como continuar.

## 1. Proyecto y objetivo

PMM es una aplicacion Windows para gestionar/modificar flujos de mods. La linea `v1.5.0.1-PMM-reliability` se creo para mejorar fiabilidad, procedencia, build reproducible, supervision de procesos y distribucion verificable, conservando funcionalidad y traducciones.

No se busca "burlar" antivirus. Se pretende reducir causas legitimas de falsos positivos mediante ingenieria justificable y una cadena fuente -> build -> paquete -> ejecucion auditable.

La rama de traducciones `v1.5.0.0-PMM-translated` sigue independiente. Ancestro comun fijo: `38bd5a934488ac11a6200d3142b889ca86a82f57`.

## 2. Politica Git/GitHub acordada

- Lectura de GitHub libre.
- Cada escritura remota necesita autorizacion del usuario; "siguiente tanda" o una peticion explicita de publicar cuenta como autorizacion para ese bloque.
- Desarrollo: commit/push silencioso con `[skip ci]`.
- No Actions/CI/tests remotos en esta rama salvo peticion expresa.
- No PR, tag, release o cambio de Latest por iniciativa propia.
- Las pruebas funcionales de desarrollo las hace el usuario localmente salvo peticion expresa.
- No sobrescribir una carpeta nueva con una vieja.
- Antes de escribir: fijar HEAD, comprobar que no avanzo y hacer fast-forward sin force.

## 3. Estado remoto actual

SESSION_I01B parte de `e83b191e56c916b4de12c34a9d054f4bd6bbd485` y cierra la
transferencia binaria pendiente del handoff anterior.

El paquete `PMM/` de la rama es I01:
- producto 1.5.0.1;
- BUILD_ID `PMM-v1.5.0.1-reliability-i01`;
- 629 archivos;
- 628 filas en SHA256SUMS;
- 0 mismatches;
- Git tree `12e01ba3a24a2c0ce5e74d681b4931307c845a56`.

Ejecutables de la rama:
- Host C2B `PMM/PMM.exe`: SHA-256 `a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c`.
- Runtime C2B `PMM/Engine/PMMRuntime.exe`: SHA-256 `b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f`.
- FixLab original `PMM/Engine/PMMFixLab.exe`: SHA-256 `8807635af5073c784e003561b72137d011a5b1bfffbfe7b472dd1ae316bc0afe`.

Importante: I01 esta compilado e integrado, pero su ejecucion funcional Windows
sigue pendiente; compilacion y hashes no equivalen a aceptacion.

## 4. Candidatas nativas ya construidas

Directorios autoritativos:
- `Development/Reliability/NativeCandidates/Host/`
- `Development/Reliability/NativeCandidates/Runtime/`
- `Development/Reliability/NativeCandidates/Supervision/`
- `Development/Reliability/NativeCandidates/UIBridge/`
- `Development/Reliability/NativeCandidates/FixLab/`.

Host C2B:
- SHA-256 `a5601742a3fe0ee214bab3ce96835e3bd7cca8d9a94d629dc027d5fcad69b19c`.
- tree de fuentes Host en la preparacion I01: `81414da2ab9c7d37faac5196262228b39732878a`.

Runtime C2B:
- SHA-256 `b338faf9b76df0f44749b673c53aa7abc41b6c29994e7efafb8e1c2210426b1f`.
- tree de fuentes Runtime: `869ddc4afe047b0ca86c94119d3d4d8ca8162437`.

Supervision:
- tree `df63da545d67425ffbf223b6788c88de6f33f6a1`.

UIBridge:
- tree `b3fb9acc38203873ef6b9ccbfbeb28a2aad98341`.

Estos hashes son identidad de artefactos concretos, no aceptacion Windows ni garantia antivirus.

## 5. I01 - primera integracion ejecutable

El propietario pidio integrar ya piezas maduras para poder probar el programa incrementalmente.

`Development/Reliability/Integration/I01/` contiene:
- `README.md`: contrato/uso;
- `assemble.py`: ensamblador puro del paquete;
- `test_assemble.py`;
- `evidence/`: recibos y pruebas.

I01 sustituye SOLO:
1. `PMM/PMM.exe` por Host C2B;
2. `PMM/Engine/PMMRuntime.exe` por Runtime C2B;
3. `PMM/Resources/Metadata/BUILD_ID.txt`;
4. `PMM/Resources/Metadata/RELEASE_MANIFEST.json`;
5. `PMM/Resources/Metadata/SHA256SUMS.txt`.

Todo lo demas permanece byte-identico. FixLab original se conserva.

Identidad I01:
- build `PMM-v1.5.0.1-reliability-i01`;
- tree esperado `12e01ba3a24a2c0ce5e74d681b4931307c845a56`;
- 629 archivos / 628 checksums / 0 mismatch.

Verificaciones ya realizadas durante I01:
- 92 pruebas Go con aserciones, incluida lectura real del inventario del paquete integrado;
- 12 tests Python del ensamblador;
- vet Windows de Host, Runtime, Supervision y UIBridge;
- compilaciones repetidas Host/Runtime identicas a los hashes C2B;
- NO ejecucion real de I01 en Windows;
- NO medicion de velocidad;
- NO escaneo antivirus.

### Transferencia binaria resuelta en SESSION_I01B

El chat que preparo I01 no pudo cargar los dos EXE. SESSION_I01B uso un checkout
local Windows, Go 1.23.2 verificado y Git autenticado para reproducir ambos hashes,
ensamblar el arbol esperado e integrar juntos los cinco archivos. Ya no se necesita
un ZIP anterior para instalar I01 mediante Pull.

## 6. Como reconstruir I01 solo desde Git

Requisitos: checkout limpio de la base compatible s01b, Python 3.9+ y Go 1.23.2. No descargar toolchains desde los builders.

Builders:
`Development/Reliability/NativeCandidates/Host/build.py`
`Development/Reliability/NativeCandidates/Runtime/build.py`

Ambos exigen el Host/Runtime s01b originales y construyen fuera del checkout. Los resultados esperados son los hashes C2B anteriores.

Luego:
`Development/Reliability/Integration/I01/assemble.py`

El ensamblador exige:
- base PMM tree `09df5c45aee3390c6b8ea235c8afa4e149a9f1fa`;
- Host/Runtime C2B exactos;
- salida nueva fuera del repo.

Produce el paquete I01 y regenera manifest/checksums. Nunca relajar pins para aceptar bytes distintos.

Como el checkout actual ya contiene I01, una reconstruccion futura debe obtener la
base s01b mediante un worktree o archivo limpio del commit pinneado. No cambiar los
guards para compilar sobre los EXE I01 ni copiar una carpeta antigua sobre la nueva.

## 7. FixLab - implementacion hasta 04A-6C, NO integrada

El ejecutable original sigue en PMM.

Trabajo versionado:
- 04A: procedencia del PMMFixLab original; source exacto no recuperado, overlay historico corrupto.
- 04A-2: codec PMMDLT1.
- 04A-3: PAKV11 acotado.
- 04A-4: lector UAsset fijado.
- 04A-4B: `RewriteNames`, solo transformaciones seguras.
- 04A-4C: `PatchPostProcess` escalar con schema/review; no inferir desde offset 120.
- 04A-5A: `PlanCore`.
- 04A-5B: `CaptureCore` + dossiers.
- 04A-5C: `VerifyMembership` contra PAKs fijados.
- 04A-6A: `ExecuteBounded` en memoria; nombres mismo ancho + postProcess escalar + PAK.
- 04A-6B: `PublishCandidate`/guardado transaccional aislado.

Estado 6B:
- 130 tests Go normales PASS;
- 52 Python PASS;
- race enfocado en 26 tests nuevos PASS;
- intentos de race completo interrumpidos por limite de herramienta, NO contarlos como PASS;
- Windows compilado/vet, cuatro pruebas Windows-only NO ejecutadas;
- todos los fixtures artificiales.

04A-6C, autorizada mientras el propietario prueba I01, corrige el adapter Windows
(padre, sharing, rename anclado y sellado de hojas) y agrega
ExecuteAndPublishCandidate con estados de rechazo/residuo/commit/error.
Win10 19045 NTFS sin elevar: 141 Test Go + 4 targets Fuzz con seeds PASS,
50 Python PASS / 2 SKIP, EXE independiente 40 PASS, builds repetidos identicos.
Win11, disco lleno real, AV y crash fisico siguen pendientes; no race nuevo.
Ver SESSION04A6C_FINDINGS/CHECKS y CoreR1/INTEGRATION_CONTRACT.md.
Siguiente: matriz pendiente y contrato de orquestacion V2/CLI candidato-only.
Aun faltan schemas/serializers reales, relocalizacion variable/bulk, V2/CLI y
motor FixLab completo antes de reemplazar `PMMFixLab.exe`.

## 8. Host/Runtime - gates pendientes

Aunque I01 permite una prueba incremental, no declarar Host/Runtime totalmente aceptados todavia.

Pendientes conocidos:
- aceptacion Windows real;
- familia de procesos / Job Objects y algunos contratos de supervision;
- manifests/pins/rutas pendientes del plan de fiabilidad;
- flujos de reparacion/dependencias;
- medir y optimizar arranque;
- verificar compatibilidad completa con UI y workflows reales.

El usuario ha pedido especificamente optimizar el inicio si es posible. Primero medir:
- tiempo hasta ventana visible;
- tiempo hasta UI utilizable;
- segundo arranque;
- Host -> Runtime -> UI;
- tareas de integridad/localizacion/dependencias que puedan aplazarse sin perder seguridad.

No eliminar verificaciones a ciegas para acelerar.

## 9. Traducciones

No bloquear toda la integracion nativa esperando a terminar idiomas.

La rama `v1.5.0.0-PMM-translated` continua independiente. Mas adelante integrar cambios hacia reliability mediante revision de tres vias y el contrato de `TRANSLATION_INTEGRATION.md`.

Nunca:
- copiar toda una carpeta PMM antigua sobre la nueva;
- recuperar EXE antiguos por accidente;
- resolver conflictos con ours/theirs global;
- perder claves/placeholders/fallback/nativeName/RTL.

Las nuevas cadenas de reliability deben registrarse para traducirlas antes de candidata final.

## 10. Roadmap restante, nivel alto

1. Obtener la prueba Windows del usuario para I01 ya integrado.
2. Corregir cualquier regresion de I01 y medir arranque.
3. Completar matriz 6C fuera de Win10 NTFS y delimitar V2/CLI candidato-only.
4. Completar las capacidades FixLab reales pendientes y V2/CLI.
5. Integrar un PMMFixLab reconstruido cuando tenga paridad suficiente; prueba incremental.
6. Cerrar Host/Runtime restantes y optimizar arranque.
7. Cerrar repair/dependencies, manifests/pins/rutas y packaging reproducible.
8. Integrar idiomas de forma controlada.
9. Windows end-to-end, firma si el propietario la provisiona y preflight final.
10. Solo despues valorar upload/release/Nexus. No se garantiza check verde.

Es normal que algunos hitos se dividan en A/B.

## 11. Que NO repetir

- No volver a buscar el source/overlay historico de FixLab sin una pista nueva.
- No reprogramar PMMDLT1/PAKV11/UAsset desde cero.
- No tratar `expectedSerializedOffsets: [120]` como permiso de escritura ciega.
- No elevar `TransformReady/BuildReady/Validated/Installed` por tener hashes.
- No afirmar que fixtures sinteticos prueban compatibilidad Unreal/Palworld.
- No contar tests compilados como ejecutados.
- No llamar al PMM s01b "programa modificado" solo porque VERSION diga 1.5.0.1.
- No pedir ZIPs antiguos antes de revisar Git.

## 12. Donde esta la historia completa

Leer `Development/Reliability/HISTORY_INDEX.md`. Cada etapa conserva su `SESSION...FINDINGS.md` y, cuando existe, su `SESSION...CHECKS.json`. Esa evidencia es historica e inmutable; un archivo posterior puede resolver un bloqueo de publicacion sin reescribir el resultado original.

## 13. Entorno recomendado para el nuevo proyecto

Ideal:
- ChatGPT Work o Codex con acceso a un checkout local;
- Git + autenticacion al repo;
- GitHub Desktop puede coexistir para que el usuario vea/pullee;
- Windows disponible para pruebas funcionales;
- Python 3.9+;
- Go 1.23.2 exacto para builds pinneados.

Si se trabaja desde Linux para compilar Windows, mantener `GOTOOLCHAIN=local`, `GOPROXY=off`, `GOSUMDB=off`, `GOWORK=off`, `CGO_ENABLED=0` donde los builders lo indiquen.

Primera accion del nuevo agente: leer `START_HERE_NEW_PROJECT.md`, no preguntar "que hicimos antes".
