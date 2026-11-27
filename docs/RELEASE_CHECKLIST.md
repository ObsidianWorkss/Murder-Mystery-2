# Release candidate checklist

Version: **1.0.0-rc.56**. Do not describe this candidate as fully verified until the pending live checks have been completed.

## Knife flight and floor targeting (rc.56)

- [x] Prefer central torso/head knife aim points instead of floor-skimming lower limbs.
- [x] Apply turn and braking motion predictions to knife trajectories, retaining the bounded flight-time solver and replication-age checks.
- [x] Adjust nearby flat-floor mouse fallback toward torso height without altering high-ledge/steep-slope throws or breaking manual input when raycasting fails.
- [x] Run 1,350 offline Luau assertions, compile five entrypoints, and validate package checksum.
- [ ] Record real knife trajectories and server hit registration against jumping, strafing and last-second turning players in a live MM2 Murderer round. Opponents remain able to react after release.

## Native manual knife throws (rc.55)

- [x] Keep manual E/right-click releases independent of charge-time target locks and allow cursor fallback with Require Clear Knife Target enabled.
- [x] Recalculate from the moving shooter's actual handle; use current cursor direction rather than cancel a manual release after a second movement.
- [x] Listen to the native WeaponService knife throw bindable for inputs routed through MM2's control system, with the charging guard preventing duplicate requests.
- [x] Run 1,344 Luau assertions and compile all five entry points.
- [ ] Verify live E/right-click/controller throw and actual server-registered trajectory in a Murderer round; simulator assertions do not prove a real hit.

## Moving-target gun and knife aim (rc.54)

- [x] Use bounded observed replication age for moving-target interception and retain a ping-only fallback when unavailable; reject unreasonably stale target data.
- [x] Use the same observation delay for knife flight-time solution and final offset refinement, including jumping targets.
- [x] Re-aim once from a moved throwing handle or firing attachment; cancel implausible or repeated displacement instead of firing toward stale geometry.
- [x] Automatically target broad torso hitboxes during high-vertical-speed gun shots and keep triggerbot scan cost bounded at high FPS.
- [x] Run all 1,340 Luau assertions and compile all five entry points locally.
- [ ] Perform controlled two-player live jump-spam, strafe, and 360-degree turn tests for both weapons, then compare server-reported results. A request being sent is not proof of a hit.

## Experimental local-seat invisibility recovery (rc.53)

- [x] A broken weld, detached seat, incorrect local assembly root or round-position correction drops the active state and schedules at most two safe delayed retries after successful restoration.
- [x] Retry is cancelled by explicit Off, emergency stop, death, replaced character, failed cleanup, or unload. No infinite seat/teleport retry loop.
- [x] The status reports a local seat assembly rather than verified invisibility to other players. Support diagnostics show local verification, retry count, and retry pending.
- [x] New extracted-source tests cover 14 recovery and cancellation assertions; all 1,314 Luau assertions pass (1,143 main-runtime, 171 farm).
- [x] Safe live rc.53 activation: the local seat became the assembly root and GetInvisibilityReport returned LocalAssemblyVerified=true and OtherClientsVerified=false. Manual Off restored the normal root and camera; Right Shift/F10 remained registered and five guarded subsystems reported zero errors.
- [ ] Full live retry after forced weld interruption: a round began before the isolated test could run safely. The extracted-source retry and cancellation tests passed.
- [ ] A second observer client is required to verify whether the character remains invisible to other players; no client-only result establishes that.

## Native opaque hitbox and cover checks (rc.52)

- [x] Compare local MM2 GunClient and WeaponService: native WeaponRaycast ignores Transparency==1; current live characters have transparent, queryable roots and opaque torsos.
- [x] Filter fully transparent and non-queryable gun hitbox candidates; prevent transparent collidable roots from short-circuiting wall/torso checks. Preserve equipment and excluded-player protection.
- [x] New extracted-source regression tests: 2 combat hitbox assertions and 5 cover-ray assertions. All 1,300 offline assertions pass (1,129 main-runtime and 171 farm); five Luau entrypoints compile.
- [x] Safe live rc.52 reload: TestCoverChecks, TestCampChaseAim and TestObservedAimIntegration pass, including the transparent-root/opaque-wall and transparent-root/opaque-torso cases. Right Shift/F10 remain bound, the cursor starts free, and five guarded updates report zero errors.
- [ ] Measure actual rc.52 request/reply/hit behavior in a live Sheriff round; no client-only test establishes a guaranteed hit rate.

## Aim and triggerbot regression (rc.51)

- [x] Five conservative timing hypotheses are centered on estimated shot arrival rather than including the target's old position and an extreme future prediction; the nominal ray is also checked.
- [x] Gun hitbox selection prefers an eligible center-mass target instead of choosing a smaller limb purely on sampled exposure quality. Knife priority behavior is unchanged.
- [x] A manual gun click without a valid assisted target falls back to the game's native mouse direction. Automatic screen-only triggerbot and strict target-locked requests cannot use this fallback; excluded-player path rejection remains active.
- [x] The full offline suite passes 1,293 assertions (1,122 main-runtime, 171 farm), and all five Luau entry points compile.
- [ ] Run the local aim/cover probes and compare real round shot-to-reply/hit outcomes after a safe rc.51 client reload. No client-only test can guarantee server hit registration.

## Gun feedback accounting and freshness (rc.50)

- [x] Pending shots that expire, overflow the eight-request queue or are interrupted by a successful unload are counted as unknown, with their shot IDs and distinct reasons retained in the bounded history.
- [x] Repeated cleanup does not double-count already removed pending shots. An older timeout cannot overwrite the result of a newer shot.
- [x] A late server reply remains visible for two seconds after it arrived, while the original shot's send time is preserved for diagnostics.
- [x] Full Luau 0.739 suite passes 1,285 assertions (1,114 main-runtime, 171 farm) and all five entry points compile.
- [ ] Reload rc.50 during a quiet lobby interval and verify the same menu/camera behavior in-game. Server hit-rate, FPS and request acceptance have not been validated for rc.50.

## Gun requests and feedback correlation (rc.49)

- [x] Automatic gun requests use the script's existing 1.5-second gun-ready interval instead of 150 ms; the first valid shot is immediate, and failed aim checks still respond to camera movement and short cache expiry.
- [x] Different shots with identical ray geometry can each match a distinct server reply, while duplicate and stale reply safeguards remain in place.
- [x] A real server reply remains visible in the gun HUD for up to two seconds when later aim checks are rejected; the current rejected-shot reason stays visible through triggerbot status.
- [x] Full offline suite passes 1,270 Luau assertions (1,099 main runtime, 171 farm), with all five entry points compiling.
- [ ] Verify new shot pacing, request-to-reply correlation and hit outcomes in a live Sheriff round. No client-side test can prove that the server accepted every request.

## Knife input and live read-only diagnostics (rc.48)

- [x] Manual E/right-click knife charge without an aim-assist target reaches the native cursor CFrame instead of being rejected by the default clear-target setting.
- [x] Strict automated throws still reject a missing target; a locked assisted target remains protected through release. Manual cursor fallback still refuses shots crossing excluded players and never switches to another player midway through charging.
- [x] Live read-only rc.47 inspection confirmed WeaponService:GetMouseTargetCFrame returns a valid CFrame, current menu bindings prioritize Right Shift above native mouse-lock, and five monitored update systems reported zero errors.
- [x] Full offline regression suite passes 1,258 assertions (1,087 main-runtime, 171 standalone farm), and all five Luau entry points compile.
- [ ] Verify E/right-click release and server acceptance in an actual knife round. The inspected live client had no knife or gun equipped; no guaranteed-hit or proven FPS improvement claim.

## Camera and combat resilience (rc.47)

- [x] Eight camera-guard fixture assertions preserve native Shift Lock, hold-pan and active camera rotation, and bound repeated stuck-cursor releases to a 50 ms retry period.
- [x] Six blade-scan fixture assertions isolate individual collision-query errors, limit error retries to one per 250 ms and verify automatic recovery.
- [x] Three support-report assertions cover aggregate triggerbot counters, blade-scan error counts and omission of player names/raw error messages.
- [x] Official Luau 0.739 compiles all five entry points and the complete offline suite passes 1,254 assertions (1,083 main-runtime, 171 farm).
- [ ] Check cursor handling, gameplay FPS, knife contacts and triggerbot outcomes after rc.47 is reloaded in a real MM2 session. The current live rc.46 read-only check found normal cursor behavior with no camera corrections; that is not rc.47 validation.

## Input and weapon restoration (rc.46)

- [x] Right Shift remains bound to open the UI when saved menu shortcuts change; no duplicate binding when Right Shift is already selected. Extra shortcuts can be replaced without removing Right Shift.
- [x] Extracted fallback handler opens the menu on Right Shift even when a native input handler marked that key processed. Typing and mobile-mode guards remain in place.
- [x] Gun hint visibility is restored to its original state. Knife callbacks preserve zero speed and active boost. Delayed weapon restoration does not override another newly equipped tool.
- [x] All five Luau entry points compile and 1,237 offline assertions pass (1,066 main-runtime and 171 farm).
- [ ] Verify the new menu shortcut and gun/knife restoration in a live MM2 session. Offline fixtures cannot establish the game's live input or server behavior.

## Aim reliability (rc.45)

- [x] Offline triggerbot fixtures cap unchanged-view rejected gun/knife scans near 40 Hz at a simulated 240 Hz heartbeat; camera movement, camera replacement, focus return and toggling reactivate a target check without the 25 ms wait.
- [x] Existing manual weapon and native Shift Lock paths were not modified. Triggerbot still respects role, cover, weapon readiness, exclusions and outstanding gun feedback.
- [x] Luau 0.739 compiles all five entry points and the regression suite passes 1,211 assertions (1,040 main-runtime plus 171 farm).
- [ ] Rejoin with rc.45 and compare actual gun/knife request counts, measured frame cost, hit outcomes and native input behavior. These are not verified by offline fixtures.

- [x] Prior rc.44 checks: 1,026 main-runtime and 171 farm assertions pass, including nine new classifier and network-delay checks.
- [x] Local fixture checks reject equipped weapon handles as valid avatar body hits and as learnable map cover.
- [ ] Compare gun hit paths, knife speed samples, request/reply correlation and confirmed outcomes against previous rounds. No guaranteed-hit claim.

## ESP, triggerbot and voting reliability

- [x] Both scripts compile; all 1,017 Luau assertions pass, including actual extracted ESP rendering logic, independent update recovery, stable-invisibility trigger guards and current nested voting layouts.
- [x] User-authorized complete live reload initializes rc.43. Classic recognizes one map/eight role rows and attaches all seven eligible player visuals; five guarded features report zero errors.
- [x] Already-enabled gun triggerbot sends automatic requests and reports cooldown/pending-feedback states. Request counts are separate from confirmed server outcomes.
- [x] Shipped voting reader finds three current nested pads read-only; voting stays off with no reset/contact requested.
- [ ] Verify native stable-invisibility shots without revealing, explicit invisible-knife preference, preparation/restoration guards and real observer visibility.
- [ ] Verify map replacement, event rounds and native focus/respawn/error recovery. Confirm server shot attribution and observed outcomes separately from requests.

## Halloween compatibility candidate

- [x] Both runtime scripts compile; all 1,017 Luau assertions pass, including 108 context/ESP/update-health checks and the existing event combat integration regressions.
- [x] Read native event role definitions and Zombie throw restriction; read-only Classic context probe recognizes current map, role rows and in-map characters.
- [ ] Check native role ESP/gun ESP/HUD/threat warnings in Infection and FreezeTag, including clean visuals and the optional companion view. Classic startup and attached player visuals are checked above.
- [ ] Verify Zombie conversion, frozen Runner state, death/respawn, map replacement and lobby/spectator transitions. Confirm the actual replicated frozen-state fields used by the current event server.
- [ ] Verify owned event gun/knife readiness, supported native attacks, teammate cancellation, Zombie throw refusal, triggerbot, aura and queue behavior. Record requests, accepted freezes/damage and observed outcomes separately.
- [ ] Check event map teleports, rule guidance, role-action group selection, manual role previews, existing movement/invisibility/dodge and unsupported-mode native weapon restoration.

## Windows streamer candidate

- [x] Both scripts compile; 1,017 Luau assertions and 33 headless Windows companion checks pass locally.
- [x] Source packaging excludes generated connection tokens. Windows CI builds and tests the companion without opening a window.
- [ ] Launch companion manually; verify Windows affinity acceptance, Solara loopback handshake, initial UI visibility, click-through menu controls, keyboard recovery and text editing.
- [ ] Verify normal/borderless windows, resize, DPI/multiple monitors, focus, minimize, respawn, dynamic native UI and multiple-client refusal/explicit PID.
- [ ] Verify connection loss, stale-frame expiry, failed property restoration/retry, companion exit, unload and reload against native GUI objects.
- [ ] Save an OBS Window Capture clip with Capture Cursor off. Compare player display and recorded menu, ESP, crosshairs, cursor and inventory. Document unsupported world UI, native health/name displays, external Drawing graphics and missing 3D/styling/images. Do not mark full capture support based only on a successful affinity flag.

## Automated checks

- [ ] GitHub workflow `Validate script` succeeds on the published commit.
- [x] Both `main.lua` and `loader.lua` compile locally.
- [x] Combat, loader, support-report, role-reveal, movement, x-ray, animation-pack, keybind, triggerbot, aura, saved-settings, anti-fling, equip, visibility, voting, dodge lifecycle, side-teleport, phone-control, streamer and game-mode/ESP regression suites pass locally (1,040 main-runtime Luau assertions; 171 farm assertions).
- [x] ZIP contents match `MANIFEST.json`; archive checksum matches `SHA256SUMS.txt`.

## Live checks

- [ ] Phone: initial closed menu, MM2 reopen, Pages picker, full-width settings, Invis/Speed/Trigger/Aura state and behavior, More actions, direct Stop, no instruction/inventory obstruction, dragging/reset, rotation, short landscape layout, notches and hybrid input switching. Check actual touch rendering separately from the passing geometry/controller tests.
- [ ] Side teleport: real incoming throws, correct perpendicular displacement, walls/occupied endpoints/ledges/slopes, multiple knives, walking input, mode switches, cooldown, server correction and survival. Run the expanded native TestKnifeDodge preflight before treating local geometry checks as verified.
- [ ] Auto dodge starts on after saved Off/Emergency stop; real incoming thrown knife jump/sidestep, invisibility pause/resume, area teleport continuity, explicit off/on, focus, respawn and unload. Distinguish a chosen dodge action from actual survival.
- [ ] Acquire/equip/fire a real gun while invisible; verify invisibility stays active, accepted shots and observer visibility separately. Weapon input during preparation must wait without revealing. Verify manual restoration and error recovery separately.
- [ ] Opt into map voting during an active lobby vote: real current Pad or legacy Detector selection, character reset, new living character, physical return to that same pad and another accepted vote; off/End/unload and voting end stop it. Confirm extra vote attribution separately from other players changing the total; duplicate votes remain unverified.
- [x] Reproduced rc.36 staying Armed despite own pad touches during an active vote: current board enabled and count increasing while all legacy metadata remained inactive. Current-board precedence is covered by extracted adapter/controller tests.
- [x] Live rc.37 completed three reset/new-character/return/re-vote cycles and stopped at its cap. Board total rose by 5; individual vote attribution and the remaining cancellation scenarios above are separate pending checks.
- [ ] Kill all: Burst and Aimed throws, priorities, queue/charge cancellation, prior aura restoration and actual server outcomes. Measure accepted damage distance rather than treating the 1,000-stud client radius as accepted range.
- [ ] Aura: normal contact without blade overlap, extended contact acceptance, partial cover, automatic equip and respawn recovery while murderer. Distinguish sent requests from observed server damage.
- [x] PC triggerbot smoke check: rc.18 running, both status cards present, independent menu setters, unchanged master aim, unbound keys, both modes off, and no trigger requests sent.
- [ ] Triggerbot: visible on-screen gun and knife acquisition without cursor contact, offscreen cancellation including camera turns, reaction scheduling, weapon cooldowns, independent toggles, pause/resume, emergency stop and reload-off behavior. Record sent requests separately from matched server feedback and observed eliminations.
- [x] Saved settings: a change is written within 2 s, a fresh start loads it (slider, theme and keybind shown), and Reset settings restores defaults and saves them.
- [x] Anti-fling: a one-frame 400 studs/s launch and a 200 rad/s spin on your own character are undone in the same frame; 20 s of normal play in an 8-player server shielded nobody.
- [ ] Anti-fling against a real flinger (shield on their parts, no launch).
- [ ] One copy: running the loader again or from a second executor leaves exactly one menu; X-ray and invisibility switch off cleanly afterwards.
- [ ] First launch: valid key, invalid key, cancel, and saved-key behavior.
- [ ] Toasts: every toggle, key press, role start, gun pickup, elimination and gun drop shows one message; the Toasts setting silences them.
- [ ] Keybinds: default keys act on PC, nothing fires while chatting or with the menu open, rebinding and Backspace work, the card is hidden on mobile.
- [ ] Animation packs: each pack changes idle, walk, run, jump, fall, climb and swim; switching packs and Default restore cleanly; the choice survives respawn.
- [ ] X-ray: walls fade on a large map without a freeze, players and the gun stay solid, Strength updates, off restores the map.
- [ ] Keybinds: the menu opens with every key card; rebinding the menu and stop keys works at once; a key toggles exactly like its menu switch; X-ray fills in on a large map without a visible hitch.
- [ ] Fly: teleport to map, lobby or a player, invisibility and fling all start while flying; fly resumes after a teleport.
- [ ] Movement: speed, jump, infinite jump, noclip and fly work on PC and mobile, restore on switch-off, and survive respawn without leftovers.
- [ ] Menu: role tabs, cards open and close, live status text resizes its card, search opens the card holding a result.
- [ ] Status card, Fire/Throw/Stop buttons, status pill and murderer warning render cleanly on PC and mobile; the card drags from anywhere.
- [ ] Reveal roles: emojis render in chat, the hero appears after the sheriff dies, preview matches the round, one message posts, the cooldown blocks a second press, and it refuses while you are murderer.
- [ ] PC: Right Shift menu, click fire/stab, E/right-click throw, End stop.
- [ ] Mobile: dragging, Fire/Stab, Throw, Stop, fly Up/Down hold, the menu fitting a phone in landscape, and switching input modes.
- [ ] Support report: clipboard success and unavailable-clipboard fallback.
- [ ] Equip/unequip, role transitions, respawn, target death, and player departure.
- [ ] Gun/knife toggles and exclusions; no attack during focused text input.
- [ ] Unload restores handlers; re-running creates one functional UI with no stale callbacks.
- [ ] Re-run `TestCoverChecks` and `TestCampChaseAim`.
- [ ] Resolve or explain `TestMotionIntegration` and `TestObservedAimIntegration` failures with reproducible evidence.

Record device, executor, place version, test date, result, and any observed errors. Automated mock tests do not certify server behavior or device compatibility.

- [ ] rc.27 combat: verify Kill all retries survivors, uses predicted ranged throws, retains blocked targets, stops after 30 active seconds, and cancels charged throws. Measure server acceptance and trigger reaction during an active weapon round.

- [ ] rc.28: observe whether the server accepts several contacts in one swing, measure effective damage distance, and check unresolved results. Same-frame request tests do not establish simultaneous kills.

- [ ] rc.29: distinguish sent obstructed/off-screen Kill all contacts from actual server eliminations; verify ordinary aura and triggerbot still retain their visibility checks.

- [x] rc.30 startup/settings smoke: result panel and selectors exist; mode/priority/preset changes synchronize their controls; Low effects changes visuals/cadence while preserving combat switches; new choices serialize.
- [ ] rc.30 active combat: both modes, aimed-throw cancellation, selected-player/sheriff priorities, observed results, and measured performance on PC/mobile.

- [x] rc.31 extracted tests: early completion and flight grace, full stalled-frame deadline, survivor-only retries and invalidation, bounded independent history/reason snapshots, direct contact lookup, idle scan backoff, and menu start/retry dispatch.
- [ ] rc.31 live combat: server outcomes, survivor retry after a real run, measured CPU cost, and automatic menu close after a successful murderer action.

- [x] rc.32 compile/regression/startup: recovery setting/card/support fields, reserved 1 key, native toggle order, delayed equip, cancellation and privacy.
- [ ] rc.32 active weapon round: capture the actual missed 1 press, verify native-input observations and a real local recovery, and verify normal repeated holstering with the native hotbar.
