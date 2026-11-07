import re
import tempfile
import unittest
from pathlib import Path

from release_version import check_tag, is_prerelease, read_version

REPO = Path(__file__).resolve().parent.parent
WORKFLOWS = REPO / ".github/workflows"


class ReleaseVersion(unittest.TestCase):
    def test_matching_tag(self) -> None:
        self.assertEqual(check_tag("v0.7.0", "0.7.0"), "0.7.0")

    def test_prerelease(self) -> None:
        self.assertEqual(check_tag("v0.7.0-rc.1", "0.7.0-rc.1"), "0.7.0-rc.1")
        self.assertTrue(is_prerelease("0.7.0-rc.1"))
        self.assertFalse(is_prerelease("0.7.0"))

    def test_mismatch_names_both(self) -> None:
        with self.assertRaises(SystemExit) as caught:
            check_tag("v0.7.0", "0.5.1")
        self.assertIn("v0.7.0", str(caught.exception.code))
        self.assertIn("0.5.1", str(caught.exception.code))

    def test_tag_without_v(self) -> None:
        with self.assertRaises(SystemExit):
            check_tag("0.7.0", "0.7.0")

    def test_reads_project(self) -> None:
        with tempfile.TemporaryDirectory() as scratch:
            project = Path(scratch) / "project.godot"
            project.write_text('[application]\n\nconfig/name="Wargrid"\nconfig/version="0.5.1"\n')
            self.assertEqual(read_version(project), "0.5.1")
            project.write_text('[application]\n\nconfig/name="Wargrid"\n')
            with self.assertRaises(SystemExit):
                read_version(project)

    def test_reads_repo_project(self) -> None:
        self.assertTrue(read_version(REPO / "game/project.godot"))

    def test_release_builds_with_the_tested_engine(self) -> None:
        tests = (WORKFLOWS / "tests.yml").read_text()
        release = (WORKFLOWS / "release.yml").read_text()
        pins = re.findall(r"^  (GODOT_\w+|TEMPLATES_SHA256): (\S+)$", release, re.M)
        self.assertEqual(len(pins), 5)
        for name, value in pins:
            self.assertIn(value, tests, name)


if __name__ == "__main__":
    unittest.main()
