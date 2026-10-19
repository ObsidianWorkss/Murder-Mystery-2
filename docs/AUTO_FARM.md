# Standalone currency farm

This separate script starts automatically and creates no UI. The default loader uses normal character walking through computed paths to `Coin_Server` pickups. Ground mode does not change walking speed, collisions or the character's position directly. Both modes skip collected/deleted coins and retry unreachable targets after a delay.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ObsidianWorkss/Murder-Mystery-2/refs/heads/main/auto-farm.lua"))()
```

Use the current branch's `auto-farm.lua` for an offline copy. It is independent of the menu script and does not need the menu's access-key prompt. Earlier fixed release archives may not contain it.

## Experimental underground tween mode

This is the prone movement style: turn the character flat, disable its body collisions, sink below the pickup plane and slide between coins with linear CFrame tweens. It uses a four-stud offset below each pickup, nominal **48 studs/second travel** and **12 studs/second sink/pickup** stages, then approaches the actual server pickup from below for contact. The travel setting is three times the original 16; this is a configured speed, not a measured collection multiplier. It does not walk along a normal path or require a clear corridor. Faster travel may increase position-rejection risk.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ObsidianWorkss/Murder-Mystery-2/refs/heads/main/auto-farm-underground.lua"))()
```

The thin loader selects underground movement for one startup of the shared core. It refuses an older downloaded core that lacks movement support. The normal loader still selects Ground on a later run. Both variants share the same stop function, full-bag handling and event-currency crate buyer.

Underground mode holds a flat orientation and tracks body collision values for cleanup. End, replacement, round/death cancellation or a movement error cancels the tween and ends any optional paired executor touch. For a living character on the same loaded map, cleanup attempts to return it upright to a surface before restoring body collisions and humanoid controls; it does not move a dead/replaced character or take over an active invisibility/fling operation. Stop underground mode before enabling another movement feature. A physical nudge is used at pickup when the executor touch API is unavailable; native awards remain subject to server validation.

Cleanup uses only a nearby detected surface. Missing or distant floor queries preserve the current position and restore upright orientation; they never teleport back to the session's original location. If this leaves the character stuck, use the game's normal manual reset. Tween completion also checks the actual root position before advancing or reporting pickup contact. The orientation constraint is disabled while a tween controls rotation, then enabled at rest. These are movement correctness fixes, not a verified fix for an Invalid position kick.

**Experimental:** the earlier underground-flight prototype caused an Invalid position kick. A subsequent short run with the faster tween/pose variant enabled received 13 server collection events. That does not verify long sessions or protection from another kick. It does not hide position updates from the server, bypass anti-cheat, guarantee invulnerability or guarantee that the entire body stays hidden during pickup. Existing reset and purchase behavior also remains subject to server validation.

Press **End** or run this to stop movement and further crate requests:

```lua
getgenv().MM2AutoFarm.Stop()
```

On a phone, run the stop command through the same scripting environment. No phone buttons are added. Re-running either script stops the previous copy first. You can inspect `MM2AutoFarm.Snapshot()`, `MM2AutoFarm.GetMovementSnapshot()`, `MM2AutoFarm.GetThreatSnapshot()`, `MM2AutoFarm.GetReconnectSnapshot()` and `MM2AutoFarm.GetCrateSnapshot()` without opening a menu.

## Low-graphics farming

For an already joined MM2 client, this separate loader selects the same experimental Underground farm with 3D rendering disabled where the executor permits it:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ObsidianWorkss/Murder-Mystery-2/refs/heads/main/auto-farm-low-graphics.lua?farm=20261020.1"))()
```

It requests a 20 FPS cap only when both `getfpscap` and `setfpscap` are available and a valid previous cap can be saved. An existing cap of 20 or below is retained. Missing/failed rendering or FPS APIs leave that setting unchanged and appear in `MM2AutoFarm.GetGraphicsSnapshot()`. This loader adds no UI and does not remove the map, coins, GUI state or game scripts. Native UI/other overlays can remain visible. Physics, pickup confirmation, buying and reconnect keep their existing logic; lower frame rates can affect native collection timing and still need live validation.

End/Stop and replacement release the graphics settings owned by the farm. Known previous rendering state is preserved; when the engine does not expose its rendering getter, explicit cleanup reenables 3D. A later external FPS change is respected. Failed restoration remains visible as `RestorePending`; call `MM2AutoFarm.RestoreGraphics()` to retry. To restore graphics while leaving the current farm running, use the same function. Reconnect startup retains the selected low-graphics mode. The normal Ground/Underground loaders leave rendering/FPS settings alone.

A helper count of 99 means 99 account records, not 99 running players. This loader neither starts clients nor bypasses multi-client restrictions. Each instance still has CPU, memory and network costs; turning off 3D does not establish a supported number of simultaneous players. No 99-client load test or live low-graphics farm test has been performed.

## Pickup confirmation and retries

The scanner finds actual `Coin_Server` parts under each recognized CoinContainer, including nested parts. A touch attempt is not a collected coin. `Attempts`, raw `ServerEvents`, removed/flagged targets and `PickupEvents` are separate counters. PickupEvents correlate a matching currency's increasing server bag count with a nearby selected pickup; the event does not identify the individual coin, so this is not exact per-coin attribution.

Underground mode waits 0.9 seconds after contact. If the target is still eligible and no nearby matching bag increase was observed, it retries at up to two alternate contact positions, then skips the unconfirmed target temporarily. Later attempts overlap the actual pickup more deeply and may briefly expose part of the body above the floor. An absent/failing executor touch API uses a short physical nudge. Retries remain subject to position and collection checks; no reward is forced. `Retries` and `Unconfirmed` expose failures without labelling them successful collections. Set `MaxPickupRetries` in the local config to change the cap. Ground mode retains ordinary physical collection without these underground contact-position retries.

## Role-opponent avoidance

Avoidance is on by default, with a 24-stud radius. Known Classic murderers avoid Sheriff/Hero; Sheriff/Hero and Innocent avoid Murderer. Infection handles Zombie/Survivor opponents, and FreezeTag runners avoid Freezers. Known teammates and harmless roles are not automatically treated as threats. The main script's context supplies current targeting/frozen-state eligibility when available; otherwise the farm reads CurrentRoundClient role rows and character/weapon information. Unknown roles or modes use a conservative visible-weapon fallback.

Threatened pickups are skipped. An existing underground session retreats to its saved travel depth when a nearby role opponent approaches, holds there without pickup touches, and resumes after the threat clears. It does not sink farther every frame or surface merely because all remaining pickups are threatened. Full-bag reset can wait while this hiding pause is active. Set `AvoidOpponents=false` or change `DangerRadius` in the local config to adjust it.

This is avoidance, not invulnerability. It does not disable weapons, change server health/roles, prevent distant gunfire, conceal server positions or guarantee survival. Opponent positions, roles and threats can change between scans.

## Long sessions and reconnect

`AutoRejoin=true` has **no attempt or session-duration limit**. Recognized disconnect/kick messages schedule a retry after five seconds; failed requests increase the delay to 10, 20, 40, 80 and then 120 seconds. The delay stays at two minutes while failures continue. Duplicate notifications cannot create concurrent teleports, and a 30-second watchdog handles a request that never completes. Access-denial, permission and ban messages stop retries.

An accessible error-notification signal and executor teleport queue are required. Resume code is queued once per departing client, retaining movement choice. The new client discovers its own current event/shop/balance again; there is no consumed retry budget. Download failures and stale cores are retried with increasing delays. A token prevents duplicate queued copies from starting multiple farms. Stop or End cancels pending retries/downloads and removes owned hooks. Already queued code or a teleport in progress cannot be recalled from the departing client; Stop/End remains available in the arriving bootstrap.

`RejoinBeforeIdle=true` also watches the native player Idled event. Once it reports 15 minutes, a lobby interval with no movement or pending purchase can request a proactive rejoin before the engine disconnects the idle client. Returning input cancels a pending idle request. It does not inject desktop input, launch clients or keep a sleeping/closed PC running. The engine's idle detection and automatic disconnection are documented under [Player.Idled](https://create.roblox.com/docs/reference/engine/classes/Player#Idled).

A pending or ambiguous purchase before reconnect carries a purchase-pause flag so the next client cannot blindly repeat a possible charge. Farming and reconnects can continue; buying remains paused in that chain. A native queue exception can retry later without teleporting first. A failed movement cleanup stops reconnect instead of leaving competing controllers.

Roblox may refuse client teleports after a disconnect, and some executors cannot resume at all. This is best-effort recovery; it does not bypass bans/position validation or relaunch Roblox after a crash. Set `AutoRejoin=false` or `RejoinBeforeIdle=false` to disable the respective options. See [TeleportService](https://create.roblox.com/docs/reference/engine/classes/TeleportService).

## Full bags and rounds

The script reads the native bag UI and the server's `CoinCollected` event. It stops targeting a full bag. Once all known bags are full and a server capacity event has confirmed fullness, it requests one character reset after a one-second delay. It does not reset repeatedly in the same round, reset in the lobby, or treat a GUI flag alone as permission to reset. The new round clears capacity and retry state. A reset request does not prove a respawn or banked rewards.

Set `ResetWhenFull=false` in the local script's `config` table to disable this behavior. Death, frozen characters, lobby/map departure, missing paths and round end pause movement. Active invisibility, fly, noclip and other conflicting movement actions in the main script also pause it; their preferences are not changed. Speed boost pauses Ground mode, but is allowed in Underground mode, whose tween speed is independent of WalkSpeed.

## Event currency and automatic crate openings

Purchases are enabled by default. The buyer reads the native `GetEvents` response and merges current event MysteryBox/item data into its own catalog, without altering the game's catalog. The main active event's `CurrencyName` determines spending; pickup bag names such as `Candy` are not assumed to be currency IDs. It checks again once a minute, and purchase selection pauses if the last successful check is older than three minutes. Only one discovery request is pending at a time.

The inspected active event is **Halloween 2026**: `Candies2026` funds **Halloween Box '26** (`Halloween2026Box`) at **600 Candy** per roll, with **Embersickle** listed as its godly. The same offer lists one Halloween Key as an alternative, but the farm does not spend keys. This information comes from the active server response, not the unused 2025 modules still present in the client. Future event IDs/prices are read from that server data rather than hardcoded. When no collectible-currency event is active, verified ordinary Coin offers can be used. A live Candy event never falls back to spending Coins, Gems, keys or Robux. No currency or premium bundles are purchased.

**The entire available selected in-game currency balance can be spent**, including what the account had before loading. There is no reserved starting balance, spending cap, crate-count limit, godly limit or time limit. Crates open one at a time in the lobby with at least ten seconds between successful results, and only when a full current price is affordable. The buyer waits for the corresponding currency debit before opening another crate. It never converts or substitutes currencies to make a purchase.

Smart selection prefers listed normal godlies missing from inventory, then explicitly listed chromas, using lower prices/more missing targets and a deterministic crate preference for ties. A local received-item overlay covers delayed inventory replication. Once all listed targets are owned it continues ordinary rolls; ownership is a preference, not a stop condition. Selection cannot improve random drop odds or prevent duplicates. Event reward rarity metadata recognizes godly/ancient results without inferring a chroma drop table or godly probabilities.

There is one pending unbox at most. A failed, timed-out or ambiguous result pauses buying to avoid repeating a possible charge; it does not mark it as a successful roll. A late/duplicate response cannot count twice. Stop cannot cancel a purchase already processing on the server. `StopOnGodly=false` is the default; an explicit true value remains available for an optional one-godly session. `AutoOpenCrates=false` disables purchases. These are local `config` settings.

`MM2AutoFarm.GetCrateSnapshot()` reports discovery status, active event/currency, selected crate/price, pending state, opened/godly counts and `SpentByCurrency` totals. `Spent` is a legacy summed count of nominal currency units; use `SpentByCurrency` when currencies change. Each client/account has independent state. The script does not sign accounts in, launch clients, transfer items or guarantee a godly.

## Movement and validation limits

The default Ground mode continues to use normal paths. Underground mode is an explicit separate loader, with no automatic fallback or concealment of movement requests. Server position validation and player attacks apply to both modes. See Roblox's [pathfinding guide](https://create.roblox.com/docs/characters/pathfinding), [tween playback documentation](https://create.roblox.com/docs/reference/engine/classes/TweenBase) and [orientation alignment documentation](https://create.roblox.com/docs/physics/constraints/align-orientation) for the underlying engine mechanisms.

The ground-path candidate initialized at native WalkSpeed 16 with PlatformStand false; its collection-event count increased from 3 to 31 and the user confirmed collection. Before the latest stop, an Underground candidate reported 100 server events, 57 nearby matching bag-count correlations, 97 arrival attempts and two reset requests, with zero purchases. Those counters measure different events; they do not prove exact coin attribution, banked rewards or accepted respawns.

The farm was stopped at the user's request before inspecting the Candy shop. A later read-only test of the updated shipped selector against native event/inventory data chose Halloween2026Box at 600 Candies2026, with one missing listed target and a 520 Candy balance. The farm remained stopped and Opened remained zero. No purchase, automatic reconnect or resumed live farm was tested for this update.

All four scripts compile. The 171 extracted-source farm assertions include a simulated 24-hour reconnect failure chain with over 700 attempts, fixed-size timer/queue behavior, cancellation, retry recovery and access refusal, plus 10,000 serialized Candy rolls over more than 30 simulated hours. Nineteen additional graphics/resume checks cover opt-in behavior, missing/failed APIs, prior rendering/cap preservation, external FPS changes, idempotent/retryable restoration, invalid values and reconnect preference. They also cover discovery/isolation of event currency, existing-balance use, continued rolls after owning godlies, per-currency debit accounting, duplicate responses and download/resume cleanup. Alongside the main runtime's 1,017 assertions, 1,188 pass locally. These simulations do not establish overnight native reliability, server movement acceptance, successful paid unboxing, executor resume behavior, idle prevention or godly drop rates.
