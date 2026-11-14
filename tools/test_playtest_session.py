import base64
import contextlib
import io
import json
import os
import subprocess
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
                "build": "0.11.0-dev+abc1234",
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
                "factions": ["usa", "china"],
                "build": "0.11.0-dev+def5678",
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
            "MATCH 1 offline skirmish seed=7 seat=1 end_tick=60 build=0.11.0-dev+abc1234 result=win",
            f'MARKER 1.1 tick=30 good text="nice" comment="" camera=4.5,14.5 selected=1,2 jpg={jpgs[0]}',
            'MARKER 1.2 tick=60 bad text="no pic" comment="" camera=4.5,14.5 selected=1,2 jpg=-',
            "MATCH 2 online dry_wells seed=3 seat=0 end_tick=90 build=0.11.0-dev+def5678 result=",
        ]
        self.assertEqual(ps.summary_lines(s, jpgs), expected)

    def test_write_jpgs(self):
        jpgs = ps.write_jpgs(ps.load_session(self.path), self.path)
        self.assertEqual(jpgs, [self.path.parent / "sess-m1-1.jpg", None])
        self.assertEqual(self.path.parent.joinpath("sess-m1-1.jpg").read_bytes()[:2], b"\xff\xd8")

    def test_replay_rows(self):
        rows = [r.split("\t") for r in ps.replay_rows(ps.load_session(self.path), self.path)]
        cmd1 = self.path.parent / "sess-m1.cmd"
        self.assertEqual(
            rows[0],
            ["1", str(cmd1), "offline", "skirmish", "7", "frc,china", "60", "aa", "30,60", "0.11.0-dev+abc1234"],
        )
        self.assertEqual(rows[1][5], "-", "online rows pass no --factions")
        self.assertEqual(rows[1][8], "-")
        self.assertEqual(rows[1][9], "0.11.0-dev+def5678")
        self.assertEqual(cmd1.read_text(), "line one\nline two\n")

    def test_float_numbers_from_a_resumed_sitting(self):
        floaty = session()
        floaty["format"] = 1.0
        for m in floaty["matches"]:
            for key in ("seed", "seat", "end_tick"):
                m[key] = float(m[key])
            for mk in m["markers"]:
                mk["tick"] = float(mk["tick"])
                mk["selected"] = [float(e) for e in mk["selected"]]
        for answer in floaty["answers"].values():
            answer["score"] = float(answer["score"])
        self.path.write_text(json.dumps(floaty))
        s = ps.load_session(self.path)
        self.assertEqual(
            ps.summary_lines(s, [None, None]), ps.summary_lines(ps.load_session(self._write(session())), [None, None])
        )
        rows = [r.split("\t") for r in ps.replay_rows(s, self.path)]
        self.assertEqual(rows[0][4:9], ["7", "frc,china", "60", "aa", "30,60"])

    def _write(self, data):
        other = self.path.with_name("plain.json")
        other.write_text(json.dumps(data))
        return other

    def test_rejects_other_format(self):
        bad = session()
        bad["format"] = 2
        self.path.write_text(json.dumps(bad))
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            code = ps.main([str(self.path)])
        self.assertEqual(code, 2)
        self.assertIn("unsupported session format", err.getvalue())

    def _replay(self, client_exit, extra=""):
        one = session()
        one["matches"] = one["matches"][:1]
        self.path.write_text(json.dumps(one))
        fake = Path(self._tmp.name) / "fake_client.sh"
        fake.write_text(f"#!/bin/sh\necho 'ORACLE FINAL 60 aa'\n{extra}exit {client_exit}\n")
        fake.chmod(0o755)
        script = Path(__file__).resolve().parent / "replay_session.sh"
        env = {**os.environ, "WARGRID_CLIENT": str(fake), "PYTHON": sys.executable}
        return subprocess.run(["sh", str(script), str(self.path)], env=env, capture_output=True, text=True, check=False)

    def test_replay_wrapper_needs_client_success(self):
        passed = self._replay(0)
        self.assertEqual((passed.returncode, "REPLAY MATCHED 1" in passed.stdout), (0, True), passed.stdout)
        crashed = self._replay(1)
        self.assertNotEqual(crashed.returncode, 0, crashed.stdout)
        self.assertNotIn("REPLAY MATCHED", crashed.stdout)
        errored = self._replay(0, "echo 'SCRIPT ERROR: boom'\n")
        self.assertEqual((errored.returncode, "REPLAY MATCHED" in errored.stdout), (1, False), errored.stdout)


if __name__ == "__main__":
    unittest.main()
