import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import desync_bisect
from desync_bisect import seat_verdict, wire_lines

LOCAL = [f"{i:016x}" for i in range(1, 65)]


def ring(digests, start=1):
    return [f"{start + i}\t{d}" for i, d in enumerate(digests)]


def snapshot(credits):
    return {"tick": 60, "players": [{"id": 1, "credits": 9200}, {"id": 2, "credits": credits}]}


def report(seat, digests, start=1, credits=9200, log=None, **changes):
    base = {
        "seat": seat,
        "tick": 60,
        "map": "skirmish",
        "seed": 7,
        "starts": [],
        "command_log": log if log is not None else [{"type": "choose_faction", "tick": 4, "player": 1, "sequence": 0}],
        "snapshot": snapshot(credits),
        "hash_ring": ring(digests, start),
    }
    base.update(changes)
    return base


def perturbed(from_tick):
    return LOCAL[: from_tick - 1] + [f"{9000 + i:016x}" for i in range(from_tick, 65)]


class FakeOracle:
    def __init__(self, digests, credits=9200, ok=True):
        self.digests, self.credits, self.ok = digests, credits, ok
        self.calls = []

    def __call__(self, client, report, out, tag, ticks, state_ticks=None):
        self.calls.append((client, tag, ticks, state_ticks))
        if not self.ok:
            return False
        digests = self.digests[tag] if isinstance(self.digests, dict) else self.digests
        credits = self.credits[tag] if isinstance(self.credits, dict) else self.credits
        Path(out, f"ring-{tag}.tsv").write_text("".join(f"{r}\n" for r in ring(digests[:ticks])))
        for tick in state_ticks or []:
            folder = Path(out, tag)
            folder.mkdir(parents=True, exist_ok=True)
            snap = {**snapshot(credits), "tick": tick}
            folder.joinpath(f"tick-{tick}.json").write_text(json.dumps(snap))
        return True


class BisectCase(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.out = Path(self.dir.name, "out")

    def write(self, name, data):
        path = Path(self.dir.name, name)
        path.write_text(json.dumps(data))
        return str(path)

    def run_main(self, args, fake):
        buffer = io.StringIO()
        with mock.patch.object(desync_bisect, "replay", fake), contextlib.redirect_stdout(buffer):
            code = desync_bisect.main([*args, "--out", str(self.out)])
        return code, buffer.getvalue()


class WireLinesTests(unittest.TestCase):
    def test_groups_by_tick_in_log_order(self):
        log = [
            {"type": "stop", "tick": 5, "player": 1},
            {"type": "stop", "tick": 3, "player": 1},
            {"type": "stop", "tick": 5, "player": 2},
        ]
        lines = wire_lines(log)
        self.assertEqual(len(lines), 2)
        first = json.loads(lines[0])
        self.assertEqual((first["type"], first["seat"], first["tick"]), ("tick", 0, 5))
        self.assertEqual([c["player"] for c in first["commands"]], [1, 2])
        self.assertEqual(json.loads(lines[1])["tick"], 3)

    def test_line_is_sorted_json(self):
        line = wire_lines([{"type": "stop", "tick": 3}])[0]
        self.assertEqual(line, json.dumps(json.loads(line), sort_keys=True))

    def test_empty_log(self):
        self.assertEqual(wire_lines([]), [])


class SeatVerdictTests(unittest.TestCase):
    def test_match(self):
        self.assertIsNone(seat_verdict(ring(LOCAL), LOCAL))

    def test_first_differing_tick(self):
        self.assertEqual(seat_verdict(ring(perturbed(41)), LOCAL), 41)

    def test_ring_starting_late(self):
        self.assertIsNone(seat_verdict(ring(LOCAL[20:], 21), LOCAL))
        self.assertEqual(seat_verdict(ring(perturbed(41)[20:], 21), LOCAL), 41)

    def test_ring_past_local_end_is_ignored(self):
        self.assertIsNone(seat_verdict([*ring(LOCAL), "99\tffff"], LOCAL))

    def test_no_shared_ticks(self):
        self.assertIsNone(seat_verdict(["500\tffff"], LOCAL))


class MainTests(BisectCase):
    def test_different_command_logs(self):
        a = self.write("a.json", report(1, LOCAL))
        b = self.write("b.json", report(2, LOCAL, log=[]))
        fake = FakeOracle(LOCAL)
        code, text = self.run_main([a, b], fake)
        self.assertEqual(code, 1)
        self.assertIn("COMMAND LOGS DIFFER command_log", text)
        self.assertEqual(fake.calls, [])

    def test_seat_two_diverges(self):
        a = self.write("a.json", report(1, LOCAL))
        b = self.write("b.json", report(2, perturbed(41), credits=9201))
        fake = FakeOracle(LOCAL)
        code, text = self.run_main([a, b], fake)
        self.assertEqual(code, 1)
        self.assertIn("RINGS DIVERGE AT TICK 41\n", text)
        self.assertIn("SEAT 1 MATCHES LOCAL REPLAY\n", text)
        self.assertIn("SEAT 2 DIVERGES FROM LOCAL REPLAY AT TICK 41\n", text)
        first_field = next(line for line in text.splitlines() if line.startswith("SEAT 2 FIRST FIELD"))
        self.assertIn("players", first_field)
        self.assertNotIn("SEAT 1 FIRST FIELD", text)
        self.assertIn(f"SNAPSHOTS {self.out}", text)
        pass_two = [call for call in fake.calls if call[3]]
        self.assertEqual(len(pass_two), 1)
        self.assertEqual(pass_two[0][3], [40, 41, 60])

    def test_all_match(self):
        a = self.write("a.json", report(1, LOCAL))
        b = self.write("b.json", report(2, LOCAL))
        fake = FakeOracle(LOCAL)
        code, text = self.run_main([a, b], fake)
        self.assertEqual(code, 0)
        self.assertIn("RINGS AGREE\n", text)
        self.assertIn("SEAT 1 MATCHES LOCAL REPLAY\n", text)
        self.assertIn("SEAT 2 MATCHES LOCAL REPLAY\n", text)
        self.assertEqual(len(fake.calls), 1)

    def test_single_report_late_ring(self):
        a = self.write("a.json", report(1, LOCAL[30:], start=31))
        code, text = self.run_main([a], FakeOracle(LOCAL))
        self.assertEqual(code, 0)
        self.assertNotIn("RINGS", text)
        self.assertIn("SEAT 1 MATCHES LOCAL REPLAY\n", text)

    def test_seat_without_ring(self):
        data = report(1, LOCAL)
        del data["hash_ring"]
        a = self.write("a.json", data)
        code, text = self.run_main([a], FakeOracle(LOCAL))
        self.assertEqual(code, 1)
        self.assertIn("SEAT 1 HAS NO RING\n", text)

    def test_oracle_failure(self):
        a = self.write("a.json", report(1, LOCAL))
        code, text = self.run_main([a], FakeOracle(LOCAL, ok=False))
        self.assertEqual(code, 2)
        self.assertIn("BISECT FAILED", text)

    def test_unreadable_report(self):
        code, text = self.run_main([str(Path(self.dir.name, "missing.json"))], FakeOracle(LOCAL))
        self.assertEqual(code, 2)
        self.assertIn("BISECT FAILED", text)

    def test_clients_diverge(self):
        a = self.write("a.json", report(1, LOCAL))
        fake = FakeOracle({"a": LOCAL, "b": perturbed(3)}, credits={"a": 9200, "b": 9201})
        code, text = self.run_main([a, "--client-b", "other-client --flag"], fake)
        self.assertEqual(code, 1)
        line = next(line for line in text.splitlines() if line.startswith("CLIENTS DIVERGE"))
        self.assertTrue(line.startswith("CLIENTS DIVERGE AT TICK 3 FIRST FIELD "), line)
        self.assertIn("players", line)
        self.assertIn((["other-client", "--flag"], "b", 64, None), [c for c in fake.calls if c[1] == "b"])

    def test_clients_match(self):
        a = self.write("a.json", report(1, LOCAL))
        code, text = self.run_main([a, "--client-b", "other-client"], FakeOracle(LOCAL))
        self.assertEqual(code, 0)
        self.assertIn("CLIENTS MATCH 64 TICKS\n", text)


if __name__ == "__main__":
    unittest.main()
