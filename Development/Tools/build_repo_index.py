#!/usr/bin/env python3
"""Build a local PMM repository index for Codex/developer navigation.

Standard-library only. Reads tracked files from the current Git checkout and
writes local generated data under .pmm-index/. It does not access the network
or modify tracked project/product files.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / ".pmm-index"

TEXT_EXTENSIONS = {
    ".md", ".txt", ".json", ".ps1", ".psm1", ".psd1", ".go", ".py",
    ".cs", ".csproj", ".sln", ".xaml", ".xml", ".yml", ".yaml", ".toml",
    ".cmd", ".bat", ".ini", ".config", ".mod", ".sum", ".patch",
}
MAX_TEXT_BYTES = 4 * 1024 * 1024

PS_FUNCTION = re.compile(r"(?mi)^\s*function\s+([A-Za-z_][\w-]*)")
GO_FUNCTION = re.compile(r"(?m)^\s*func\s+(?:\([^\n)]*\)\s*)?([A-Za-z_]\w*)\s*\(")
GO_TYPE = re.compile(r"(?m)^\s*type\s+([A-Za-z_]\w*)\s+")
URL_RE = re.compile(r"https?://[^\s\"'<>]+", re.I)
EXE_RE = re.compile(r"(?i)(?:^|[^A-Za-z0-9_.-])([A-Za-z0-9_.-]+\.exe)(?:$|[^A-Za-z0-9_.-])")
PATH_RE = re.compile(
    r"(?i)(?:Development|PMM|Modules|Resources|CKL|Documentation|Engine|Workspace)"
    r"(?:[\\/][A-Za-z0-9_.() +@#-]+)+"
    r"(?:\.(?:md|json|ps1|psm1|go|py|cs|xaml|txt|exe|dll|toml|yml|yaml|usmap))?"
)


def git(*args: str) -> str:
    p = subprocess.run(
        ["git", *args],
        cwd=ROOT,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if p.returncode:
        raise RuntimeError("git " + " ".join(args) + " failed: " + p.stderr.strip())
    return p.stdout.strip()


def classify(rel: str) -> str:
    low = rel.lower()
    if rel.startswith("Development/Handoff/"):
        return "continuity"
    if rel == "START_HERE_NEW_PROJECT.md" or rel == "AGENTS.md":
        return "continuity"
    if "/evidence/" in low or "checks.json" in low:
        return "evidence"
    if "findings.md" in low or "history" in low or "decision_transcript" in low:
        return "history"
    if rel.startswith("Development/Reliability/NativeCandidates/"):
        return "candidate"
    if rel.startswith("Development/Source/"):
        return "source-snapshot"
    if rel.startswith("Development/Tests/") or "_test.go" in low or "regression" in low:
        return "test"
    if rel.startswith("Development/"):
        return "development"
    if rel.startswith("PMM/"):
        return "product"
    if rel.startswith(".github/"):
        return "repository-infra"
    return "repository"


def authority(rel: str) -> str:
    if rel in {
        "Development/Handoff/CURRENT_HANDOFF.md",
        "Development/Handoff/CURRENT_STATE.json",
        "Development/Reliability/V1502_SINGLE_EXE_AND_NOFLAG_PLAN.md",
        "Development/Reliability/STATUS.md",
        "Development/Reliability/NEXT_SESSION.md",
    }:
        return "current"
    if rel.startswith("PMM/"):
        return "distributed-product"
    if rel.startswith("Development/Reliability/NativeCandidates/"):
        return "candidate-not-automatically-distributed"
    if rel.startswith("Development/Source/"):
        return "snapshot-requires-reconciliation"
    if "FINDINGS" in rel or "CHECKS" in rel or "/evidence/" in rel:
        return "historical-evidence"
    return "supporting"


def is_text(path: Path) -> bool:
    return path.suffix.lower() in TEXT_EXTENSIONS or path.name in {
        ".gitignore", ".gitattributes", "LICENSE"
    }


def read_text(path: Path) -> str | None:
    try:
        if path.stat().st_size > MAX_TEXT_BYTES or not is_text(path):
            return None
        return path.read_text(encoding="utf-8-sig", errors="replace")
    except OSError:
        return None


def path_candidates(raw: str) -> list[str]:
    value = raw.replace("\\", "/").strip(" .,:;()[]{}'\"")
    if value.startswith("repository "):
        value = value[len("repository "):]
    if not value or "://" in value or "<" in value or ">" in value or "*" in value:
        return []
    out = [value]
    if not value.startswith("PMM/"):
        out.append("PMM/" + value)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="only verify that the local index matches HEAD")
    args = ap.parse_args()

    head = git("rev-parse", "HEAD")
    if args.check:
        state = OUT / "repo.json"
        if not state.exists():
            print("PMM_INDEX_STALE missing")
            return 2
        try:
            data = json.loads(state.read_text(encoding="utf-8"))
        except Exception:
            print("PMM_INDEX_STALE unreadable")
            return 2
        if data.get("head") != head:
            print("PMM_INDEX_STALE head-mismatch")
            return 2
        print("PMM_INDEX_OK " + head)
        return 0

    tracked = [x for x in git("ls-files").splitlines() if x]
    tracked_set = set(tracked)
    files = []
    symbols = []
    processes = []
    references = []
    counts = Counter()
    category_counts = Counter()

    for rel in tracked:
        path = ROOT / rel
        try:
            size = path.stat().st_size
        except OSError:
            size = -1
        cat = classify(rel)
        auth = authority(rel)
        suffix = path.suffix.lower() or "<none>"
        counts[suffix] += 1
        category_counts[cat] += 1
        text = read_text(path)
        row = {
            "path": rel,
            "size": size,
            "extension": suffix,
            "category": cat,
            "authority": auth,
            "textIndexed": text is not None,
        }
        if text is not None:
            schemas = sorted(set(re.findall(r'(?i)"schema"\s*:\s*"([^"]+)"', text)))
            urls = sorted(set(URL_RE.findall(text)))
            exes = sorted(set(m.group(1) for m in EXE_RE.finditer(text)))
            flags = []
            low = text.lower()
            if "executionpolicy" in low and "bypass" in low:
                flags.append("execution-policy-bypass")
            if "start-process" in low:
                flags.append("powershell-start-process")
            if "exec.command" in low:
                flags.append("go-exec-command")
            if "subprocess.run" in low or "subprocess.popen" in low:
                flags.append("python-subprocess")
            if "invoke-webrequest" in low or "httpclient" in low or "webclient" in low or urls:
                flags.append("network-capable")
            if schemas:
                row["schemas"] = schemas
            if exes:
                row["executables"] = exes
            if flags:
                row["signals"] = sorted(set(flags))

            ps = sorted(set(PS_FUNCTION.findall(text))) if suffix in {".ps1", ".psm1"} else []
            gf = sorted(set(GO_FUNCTION.findall(text))) if suffix == ".go" else []
            gt = sorted(set(GO_TYPE.findall(text))) if suffix == ".go" else []
            if ps or gf or gt:
                symbols.append({"path": rel, "powershellFunctions": ps, "goFunctions": gf, "goTypes": gt})

            if exes or flags or urls:
                processes.append({
                    "path": rel,
                    "executables": exes,
                    "signals": sorted(set(flags)),
                    "urls": urls,
                })

            seen_refs = set()
            for raw in PATH_RE.findall(text):
                normalized = raw.replace("\\", "/").strip()
                if normalized in seen_refs:
                    continue
                seen_refs.add(normalized)
                candidates = path_candidates(normalized)
                resolved = next((x for x in candidates if x in tracked_set), None)
                references.append({
                    "source": rel,
                    "reference": normalized,
                    "resolved": resolved,
                    "brokenCandidate": resolved is None and not normalized.startswith("Workspace/"),
                })

        files.append(row)

    OUT.mkdir(parents=True, exist_ok=True)
    repo_index = {
        "schema": "PMM_LOCAL_REPOSITORY_INDEX_V1",
        "head": head,
        "trackedFiles": len(tracked),
        "countsByExtension": dict(sorted(counts.items())),
        "countsByCategory": dict(sorted(category_counts.items())),
        "files": files,
    }
    (OUT / "repo.json").write_text(json.dumps(repo_index, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (OUT / "symbols.json").write_text(json.dumps({"schema":"PMM_LOCAL_SYMBOL_INDEX_V1","head":head,"items":symbols}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (OUT / "processes.json").write_text(json.dumps({"schema":"PMM_LOCAL_PROCESS_INDEX_V1","head":head,"items":processes}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    broken = [x for x in references if x["brokenCandidate"]]
    (OUT / "references.json").write_text(json.dumps({"schema":"PMM_LOCAL_REFERENCE_INDEX_V1","head":head,"items":references}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    summary = [
        "# PMM local repository index",
        "",
        f"HEAD: `{head}`",
        f"Tracked files: {len(tracked)}",
        "",
        "## Categories",
        "",
    ]
    for key, value in sorted(category_counts.items()):
        summary.append(f"- {key}: {value}")
    summary += [
        "",
        "## Navigation signals",
        "",
        f"- symbol-bearing files: {len(symbols)}",
        f"- process/network signal files: {len(processes)}",
        f"- path references: {len(references)}",
        f"- unresolved path-reference candidates: {len(broken)}",
        "",
        "Unresolved candidates are navigation warnings, not automatically defects.",
        "Workspace paths and dynamic/generated paths may intentionally not exist in Git.",
        "",
    ]
    (OUT / "summary.md").write_text("\n".join(summary), encoding="utf-8")
    print(f"PMM_INDEX_OK head={head} files={len(tracked)} brokenCandidates={len(broken)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
