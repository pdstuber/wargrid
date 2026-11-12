import base64
import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import playtest_session as ps

JPG = base64.b64encode(bytes([0xFF, 0xD8, 0xFF, 0xD9])).decode()


def marker(tick, kind, text, jpg):
    return {
        "tick": tick,
        "kind": kind,
        "text": text,
        "comment": "",
        "camera": [4.5, 14.5],
        "selected": [1, 2],
        "jpg": jpg,
    }


def session():
    return {
        "format": 1,
        "build": "0.11.0-dev+abc1234",
        "focus": "p1-frc-economy",
        "started": "2026-11-12T12:00:00",
        "checklist": {"a": True, "b": False},
        "answers": {"q1": {"score": 4, "text": 'fine "quoted"'}},
        "matches": [
            {
                "mode": "offline",
                "map": "skirmish",
                "seed": 7,
                "factions": ["frc", "china"],
                "seat": 1,
                "end_tick": 60,
                "end_digest": "aa",
                "result": "win",
                "markers": [marker(30, "good", "nice", JPG), marker(60, "bad", "no pic", "")],
                "commands": ["line one", "line two"],
            },
            {
                "mode": "online",
                "map": "dry_wells",
                "seed": 3,
                "factions": [],
                "seat": 0,
                "end_tick": 90,
                "end_digest": "bb",
                "result": "",
                "markers": [],
                "commands": ["line three"],
            },
        ],
    }


class PlaytestSessionTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.path = Path(self._tmp.name) / "sess.json"
        self.path.write_text(json.dumps(session()))

    def test_summary_lines(self):
        s = ps.load_session(self.path)
        jpgs = [self.path.parent / "sess-m1-1.jpg", None]
        expected = [
            "SESSION build=0.11.0-dev+abc1234 focus=p1-frc-economy started=2026-11-12T12:00:00 matches=2",
            "CHECK a yes",
            "CHECK b no",
            'ANSWER q1 4 fine "quoted"',
            "MATCH 1 offline skirmish seed=7 seat=1 end_tick=60 result=win",
            f'MARKER 1.1 tick=30 good text="nice" comment="" camera=4.5,14.5 selected=1,2 jpg={jpgs[0]}',
            'MARKER 1.2 tick=60 bad text="no pic" comment="" camera=4.5,14.5 selected=1,2 jpg=-',
            "MATCH 2 online dry_wells seed=3 seat=0 end_tick=90 result=",
        ]
        self.assertEqual(ps.summary_lines(s, jpgs), expected)

    def test_write_jpgs(self):
        jpgs = ps.write_jpgs(ps.load_session(self.path), self.path)
        self.assertEqual(jpgs, [self.path.parent / "sess-m1-1.jpg", None])
        self.assertEqual(self.path.parent.joinpath("sess-m1-1.jpg").read_bytes()[:2], b"\xff\xd8")

    def test_replay_rows(self):
        rows = [r.split("\t") for r in ps.replay_rows(ps.load_session(self.path), self.path)]
        cmd1 = self.path.parent / "sess-m1.cmd"
        self.assertEqual(rows[0], ["1", str(cmd1), "offline", "skirmish", "7", "frc,china", "60", "aa", "30,60"])
        self.assertEqual(rows[1][5], "-")
        self.assertEqual(rows[1][8], "-")
        self.assertEqual(cmd1.read_text(), "line one\nline two\n")

    def test_rejects_other_format(self):
        bad = session()
        bad["format"] = 2
        self.path.write_text(json.dumps(bad))
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            code = ps.main([str(self.path)])
        self.assertEqual(code, 2)
        self.assertIn("unsupported session format", err.getvalue())


if __name__ == "__main__":
    unittest.main()
