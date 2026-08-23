# AI_HANDOFF y Knowledge Library

Este es el flujo avanzado para conflictos que PMM todavía no puede demostrar de forma automática.

Cuando Analyze marca un asset compartido como Unsupported, PMM puede crear `AI_HANDOFF_<caseId>.zip` con las familias cooked exactas de Vanilla/providers, los source PAK implicados, hashes, informes estructurales, evidencia de Semantic Lab, snapshot de Knowledge, contexto del merge global y el contrato de devolución.

Entrega ese ZIP a una IA capaz o a un modder junto con una descripción breve del comportamiento que quieres conservar. La solución debe volver en un ZIP que cumpla `PMM_MANUAL_SOLUTION_V1`. PMM valida procedencia, caseId, hashes, topología y legibilidad antes de permitir aceptarla como solución **experimental**. La semántica de gameplay se valida finalmente dentro de Palworld.

Un caso que funcione puede contribuirse al proyecto conservando: handoff original + solución devuelta + resultado runtime. La meta es convertir ejemplos reales en reglas estructurales generales, no en excepciones por nombre de mod.

Consulta también `../../Docs/COMMUNITY_KNOWLEDGE_WORKFLOW.md`, `../../Docs/MANUAL_SOLUTION_CONTRACT.md`, `../KNOWLEDGE_LIBRARY.md` y `../DEVELOPERS_AND_AI.md`.
