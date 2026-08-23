# Security Policy

Remote content is untrusted until verified.

## Remote knowledge
- schema validate;
- allow-list file/content types;
- size-limit uploads;
- reject path traversal/archive bombs;
- never execute community content;
- keep new submissions outside the stable library until promoted.

## Application updates
- use approved release/update manifests;
- verify hashes before installation;
- require signed manifests before unattended updating;
- never install arbitrary branch contents merely because a branch exists.

## Secrets
Never commit GitHub tokens, private keys, API credentials, cloud credentials, user saves, or personal contributor data.

## Privacy
Knowledge submissions should default to anonymous. Optional attribution must be explicit.
## PMM 1.2 runtime and PowerShell policy
- PMM never attempts to force `FullLanguage`, disable App Control/AppLocker, or change system security policy.
- `PMMRuntime.exe` exists so native operations can be performed without asking untrusted PowerShell scripts for restricted .NET capabilities.
- External `Knowledge/*.json` is data, never executable code; PMMRT validates it before use.
- If Windows policy blocks the PMM executables themselves, PMM reports that as an application-control issue rather than attempting a bypass.

