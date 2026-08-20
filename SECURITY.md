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
