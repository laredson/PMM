# Decisions and guardrails

## Repository roles

- `main`: stable application authority.
- `1.3.1-mod-creation`: current application development.
- `info`: compact persistent project context only. Never treat `info` as application source and never merge it into an application branch.

## Context-storage policy

- Each meaningful `info` update is written as a new timestamped folder.
- Snapshot folders are immutable after creation except to correct a serious factual error.
- Do not create a snapshot for every conversation turn or trivial edit.
- Prefer one snapshot per accepted milestone, major design decision, release/handoff boundary, or meaningful failure/lesson.
- Small application changes should be grouped into coherent commits on the application branch; the `info` snapshot only summarizes the accepted result.
- Keep context files concise. Git history plus timestamp folders provide rollback/history; redundant old folders may be cleaned later if the visible tree becomes noisy.

## Never store in `info`

Workspace archives, Game Reference payloads, Palworld cooked assets, user/mod PAKs, saves, logs, screenshots, credentials, generated binaries, or other large/transient artifacts.

## Application guardrails

- `PMM/` is the runnable authority for the active 1.3.1 branch.
- Do not replace packaged native executables using the older/incomplete native source snapshot without source/binary reconciliation and Windows acceptance.
- Preserve compatibility-merge, Fix Lab and deployment ownership boundaries while changing standalone mod creation.
- AIIO input/output is untrusted data; no automatic returned-code execution, deploy, publish or Knowledge promotion.
- Standalone created mods remain runtime `UNPROVEN` until exact gameplay testing succeeds.

## Project/chat hygiene

Use GitHub as the durable project memory. Upload to ChatGPT only the material needed for the current task. Avoid accumulating repeated full PMM packages, workspaces, screenshots and historical handoff ZIPs inside the project when GitHub can carry the durable context instead.
