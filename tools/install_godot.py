"""Downloads the pinned Godot editor for CI, checks its SHA-256 and exports GODOT_BIN.

Skips the download when the archive is already in RUNNER_TEMP (CI cache).
Reads GODOT_VERSION, GODOT_ZIP, GODOT_SHA256, GODOT_EXECUTABLE, RUNNER_TEMP and GITHUB_ENV.
"""

import hashlib
import os
import urllib.error
import urllib.request
import zipfile
from pathlib import Path


def download(version: str, archive: Path) -> None:
    opener = urllib.request.build_opener()
    opener.addheaders = [("User-Agent", "wargrid-ci")]  # the Godot mirror answers 403 to Python-urllib
    urllib.request.install_opener(opener)
    try:
        urllib.request.urlretrieve(
            f"https://github.com/godotengine/godot/releases/download/{version}/{archive.name}", archive
        )
    except urllib.error.URLError as error:
        # Godot's own mirror serves the same files; GitHub returned 504 for them on 2026-11-08.
        print(f"GitHub download failed ({error}), using downloads.godotengine.org")
        number, flavor = version.split("-", 1)
        slug = archive.name.removeprefix(f"Godot_v{version}_")
        urllib.request.urlretrieve(
            f"https://downloads.godotengine.org/?version={number}&flavor={flavor}&slug={slug}", archive
        )


def main() -> None:
    archive = Path(os.environ["RUNNER_TEMP"]) / os.environ["GODOT_ZIP"]
    if not archive.exists():  # restored by actions/cache; the checksum below still vets it
        download(os.environ["GODOT_VERSION"], archive)
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
