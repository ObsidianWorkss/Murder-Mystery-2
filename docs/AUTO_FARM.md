# Standalone coin farm

This separate script starts automatically and creates no UI. The default loader uses normal character walking through computed paths to `Coin_Server` pickups. Ground mode does not change walking speed, collisions or the character's position directly. Both modes skip collected/deleted coins and retry unreachable targets after a delay.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ObsidianWorkss/Murder-Mystery-2/refs/heads/main/auto-farm.lua"))()
```

Use the current branch's `auto-farm.lua` for an offline copy. It is independent of the menu script and does not need the menu's access-key prompt. Earlier fixed release archives may not contain it.

## Experimental underground tween mode

This is the prone movement style: turn the character flat, disable its body collisions, sink below the pickup plane and slide between coins with linear CFrame tweens. It uses a four-stud offset below each pickup and a nominal 16 studs/second tween speed, then approaches the actual server pickup from below for contact. It does not walk along a normal path or require a clear corridor.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ObsidianWorkss/Murder-Mystery-2/refs/heads/main/auto-farm-underground.lua"))()
```

The thin loader selects underground movement for one startup of the shared core. It refuses an older downloaded core that lacks movement support. The normal loader still selects Ground on a later run. Both variants share the same stop function, full-bag handling and coin-funded crate buyer.

Underground mode holds a flat orientation and tracks body collision values for cleanup. End, replacement, round/death cancellation or a movement error cancels the tween and ends any optional paired executor touch. For a living character on the same loaded map, cleanup attempts to return it upright to a surface before restoring body collisions and humanoid controls; it does not move a dead/replaced character or take over an active invisibility/fling operation. Stop underground mode before enabling another movement feature. A physical nudge is used at pickup when the executor touch API is unavailable; native collection remains unverified.

**Experimental:** the earlier underground-flight prototype caused an Invalid position kick. This new tween/pose variant has not been verified for server acceptance or live collection. It does not hide position updates from the server, bypass anti-cheat, guarantee invulnerability or guarantee that the entire body stays hidden during pickup. It may cause the same kick. Existing reset and purchase behavior also remains subject to server validation.

Press **End** or run this to stop movement and further crate requests:

```lua
getgenv().MM2AutoFarm.Stop()
```

On a phone, run the stop command through the same scripting environment. No phone buttons are added. Re-running either script stops the previous copy first. You can inspect `MM2AutoFarm.Snapshot()`, `MM2AutoFarm.GetMovementSnapshot()` and `MM2AutoFarm.GetCrateSnapshot()` without opening a menu.

## Full bags and rounds

The script reads the native bag UI and the server's `CoinCollected` event. It stops targeting a full bag. Once all known bags are full and a server capacity event has confirmed fullness, it requests one character reset after a one-second delay. It does not reset repeatedly in the same round, reset in the lobby, or treat a GUI flag alone as permission to reset. The new round clears capacity and retry state. A reset request does not prove a respawn or banked rewards.

Set `ResetWhenFull=false` in the local script's `config` table to disable this behavior. Death, frozen characters, lobby/map departure, missing paths and round end pause movement. Active invisibility, fly, noclip, speed boost and other conflicting movement actions in the main script also pause it; their preferences are not changed.

## Coin-funded crate openings

The default is **Mystery Box #2**. The inspected native catalog lists a **1,000 Coins** price and Lightbringer/Darkbringer as possible godly rewards. The script rechecks that the catalog still offers that crate for Coins and lists a godly possibility before purchasing. It does not infer godly probabilities from the other rarity percentages.

The coin balance at script startup is reserved. A normal one-crate request can run only in the lobby, after the current balance exceeds that starting balance by the current crate price. This spends session balance growth, which is not attributed to an individual pickup. There is no fallback to Gems, keys, Robux or currency purchases.

Only one unbox request can be pending. After success, the script waits for the matching balance decrease and at least ten seconds before another attempt. An ambiguous or failed result stops purchases rather than retrying a possible charge. A known godly/chroma reward stops the farm and further rolls. Stop cannot cancel a purchase the server is already processing. Set `AutoOpenCrates=false` in the local `config` to disable purchasing.

Each client/account has its own local state. This script does not sign accounts in, launch clients or transfer items. Halloween bag identifiers and event currency are not assumed interchangeable with Coins; only an actual increase in the native Coins balance can fund the selected crate. Random rolls cannot guarantee a godly, and farming does not grant invulnerability.

## Movement and validation limits

The default Ground mode continues to use normal paths. Underground mode is an explicit separate loader, with no automatic fallback or concealment of movement requests. Server position validation and player attacks apply to both modes. See Roblox's [pathfinding guide](https://create.roblox.com/docs/characters/pathfinding), [tween playback documentation](https://create.roblox.com/docs/reference/engine/classes/TweenBase) and [orientation alignment documentation](https://create.roblox.com/docs/physics/constraints/align-orientation) for the underlying engine mechanisms.

The ground-path candidate initialized in the connected game at native WalkSpeed 16 with PlatformStand false. Its server collection-event count increased from 3 to 31, and the user confirmed collection worked. The inspected snapshot showed no crate requests or resets; full-bag reset, actual banked earnings, paid unboxing, godly rewards and long sessions across multiple accounts remain unverified live. The 59 local farm/buyer assertions cover controller, tween routing and spending guards, not native tween physics, path geometry or drop rates.
