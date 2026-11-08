import hashlib
import io
import os
import tempfile
import unittest
import urllib.error
import zipfile
from pathlib import Path
from unittest import mock

import install_godot


def _zip_bytes() -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as bundle:
        bundle.writestr("godot.bin", "engine")
    return buffer.getvalue()


ZIP = "Godot_v4.7.2-stable_linux.x86_64.zip"


class InstallGodot(unittest.TestCase):
    def run_install(self, cached: bytes | None, sha256: str, fetch_effect: object = None) -> mock.MagicMock:
        with tempfile.TemporaryDirectory() as temp:
            if cached is not None:
                (Path(temp) / ZIP).write_bytes(cached)
            env = {
                "RUNNER_TEMP": temp,
                "GODOT_ZIP": ZIP,
                "GODOT_VERSION": "4.7.2-stable",
                "GODOT_SHA256": sha256,
                "GODOT_EXECUTABLE": "godot.bin",
                "GITHUB_ENV": str(Path(temp) / "env"),
            }
            with (
                mock.patch.dict(os.environ, env),
                mock.patch.object(install_godot.urllib.request, "urlretrieve", side_effect=fetch_effect) as fetch,
            ):
                install_godot.main()
            return fetch

    def test_cached_archive_skips_download(self) -> None:
        data = _zip_bytes()
        fetch = self.run_install(data, hashlib.sha256(data).hexdigest())
        fetch.assert_not_called()

    def test_cached_archive_with_wrong_checksum_fails(self) -> None:
        with self.assertRaises(SystemExit):
            self.run_install(_zip_bytes(), "0" * 64)

    def test_github_failure_falls_back_to_godot_mirror(self) -> None:
        data = _zip_bytes()

        def fetch(url: str, path: Path) -> None:
            if url.startswith("https://github.com/"):
                raise urllib.error.HTTPError(url, 504, "Gateway Time-out", {}, None)  # type: ignore[arg-type]
            Path(path).write_bytes(data)

        calls = self.run_install(None, hashlib.sha256(data).hexdigest(), fetch)
        self.assertEqual(
            calls.call_args_list[-1].args[0],
            "https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=linux.x86_64.zip",
        )


if __name__ == "__main__":
    unittest.main()
