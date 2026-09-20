# 04A-6D - job V2 y CLI candidato-only

`PMM_R1_CANDIDATE_JOB_V2` es un documento de orquestacion fijado por SHA-256.
Une las APIs ya acotadas en un unico proceso:

`PlanCore -> CaptureCore -> VerifyMembership -> ExecuteBounded -> PublishCandidate`.

No importa informes serializados como objetos privados. CaptureCore,
MembershipEvidence y MemoryResult se reconstruyen en memoria durante esa llamada.
El job referencia documentos JSON por ruta relativa, hash y tamano dentro de un
`documentRoot` absoluto. Las lecturas usan el adaptador anclado existente,
rechazan links/reparse, cambios de identidad, tamanos distintos y hashes distintos.

## Capacidades negativas obligatorias

El job exige exactamente:

- `operation = EXECUTE_AND_PUBLISH_CANDIDATE_ONLY`;
- `candidateOnly = true`;
- `installRequested = false`;
- `deployRequested = false`.

Cualquier otra combinacion produce `JOB_REJECTED` antes de capturar o publicar.
El schema no contiene destino de instalacion, lista de mods activa, orden de
deploy, comandos, argumentos de shell, URL, credenciales ni politica de reparacion.
Campos desconocidos, duplicados o con mayusculas distintas se rechazan.

La publicacion sigue usando un hijo nuevo aleatorio bajo un padre controlado y
conserva todas las prohibiciones de PUBLICATION_CONTRACT.md. Un job no puede
publicar dentro de repositoryRoot, gameRoot o workspaceRoot. No hay retry,
sobrescritura, limpieza recursiva ni promocion de staging.

## CLI

`CoreR1-candidate.exe` es un ejecutable separado del harness y de
`PMMFixLab.exe`. Solo ofrece:

```text
CoreR1-candidate.exe run --job <ruta-absoluta> --job-sha256 <sha256-minuscula> --job-bytes <tamano-exacto>
```

El job se lee por descriptor anclado con maximo 512 KiB. La salida normal es un
solo `PMM_R1_CANDIDATE_JOB_RESULT_V2` JSON. Exit 0 significa candidato publicado;
exit 3 significa rechazo/error con resultado JSON; exit 2 significa CLI invalido.
Interrumpir es cancelacion cooperativa. Tras el commit gana la publicacion.

Estados heredados:

- `JOB_REJECTED`: schema, documentos, captura o membership rechazados;
- `EXECUTION_REJECTED`: ejecucion acotada rechazada;
- `PUBLICATION_REJECTED`: no se cruzo commit;
- `PUBLICATION_REJECTED_WITH_POSSIBLE_RESIDUE`: conservar ResidueName;
- `CANDIDATE_PUBLISHED_NOT_GAME_ACCEPTED`: bundle completo, no instalado;
- `CANDIDATE_PUBLISHED_REQUIRES_ATTENTION`: commit con error posterior.

Un resultado publicado conserva `gameAccepted=false` e `installed=false`.
El caller debe guardar externamente CandidateName y ManifestSHA256 para
InspectCandidate; encontrarlos dentro del propio bundle no autentica su origen.

## Limites pendientes

Este cierre implementa versionado/orquestacion y una frontera CLI, no completa el
motor historico V2. Siguen bloqueados schemas/serializers reales, relocalizacion
variable/bulk, autenticacion de reviewer/build, aceptacion Unreal/Palworld,
instalacion, rollback de mods, UI final, firma y distribucion. Los fixtures son
artificiales. No conectar este CLI al PMM distribuido como reemplazo de FixLab.
