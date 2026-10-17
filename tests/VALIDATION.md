# Validation — 2026-10-17

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
