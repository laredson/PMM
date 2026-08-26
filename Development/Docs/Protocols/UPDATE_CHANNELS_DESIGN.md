# PMM Update Channels Design

A Git branch is source code, not an update package.

PMM should install only validated, versioned artifacts referenced by signed manifests.

## Client settings

Recommended:

- Application update channel: `Stable | Beta`
- Knowledge channel: `Stable | Experimental`
- Automatic knowledge updates: `On | Off`
- Automatic app download: `On | Off`
- Automatic app installation: initially `Off`

## Manifest

A manifest should include version, channel, source commit, published time, artifact URL, SHA-256, size, compatibility bounds, and signature.

## Installation

1. verify signature;
2. download to staging;
3. verify size/hash;
4. sanity-check package;
5. preserve current version;
6. install atomically where possible;
7. health-check;
8. rollback on failure.
