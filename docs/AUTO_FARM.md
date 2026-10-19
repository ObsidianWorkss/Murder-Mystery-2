# Standalone coin farm

This separate script starts automatically and creates no UI. It uses normal character walking through computed paths to `Coin_Server` pickups. It does not change walking speed, collisions or the character's position directly. It skips collected/deleted coins and retries unreachable targets after a delay.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ObsidianWorkss/Murder-Mystery-2/refs/heads/main/auto-farm.lua"))()
```

Use the current branch's `auto-farm.lua` for an offline copy. It is independent of the menu script and does not need the menu's access-key prompt. Earlier fixed release archives may not contain it.

Press **End** or run this to stop walking and further crate requests:

```lua
getgenv().MM2AutoFarm.Stop()
```

On a phone, run the stop command through the same scripting environment. No phone buttons are added. Re-running the script stops the previous copy first. You can inspect `MM2AutoFarm.Snapshot()` and `MM2AutoFarm.GetCrateSnapshot()` without opening a menu.

## Full bags and rounds

The script reads the native bag UI and the server's `CoinCollected` event. It stops targeting a full bag. Once all known bags are full and a server capacity event has confirmed fullness, it requests one character reset after a one-second delay. It does not reset repeatedly in the same round, reset in the lobby, or treat a GUI flag alone as permission to reset. The new round clears capacity and retry state. A reset request does not prove a respawn or banked rewards.

Set `ResetWhenFull=false` in the local script's `config` table to disable this behavior. Death, frozen characters, lobby/map departure, missing paths and round end pause movement. Active invisibility, fly, noclip, speed boost and other conflicting movement actions in the main script also pause it; their preferences are not changed.

## Coin-funded crate openings

The default is **Mystery Box #2**. The inspected native catalog lists a **1,000 Coins** price and Lightbringer/Darkbringer as possible godly rewards. The script rechecks that the catalog still offers that crate for Coins and lists a godly possibility before purchasing. It does not infer godly probabilities from the other rarity percentages.

The coin balance at script startup is reserved. A normal one-crate request can run only in the lobby, after the current balance exceeds that starting balance by the current crate price. This spends session balance growth, which is not attributed to an individual pickup. There is no fallback to Gems, keys, Robux or currency purchases.

Only one unbox request can be pending. After success, the script waits for the matching balance decrease and at least ten seconds before another attempt. An ambiguous or failed result stops purchases rather than retrying a possible charge. A known godly/chroma reward stops the farm and further rolls. Stop cannot cancel a purchase the server is already processing. Set `AutoOpenCrates=false` in the local `config` to disable purchasing.

Each client/account has its own local state. This script does not sign accounts in, launch clients or transfer items. Halloween bag identifiers and event currency are not assumed interchangeable with Coins; only an actual increase in the native Coins balance can fund the selected crate. Random rolls cannot guarantee a godly, and farming does not grant invulnerability.

## Movement and validation limits

The discarded underground-flight test received some collection events, but the user reported an **Invalid position** kick. The shipped version uses ground paths; it includes no underground mode, prone position bypass, anti-cheat concealment, noclip or teleport fallback. Server position validation and player attacks still apply. Roblox documents pathfinding as movement along traversable routes around obstacles; see the [official pathfinding guide](https://create.roblox.com/docs/characters/pathfinding).

The ground-path candidate initialized in the connected game at native WalkSpeed 16 with PlatformStand false. Its server collection-event count increased from 3 to 31, and the user confirmed collection worked. The inspected snapshot showed no crate requests or resets; full-bag reset, actual banked earnings, paid unboxing, godly rewards and long sessions across multiple accounts remain unverified live. The 45 local farm/buyer assertions cover controller and spending guards, not native path geometry or drop rates.
