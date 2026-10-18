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
    "SCREEN": ("function State.IsAimPointOnScreen(", "local function visibleBodySamples("),
    "VISIBLE": ("local function visibleBodySamples(", "local function sampleRayHitsBody("),
    "MOTION": ("local function sampleMotion(", "connect(Players.PlayerRemoving, function(other) State.Motion[other] = nil end)"),
    "PREVIEW": ("function State.GetCachedAimPreview(", "-- This executor cannot hook the live script's module cache."),
    "AIMPOINT": ("local function aimPoint(", "\ndo\n-- Predict only other players' possible ray obstruction"),
    "TIMING": ("local function gunTimingCoverage(", "local function exposedSolution("),
    "STAB": ("function State.SelectStabAssistTarget(", "local function knifeFeedback(message)"),
    "THROW": ("local function knifeFeedback(message)", "local function takeOver(item)"),
    "GUN": ("local function sendGun(record, preferred, strict, onScreenOnly)", "local installAuraTouch=function(C)"),
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

    dodge = (root / "tests" / "dodge.luau").read_text(encoding="utf-8")
    start = source.index("local installKnifeDodgeLifecycle=function(C)")
    end = source.index("    local dodge = {Status", start)
    dodge = dodge.replace("-- INSERT_DODGE", source[start:end])
    start = source.index("local installEmergencyStop = function(C)")
    end = source.index("installEmergencyStop({", start)
    dodge = dodge.replace("-- INSERT_EMERGENCY", source[start:end])
    start = source.index("local installWorldTeleports=function(C)")
    end = source.index("installWorldTeleports({", start)
    dodge = dodge.replace("-- INSERT_TELEPORT", source[start:end])
    if "-- INSERT_" in dodge:
        raise RuntimeError("Unexpanded dodge-test source marker")
    harness.write_text(dodge, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)

    voting = (root / "tests" / "voting.luau").read_text(encoding="utf-8")
    start = source.index("local installMapVoteRepeat=function(C)")
    end = source.index("installMapVoteRepeat({", start)
    voting = voting.replace("-- INSERT_VOTING", source[start:end])
    start = source.index("local installEmergencyStop = function(C)")
    end = source.index("installEmergencyStop({", start)
    voting = voting.replace("-- INSERT_EMERGENCY", source[start:end])
    if "-- INSERT_" in voting:
        raise RuntimeError("Unexpanded voting-test source marker")
    harness.write_text(voting, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)

    visibility = (root / "tests" / "visibility.luau").read_text(encoding="utf-8")
    start = source.index("local installSeatVisibility=function(C)")
    end = source.index("installSeatVisibility({", start)
    visibility = visibility.replace("-- INSERT_VISIBILITY", source[start:end])
    if "-- INSERT_" in visibility:
        raise RuntimeError("Unexpanded visibility-test source marker")
    harness.write_text(visibility, encoding="utf-8")
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
    start = source.index("local installAntiFling=function(C)")
    end = source.index("installAntiFling({", start)
    release = release.replace("-- INSERT_ANTIFLING", source[start:end])
    start = source.index("        function mobile.RunKillAll(retry)")
    end = source.index('        automation:Button({Title="Kill all"', start)
    release = release.replace("-- INSERT_RUN_KILLALL", source[start:end])
    start = source.index("local installPerformancePreset=function(C)")
    end = source.index("installPerformancePreset({", start)
    release = release.replace("-- INSERT_PERFORMANCE", source[start:end])
    start = source.index("local installSettings=function(C)")
    end = source.index("installSettings({", start)
    release = release.replace("-- INSERT_SETTINGS", source[start:end])
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
    aura = (root / "tests" / "aura.luau").read_text(encoding="utf-8")
    for marker, begin, finish in [
        ("AURA", "local installKillAura=function(C)", "local function auraKnifeReady(item)"),
        ("AURA_READY", "local function auraKnifeReady(item)", "local function auraStab(item,target,part)"),
        ("AURA_STAB", "local function auraStab(item,target,part)", "installKillAura({"),
        ("AURA_CONTACT", "local function reportStabContact(record, hit, source)", "local function scanStabContacts(record)"),
    ]:
        start = source.index(begin)
        end = source.index(finish, start)
        aura = aura.replace("-- INSERT_" + marker + "\n", source[start:end] + "\n")
    if "-- INSERT_" in aura:
        raise RuntimeError("Unexpanded aura-test source marker")
    harness.write_text(aura, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)

    equip = (root / "tests" / "equip.luau").read_text(encoding="utf-8")
    start = source.index("local installWeaponEquipRecovery=function(C)")
    end = source.index("installWeaponEquipRecovery({", start)
    equip = equip.replace("-- INSERT_EQUIP", source[start:end])
    if "-- INSERT_" in equip:
        raise RuntimeError("Unexpanded equip-test source marker")
    harness.write_text(equip, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)
