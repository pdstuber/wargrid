import io
import json
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
REAL_ARCHIVE = zh_ini.DEFAULT_ARCHIVE


# Unindented lines inside a block: `Key Value` fields without "=" and nested bare ParticleSystem openers.
UNINDENTED_IN_BLOCK = {"OptionsButtonDisabled", "BuddyButtonDisabled", "BeaconButtonDisabled", "ParticleSystem"}


def parse(text: str, bare_only: frozenset[str] = frozenset()) -> list[zh_ini.Block]:
    with (
        mock.patch.object(zh_ini, "OPENERS", frozenset({"Module"})),
        mock.patch.object(zh_ini, "BARE_ONLY", bare_only),
    ):
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

    def test_end_with_trailing_token(self) -> None:
        (block,) = parse("A\n  X = 1\nEnd Foo\n")
        self.assertEqual(block["end_line"], 3)

    def test_top_level_opener_key_value(self) -> None:
        (block,) = parse("Module = Low\n  X = 1\nEnd\n")
        self.assertEqual((block["kind"], block["name"], block["end_line"]), ("Module", "Low", 3))

    def test_bare_only_with_equals_is_field(self) -> None:
        (block,) = parse("A\n  Module = Foo\n  Y = 1\nEnd\n", frozenset({"Module"}))
        self.assertEqual([(f["key"], f["path"]) for f in block["fields"]], [("Module", []), ("Y", [])])

    def test_path_whitespace_collapsed(self) -> None:
        (block,) = parse("A\n  Module   =   Spin   Tag\n    Rate = 3\n  End\nEnd\n")
        self.assertEqual(block["fields"][0]["path"], ["Module = Spin Tag"])

    def test_double_slash_inside_value_kept(self) -> None:
        (block,) = parse("A\n  Url = http://x.y/z // note\nEnd\n")
        self.assertEqual(block["fields"][0]["value"], "http://x.y/z")

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

    def test_failed_run_keeps_previous_dump(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "dump.jsonl"
            out.write_text("old\n", encoding="utf-8")
            archive = Path(tmp) / "x.big"
            archive.write_bytes(big({ENTRY: "Widget A\n  X = 1\n"}))
            with mock.patch.object(sys, "stderr", io.StringIO()):
                code = zh_ini.main(["dump", str(archive), "--out", str(out), "--skip-hash"], io.StringIO())
            self.assertEqual(code, 1)
            self.assertEqual(out.read_text(encoding="utf-8"), "old\n")
            self.assertFalse(out.with_name("dump.jsonl.tmp").exists())


@unittest.skipUnless(REAL_ARCHIVE.exists(), "retail archive not present")
class RealArchiveTest(unittest.TestCase):
    def assert_column_zero_lines_start_blocks(
        self, files: dict[str, str], parsed: dict[str, list[zh_ini.Block]]
    ) -> None:
        stray = []
        for name, blocks in parsed.items():
            starts = {b["line"] for b in blocks}
            for number, raw in enumerate(files[name].splitlines(), 1):
                tokens = raw.split()
                if raw[:1].isspace() or not tokens or raw[0] in ";/" or "=" in raw:
                    continue
                if tokens[0].lower() != "end" and tokens[0] not in UNINDENTED_IN_BLOCK and number not in starts:
                    stray.append((name, number))
        self.assertEqual(stray, [])
        for entry, kind, line in (
            ("data\\ini\\soundeffects.ini", "AudioEvent", 19),
            ("data\\ini\\object\\americavehicle.ini", "Object", 2057),
        ):
            self.assertIn((kind, line), {(b["kind"], b["line"]) for b in parsed[entry]})

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
        self.assert_column_zero_lines_start_blocks(files, parsed)
        boxes = [f for f in find("data\\ini\\object\\civilianbuilding.ini", "StartingBoxes") if f["line"] == 406]
        self.assertEqual(len(boxes), 1)
        self.assertTrue(boxes[0]["value"].startswith("400"))


if __name__ == "__main__":
    unittest.main()
