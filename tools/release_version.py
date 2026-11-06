"""Checks that a release tag matches the game's `config/version`.

The relay only lets clients with equal `build` strings share a room, so a tag
whose build still reports an older version would mix simulations.

usage: python3 tools/release_version.py TAG [PROJECT]
"""

import re
import sys
from pathlib import Path

VERSION = re.compile(r'^config/version="(.+)"$', re.M)
DEFAULT_PROJECT = Path(__file__).resolve().parent.parent / "game/project.godot"


def read_version(project: Path) -> str:
    found = VERSION.search(project.read_text())
    if not found:
        raise SystemExit(f"{project} has no config/version")
    return found.group(1)


def check_tag(tag: str, version: str) -> str:
    if tag != "v" + version:
        raise SystemExit(f"tag {tag} does not match config/version {version}; expected v{version}")
    return version


def is_prerelease(version: str) -> bool:
    return "-" in version


def main() -> None:
    if len(sys.argv) not in (2, 3):
        raise SystemExit(__doc__)
    project = Path(sys.argv[2]) if len(sys.argv) == 3 else DEFAULT_PROJECT
    version = check_tag(sys.argv[1], read_version(project))
    print(f"version={version}")
    print(f"prerelease={'true' if is_prerelease(version) else 'false'}")


if __name__ == "__main__":
    main()
