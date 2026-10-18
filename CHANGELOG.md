# Changelog

## 1.0.0-rc.39 — 2026-10-18

- Added default Side teleport dodge mode with saved Jump / sidestep alternative. Chooses the shortest clear, supported 4/6/8-stud perpendicular route, checking body sweep, endpoint space, floor, other tracked knives, vertical intersections, landing and continued walking input. Revalidates character, primary threat, route and fresh knife paths before movement. Unsafe/unavailable teleports fall back to ordinary dodge selection.
- Teleport requests use a 300 ms cooldown, expire stale plans, reject mode/off/unload changes and limit per-knife retries. Preserves character rotation/pivot offset and vertical velocity. No invisibility restoration is added.
- Added normalized direction, physical velocity and sampled-motion fallback, speed-based tracking distance and a 0.55 s teleport prediction window. Kept the 0.38 s ordinary movement horizon. UI/support counters distinguish movement requests from results; real server acceptance and survival remain unverified.

## 1.0.0-rc.38 — 2026-10-18

- Fixed invisibility preparation permanently unbinding knife dodge. Temporary pauses now cancel current movement; explicit Off unbinds, On binds again, and unload destroys the hook. Area teleports no longer silently switch dodge off.
- Auto knife dodge starts enabled on every load, ignoring saved or previous-session Off values. Explicit Off and Emergency stop remain effective for the current session.
- Added Auto dodge status, support counters and visible frame-error handling. Status explains input/focus/invisibility/character pauses. This does not guarantee dodging or verify live survival.

## 1.0.0-rc.37 — 2026-10-18

- Fixed the live failure where an actual pad touch during voting never selected a map. Current MM2 updates VoteInfoGui visibility/map/count while legacy VoteIcons Voting/Map/Votes remain false/nil/zero. The reader now prefers current boards and uses legacy metadata only when no current board exists.
- Disabled, hidden, incomplete or unreadable boards cannot start resets through stale legacy flags. A native Pad can serve as the physical target without legacy folders.
- Waiting status now distinguishes voting closed, missing pads, selection needed and named input/character conflicts. Support diagnostics include active-pad count, metadata source and selection detection method.

## 1.0.0-rc.36 — 2026-10-18

- Fixed map voting targeting display icons instead of the actual VotePads.Detector1–3 touch triggers. Display metadata is matched by slot; standing inside a detector can select it when Touched was missed.
- Re-voting now follows vote, reset, new living character, physical return to the same detector, then another vote. Reset requests death and breaks the owned character's joints. Map geometry is not moved; executor touches are optional supplements to physical contact.
- Paired touch cleanup, three-reset cap, timeout, voting/map-change cancellation and unchanged-count stop remain. Waits two seconds for repeated vote feedback. Real extra votes still require a live check.

## 1.0.0-rc.35 — 2026-10-18

- Gun firing no longer automatically restores the invisible character. Gun and knife inputs wait during invisibility transitions or incomplete restoration, retaining the assembly. Disabling Knife while invisible pauses knife input instead of restoring visibility.
- Manual restoration, emergency cleanup and explicit non-weapon movement cleanup remain. This does not establish server acceptance of shots or observer invisibility.

## 1.0.0-rc.34 — 2026-10-18

- Removed automatic invisibility restoration on gun pickup/equip and the gun-ownership activation restriction. Guns no longer cancel preparation or active invisibility. Removed its setting/key option; obsolete saved values are ignored.
- Existing shooting restoration, manual restoration and character cleanup remain. Experimental map voting is unchanged.

## 1.0.0-rc.33 — 2026-10-18

- Added saved, default-on Reveal on gun pickup: a gun in the backpack or character restores invisibility, including preparation phases. Owning a gun refuses a new activation while this preference is on. Existing restore error handling and shooting restoration remain.
- Added experimental Movement → Map Voting. Enable, then step on a live map pad to select it. Attempts at most three respawns, waits for a new living character, briefly moves the selected pad locally for one paired touch and restores it. Requests and changes in the server's total vote count are shown separately; extra votes are unverified.
- Stops on unchanged counts after a repeat touch, a 12-second respawn timeout, voting/map changes, conflicts, menus, errors, off, Emergency stop and unload. Never resumes from saved settings. Both new controls have unbound Movement key options.

## 1.0.0-rc.32 — 2026-10-18

- Added guarded recovery for missed native slot-1 weapon equips, on by default with a saved General setting. It observes input without binding/consuming 1, waits 120 ms, and makes at most one normal EquipTool call if the same single owned weapon stayed in the backpack without an equip-state change.
- Preserves native holstering and successful equips regardless of callback order. Rapid toggles, consumed input without native action, menus, chat, focus loss, respawn/tool replacement, ambiguous weapons, missing handles, disabled native context and unload cancel recovery. Disabled firing state alone does not prevent equipping.
- Added Weapon equip status and support-report diagnostics for key presses, native input observations, local recoveries, skips and failures. The exact intermittent failure remains unconfirmed; inspection found MM2 uses a custom hotbar while the normal Roblox backpack UI is disabled.

## 1.0.0-rc.31 — 2026-10-18

- Kill all finishes exhausted retry budgets after a bounded feedback grace instead of waiting out the full 30 seconds. Ranged mode includes charge and estimated flight time. Stalled frames count their full active time.
- Results show unresolved reason counts and five recent session summaries. Snapshots remain independent of live state. These reasons do not claim server rejection or attributed kills.
- Added Retry unresolved in Kill Aura and Combat results, with an optional unbound Combat key. It only retries eligible survivors of the last run; protection, departure, elimination, respawn and round-end checks prevent stale retries. A refused retry never starts a full queue.
- Successful menu starts and retries close the menu automatically; refusals preserve it and their reason text.
- Locked knife contacts use a direct player lookup and one candidate rather than repeatedly fetching/scanning the whole roster. Player departure is still checked. Ordinary aura backs off idle ray checks to 50 ms (100 ms under Low effects); trigger timing remains per heartbeat.

## 1.0.0-rc.30 — 2026-10-18

- Added Home → Combat results with session weapon totals and last-run Kill all contacts, bursts, started throws, observed eliminations, unresolved targets, skips and current status. Snapshots do not expose mutable counters or claim attributed kills.
- Added a saved Kill all mode selector: Burst retains same-frame contact attempts; Aimed throws uses clear nearby stabs and target-locked predicted throws at range. Mode changes stop the queue and pending automatic throws; native charge, stab and throw cooldowns remain.
- Added saved target priorities for aura and Kill all: Nearest, Sheriff first (including hero), and Selected player using the existing player picker. Missing/unavailable preferred players fall back to eligible nearest targets. Burst mode orders contacts rather than dropping other players.
- Added saved Balanced / Low effects presets. Low effects suppresses optional visuals and guidance, doubles background visual/dashboard intervals and extends the visual-preview cache. Actual attack prediction and trigger acquisition remain fresh. Balanced restores the affected visual defaults.

## 1.0.0-rc.29 — 2026-10-17

- Kill all attempts eligible off-screen or obstructed players without local line-of-sight checks. The change applies to candidate selection, burst delivery and the explicit KillAllBurst contact reporter. Ordinary aura and triggerbot visibility policies remain unchanged. Range, protection, role, character identity, cooldown and cancellation checks remain. Server acceptance and through-wall damage are unverified.
- Stopping or replacing a queue during contact delivery prevents further contacts from the old burst, including when ordinary aura was already enabled and is restored on stop.

## 1.0.0-rc.28 — 2026-10-17

- Kill all reports contact attempts for every clear, eligible player during one native swing, on the same heartbeat. It no longer waits for each player or charges a throw between targets. Every contact rechecks protection, character identity, role, range and line of sight. Contact failures do not block other eligible players; stopping during delivery prevents further contacts.
- Surviving players retain the existing three-attempt budget and 30-active-second deadline; native knife cooldowns apply between bursts. Status counts bursts and sent contacts separately from observed eliminations. Server acceptance and simultaneous kills are not guaranteed.
- Aura range cap and default raised to 1,000 attempted studs. Old defaults (6/60) and the previous 200-stud maximum migrate once; other custom active ranges remain. This is a client target radius, not a discovered server damage limit. Triggerbot is unchanged.

## 1.0.0-rc.27 — 2026-10-17

- Kill all revisits surviving targets instead of ending after one request each. Temporarily blocked or out-of-range targets remain queued while clear targets can be attacked. Attempts are capped at three per player and 30 active seconds. Status separates observed eliminations, unresolved players, skips and attack starts.
- Kill all uses aimed, target-locked knife throws beyond 6.5 studs instead of distant stab reports. Stops, menu/focus pauses, role changes and stale queue generations prevent deferred automatic throws from releasing. Server damage remains unverified.
- One Aura range slider controls the active 1–200 stud radius, default 60. The old 6-stud default is migrated once; other active custom ranges are preserved.
- Triggerbot still acquires visible on-screen targets every heartbeat. Removed its extra 3-second local gun wait; requests are bounded to one per 150 ms, wait up to 750 ms for unresolved feedback, and respect tool readiness. Native GunClient inspection found no fixed local 3-second timer. These intervals do not guarantee server fire rate or hits.

## 1.0.0-rc.26 — 2026-10-17

### Added

- Anti-fling, on by default (Movement → Anti-fling, with a status line and an optional key). A player spinning faster than 60 rad/s or moving faster than 250 studs/s stops colliding with you on your screen for 3 seconds after their last spike; everyone else stays solid. If you are launched or spun anyway, your speed is zeroed and you are put back where you stood in the same frame, with a "Fling blocked" message. Thresholds sit above everything normal play and the script's own movement do (walk and fly speed, jump power, long falls). It pauses while your own fling or invisibility moves you and for half a second after, and unload or switching it off restores every collision it changed.

## 1.0.0-rc.25 — 2026-10-17

### Added

- Settings are saved between runs. Toggles, sliders, keybinds, protected players and the menu theme are written to `MM2Universal/settings.json` (checked every 2 seconds, written only when something changed, and once more on unload) and loaded on every start, so a rejoin or a new server keeps them. Features that always start off still start off.
- The menu theme is now a saved setting.
- **Settings → Reset settings** puts every setting back to its default, sliders and keybinds included, and keeps protected players. **Saved settings** shows whether saving works.

## 1.0.0-rc.24 — 2026-10-17

### Fixes

- Only one copy of the script runs at a time. A live game had two copies running (two menus, two status panels), and their toggles undid each other: X-ray and invisibility stayed on after switching them off. Every start now claims a shared marker on your player, and an older copy that sees a newer claim unloads itself, even when it runs in a different executor environment.
- X-ray stores each part's original value on the part. A second copy no longer records X-ray's own 60% as the original, switching X-ray off clears parts changed by any copy, and the next start restores parts left by a copy that stopped without cleaning up.

## 1.0.0-rc.23 — 2026-10-17

- Added **Kill all** and **Stop Kill all** to Murderer → Kill Aura, with optional unbound keys in Combat keys. The action makes one pass through eligible players within the configured aura radius, respecting cooldowns, protection and clear paths. It reports requests and skips without claiming kills. Existing aura state is restored when the pass ends; explicit stops and character/role changes cancel the queue.
- Extended reach now permits up to 200 studs, with a 60-stud default. The previous 30-stud default migrates once; other saved ranges remain. This expands contact attempts, not the server's accepted damage range.
- Removed triggerbot's artificial polling timers: it checks on every heartbeat while enabled and ready. On-screen targeting, pause guards, gun/stab/throw cooldowns and exclusion checks remain enforced. Actual reaction time depends on client frames and network conditions.

## 1.0.0-rc.22 — 2026-10-17

- Automatic gun shots now use visible on-screen targets only. The policy filters body samples before prediction, filters predicted points, and rechecks both the current body point and the selected lead point before sending. It cannot fall back to an offscreen target. Manual Gun aim keeps its existing behavior.
- Ready-weapon aim checks run at a 50 ms minimum interval instead of 250 ms, with cheap readiness polling at most 60 Hz. Gun, stab and throw cooldowns still apply; this is a reaction scheduling change, not a server fire-rate change.
- Knife triggerbot now selects a clear nearby on-screen opponent without requiring direct cursor contact or a 0.1-second dwell. It uses the same body-point selection as clicked stab assistance, with an enforced screen filter and the normal 6.5-stud reach.
- Universal T and the working kill aura remain available. Aura code is unchanged from rc.21.

## 1.0.0-rc.21 — 2026-10-17

- Normal and extended kill aura now explicitly report the selected body contact after starting a swing. Normal aura previously relied on blade overlap; physical contact is no longer required to send its report. Server damage validation remains unchanged.
- Aura selects a clear body part instead of requiring a clear ray to the target's root, and revalidates that same part before reporting contact.
- Enabled aura waits through death, respawn and innocent rounds rather than switching itself off when the character changes. Explicit stops, unloads, and actions that stop aura still disable it.
- Status distinguishes contact requests from swings without contact reports and includes target distance. Range changes cancel outstanding aura contacts; invalid throw-speed values cannot bypass cooldowns.
- Adds 46 assertions covering the extracted aura controller, readiness function, swing adapter and actual contact reporter, including normal and extended requests without physical touch, automatic equip, partial cover, respawn and failures.

## 1.0.0-rc.20 — 2026-10-17

- Gun triggerbot now calls the exact `sendGun(record)` path used by a manual assisted click. It finds the known murderer and uses fresh prediction, timing and path checks, without requiring a direct cursor hit or crosshair dwell. Clear offscreen assisted shots work the same way as manual Gun aim.
- Removed the extra gun crosshair gate that could prevent an assisted shot from ever being attempted. A ready gun checks for a shot at most four times per second, preserving tool readiness, the 3-second request interval, unresolved-feedback handling, and existing pause conditions. Knife triggerbot still uses its crosshair and range checks.
- Added aim-check counts and a retained last-check reason to the status cards, so a pause or round change does not hide why a gun shot was rejected. Universal T still toggles both modes.

## 1.0.0-rc.19 — 2026-10-17

- **T** now toggles gun and knife triggerbots together. If either mode is on, T switches both off; otherwise it switches both on. The equipped weapon and role determine which mode runs.
- Added **Universal triggerbot** to Settings → Combat keys with a rebindable T default. Independent gun and knife binds remain available. Typing and menu input guards still apply.

## 1.0.0-rc.18 — 2026-10-17

### Crosshair triggerbot

- Reintroduces independent gun and knife triggerbots with fresh raycasts and a 0.1-second dwell on the same living character. No cached mouse target or nearest-player fallback. Gun requests use the strict preferred target; knives stay within 6.5 studs regardless of aura settings.
- Gun requests use a conservative 3-second local interval, including manual assisted shots, the tool's enabled state, and outstanding feedback. Knife requests respect stab and throw cooldowns and never cancel a charged throw.
- Both modes start off on every load and leave other settings unchanged. Both keys start unbound in Settings → Combat keys. Menus, chat, loss of focus, invisibility, fling, kill aura, and selected-player automatic attacks pause the triggerbot; Emergency stop and unload stop it.
- Matches the current WeaponService cursor and mouse-lock coordinates. Mobile requires mouse lock. Transparency traversal is bounded to eight raycasts; the active scan runs at most 30 times per second, failed predictions at most four times per second, and disabled triggers do no raycasts.
- Status cards report the blocking reason and successful request counts. Rejected gun/stab attempts no longer count as sent requests. Server acceptance, hits, and kills remain unguaranteed.
- Adds 75 triggerbot regression assertions and three keybind assertions. Existing manual gun prediction and knife behavior are unchanged.

## 1.0.0-rc.17 — 2026-10-17

### Removed

- The triggerbot and knife triggerbot added in rc.13 and rc.14: their module, menu toggles, the T key, the Combat key entries, the emergency-stop and unload hooks, the support-report flags and their tests. With it on, it fired the gun on its own and most of those shots missed. Normal gun aim is unchanged; its code is the same as rc.1.

## 1.0.0-rc.16 — 2026-10-17

### Keybinds for everything

- Every menu toggle and action can have a key, grouped into Keybinds, Combat keys, Movement keys, Visual keys and Action keys in Settings. New entries start unbound.
- The menu key (Right Shift) and the emergency-stop key (End) are rebindable and take effect immediately; they can move but never be cleared, and no other action can take them.
- A key and its menu toggle now run the same code, so a key behaves exactly like clicking the switch, including its refusal reason.
- The Home → Controls card shows your current menu and stop keys.

### Fixes

- Key names are looked up safely when the key cards are built. Two reserved names are not keyboard keys, and an unguarded lookup of them could stop the whole menu from opening.

### Performance

- X-ray works at most about 4 ms per frame while it fills in a map, so switching it on no longer causes a hitch; changing strength and switching off are cheaper again.

## 1.0.0-rc.15 — 2026-10-17

### Fixes

- Fly no longer blocks teleports (map, lobby, selected player), invisibility or fling. Fly held the character's PlatformStand, which those features treat as "not free to move"; they now release fly first, and fly resumes after a teleport.
- Refused actions show their reason as an amber toast instead of a grey "off". Pressing F8 when invisibility cannot start used to say `Invisibility off`; menu toggles do the same now.
- X-ray skips Terrain, and a part that refuses the change no longer breaks switching X-ray off, unloading or reloading.
- Toasts no longer overlap the status card on PC or the Up/Down and Fire buttons on phones; on phones they sit in the top strip.
- Esc or a mouse click cancels picking a key in Settings → Keybinds and keeps the current key.
- A refused unload no longer switches movement and X-ray off while the script keeps running.
- A custom pose that fails to load shows the real loading error.

## 1.0.0-rc.14 — 2026-10-17

### Murderer knife triggerbot

- Murderer → Knife Aim → **Knife triggerbot**, off by default: automatically swings your knife when aiming at a clear, living player within reach (6.5 studs or extended kill aura reach) while you are Murderer.
- Enforces an 0.85s knife swing cooldown, verifies line of sight via path obstruction checks, ignores other murderers or protected targets, and pauses while charging a throw, flinging, or invisible.
- Setting `Triggerbot` on PC or mobile simultaneously manages gun triggerbot as Sheriff/Hero and knife swing triggerbot as Murderer. Independent control is also available via the `KnifeTriggerbot` setting in the Murderer tab.

## 1.0.0-rc.13 — 2026-10-17

### Triggerbot

- Sheriff → Gun Aim → **Triggerbot**, off by default: automatically fires your gun when your crosshair or cursor aims at the murderer. It pauses while the menu or chat is open, while flinging or invisible, enforces weapon ready and cooldown checks, and skips protected or non-murderer players.
- PC keybind: bound to **T** by default, rebindable or clearable in Settings → Keybinds. Confirms with `Triggerbot on` / `Triggerbot off` toasts.

## 1.0.0-rc.12 — 2026-10-17

### Keybinds

- Removed **Hold Alt**: keybinds act on a single key press again, and Alt can be bound like any other key. Rebind or clear (Backspace) any key you hit by accident in Settings → Keybinds.

## 1.0.0-rc.11 — 2026-10-17

### Keybinds

- **Hold Alt**, on by default: keybinds only act while Alt is held, so brushing G or F during play never toggles anything. Switch it off in Settings → Keybinds for single-key binds. Alt itself is reserved.

### Toasts

- One toast at a time with a colored dot: green on, grey off, amber warning, accent info, or the role color. It slides in above the hotbar and replaces the previous one instead of stacking.
- Every menu toggle and key press confirms itself, for example `Fly on`.
- Round events: your role when a round starts, `You picked up the gun`, `You were eliminated` and `Gun dropped`.
- Visuals → HUD & Alerts → **Toasts** switches them off; keybind changes still confirm.

## 1.0.0-rc.10 — 2026-10-17

### PC keybinds

- Settings → **Keybinds** card with 16 rebindable actions: aim assist, gun aim, kill aura, player ESP, X-ray, fly, noclip, speed boost, jump boost, infinite jump, invisibility, animation pack, reveal roles, teleport to map, teleport to lobby and camera repair.
- Defaults: F6 aim assist, F7 gun aim, F8 invisibility, F10 camera repair (unchanged), plus F fly, N noclip, G speed, J infinite jump, K kill aura, V ESP and X X-ray. Reveal roles, teleports, jump boost and the animation pack start unbound.
- Keys never fire while typing (chat included), with the menu open, or in the mobile layout; the card is hidden on mobile.
- Reserved keys (movement, Space, Shift, Ctrl, number keys, Tab, `/`, I, O, arrows, E, Right Shift, End, F9, F11, F12) and mouse buttons cannot be bound. A key already in use moves to the new action; Backspace clears a bind; Reset keybinds restores the defaults.
- Each press shows one short confirmation such as "Fly on", or the reason it could not act.
- The old fixed F9 animation toggle is removed because F9 also opens Roblox's developer console.

## 1.0.0-rc.9 — 2026-10-17

### Animations

- **Animation pack** picker with 17 Roblox catalog packs: Astronaut, Bubbly, Cartoony, Elder, Knight, Levitation, Mage, Ninja, Pirate, Robot, Rthro, Stylish, Superhero, Toy, Vampire, Werewolf and Zombie. Choosing one swaps the whole movement set at once: three idles, walk, run, jump, fall, climb, swim and swim idle.
- Every pack ID comes from the Roblox Creator Hub catalog-animation table and was checked against the Roblox asset API as a Roblox-made animation (169 IDs, 0 failures).
- The pack you pick is saved, reapplied after respawn, and replaced cleanly when you pick another; Default restores your avatar's own animations.
- Single looping poses (Floating, Bend, custom ID) stay below the picker, labeled as single poses.

## 1.0.0-rc.8 — 2026-10-17

### New

- Visuals → **X-ray**: walls and the rest of the map turn see-through on your screen only, with a Strength slider from 20 to 90 percent (default 60). Players, tools, coins, the dropped gun and the script's own markers stay solid. Large maps fade in batches across frames, parts that load later are included, and switching off or unloading restores every part unless the game changed it meanwhile.

## 1.0.0-rc.7 — 2026-10-17

### Polish

- 73 status messages rewritten in one short style, for example `Gun ready  ·  name  ·  above` instead of `Magic Bullet ready: name / UpperTorso / above`, and `Paused  ·  close the menu or finish typing` instead of `Kill aura paused: focus Roblox / close menu / finish typing`. Cards titled Status no longer repeat the feature name.
- Kill aura range and extended reach are sliders instead of text boxes, so phones need no keyboard. Aura range says it applies while Extended stab reach is off.
- Every toggle has a short description.
- ESP, dropped-gun and guidance labels use the menu font.
- The window is titled MM2 Universal on every device, and the console load message names the version and how to open the menu.

## 1.0.0-rc.6 — 2026-10-17

### Mobile

- Fly gets on-screen **Up** and **Down** buttons while flying on a phone; hold one to rise or sink. Drag them by their grip like the weapon buttons.
- Holding the jump button now rises while flying, on phones and PC.
- The **Stop** button also appears while speed, jump, infinite jump, noclip or fly is on, since phones have no End key.
- The menu keeps a smaller screen margin on phones, so short landscape screens show more of it.
- Without a clipboard, Copy support report shows the report in its card, since phones have no developer console.

## 1.0.0-rc.5 — 2026-10-17

### Reveal roles

- Messages use emojis: `🔪 Murderer: @name • 🔫 Sheriff: @name`.
- After the sheriff dies, the player holding the gun is named: `🔪 Murderer: @name • 💀 Sheriff: dead • 🦸 Hero: @name`. The original sheriff and the hero come from the round data; a gun holder counts as hero before that data updates.
- You are still never named, and a protected hero is left out.

## 1.0.0-rc.4 — 2026-10-17

### New

- Movement card: speed boost, jump boost, infinite jump, noclip and fly, with sliders for walk speed, jump power and fly speed. All start off on load, pause while you fling or are invisible, never unfreeze a player the game froze, and switch off with End or Unload.

### Menu

- Tabs follow your role: Murderer (knife aim, kill aura), Sheriff (gun aim), Innocent (knife dodge, gun pickup), then Fling, Movement, Visuals, Players and Settings.
- Aim assist, the master switch, moved to Home.

## 1.0.0-rc.3 — 2026-10-17

### New

- Players → Chat → **Reveal roles** posts `Murderer: @name • Sheriff: @name` to chat. The card previews the exact message, never names you, skips protected players, refuses while you are murderer and waits 4 seconds between messages.

### Interface

- Status card rebuilt: role chip in the role's color, weapon state, one primary line, and a toned last-shot line when not compact. The whole card drags; the "MM2 · drag" label is gone.
- Overlay buttons now outline their edge instead of their letters; Fire is the accented primary, the MOVE bar is a grip, Stop is a quiet red pill.
- Status pill, murderer warning and ESP labels use the menu font, neutral surfaces, and short lowercase details.
- Shorter menu copy throughout; status cards are titled Status.

## 1.0.0-rc.2 — 2026-10-17

Same features and settings as rc.1.

### Menu

- 20 sidebar tabs reduced to 7: Home, Combat, Visuals, Character, Players, Fling and Settings.
- Each former tab is now a collapsible card inside its group; the first card in each tab starts open.
- Search still finds controls inside cards and opens the card that holds the result.

### Performance

- ESP refresh restyles a highlight only when it is new or the player's role changes, instead of rewriting nine properties per player every tick.
- Dropped-gun ESP and the legacy status labels write only values that changed.
- The aim marker no longer hides and re-shows itself every frame, and skips weapon lookups while the marker is off.
- Idle per-frame work is cheaper: knife dodge checks its setting first, the ghost appearance skips cleanup when nothing is applied, and input-mode detection no longer allocates a closure each frame.

## 1.0.0-rc.1 — 2026-10-17

First packaged release candidate. Existing access keys and the original loader URL remain supported.

### Release polish

- Version and release channel shown in the menu.
- Settings → Copy support report collects version, capability flags, settings, and counters without player identities, access keys, or shot payloads.
- Optional `loader.lua` reports download, compilation, and startup failures.
- Automated compilation and regression checks using pinned Luau 0.739.
- Reproducible ZIP packaging with per-file SHA-256 hashes and an archive checksum.
- Support guidance, issue template, third-party notices, and a live release checklist.

### Combat and performance

- Conservative gun timing checks, clear-target knife protection, offscreen knife acquisition, and clicked stab assistance.
- Native post-throw stab cooldown and release-time target/weapon checks.
- Fresh attack calculations with cached visual previews and bounded background motion sampling.
- Fewer duplicate timing rays, early rejection of failed conservative checks, and reusable line-of-sight filter storage.

### Known limitations

- Hits, damage, kills, pickup, and fling outcomes remain server-controlled.
- Two existing local-dummy motion probes fail identically in baseline and performance builds. See `tests/VALIDATION.md`.
- This release candidate's new menu/report controls have not been verified live because the Roblox client is disconnected.
- Device/executor compatibility and the full live checklist remain unverified; this is not a stable-release certification.
