import stat
import tempfile
import unittest
import zipfile
from pathlib import Path

from package_release import package


def _mode(info: zipfile.ZipInfo) -> int:
    return (info.external_attr >> 16) & 0o777


class PackageRelease(unittest.TestCase):
    def setUp(self) -> None:
        self._scratch = tempfile.TemporaryDirectory()
        self.root = Path(self._scratch.name)
        self.extras = []
        for name in ("LICENSE", "NOTICE.md", "GODOT_LICENSES.txt"):
            path = self.root / name
            path.write_text(name)
            self.extras.append(path)

    def tearDown(self) -> None:
        self._scratch.cleanup()

    def _build(self, *names: str) -> Path:
        build = self.root / "build"
        build.mkdir()
        for name in names:
            (build / name).write_bytes(b"binary")
            (build / name).chmod(0o755)
        return build

    def test_linux_contents(self) -> None:
        out = package("linux", self._build("Wargrid.x86_64"), self.root / "linux.zip", self.extras)
        with zipfile.ZipFile(out) as bundle:
            self.assertEqual(
                sorted(bundle.namelist()),
                ["GODOT_LICENSES.txt", "LICENSE", "NOTICE.md", "README.txt", "Wargrid.x86_64"],
            )
            self.assertEqual(_mode(bundle.getinfo("Wargrid.x86_64")), 0o755)

    def test_windows_contents(self) -> None:
        out = package("windows", self._build("Wargrid.exe", "Wargrid.console.exe"), self.root / "w.zip", self.extras)
        with zipfile.ZipFile(out) as bundle:
            self.assertIn("Wargrid.exe", bundle.namelist())
            self.assertIn("Wargrid.console.exe", bundle.namelist())
            self.assertIn("SmartScreen", bundle.read("README.txt").decode())

    def test_macos_appends_and_keeps_modes(self) -> None:
        godot_zip = self.root / "Wargrid.zip"
        binary = zipfile.ZipInfo("Wargrid.app/Contents/MacOS/Wargrid")
        binary.external_attr = (stat.S_IFREG | 0o755) << 16
        link = zipfile.ZipInfo("Wargrid.app/Contents/Frameworks/Current")
        link.external_attr = (stat.S_IFLNK | 0o777) << 16
        with zipfile.ZipFile(godot_zip, "w") as bundle:
            bundle.writestr(binary, b"binary")
            bundle.writestr(link, "A")
        out = package("macos", godot_zip, self.root / "mac.zip", self.extras)
        with zipfile.ZipFile(out) as bundle:
            self.assertEqual(bundle.getinfo(binary.filename).external_attr, binary.external_attr)
            self.assertEqual(bundle.getinfo(link.filename).external_attr, link.external_attr)
            for name in ("LICENSE", "NOTICE.md", "GODOT_LICENSES.txt"):
                self.assertIn(name, bundle.namelist())
            self.assertIn("xattr -dr com.apple.quarantine", bundle.read("README.txt").decode())

    def test_empty_build_fails(self) -> None:
        with self.assertRaises(SystemExit):
            package("linux", self._build(), self.root / "empty.zip", self.extras)

    def test_unknown_platform_fails(self) -> None:
        with self.assertRaises(SystemExit):
            package("web", self._build("index.html"), self.root / "web.zip", self.extras)


if __name__ == "__main__":
    unittest.main()
