import json
import tempfile
import unittest
from pathlib import Path

from desync_diff import first_difference, ring_divergence


def report(**changes):
    base = {
        "seat": 1,
        "tick": 60,
        "hash_rows": ["0\ta"],
        "command_log": [{"type": "move", "tick": 4}],
        "snapshot": {"players": {"1": {"credits": 5}}, "entities": [{"position": [14.1, 2.0]}]},
    }
    base.update(changes)
    return base


class DesyncDiffTests(unittest.TestCase):
    def test_identical_ignores_seat_and_hash_rows(self):
        self.assertIsNone(first_difference(report(), report(seat=2, hash_rows=["0\tb"])))

    def test_command_log_index(self):
        other = report(command_log=[{"type": "move", "tick": 4}, {"type": "stop", "tick": 5}])
        self.assertIn("command_log[1]", first_difference(report(), other) or "")

    def test_command_log_content(self):
        other = report(command_log=[{"type": "stop", "tick": 4}])
        self.assertIn("command_log[0]", first_difference(report(), other) or "")

    def test_snapshot_path_and_values(self):
        other = report(
            snapshot={"players": {"1": {"credits": 5}}, "entities": [{"position": [14.100000000000001, 2.0]}]}
        )
        text = first_difference(report(), other) or ""
        self.assertIn("snapshot.entities[0].position[0]", text)
        self.assertIn("14.1 != 14.100000000000001", text)

    def test_names_players(self):
        other = report(snapshot={"players": {"1": {"credits": 6}}, "entities": [{"position": [14.1, 2.0]}]})
        self.assertIn("players", first_difference(report(), other) or "")

    def test_int_versus_float(self):
        other = report(snapshot={"players": {"1": {"credits": 5.0}}, "entities": [{"position": [14.1, 2.0]}]})
        self.assertIsNotNone(first_difference(report(), other))

    def test_missing_key(self):
        other = report(snapshot={"players": {}, "entities": []})
        self.assertIsNotNone(first_difference(report(), other))

    def test_ring_equal(self):
        ring = ["40\ta", "41\tb"]
        self.assertIsNone(ring_divergence(report(hash_ring=ring), report(hash_ring=list(ring))))

    def test_ring_first_difference(self):
        first = report(hash_ring=["40\ta", "41\tb", "42\tc"])
        second = report(hash_ring=["40\ta", "41\tx", "42\ty"])
        self.assertEqual(ring_divergence(first, second), 41)

    def test_ring_ticks_sort_as_numbers(self):
        first = report(hash_ring=["9\ta", "10\tb"])
        self.assertEqual(ring_divergence(first, report(hash_ring=["9\tx", "10\ty"])), 9)

    def test_ring_disjoint_ticks(self):
        self.assertIsNone(ring_divergence(report(hash_ring=["1\ta"]), report(hash_ring=["2\tb"])))

    def test_ring_missing(self):
        self.assertIsNone(ring_divergence(report(), report(hash_ring=["1\ta"])))

    def test_cli_exit_codes(self):
        import subprocess
        import sys

        with tempfile.TemporaryDirectory() as d:
            a, b = Path(d, "a.json"), Path(d, "b.json")
            a.write_text(json.dumps(report(hash_ring=["41\ta"])))
            b.write_text(json.dumps(report(seat=2, hash_ring=["41\ta"])))
            tool = str(Path(__file__).parent / "desync_diff.py")
            self.assertEqual(
                subprocess.run([sys.executable, tool, str(a), str(b)], capture_output=True, check=False).returncode, 0
            )
            b.write_text(json.dumps(report(command_log=[], hash_ring=["41\tb"])))
            run = subprocess.run([sys.executable, tool, str(a), str(b)], capture_output=True, text=True, check=False)
            self.assertEqual(run.returncode, 1)
            self.assertIn("ring diverges at tick 41", run.stdout)
            b.write_text(json.dumps(report(seat=2, hash_ring=["41\tb"])))
            run = subprocess.run([sys.executable, tool, str(a), str(b)], capture_output=True, text=True, check=False)
            self.assertEqual(run.returncode, 1)
            self.assertIn("RING ONLY", run.stdout)
            self.assertNotIn("IDENTICAL", run.stdout)


if __name__ == "__main__":
    unittest.main()
