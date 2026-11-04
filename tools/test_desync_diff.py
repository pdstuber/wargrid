import json
from pathlib import Path
import tempfile
import unittest

from desync_diff import first_difference


def report(**changes):
    base = {"seat": 1, "tick": 60, "hash_rows": ["0\ta"], "command_log": [{"type": "move", "tick": 4}], "snapshot": {"players": {"1": {"credits": 5}}, "entities": [{"position": [14.1, 2.0]}]}}
    base.update(changes)
    return base


class DesyncDiffTests(unittest.TestCase):
    def test_identical_ignores_seat_and_hash_rows(self):
        self.assertIsNone(first_difference(report(), report(seat=2, hash_rows=["0\tb"])))

    def test_command_log_index(self):
        other = report(command_log=[{"type": "move", "tick": 4}, {"type": "stop", "tick": 5}])
        self.assertIn("command_log[1]", first_difference(report(), other))

    def test_command_log_content(self):
        other = report(command_log=[{"type": "stop", "tick": 4}])
        self.assertIn("command_log[0]", first_difference(report(), other))

    def test_snapshot_path_and_values(self):
        other = report(snapshot={"players": {"1": {"credits": 5}}, "entities": [{"position": [14.100000000000001, 2.0]}]})
        text = first_difference(report(), other)
        self.assertIn("snapshot.entities[0].position[0]", text)
        self.assertIn("14.1 != 14.100000000000001", text)

    def test_names_players(self):
        other = report(snapshot={"players": {"1": {"credits": 6}}, "entities": [{"position": [14.1, 2.0]}]})
        self.assertIn("players", first_difference(report(), other))

    def test_int_versus_float(self):
        other = report(snapshot={"players": {"1": {"credits": 5.0}}, "entities": [{"position": [14.1, 2.0]}]})
        self.assertIsNotNone(first_difference(report(), other))

    def test_missing_key(self):
        other = report(snapshot={"players": {}, "entities": []})
        self.assertIsNotNone(first_difference(report(), other))

    def test_cli_exit_codes(self):
        import subprocess, sys
        with tempfile.TemporaryDirectory() as d:
            a, b = Path(d, "a.json"), Path(d, "b.json")
            a.write_text(json.dumps(report()))
            b.write_text(json.dumps(report(seat=2)))
            tool = str(Path(__file__).parent / "desync_diff.py")
            self.assertEqual(subprocess.run([sys.executable, tool, str(a), str(b)], capture_output=True).returncode, 0)
            b.write_text(json.dumps(report(command_log=[])))
            self.assertEqual(subprocess.run([sys.executable, tool, str(a), str(b)], capture_output=True).returncode, 1)


if __name__ == "__main__":
    unittest.main()
