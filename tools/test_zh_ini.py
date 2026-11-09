import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_reference as ref
import zh_ini
from test_check_reference import big

ENTRY = "data\\ini\\test.ini"
FIXTURE = """; header comment
Widget Alpha
  Speed = 12 ; trailing comment
  Module = SpinUpdate Tag_01
    Rate = 3 // other comment
  END
  Label   Hello World
End
Gadget
  Size = 4
End ; closing comment
Reskin Beta Alpha
End
"""
REAL_ARCHIVE = Path(os.environ["HOME"]) / "CnC/run/Command & Conquer Generals - Zero Hour/INIZH.big"


def parse(text: str) -> list[zh_ini.Block]:
    with mock.patch.object(zh_ini, "OPENERS", frozenset({"Module"})):
        return zh_ini.parse_entry(ENTRY, text)


class ParseTest(unittest.TestCase):
    def test_blocks_and_lines(self) -> None:
        widget, gadget, reskin = parse(FIXTURE)
        self.assertEqual((widget["line"], widget["end_line"], widget["name"], widget["args"]), (2, 8, "Alpha", []))
        self.assertEqual((gadget["line"], gadget["end_line"], gadget["name"]), (9, 11, None))
        self.assertEqual((reskin["line"], reskin["name"], reskin["args"]), (12, "Beta", ["Alpha"]))

    def test_fields_and_comments(self) -> None:
        widget, gadget, _ = parse(FIXTURE)
        got = [(f["key"], f["value"], f["line"], f["path"]) for f in widget["fields"]]
        self.assertEqual(
            got,
            [
                ("Speed", "12", 3, []),
                ("Rate", "3", 5, ["Module = SpinUpdate Tag_01"]),
                ("Label", "Hello World", 7, []),
            ],
        )
        self.assertEqual([(f["key"], f["value"], f["line"]) for f in gadget["fields"]], [("Size", "4", 10)])

    def test_end_case_and_comment(self) -> None:
        blocks = parse("A\n  X = 1\nEND\nB\n  Y = 2\nEnd ; done\n")
        self.assertEqual([(b["kind"], b["end_line"]) for b in blocks], [("A", 3), ("B", 6)])

    def test_unbalanced_raises(self) -> None:
        with self.assertRaisesRegex(ValueError, r"test\.ini.*2"):
            parse("\nWidget A\n  X = 1\n")
        with self.assertRaisesRegex(ValueError, r"test\.ini.*3"):
            parse("A\nEnd\nEnd\n")

    def test_top_level_field(self) -> None:
        (only,) = parse("Mode = Fast\n")
        self.assertEqual((only["kind"], only["name"], only["end_line"], len(only["fields"])), ("Mode", None, 1, 1))


class DumpTest(unittest.TestCase):
    def test_dump_and_cli(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / "x.big"
            archive.write_bytes(big({ENTRY: FIXTURE, "data\\other.txt": "ignored"}))
            out = Path(tmp) / "sub" / "dump.jsonl"
            stream = io.StringIO()
            with mock.patch.object(zh_ini, "OPENERS", frozenset({"Module"})):
                code = zh_ini.main(["dump", str(archive), "--out", str(out), "--skip-hash"], stream)
            self.assertEqual(code, 0)
            self.assertRegex(stream.getvalue(), r"^ZH_INI entries=1 blocks=3 fields=4 out=")
            rows = [json.loads(line) for line in out.read_text(encoding="utf-8").splitlines()]
            self.assertEqual(len(rows), 3)
            for row in rows:
                self.assertEqual(set(row), {"entry", "line", "end_line", "kind", "name", "args", "fields"})

    def test_missing_archive(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "dump.jsonl"
            stderr = io.StringIO()
            with mock.patch.object(sys, "stderr", stderr):
                code = zh_ini.main(["dump", str(Path(tmp) / "none.big"), "--out", str(out)], io.StringIO())
            self.assertEqual(code, 1)
            self.assertTrue(stderr.getvalue())
            self.assertFalse(out.exists())


@unittest.skipUnless(REAL_ARCHIVE.exists(), "retail archive not present")
class RealArchiveTest(unittest.TestCase):
    def test_real_archive(self) -> None:
        files = ref.load_archive(str(REAL_ARCHIVE))
        parsed = {name: zh_ini.parse_entry(name, text) for name, text in files.items() if name.endswith(".ini")}
        self.assertEqual(len(parsed), 135)

        def find(entry: str, key: str, kind: str | None = None, name: str | None = None) -> list[zh_ini.Field]:
            return [
                f
                for b in parsed[entry]
                if (kind is None or b["kind"] == kind) and (name is None or b["name"] == name)
                for f in b["fields"]
                if f["key"] == key
            ]

        (supply,) = find("data\\ini\\gamedata.ini", "ValuePerSupplyBox")
        self.assertEqual((supply["value"], supply["line"]), ("75", 248))
        (respawn,) = find("data\\ini\\object\\factionbuilding.ini", "WorkerRespawnDelay", "Object", "GLAHole")
        self.assertTrue(respawn["value"].startswith("20000"))
        self.assertEqual(respawn["line"], 143)
        self.assertEqual(len(respawn["path"]), 1)
        self.assertTrue(respawn["path"][0].startswith("Behavior = RebuildHoleBehavior"))
        boxes = [f for f in find("data\\ini\\object\\civilianbuilding.ini", "StartingBoxes") if f["line"] == 406]
        self.assertEqual(len(boxes), 1)
        self.assertTrue(boxes[0]["value"].startswith("400"))


if __name__ == "__main__":
    unittest.main()
