# Release candidate checklist

Version: **1.0.0-rc.2**. Do not describe this candidate as fully verified until the pending live checks have been completed.

## Automated checks

- [ ] GitHub workflow `Validate script` succeeds on the published commit.
- [x] Both `main.lua` and `loader.lua` compile locally.
- [x] Combat, loader, and support-report regression suites pass locally (72 assertions).
- [x] ZIP contents match `MANIFEST.json`; archive checksum matches `SHA256SUMS.txt`.

## Live checks — pending a connected Roblox client

- [ ] First launch: valid key, invalid key, cancel, and saved-key behavior.
- [ ] Menu: seven tabs, cards open and close, live status text resizes its card, search opens the card holding a result.
- [ ] PC: Right Shift menu, click fire/stab, E/right-click throw, End stop.
- [ ] Mobile: dragging, FIRE/STAB, THROW, STOP, and switching input modes.
- [ ] Support report: clipboard success and unavailable-clipboard fallback.
- [ ] Equip/unequip, role transitions, respawn, target death, and player departure.
- [ ] Gun/knife toggles and exclusions; no attack during focused text input.
- [ ] Unload restores handlers; re-running creates one functional UI with no stale callbacks.
- [ ] Re-run `TestCoverChecks` and `TestCampChaseAim`.
- [ ] Resolve or explain `TestMotionIntegration` and `TestObservedAimIntegration` failures with reproducible evidence.

Record device, executor, place version, test date, result, and any observed errors. Automated mock tests do not certify server behavior or device compatibility.
