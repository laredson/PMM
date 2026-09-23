# Development tools

## Repository index

Run from any location inside a local clone:

```
python Development/Tools/build_repo_index.py
```

Outputs are local-only under `.pmm-index/` and are ignored by Git.

The index exists to make large-repository navigation deterministic for Codex/developers without depending on GitHub Code Search indexing.

Generated files:
- `repo.json`: file inventory, classifications and lightweight signals;
- `symbols.json`: PowerShell/Go symbols;
- `processes.json`: process/network/ExecutionPolicy/executable references;
- `references.json`: path-like references and broken-reference candidates;
- `summary.md`: human-readable counts/warnings.

Check whether an existing index matches the checked-out HEAD:

```
python Development/Tools/build_repo_index.py --check
```

The generator uses only the Python standard library and `git`. It never accesses the network or edits PMM product files.
