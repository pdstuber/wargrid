"""Packages one exported platform build into a release zip with license notices.

usage: python3 tools/package_release.py PLATFORM BUILD OUT SOURCE_URL EXTRA...
PLATFORM is linux, windows or macos. BUILD is the export directory (linux, windows)
or the zip Godot exported (macos).
"""

import shutil
import sys
import zipfile
from pathlib import Path
from typing import Literal

FIRST_RUN = {
    "linux": "Run: chmod +x Wargrid.x86_64 && ./Wargrid.x86_64\n",
    "windows": "Unsigned build: if SmartScreen warns, choose More info, then Run anyway.\n",
    "macos": (
        "Unsigned build: after the first blocked start, open System Settings > Privacy & Security\n"
        "and choose Open Anyway, or run once before the first start:\n"
        "  xattr -dr com.apple.quarantine Wargrid.app\n"
    ),
}
README = (
    "Wargrid {platform} build.\n\n{first_run}\n"
    "License: GPL-3.0-or-later, see LICENSE. Corresponding source for this build: {source}\n"
)


def package(platform: str, build: Path, out: Path, source: str, extras: list[Path]) -> Path:
    if platform not in FIRST_RUN:
        raise SystemExit(f"unknown platform {platform}; expected one of {', '.join(FIRST_RUN)}")
    out.parent.mkdir(parents=True, exist_ok=True)
    mode: Literal["a", "w"] = "a" if platform == "macos" else "w"
    if platform == "macos":
        # Append to Godot's own zip: re-zipping the app would drop its symlinks and mode bits.
        shutil.copyfile(build, out)
        files: list[Path] = []
    else:
        files = sorted(path for path in build.iterdir() if path.is_file())
        if not files:
            raise SystemExit(f"{build} has no exported files")
    with zipfile.ZipFile(out, mode, zipfile.ZIP_DEFLATED) as bundle:
        for path in files + sorted(extras):
            bundle.write(path, path.name)
        bundle.writestr("README.txt", README.format(platform=platform, first_run=FIRST_RUN[platform], source=source))
    return out


def main() -> None:
    if len(sys.argv) < 5:
        raise SystemExit(__doc__)
    package(sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4], [Path(arg) for arg in sys.argv[5:]])


if __name__ == "__main__":
    main()
