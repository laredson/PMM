# PMM `info` branch

This branch is a compact, persistent context store for Palworld Manager Merger development.

It is **not an application branch and must not be merged into `main` or development branches**. The code authority always lives in the active development branch and the stable authority lives in `main`.

## Snapshot policy

- `initial/` preserves the useful context from the old `info` branch before it was repurposed.
- Every meaningful context update creates a **new immutable timestamp folder** using `YYYY-MM-DD_HH-mm` in the maintainer's local time.
- The newest timestamp folder is the current project-context snapshot.
- Older folders are retained while useful. They may be deleted from the current tree during cleanup when they become redundant; Git history still preserves earlier commits unless history is explicitly rewritten.
- Do not update this branch for every prompt. Update it at meaningful milestones: accepted builds, architectural decisions, major discoveries, release/handoff boundaries, or when changing the active development focus.

## Keep this branch small

Store concise Markdown/JSON context only. Do **not** store PAKs, cooked Palworld assets, Game Reference payloads, Workspace archives, saves, logs, screenshots, credentials, binaries, or large generated artifacts here.

## How a new AI/developer should use it

1. Read the newest timestamp folder in this branch.
2. Follow the exact branch/commit references recorded there.
3. Treat that referenced application branch as source authority.
4. Use older snapshot folders only for history or rationale.
