# RC28 static validation record

Candidate: `PMM-v1.3.0-RC28-VALIDATION-RUNTIME-FIX`  
Date: 2026-08-30

## Proven in the build environment

- The complete deterministic validation-ID model produces a stable 64-character lowercase SHA-256 and matches its fixed fixture.
- The canonical schema-3 deployment model exposes deployed source mods plus the selected compatibility patch without absolute paths and excludes suppressed alternatives.
- Candidate refresh cannot assign a collection through an unwrapping `if` expression.
- The submitted executed RC27 PAK hash matches its schema-9 manifest output hash; its modeled RC28 build ID is a valid 64-character SHA-256.
- All inherited RC22–RC27 cross-platform regression models pass.
- Application JSON and localized XAML parse, required controls remain in parity and no runtime `Workspace`, user PAK, save, log, Game Reference data or Oodle DLL is shipped.
- Internal and outer SHA-256 inventories, ZIP CRC, safe member names, clean extraction and byte-for-byte package comparisons pass for the final artifacts.

## Still requires Windows

This environment does not provide Windows PowerShell 5.1, WPF, Steam or Palworld. Run `PMM/Documentation/TEST_THIS_BUILD_RC28.txt` before publishing. In particular, record validation against the existing deployed merge, AI & Help refresh with schema-3 state, and zero/one/many candidate refresh must be accepted on Windows.
