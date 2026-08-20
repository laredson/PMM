# Git Setup for PMM

Copy these support files into the repository root, then run:

```bash
git add .gitattributes .gitignore
git add --renormalize .
git status
```

Review all changes, then:

```bash
git add .
git commit -m "Prepare PMM repository"
```

## Recommended GitHub settings

- protect `main`;
- require pull requests;
- require status checks before merge;
- prevent force pushes;
- enable branch deletion after merge;
- enable security alerts;
- use GitHub Releases for binaries.

## Branch model

- `main`: stable/releasable source
- feature/fix/knowledge branches for work
- tags/releases for distributable versions

Do not use arbitrary branches as application update sources.
