# Palworld Manager Merger 1.2 RC1

Palworld Manager Merger (PMM) preserves original Palworld mods and builds compatibility patches
for conflicting content. This clean RC1 is the integration baseline derived from the maintainer-tested
v1.2 Alpha 3 build and includes the proven Ribunny package-choice improvement.

## Start

Run `Start.cmd` (or `PMM.exe start`). Normal startup is supervised by the small native `PMM.exe`
Host and routed directly to `PMMRuntime.exe`; dependency preparation and the native fallback shell do
not require PowerShell FullLanguage.

The full current Mods & Merge workspace is still the proven PowerShell/WPF implementation on
FullLanguage systems. If Windows restricts PowerShell to ConstrainedLanguage, PMM opens the native
Runtime shell and preserves diagnostics instead of crashing during startup. The remaining full
Analyze/Build/Deploy workflow still needs native migration before this candidate can honestly be
published as the complete ConstrainedLanguage fix.

## Open source and modularity

- `Host/` contains the complete PMM Host source.
- `Runtime/` contains the complete PMMRuntime source and build script.
- `Runner/` contains external routing and editable script operations.
- `Knowledge/*.json` is the external Compatibility Knowledge Library source of truth.
- UI/configuration stays external where practical.
- Future Fix Lab knowledge should remain external in the same spirit.

See `Documentation/V1_2_RC1_VALIDATION.md` before public release.
