import re
import unittest
from pathlib import Path

BANNED = re.compile(r"\b(sin|cos|tan|atan2?|acos|asin|exp|log)\s*\(")
POW = re.compile(r"\bpow\s*\([^,()]*,\s*-?\d*\.\d*[1-9]")
CLOCK = re.compile(r"\b(Time|OS|Engine)\.")
RNG = re.compile(
    r"\b(randi|randf|randi_range|randf_range|randfn|randomize|rand_from_seed)\s*\("
    r"|\bRandomNumberGenerator\b"
)
NATIVE_HASH = re.compile(r"\.hash\s*\(\s*\)")
CHECKS = {"CLOCK": CLOCK, "RNG": RNG, "NATIVE_HASH": NATIVE_HASH}
EXEMPT = {
    # Setup-only seeded RNG; a coupling a port must reproduce.
    "start_spots.gd": {"RNG"},
    # Godot hash until the state digest plan replaces it; that plan deletes this entry.
    "state_hash.gd": {"NATIVE_HASH"},
}


def violations(text, name=""):
    code = "\n".join(line.split("#", 1)[0] for line in text.splitlines())
    found = BANNED.findall(code) + POW.findall(code)
    for key, pattern in CHECKS.items():
        if key not in EXEMPT.get(name, set()):
            found += pattern.findall(code)
    return found


class SimMath(unittest.TestCase):
    def test_fixture_fails(self):
        self.assertTrue(violations("var a = cos(1.0)"))
        self.assertTrue(violations("var a = pow(x, 0.5)"))
        self.assertFalse(violations("var a = pow(x, 2)  # cos(1)"))
        self.assertTrue(violations("var t = Time.get_ticks_msec()"))
        self.assertTrue(violations("var r = randi()"))
        self.assertTrue(violations("var g = RandomNumberGenerator.new()"))
        self.assertTrue(violations("var h = state.hash()"))
        self.assertFalse(violations("var t = MyTime.get()"))
        self.assertFalse(violations('var os_name = "x"  # Time.now'))

    def test_simulation_clean(self):
        root = Path(__file__).resolve().parent.parent / "game/scripts/simulation"
        files = sorted(root.rglob("*.gd"))
        self.assertTrue(files)
        for path in files:
            self.assertFalse(violations(path.read_text(), path.name), path.name)


if __name__ == "__main__":
    unittest.main()
