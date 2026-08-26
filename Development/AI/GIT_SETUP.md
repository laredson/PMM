# Git Setup for PMM

## Recommended layout

The repository root should contain only:

- `PMM/`
- `Development/`
- `.github/`
- `.gitignore`
- `.gitattributes`
- `README.md`
- `LICENSE`

## Initial commit

From the repository root:

```bash
git add .
git status
git commit -m "release: establish PMM 1.2.1 Guided Flow baseline"
```

Tag the public stable point only after validating the uploaded tree:

```bash
git tag -a v1.2.1 -m "Palworld Manager Merger 1.2.1"
git push origin main --tags
```

## Recommended branch model

- `main`: stable/releasable source and packaged application tree.
- `dev/1.3-fixlab`: active Fix Lab development.
- short-lived `fix/*` or `feature/*` branches only when useful.

For the next line:

```bash
git switch -c dev/1.3-fixlab
```

## GitHub settings

Recommended:

- protect `main`;
- require pull requests/status checks when working with collaborators;
- prevent force pushes to `main`;
- allow branch deletion after merge;
- use GitHub Releases for user ZIPs;
- never use the repository itself as storage for user Workspace data or third-party mod assets.

## ChatGPT / AI workflow

Git remains the source of truth. Chat conversations are not version control.

Every AI/developer should first read `Development/AI/CURRENT_STATE.md`, inspect the current branch and recent commits, then make changes against that state. A ChatGPT GitHub connection can be used to read/analyze the repository; an environment with repository write access can commit/push through the same normal Git branch workflow.
