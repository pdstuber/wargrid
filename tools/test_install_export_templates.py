import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import install_export_templates
import install_godot


class InstallExportTemplates(unittest.TestCase):
    def test_downloads_through_install_godot(self) -> None:
        with (
            tempfile.TemporaryDirectory() as home,
            mock.patch.dict(os.environ, {"HOME": home, "APPDATA": home}),
            mock.patch.object(sys, "argv", ["install_export_templates.py", "0" * 64, "4.7.2-stable"]),
            mock.patch.object(install_godot, "download", side_effect=lambda _v, p: Path(p).write_bytes(b"x")) as fetch,
            self.assertRaises(SystemExit),  # the fake archive fails the checksum
        ):
            install_export_templates.main()
        version, archive = fetch.call_args.args
        self.assertEqual((version, archive.name), ("4.7.2-stable", "Godot_v4.7.2-stable_export_templates.tpz"))


if __name__ == "__main__":
    unittest.main()
