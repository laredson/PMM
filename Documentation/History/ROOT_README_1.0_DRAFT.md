# Palworld Manager Merger 1.0 — README draft

**Palworld PAK compatibility merger + lightweight mod management.**

Palworld Manager Merger analyzes the exact cooked assets shared by your active Palworld PAK mods and tries to preserve every compatible change instead of relying on whole-file load-order winners.

## Start here

1. Run `Start.cmd`.
2. Detect/select Palworld.
3. Import your PAKs or **Import ~mods**.
4. Select active source mods.
5. **Analyze**.
6. Resolve only real `DECISION REQUIRED` values.
7. **BUILD MERGE**.
8. **DEPLOY**.

For full instructions, open `Documentation/README.md`.

## Why PMM is different

PMM treats conflicts at the smallest identity its current adapters can prove. Independent same-file changes remain merged after a local decision.

The current runtime regression stack includes a single Double/Triple/Quad MultiJump decision while retaining Fly in the same `BP_PlayerBase`, Fly + Wing in `BP_WingGlider`, and established Stack/ZeroWeight, FoodNeverSpoils, Early Aquatic, BreedFarm and PlayerStatus compatibility families.

## Safe uncertainty

If PMM cannot prove a composition, it reports **Unsupported** and blocks Build. It does not silently pick an entire mod winner.

Unsupported cases can be exported as a self-contained `AI_HANDOFF_<caseId>.zip` for a capable AI or human modder. Any returned manual solution remains experimental until tested in Palworld.

## AI-assisted development

Created by **laredson with extensive GPT assistance**. 50+ hours of hands-on development, investigation and runtime testing went into the current release line.

AI helped build and debug PMM, but AI is not trusted as a binary safety oracle. Structural validation and in-game testing remain central to the project.

## Source and extension

PMM's own PowerShell/WPF/C# source and Knowledge JSON/Markdown are included. See `Documentation/DEVELOPERS_AND_AI.md` for architecture and contribution guidance.

The final 1.0 package must include a project `LICENSE` defining formal fork/redistribution rights and the required third-party notices.

## Current target

- Windows
- Steam Palworld
- English / Español UI

Game Pass, Nexus integration, Workshop, PalSchema and UE4SS awareness are roadmap items rather than current 1.0 promises.

## Important

Modding can break after game/mod updates. PMM pins manifests/hashes and prefers conservative failure, but keep backups and test important setups in-game.

Palworld Manager Merger is an unofficial community tool and is not affiliated with or endorsed by Pocketpair, Epic Games, Nexus Mods, Microsoft or OpenAI.
