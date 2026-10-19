"""Build and verify a distributable without including local files or credentials."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path, default=Path("dist"))
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
match = re.search(r'^State.Version = "([0-9A-Za-z.-]+)"$', (root / "main.lua").read_text(encoding="utf-8"), re.M)
if not match:
    raise SystemExit("Missing release version in main.lua")
version = match.group(1)
files = ["main.lua", "loader.lua", "Readme.md", "CHANGELOG.md", "THIRD_PARTY_NOTICES.md",
         "CONTRIBUTING.md", "assets/banner.svg", "docs/FEATURES.md",
         "docs/SUPPORT.md", "docs/RELEASE_CHECKLIST.md", "docs/STREAMER_MODE.md", "tests/VALIDATION.md",
         "streamer/Overlay.cs", "streamer/build.ps1", "streamer/Start-Streamer.ps1", "streamer/Stop-Streamer.ps1"]
payloads = {name: (root / name).read_text(encoding="utf-8").replace("\r\n", "\n").encode("utf-8") for name in files}
manifest = {"version": version, "files": {name: hashlib.sha256(data).hexdigest() for name, data in payloads.items()}}
payloads["MANIFEST.json"] = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8")
args.output.mkdir(parents=True, exist_ok=True)
archive = args.output / f"MM2-Universal-{version}.zip"
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
    for name, data in sorted(payloads.items()):
        info = zipfile.ZipInfo(name)
        info.create_system = 3  # Stable metadata on Windows and Linux.
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        bundle.writestr(info, data)
with zipfile.ZipFile(archive) as bundle:
    if set(bundle.namelist()) != set(payloads):
        raise SystemExit("Unexpected archive contents")
    for name, expected in manifest["files"].items():
        if hashlib.sha256(bundle.read(name)).hexdigest() != expected:
            raise SystemExit(f"Checksum mismatch: {name}")
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(args.output / "SHA256SUMS.txt").write_text(f"{digest}  {archive.name}\n", encoding="utf-8")
print(f"Verified {archive.name}: {len(payloads)} files; SHA-256 {digest}")
