"""Read-only MCP handshake from a non-PowerShell parent; no AI service or inference."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import uuid

repo = Path(__file__).resolve().parents[2]
fixture = repo / "Development" / "TestResults" / ("MCPBoot134-" + uuid.uuid4().hex) / "PMM"
for name in ("Modules", "Resources", "CKL"):
    shutil.copytree(repo / "PMM" / name, fixture / name)
state = fixture / "Workspace" / "MCP"
state.mkdir(parents=True)
(state / "settings.json").write_text('{"enabled":true}', encoding="utf-8")
frames = [
    {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
        "protocolVersion": "2025-11-25", "capabilities": {},
        "clientInfo": {"name": "PMM-local-regression", "version": "1.3.4"}}},
    {"jsonrpc": "2.0", "method": "notifications/initialized"},
    {"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "pmm_status", "arguments": {}}},
    {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "pmm_cases_list", "arguments": {}}},
]
powershell = Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"
proc = subprocess.run(
    [str(powershell), "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
     "-File", str(fixture / "Modules/MCP/Start-PMMMCP.ps1")],
    input="\n".join(json.dumps(frame) for frame in frames) + "\n",
    capture_output=True, encoding="utf-8", errors="replace", timeout=30)
assert proc.returncode == 0, proc.stderr
rows = [json.loads(line) for line in proc.stdout.splitlines() if line.strip()]
assert len(rows) == 3, rows
def content(identifier):
    row = next(row for row in rows if row["id"] == identifier)
    assert "error" not in row, row
    result = row["result"]
    assert not result.get("isError"), result
    return json.loads(result["content"][0]["text"])
assert Path(content(2)["installationRoot"]).resolve() == fixture.resolve()
assert content(3)["cases"] == []
print("PASS MCP boot: 4 assertions, isolated fixture, zero AI requests.")
