# MM2 Universal

**v1.0.0-rc.19 · Release candidate · PC + mobile**

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
| Gun triggerbot | Automatically attempts a shot only when your crosshair stays on the known murderer's body. Requires Aim assist and Gun aim. Off by default. |
| Knife triggerbot | Automatically attempts a stab at the clear opponent under your crosshair within 6.5 studs, while you are murderer. Independent of gun triggerbot; off by default. |
| Knife throw prediction | Predicts movement when you explicitly throw. Refreshes the solution after charging. |
| All-direction knife aim | Includes clear offscreen targets, with visible targets ranked first. Enabled by default. |
| Require clear throw target | Skips assisted throws without a clear target. Keeps the charged target through release instead of silently switching or throwing at the cursor. Enabled by default. |
| Clicked stab assist | Attempts contact with the nearest clear opponent within 6.5 studs when the murderer clicks to stab. Enabled by default. |
| Stab sweep | Checks blade overlaps and movement during a stab. |
| Kill aura | Optional automatic stab attempts. Disabled by default. |

Clicking with a knife stabs; it does not automatically throw. Turn off **Knife throw prediction** for manual cursor throws. To keep prediction while allowing cursor fallback when no target is available, turn off **Require clear throw target**.

Assistance does not move the camera or cursor. Gun shots retain wall, player-path, and exclusion checks. Nearby stab assistance respects range, exclusions, and line of sight. Target death, character replacement, weapon changes, or lost visibility can cancel a charged throw.

**Hits and kills are not guaranteed.** The server decides damage, range, cooldowns, and whether an attack is accepted. Prediction cannot know future movement or eliminate network delay. A sent attack or reported ray hit is not proof of a kill.

### Using the triggerbot

1. Equip your weapon. Enable **Sheriff → Gun Aim → Gun triggerbot** or **Murderer → Knife Aim → Knife triggerbot**. Keep **Aim assist** on; the gun also needs **Gun aim**.
2. Close the menu and aim at an opponent's body. The gun only accepts the known murderer. Keep the crosshair on the same opponent for at least 0.1 seconds. On mobile, enable the game's mouse lock and use its center crosshair.
3. Press **T** to toggle both triggerbot modes together. Rebind **Universal triggerbot** in **Settings → Combat keys**. Independent gun and knife keys remain available and start unbound. Read **Triggerbot status** in either aim card for missing settings, cooldowns, blocked paths, or rejected shot predictions.

The triggerbot does not turn other settings on. Each mode switches off on reload and with **Emergency stop**. Menus, chat, lost window focus, invisibility, fling, kill aura, and selected-player automatic attacks pause it. Resuming requires a fresh crosshair acquisition; missed manual clicks are never queued.

Gun requests have a conservative **3-second minimum interval**, also measured from manual assisted shots, and wait for the tool to be enabled. Knife requests respect the existing stab and throw cooldowns; extended aura range does not extend triggerbot reach. The gun keeps your existing prediction, timing, wall, player-path, and exclusion checks. A rejected prediction may be retried while you keep aiming, but it does not count as a sent shot. Request counters are not hit or kill counters.

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
- **Triggerbot does nothing:** check its status card, close the menu, equip the weapon, and aim at the opponent's body. Enable Aim assist and, for guns, Gun aim. Mobile needs the game's mouse lock. The triggerbot resets to off after reloading the script.
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

The tests extract current functions from `main.lua` and exercise combat, triggerbot acquisition and cooldowns, emergency stop, loader failure handling, and support-report privacy with mocked client state. They do not verify server damage or live executor compatibility. GitHub Actions runs compilation and regression checks on pushes and pull requests.

Packaging uses an explicit file list, verifies the ZIP against its per-file `MANIFEST.json`, and writes `SHA256SUMS.txt` alongside the archive. Local key files and repository metadata are not packaged.

Bundled WindUI and Footages Icons license notices are preserved inside `main.lua`; see [third-party notices](THIRD_PARTY_NOTICES.md).
