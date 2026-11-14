import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "deploy_web.sh"
STUB = '#!/bin/sh\necho "{name} $*" >> "$STUB_LOG"\n'
FAKE_EXPORT = '#!/bin/sh\nmkdir -p "$(dirname "$2")" && echo "export $*" >> "$STUB_LOG"\n'


class DeployWebTest(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root)
        (self.root / "tools").mkdir()
        shutil.copy(SCRIPT, self.root / "tools/deploy_web.sh")
        (self.root / "tools/export_build.sh").write_text(FAKE_EXPORT)
        (self.root / "game/data/maps").mkdir(parents=True)
        (self.root / "game/data/maps/NOTICE.md").write_text("")
        (self.root / "LICENSE").write_text("")
        (self.root / "game/audio").mkdir(parents=True)
        (self.root / "game/audio/CREDITS.md").write_text("")
        (self.root / "game/fonts").mkdir(parents=True)
        (self.root / "game/fonts/PublicSans-OFL.txt").write_text("")
        (self.root / "web/site").mkdir(parents=True)
        (self.root / "web/site/old").write_text("")
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        for name in ("fly", "curl", "godot"):
            (bin_dir / name).write_text(STUB.format(name=name))
            (bin_dir / name).chmod(0o755)
        self.log = self.root / "stub.log"
        self.env = {
            **os.environ,
            "PATH": f"{bin_dir}:{os.environ['PATH']}",
            "GODOT_BIN": str(bin_dir / "godot"),
            "STUB_LOG": str(self.log),
        }

    def run_script(self, version: str | None, *args: str) -> subprocess.CompletedProcess[str]:
        line = f'config/version="{version}"\n' if version is not None else ""
        (self.root / "game/project.godot").write_text(f'[application]\n\nconfig/name="Wargrid"\n{line}')
        return subprocess.run(
            ["sh", str(self.root / "tools/deploy_web.sh"), *args],
            env=self.env,
            capture_output=True,
            text=True,
            check=False,
        )

    def calls(self) -> list[str]:
        return self.log.read_text().splitlines() if self.log.exists() else []

    def assert_refused(self, result: subprocess.CompletedProcess[str], needle: str) -> None:
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn(needle, result.stderr)
        self.assertEqual(self.calls(), [])
        self.assertTrue((self.root / "web/site/old").exists(), "refusal must not clear web/site")

    def test_test_target_deploys_the_test_app(self) -> None:
        result = self.run_script("0.7.0-dev", "test")
        self.assertEqual(result.returncode, 0, result.stderr)
        fly = [c for c in self.calls() if c.startswith("fly ")]
        self.assertEqual(len(fly), 1)
        self.assertIn(" -a wargrid-web-test ", fly[0])
        self.assertIn("https://wargrid-web-test.fly.dev/health", self.calls()[-1])

    def test_production_deploys_the_production_app(self) -> None:
        result = self.run_script("0.7.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        fly = [c for c in self.calls() if c.startswith("fly ")]
        self.assertEqual(len(fly), 1)
        self.assertIn(" -a wargrid-web ", fly[0])
        self.assertIn("https://wargrid.pdstuber.dev/health", self.calls()[-1])

    def test_test_refuses_a_release_version(self) -> None:
        self.assert_refused(self.run_script("0.6.0", "test"), '"0.6.0"')

    def test_production_refuses_a_dev_version(self) -> None:
        self.assert_refused(self.run_script("0.7.0-dev"), '"0.7.0-dev"')

    def test_unknown_target_refuses(self) -> None:
        self.assert_refused(self.run_script("0.7.0-dev", "tset"), "usage: sh tools/deploy_web.sh [test]")

    def test_missing_version_refuses_both_targets(self) -> None:
        self.assert_refused(self.run_script(None, "test"), 'config/version is ""')
        self.assert_refused(self.run_script(None), 'config/version is ""')


if __name__ == "__main__":
    unittest.main()
