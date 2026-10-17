# MM2 Universal

Murder Mystery 2 script with a bundled WindUI menu, PC and mobile controls, role-aware gun aim, predicted knife throws, ESP, and player tools.

## Load the script

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ObsidianWorkss/Murder-Mystery-2/refs/heads/main/main.lua"))()
```

Enter your access key when prompted, then equip your gun or knife. The loader always retrieves `main.lua` from this repository's `main` branch. Re-run it after an update; the previous instance is cleaned up before the replacement starts.

Requires a compatible Roblox client scripting environment with `loadstring` and HTTP access. Some optional actions require additional executor APIs. Compatibility varies by device and executor.

## Combat assistance

| Setting | Behavior |
| --- | --- |
| Aim assist | Master switch for weapon assistance. Enabled by default. |
| Gun aim | Redirects a fired shot toward a clear body point on the known murderer, including targets outside the camera view. |
| Knife throw prediction | Predicts movement when you explicitly throw. Refreshes the solution after charging. |
| All-direction knife aim | Includes clear offscreen targets, with visible targets ranked first. Enabled by default. |
| Require clear throw target | Skips assisted throws without a clear target. Keeps the charged target through release instead of silently switching or throwing at the cursor. Enabled by default. |
| Clicked stab assist | Attempts contact with the nearest clear opponent within 6.5 studs when the murderer clicks to stab. Enabled by default. |
| Stab sweep | Checks blade overlaps and movement during a stab. |
| Murderer kill aura | Optional automatic stab attempts. Disabled by default. |

Clicking with a knife stabs; it does not automatically throw. Turn off **Knife throw prediction** for manual cursor throws. To keep prediction while allowing cursor fallback when no target is available, turn off **Require clear throw target**.

Assistance does not move the camera or cursor. Gun shots retain wall, player-path, and exclusion checks. Nearby stab assistance respects range, exclusions, and line of sight. Target death, character replacement, weapon changes, or lost visibility can cancel a charged throw.

**Hits and kills are not guaranteed.** The server decides damage, range, cooldowns, and whether an attack is accepted. Prediction cannot know future movement or eliminate network delay. A sent attack or reported ray hit is not proof of a kill.

## Controls

| Action | PC | Mobile |
| --- | --- | --- |
| Open / close menu | Right Shift | Draggable MM2 icon |
| Fire gun / stab | Left click | FIRE / STAB |
| Throw knife | E or right click | THROW |
| Stop active actions / return | End | STOP |
| Toggle aim assistance | F6 | Aim assist setting |
| Toggle gun aim | F7 | Gun aim setting |
| Repair camera input | F10 | Repair camera input button |

The layout follows the active input device. Touch-capable PCs can continue using mouse and keyboard controls.

## Other tools

- Role and dropped-gun ESP, threat warnings, and compact combat status.
- Player exclusions shared by script-controlled targeting and player actions.
- Optional gun pickup, knife dodge, tactical hints, selected-player attacks, teleports, and fling attempts.
- R15 animation options, display presets, camera repair, and unload controls.

Experimental actions can be rejected or corrected by the server. Use **Stop all player actions**, **Emergency stop / return**, or **Unload and restore** as appropriate. **Repair character (respawns)** resets your character.

## Troubleshooting

- **No clear target:** confirm you are in an active round, equip the weapon, and move to an unobstructed position. Gun aim requires an identified murderer.
- **Knife won't throw:** check cooldown and clear-target protection. A cancelled charge releases its local cooldown; press throw again after repositioning.
- **Stab misses:** the opponent must be nearby and unobstructed. Server validation can still reject contact attempts.
- **Controls stop responding:** close the menu and any focused text box. Try camera repair or unload and reload.
- **Optional feature unavailable:** check the feature's status in the menu; required executor functionality may be missing.

## Latest changes

- Matched manual stabs to the live native knife controller's post-throw cooldown (`2 * ThrowSpeed`), with feedback while waiting.
- Added all-direction knife acquisition and explicit clear-target protection.
- Added nearby-target assistance for clicked stabs, with normal cooldown and exclusion checks.
- Revalidate the charged target and weapon before releasing a knife; reject stale targets and blocked paths.
- Keep gun prediction, path checks, and the shot payload on the same sampled origin; reject repeated large muzzle movement.
- A failed stab request no longer consumes the local stab cooldown. Optional animation errors do not block contact assistance.

## Development

`main.lua` is the complete bundled script. Keep the lowercase filename so the public loader continues working.

Run the combat regression tests with Python 3 and the Luau CLI:

```sh
python tests/run.py --luau /path/to/luau
luau-compile --null main.lua
```

The tests extract the current combat functions from `main.lua` and exercise them with mocked client state. They do not verify server damage or live executor compatibility.

Bundled WindUI and Footages Icons license notices are preserved inside `main.lua`.
