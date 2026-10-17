# Validation — 2026-10-17

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
