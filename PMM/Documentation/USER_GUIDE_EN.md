# Palworld Manager Merger v1.3.1 — User Guide

**Guided workflow:** PMM highlights only the next useful stage: **Import -> Fix Lab when required -> Analyze -> Build -> Deploy -> Play**. The color is state-derived. During Import/Analyze/Build/Deploy the highlighted button itself becomes a progress surface, while the persistent progress bar under Build/Deploy keeps the last percentage/result until another operation starts.

## What PMM does

PMM is both a Palworld PAK mod manager and a compatibility merger. It keeps a local mod library, analyzes assets shared by multiple mods, builds one compatibility overlay, and explicitly deploys the selected source mods + optional overlay to Palworld.

## Normal workflow

1. Double-click `PMM.exe`. It is the normal and only user-facing launcher in the portable application root. The public package includes the pinned PMM tools and verifies them before launch. PMM requires .NET Runtime 8.0.30; if that exact runtime is not already available, Setup downloads the pinned Microsoft win-x64 runtime once, verifies its SHA-512 and installs it portably inside the PMM folder. PMM does not compile itself on an end-user PC. repak may also obtain its Oodle runtime later when a PAK requires it.
2. PMM resolves Palworld automatically when possible. The installation-status card in the main header is also the **Detect** button. It remains visible and is enabled only while the installation needs attention; once Palworld is validated, it stays visible but disabled. If a manual click cannot detect Palworld automatically, PMM opens one chooser for either a Steam folder or a Palworld folder. Detection/change-installation controls also remain available in **Settings**.
3. Import PAK/ZIP/7Z/RAR files, or import the current game `~mods` folder.
4. Use the **On** checkboxes to enable/disable source mods. Disabled PAKs are kept in PMM's library.
5. Arrange merge priority if needed: **top applies earlier / lower priority; bottom applies later / higher priority**.
6. Click **Analyze**.
7. Review **Analysis plan**. Automatic rows require no action.
8. If **Resolution & Review** opens with `DECISION REQUIRED`, choose the desired value/provider only for the real overlapping change.
9. If **Blocked shared assets** reports Unsupported, either disable an involved mod and Analyze again or open **AI & Help > AI repair / AIIO** for a persistent advanced task. The legacy **CREATE AI HANDOFF** action remains available.
10. Click **BUILD MERGE** when ColorFlow requests it. If Analyze proves that an existing patch still covers the effective conflict set, PMM skips Build automatically. Build is local; it does not deploy to the game.
11. Select the desired saved patch in **Compatibility patches** and click **DEPLOY**.

## Header and Palworld paths

The branded main header uses the larger transparent PMM mark, the three-line **PALWORLD / MANAGER / MERGER** name and its subtitle. On wide windows branding and actions occupy equal halves; at narrow widths actions stack below branding. The installation-status card is the header Detect action: enabled when attention is required and disabled after validation. The same header keeps **SemiAUTO**, **Run Palworld after Deploy**, one-shot **AUTO**, **Open game folder**, **Open mods folder**, and **Start Palworld** together. The full installation path, persistent detection/change controls, manual **Choose Steam folder** / **Choose Palworld folder** controls, and diagnostics live in **Settings**. **Open mods folder** opens or creates `Pal\Content\Paks\~mods`.

## Manager-only mode

Select **No compatibility patch** to deploy active source mods without any PMM compatibility overlay. Analyze is optional. If a PMM overlay is currently deployed, manager-only Deploy removes that managed overlay while keeping saved patches in PMM's library.

## Saved patches

PMM may keep several patches, for example different choices from a conflict. An exact source-set match is selectable immediately. After Analyze, PMM can also reuse a patch when every effective conflict participant, provider hash, adapter, decision, mapping and Vanilla input still matches—even if unrelated unique mods were enabled or disabled. In that case Build is skipped and Deploy only synchronizes the changed source PAKs. A patch that is not proven compatible remains visible but disabled.

## Source mods and priority

- **Import** copies mods into PMM's library. Newly discovered source PAKs are appended at the bottom/highest priority until you move them.
- Drag a source row to insert it before/after another mod, or type its final 1-based position directly in **Order**. The list is always normalized to `1..N`; out-of-range numbers clamp to the first/last position and the intervening mods shift automatically.
- **Earlier / lower priority** and **Later / higher priority** remain available for one-step moves.
- Priority is field-level conflict precedence, not a whole-file winner: independent changes are union-merged, and only a real overlapping value defaults to the lower-listed provider.
- Manual choices in **Resolution & Review** override priority. Unsupported structures are never forced through by priority.
- Changing priority requires Analyze again before a new Build. Existing same-source patches stay available only as explicit rollback outputs if their order differs.
- Uncheck **On** to disable/back up a mod without deleting it.
- Re-check it to reactivate it.
- The mod grid supports **Ctrl/Shift** multi-selection and **Ctrl+A**. Use **Enable selected**, **Disable selected**, or **Delete selected** to change a group at once. Priority move buttons intentionally require one selected mod.
- **Import...** opens one small chooser: **Import mods...** selects one or multiple PAK/ZIP/7Z/RAR inputs, while **Import folder...** imports all supported files directly inside one folder. Archives are unpacked only as temporary input; only their PAK files enter the PMM library. **Import ~mods** is the guided choice when Palworld already contains source PAKs PMM needs to bring into its library.
- **Delete selected** is immediate: it removes the imported copy from PMM and the exact same hash from Palworld `~mods` if it is deployed there. A same-name file with a different SHA-256 blocks the delete. Any deployed PMM compatibility merge and sidecar are preserved until you explicitly change them in **Compatibility patches**; Analyze freshness is invalidated so PMM can explain the new source state.
- Deploy does not blindly delete unrelated PAKs PMM has never managed.

## World Save

The **World Save** tab can create world backups and restore a selected backup. PMM creates a safety backup before replacing a world during restore. Keep independent backups for important worlds as well.

## AI & Help and local-first AIIO

**AI & Help** contains bounded assistance, persistent AIIO repair/mod-creation tasks, Feedback & Knowledge, reception of returned work, and the color-scheme editor. **Prepare for AI** creates a local ZIP for you to send manually. PMM has no AI-provider login and performs no automatic upload. A returned ZIP is untrusted data: scripts, executable content, unsafe paths and nested archives are rejected, and candidates remain staged until inspected.

For a new standalone mod, choose **New mod project**, describe the intended behavior and optionally provide an exact asset/family hint. A `CREATE_MOD` session may request bounded families from the current Game Reference. After importing a response, PMM can expose **Build standalone PAK...** only when the candidate declares a safe cooked tree and exact hashes. The output stays in the AIIO session workspace as `LOCAL_BUILD_UNPROVEN`; it is never installed, deployed or published automatically. Its PAK contains inert `created using PMM` metadata. If you publish the mod, its description must include: **This mod was created with PMM assistance.**

Only an exact current `PMM_MANUAL_SOLUTION_V1` cooked-family candidate may expose **Use candidate in Merge**. Confirmation forces Analyze; it never starts Build or Deploy. Build validation and feedback history are local and deterministic. See `AI_HANDOFF_AND_KNOWLEDGE.md`.

Settings now mirrors sound ownership for themes: eleven hash-pinned JSON schemes plus Night/Light remain under official schemes; anything added by the user appears in a separate bordered `Workspace\Themes` collection. The AI & Help editor exposes fallback color and optional local image controls for every named palette/ColorFlow brush.

## What Unsupported means

Unsupported means PMM cannot currently prove a safe composition for that exact shared cooked asset. It does **not** automatically mean the mods are fundamentally incompatible. You can disable a provider or use the advanced AI/modder handoff described in `AI_HANDOFF_AND_KNOWLEDGE.md`.

## Logs and troubleshooting

Start with `Documentation/TROUBLESHOOTING.md` and `Logs/PalModMerger.log`. Send that **single log file** for support. v1.1.1 coalesces exact repeated events with counts and first/last timestamps while preserving distinct diagnostic lines. Include the PMM version, exact error text and relevant AI_HANDOFF/review case when reporting a compatibility problem.

## Vanilla Game Reference and AIIO

In **Settings**, **Build / refresh Game Reference** maintains a local, version-aware research cache. PMM reads selected material from your installed `Pal-Windows.pak` into `Workspace/GameReference` and never modifies the game. Normal compatibility analysis can work without a full reference, while Fix Lab recipes can request and retain additional current families on demand.

AIIO handoff creation does not require this cache. When you explicitly create a handoff,
AIIO re-extracts the exact conflicting Vanilla file/family and the exact counterparts from
each involved source PAK, then places them in separate origin folders in one bundle.
If you close the Explorer window, select the exchange in **AI reception** and press
**Open latest handoff** to show its most recent request ZIP again.

After PMM accepts an AI/manual solution and you have actually tested it successfully in
Palworld, Settings -> **Create tested contribution...** creates one evidence ZIP that can
be sent to the PMM maintainer/community review. Only confirm PASS for the exact solution
you tested.


## Long operations in PMM 1.3

Analyze, Build, Game Reference work, and Fix Lab Repair run in supervised child worker processes. The WPF window remains available for navigation, resizing, progress review, and cancellation while a long Repair is running. Real progress is mirrored both by the active workflow button and by the persistent universal progress bar below Build/Deploy. Determinate bars present each newly proven range one percentage point at a time over roughly three seconds: they may lag the worker but never display a percentage the worker has not reached. A confirmed 100% update jumps immediately to 100 and clears pending animation before the next task. The universal bar remains at the previous 100% result until another operation starts. Successful operations do not open completion popups; confirmations, actionable warnings and errors still appear when needed.

The five complete Gawr Gura Case 001 outputs are mutually exclusive variants. If two are active, Analyze stops before enumerating/extracting the large model families and requests one package choice in **Resolution & Review**. Choose the intended output and run Analyze again; the alternative remains in the local library but is excluded from analysis and the next Deploy.

The original source mods are never consolidated into a MegaMerge. Build creates only PMM's compatibility patch.


### Managing imported mods and saved merges

The selection controls directly below **Mod library** apply to imported mods. Ctrl/Shift/Ctrl+A can select several rows, then **Enable selected**, **Disable selected** or **Delete selected** applies to the group. The **Compatibility patches** section has **Validate merge** and **Delete merge** actions. **UNDEPLOY** removes only the selected exact merge from Palworld `~mods` and keeps the saved PMM build. **Delete merge** removes the exact deployed copy if present, all matching saved PMM copies/manifests, its selection state and its runtime-validation record; source mods are never deleted. PMM does not silently recreate a saved build merely because a deployed PMM merge is detected in `~mods`.


### Automatic mode and Cancel

**ColorFlow and AUTO use the same workflow state machine.** The order is `Detect (only if needed) -> Import -> [Fix Lab when required: Game Reference -> output choice -> Repair -> Apply Fix] -> Analyze -> Build Merge -> Deploy -> Play ready`. **SemiAUTO** is persistent continuation: when it is checked, a flow action you start manually continues through the remaining safe steps. The header **AUTO** button is a separate one-shot command that runs the remaining safe workflow once without enabling SemiAUTO. AUTO may import the known Palworld `~mods` source directly; arbitrary file/folder import still pauses for user selection. After a current deployment, ColorFlow illuminates **Start Palworld** and shows **Everything is ready to play.** **Run Palworld after Deploy** controls only automatic launch and remains off by default.

If PMM recognizes an exact legacy/broken-mod identity with Fix Lab knowledge, Fix Lab becomes the next ColorFlow/AUTO state **before normal Analyze**. If the recipe requires Current Game Reference and it is not current, AUTO builds it directly in the background. One repair output may be auto-selected; multiple outputs stop at **Choose output**. After Repair and **Apply Fix**, Fix Lab is considered resolved and the next shared state is normal **Analyze**. Ignore this legacy mod suppresses that exact source hash under the user's responsibility.

**CANCEL** is available for manual and automatic operations. Analyze/Build/Fix Lab/AIIO background workers are stopped; archive/import work cooperatively stops its child extractor; Deploy uses the normal verified rollback path if managed files had already begun to commit.

For Fix Lab, Ctrl/Shift can select more than one library source for the same job. The first selected source becomes the primary snapshot and the remainder are preserved as related/historical evidence. Gura Case 001 can generate all five documented outputs locally from either exact v5 **Normal** or exact v5 **FullReplacement**, plus Current Game Reference and compact CKL recipes. Original Full Replacement, **Normal - Locked** (confirmed in-game on 2026-08-27, including pelvis), and Hair2/Panties have runtime evidence. Red/Evil and Hooded are structurally validated deployable repairs whose runtime acceptance is not yet recorded. Fix Lab presents this as a confidence level in Built outputs and does not show an extra warning dialog before Apply Fix; `DeployAllowed` is the actual deployment gate. The responsive Fix Lab page organizes Source, Configure Repair, Build & Validate, Built Outputs, Backups, and Advanced/AIIO as collapsible stages. Tab navigation uses the cached dashboard and queues periodic hydration after the visual change; **Refresh Fix Lab** requests an immediate on-demand refresh. Apply Fix and Restore original never remove or replace a deployed compatibility merge.


## PMM 1.3 merge lifecycle

- **Deploy**: install/synchronize the selected compatible merge to Palworld.
- **Undeploy**: remove only that exact merge PAK and its sidecar from Palworld `~mods`; keep the saved build in PMM.
- **Delete merge**: undeploy the exact hash if present and delete matching saved copies/manifests inside PMM. A same-name file with a different hash is never removed.
- **Validate merge**: record that exact output hash as user-tested in game.
- There is no user-facing Archive operation. `Builds\Previous` is internal history only.
- `Import ~mods` imports source mods but only *recognizes* PMM-generated merge PAKs; it does not silently re-create deleted saved builds.
### Concurrent Game Reference + output choice

When a supported Fix Lab case needs Current Game Reference, PMM starts/builds the reference first. If the case has multiple outputs, the output chooser is a parallel human decision: ColorFlow marks it while Game Reference keeps building. AUTO stays armed while waiting. Choose during the build and AUTO continues to Repair as soon as the reference is ready; if you wait, the same output choice remains the required action after the reference finishes. The source card also offers **Ignore this legacy mod** and **Delete this mod**; Delete is the same exact-hash delete-everywhere operation as Imported Mods.

### AUTO while Fix Lab builds Game Reference

If a detected repair needs Game Reference, AUTO first invokes the **same canonical Build / refresh Game Reference command used by the Settings button**, before any Fix Lab tab navigation. This deliberately avoids a second AUTO-only launch path. When AUTO first encounters that Fix Lab case it opens **Fix Lab once** so the case/output choice is visible. After that initial presentation, tab navigation belongs to the user: moving to Settings or another tab while Game Reference builds is never undone by the watchdog. The same progress bar/state is shown in both Settings and Fix Lab. For a repair with several outputs, choose the output whenever you want while the reference is building; AUTO resumes as soon as both the reference and your choice are ready. A Game Reference build started manually also resumes an already-running AUTO chain when it completes; with SemiAUTO, starting Game Reference manually arms continuation just like any other workflow step.

Successful steps no longer use informational OK popups. **Settings** provides independent Color scheme and Sound event controls, built-in and custom sounds, and a 0-100% volume slider (50% default). The two microwave profiles remain distinct: **Microwave finish** and **3 beeps**. Manual workflow steps use the Manual profile; AUTO/SemiAUTO uses the configured Auto/Semiauto profiles.


### Appearance

PMM continues to use WPF/XAML. The visual layer now has a full Light/Dark palette, themed cards, grids, inputs, tabs and a larger application header. Theme changes are applied with **Apply changes**, update the full interface without restarting PMM, and persist in `Workspace/State/config.json`. Night mode uses dark neutral surfaces and darker neutral buttons while preserving semantic Fix Lab/ColorFlow colours.

### RC14 settings behavior
Appearance, action-hint duration, completion sound and volume are staged in Settings and committed with **Apply changes**. Light/Night theme brushes use dynamic WPF resources so the complete interface updates without restarting PMM.

## RC17 appearance, sounds and save backup browser

New installations default to **PMM Crystal** while upgrades preserve a valid existing choice. Settings separates **Color scheme** and **Completion sound** into independent lists. **Add schemes (JSON/ZIP)...** accepts one or several `PMM_COLOR_SCHEME_V1` JSON files or a bounded ZIP and stores only validated user schemes in `Workspace\Themes`; **Add sound...** copies a WAV/MP3/WMA into `Workspace\Sounds`. Press **Apply changes** to commit theme, ColorFlow hint duration, sound and volume without restarting PMM. **Restore defaults**, placed beside Apply at the upper right, stages PMM Crystal, a 5-second hint, 50% volume and the RC19 sound-profile defaults without changing language, paths, library or user data; press Apply to save them.

The World Save tab has two collapsible right-side panes: **Selected save** and **PMM backups made**. Selecting a backup shows its date, archive size, expanded size, file count and simple delta against the current save. Restore uses the selected PMM backup and creates a safety backup before replacing the live world.


### Sound events
Settings -> Sound events lets you configure Auto, Semiauto, Manual, Attention required and Error independently. Built-in sounds are shown separately from imported custom sounds. `Sound each AUTO step` is enabled by default and controls the short Semiauto cue; choosing a concrete Semiauto sound enables it, while choosing `None` or clearing the checkbox mutes it. `Sound when attention is required` controls decision alerts. Manual Start Palworld is intentionally silent; the Auto completion sound fires only when the whole automatic workflow has completed.

RC22 keeps the RC19 built-in sound assignments and corrects the Semiauto master default: Auto = Microwave finish, Semiauto = OK, Manual = Good, Attention required = Short alert, Error = 3 beeps. Existing RC21 settings migrate once so an assigned Semiauto cue is audible unless it is explicitly set to `None`; the checkbox can still mute it. OK and Good are bundled official sounds. The Configure repair Action required bubble uses a dedicated contrasting decision color so it remains distinct from the amber Configure repair panel.
