# Validation — 2026-10-17

## Release candidate 1.0.0-rc.24

- `main.lua` and `loader.lua` compile with Luau 0.739; 80 combat, 127 release, 56 triggerbot and 76 aura assertions pass (339 total).
- Live finding on rc.23: with X-ray off (setting off, inactive, 0 tracked parts), 1,985 of 4,306 map parts were still at 0.60 transparency, and every script screen existed twice, showing two running copies.
- 5 new X-ray assertions run two copies on one fake map. The first fails on rc.23's code ("a second copy keeps the true original value") and all pass on rc.24.
- The single-copy guard has not yet been exercised by a second executor environment live.

## Release candidate 1.0.0-rc.23

- Luau 0.739 compiles both scripts; 80 combat, 122 release, 56 triggerbot and 76 aura assertions pass (334 total).
- Kill all tests exercise one-pass ordering, cooldowns, cancellation, completion without extra swings, restoration of ordinary aura, role refusal, protected/dead/departed/respawned/out-of-range targets, menu pauses, automatic equipping, and failed swing/contact reports. Keybind and support-report tests cover the new actions and bounded activity flag.
- Updated range checks accept 200 and reject 201. Trigger regressions verify reconsideration on heartbeats below the former 50 ms interval without bypassing successful-shot cooldowns.
- Exact accepted extended distance and live Kill all outcomes remain unverified. The responsive client is disconnected; no new server damage or latency measurement is claimed.

## Release candidate 1.0.0-rc.22

- Luau 0.739 compiles both scripts; 80 combat, 118 release, 56 triggerbot and 46 aura assertions pass (300 total). Obsolete cursor-ray and dwell cases were replaced with screen-policy and fast-acquisition regressions.
- Tests exercise viewport edges, camera line of sight, behind-camera points, invalid vectors, sample filtering before prediction, policy forwarding, cancellation when the body or lead point is off screen at send time, visible knife selection, cooldowns, pause handling and 50 ms retries.
- Kill aura is unchanged; the user reported that rc.21 aura works in their live test. This does not establish a particular extended server range or kill rate.
- The responsive Roblox client disconnected during development. Live reaction time and combat accuracy for this version remain unverified; the configured scheduling interval is not a measured latency or accuracy improvement.

## Release candidate 1.0.0-rc.21

- Luau 0.739 compiles both scripts; 58 combat, 118 release, 80 triggerbot and 46 aura assertions pass (302 total).
- Aura tests extract the shipped controller, readiness checks, swing adapter and contact reporter. A fake remote records the actual contact payload; no physical touch or executor touch API is supplied. Normal and extended modes report the selected body part. The remaining checks cover range changes, partial cover, automatic equip, respawn, death, role waiting, cooldowns, exclusions, menu/focus pauses and failed swings/contacts/cleanup.
- Current native KnifeClient inspection confirmed `KnifeStabbed:FireServer()` followed by `HandleTouched:FireServer(part)` during its 0.85-second swing window. The new adapter preserves that payload shape and existing cooldowns.
- Live pre-update diagnostics showed aura off with zero attempts after respawn, and later stopped by an area teleport. Extended reach was enabled but aura itself was off. The local character was sheriff during verification, so live murderer damage and acceptance at extended distances remain unverified.
- Loaded rc.21 and enabled Kill aura plus extended reach in the connected client. Verified a 30-stud configured radius and the live status `Waiting until you are murderer` while in the lobby, with zero swing/contact requests. This checks startup and role waiting, not damage.

## Release candidate 1.0.0-rc.20

- Luau 0.739 compiles both scripts; 58 combat, 118 release, and 80 triggerbot assertions pass (256 total).
- Regressions verify the gun passes the identical record and arguments as a manual assisted click, bypasses cursor/body acquisition, works with the cursor on empty space, walls, innocent players or your own body, and does not require mouse lock on mobile. These cases use a recorded assisted-send callback; the existing combat suite separately exercises the extracted `sendGun` checks.
- Failed aim checks remain throttled and retain their reason without counting a sent shot. Existing knife crosshair, focus, range and obstruction tests remain; gun cooldown and pause guards remain covered.
- Read-only rc.19 live diagnostics showed Gun aim and both triggers enabled, zero trigger sends and zero skipped gun shots, with two manual assisted requests. This is consistent with an early trigger gate preventing attempts, but does not reconstruct the exact reported shot angle. The gun crosshair gate has now been removed as requested. Live combat accuracy remains unverified.
- Loaded rc.20 in the connected MM2 client and verified running state, menu readiness, the T bind, aim-check diagnostics, and both modes off. The local character had no gun equipped, so this startup check did not send a combat request.

## Release candidate 1.0.0-rc.19

- Adds four extracted-source keybind assertions: T is the universal default in the Combat group, enables both trigger modes, disables both, and stops a mixed state. Resetting keybinds restores T. Existing input guards and independent binds are exercised by the release suite.
- Luau 0.739 compiles both scripts; 58 combat, 118 release, and 75 triggerbot assertions pass (251 total).

## Release candidate 1.0.0-rc.18

- Luau 0.739 compiles `main.lua` and `loader.lua`. The extracted-source suites pass 58 combat, 114 release, and 75 triggerbot assertions (247 total).
- Trigger coverage includes continuous acquisition, target respawn, target loss, slow frames, role/protection/death checks, cursor and mouse-lock coordinates, obstruction handling, bounded transparency traversal, manual-shot and weapon cooldowns, failed-send counters, retry throttling, independent toggles, competing attacks, menu/input/focus pauses, callback errors, and the actual emergency-stop installer.
- Read the connected client's current `GunClient` and `ReplicatedStorage.ClientServices.WeaponService` to verify request shape and cursor/mouse-lock behavior. The 3-second gun interval is a conservative local policy, not a measured guarantee of server readiness. Cursor coordinates also follow [Roblox's raycasting tutorial](https://create.roblox.com/docs/tutorials/use-case-tutorials/scripting/intermediate-scripting/hit-detection-with-lasers).
- Live smoke check: loaded rc.18 on a new MM2 connection (place version 1456, Windows PC, executor connected through MCP). Running state, both status cards, independent menu setters, unbound keys, unchanged master aim, and both modes off were verified. No triggerbot attack requests were sent during the smoke check. Actual combat and mobile operation remain unverified; mock passes do not establish a hit rate or server damage.

## Release candidate 1.0.0-rc.17

- `main.lua` and `loader.lua` compile with Luau 0.739; 58 combat and 111 release assertions pass (169 total). The 18 triggerbot assertions were removed with the feature.
- No file mentions the triggerbot any more; the diff from rc.16 only removes code apart from the shortened lines that listed it.
- Live data before removal (rc.16, one server): 27 gun shots, 11 of them fired by the triggerbot; the server confirmed 2 hits and 6 misses, 19 had no matching reply; 13 shots were skipped by the conservative check; 238 FPS; 87 ms ping.

## Release candidate 1.0.0-rc.16

- `main.lua` and `loader.lua` compile with Luau 0.739 (0.07 s, 1.07 MB bytecode); 58 combat and 129 release assertions pass (187 total) in 0.5 s.
- 8 new keybind assertions: menu and stop defaults, the menu key cannot be cleared, the stop key cannot be taken, the menu key can move, menu and stop keys are left to the menu, every toggle and action is listed, a toggle key uses the menu toggle path, and its refusal is shown.

### Offline benchmarks

Shipped modules run against plain-table fakes with Luau `-O2`. These numbers cover the script's own Luau work only; real property writes, rendering and physics cost extra and need a live client to measure.

| Benchmark | rc.14 | rc.16 |
| --- | --- | --- |
| X-ray on, 20,000-part map: frames to fill in | 14 | 63 (about 1 s at 60 FPS) |
| X-ray on: worst single frame | 22.9 ms | 7.0 ms (first frame includes the one-time map scan) |
| X-ray strength change (all parts) | 4.4 ms | 6.5 ms |
| X-ray off / unload restore | 3.8 ms | 5.6 ms |
| X-ray idle per frame (on / off) | 0.34 / 0.06 µs | 0.47 / 0.06 µs |
| Movement per frame, all assists on / off | — | 5.4 / 0.9 µs |
| Key press dispatch, 48 actions (bound / unbound key) | — | 2.5 / 2.3 µs |
| Reveal roles preview, 12 players | — | 5.7 µs |

- The rc.15 crash fix (protected writes) made strength change and switch-off slower than rc.14; rc.16 removes the per-part closures, keeping the protection at a smaller cost.

## Release candidate 1.0.0-rc.15

- `main.lua` and `loader.lua` compile with Luau 0.739; 58 combat and 121 release assertions pass (179 total).
- 7 new regression assertions: releasing and resuming fly, refused kill aura, invisibility and reveal toasts with their reasons and a warning tone, and X-ray surviving Terrain and a part that refuses the change through switch-off and unload.
- The reproduction from the review now passes: the shipped X-ray module no longer errors when a part refuses the write, and F8 shows the refusal reason.
- `luau-analyze` reports one note fewer than rc.14 (the discarded pose error is now used); the menu control list is unchanged.
- Toast placement, Esc and click cancel while picking a key, and fly with teleports or invisibility have not been tried in a live server.

## Release candidate 1.0.0-rc.14

- `main.lua` and `loader.lua` compile with Luau 0.739; 58 combat and 114 release assertions pass (172 total).
- 5 new release assertions cover knife triggerbot: swings knife at a player in reach while murderer, enforces the 0.85s cooldown, refuses out-of-reach targets, refuses obstructed targets, and verifies `SetKnifeTriggerbot` independently enables the bot.
- `luau-analyze` findings are unchanged from rc.13 — no new real errors introduced.
- Knife triggerbot has not been tested in a live server.

## Release candidate 1.0.0-rc.13

- `main.lua` and `loader.lua` compile with Luau 0.739; 58 combat and 109 release assertions pass (167 total).
- 13 new release assertions cover Triggerbot: starts off, stays off until enabled, enables aim and gun aim, waits for target, ignores innocent players, skips protected murderers, fires at the murderer and increments shot counter, enforces cooldown, reports missing gun, stops cleanly on disable or emergency stop, defaults to T keybind, toggles via keybind, and confirms with toasts.
- Triggerbot has not been tested in a live server.

## Release candidate 1.0.0-rc.12

- `main.lua` and `loader.lua` compile with Luau 0.739; 58 combat and 96 release assertions pass (154 total).
- The three Hold Alt assertions were removed with the feature; the info-tone check moved onto the reveal-roles key test.

## Release candidate 1.0.0-rc.11

- `main.lua` and `loader.lua` compile with Luau 0.739; 58 combat and 99 release assertions pass (157 total).
- New keybind assertions: keys need Alt by default, Alt cannot be bound, single keys work with Hold Alt off, and toasts carry on, off, info and warning tones.
- Toast visuals and round-event toasts have not been viewed live.

## Release candidate 1.0.0-rc.10

- `main.lua` and `loader.lua` compile with Luau 0.739; 58 combat and 96 release assertions pass (154 total).
- 21 new keybind assertions cover saved, reserved and duplicate keys, defaults, toggling with confirmation, ignoring handled input, typing, an open menu, mobile and mouse clicks, rejecting reserved keys and mouse buttons, moving a duplicate, clearing with Backspace, refused and failing actions, and reset.
- Keybinds have not been pressed in a live server.

## Release candidate 1.0.0-rc.9

- `main.lua` and `loader.lua` compile with Luau 0.739; 58 combat and 75 release assertions pass (133 total).
- 7 new pack assertions check 17 packs in order, three idles and eight movement slots per pack, no ID shared between packs, the Mage IDs unchanged, catalog IDs for popular packs, and the saved-pack fallback.
- All 169 pack IDs were checked with `economy.roblox.com/v2/assets/{id}/details`: asset type 24 (Animation), creator Roblox, names matching their slot.
- Packs have not been applied in a live server.

## Release candidate 1.0.0-rc.8

- `main.lua` and `loader.lua` compile with Luau 0.739; 58 combat and 68 release assertions pass (126 total).
- 13 new x-ray assertions use a fake workspace: off until enabled, batching across frames, map parts fade, players, tools, invisible parts, coins, the dropped gun and script objects stay untouched, strength changes are throttled then applied everywhere, late parts are included, and off and unload restore original values without overwriting game changes.
- X-ray has not been tried in a live server.

## Release candidate 1.0.0-rc.7

- `main.lua` and `loader.lua` compile with Luau 0.739; all 113 assertions pass.
- No code compares the rewritten messages; the only compared status text (fling `Return failed:`) is unchanged.
- `luau-analyze` findings and the menu's 48 actions are unchanged from rc.6.
- The new wording and sliders have not been viewed live.

## Release candidate 1.0.0-rc.6

- `main.lua` and `loader.lua` compile with Luau 0.739; 58 combat and 55 release assertions pass (113 total).
- New assertions: fly sinks while Down is held, rises while jump is held, and stopping movement releases the Up/Down hold.
- `luau-analyze` findings and the menu control list are unchanged from rc.5.
- The mobile layout has not been viewed on a phone.

## Release candidate 1.0.0-rc.5

- `main.lua` and `loader.lua` compile with Luau 0.739; 58 combat and 53 release assertions pass (111 total).
- 5 new reveal assertions cover the hero after the sheriff dies, a gun holder before round data updates, a protected hero, never naming you as hero, and a gun holder counting as sheriff when round data is missing.
- Emoji rendering in Roblox chat has not been checked live.

## Release candidate 1.0.0-rc.4

- `main.lua` and `loader.lua` compile with Luau 0.739; 58 combat and 48 release assertions pass (106 total).
- 21 new movement assertions use a fake character: speed and jump restore the game's latest value, a frozen player stays frozen, height-based rigs get the converted jump height, noclip restores only collisions that were on, fling pauses noclip, infinite jump ignores ground jumps and holds, fly attaches and removes its movers, and stop restores everything.
- The menu keeps every rc.3 control; 8 movement controls and a status line were added.
- Movement has not been tried in a live server.

## Release candidate 1.0.0-rc.3

- `main.lua` and `loader.lua` compile with Luau 0.739; 58 combat and 27 release assertions pass (85 total).
- 13 new role-reveal assertions cover the message format, dead or protected sheriffs, never naming you, refusing while you are murderer, lobby leftovers, the cooldown and failed sends. A fake send function records messages; the tests never reach a real chat.
- `luau-analyze` reports no new errors or unknown non-Roblox globals compared with rc.2.
- Reveal roles has not been pressed in a live server.

## Release candidate 1.0.0-rc.2

- `main.lua` and `loader.lua` compile with Luau 0.739; the 72 rc.1 assertions still pass.
- `luau-analyze` reports no new errors or unknown globals compared with rc.1.
- The menu builder creates the same 89 titled controls and 46 callbacks as rc.1; only their grouping changed.
- The seven-tab layout and collapsible cards have not been viewed live because no Roblox client was connected.
- The performance changes remove redundant writes and per-frame allocations. No live FPS measurement was taken.

## Release candidate 1.0.0-rc.1

- `main.lua` and `loader.lua` compile with Luau 0.739.
- 58 combat/performance assertions and 14 release assertions pass locally (72 total).
- Release checks cover successful loading, unsupported environments, download/response/compilation/startup failures, and bounded support-report fields.
- The distributable ZIP is checked against its per-file SHA-256 manifest; a separate archive checksum is included.
- New menu controls and support-report clipboard behavior await a live client. The existing live motion-probe failures below remain unresolved.

## Earlier performance comparison

Baseline: `099b7e2` (`ConservativeGun`). Updated build: `Performance`.

### Passed

- Full bundled script compiled with Luau 0.739.
- 58 assertions in `python tests/run.py`: combat behavior, conservative timing checks, preview invalidation, and attack-time cache bypass.
- Live `TestCoverChecks`: invisible solid blockers, helper filtering, learned blockers, non-queryable blockers, and unobstructed paths.
- Live `TestCampChaseAim`: all checks passed in five runs on each build, including stationary targets, close approaches, narrow visibility, and full cover.

### Measured work reduction

- A two-second live sample recorded 79 motion sweeps across 217 frames. Previously the heartbeat traversed the roster every frame.
- The controlled aim fixture used 57 body-ray queries per run versus 62 in the baseline. Line-of-sight queries remained 204 in both builds.
- The preview-cache regression verifies one full gun target scan across three status ticks instead of one on each tick. Invalid targets or changed settings refresh immediately; firing bypasses this cache.

These are operation counts, not an FPS guarantee. Fixture runtimes varied with the live session and did not demonstrate a consistent latency improvement.

### Existing failures reproduced on both builds

- `TestMotionIntegration`: `JumpGravityPreserved` fails; steering, wall clamping, and landing checks pass.
- `TestObservedAimIntegration`: controlled-vertical and jump-gravity checks fail with identical numerical errors on baseline and updated builds.

These local-dummy motion probes remain unresolved. The performance update does not change the motion predictor or claim those probes pass.

Temporary benchmark counters were used only in local probe copies and are not included in the published script.
