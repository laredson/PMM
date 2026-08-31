# PMM official themes and editor — RC27 continuation handoff

**Project:** Palworld Manager Merger  
**Creator:** `laredson`  
**Implementation baseline:** PMM 1.3.0 RC27  
**Decision date:** 2026-08-30

This document describes the implementation delivered in RC27. It is no longer a plan based on RC23.

## Implemented ownership model

Color schemes follow the same ownership architecture as sounds:

- official schemes are immutable, hash-pinned release resources in `Resources\Themes`;
- user schemes live only in `Workspace\Themes`;
- Settings renders official and user schemes in separate areas;
- Add scheme and Open schemes folder operate only on the user collection;
- an imported definition cannot replace or shadow an official ID.

The official set is eleven JSON schemes plus the built-in Night and Light compatibility palettes, for thirteen choices:

1. PMM Crystal — fresh-install and Restore-defaults choice;
2. Olive Grove;
3. Mushroom Kingdom;
4. Web Slinger;
5. Minecraft Overworld;
6. Neon Synthwave;
7. Coral Reef;
8. Sakura Matcha;
9. Nocturne Castle;
10. Desert Sunset;
11. Aurora Confetti;
12. Night;
13. Light.

The authoritative inventory and hashes are in `Resources\Themes\OFFICIAL_THEME_MANIFEST.json`. `BUNDLED_THEME_MANIFEST.json` independently pins the eleven JSON resources. A missing, altered or unlisted official file is not treated as an unsigned official theme; PMM falls back to PMM Crystal and finally to the hard-coded Night emergency palette.

## Import contract

Settings accepts one or several `PMM_COLOR_SCHEME_V1` JSON files or a bounded ZIP. The importer:

- inspects and parses the complete selection before committing anything;
- rejects traversal, absolute or drive-qualified paths, alternate data streams, links, nested archives and executable/script content;
- validates the real PMM surface contrast matrix at 4.5:1;
- rejects collisions with official IDs;
- confirms and backs up a changed user definition before replacement;
- refreshes the list once after the transaction.

Official files must never be copied into `Workspace\Themes`. Importing an exact official definition reports that it is already bundled.

## AI & Help editor

The editor exists only in **AI & Help / IA y ayuda > Color scheme editor**. Settings remains the selection/import surface.

Every managed palette and ColorFlow brush row exposes:

- a required fallback color;
- a color picker;
- Upload image;
- image preview/options;
- Remove image.

Drafts persist below `Workspace\Themes\Drafts`. Solid themes export as `PMM_COLOR_SCHEME_V1`. Image-backed themes export as `PMM_COLOR_SCHEME_V2` inside a self-contained `PMM_THEME_PACK_V1` ZIP. Only local PNG/JPEG assets are allowed; URLs, UNC paths, absolute paths, environment expansion and executable formats are rejected. Image assets remain subject to entry, byte, dimension, decoded-pixel and contrast limits.

Preview is reversible and does not save the active configuration until the user confirms. Install locally creates a user scheme; it cannot mutate the official set. Create with AI produces an offline handoff, and an imported AI response becomes an editable draft only.

## Runtime integration

Non-WPF validation, import/export and ownership logic live in `Modules\Theme\ThemeService.ps1`. Draft/editor logic lives in `Modules\Theme\ThemeEditorService.ps1`. WPF resource application and control binding remain in `Modules\Bootstrap\Start-PalModMerger.ps1`.

The three localized XAML files share one control contract. The header keeps equal responsive branding/action halves, the larger transparent PMM logo and title, and the 900x600 logical minimum. At constrained width, the action half stacks instead of collapsing or hiding the main navigation.

Determinate progress may interpolate only values below completion. A confirmed 100% report cancels pending interpolation and appears immediately before the next task begins.

## AIIO boundary

The editor uses the same local-first trust model as AIIO. Theme packages and AI responses are data, never code. RC27 has no provider login, automatic upload, remote theme install, returned-code execution or automatic Apply/Build/Deploy/Publish action.

## Continuation rules

- Preserve all eleven JSON themes and both compatibility palettes.
- Preserve official/user separation and reserved IDs.
- Keep V1 valid; add future image features through backward-compatible V2 contracts.
- Keep the editor exclusively under AI & Help.
- Do not move heavy validation onto the WPF dispatcher.
- Do not claim Windows acceptance until `TEST_THIS_BUILD_RC27.txt` passes on a real Windows/Palworld installation.
