# PMM Protocol Design

## Merge identity

Two users can validate the same merge even if one has 109 mods and another has 34. The primary identity is the effective conflicting mod set, affected assets/properties, relevant precedence, and normalized generated result.

If order cannot change the normalized result, `orderSemantics.relevant=false`. If it can, store the effective order.

Other mods are evidence context. If failures correlate with a previously unrelated mod, PMM can later create a special-case or competing knowledge entry.

## Evidence strength

Runtime evidence and functional evidence are separate.

`gameStarted`, `mainMenuReached`, `worldLoadDetected`, runtime duration, crashes and merge-related log errors can be detected automatically.

“No crash detected” means only “no evidence of runtime failure”. It must not equal “mod behavior confirmed”.

New-world evidence is explicitly tracked because the current merge/mod state is known from world creation onward and therefore can provide stronger evidence than an old world with unknown historical mod state.

Negative reports are never deleted. `alternative-worked` can point to a competing knowledge entry.

## Promotion

Promotion thresholds live outside the schema in policy. Suggested starting values are in `knowledge-policy.example.json`.

Count independent installations, not raw clicks. Repeated reports from one installation must not count as many independent users.

Experimental knowledge must pass structural and safety checks before broad testing. Stable requires materially stronger runtime evidence and no unresolved severe negatives.

## Update model

PMM binary and Knowledge Library update independently.

PMM:
- stable
- beta
- community

Knowledge:
- stable
- experimental

A developer branch is not directly executable by clients. CI converts a branch/PR into a versioned artifact, hashes it, signs the manifest, and publishes it to the appropriate channel. This preserves community builds without turning mutable Git branches into remote-code execution.

Knowledge bundles declare PMM/schema compatibility. A newer KL can require a newer PMM.

## Update verification

Recommended manifest signing: Ed25519.

Signature input: RFC 8785 JCS canonical JSON of the manifest with the `signature` object omitted.

Client flow:
1. optionally check for updates;
2. verify manifest signature;
3. verify compatibility;
4. download to staging;
5. verify size and SHA-256;
6. validate package/schema;
7. preserve current version;
8. activate/install;
9. health check;
10. rollback on failure.

The user's first-run choice to skip updates must always permit local execution.

## Privacy

Never send raw username, Steam ID, machine GUID, full local path, save contents, or credentials.

For deduplication, use a locally generated random installation secret/UUID and derive a one-way anonymous fingerprint.
