"""Offline checks: no application import, network, hardware, or dependency install."""
import ast
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
counts = {"python": 0, "json": 0, "shell": 0}
for p in ROOT.rglob("*"):
    if not p.is_file() or any(x in p.parts for x in (".git", "node_modules", ".next")):
        continue
    if p.suffix == ".py":
        ast.parse(p.read_text(), filename=str(p))
        counts["python"] += 1
    elif p.suffix == ".json":
        json.loads(p.read_text())
        counts["json"] += 1
    elif p.suffix == ".sh":
        subprocess.run(["bash", "-n", str(p)], check=True)
        counts["shell"] += 1
    try:
        text = p.read_text()
    except UnicodeDecodeError:
        continue
    for pattern in (r"\b\d{8,12}:[A-Za-z0-9_-]{30,}\b", r"\bsk-[A-Za-z0-9_-]{16,}\b", r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"):
        assert not re.search(pattern, text), f"Potential credential: {p.relative_to(ROOT)}"

# Extract reviewed pure functions only, avoiding camera and network initialization.
module = ast.parse((ROOT / "02_jetson_nano_ai_node/main.py").read_text())
selected = []
for node in module.body:
    if isinstance(node, ast.FunctionDef) and node.name in ("norm_label", "analyze_detections"):
        selected.append(node)
    elif isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "DIRECT_DANGER_MAP" for t in node.targets):
        selected.append(node)
ns = {}
exec(compile(ast.Module(body=selected, type_ignores=[]), "reviewed_pure_functions", "exec"), ns)
analyze = ns["analyze_detections"]
def det(label, confidence):
    return {"class": label, "conf": confidence, "bbox": [0, 0, 10, 10]}
assert analyze([], {"fire": .4}) == []
assert analyze([det("fire", .39)], {"fire": .4}) == []
assert analyze([det("fire", .4)], {"fire": .4})[0]["alert_name"] == "fire"
assert analyze([det("fire", .9)], {"fire": 0}) == []
assert analyze([det("head", .9)], {"hardhat": .35})[0]["alert_name"] == "no_helmet"
assert analyze([det("head", .9), det("helmet", .9)], {"hardhat": .35}) == []
assert analyze([det("helmet", .9)], {"vest": .35})[0]["alert_name"] == "no_vest"
assert analyze([det("helmet", .9), det("Safety_vest", .9)], {"vest": .35}) == []
print(json.dumps({"status": "PASS", "syntax": counts, "pure_logic_cases": 8, "credential_patterns": 3}, indent=2))
