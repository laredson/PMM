# PMM color-scheme creation guide

This guide applies to `PMM_COLOR_SCHEME_V1` and image-backed `PMM_COLOR_SCHEME_V2` used by Palworld Manager Merger 1.3 RC27. It is written for human developers and AIs generating schemes.

## The central rule

A PMM scheme is not only a list of attractive colors. The same resources are reused across headers, cards, tables, disabled buttons, progress states, Fix Lab panels and action popups. Design the **relationships** first and validate every state before shipping.

The first experimental multicolor scheme demonstrated the common failure: a saturated violet `ButtonBackground` looked attractive with white `ButtonForeground`, but PMM later placed green detected-status text on that same button and dimmed the disabled control to 50% opacity. The combination became difficult to read.

The ten official candidates in this package avoid that by:

- using light buttons with nearly black text in Light schemes;
- using genuinely dark button surfaces with white text in Night schemes;
- choosing an `AccentHeadingGreen` that also contrasts with the button surface;
- using light ColorFlow progress colors with dark PrimaryText in Light schemes;
- using dark ColorFlow progress colors with light PrimaryText in Night schemes;
- checking disabled/composited states, not only the raw hex pairs.

## V1 file structure

```json
{
  "schema": "PMM_COLOR_SCHEME_V1",
  "id": "my-theme-id",
  "name": "My Theme",
  "base": "Light",
  "palette": {
    "AppBackground": "#F4F6F8",
    "PrimaryText": "#17202A"
  },
  "colorFlow": {
    "Import":  { "Progress": "#E8D9FF", "Border": "#6741A5" },
    "Analyze": { "Progress": "#D7EAFF", "Border": "#175CD3" },
    "Build":   { "Progress": "#FFE39A", "Border": "#875600" },
    "Deploy":  { "Progress": "#D4EFD9", "Border": "#2F7040" },
    "Play":    { "Progress": "#CDEBE5", "Border": "#176B61" }
  }
}
```

- `schema` must be `PMM_COLOR_SCHEME_V1`.
- `id` should use lowercase letters, digits, dots, underscores or hyphens and must be unique.
- `name` is the user-facing label.
- `base` is `Light` or `Night`. Missing palette keys inherit from that base.
- Colors should use `#RRGGBB` or another WPF-supported color representation, but `#RRGGBB` is strongly recommended for portability and review.

For an official or AI-generated theme, provide all supported keys explicitly. Inheritance is convenient for small user edits but hides design decisions during review.

## Palette key map

### Global surfaces and text

| Key | Usage |
|---|---|
| `AppBackground` | outer window/workspace background |
| `HeaderBackground` | main application header |
| `CardBackground` | primary cards, lists and content surfaces |
| `CardAltBackground` | secondary cards and normal progress-button surface |
| `InputBackground` | text boxes, combo boxes and popup inputs |
| `CardBorder` | standard card border |
| `InputBorder` | input and dropdown border |
| `PrimaryText` | most normal text, headings and in-progress button text |
| `MutedText` | descriptions, hints and secondary labels, often at small font sizes |
| `SelectionBackground` | selected rows/items/tabs |
| `SelectionText` | text over selected items |
| `GridLine` | table/grid separators |
| `Splitter` | resizable splitter visuals |
| `StatusBackground` | bottom status bar |

### Summary and semantic surfaces

| Key | Usage |
|---|---|
| `SoftBlue` | shared/informational summary cards |
| `SoftGreen` | automatic/success summary cards |
| `SoftAmber` | decision/warning summary cards |
| `SoftRed` | unsupported/error summary cards |
| `SoftGray` | neutral secondary panels |

### Fix Lab and workflow cards

| Key | Usage |
|---|---|
| `FixHeaderBackground`, `FixHeaderBorder` | Fix Lab header |
| `NoticeBackground`, `NoticeBorder` | ordinary action-required popup |
| `DecisionNoticeBackground`, `DecisionNoticeBorder`, `DecisionNoticeHeading` | human decision popup |
| `SourceBackground`, `SourceBorder` | repair-source section |
| `ConfigureBackground`, `ConfigureBorder` | repair-configuration section |
| `BuildBackground`, `BuildBorder` | build/repair section |
| `OutputBackground`, `OutputBorder` | output/success section |
| `BackupBackground`, `BackupBorder` | backup/restore section |
| `AdvancedBackground` | advanced section |
| `AccentHeadingBlue` | source/information heading |
| `AccentHeadingAmber` | warning/configuration heading and normal popup title |
| `AccentHeadingPurple` | build/processing heading |
| `AccentHeadingGreen` | success/output heading and detected Palworld status |
| `WarmHeading` | backup/history heading |

### Generic buttons

| Key | Usage |
|---|---|
| `ButtonBackground` | normal generic button |
| `ButtonHover` | hovered generic button |
| `ButtonForeground` | generic button text |
| `ButtonBorder` | generic button border |

The AI & Help editor exposes every named palette and ColorFlow brush with a required fallback color. Remaining non-theme layout resources are deliberately outside the scheme contract.

## ColorFlow contract

Each state has:

- `Border`: used as the fully highlighted guided-action button background and border. The text is white.
- `Progress`: used in the remaining/uncompleted portion of a button while work is running. The text is `PrimaryText`.

This means a Night theme normally needs **dark** Progress values, even if bright pastel progress colors seem more colorful. A Light theme normally needs **light** Progress values. Validate both pairs independently.

States are `Import`, `Analyze`, `Build`, `Deploy` and `Play`.

## Required contrast checks

Use WCAG relative-luminance contrast calculations. PMM's normal text is commonly 11–13 px, so treat 4.5:1 as the minimum rather than relying on large-text exceptions.

### Hard requirements

1. `PrimaryText` against every background where normal text can appear: at least **4.5:1**.
2. `MutedText` against those same surfaces: at least **4.5:1**.
3. `ButtonForeground` against `ButtonBackground` and `ButtonHover`: at least **4.5:1**.
4. `SelectionText` against `SelectionBackground`: at least **4.5:1**.
5. `DecisionNoticeHeading` against `DecisionNoticeBackground`: at least **4.5:1**.
6. Each accent heading against its corresponding section background: at least **4.5:1**.
7. White (`#FFFFFF`) against every ColorFlow `Border`: at least **4.5:1**.
8. `PrimaryText` against every ColorFlow `Progress`: at least **4.5:1**.
9. `AccentHeadingGreen` against `ButtonBackground`: at least **4.5:1**, because detected Palworld status can use this pair.
10. Disabled/composited control text: target at least **3:1**.

For two colors with relative luminances `L1` and `L2`, where `L1` is lighter:

```text
contrast = (L1 + 0.05) / (L2 + 0.05)
```

Do not calculate contrast from HSL lightness or the average RGB value; those are not perceptual luminance.

## Disabled-state trap

In RC23, disabled buttons are rendered with 50% opacity. The displayed foreground and background are therefore composites with the parent surface:

```text
displayedForeground = 0.5 × foreground + 0.5 × parentBackground
displayedButton      = 0.5 × buttonBackground + 0.5 × parentBackground
```

Calculate contrast using the displayed/composited colors. A raw pair can pass 7:1 and still become weak after both layers are faded toward the same parent.

Recommended authoring practice until the core disabled style is improved:

- Light theme: use a very light button with nearly black `ButtonForeground`; use a very dark green detected-status color.
- Night theme: use a dark button with white `ButtonForeground`; use a light mint/green detected-status color.
- Avoid saturated mid-tone generic buttons when another semantic foreground may be placed over them.

## A reliable design method

### 1. Choose Light or Night first

Do not mix a dark Header with light Cards if both use the same `PrimaryText`. PMM currently has one primary-text resource across both. Keep all major surfaces in the same luminance family.

### 2. Build the neutral skeleton

Choose, in order:

1. `AppBackground`;
2. `CardBackground` and `CardAltBackground`;
3. `HeaderBackground`;
4. `PrimaryText` and `MutedText`;
5. input, border, grid and status colors.

Validate this skeleton before adding decorative colors.

### 3. Design buttons as controls, not decorations

Check normal, hover, disabled, detected-status and guided-action states. A button color that only works with its own foreground is insufficient.

### 4. Add semantic families

Use related but distinguishable surface tints for blue/information, green/success, amber/decision, red/unsupported and purple/build. The text resources still need to pass on every one.

### 5. Design ColorFlow last

For each state, check both white-on-Border and PrimaryText-on-Progress. Ensure Progress also remains visually distinguishable from `CardAltBackground`.

### 6. Test the real application

At minimum inspect:

- header with Palworld detected and not detected;
- enabled and disabled generic buttons;
- Mod Library alternating and selected rows;
- action-required popup;
- five analysis summary cards;
- Fix Lab source/configure/build/output/backups sections;
- ColorFlow idle, guided and running-progress states;
- combo boxes and dropdown selection;
- English and Spanish labels;
- 1060×700, intermediate width and maximized window.

## PMM Crystal as a worked example

The complete file is included as `PMM_COLOR_SCHEME_PMM_CRYSTAL.json`.

Its method is:

- dark navy surfaces (`#081522`, `#0D1B2A`, `#12263A`);
- near-white primary text (`#F2F8FF`);
- clearly lighter muted text (`#B6C7D8`), still high-contrast on every dark semantic card;
- a dark blue generic button (`#153B59`) with white text;
- a light mint detected/success heading (`#91E0C6`) that remains visible on the button;
- dark ColorFlow Progress values so light PrimaryText remains readable;
- darker ColorFlow Borders so white guided-action text remains readable.

The important lesson is not to copy those exact hex values. Copy the relationship between surface, text, semantic accent and state.

## AI generation instructions

An AI creating a PMM scheme should receive:

- this guide;
- the formal JSON schema;
- a complete known-good example such as PMM Crystal;
- the requested visual inspiration;
- whether Light or Night is preferred;
- the required contrast threshold;
- any reference images selected by the user.

The AI should return only theme design data: JSON, optional declared images, a response manifest and notes. It must not return executable scripts as part of a theme package.

Before returning a result, the AI should report:

- the chosen base;
- the intended visual concept;
- the minimum contrast ratio found and its pair;
- whether disabled-state composition was tested;
- whether all 46 palette keys and ten ColorFlow values are present;
- any warnings that still require a real PMM preview.

## Images on every editable brush in V2

Every editor row that exposes a color also exposes **Upload image**. This applies to surfaces, text/foreground, borders, selection, buttons, semantic headings and ColorFlow resources. The editor lives only in **AI & Help / IA y ayuda -> Color scheme editor**.

Always keep the solid palette color as fallback and optional overlay/tint. Test sampled darkest/lightest regions after the overlay, and keep images local to the theme pack—no URLs or absolute paths.

An image-filled text or thin border can be technically valid but unreadable. Show it in the live preview and require the same contrast/interaction checks. Offer fit/tile/alignment/opacity and Remove image controls on the same row. A theme may target only named PMM brush resources; it must never identify or inject arbitrary WPF controls.

V2 uses the same `palette` and `colorFlow` fallback colors as V1 plus a `brushes` object keyed by the exact palette key or `ColorFlow.<State>.<Part>`. Each image entry declares `type: image`, a relative `assets/...` PNG/JPEG path, SHA-256, dimensions, stretch, alignment, tile mode, opacity and overlay. Export packages use `PMM_THEME_PACK_V1`; detached V2 JSON is rejected because its assets cannot be validated with it.

## Final author checklist

- [ ] Unique, sanitized ID.
- [ ] Correct V1/V2 schema and Light/Night base.
- [ ] All 46 palette keys present for an official theme.
- [ ] All five ColorFlow states include Progress and Border.
- [ ] Every color parses.
- [ ] Primary and muted text pass every relevant surface.
- [ ] Buttons pass normal, hover, disabled and detected states.
- [ ] Selection and popup states pass.
- [ ] ColorFlow Border and Progress pairs pass.
- [ ] Real WPF preview checked in both languages and several window sizes.
- [ ] No external paths, code or unlicensed assets in the package.
- [ ] V2 images are packaged locally, hash-matched, no larger than 8 MiB each, no larger than 4096×4096 or 32 megapixels.
