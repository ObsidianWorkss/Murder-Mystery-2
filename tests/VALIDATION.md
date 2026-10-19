# Validation — 2026-10-19

## Release candidate 1.0.0-rc.41

- Luau 0.739 compiles `main.lua` and `loader.lua`; all 880 assertions pass: the previous 816, six keybind checks and 58 new streamer checks. The streamer harness extracts the shipped lifecycle and presentation manager rather than maintaining a second implementation.
- Streamer checks cover strict capture-exclusion readiness, HTTP/first-frame failures, finite viewport/item bounds, startup-off state, activation cancellation, pending/double activation, single-flight pacing, backoff, stale replies, unload, independent sanitized snapshots, explicit Off and restoration retries. Connection/snapshot failures preserve the hidden state. Property tests cover text/images/borders/scrollbars/cursor, unchanged visibility/input, latest observed game updates, new/denied/destroyed widgets and partial cleanup.
- Keybind checks cover F4 default, menu-open enable/disable, typing guard and preserving an existing saved F4 action.
- The x64 .NET Framework companion builds locally. Its `--self-test` passes 33 checks without constructing a native window: protocol/finite-value/item limits, tokens, allowed image hosts, actual loopback HTTP authentication/status/frame/clear requests, readiness refusal, closed-session late frames, fresh sessions, browser origins, transfer encoding and duplicate content lengths.
- The Windows companion window, native UI mirroring/input, actual Solara loopback support, DPI/multi-monitor alignment, focus/resize/respawn behavior and a saved OBS clip have **not** been tested. No capture exclusion result or complete HUD removal is claimed. World-space UI/health/name displays, 3D previews, external Drawing overlays and styling/image differences remain documented limits.
- No desktop input, OBS configuration or recording was performed for rc.41. Packaging includes allowlisted source and manual launcher scripts, with no connection tokens or access keys.

## Release candidate 1.0.0-rc.40

- Luau 0.739 compiles both scripts. All 816 assertions pass: 142 phone controls plus the existing 674 combat, release, triggerbot, aura, equip, visibility, voting, dodge lifecycle and side-dodge assertions.
- Extracted the shipped phone controller and bundled window startup guard. Checks cover default dock/hidden instructions/closed menu, unchanged desktop startup/HUD policy, primary versus More actions, shared setters, universal trigger toggling, mixed trigger state, actual refusal messages, errors, busy action rejection with Stop still available, deliberate Kill all start/stop, and menu/typing/input-mode/unload guards.
- Layout checks cover 320×568, 390×844, 430×932, 568×284, 667×339, 844×354 and 1024×732 usable canvases: bounds, native bottom-control reserve, dock versus More/weapon separation, fly/menu separation, short landscape rows and menu dimensions. These are geometry/controller checks, not screenshots or native touch tests. Dragging, actual MM2 inventory placement, notches, hybrid input changes and physical phone rendering still require live checks.
- A private one-time harness used the shipped key gate to accept the newly issued key and its trimmed lowercase form and reject an invalid key. Only the new hash is committed; the plaintext and verification harness are not packaged.
- The listed Roblox client timed out on a targeted status/viewport probe. Live rc.40 startup and phone touch behavior remain unconfirmed.

## Release candidate 1.0.0-rc.39

- Luau 0.739 compiles both scripts; 83 combat, 191 release, 58 triggerbot, 145 aura, 32 equip, 29 visibility, 60 voting, 32 dodge lifecycle and 44 side-dodge assertions pass (674 total).
- Extracted side planner, motion resolver, commit guard and real runtime recheck are tested with mocked geometry: perpendicular 4-stud selection, blocked side/route, unsupported floor, shortest sufficient expansion to 8, displacement cap, horizon/timing/finite-value guards, multiple incoming knives, falling vertical knives, predicted landing and held walking input.
- Commit checks cover fresh versus stale plans, cooldown (including failed movement), off/unload/mode/character changes, a new wall or knife during validation, a primary that disappears/turns away, reentrant movement and failed requests. Motion tests cover normalized attributes, physics, successive samples, immediate cached rechecks, stopped/discontinuous movement and invalid values. Mode preference saves separately from default-on session state.
- Native TestKnifeDodge preflight now includes supported side teleport planning and ledge refusal, but was not run against Roblox physics for this release. Mocked floor/collision checks do not establish native query behavior, accepted teleports or survival. No measured multiplier is claimed.
- Sent rc.39 to the listed client; its subsequent targeted probe timed out. Live initialization remains unconfirmed.

## Release candidate 1.0.0-rc.38

- Luau 0.739 compiles both scripts; 83 combat, 189 release, 58 triggerbot, 145 aura, 32 equip, 29 visibility, 60 voting and 27 dodge assertions pass (623 total).
- Code audit found that invisibility preparation called StopKnifeDodge, which unbound its render hook permanently; SetAutoKnifeDodge(true) never rebound it. Area teleport separately called SetAutoKnifeDodge(false). The lifecycle fix preserves the guarded loop across temporary pauses, rebinds on explicit enable and reserves destruction for unload. Area teleport cancels current movement instead of changing the setting.
- Extracted lifecycle and real area-teleport tests cover binding, temporary pauses, off/on, no duplicate hook, direct off guards, focus, character removal, detached diagnostics, Emergency stop, unload/queued callback rejection, unexpected frame-error handling/retry and preservation of explicit Off during teleport. Saved-settings checks verify previous Off values cannot disable the next default-on session. These checks do not simulate real incoming-knife geometry or establish survival.
- The previously responsive client disconnected; the remaining client entry timed out on a targeted status probe. Live startup, incoming-throw behavior and survival for rc.38 remain unverified.

## Release candidate 1.0.0-rc.37

- Luau 0.739 compiles both scripts; 83 combat, 187 release, 58 triggerbot, 145 aura, 32 equip, 29 visibility and 60 voting assertions pass (594 total).
- Reproduced rc.36's failure live with a temporary read-only observer. During an open voting window, the user's character touched both VotePad1.Pad and VotePads.Detector1, but the controller stayed Armed with zero resets. VoteInfoGui was enabled and its displayed count increased from 0 to 2, while every legacy Voting flag stayed false, Map stayed nil and Votes stayed 0. Count changes are not attributed to the user's vote.
- Extracted adapter/controller tests reproduce current enabled boards with obsolete false/nil/zero legacy values, ensure board count changes drive repeat progress, and cover disabled/hidden/incomplete/unreadable boards, missing containers, legacy-folder absence, stable map identity and precise waiting reasons. Current boards take precedence; fallback is for board absence only.
- Live rc.37 startup verified running state, the user's previously enabled repeat toggle restored for this active test, menu closed, metadata source VotingBoard and the correct closed-voting waiting status.
- The next live run completed three resets and three re-vote attempts, selected by Touch, and stopped with `3 respawn attempts complete`. Each re-vote requires observation of a different living character, so all three reset/return cycles progressed. The observed board-total increase was 5; this does not attribute all five votes to the local player. Voting subsequently closed and the user was back in the round. Snapshotted counters: Enabled=false, Phase=Idle, Respawns=3, Touches=3, Detection=Touch, MetadataSource=VotingBoard, ObservedIncrease=5. Attribution of individual additional votes remains unverified.

## Release candidate 1.0.0-rc.36

- Luau 0.739 compiles both scripts; 83 combat, 187 release, 58 triggerbot, 145 aura, 32 equip, 29 visibility and 46 voting assertions pass (580 total).
- Live read-only finding: the actual lobby touch volumes are VotePads.Detector1–3. VoteIcons.VotePad1–3 are separate displays approximately 6.9–7.1 studs from them. The previous adapter targeted displays for both initial selection and repeat touches. The new adapter matches detector and metadata by slot; an extracted-adapter regression requires the returned target to be the detector, not its display.
- Extracted controller/adapter checks cover own voting touch, occupancy fallback without Touched, reset of the exact original character, waiting for a new living character, physical return to the same detector, optional supplemental touch, unchanged counts and existing caps/cancellation. Reset adapter requests death and BreakJoints, refusing mismatched ownership. No map geometry is moved, including during cancellation/errors.
- Live rc.36 startup verified running state, Map Voting page, off/idle state, zero respawns/touches and matching console loaded message in the responsive client. No vote/reset was requested for this startup check. Actual respawn, repeated server vote acceptance and attribution of extra votes remain unverified.

## Release candidate 1.0.0-rc.35

- Luau 0.739 compiles both scripts; 83 combat, 187 release, 58 triggerbot, 145 aura, 32 equip, 29 visibility and 38 voting assertions pass (572 total).
- The extracted controller allows active invisible gun input without removing its record, seat or weld. Both weapon types wait during Parking, Attaching and RestoreFailed; disabling invisible knife use refuses input without revealing. Visible gun input, manual restore/error recovery and explicit non-weapon cleanup remain covered.
- Sent rc.35 to the connected client, but the subsequent value probe timed out. Initialization is unconfirmed. Actual server acceptance of shots while invisible and other-client visibility remain unverified.

## Release candidate 1.0.0-rc.34

- Luau 0.739 compiles both scripts; 83 combat, 187 release, 58 triggerbot, 145 aura, 32 equip, 23 visibility and 38 voting assertions pass (566 total).
- The extracted visibility controller retains its assembly and phase when guns enter the backpack or character during Parking, Attaching and Active. Gun ownership permits activation, actual preparation survives acquisition, and obsolete auto-reveal values cannot trigger restoration or load from saved settings. Existing gun-shot restoration, invisible knife use, manual restore, safe-position preservation and restoration failure/retry are covered separately.
- Sent rc.34 to the connected client, but value probes timed out and the console probe failed. Execution dispatch alone does not confirm initialization; live startup and acquiring a real gun while invisible remain unverified.

## Release candidate 1.0.0-rc.33

- Luau 0.739 compiles both scripts; 83 combat, 188 release, 58 triggerbot, 145 aura, 32 equip, 23 visibility and 38 voting assertions pass (567 total). New suites extract the shipped visibility and voting controllers, not copies of their implementations.
- Gun reveal tests cover backpack/equipped acquisition during Parking, Attaching and Active, seat/weld cleanup, preservation of current safe position, actual preparation cancellation, opt-out, already-owned refusal, missing older defaults and restoration failure/retry. Saved-settings tests persist the preference and refuse to load voting automation from older files.
- Voting tests cover no actions on enable, own versus other-player touches, first reset, new-character detection, paired touch and pad restoration, unchanged count cancellation, three-attempt maximum despite growing totals, voting/map/pad changes, conflicts, character changes, unload, respawn timeout, missing API/map, begin/reset/restore errors, newer external pad positions, direct off, menu preassignment and Emergency stop. Total-count changes are not attributed to the local player.
- Read-only inspection found RegularLobby.VoteIcons.VotePad1–3 with Map ObjectValue, Voting BoolValue and Votes IntValue. The voting Script runs on the server, and its source was not available; no verified reset/vote remote was found. The experiment uses an ordinary local humanoid death request and paired executor touches, with bounded timeout if no respawn follows.
- Live rc.33 startup verified running state, default-on gun reveal, Map Voting page/status card, both optional keys unbound, support snapshot and zero respawns/touches. Console reported rc.33 loaded. No resets or votes were requested for the startup check. Real gun pickup/observer visibility, respawn behavior during voting and duplicate server votes remain unverified.

## Release candidate 1.0.0-rc.32

- Luau 0.739 compiles both scripts; 83 combat, 185 release, 58 triggerbot, 145 aura and 32 equip assertions pass (503 total). The equip suite extracts the shipped recovery controller.
- Tests cover one delayed recovery, enabled/disabled firing state, native equip before/after the observer, holster in both callback orders, rapid double toggles, intermediate parent changes, processed/native versus consumed input, menu/chat/native-context guards, multiple/no tools, touch mode, pending respawn/death/focus/handle/unload cancellation, unrelated keys, failures, snapshot privacy and re-enabling.
- Read-only live investigation: no 1 binding from this script/CAS, no focused text or open menus; MM2 CoreGui Backpack disabled. Its custom BackpackContext.Item1 is enabled with a One binding. Native BackpackScript uses a cached slot array and toggles via EquipTool/UnequipTools. No owned weapon was present during the probes, so the failed press was not reproduced or assigned a definite cause.
- Live rc.32 startup verified running state, recovery enabled, equip status control, empty press/recovery counts, 1 still reserved and equip diagnostics in the support snapshot. The exact reported intermittent failure and recovery during an active weapon round remain unverified.

## Release candidate 1.0.0-rc.31

- Luau 0.739 compiles both scripts; 83 combat, 185 release, 58 triggerbot and 145 aura assertions pass (471 total).
- New extracted-source checks cover early completion of spent burst retries, extra ranged charge/flight feedback grace, full active time on stalled frames, independent unresolved reasons and bounded recent-run history, and survivor-only retry budgets. Retry filters protection, departure, target/server elimination, own/target respawn and round-end invalidation.
- A 23-target mock burst sends every contact without repeated full-roster queries from the reporter; a player leaving mid-burst is rejected by the direct lookup. No-target ordinary aura avoids ray queries on intervening heartbeats and resumes with fresh checks after its idle interval. These operation checks are not measured live speedups.
- Menu dispatch tests prove a failed retry never falls back to Start Kill all, failures preserve their messages/menu, and successful starts/retries close the menu exactly once.
- Live startup smoke: rc.31 running, 1000-stud radius, results/recent-history controls present. A retry refused because the local role was inactive preserved the menu and sent no knife attacks. The Retry key is None (unbound), and Burst / Nearest / Balanced preferences remain. No active-round kill-rate, through-wall damage, live CPU gain or successful murderer auto-close was measured.

## Release candidate 1.0.0-rc.30

- Luau 0.739 compiles both scripts; 83 combat, 181 release, 58 triggerbot and 118 aura assertions pass (440 total).
- New extracted-source regressions cover independent result snapshots, empty/sent/observed/unresolved counters, aimed-mode near stabs and distant target-locked charges, duplicate prevention, mode/input cancellation, blocked-path refusal and disabled prediction. Priority checks exercise nearest, sheriff-first and selected-player behavior with fallback in aimed mode and ordinary aura.
- Performance regressions cover unchanged custom visuals on Balanced startup, Low effects flags and guidance, background cadence changes, preserved combat switches, cache invalidation, restoring defaults, invalid choices and reapplying a saved low preset. Extended preview caching is exercised alongside fresh real attack selection. Mode, priority and performance settings survive save/reload and reset.
- Live smoke: rc.30 running with result panel and all selectors. Aimed throws, Sheriff first and Low effects API changes synchronized the visible-control values; Low effects changed visual flags/cadence while preserving Aim and trigger settings. Original mode, priority, preset and visual preferences were restored. Settings serialization included the new choices. No combat requests were sent during these checks. Active server kills, accuracy, mobile layout and measured FPS gains remain unverified.

## Release candidate 1.0.0-rc.29

- Luau 0.739 compiles main.lua and loader.lua; 81 combat, 170 release, 58 triggerbot and 96 aura assertions pass (405 total).
- The extracted Kill all controller, burst adapter and contact reporter send same-frame contacts for obstructed and distant mock targets without calling the visibility function at any layer. An error-raising visibility stub proves the Kill all path does not use it. New cover during a burst no longer discards the next eligible player; ordinary aura still queries visibility and rejects blocked targets. Request-only counters do not imply confirmed damage.
- Additional regressions stop a burst while restoring a previously active aura, and replace the queue during its first contact. Neither case allows old remaining contacts or counter writes to continue. Existing range, protection, role, death, respawn, cooldown and trigger visibility regressions pass.
- Live startup smoke verified rc.29 running, menu readiness, a 1000-stud radius, inactive queue and zero bursts. The console reported rc.29 loaded. No combat requests were sent for this smoke check; actual server acceptance of off-screen/obstructed contacts and through-wall kills remain unverified.

## Release candidate 1.0.0-rc.28

- Luau 0.739 compiles main.lua and loader.lua; 81 combat, 170 release, 58 triggerbot and 92 aura assertions pass (401 total).
- Extracted controller, burst adapter and real contact reporter verify two targets receive requests on the first ready frame through one native swing, no second burst occurs during cooldown, survivors are revisited together, and requests do not count as kills. Two distant fake players at 800 and 999 studs are contacted in that same swing; no throw charges. Range 1000 is accepted and 1001 refused.
- Each contact is rechecked after the previous contact: new protection, respawn, death, allied role, obstruction and range changes skip later targets. One failed contact does not prevent another player from receiving a request. A stop during delivery prevents remaining contacts and preserves the stop status. Existing queue deadlines, feedback and recovery tests remain.
- Live startup smoke: loaded rc.28 into the current MM2 public client; running state, the menu range control, 1000-stud migrated radius, zero bursts and rejection of 1001 were verified. The console reported rc.28 loaded. No combat request was sent during this smoke check. Server acceptance of multiple contacts in one swing and actual extended damage distance remain unverified.

## Release candidate 1.0.0-rc.27

- Luau 0.739 compiles main.lua and loader.lua; 81 combat, 170 release, 58 triggerbot and 88 aura assertions pass (397 total). Tests extract shipped code into mocked clients; they do not establish real server damage or fire rate.
- Queue regressions cover retries of living targets, fair rotation, temporary obstruction/range recovery, observed deaths during cooldown, unresolved results, three sent-attack limit, 30-second active deadline even without a knife, pause timing, protection, respawn, departure, role loss and unload.
- Ranged adapter checks verify target-locked throws beyond stab reach, required prediction, cancellation on stopped/replaced queue, menu pause and range changes. The extracted real throw function also rejects a deferred automatic release after cancellation.
- Trigger checks cover first-frame acquisition, the 150 ms request bound, manual-shot/toggle continuity, a 750 ms unanswered-feedback window, tool readiness, visibility, input pauses and exclusion checks. Inspected the current native GunClient, which sends through Shoot without a fixed local 3-second interval.
- Live startup smoke: rc.27 loaded in the connected MM2 public client, menu slider initialized at 60, the range setter accepted 200 and refused 201, and 60 was restored. Both triggers enabled, reported the menu/input pause, and were switched off again; zero trigger shots or stabs were sent. No startup error appeared in the inspected console entries. Live combat accuracy, accepted aura distance, ranged kills and measured reaction time remain unverified.

## Release candidate 1.0.0-rc.26

- `main.lua` and `loader.lua` compile with Luau 0.739; 80 combat, 170 release, 56 triggerbot and 76 aura assertions pass (382 total).
- 24 new anti-fling assertions: normal and turning players stay solid, spinning or launched players are shielded and released after 3 s, walking, turning, speed boost, jumping, flying and a 700 studs/s fall are left alone, sideways launches, spins and floor slams are undone, your own fling and invisibility are never undone, the post-fling wait, off and unload restore collisions, and an error switches it off with its reason shown.
- Live on an 8-player Murder Mystery 2 server: over 20 s of normal play, other players peaked at 19.7 rad/s spin and 65 studs/s, and your own turning reached 20 rad/s. The spin limits were raised from 40 to 60 rad/s after this, and nobody was shielded. A one-frame 400 studs/s sideways launch on your own character ended 0 studs from the start, and a 200 rad/s spin was stopped. Cost per frame: 48.6 µs for the shield scan and 16.4 µs for the launch guard. No console errors, one menu.
- Not yet observed against a real flinger.

## Release candidate 1.0.0-rc.25

- `main.lua` and `loader.lua` compile with Luau 0.739; 80 combat, 146 release, 56 triggerbot and 76 aura assertions pass (358 total).
- 19 new saved-settings assertions: first start, write-once-per-change, load of switches, sliders, theme, keybinds and protected players, ping never saved, wrong or unknown values ignored, unreadable file, no file access, failed write, and reset.
- Live on a Murder Mystery 2 server: the running copy wrote 58 settings (no ping) with Roblox's own JSON encoder. After changing X-ray strength, theme and a keybind, unloading and starting a fresh copy, all 58 loaded and the slider, theme picker and key box showed the saved values. Reset settings restored the defaults and saved them; no console errors; one menu throughout.

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
