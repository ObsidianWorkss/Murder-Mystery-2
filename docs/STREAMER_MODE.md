# Windows streamer mode — experimental

Streamer mode moves supported 2D UI into a separate Windows overlay, keeping the original Roblox controls transparent and clickable. The companion requests capture exclusion for its own window and the script requires a successful readback before activation. **A saved recording has not yet been verified. This candidate does not promise that every HUD element disappears.**

## Requirements

- 64-bit Windows 10 version 2004 or later, or Windows 11, with desktop composition enabled. The companion uses [Windows capture exclusion](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowdisplayaffinity), which is not a universal recording protection guarantee.
- .NET Framework 4.8 or later, including the Framework C# compiler and WPF libraries. The build script checks for the compiler; it does not install software.
- A client environment with HTTP `request`, `http.request` or `syn.request` access to loopback. Solara compatibility needs a live check; its name alone does not establish support.
- One normal `RobloxPlayerBeta` window. For multiple clients, explicitly pass the intended process ID to the launcher.
- OBS Window Capture pointed at Roblox. OBS [recommends Window Capture for Roblox](https://obsproject.com/kb/game-capture-troubleshooting). This workflow has not been validated with Roblox's built-in recorder.

## Manual setup

1. Download and extract the release archive. Keep the `streamer` folder and its source/scripts together.
2. Open PowerShell in that folder and run `./Start-Streamer.ps1`. This builds the companion locally and launches its transparent window. It does not install a service, request elevation, inject into Roblox, send input or start/configure OBS. If Windows blocks local scripts, use a session policy allowed by your own system rather than disabling machine-wide protections.
3. Load the latest `main.lua` normally and finish the access-key prompt.
4. Open the generated `streamer/build/connect.lua` in your client environment and execute its contents. It supplies the private local connection and enables streamer mode. Do not post or commit that file.
5. In OBS, manually select **Window Capture → Roblox** and disable **Capture Cursor**. Window Capture records the selected window; its cursor setting is documented in the [OBS source guide](https://obsproject.com/kb/window-capture-sources). Leave unrelated sources out of the test scene.
6. Save a short test clip. Check the menu, ESP, aim marker, game crosshair, inventory, cursor, respawn and camera movement in the actual file. Confirm both that your own display remains usable and that the recorded result is clean before making a longer recording.

**F4** toggles the mode, including while the MM2 menu is open; typing and processed keyboard input still take precedence. Rebind under **Settings → Visual keys**. An existing saved F4 binding keeps its action, so streamer mode may initially be unbound. The menu switch is **Visuals → HUD & Alerts → Streamer mode (Windows)**.

To select one of several clients:

```powershell
./Start-Streamer.ps1 -RobloxPid 1234
```

Use the actual Roblox process ID. The companion refuses an ambiguous automatic selection.

## What is mirrored

The adapter traverses readable PlayerGui, CoreGui and the script's UI root. It sends bounded snapshots of visible rectangles, text, images and an approximate cursor at up to 20 frames per second, with one request in flight. Native visual properties are suppressed while their original or latest observed values feed the mirror. Visibility, enabled state and input hitboxes stay in Roblox, so clicks pass through the companion window to the original controls.

The script's native role highlights, body overlay and gun labels are suppressed. The companion draws projected player boxes/names and gun labels instead. X-ray and tactical hints are suspended because their world visuals would otherwise remain in the captured game. Their preferences are preserved for when streamer mode is off. Character invisibility is not changed by this mode.

## Limits to check

- Text fonts, wrapping, borders, rotation, ordering, clipping and cursor alignment are approximations. The mirror may lag and adds CPU/network serialization cost. No performance improvement is claimed.
- Gradients, text styling, image tinting/nine-slice behavior and native text-editing decorations are not reproduced exactly. Unsupported, private or unavailable images can be absent.
- ViewportFrame 3D previews are hidden without a companion equivalent. Native scrollbars are hidden; scrolling still uses the original control.
- World-space UI, native overhead health/name displays, graphics drawn outside readable ScreenGui trees, other executors' Drawing overlays and world effects are outside this mirror. These can remain in the recording. A crosshair made from readable 2D GUI can be mirrored; a world-rendered crosshair cannot be assumed removable.
- The companion appears only while the selected Roblox window is foreground and its most recent frame is under one second old. Use a normal or borderless window; exclusive fullscreen, DPI changes, multiple monitors and resizing still need live alignment checks.
- Capture exclusion acceptance only proves that Windows accepted the flag. It does not prove what a particular recorder saved. `RecordingVerified` intentionally stays false in diagnostics.

## Disconnects and recovery

Once active, connection/snapshot failures keep the native UI hidden. The companion drops stale frames rather than freezing an old HUD indefinitely. Stop recording before turning the mode off: doing so restores the native HUD and makes it recordable again.

1. Stop your recording yourself.
2. Press the streamer key, turn its menu switch Off, or run:

   ```lua
   local ok, message = getgenv().MM2Assist.SetStreamerMode(false)
   print(ok, message)
   ```

3. If restoration reports incomplete, retry Off. Unload refuses to finish while tracked properties still need restoration. Destroyed or inaccessible objects may need a fresh client.
4. Run `./Stop-Streamer.ps1` to close only the companion executable built in that folder and remove its connection file. For a custom build output folder, close that specific companion process manually.

New UI permissions can change mid-session. If the status reports a surface error, stop recording and restore the UI; coverage of newly inaccessible surfaces cannot be guaranteed.

## Local connection and privacy

The companion listens only on `127.0.0.1`, choosing an ephemeral port and random 256-bit session token. Every request requires that token. Browser-origin requests are rejected. The only endpoints are status, validated display frames and session clearing; there is no command execution endpoint. Session clearing rejects late frames from that session.

Frames contain displayed UI text and projected player labels. They stay on the local loopback connection, but any text visible in the game may therefore be present in the companion process's memory. Image loading can contact allowlisted Roblox/CDN HTTPS hosts without the local token; redirects must remain on that allowlist. Built-in textures are restricted to the selected Roblox installation's content folder.

The generated connection file is ignored by Git and omitted from release packaging. Support snapshots omit tokens, port numbers and frame contents. Never attach `connect.lua` to an issue.

## Development checks

```powershell
$overlayPath = & ./streamer/build.ps1
$test = Start-Process -FilePath $overlayPath -ArgumentList '--self-test' -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput self-test.log -RedirectStandardError self-test.err
Get-Content self-test.log
Get-Content self-test.err
if ($test.ExitCode -ne 0) { throw 'Companion tests failed' }
```

`--self-test` exercises frame validation and the authenticated loopback protocol without creating a window. The Luau suite exercises the shipped lifecycle and presentation manager with mocked properties. Neither check establishes native rendering, alignment or capture results; those remain on the [release checklist](RELEASE_CHECKLIST.md).
