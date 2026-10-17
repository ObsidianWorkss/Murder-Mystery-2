"""Test current bundled combat code using the standalone Luau CLI."""
import argparse
from pathlib import Path
import subprocess
import tempfile
import shutil

parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
args = parser.parse_args()
if not shutil.which(args.luau):
    parser.error("Luau executable not found. Pass --luau /path/to/luau.")
root = Path(__file__).resolve().parent.parent
source = (root / "main.lua").read_text(encoding="utf-8")
template = (root / "tests" / "combat.luau").read_text(encoding="utf-8")
sections = {
    "MOTION": ("local function sampleMotion(", "connect(Players.PlayerRemoving, function(other) State.Motion[other] = nil end)"),
    "PREVIEW": ("function State.GetCachedAimPreview(", "-- This executor cannot hook the live script's module cache."),
    "AIMPOINT": ("local function aimPoint(", "\ndo\n-- Predict only other players' possible ray obstruction"),
    "TIMING": ("local function gunTimingCoverage(", "local function exposedSolution("),
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
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)
    release = (root / "tests" / "release.luau").read_text(encoding="utf-8")
    start = source.index("function State.GetSupportSnapshot()")
    end = source.index('if State.Config.ESPStyleVersion', start)
    release = release.replace("-- INSERT_SUPPORT", source[start:end])
    release = release.replace("-- INSERT_LOADER", (root / "loader.lua").read_text(encoding="utf-8"))
    start = source.index("local installRoleReveal=function(C)")
    end = source.index("installRoleReveal({", start)
    release = release.replace("-- INSERT_REVEAL", source[start:end])
    start = source.index("local installMovement=function(C)")
    end = source.index("installMovement({", start)
    release = release.replace("-- INSERT_MOVEMENT", source[start:end])
    start = source.index("local installXRay=function(C)")
    end = source.index("installXRay({", start)
    release = release.replace("-- INSERT_XRAY", source[start:end])
    start = source.index("    local animationPacks = {")
    end = source.index("\n", source.index('State.Config.AnimationPack = "Mage" end', start))
    release = release.replace("-- INSERT_PACKS", source[start:end])
    start = source.index("local installKeybinds=function(C)")
    end = source.index("installKeybinds({", start)
    release = release.replace("-- INSERT_KEYBINDS", source[start:end])
    if "-- INSERT_" in release or "-- INSERT_" in template:
        raise RuntimeError("Unexpanded regression-test source marker")
    harness.write_text(release, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)
    trigger = (root / "tests" / "triggerbot.luau").read_text(encoding="utf-8")
    start = source.index("local installTriggerbot=function(C)")
    end = source.index("installTriggerbot({", start)
    trigger = trigger.replace("-- INSERT_TRIGGERBOT", source[start:end])
    start = source.index("local installEmergencyStop = function(C)")
    end = source.index("installEmergencyStop({", start)
    trigger = trigger.replace("-- INSERT_EMERGENCY", source[start:end])
    if "-- INSERT_" in trigger:
        raise RuntimeError("Unexpanded triggerbot-test source marker")
    harness.write_text(trigger, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)
