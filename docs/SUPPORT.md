# Support

## Report a reproducible issue

1. Load the latest script and note the version shown on Home.
2. Open Settings → **Copy support report**.
3. Open a repository issue and paste the report, your device/input type, and the exact steps that caused the problem.
4. Include what you expected and what happened. For attacks, distinguish a skipped request, an unconfirmed reply, a reported hit, and an observed elimination.

The report includes build information, capability availability, enabled combat features, operation counts, and aggregate attack counters. It omits access keys, saved key contents, usernames, user IDs, server IDs, and individual shot payloads. It is copied only when requested; the script does not submit it to an issue tracker.

If clipboard access is unavailable, the button prints the report to the developer console. You can also run:

```lua
print(getgenv().MM2Assist.GetSupportReport())
```

Do not include your access key in an issue. Ask the repository owner for a valid key if you do not have one. The optional saved-key file is `MM2Universal/key.txt` inside the executor's filesystem. A client-side key prompt is not a server-side authentication boundary.

## Recover controls

For streamer mode, stop recording before restoring native UI. Press **F4** (or your rebound key) even with the menu open, turn Streamer mode Off, or run `getgenv().MM2Assist.SetStreamerMode(false)`. Connection loss keeps native UI hidden until Off. Retry Off if restoration reports incomplete, then use `streamer/Stop-Streamer.ps1` to close that folder's companion. See [full setup, recovery and limits](STREAMER_MODE.md). Never post the generated `connect.lua` token file.

- **Phone:** tap MM2, then Pages to choose a section. Main shortcuts are Invis, Speed, Trigger and Aura; More contains the less-used actions. Settings → General resets button positions. Visuals → HUD & Alerts → Show instructions on phone is off by default to leave the inventory clear.
- **End / STOP:** requests cancellation of active player actions and return where supported.
- **Repair camera input:** clears stale input state.
- **Restore character:** requests restoration after invisibility use.
- **Unload and restore:** disconnects script handlers and restores native weapon handlers. If restoration fails, read the displayed status and retry after resolving it.
- **Repair character (respawns):** explicitly resets your character.

Use the repository's previous commit to obtain an older `main.lua` if an update introduces a regression. Re-running a script invokes the previous instance's cleanup first.

## Compatibility and experimental features

For Halloween modes, check the mode on Home and `GameMode` in the support report. rc.42 recognizes Infection's Zombie/Survivor and FreezeTag's Freezer/Runner roles. Reload the latest script after updating. A Zombie cannot use the native knife throw; an unarmed Runner cannot automate a gun. Unknown roles/modes leave weapon handling native until supported data arrives. See [event behavior and limits](FEATURES.md#halloween-and-event-modes). Include the exact mode, your actual role, weapon and whether normal native attacks work when reporting an event failure.

The main script needs a compatible client scripting environment. The HTTP loader additionally needs `game:HttpGet` and `loadstring`. Clipboard, local file storage, and simulated touch are optional capabilities; their availability appears in the support report.

Player exclusions apply across script-controlled attacks and actions. Built-in protected accounts are separate from the removable session exclusions. Experimental reach, pickup, invisibility, teleports, and fling behavior may be rejected or corrected by the server.
