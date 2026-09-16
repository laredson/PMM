# Optional modding tools installation

## 1. Decide whether your mod needs these tools

PMM does not require Unreal, Wwise or a separately installed Python to manage mods, investigate the game reference, inspect properties and DataTables, extract bounded asset families, perform supported edits or repack already cooked assets. Merge and FIX LAB do not inherently require this entire environment.

Unreal is used for work requiring the editor to create/import content and cook it for Windows. PMM's first adapter is limited to textures and duplication/configuration of verified templates. Installing Unreal does not enable arbitrary Blueprint modification.

Wwise provides the AkAudio dependency of the full Palworld kit used here. That dependency can be required to compile the kit even when a mod does not change audio. Wwise is not required for every Palworld mod or every Unreal project. A lightweight profile without Wwise is not implemented or verified in this adapter.

The additional-100-main-inventory-slots PAK is still unproven in game. Installing the tools does not establish that this change is feasible.

## 2. Open PMM's tools

Open Settings → Installations. Select Detect installed tools before installing. Components have separate states; Locate accepts an existing folder, executable or compatible package.

Accept starts the proposed installations. Choose persistent permission for the PMM catalog or ask each time; Cancel grants no permission. Permission can be revoked. Official account, license and Windows prompts remain interactive.

## 3. Unreal Engine 5.1.1

You need the editor and cooker, not only an SDK.

1. Open Epic Games Launcher from PMM.
2. In Unreal Engine → Library, add an engine version using +.
3. Select exactly 5.1.1 in the version dropdown. The launcher may default to the newest version; that is not the version for this kit.
4. Install with the necessary Windows tools. Quixel Bridge is optional and is not needed by PMM.
5. Return to PMM and select Detect installed tools. If needed, Locate accepts the UE_5.1 root or UnrealEditor.exe.

The normal launcher flow requires manual version selection. PMM does not promise silent engine installation. No separate Python installation is needed: managed projects use Unreal's embedded Python.

## 4. Visual Studio and Microsoft tools

Install Visual Studio 2022 with C++, MSVC v143 x64/x86 14.38–17.8, Windows SDK and .NET Runtime 6 x64.

An up-to-date VS 2022 installation does not necessarily include MSVC 14.38. That toolset can coexist with newer ones. PMM distinguishes the IDE from the toolset and uses documented installer arguments to add missing components. Existing VS editions need not be removed.

Manual route: Visual Studio 2022 → Modify → Individual components → MSVC v143 — VS 2022 C++ x64/x86 (v14.38–17.8).

Avoid simultaneous installer instances. Let active installations finish; close an idle installer window before requesting modification from PMM. An install.lock message alone is not a reason to reboot: check the active job first.

## 5. Wwise SDK: download, then install

Initial acquisition uses the connected Audiokinetic Launcher and your account. Offline packages allow later reuse; they do not remove license requirements.

1. In Wwise select 2021.1.11.7933, not Latest.
2. Choose Create offline installer to retain the packages.
3. Include SDK (C++), Microsoft → Windows → Visual Studio 2022, with Win32/x64 vc170 libraries.
4. Game Core, UWP, consoles, other platforms and extra audio plug-ins are unnecessary here. Authoring is optional for this PMM workflow. Do not add Wwise to Unity.
5. Use PMM's Open Wwise offline folder: Workspace/Dependencies/Offline/Wwise-2021.1.11. The launcher may append Wwise_2021.1.11.7933; preserve that directory and its bundle folder.
6. Wait for the download. Creating an offline package does NOT install the SDK.
7. Run the launcher included with the package, or select Use offline installer and the bundle folder inside the downloaded package, then confirm Install. An empty directory or installed SDK root is not an offline package.
8. Detect tools again in PMM. Locate accepts the Wwise root, SDK or Wwise.exe. PMM checks the version and libraries, not just the directory name.

## 6. Wwise Unreal integration: a separate download

The installed SDK and Unreal integration are separate components.

1. Fully close the offline launcher. The orange indicator and disabled Download/Sign in controls identify offline mode.
2. Open the installed Audiokinetic Launcher from the Start menu. Do not run the launcher from the offline package again.
3. While connected, open Unreal Engine → Download → Offline integration files.
4. Choose 2021.1.11, integration 2021.1.11.2437. Save to the directory opened by PMM's Open integration download folder.
5. Preserve bundle.json, install-entry.json and Unreal.5.0.tar.xz. PMM also searches the Wwise offline directory.
6. Select Detect installed tools in PMM, or Locate the Unreal.5.0.tar.xz file directly.

An existing Unreal project is not needed to download integration files. The pinned kit uses Unreal.5.0.tar.xz with an adaptation to UE 5.1 in its managed copy; do not install UE 5.0 instead. PMM uses Unreal's Python to decompress XZ when Windows tar cannot.

## 7. Community kit and real verification

PMM pins PalworldModdingKit to e6632458b97af0083eb81715775651b08104ef6a. Resources/Unreal/profile.json records its URL and SHA-256. Install/complete retrieves and verifies that revision; existing projects must not be silently updated.

Pinned ZIP SHA-256: 9a13bf315b5e11587c9706ba9c6f4a370bfbbdde29509540b2d992665c79e993.

Detected means PMM found a component. It does not certify project compilation, candidate cooking or Palworld behavior. The integration is disabled by default; real checks use isolated projects. Use a separate test save for initial game testing.

## 8. Restore your private offline backup

The maintainer's packages are in a Release of the private PMM-setup-backup repository. Public users acquire dependencies officially; the personal backup is not part of the public PMM ZIP.

1. Download PMM-offline-2021.1.11.zip, its .sha256 file and OFFLINE_INVENTORY.json from the same authenticated Release. Download this PMM branch too.
2. Use the hash from that Release. From the PMM directory, first run a verification in PowerShell:

    & ./Resources/Unreal/Restore-OfflineBackup.ps1 -Archive 'D:/Downloads/PMM-offline-2021.1.11.zip' -ExpectedSha256 'HASH_FROM_SHA256_FILE' -VerifyOnly

3. Repeat without -VerifyOnly to restore into Workspace/Dependencies/Offline.
4. The script validates paths, sizes and hashes, reuses identical files and rejects conflicting files without overwriting them. It never launches installers or applies the original machine's permissions or paths to PMM settings.
5. Select Detect installed tools. An installed SDK is reused; if only offline packages exist, Install/complete opens the SDK installation flow.

Original vendor metadata may retain the original download location. PMM locates restored files in their new directory; it does not import that location as configuration. The backup excludes Unreal and full Visual Studio installations. Each machine uses detection or Locate for local configuration.

## 9. Troubleshooting

- Error 1639: Windows Installer rejected its arguments. Use this corrected PMM branch; opening Epic Store does not fix the arguments.
- Get-FileHash unavailable: use the corrected PMM version and Windows PowerShell; do not bypass integrity checks.
- Another installer / install.lock: check the active job and avoid duplicate requests. Never delete a lock while installation is running.
- Offline package ready: the SDK still needs installing.
- Error loading bundles: select a complete downloaded package, not an empty directory.
- Download disabled: close the offline launcher and open the installed connected launcher.
- Integration not detected: it is not included in the SDK download; locate its Unreal.5.0.tar.xz.
- Location rejected: check the version and components instead of modifying files to fake compatibility.
- All detected: real project verification is still separate. A built PAK is not proof of in-game behavior.

## Sources

- [Official Unreal installation](https://dev.epicgames.com/documentation/en-us/unreal-engine/installing-unreal-engine?application_version=5.1)
- [Visual Studio Installer arguments](https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2022)
- [Audiokinetic offline installers](https://www.audiokinetic.com/en/public-library/launcher_2025.3.3.5754/?id=working_with_offline_installers&source=InstallGuide)
- [Audiokinetic Launcher Unreal integration](https://www.audiokinetic.com/en/public-library/Launcher_2025.2.0.5346/?id=unreal_engine&source=InstallGuide)
- [Kit prerequisites](https://pwmodding.wiki/docs/developers/palworld-modding-kit/prerequisites)
- [Kit installation](https://pwmodding.wiki/docs/developers/palworld-modding-kit/installation)

## Centralized permissions and settings

In Settings → Installations, Change permissions switches between asking each time and authorizing future catalog requests. Accept saves the choice without installing anything; Cancel preserves the previous mode. Cancelling jobs is separate. Pending consent is also handled while this tab is hidden.

Settings contains General, AI/MCP, Installations, and the existing Mods & Merge, Mod Creation and Help options. Each relevant workspace has an Options shortcut. Cases retain separate IDs and histories even when their titles match.
