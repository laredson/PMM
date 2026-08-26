# Palworld Manager Merger (PMM)

## Make conflicting Palworld mods work together

**Palworld Manager Merger analyzes your PAK mods and creates a compatibility patch so mods that would normally overwrite each other can work together.**

It is also a practical mod manager: import mods, enable or disable them, keep backups, deploy your setup, switch between saved merge patches, and backup or restore your Palworld worlds.

### The whole process

**Extract anywhere -> Import -> Analyze -> Build -> Deploy -> Play.**

PMM tries to do the hard part for you. If several mods edit the same game file but their changes can coexist, PMM combines them. If they genuinely disagree about one value, it asks what you want. If it cannot prove a safe merge, it tells you instead of blindly generating a broken patch.

**PMM is open source and transparent:** the PowerShell/WPF application and C# merge/reader source are included in the download, under the MIT License.

You can also select **No compatibility patch** and use PMM only as a mod manager. In that mode Deploy installs your active source mods and removes any PMM merge overlay from the game.

---

## Tested working together

The following have been tested successfully in Palworld as part of the same large mod setup:

- **FlyMode**
- finite **MultiJump** variants, including Double / Triple / Quad
- **WingPack - No Wing Cells / Visible Only While Flying**
- **Food Never Spoils**
- **Stack Size / Zero Weight**
- **Early Aquatic Construction Kit**
- **Easy Breeding**
- **No Collision Farms and Expeditions**
- **Free Enhance Player Ability**
- **Increased Player Stat Caps 1000**
- **RushRoar Leather Drop**
- many additional PAK mods using independent files

A useful example is **MultiJump + Fly + Wing**. PMM can preserve the selected finite jump count, keep Fly's independent player changes, and keep the compatible Wing behavior at the same time. In the tested setup you can perform the selected extra jumps, enter Fly behavior, and see the wings during flight while the other merged mods continue working.

The important point is that PMM is **not limited to these names**. It analyzes the actual files you give it.

---

## What other mods should work?

In principle, any PAK mods whose changes PMM can safely combine are candidates.

Especially promising cases are mods that are normally described as incompatible simply because they edit the same:

- Pal parameter DataTables — mount speed, stamina, work suitability, stats, etc.
- option/settings Blueprints — FOV, camera, world settings, and similar options
- item/recipe DataTables — recipes, crafting and item changes
- player or Pal Blueprints where different mods modify independent behavior
- different versions of the same mod where only one value changes

Those combinations are **not automatically claimed as tested** unless they appear in the tested list above. PMM analyzes the current files and decides from their structure, not from a filename compatibility list.

---

# Quick use

1. Extract PMM wherever you want.
2. Double-click `PMM.exe` (first launch may prepare/download the pinned dependencies).
3. Detect your Palworld installation.
4. Import your PAK mods or use **Import ~mods**.
5. Choose which mods are On.
6. Click **Analyze**.
7. If PMM asks for a real conflict choice, choose what you want.
8. Click **BUILD MERGE**.
9. Click **DEPLOY**.
10. Play.

That's the normal workflow.

If you do not want a compatibility patch, select **No compatibility patch** and Deploy. Analyze is not required for this manager-only mode.

---

# Mod manager features

PMM can also:

- import an existing `~mods` setup;
- enable/disable source mods without deleting them;
- remove mods from the PMM library;
- keep disabled mods backed up;
- avoid deploying redundant byte-identical copies;
- keep several saved compatibility patches;
- switch between saved compatible merge choices and Deploy them without rebuilding;
- manage the deployed PMM overlay automatically;
- backup Palworld worlds;
- restore world backups;
- work in English or Spanish.

Import and Build do not normally modify Palworld. **Deploy** is the explicit step that synchronizes the selected setup with the game.

---

# Transparent / open-source project

PMM is designed to be completely inspectable.

The application is built around readable **PowerShell scripts + WPF/XAML**, and the C# source for PMMCore and the asset-reading tools is included. The managed C# tools are built from that included source during setup; PMM does not hide its merge logic inside a closed proprietary application executable.

PMM does use separate third-party tools/runtimes where required, such as `repak` and .NET dependencies. Their notices/licensing are documented separately.

The final public release includes the project's open-source license so developers can inspect, fork and continue the project under those terms.

---

# Unsupported conflicts and community growth

PMM already contains a growing **Knowledge Library** based on real solved cases.

If new conflicts are Unsupported, advanced users can explicitly create **one AI_HANDOFF bundle** for the current mod list. AIIO includes the analysis plus only the exact conflicting files from each involved mod and Vanilla; it never copies whole source PAKs. A developer or capable AI can investigate the cases and return solutions in PMM's documented format.

Successful community solutions can be shared back with the project so later releases can expand the Knowledge Library and automatic compatibility support.

Palworld Manager Merger was created by **laredson with GPT assistance**, with **50+ hours of hands-on development, debugging, research and in-game testing** behind the v1.1 release.

More information for developers, contributors and AI-assisted workflows is included inside the download under **Documentation**.

---

# Possible future versions

Depending on feedback and development time:

- Nexus Mods integration and direct downloads
- mod update checks
- shareable/automatic modlists and profiles
- Steam Workshop support
- PalSchema management
- UE4SS management
- Game Pass support
- deeper Blueprint/Kismet compatibility analysis
- more community Knowledge packs and automatic merge methods
- additional AI-assisted Palworld mod-development tools

---

## Credits

**Palworld Manager Merger (PMM)**  
Created by **laredson + GPT-assisted development**.

Thanks to Palworld mod authors, the Palworld modding community, and the developers/contributors behind the tools and libraries used by PMM.

Please support the original mod creators. PMM does not replace their mods — **it helps them work together**.
