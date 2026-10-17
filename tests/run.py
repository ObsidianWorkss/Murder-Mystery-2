"""Test current bundled combat code using the standalone Luau CLI."""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
source = (root / "main.lua").read_text(encoding="utf-8")
template = (root / "tests" / "combat.luau").read_text(encoding="utf-8")
sections = {
    "STAB": ("function State.SelectStabAssistTarget()", "local function knifeFeedback(message)"),
    "THROW": ("local function knifeFeedback(message)", "local function takeOver(item)"),
    "GUN": ("local function sendGun(record, preferred, strict)", "local installAuraTouch=function(C)"),
}
for name, (start, end) in sections.items():
    code = source[source.index(start):source.index(end, source.index(start))]
    if name == "GUN":
        code = code[:code.rindex("\ndo\n")]
    template = template.replace("-- INSERT_" + name, code)
with tempfile.TemporaryDirectory(prefix="mm2-combat-") as directory:
    harness = Path(directory) / "combat.luau"
    harness.write_text(template, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True)
