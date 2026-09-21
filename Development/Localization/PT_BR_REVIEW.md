# Brazilian Portuguese localization review

Branch: `v1.5.0.0-PMM-translated`
Recovery baseline: `38bd5a934488ac11a6200d3142b889ca86a82f57`
Date: 2026-09-17

## Current checkpoint

The GitHub connection is being retried after an unavailable write action. The last confirmed Portuguese catalog is an empty template. Do not mark the language complete or enable it until the canonical catalog has been saved and checked against `en.json`.

## Terminology

- Mod / mods: mod / mods.
- Analyze: Analisar.
- Build: Gerar (a local output file, not installation in the game).
- Deploy: Instalar no jogo (not public release publication).
- Undeploy: Remover do jogo (keep the saved library output).
- Merge: mesclagem.
- Compatibility patch: patch de compatibilidade.
- Game Reference: referencia do jogo (use Portuguese accents in the catalog).
- Handoff: pacote de contexto when referring to a ZIP for another AI.
- Save: Salvar for the action; save for a game save file.
- Preserve product names, file extensions, paths, identifiers and format placeholders exactly.

## Acceptance boundaries

Check all canonical keys, duplicate keys, format placeholders, file-dialog filters, escapes and untranslated English sentences. Catalog completeness does not establish Windows visual acceptance.

Arabic keeps its RTL layout. LTR exceptions must be presentation-only for technical data, not blanket changes to Arabic sentences or stored values. Preserve restart-based language changes. No release, main merge, tag or GitHub Actions run is requested.
