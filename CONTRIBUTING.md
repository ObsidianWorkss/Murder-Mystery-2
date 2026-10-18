# Contributing

Thanks for helping improve MM2 Universal. Start with an existing issue or open a focused bug report or feature request describing the behavior you want to change.

## Repository layout

| Path | Purpose |
| --- | --- |
| `main.lua` | Complete runtime bundle: third-party UI library, key gate and project behavior. |
| `loader.lua` | Fetches the current `main` runtime and reports startup errors. |
| `tests/*.luau` | Regression harnesses that exercise extracted runtime functions with mocked client state. |
| `tests/run.py` | Extracts the shipped functions and runs the suites through the Luau CLI. |
| `tests/VALIDATION.md` | Recorded automated results and live observations. |
| `tools/package.py` | Builds an allowlisted archive and verifies its manifest and checksums. |
| `docs/` | Feature guide, support instructions and release checklist. |
| `.github/` | CI, issue forms and pull request template. |

`main.lua` includes a substantial bundled WindUI dependency. Total physical line counts include that dependency, comments and blank lines; do not present the entire bundle as newly authored project code.

## Local workflow

1. Use Python 3 and the Luau **0.739** CLI tools. CI builds the exact source revision recorded in [validate.yml](https://github.com/ObsidianWorkss/Murder-Mystery-2/blob/main/.github/workflows/validate.yml).
2. Edit the relevant runtime function in `main.lua`. Keep its lowercase filename and the public loader URL intact.
3. Add regression coverage when a behavior change needs it. Tests should exercise the shipped function rather than a copied implementation.
4. Run the checks appropriate to your change:

```sh
luau-compile --null main.lua loader.lua
python tests/run.py --luau /path/to/luau
python tools/package.py --output dist
git diff --check
```

For documentation-only work, check local links and regenerate the archive when packaged files change. New files intended for distribution must be included in the explicit file list in `tools/package.py`.

## Changes to controls and gameplay

- Use the existing setters so keyboard, menu and phone controls stay consistent.
- Preserve typing, menu, focus, character and unload guards where they apply.
- Keep the difference between a sent request, a matched reply and an observed result clear in UI text and documentation.
- Record what was tested with mocks and what was observed in a real client separately. Do not describe untested server outcomes as confirmed behavior.

## Pull requests

Use a focused title and explain the problem, resulting behavior and validation. Include relevant device/input details for UI changes. For phone layouts, describe portrait and landscape checks and any remaining live rendering limitations.

Update the [changelog](CHANGELOG.md) and affected guides when user-visible behavior changes. Keep bundled copyright and license notices intact; see [third-party notices](THIRD_PARTY_NOTICES.md).

## Reports and private data

Use [bug reports](https://github.com/ObsidianWorkss/Murder-Mystery-2/issues/new?template=bug_report.yml) for reproducible failures and [feature requests](https://github.com/ObsidianWorkss/Murder-Mystery-2/issues/new?template=feature_request.yml) for suggestions. Access keys, saved key files and private support data must not be committed or posted in issues.
