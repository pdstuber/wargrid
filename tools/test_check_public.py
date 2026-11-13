import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "check_public.sh"
LEAKS = {
    "home path": "logs in /Users/someone/projects/x",
    "hostname": "ssh me@Some-MacBook-Pro.local now",
    "LAN address": "the deck is at 192.168.1.20 today",
    "session id": "session 0a0fadcf-1f71-46b4-97f4-1dc24fd9a120 ran",
    "scratch path": "output in /tmp/claude-501/out.txt",
    "personal mail": "mail someone@gmail.com",
}
CLEAN = "settings.local.json, Windows 10.0.19045, 127.0.0.1, ~/projects/x, session 0a0fadcf, relay.example.local\n"


class CheckPublicTest(unittest.TestCase):
    def setUp(self) -> None:
        base = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, base)
        self.root = base / "repo"
        self.words = base / "words.txt"
        (self.root / "tools").mkdir(parents=True)
        (self.root / "docs").mkdir()
        shutil.copy(SCRIPT, self.root / "tools/check_public.sh")
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)

    def check(self, name: str, text: str, add: bool = True) -> subprocess.CompletedProcess[str]:
        (self.root / name).write_text(text)
        if add:
            subprocess.run(["git", "-C", str(self.root), "add", "-A"], check=True)
        return subprocess.run(
            ["sh", str(self.root / "tools/check_public.sh")],
            env={**os.environ, "WARGRID_PRIVATE_WORDS": str(self.words)},
            capture_output=True,
            text=True,
            check=False,
        )

    def test_clean_tree_passes(self) -> None:
        self.check("docs/milestone-prompt.md", CLEAN)
        result = self.check("docs/note.md", CLEAN)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("PUBLIC CHECK PASSED", result.stdout)

    def test_each_private_detail_fails(self) -> None:
        for kind, line in LEAKS.items():
            with self.subTest(kind=kind):
                result = self.check("docs/note.md", f"{CLEAN}{line}\n")
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn(line, result.stdout)

    def test_tracked_working_file_fails(self) -> None:
        for name in ("docs/m9-prompt.txt", "docs/session-notes.md"):
            with self.subTest(name=name):
                result = self.check(name, CLEAN)
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn(name, result.stdout)
                (self.root / name).unlink()

    def test_untracked_files_are_checked(self) -> None:
        self.words.write_text("secretword\n")
        for name, text in (
            ("docs/new.md", f"{LEAKS['home path']}\n"),
            ("docs/m9-prompt.txt", CLEAN),
            ("docs/word.md", "a secretword\n"),
        ):
            with self.subTest(name=name):
                result = self.check(name, text, add=False)
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn(name, result.stdout)
                (self.root / name).unlink()

    def test_ignored_files_are_skipped(self) -> None:
        self.check(".gitignore", "local/\n")
        (self.root / "local").mkdir()
        result = self.check("local/note.md", f"{LEAKS['home path']}\n", add=False)
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_word_from_the_private_list_fails(self) -> None:
        self.words.write_text("secretword\n")
        result = self.check("docs/note.md", "a SecretWord here\n")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("private list", result.stdout)


if __name__ == "__main__":
    unittest.main()
