#!/usr/bin/env python3
"""Pin the latest published OpenTubeX release and its SHA-256 asset digests."""

import argparse
import base64
import json
from pathlib import Path
import re
import subprocess


def release_metadata(release):
    tag = release["tag_name"]
    match = re.fullmatch(r"v(\d+\.\d+\.\d+)(-beta)?", tag)
    if not match or release.get("draft") or release.get("prerelease"):
        raise ValueError(f"Expected a published stable release, got {tag!r}")
    version, suffix = match.groups()
    version_with_suffix = version + (suffix or "")
    deb_version = version_with_suffix.replace("-", "_")
    names = {
        "x86_64-linux": f"opentubex_{deb_version}_amd64.deb",
        "aarch64-linux": f"opentubex_{deb_version}_arm64.deb",
        "x86_64-darwin": f"opentubex-{version_with_suffix}-mac-x64.zip",
        "aarch64-darwin": f"opentubex-{version_with_suffix}-mac-arm64.zip",
    }
    sources = {}
    for system, name in names.items():
        assets = [asset for asset in release["assets"] if asset["name"] == name]
        if len(assets) != 1:
            raise ValueError(f"Expected exactly one release asset named {name}")
        digest = assets[0].get("digest") or ""
        if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
            raise ValueError(f"Missing or invalid SHA-256 digest for {name}")
        encoded = base64.b64encode(bytes.fromhex(digest[7:])).decode("ascii")
        sources[system] = {"name": name, "hash": f"sha256-{encoded}"}
    return {"version": version_with_suffix, "tag": tag, "sources": sources}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", help="Published release tag; defaults to the latest release")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "release.json")
    args = parser.parse_args()
    if args.tag and not re.fullmatch(r"v\d+\.\d+\.\d+(-beta)?", args.tag):
        parser.error("Expected a release tag such as v0.34.1-beta")
    endpoint = f"tags/{args.tag}" if args.tag else "latest"
    result = subprocess.run(
        ["gh", "api", f"repos/OpenTubeX/OpenTubeX/releases/{endpoint}"],
        check=True, capture_output=True, text=True,
    )
    metadata = release_metadata(json.loads(result.stdout))
    # Validate every platform before touching the existing pin.
    args.output.write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"Pinned OpenTubeX {metadata['version']}")


if __name__ == "__main__":
    main()
