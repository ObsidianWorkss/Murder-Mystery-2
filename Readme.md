# MM2 Universal

**v1.0.0-rc.38 · Release candidate · PC + mobile**

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

Gun requests are bounded to one per **150 ms**, including manual assisted shots, and wait up to **750 ms** for unanswered feedback. The tool must be enabled. These are client request intervals, not a guaranteed server fire rate. Knife requests retain stab and throw cooldowns; aura range does not extend knife triggerbot reach. Gun prediction, timing, wall, player-path, exclusion and on-screen checks remain. **Triggerbot checks every heartbeat with no added polling delay.** Actual reaction depends on frame rate, selection cost and network delay. Request counters are not hit or kill counters.

### Using kill aura

Enable **Murderer → Kill Aura → Kill aura**, or press **K** after closing the menu. **Equip knife for aura** equips your knife automatically. While you are murderer, aura selects a clear nearby body part, swings, and sends its contact report without waiting for your blade to touch the player. It checks alternative body parts when the target's center is behind cover.

**Aura range** controls the active attempted radius from **1–1,000 studs, default 1,000**. Previous default ranges of 6 or 60 and the old 200-stud maximum upgrade once; other custom active ranges are preserved. This is a client selection radius, not a measured server damage limit. Distant aura contacts can still be rejected.

The aura stays enabled while waiting through normal death, respawn, or innocent rounds, and resumes when you have a ready murderer knife. It pauses for menus, typing, lost focus, fling, and unavailable weapon states. Emergency stop, unload/reload, and actions that explicitly stop aura turn it off. Its status distinguishes a successful contact request from a swing with no contact report; neither proves a kill.

### Kill all

**Murderer → Kill Aura → Kill all** supports two saved modes:

- **Burst** (default): one native swing sends contact attempts for all eligible players in the same frame, including off-screen or obstructed players. Range, protection, role and character checks remain. The server can reject those requests.
- **Aimed throws**: attacks one player at a time, using ordinary assisted stabs within 6.5 studs and target-locked predicted throws farther away. Requires a clear path and Knife throw prediction for ranged attacks. Native charge and cooldown times apply. This mode does not guarantee damage.

Starting Kill all from its menu button now closes the menu automatically. Changing mode stops the current queue and cancels its pending automatic throw. Survivors can receive up to three attempts each during at most 30 active seconds. When all remaining retry budgets are spent, Burst finishes after a 1.25-second feedback grace instead of sitting idle until the deadline. Aimed throws allow extra bounded charge/flight time before completion. A stalled frame counts its full active time toward the deadline. **Stop Kill all**, **Emergency stop**, stopping aura, losing the murderer role, or respawning cancels the action. Menu/focus pauses also pause the deadline. Existing ordinary aura resumes afterward; otherwise it switches off. Optional action keys are in **Settings → Combat keys**, initially unbound.

**Target priority**, in the same Kill Aura section, offers **Nearest**, **Sheriff first** (including the current hero), and **Selected player**. Select that player in **Players → Player Actions → Specific player**. Missing, protected or unavailable preferred players fall back to eligible nearby players. Priority selects the next player for ordinary aura and aimed mode; in Burst it orders contact delivery without excluding other eligible targets.

### Combat results

Open **Home → Combat results** for session weapon totals and the last Kill all run: gun requests, matched replies, target ray hits, unanswered requests, knife swings, sent throws and contacts, bursts, throws started, observed eliminations, unresolved targets, skips and the current status. A throw that only started charging is counted separately from one actually sent. Observed deaths are not attributed kills; unmatched requests have an unknown outcome. The panel does not label contact reports as confirmed damage. Unresolved targets have reason counts such as out of range, character loading, missing knife, blocked aimed path, disabled prediction, unavailable contact report or spent retry budget. Reasons are observations of client state, not server rejection codes.

**Retry unresolved**, in Kill Aura and Combat results, starts a new bounded pass only for eligible survivors of the last run. It filters fresh protection, departure, elimination and character changes; own respawn and round end clear retry eligibility. Refused retries never fall back to attacking everyone. Successful retries close the menu automatically. Its optional Combat key starts unbound.

**Recent runs** retains up to five session summaries with mode, active duration, sent contacts, observed eliminations and unresolved counts. Changing a returned snapshot does not modify the live counters. History clears when the script reloads.

### Performance preset

Choose **Settings → General → Performance preset → Low effects** to suppress the aim marker, nearby threat notice, stable body fills and tactical/learned guidance, while using clean labels and a compact HUD. Background ESP/status visuals update every 0.4 seconds instead of 0.2; menu/HUD updates use 0.6 instead of 0.3 seconds; visual aim previews can be reused for 1 second instead of 0.5. Actual assisted attacks still calculate fresh aim, and trigger acquisition, weapon cooldowns, motion tracking, protection and damage checks retain their existing timing.

Contact reports for a locked target use a direct player lookup rather than fetching and scanning the full roster for each contact. When ordinary aura has no clear target, idle ray checks back off to 50 ms (100 ms under Low effects), with fresh validation on the next attempt. Triggerbot remains per heartbeat.

**Balanced** restores these visual settings to their defaults. Mode, target priority and performance preset are saved between runs. Selected player identity is session-only. Performance gains depend on the client and enabled features; no frame-rate improvement is guaranteed.

### Weapon equip recovery

MM2 uses its own hotbar for **1**; the script keeps that key reserved and does not replace the native equip/holster action. **Settings → General → Slot 1 equip recovery**, on by default, observes the key and gives the native handler 120 ms to equip. It retries once only if one owned, tagged knife or gun stayed in the backpack without a parent-state transition. It uses `Humanoid:EquipTool` and does not grant weapons.

Normal equips and holsters, rapid toggles, consumed UI input, menus, chat, focus loss, multiple weapons, missing handles, character/tool replacement and unload prevent or cancel recovery. Processed input requires an observed native slot action. Weapon firing cooldown does not incorrectly prevent equipping. The preference is saved.

**Weapon equip status**, next to the setting, retains the outcome and press/recovery/skip/failure counts. **Copy support report** includes these counters, native-action/input observations and the last weapon location without raw errors or player identities. If 1 fails again, use that status to distinguish a missing owned tool, inactive hotbar, consumed input or failed local equip. The reported intermittent failure has not yet been reproduced during an active weapon round.

## Auto knife dodge

**Innocent → Knife Dodge → Dodge incoming knives** starts enabled on every load. Old saved Off values and a previous session's Emergency stop do not disable the next load. You can turn it off for the current session; Emergency stop also switches it off.

It attempts a jump over a low incoming thrown knife or a supported sidestep with a clear route. It does not counter knife stabs or guarantee survival. Menus, typing, lost focus, missing/dead characters, controlled movement and invisibility pause it. Invisibility preparation now cancels the current sidestep without permanently removing the dodge loop; the loop resumes when the character becomes available again. Map/lobby teleports also cancel the old sidestep without switching the feature off.

**Auto dodge status** shows the current waiting/pause reason and jump/sidestep counts. Explicit Off removes the frame hook and On rebinds it. Unload removes it permanently for that script instance. Unexpected frame errors stop the feature with a visible retry status. Support reports include enabled/bound/focus state and tracked-knife/action counters, without raw errors. Real incoming-throw survival for rc.38 remains a live check.

## Gun pickup and invisibility

Picking up, equipping and firing a gun keep invisibility active. Owning a gun also allows invisibility activation. Weapon input waits during invisibility preparation or incomplete restoration without dismantling the invisible assembly. Turning off **Knife while invisible** pauses knife input while invisible instead of revealing you. Manual **Restore character**, Emergency stop and normal character cleanup remain available. Invisibility on other clients and accepted shots while invisible still require live verification.

## Experimental map voting

Under **Movement → Map Voting**, enable **Repeat chosen map vote**, close the menu, and vote on your chosen map's pad during an active vote. The script selects the actual `VotePads.Detector1–3` trigger (or native `Pad`) paired with that slot's live `VoteInfoGui` board. Board visibility, map name and displayed count take priority over obsolete `VoteIcons` values, which can remain false/nil/zero during an active vote. Standing inside the trigger also works if a fresh touch event was missed. It follows **vote → reset → wait for a new living character → return that character to the same voting pad → vote again**, with up to **three resets** per activation.

This remains **unverified vote duplication**. The reset requests humanoid death and breaks that character's joints; after respawn the character physically returns to the detector. The executor touch API supplements the normal contact when available, but is optional. Map geometry is not moved. Status separates reset requests, re-vote attempts and the observed total increase, which can also come from other players. No count increase within two seconds after the repeat contact stops further resets; no new character within 12 seconds also stops the attempt.

Voting ending, map/pad changes, conflicting character actions, opening menus, Emergency stop, switching off and unloading cancel the run and clean up pending touches. The toggle always starts off and is never saved. Its optional key is unbound in **Settings → Movement keys**.

**Map vote status** distinguishes closed voting, unavailable pads, an open vote awaiting your choice, and input/character conflicts such as an open menu or active invisibility. The support snapshot includes active-pad count, metadata source and whether a touch or position detected your choice. A disabled current board is treated as closed voting even if legacy flags are stale.

## Controls

| Action | PC | Mobile |
| --- | --- | --- |
| Open / close menu | Right Shift (rebindable) | Draggable MM2 button |
| Equip / holster weapon | 1 (native MM2 slot 1) | Native weapon icon |
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

Settings are saved automatically to `MM2Universal/settings.json` in your executor's folder: toggles, sliders, keybinds, protected players and the menu theme come back on every run, including after a rejoin or in a new server. Features the script always starts off (invisibility, kill aura, triggerbots, movement) still start off. **Settings → Reset settings** returns everything to defaults and keeps protected players. **Saved settings** shows whether saving works; on an executor without file access the script runs normally without saving.

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
- Anti-fling (Movement → Anti-fling, on by default): a player spinning or moving at fling speed passes through you on your screen for a few seconds, and if you are launched or spun anyway, your speed is zeroed and you are put back where you stood in the same frame. Everyone else stays solid, so aim and dodge checks are unchanged. It stands aside while your own fling or invisibility moves you. Its key starts unbound (Settings → Movement keys).
- Movement → Animations → **Animation pack** swaps your whole movement set (idle, walk, run, jump, fall, climb, swim) to one of 17 Roblox catalog packs: Astronaut, Bubbly, Cartoony, Elder, Knight, Levitation, Mage, Ninja, Pirate, Robot, Rthro, Stylish, Superhero, Toy, Vampire, Werewolf or Zombie. Needs an R15 avatar; your choice is kept on respawn and reload.
- Visuals → X-ray makes walls and the map see-through on your screen only, with a strength slider. Players, tools, coins and the dropped gun stay solid, and switching it off restores the map.
- Toasts: a short message with a colored dot confirms every toggle and key press and announces your role, picking up the gun, elimination and a dropped gun. Visuals → HUD & Alerts → Toasts turns them off.
- Role and dropped-gun ESP, threat warnings, and compact combat status.
- Player exclusions shared by script-controlled targeting and player actions.
- Players → Chat → **Reveal roles** posts the round's roles in chat, for example `🔪 Murderer: @name • 🔫 Sheriff: @name`, or `🔪 Murderer: @name • 💀 Sheriff: dead • 🦸 Hero: @name` once someone picks up the gun. It previews the message first, never names you, skips protected players, and waits 4 seconds between messages.
- Default-on knife dodge; optional gun pickup, tactical hints, selected-player attacks, teleports, and fling attempts.
- R15 animation options, display presets, camera repair, and unload controls.

Experimental actions can be rejected or corrected by the server. Use **Stop all player actions**, **Emergency stop / return**, or **Unload and restore** as appropriate. **Repair character (respawns)** resets your character.

## Troubleshooting

- **No clear target:** confirm you are in an active round, equip the weapon, and move to an unobstructed position. Gun aim requires an identified murderer.
- **Timing checks skip a shot:** reposition or wait for steadier movement, then click again. Conservative mode checks a wider timing range and may reject shots that the previous mode would attempt. Skipped clicks are not queued for automatic firing.
- **Triggerbot does nothing:** check its status card, close the menu, equip the weapon, and enable Aim assist and Gun aim. The target must be visible on screen with a clear firing path; predicted gun aim must stay on screen too. Knife triggerbot needs a visible opponent within 6.5 studs. Neither requires a direct cursor hit. Both reset to off after reload; press T to enable them. Kill aura pauses triggerbot while aura runs.
- **Knife won't throw:** check cooldown and clear-target protection. A cancelled charge releases its local cooldown; press throw again after repositioning.
- **Stab misses:** the opponent must be nearby and unobstructed. Server validation can still reject contact attempts.
- **Aura does nothing:** enable Kill aura with K outside the menu, confirm your role is murderer, and check its status. Aura range changes the active radius; increasing it does not force distant damage. Teleports and stop controls can switch aura off; normal respawns now keep it enabled.
- **1 does not equip:** check Settings → General → Weapon equip status. The native hotbar may not have delivered the equip, the tool may be unavailable, or an input/character transition may have cancelled it. The recovery only retries unchanged backpack weapons; normal holstering remains native.
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

The tests extract current functions from `main.lua` and exercise combat, slot-1 equip recovery, triggerbot acquisition and cooldowns, emergency stop, loader failure handling, and support-report privacy with mocked client state. They do not verify server damage or live executor compatibility. GitHub Actions runs compilation and regression checks on pushes and pull requests.

Packaging uses an explicit file list, verifies the ZIP against its per-file `MANIFEST.json`, and writes `SHA256SUMS.txt` alongside the archive. Local key files and repository metadata are not packaged.

Bundled WindUI and Footages Icons license notices are preserved inside `main.lua`; see [third-party notices](THIRD_PARTY_NOTICES.md).
