"""Simulation and net code reads capability data, never a faction id."""
import re
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCAN = [ROOT / "game/scripts/simulation", ROOT / "game/scripts/net"]
SKIP = ROOT / "game/scripts/simulation/definitions"
# Task 4 removes this list; until then these files still read kind ids.
ALLOWED = {ROOT / "game/scripts/simulation" / n for n in (
    "combat.gd", "combat_definitions.gd", "construction.gd", "economy_definitions.gd", "map_data.gd",
    "production.gd", "scripted_human.gd", "simulation.gd", "skirmish.gd", "supply_collection.gd")}
PATTERN = re.compile(r'"(usa|china|frc)(_[a-z_]+)?"|faction\s*==')


def violations(roots):
    found = []
    for root in roots:
        for path in sorted(root.rglob("*.gd")):
            if SKIP in path.parents or path in ALLOWED:
                continue
            for n, line in enumerate(path.read_text().splitlines(), 1):
                if PATTERN.search(line):
                    found.append(f"{path}:{n}: {line.strip()}")
    return found


class FactionGuard(unittest.TestCase):
    def test_no_faction_literals(self):
        self.assertEqual(violations(SCAN), [])

    def test_mutation_is_caught(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "x.gd").write_text('var k := "usa_builder"\n')
            self.assertEqual(len(violations([Path(d)])), 1)


if __name__ == "__main__":
    unittest.main()
