import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DECL = re.compile(r"^\s*(?:static\s+)?(?:var|const|func)\s+(_[a-z0-9_]+)", re.M)
ACCESS = re.compile(r"(?<!self)\.(_[a-z0-9_]+)\b")

ALLOWLIST: frozenset[str] = frozenset(
    [
        "economy_fixture.gd",
        "test_announcer.gd",
        "test_art_lab.gd",
        "test_combat.gd",
        "test_combat_navigation.gd",
        "test_construction.gd",
        "test_containers.gd",
        "test_defences.gd",
        "test_factions.gd",
        "test_groups.gd",
        "test_horde.gd",
        "test_lockstep.gd",
        "test_movement.gd",
        "test_navigation_incremental.gd",
        "test_production.gd",
        "test_ramp.gd",
        "test_rebuild_holes.gd",
        "test_repath.gd",
        "test_salvage.gd",
        "test_scene.gd",
        "test_skirmish.gd",
        "test_skirmish_scene.gd",
        "test_skirmish_waves.gd",
        "test_supply.gd",
        "test_supply_parity.gd",
        "test_teams.gd",
        "test_tunnels.gd",
        "test_view.gd",
        "test_wire.gd",
        "test_world_batch.gd",
    ]
)


def private_names(root):
    names = set()
    for path in (root / "game/scripts/simulation").rglob("*.gd"):
        names.update(DECL.findall(path.read_text()))
    return names


def hits(text, names):
    code = "\n".join(line.split("#", 1)[0] for line in text.splitlines())
    return [m for m in ACCESS.findall(code) if m in names]


def test_files(root):
    return sorted((root / "game/tests").rglob("*.gd"))


class SimBoundary(unittest.TestCase):
    def test_flags_private_read(self):
        found = hits("var hp = sim._entities[1].hp", {"_entities"})
        self.assertEqual(found, ["_entities"])

    def test_ignores_own_helper(self):
        self.assertEqual(hits("Replay.new()._world(runner)", {"_entities"}), [])

    def test_ignores_comment(self):
        self.assertEqual(hits("var a = 1  # sim._entities", {"_entities"}), [])

    def test_private_names_found(self):
        names = private_names(ROOT)
        self.assertLessEqual({"_entities", "_buildings"}, names)

    def test_new_files_clean(self):
        names = private_names(ROOT)
        for path in test_files(ROOT):
            if path.name in ALLOWLIST:
                continue
            found = hits(path.read_text(), names)
            self.assertFalse(found, f"{path.name} reads sim internals: {sorted(set(found))}")

    def test_allowlist_still_needed(self):
        names = private_names(ROOT)
        by_name = {p.name: p for p in test_files(ROOT)}
        for name in sorted(ALLOWLIST):
            self.assertIn(name, by_name, f"{name} is gone: remove it from ALLOWLIST")
            self.assertTrue(
                hits(by_name[name].read_text(), names),
                f"{name} no longer reads sim internals: remove it from ALLOWLIST",
            )


if __name__ == "__main__":
    unittest.main()
