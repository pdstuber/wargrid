import re
import sys
import unittest
from pathlib import Path

BANNED = re.compile(r"\b(sin|cos|tan|atan2?|acos|asin|exp|log)\s*\(")
POW = re.compile(r"\bpow\s*\([^,()]*,\s*-?\d*\.\d*[1-9]")


def violations(text):
    code = "\n".join(line.split("#", 1)[0] for line in text.splitlines())
    return BANNED.findall(code) + POW.findall(code)


class SimMath(unittest.TestCase):
    def test_fixture_fails(self):
        self.assertTrue(violations("var a = cos(1.0)"))
        self.assertTrue(violations("var a = pow(x, 0.5)"))
        self.assertFalse(violations("var a = pow(x, 2)  # cos(1)"))

    def test_simulation_clean(self):
        root = Path(__file__).resolve().parent.parent / "game/scripts/simulation"
        files = sorted(root.glob("*.gd"))
        self.assertTrue(files)
        for path in files:
            self.assertFalse(violations(path.read_text()), path.name)


if __name__ == "__main__":
    unittest.main()
