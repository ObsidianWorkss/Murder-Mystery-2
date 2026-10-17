# MM2 Universal

**v1.0.0-rc.22 · Release candidate · PC + mobile**

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
| Gun triggerbot | Automatically aims at a clear visible on-screen murderer. Both the body sample and predicted aim point must remain on screen. Requires Aim assist and Gun aim. Off by default. |
| Knife triggerbot | Automatically stabs a clear on-screen opponent within 6.5 studs while you are murderer. No crosshair contact or dwell needed. Independent of gun triggerbot; off by default. |
| Knife throw prediction | Predicts movement when you explicitly throw. Refreshes the solution after charging. |
| All-direction knife aim | Includes clear offscreen targets, with visible targets ranked first. Enabled by default. |
| Require clear throw target | Skips assisted throws without a clear target. Keeps the charged target through release instead of silently switching or throwing at the cursor. Enabled by default. |
| Clicked stab assist | Attempts contact with the nearest clear opponent within 6.5 studs when the murderer clicks to stab. Enabled by default. |
| Stab sweep | Checks blade overlaps and movement during a stab. |
| Kill aura | Automatically swings and reports clear nearby body contact as murderer; physical blade overlap is not required. Disabled by default. |

Clicking with a knife stabs; it does not automatically throw. Turn off **Knife throw prediction** for manual cursor throws. To keep prediction while allowing cursor fallback when no target is available, turn off **Require clear throw target**.

Assistance does not move the camera or cursor. Gun shots retain wall, player-path, and exclusion checks. Nearby stab assistance respects range, exclusions, and line of sight. Target death, character replacement, weapon changes, or lost visibility can cancel a charged throw.

**Hits and kills are not guaranteed.** The server decides damage, range, cooldowns, and whether an attack is accepted. Prediction cannot know future movement or eliminate network delay. A sent attack or reported ray hit is not proof of a kill.

### Using the triggerbot

1. Equip your weapon. Enable **Sheriff → Gun Aim → Gun triggerbot** or **Murderer → Knife Aim → Knife triggerbot**. Keep **Aim assist** on; the gun also needs **Gun aim**.
2. Close the menu and keep your opponent visible on screen. The gun automatically checks for a clear assisted shot at the known murderer. Knife triggerbot selects a clear on-screen opponent within 6.5 studs. Neither mode needs your cursor directly on the player, a crosshair dwell, or mobile mouse lock.
3. Press **T** to toggle both triggerbot modes together. Rebind **Universal triggerbot** in **Settings → Combat keys**. Independent gun and knife keys remain available and start unbound. Read **Triggerbot status** in either aim card for missing settings, cooldowns, blocked paths, or rejected shot predictions.

The triggerbot does not turn other settings on. Each mode switches off on reload and with **Emergency stop**. Menus, chat, lost window focus, invisibility, fling, kill aura, and selected-player automatic attacks pause it. Both modes select a fresh on-screen target when they resume. Missed manual clicks are never queued.

Gun requests have a conservative **3-second minimum interval**, also measured from manual assisted shots, and wait for the tool to be enabled. Knife requests respect the existing stab and throw cooldowns; extended aura range does not extend triggerbot reach. The gun preserves prediction, timing, wall, player-path, and exclusion checks while filtering body samples to the screen and checking visibility again before sending. Ready-weapon aim checks use a **50 ms minimum interval** (previously 250 ms); cheap readiness checks run at most 60 times per second. Frame rate, selection cost and network delay affect actual reaction time. The status card retains the last gun-check reason across pauses. Request counters are not hit or kill counters.

### Using kill aura and extended reach

Enable **Murderer → Kill Aura → Kill aura**, or press **K** after closing the menu. **Equip knife for aura** equips your knife automatically. While you are murderer, aura selects a clear nearby body part, swings, and sends its contact report without waiting for your blade to touch the player. It checks alternative body parts when the target's center is behind cover.

With **Extended stab reach** off, **Aura range** sets the radius (1–6.5 studs). With it on, **Extended reach** sets the attempted radius (1–100 studs, default 30). Extended reach modifies kill aura; it does not enable aura by itself or change the server's damage validation. A contact request beyond the server's allowed distance can still be rejected.

The aura stays enabled while waiting through normal death, respawn, or innocent rounds, and resumes when you have a ready murderer knife. It pauses for menus, typing, lost focus, fling, and unavailable weapon states. Emergency stop, unload/reload, and actions that explicitly stop aura turn it off. Its status distinguishes a successful contact request from a swing with no contact report; neither proves a kill.

## Controls

| Action | PC | Mobile |
| --- | --- | --- |
| Open / close menu | Right Shift (rebindable) | Draggable MM2 button |
| Fire gun / stab | Left click | Fire / Stab |
| Throw knife | E or right click | Throw |
| Stop active actions / return | End (rebindable) | Stop |
| Fly up / down | Space or jump / Ctrl | Jump or Up / Down |
| Toggle aim assistance | F6 (rebindable) | Aim assist setting |
| Toggle gun aim | F7 (rebindable) | Gun aim setting |
| Toggle both triggerbots | T (rebindable) | Gun / Knife triggerbot settings |
| Repair camera input | F10 (rebindable) | Repair camera input button |

### PC keybinds

Settings → **Keybinds**, **Combat keys**, **Movement keys**, **Visual keys** and **Action keys** give every menu toggle and action its own key, including the menu and emergency-stop keys (these can move but never be cleared). Click a key box and press a new key; Esc cancels and Backspace clears it; a key already in use moves to the new action. Keys never fire while you type, while the menu is open, or in the mobile layout, and a short message confirms each press.

| Action | Default |
| --- | --- |
| Aim assist / Gun aim / Invisibility / Repair camera | F6 / F7 / F8 / F10 |
| Fly / Noclip / Speed boost / Infinite jump | F / N / G / J |
| Kill aura / Player ESP / X-ray | K / V / X |
| Universal triggerbot (gun + knife) | T |
| Open menu / Emergency stop | Right Shift / End |
| Every other toggle and action (jump boost, animation pack, reveal roles, teleports, fling actions, HUD and ESP options, unload and more) | Unbound |

Movement keys, Space, Left Shift, Ctrl, number keys, Tab, `/`, I, O, arrows, E, F9, F11 and F12 stay reserved for Roblox and MM2.

The layout follows the active input device. Touch-capable PCs can continue using mouse and keyboard controls.

## Other tools

- Menu tabs follow your role: Murderer, Sheriff and Innocent, then Fling, Movement, Visuals, Players and Settings.
- Movement: speed boost, jump boost, infinite jump, noclip and fly (Space or jump to rise, Ctrl to sink; on mobile, hold the Up and Down buttons that appear while flying). Each switches off cleanly, pauses while you fling or are invisible, and stops with End. The server can still kick for movement it rejects.
- Movement → Animations → **Animation pack** swaps your whole movement set (idle, walk, run, jump, fall, climb, swim) to one of 17 Roblox catalog packs: Astronaut, Bubbly, Cartoony, Elder, Knight, Levitation, Mage, Ninja, Pirate, Robot, Rthro, Stylish, Superhero, Toy, Vampire, Werewolf or Zombie. Needs an R15 avatar; your choice is kept on respawn and reload.
- Visuals → X-ray makes walls and the map see-through on your screen only, with a strength slider. Players, tools, coins and the dropped gun stay solid, and switching it off restores the map.
- Toasts: a short message with a colored dot confirms every toggle and key press and announces your role, picking up the gun, elimination and a dropped gun. Visuals → HUD & Alerts → Toasts turns them off.
- Role and dropped-gun ESP, threat warnings, and compact combat status.
- Player exclusions shared by script-controlled targeting and player actions.
- Players → Chat → **Reveal roles** posts the round's roles in chat, for example `🔪 Murderer: @name • 🔫 Sheriff: @name`, or `🔪 Murderer: @name • 💀 Sheriff: dead • 🦸 Hero: @name` once someone picks up the gun. It previews the message first, never names you, skips protected players, and waits 4 seconds between messages.
- Optional gun pickup, knife dodge, tactical hints, selected-player attacks, teleports, and fling attempts.
- R15 animation options, display presets, camera repair, and unload controls.

Experimental actions can be rejected or corrected by the server. Use **Stop all player actions**, **Emergency stop / return**, or **Unload and restore** as appropriate. **Repair character (respawns)** resets your character.

## Troubleshooting

- **No clear target:** confirm you are in an active round, equip the weapon, and move to an unobstructed position. Gun aim requires an identified murderer.
- **Timing checks skip a shot:** reposition or wait for steadier movement, then click again. Conservative mode checks a wider timing range and may reject shots that the previous mode would attempt. Skipped clicks are not queued for automatic firing.
- **Triggerbot does nothing:** check its status card, close the menu, equip the weapon, and enable Aim assist and Gun aim. The target must be visible on screen with a clear firing path; predicted gun aim must stay on screen too. Knife triggerbot needs a visible opponent within 6.5 studs. Neither requires a direct cursor hit. Both reset to off after reload; press T to enable them. Kill aura pauses triggerbot while aura runs.
- **Knife won't throw:** check cooldown and clear-target protection. A cancelled charge releases its local cooldown; press throw again after repositioning.
- **Stab misses:** the opponent must be nearby and unobstructed. Server validation can still reject contact attempts.
- **Aura does nothing:** enable Kill aura with K outside the menu, confirm your role is murderer, and check its status. Extended reach requires Kill aura to be on. Teleports and stop controls can switch aura off; normal respawns now keep it enabled.
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

The tests extract current functions from `main.lua` and exercise combat, triggerbot acquisition and cooldowns, emergency stop, loader failure handling, and support-report privacy with mocked client state. They do not verify server damage or live executor compatibility. GitHub Actions runs compilation and regression checks on pushes and pull requests.

Packaging uses an explicit file list, verifies the ZIP against its per-file `MANIFEST.json`, and writes `SHA256SUMS.txt` alongside the archive. Local key files and repository metadata are not packaged.

Bundled WindUI and Footages Icons license notices are preserved inside `main.lua`; see [third-party notices](THIRD_PARTY_NOTICES.md).
