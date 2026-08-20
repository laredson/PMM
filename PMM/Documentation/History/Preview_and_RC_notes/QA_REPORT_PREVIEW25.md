# PalModMerger preview 25 QA notes

Static checks performed in the build environment:

- XAML files parse as XML.
- Data/config.json parses as JSON.
- PowerShell files pass a delimiter/balance scan in the build environment.
- Start.cmd contains the visible PALMODMERGER (PMM) header and conditional setup.
- Compatibility overlay is the only normal UI strategy; source mods remain installed.
- Deployed patch lifecycle functions are present: discovery, manifest migration lookup, output/source hash validation, CURRENT/STALE display, Analyze short-circuit, forced Remerge/Rebuild.
- Analyze reserves N+1 progress steps and Build has a separate green progress bar.
- Preview25+ manifests include source signature, mappings hash, exact patched provider names, asset/provider coverage, and KeepSourceModsInstalled policy.

Windows/WPF and Palworld runtime validation still requires running the packaged application on Windows.
