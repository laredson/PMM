# Color schemes and sound events

PMM 1.3 RC30 gives color schemes the same ownership model as sounds:

- **Official PMM schemes** are release resources. Eleven hash-pinned JSON schemes plus legacy Night and Light are always shown in the official area. PMM Crystal is the fresh-install and Restore-defaults choice.
- **Added user schemes** live only in `Workspace\Themes`, appear in a separate bordered collection, and use **Add scheme** / **Open schemes folder** controls. They cannot replace or shadow official IDs.

Settings accepts one or several `PMM_COLOR_SCHEME_V1` JSON files, or a bounded ZIP containing V1 definitions. Import validates the whole selection before committing, asks before replacing a different user definition and backs up the previous file. A damaged or incomplete PMM definition blocks the batch instead of being ignored.

The **AI & Help > Color scheme editor** can copy any installed source into a persistent draft. Every palette and ColorFlow brush has a fallback color plus **Upload image**, image options and Remove image. PNG/JPEG assets are copied into the draft; URLs, absolute paths and external references are forbidden. Solid themes export as V1 JSON. Image-backed themes use `PMM_COLOR_SCHEME_V2` inside a self-contained `PMM_THEME_PACK_V1` ZIP. Local install validates the complete asset set and then places it under user schemes.

Creating a theme with AI is also offline: PMM prepares a ZIP, and an imported AI response becomes an editable draft only. It is never installed automatically.

All schemes must pass PMM's real-surface 4.5:1 contrast matrix. Invalid user definitions are skipped at startup; PMM falls back to PMM Crystal and then to the hard-coded Night emergency palette without changing the saved selection.

## Sound event profiles

- **Auto**: once when the complete automatic workflow ends.
- **Semiauto**: after each completed AUTO/Auto ON step when enabled.
- **Manual**: after a manually started workflow action; Start Palworld alone is silent.
- **Attention required**: deduplicated notification for a real human decision.
- **Error**: operation-error alert.

Built-in sounds remain in the top row. WAV/MP3/WMA files added by the user live in `Workspace\Sounds` and appear in the bordered custom list. Defaults are Auto = Microwave finish, Semiauto = OK, Manual = Good, Attention = Short alert and Error = 3 beeps, with 50% volume.

Determinate progress bars interpolate proven progress below completion without exceeding the worker's real value. A confirmed 100% update always jumps immediately to 100 and cancels pending animation before the next task starts.
