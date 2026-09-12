"""Read the modular WPF shell as one source stream without executing it."""
from pathlib import Path
import re

_INCLUDE = re.compile(
    r"^[ \t]*\.\s+\(Join-Path\s+\$Script:Root\s+'"
    r"(?P<relative>Modules[\\/](?:Presentation|Workflow)[\\/][A-Za-z0-9_.-]+\.ps1)"
    r"'\)[ \t]*\r?$",
    re.MULTILINE,
)

def read_source(path: Path, app_root: Path) -> str:
    root = Path(app_root).resolve()
    active: set[Path] = set()

    def visit(file: Path) -> str:
        file = file.resolve()
        file.relative_to(root)
        if file in active:
            raise ValueError(f"Cyclic test source include: {file}")
        active.add(file)
        try:
            source = file.read_text(encoding="utf-8-sig")
            return _INCLUDE.sub(
                lambda match: visit(root / match["relative"].replace("\\", "/")).rstrip("\r\n"),
                source,
            )
        finally:
            active.remove(file)

    return visit(Path(path))
