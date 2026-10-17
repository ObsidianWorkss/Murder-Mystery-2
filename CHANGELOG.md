# Changelog

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
