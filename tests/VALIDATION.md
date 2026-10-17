# Performance build validation — 2026-10-17

Baseline: `099b7e2` (`ConservativeGun`). Updated build: `Performance`.

## Passed

- Full bundled script compiled with Luau 0.739.
- 58 assertions in `python tests/run.py`: combat behavior, conservative timing checks, preview invalidation, and attack-time cache bypass.
- Live `TestCoverChecks`: invisible solid blockers, helper filtering, learned blockers, non-queryable blockers, and unobstructed paths.
- Live `TestCampChaseAim`: all checks passed in five runs on each build, including stationary targets, close approaches, narrow visibility, and full cover.

## Measured work reduction

- A two-second live sample recorded 79 motion sweeps across 217 frames. Previously the heartbeat traversed the roster every frame.
- The controlled aim fixture used 57 body-ray queries per run versus 62 in the baseline. Line-of-sight queries remained 204 in both builds.
- The preview-cache regression verifies one full gun target scan across three status ticks instead of one on each tick. Invalid targets or changed settings refresh immediately; firing bypasses this cache.

These are operation counts, not an FPS guarantee. Fixture runtimes varied with the live session and did not demonstrate a consistent latency improvement.

## Existing failures reproduced on both builds

- `TestMotionIntegration`: `JumpGravityPreserved` fails; steering, wall clamping, and landing checks pass.
- `TestObservedAimIntegration`: controlled-vertical and jump-gravity checks fail with identical numerical errors on baseline and updated builds.

These local-dummy motion probes remain unresolved. The performance update does not change the motion predictor or claim those probes pass.

Temporary benchmark counters were used only in local probe copies and are not included in the published script.
