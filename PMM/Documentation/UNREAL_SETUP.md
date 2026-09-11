# Optional modding tools / Herramientas opcionales

- [Tutorial en español](UNREAL_SETUP.es.md)
- [English tutorial](UNREAL_SETUP.en.md)

PMM funciona sin Unreal, Wwise ni Python instalado por separado para sus herramientas propias de inspección, extracción, edición compatible y reempaquetado. El entorno opcional sirve para trabajos que necesitan el editor y el cocinador. Wwise se necesita para las dependencias AkAudio del kit completo utilizado, no para cualquier mod.

PMM's own inspection, extraction, supported editing and repacking tools work without Unreal, Wwise or a separate Python installation. The optional environment supports work requiring the editor and cooker. Wwise satisfies the full kit's AkAudio dependencies; it is not a requirement for every mod.

## Status / Estado — 2026-09-09

Las dependencias del equipo de preparación fueron detectadas. Esto no certifica compilación, cocinado ni funcionamiento en Palworld. El adaptador permanece desactivado por defecto y requiere comprobación real de proyecto. El mod de inventario de 100 espacios adicionales sigue sin validación en juego.

Dependencies were detected on the preparation machine. Compilation, cooking and Palworld behavior are not certified. The adapter stays disabled by default and requires a real project check. The additional-100-inventory-slots mod has not passed in-game validation.

## Portable configuration

The pinned profile is [profile.json](../Resources/Unreal/profile.json). [settings.example.json](../Resources/Unreal/settings.example.json) documents empty path overrides; installed components are detected locally. Do not publish Workspace/settings, account data, installer consent or absolute machine paths.

## Personal offline backup

Maintainer-only backup: private repository PMM-setup-backup, release setup-2026-09-09. Access requires the owner's GitHub account or explicitly granted repository access. It is not part of the public PMM download and does not grant redistribution rights.

The archive preserves downloaded packages, not complete installed applications. Read the language-specific tutorial before restoring. [Restore-OfflineBackup.ps1](../Resources/Unreal/Restore-OfflineBackup.ps1) verifies the downloaded archive and every inventoried file before restoring missing files. It does not execute installers.
