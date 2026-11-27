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
    "HIT_CLASSIFIERS": ("local function isDirectBodyHit(", "local clearPath"),
    "AIM_DELAY": ("function State.AimNetworkDelay(", "local function predict("),
    "KNIFE_INTERCEPT": ("local function solveIntercept(", "local function selectMotionVelocity("),
    "MUZZLE": ("function State.GunMuzzleFollowsRig(", "local function predict("),
    "SCREEN": ("function State.IsAimPointOnScreen(", "local function visibleBodySamples("),
    "VISIBLE": ("local function visibleBodySamples(", "local function sampleRayHitsBody("),
    "RELIABLE_GUN_HELPER": ("local function reliableGunPart(", "local function hiddenBodyPart("),
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
start = source.index("local function recordUnconfirmedGun(")
end = source.index("do\n-- Saved settings:", start)
template = template.replace("-- INSERT_PENDING_ACCOUNTING", source[start:end])
with tempfile.TemporaryDirectory(prefix="mm2-combat-") as directory:
    harness = Path(directory) / "combat.luau"
    modes = (root / "tests" / "game_modes.luau").read_text(encoding="utf-8")
    for marker, begin, finish in [
        ("CONTEXT", "local createGameContext=function(C)", "local function toolFor(p, name)"),
        ("COLORS", "local colors = {Sheriff", 'local visualFolder = Instance.new("Folder")'),
        ("VISUAL_ROLE", "local function visualRoleFor(p)", "local function updateESP()"),
        ("TACTICAL", "local createTacticalPolicy = function()", "local createLearnedModel = function()"),
        ("LEARNED_POLICY", "local createLearnedPolicy = function(C)", "local installTacticalGuide = function(C)"),
        ("ESP_RUNTIME", "local colors = {Sheriff", "local threatDirections ="),
    ]:
        start = source.index(begin)
        end = source.index(finish, start)
        modes = modes.replace("-- INSERT_" + marker, source[start:end])
    if "-- INSERT_" in modes:
        raise RuntimeError("Unexpanded game-mode source marker")
    harness.write_text(modes, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)

    farm_source = (root / "auto-farm.lua").read_text(encoding="utf-8")
    farm = (root / "tests" / "auto_farm.luau").read_text(encoding="utf-8")
    start = farm_source.index("local createFarm = function(C)")
    end = farm_source.index("-- Runtime adapter.", start)
    farm = farm.replace("-- INSERT_FARM", farm_source[start:end])
    harness.write_text(farm, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)
    streamer = (root / "tests" / "streamer.luau").read_text(encoding="utf-8")
    start = source.index("local installStreamerMode=function(C)")
    end = source.index("local createStreamerSurfaces=function(C)", start)
    streamer = streamer.replace("-- INSERT_CONTROLLER", source[start:end])
    start = end
    end = source.index('local coreGui=game:GetService("CoreGui")', start)
    streamer = streamer.replace("-- INSERT_SURFACES", source[start:end])
    if "-- INSERT_" in streamer:
        raise RuntimeError("Unexpanded streamer-test source marker")
    harness.write_text(streamer, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)
    phone = (root / "tests" / "mobile.luau").read_text(encoding="utf-8")
    start = source.index("local createPhoneControls = function(C)")
    end = source.index("local createMobileUI = function(C)", start)
    phone = phone.replace("-- INSERT_PHONE", source[start:end])
    start = source.index("-- MM2 phones can start with shortcuts only;")
    end = source.index("\nend)\n\nfunction aw.EditOpenButton", start)
    phone = phone.replace("-- INSERT_WINDOW_START", source[start:end])
    harness.write_text(phone, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)
    harness.write_text(template, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)

    side = (root / "tests" / "dodge_teleport.luau").read_text(encoding="utf-8")
    start = source.index("local function finiteDodgeVector(v)")
    end = source.index("local installKnifeDodgeLifecycle=function(C)", start)
    side = side.replace("-- INSERT_SIDE_DODGE", source[start:end])
    start = source.index("    function teleportCommit.Safe(ctx,action)")
    end = source.index("    function teleportCommit.Move(ctx,point)", start)
    side = side.replace("-- INSERT_RUNTIME_SAFE", source[start:end])
    if "-- INSERT_" in side:
        raise RuntimeError("Unexpanded side-dodge source marker")
    harness.write_text(side, encoding="utf-8")
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

    lifecycle = (root / "tests" / "weapon_lifecycle.luau").read_text(encoding="utf-8")
    start = source.index("local function restoreHandler(item)")
    end = source.index("local function ready(record)", start)
    lifecycle = lifecycle.replace("-- INSERT_RESTORE", source[start:end])
    start = source.index("local function takeOver(item)")
    end = source.index("local function syncWeapons()", start)
    lifecycle = lifecycle.replace("-- INSERT_TAKEOVER", source[start:end])
    if "-- INSERT_" in lifecycle:
        raise RuntimeError("Unexpanded weapon lifecycle source marker")
    harness.write_text(lifecycle, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)

    hotkeys = (root / "tests" / "menu_hotkeys.luau").read_text(encoding="utf-8")
    start = source.index("    local function menuKey()")
    end = source.index("    local function action(callback)", start)
    hotkeys = hotkeys.replace("-- INSERT_MENU_INPUT", source[start:end])
    hotkeys = hotkeys.replace("-- INSERT_MENU_FALLBACK", source[start:end])
    if "-- INSERT_" in hotkeys:
        raise RuntimeError("Unexpanded menu keybinding source marker")
    harness.write_text(hotkeys, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)

    camera_guard = (root / "tests" / "camera_guard.luau").read_text(encoding="utf-8")
    start = source.index("    function State.CheckCameraLock()")
    end = source.index("    function State.StopCameraGuard()", start)
    camera_guard = camera_guard.replace("-- INSERT_CAMERA_GUARD", source[start:end])
    if "-- INSERT_" in camera_guard:
        raise RuntimeError("Unexpanded camera guard source marker")
    harness.write_text(camera_guard, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)

    sweeps = (root / "tests" / "weapon_sweeps.luau").read_text(encoding="utf-8")
    start = source.index("local function scanWeaponContacts()")
    end = source.index("-- Select one nearby body point for a manual click", start)
    sweeps = sweeps.replace("-- INSERT_SAFE_WEAPON_SWEEPS", source[start:end])
    if "-- INSERT_" in sweeps:
        raise RuntimeError("Unexpanded blade scan source marker")
    harness.write_text(sweeps, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)

    feedback = (root / "tests" / "gun_feedback.luau").read_text(encoding="utf-8")
    start = source.index("local installAimFeedbackSafety = function(State)")
    end = source.index("installAimFeedbackSafety(State)", start)
    feedback = feedback.replace("-- INSERT_GUN_FEEDBACK", source[start:end])
    if "-- INSERT_" in feedback:
        raise RuntimeError("Unexpanded gun feedback source marker")
    harness.write_text(feedback, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)

    pending = (root / "tests" / "gun_pending_lifecycle.luau").read_text(encoding="utf-8")
    start = source.index("local function recordUnconfirmedGun(")
    end = source.index("do\n-- Saved settings:", start)
    pending = pending.replace("-- INSERT_GUN_PENDING_LIFECYCLE", source[start:end])
    if "-- INSERT_" in pending:
        raise RuntimeError("Unexpanded pending gun lifecycle source marker")
    harness.write_text(pending, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)

    transparent_cover = (root / "tests" / "transparent_cover.luau").read_text(encoding="utf-8")
    start = source.index("local function isDirectBodyHit(")
    end = source.index("function State.TestCoverChecks()", start)
    transparent_cover = transparent_cover.replace("-- INSERT_TRANSPARENT_COVER", source[start:end])
    if "-- INSERT_" in transparent_cover:
        raise RuntimeError("Unexpanded transparent cover source marker")
    harness.write_text(transparent_cover, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)

    style = (root / "tests" / "style_moves.luau").read_text(encoding="utf-8")
    start = source.index("local function styleOpponentRole(")
    end = source.index("do\n-- One-shot style moves:", start)
    style = style.replace("-- INSERT_STYLE_POLICY", source[start:end])
    # No juke/trickshot may override movement speed, even as an instant boost.
    # The separate, user-controlled Speed Boost feature is outside this block.
    start_runtime = source.index("do\n-- One-shot style moves:", end)
    end_runtime = source.index("local function equippedWeapon()", start_runtime)
    style_runtime = source[start_runtime:end_runtime]
    import re
    if re.search(r"\.WalkSpeed\s*=(?!=)", style_runtime):
        raise AssertionError("Style movement must never assign Humanoid.WalkSpeed")
    if "AppliedWalkSpeed" in style_runtime or "PreviousWalkSpeed" in style_runtime:
        raise AssertionError("Old juke speed-boost tracking remains in the style controller")
    if "-- INSERT_STYLE_POLICY" in style:
        raise RuntimeError("Unexpanded style policy source marker")
    harness.write_text(style, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)

    learning = (root / "tests" / "juke_learning.luau").read_text(encoding="utf-8")
    learning = learning.replace("-- INSERT_STYLE_POLICY", source[start:end])
    begin = source.index("local function styleObserveOpponent(")
    finish = source.index("local function scanStyleThreats(", begin)
    learning = learning.replace("-- INSERT_MOTION_TRACKER", source[begin:finish])
    if "-- INSERT_" in learning:
        raise RuntimeError("Unexpanded motion learning test marker")
    harness.write_text(learning, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)

    juke_geometry = (root / "tests" / "juke_space.luau").read_text(encoding="utf-8")
    begin = source.index("local function styleLaneClearance(")
    finish = source.index("local function stylePlanEscape(", begin)
    juke_geometry = juke_geometry.replace("-- INSERT_JUKE_LANE", source[begin:finish])
    begin = source.index("local function styleMotionHorizon(")
    finish = source.index("local function styleSpeedFactor(", begin)
    juke_geometry = juke_geometry.replace("-- INSERT_MOTION_HORIZON", source[begin:finish])
    begin = source.index("local function styleLaneRisk(")
    finish = source.index("local function styleSpinAngle(", begin)
    juke_geometry = juke_geometry.replace("-- INSERT_JUKE_SPACE_POLICY", source[begin:finish])
    begin = source.index("local function stylePlanEscape(")
    finish = source.index("function State.PreviewJukeSpace()", begin)
    juke_geometry = juke_geometry.replace("-- INSERT_JUKE_PLANNER", source[begin:finish])
    if "-- INSERT_JUKE_" in juke_geometry:
        raise RuntimeError("Unexpanded juke geometry marker")
    harness.write_text(juke_geometry, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)

    aim_ray = (root / "tests" / "aim_ray.luau").read_text(encoding="utf-8")
    begin = source.index("local function reliableGunPart(")
    finish = source.index("local function hiddenBodyPart(", begin)
    reliable = source[begin:finish]
    begin = source.index("function State.GunReliablePartNames(")
    finish = source.index("local function exposedSolution(", begin)
    aim_ray = aim_ray.replace("-- INSERT_RELIABLE_PART", reliable + source[begin:finish])
    begin = source.index("local function sampleRayHitsBody(")
    finish = source.index("local function gunTimingCoverage(", begin)
    aim_ray = aim_ray.replace("-- INSERT_SAMPLE_RAY", source[begin:finish])
    if "-- INSERT_" in aim_ray:
        raise RuntimeError("Unexpanded aim-ray test source marker")
    harness.write_text(aim_ray, encoding="utf-8")
    subprocess.run([args.luau, str(harness)], check=True, timeout=60)
