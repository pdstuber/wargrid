"""Installs the release export templates CI needs, after checking the pinned SHA-256.

usage: install_export_templates.py EXPECTED_SHA256 VERSION   (VERSION like 4.7.2-stable)
"""

import hashlib
import os
import sys
import tempfile
import zipfile
from pathlib import Path

import install_godot

WANTED = (
    "version.txt",
    "linux_release.x86_64",
    "windows_release_x86_64.exe",
    "windows_release_x86_64_console.exe",
    "macos.zip",
    "web_nothreads_release.zip",
)


def templates_dir(version: str) -> Path:
    base = Path(os.environ["APPDATA"]) / "Godot" if os.name == "nt" else Path.home() / ".local" / "share" / "godot"
    return base / "export_templates" / version.replace("-", ".")


def main() -> None:
    expected, version = sys.argv[1], sys.argv[2]
    target = templates_dir(version)
    if all((target / name).exists() for name in WANTED):
        print("templates already installed:", target)
        return
    with tempfile.TemporaryDirectory() as scratch:
        archive = Path(scratch) / f"Godot_v{version}_export_templates.tpz"
        install_godot.download(version, archive)
        digest = hashlib.sha256()
        with archive.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1 << 20), b""):
                digest.update(chunk)
        if digest.hexdigest() != expected:
            raise SystemExit(f"export template checksum mismatch: {digest.hexdigest()}")
        target.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as bundle:
            for name in WANTED:
                (target / name).write_bytes(bundle.read(f"templates/{name}"))
    print("templates installed:", target)


if __name__ == "__main__":
    main()
