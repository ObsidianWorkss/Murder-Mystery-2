# MM2 Universal

**v1.0.0-rc.8 · Release candidate · PC + mobile**

Murder Mystery 2 script with a bundled WindUI menu, PC and mobile controls, role-aware gun aim, predicted knife throws, ESP, and player tools.

Final live compatibility checks are pending. See the [release checklist](docs/RELEASE_CHECKLIST.md) and [validation results](tests/VALIDATION.md) before treating this as a stable release.

[Changes](CHANGELOG.md) · [Support](docs/SUPPORT.md) · [Report a bug](https://github.com/ObsidianWorkss/Murder-Mystery-2/issues/new?template=bug_report.md)

## Load the script

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ObsidianWorkss/Murder-Mystery-2/refs/heads/main/main.lua"))()
```

Enter your access key when prompted, then equip your gun or knife. The loader always retrieves `main.lua` from this repository's `main` branch. Re-run it after an update; the previous instance is cleaned up before the replacement starts.

Requires a compatible Roblox client scripting environment with `loadstring` and HTTP access. Some optional actions require additional executor APIs. Compatibility varies by device and executor.

For clearer startup errors, execute the included [`loader.lua`](loader.lua) file. It fetches the same latest `main.lua` and reports download, compilation, and initialization failures. For an offline copy of this version, execute the packaged `main.lua` directly; the loader always follows the latest `main` branch.

## Combat assistance

| Setting | Behavior |
| --- | --- |
| Aim assist | Master switch for weapon assistance. Enabled by default. |
| Gun aim | Redirects a fired shot toward a clear body point on the known murderer, including targets outside the camera view. |
| Conservative gun shots | Requires the nominal aim ray and five additional timing samples to intersect the target geometry. Skips uncertain shots; enabled by default. Turn off to restore the previous timing-based ranking. |
| Knife throw prediction | Predicts movement when you explicitly throw. Refreshes the solution after charging. |
| All-direction knife aim | Includes clear offscreen targets, with visible targets ranked first. Enabled by default. |
| Require clear throw target | Skips assisted throws without a clear target. Keeps the charged target through release instead of silently switching or throwing at the cursor. Enabled by default. |
| Clicked stab assist | Attempts contact with the nearest clear opponent within 6.5 studs when the murderer clicks to stab. Enabled by default. |
| Stab sweep | Checks blade overlaps and movement during a stab. |
| Kill aura | Optional automatic stab attempts. Disabled by default. |

Clicking with a knife stabs; it does not automatically throw. Turn off **Knife throw prediction** for manual cursor throws. To keep prediction while allowing cursor fallback when no target is available, turn off **Require clear throw target**.

Assistance does not move the camera or cursor. Gun shots retain wall, player-path, and exclusion checks. Nearby stab assistance respects range, exclusions, and line of sight. Target death, character replacement, weapon changes, or lost visibility can cancel a charged throw.

**Hits and kills are not guaranteed.** The server decides damage, range, cooldowns, and whether an attack is accepted. Prediction cannot know future movement or eliminate network delay. A sent attack or reported ray hit is not proof of a kill.

## Controls

| Action | PC | Mobile |
| --- | --- | --- |
| Open / close menu | Right Shift | Draggable MM2 button |
| Fire gun / stab | Left click | Fire / Stab |
| Throw knife | E or right click | Throw |
| Stop active actions / return | End | Stop |
| Fly up / down | Space or jump / Ctrl | Jump or Up / Down |
| Toggle aim assistance | F6 | Aim assist setting |
| Toggle gun aim | F7 | Gun aim setting |
| Repair camera input | F10 | Repair camera input button |

The layout follows the active input device. Touch-capable PCs can continue using mouse and keyboard controls.

## Other tools

- Menu tabs follow your role: Murderer, Sheriff and Innocent, then Fling, Movement, Visuals, Players and Settings.
- Movement: speed boost, jump boost, infinite jump, noclip and fly (Space or jump to rise, Ctrl to sink; on mobile, hold the Up and Down buttons that appear while flying). Each switches off cleanly, pauses while you fling or are invisible, and stops with End. The server can still kick for movement it rejects.
- Visuals → X-ray makes walls and the map see-through on your screen only, with a strength slider. Players, tools, coins and the dropped gun stay solid, and switching it off restores the map.
- Role and dropped-gun ESP, threat warnings, and compact combat status.
- Player exclusions shared by script-controlled targeting and player actions.
- Players → Chat → **Reveal roles** posts the round's roles in chat, for example `🔪 Murderer: @name • 🔫 Sheriff: @name`, or `🔪 Murderer: @name • 💀 Sheriff: dead • 🦸 Hero: @name` once someone picks up the gun. It previews the message first, never names you, skips protected players, and waits 4 seconds between messages.
- Optional gun pickup, knife dodge, tactical hints, selected-player attacks, teleports, and fling attempts.
- R15 animation options, display presets, camera repair, and unload controls.

Experimental actions can be rejected or corrected by the server. Use **Stop all player actions**, **Emergency stop / return**, or **Unload and restore** as appropriate. **Repair character (respawns)** resets your character.

## Troubleshooting

- **No clear target:** confirm you are in an active round, equip the weapon, and move to an unobstructed position. Gun aim requires an identified murderer.
- **Timing checks skip a shot:** reposition or wait for steadier movement, then click again. Conservative mode checks a wider timing range and may reject shots that the previous mode would attempt. Skipped clicks are not queued for automatic firing.
- **Knife won't throw:** check cooldown and clear-target protection. A cancelled charge releases its local cooldown; press throw again after repositioning.
- **Stab misses:** the opponent must be nearby and unobstructed. Server validation can still reject contact attempts.
- **Controls stop responding:** close the menu and any focused text box. Try camera repair or unload and reload.
- **Optional feature unavailable:** check the feature's status in the menu; required executor functionality may be missing.

## Release and support

Use **Settings → Copy support report** to include your version, feature settings, capabilities, and counters in a bug report. It excludes player identities and access keys. See [support instructions](docs/SUPPORT.md) for recovery steps and clipboard fallback.

Recent updates add conservative combat checks, fewer background scans, reusable timing queries, and a versioned release package. Full details are in the [changelog](CHANGELOG.md).

## Development

`main.lua` is the complete bundled script. Keep the lowercase filename so the public loader continues working.

Run the combat regression tests with Python 3 and the Luau CLI:

```sh
python tests/run.py --luau /path/to/luau
luau-compile --null main.lua loader.lua
python tools/package.py --output dist
```

The tests extract current functions from `main.lua` and exercise combat, loader failure handling, and support-report privacy with mocked client state. They do not verify server damage or live executor compatibility. GitHub Actions runs compilation and regression checks on pushes and pull requests.

Packaging uses an explicit file list, verifies the ZIP against its per-file `MANIFEST.json`, and writes `SHA256SUMS.txt` alongside the archive. Local key files and repository metadata are not packaged.

Bundled WindUI and Footages Icons license notices are preserved inside `main.lua`; see [third-party notices](THIRD_PARTY_NOTICES.md).
