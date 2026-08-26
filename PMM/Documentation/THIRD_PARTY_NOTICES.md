# Third-party notices

Palworld Manager Merger (PMM) v1.1 is open-source under the MIT License in `LICENSE`.

PMM uses or prepares the following third-party components:

- **repak 0.2.3** — Unreal Engine `.pak` CLI by Truman Kilen and contributors. The bundled `Engine/repak.exe` is distributed under the project's MIT/Apache-2.0 dual-license terms; PMM uses the MIT option. See `Documentation/ThirdParty/repak-LICENSE-MIT.txt`. Upstream: `https://github.com/trumank/repak`.
- **UAssetAPI 1.1.0** — used by the read-only AssetReader layer. MIT. The public package includes the prepared managed dependency and verifies it by release hash + AssetReader self-test; end-user setup does not rebuild it. See `Documentation/ThirdParty/UAssetAPI-LICENSE.txt`.
- **Newtonsoft.Json 13.0.3** — dependency of AssetReader. MIT. See `Documentation/ThirdParty/Newtonsoft.Json-LICENSE.txt`.
- **ZstdSharp.Port 0.8.1** — dependency of AssetReader. MIT. See `Documentation/ThirdParty/ZstdSharp-LICENSE.txt`.
- **Microsoft .NET Runtime 8.0.30 (Windows x64)** — used to execute PMMCore and AssetReader. The public v1.2.1 package includes the pinned portable runtime under `Engine/dotnet/8.0.30/` and verifies it against the bundled inventory. Network download is a repair fallback only when the local payload is missing or invalid. The .NET SDK 8.0.424 is developer-only and is not an end-user dependency. PMM does not claim ownership of .NET.
- **Palworld mappings** — `Resources/Mappings/Mappings.usmap` is a modding-support data file used to interpret current cooked assets; PMM records its SHA-256 in analysis/build manifests.
- **Oodle runtime** — PMM v1.1 intentionally does **not** redistribute `oo2core_9_win64.dll`. When Oodle is required, pinned repak obtains its expected runtime on demand. PMM also verifies the known repak 0.2.3 Oodle SHA-256 if that local DLL already exists and removes unexpected substitutions before use.

Palworld, Unreal Engine and third-party mods remain the property of their respective owners/authors. PMM is an unofficial community project and is not affiliated with or endorsed by Pocketpair, Epic Games, Nexus Mods, Microsoft or OpenAI.

## Go toolchain/runtime (PMM.exe / PMMRuntime.exe)

PMM's Host and Runtime executables are built from the included Go source. The Go runtime/toolchain license is reproduced at `Documentation/ThirdParty/Go-LICENSE.txt`.
