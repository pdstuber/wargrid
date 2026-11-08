import hashlib
import io
import os
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

import install_godot


def _zip_bytes() -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as bundle:
        bundle.writestr("godot.bin", "engine")
    return buffer.getvalue()


class InstallGodot(unittest.TestCase):
    def run_install(self, cached: bytes | None, sha256: str) -> mock.MagicMock:
        with tempfile.TemporaryDirectory() as temp:
            if cached is not None:
                (Path(temp) / "godot.zip").write_bytes(cached)
            env = {
                "RUNNER_TEMP": temp,
                "GODOT_ZIP": "godot.zip",
                "GODOT_VERSION": "4.7.2-stable",
                "GODOT_SHA256": sha256,
                "GODOT_EXECUTABLE": "godot.bin",
                "GITHUB_ENV": str(Path(temp) / "env"),
            }
            with (
                mock.patch.dict(os.environ, env),
                mock.patch.object(install_godot.urllib.request, "urlretrieve") as fetch,
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


if __name__ == "__main__":
    unittest.main()
