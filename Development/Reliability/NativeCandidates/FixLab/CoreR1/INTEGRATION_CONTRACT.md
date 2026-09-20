# 04A-6C - interfaz de integracion candidata (sin instalar)

ExecuteAndPublishCandidate(ctx, capture, membership, execution, publication)
compone ExecuteBounded y PublishCandidate, una vez cada uno. Requiere los objetos
privados de CaptureCore/VerifyMembership, el plan/review pinneado y las cuatro
rutas reales de PublicationRequest. No importa informes JSON como evidencia viva.

El resultado siempre es no nulo, incluso con error. El caller DEBE leerlo antes
de decidir que mostrar; descartar el recibo porque err != nil pierde un commit.

| State | Significado | Accion del integrador |
| --- | --- | --- |
| EXECUTION_REJECTED | No se llego a publicar | Mostrar error; no afirmar que exista candidato |
| PUBLICATION_REJECTED | Sin commit; no se ha reportado residuo | Mostrar error/cancelacion, sin reintento automatico |
| PUBLICATION_REJECTED_WITH_POSSIBLE_RESIDUE | Sin commit; cleanup incompleto | Conservar ResidueName; revision explicita, no RemoveAll |
| CANDIDATE_PUBLISHED_NOT_GAME_ACCEPTED | Commit y comprobaciones completados | Guardar recibo y pin externo; ofrecer inspeccion, NO instalacion |
| CANDIDATE_PUBLISHED_REQUIRES_ATTENTION | Commit cruzado pero error posterior | Conservar recibo/carpeta; mostrar ambos; no reintentar ni borrar |

ResidueName es relativo y diagnostico, no una orden de borrado. El integrador
retiene el Parent original y el ManifestSHA256 fuera del bundle. Para verificar
mas tarde, llama InspectCandidate con ese pin; no confia en un pin descubierto
solo dentro del mismo directorio. Los estados serializados sirven para UI/logs,
no autorizan nuevas ejecuciones, reparaciones ni cambios en politicas.

Cancelacion antes del commit de plataforma: rechazo/rollback. Despues: gana el commit.
No hay reintento por colision, fallo de acceso, bloqueo de antivirus o cancelacion.
No se silencian errores de disco. No se amplian limites del perfil acotado.
El contrato no garantiza persistencia del recibo si muere el proceso llamador.

## Orquestacion V2 acotada

`RunCandidateJobV2` y el CLI separado implementan el recorrido candidato-only
descrito en JOB_V2_CONTRACT.md. Reconstruyen captura/membership/resultados privados
en una sola ejecucion y fijan todos los documentos externos. No agregan install,
deploy, retry ni importacion de evidencia serializada.

## Responsabilidades aun fuera de esta API

- Autenticar politica/rutas/review y controlar el padre; no aceptar roots falsos.
- Planificar/capturar/verificar membership antes de la llamada.
- Mensajes UI localizables e integracion UI final: AUN NO IMPLEMENTADOS.
- Semantica completa del motor historico V2: AUN NO IMPLEMENTADA; el job actual
  solo orquesta el perfil CoreR1 acotado candidato-only. 04A-6E agrega recorrido
  de ArrayProperty con innerType escalar fijo, sin mutacion ni relocalizacion.
- Fuente/procedencia de schema real, serializers variables y containers complejos,
  relocalizacion, bulk y aceptacion Unreal/Palworld: AUN NO PROBADAS.
- Instalacion/reparacion del juego, rollback de mods, firma y distribucion:
  NO IMPLEMENTADOS por esta API.

No conectar este adaptador al PMMFixLab.exe original como si fuera motor completo.
La prueba I01 del propietario tiene prioridad sobre otra integracion grande.
