"""Downloads the pinned Godot editor for CI, checks its SHA-256 and exports GODOT_BIN.

Skips the download when the archive is already in RUNNER_TEMP (CI cache).
Reads GODOT_VERSION, GODOT_ZIP, GODOT_SHA256, GODOT_EXECUTABLE, RUNNER_TEMP and GITHUB_ENV.
"""

import hashlib
import os
import urllib.request
import zipfile
from pathlib import Path


def main() -> None:
    archive = Path(os.environ["RUNNER_TEMP"]) / os.environ["GODOT_ZIP"]
    url = f"https://github.com/godotengine/godot/releases/download/{os.environ['GODOT_VERSION']}/{archive.name}"
    if not archive.exists():  # restored by actions/cache; the checksum below still vets it
        urllib.request.urlretrieve(url, archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != os.environ["GODOT_SHA256"]:
        raise SystemExit("Godot checksum mismatch")
    directory = archive.parent / "godot"
    with zipfile.ZipFile(archive) as bundle:
        bundle.extractall(directory)
    executable = directory / os.environ["GODOT_EXECUTABLE"]
    executable.chmod(0o755)
    with open(os.environ["GITHUB_ENV"], "a") as output:
        output.write(f"GODOT_BIN={executable.resolve().as_posix()}\n")


if __name__ == "__main__":
    main()
