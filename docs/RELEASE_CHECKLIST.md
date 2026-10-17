# Release candidate checklist

Version: **1.0.0-rc.24**. Do not describe this candidate as fully verified until the pending live checks have been completed.

## Automated checks

- [ ] GitHub workflow `Validate script` succeeds on the published commit.
- [x] Both `main.lua` and `loader.lua` compile locally.
- [x] Combat, loader, support-report, role-reveal, movement, x-ray, animation-pack, keybind, triggerbot and aura regression suites pass locally (339 assertions).
- [x] ZIP contents match `MANIFEST.json`; archive checksum matches `SHA256SUMS.txt`.

## Live checks

- [ ] Kill all: one pass, skip reasons, queue cancellation, prior aura restoration, and actual server outcomes; separately verify the accepted extended distance rather than treating the 200-stud attempt setting as accepted range.
- [ ] Aura: normal contact without blade overlap, extended contact acceptance, partial cover, automatic equip and respawn recovery while murderer. Distinguish sent requests from observed server damage.
- [x] PC triggerbot smoke check: rc.18 running, both status cards present, independent menu setters, unchanged master aim, unbound keys, both modes off, and no trigger requests sent.
- [ ] Triggerbot: visible on-screen gun and knife acquisition without cursor contact, offscreen cancellation including camera turns, reaction scheduling, weapon cooldowns, independent toggles, pause/resume, emergency stop and reload-off behavior. Record sent requests separately from matched server feedback and observed eliminations.
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
