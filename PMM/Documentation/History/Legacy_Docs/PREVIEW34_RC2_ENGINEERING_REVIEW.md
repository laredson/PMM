# Palworld Manager Merger preview34 RC2 engineering review

**Date:** 2026-08-17  
**Application:** v1-preview34-RC2  
**PMMCore:** 0.8.1 (frozen from runtime-proven RC1)  
**Plan schema:** 12

## Purpose

RC2 is the final lifecycle/branding candidate before 1.0. It does not change
PMMCore, mappings, SaveService, or any production merge adapter.

## Manager-only deployment

The patch selector has an explicit **No compatibility patch / source mods only**
radio choice. When selected:

- Deploy is available without Analyze;
- active source PAKs are synchronized;
- any managed PMM compatibility overlay is removed from the game folder;
- saved overlays remain in Builds/Current and Builds/Previous;
- only byte-identical duplicate source PAKs are automatically suppressed; and
- actual conflicts between source PAKs are intentionally left to normal Palworld
  PAK load order.

Selecting or building a compatibility patch returns to the normal merger flow.

## Branding

The public application name is **Palworld Manager Merger (PMM)**. Internal legacy
filenames such as `Start-PalModMerger.ps1` and `Logs/PalModMerger.log` are retained
for migration/stability and do not represent the public product name.

## Acceptance

See `PREVIEW34_RC2_VALIDATION_TARGET.md`.
