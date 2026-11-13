import io
import json
import math
import struct
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import zh_w3d
from test_check_reference import big

S = math.sqrt(0.5)  # 90 degrees about z: (0, 0, S, S)
ROOT = ("ROOTTRANSFORM", -1, (0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0))


def chunk(kind: int, payload: bytes, sub: bool = False) -> bytes:
    return struct.pack("<II", kind, len(payload) | (0x80000000 if sub else 0)) + payload


def mesh(container: str, name: str, lo, hi, attributes: int = 0) -> bytes:
    head = struct.pack(
        "<II16s16s9I3f3f3ff", 0x40002, attributes, name.encode(), container.encode(), *[0] * 9, *lo, *hi, 0, 0, 0, 0
    )
    return chunk(0x000, chunk(0x01F, head), sub=True)


def hierarchy(name: str, pivots) -> bytes:
    head = struct.pack("<I16sI3f", 0x40001, name.encode(), len(pivots), 0, 0, 0)
    body = b"".join(struct.pack("<16sI3f3f4f", n.encode(), p & 0xFFFFFFFF, *t, 0, 0, 0, *q) for n, p, t, q in pivots)
    return chunk(0x100, chunk(0x101, head) + chunk(0x102, body), sub=True)


def hlod(name: str, hier: str, subs) -> bytes:
    lods = chunk(0x703, struct.pack("<If", len(subs), 0.0)) + b"".join(
        chunk(0x704, struct.pack("<I32s", b, s.encode())) for b, s in subs
    )
    head = struct.pack("<II16s16s", 0x10000, 1, name.encode(), hier.encode())
    return chunk(0x700, chunk(0x701, head) + chunk(0x702, lods, sub=True), sub=True)


def box(full_name: str) -> bytes:
    return chunk(0x740, struct.pack("<II32s4B3f3f", 0, 0, full_name.encode(), 0, 0, 0, 0, 0, 0, 0, 1, 1, 1))


TANK = (
    hierarchy("TANK", [ROOT, ("HULL", 0, (1, 0, 0), (0, 0, S, S)), ("GUN", 1, (2, 0, 1), (0, 0, 0, 1))])
    + mesh("TANK", "HULL", (0, 0, 0), (2, 1, 1))
    + mesh("TANK", "GUN", (0, 0, 0), (1, 0.5, 0.5))
    + mesh("TANK", "MUZZLEFX01", (0, 0, 0), (5, 5, 5))
    + mesh("TANK", "SECRET", (-9, -9, -9), (9, 9, 9), 0x1000)
    + box("TANK.PICKBOX")
    + hlod(
        "TANK",
        "TANK",
        [
            (1, "TANK.HULL"),
            (2, "TANK.GUN"),
            (2, "TANK.MUZZLEFX01"),
            (0, "TANK.SECRET"),
            (0, "TANK.PICKBOX"),
            (0, "TANK.GHOST"),
        ],
    )
)
SKELETON = hierarchy("SOLDIER_SKL", [ROOT, ("HAND", 0, (0, 0, 3), (0, 0, 0, 1))])
SKIN = (
    mesh("SOLDIER_SKN", "BODY", (-1, -1, 0), (1, 1, 4), 0x20000)
    + mesh("SOLDIER_SKN", "RIFLE", (0, 0, 0), (0, 2, 0.5))
    + hlod("SOLDIER_SKN", "SOLDIER_SKL", [(0, "SOLDIER_SKN.BODY"), (1, "SOLDIER_SKN.RIFLE")])
)


def tank_row() -> zh_w3d.Row:
    rows, skips = zh_w3d.build_rows([("W3D.big", "tank.w3d", TANK)])
    assert skips == [] and len(rows) == 1
    return rows[0]


def mesh_by_name(row: zh_w3d.Row, name: str) -> zh_w3d.Mesh:
    return next(m for m in row["meshes"] if m["name"] == name)


class WalkTest(unittest.TestCase):
    def test_walk_masks_sub_chunk_flag(self):
        self.assertEqual(list(zh_w3d.walk(chunk(0x100, b"abcd", sub=True), 0, 12)), [(0x100, 8, 12)])

    def test_walk_overrun_raises(self):
        with self.assertRaises(ValueError):
            list(zh_w3d.walk(struct.pack("<II", 0x0, 99) + b"x", 0, 9))


class BoundsTest(unittest.TestCase):
    def test_mesh_header_bounded_by_chunk(self):
        short = chunk(0x000, chunk(0x01F, b"\0" * 4) + chunk(0x999, b"\0" * 200), sub=True)
        with self.assertRaises(ValueError):
            zh_w3d.parse_entry(short)

    def test_pivot_count_bounded_by_chunk(self):
        head = struct.pack("<I16sI3f", 0x40001, b"BAD", 3, 0, 0, 0)
        pivot = struct.pack("<16sI3f3f4f", b"ROOT", 0xFFFFFFFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
        data = chunk(0x100, chunk(0x101, head) + chunk(0x102, pivot) + chunk(0x999, b"\0" * 200), sub=True)
        with self.assertRaises(ValueError):
            zh_w3d.parse_entry(data)

    def test_sub_object_bounded_by_chunk(self):
        lods = chunk(0x704, b"\0" * 4) + chunk(0x999, b"\0" * 100)
        head = struct.pack("<II16s16s", 0x10000, 1, b"BAD", b"BAD")
        data = chunk(0x700, chunk(0x701, head) + chunk(0x702, lods, sub=True), sub=True)
        with self.assertRaises(ValueError):
            zh_w3d.parse_entry(data)


class RowsTest(unittest.TestCase):
    def test_bone_positions_compose_rotation(self):
        pivots = [(b["name"], b["parent"], b["position"]) for b in tank_row()["pivots"]]
        self.assertEqual(
            pivots,
            [("ROOTTRANSFORM", -1, [0.0, 0.0, 0.0]), ("HULL", 0, [1.0, 0.0, 0.0]), ("GUN", 1, [1.0, 2.0, 1.0])],
        )

    def test_rigid_mesh_box_in_model_space(self):
        row = tank_row()
        hull, gun = mesh_by_name(row, "TANK.HULL"), mesh_by_name(row, "TANK.GUN")
        self.assertEqual(hull["bone"], 1)
        self.assertEqual((hull["min"], hull["max"]), ([0.0, 0.0, 0.0], [1.0, 2.0, 1.0]))
        self.assertEqual((gun["min"], gun["max"]), ([0.5, 2.0, 1.0], [1.0, 3.0, 1.5]))

    def test_body_excludes_hidden_and_fx(self):
        row = tank_row()
        self.assertEqual(row["body"], {"min": [0.0, 0.0, 0.0], "max": [1.0, 3.0, 1.5], "size": [1.0, 3.0, 1.5]})
        self.assertEqual(row["excluded"], ["TANK.MUZZLEFX01", "TANK.SECRET"])
        self.assertTrue(mesh_by_name(row, "TANK.SECRET")["hidden"])

    def test_box_dropped_missing_listed(self):
        row = tank_row()
        self.assertEqual(row["unresolved"], ["TANK.GHOST"])
        self.assertEqual(
            [m["name"] for m in row["meshes"]], ["TANK.HULL", "TANK.GUN", "TANK.MUZZLEFX01", "TANK.SECRET"]
        )
        self.assertEqual(
            set(row), {"entry", "archive", "hlod", "hierarchy", "meshes", "pivots", "body", "excluded", "unresolved"}
        )
        self.assertEqual(row["archive"], "W3D.big")

    def test_skin_uses_hierarchy_from_other_entry(self):
        rows, skips = zh_w3d.build_rows(
            [("W3D.big", "soldier_skl.w3d", SKELETON), ("W3D.big", "soldier_skn.w3d", SKIN)]
        )
        self.assertEqual(skips, [])
        skeleton, skin = rows
        self.assertEqual((skin["hierarchy"], skin["pivots"]), ("SOLDIER_SKL", []))
        body, rifle = mesh_by_name(skin, "SOLDIER_SKN.BODY"), mesh_by_name(skin, "SOLDIER_SKN.RIFLE")
        self.assertTrue(body["skin"])
        self.assertEqual(body["min"], [-1.0, -1.0, 0.0])
        self.assertEqual((rifle["min"], rifle["max"]), ([0.0, 0.0, 3.0], [0.0, 2.0, 3.5]))
        assert skin["body"] is not None
        self.assertEqual(skin["body"]["size"], [2.0, 3.0, 4.0])
        self.assertEqual((skeleton["meshes"], skeleton["body"], skeleton["hlod"]), ([], None, None))
        self.assertEqual(skeleton["hierarchy"], "SOLDIER_SKL")

    def test_skin_box_ignores_nonidentity_bone(self):
        skin = mesh("SOLDIER_SKN", "BODY", (-1, -1, 0), (1, 1, 4), 0x20000) + hlod(
            "SOLDIER_SKN", "SOLDIER_SKL", [(1, "SOLDIER_SKN.BODY")]
        )
        rows, _ = zh_w3d.build_rows([("W3D.big", "soldier_skl.w3d", SKELETON), ("W3D.big", "soldier_skn.w3d", skin)])
        body = mesh_by_name(rows[1], "SOLDIER_SKN.BODY")
        self.assertEqual((body["bone"], body["min"], body["max"]), (1, [-1.0, -1.0, 0.0], [1.0, 1.0, 4.0]))

    def test_missing_hierarchy_rigid_unresolved(self):
        rows, _ = zh_w3d.build_rows([("W3D.big", "soldier_skn.w3d", SKIN)])
        self.assertEqual(rows[0]["unresolved"], ["SOLDIER_SKN.RIFLE"])
        assert rows[0]["body"] is not None
        self.assertEqual(rows[0]["body"]["size"], [2.0, 2.0, 4.0])

    def test_no_hlod_mesh_identity(self):
        rows, _ = zh_w3d.build_rows([("W3D.big", "rock.w3d", mesh("", "ROCK", (-1, -2, 0), (1, 2, 3)))])
        row = rows[0]
        self.assertEqual(len(row["meshes"]), 1)
        rock = row["meshes"][0]
        self.assertEqual((rock["name"], rock["bone"], rock["min"]), ("ROCK", None, [-1.0, -2.0, 0.0]))
        self.assertIsNone(row["hlod"])
        assert row["body"] is not None
        self.assertEqual(row["body"]["size"], [2.0, 4.0, 3.0])

    def test_bad_entry_skipped(self):
        bad = ("W3D.big", "bad.w3d", struct.pack("<II", 0x0, 99))
        rows, skips = zh_w3d.build_rows([bad, ("W3D.big", "tank.w3d", TANK)])
        self.assertEqual([r["entry"] for r in rows], ["tank.w3d"])
        self.assertEqual(len(skips), 1)
        self.assertTrue(skips[0].startswith("bad.w3d: "))

    def test_animation_only_no_row(self):
        rows, skips = zh_w3d.build_rows([("W3D.big", "anim.w3d", chunk(0x200, b"\0" * 8, sub=True))])
        self.assertEqual((rows, skips), ([], []))

    def test_parent_after_child_skipped(self):
        data = hierarchy("BAD", [ROOT, ("A", 2, (0, 0, 0), (0, 0, 0, 1)), ("B", 0, (0, 0, 0), (0, 0, 0, 1))])
        rows, skips = zh_w3d.build_rows([("W3D.big", "bad.w3d", data)])
        self.assertEqual((rows, len(skips)), ([], 1))


def latin(data: bytes) -> str:
    return data.decode("latin-1")


def write_big(directory: str, name: str, files: dict[str, bytes]) -> Path:
    path = Path(directory) / name
    path.write_bytes(big({entry: latin(data) for entry, data in files.items()}))
    return path


class DumpTest(unittest.TestCase):
    def test_dump_and_cli(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            archive = write_big(tmp, "x.big", {"art\\w3d\\tank.w3d": TANK, "art\\w3d\\notes.txt": b"ignored"})
            out = Path(tmp) / "sub" / "w3d.jsonl"
            stream = io.StringIO()
            code = zh_w3d.main(["dump", str(archive), "--out", str(out)], stream)
            self.assertEqual(code, 0)
            self.assertRegex(stream.getvalue(), r"^ZH_W3D entries=1 rows=1 meshes=4 skipped=0 out=")
            rows = [json.loads(line) for line in out.read_text(encoding="utf-8").splitlines()]
            self.assertEqual(len(rows), 1)
            self.assertEqual(
                set(rows[0]),
                {"entry", "archive", "hlod", "hierarchy", "meshes", "pivots", "body", "excluded", "unresolved"},
            )

    def test_first_archive_wins(self) -> None:
        entry = "art\\w3d\\tank.w3d"
        with tempfile.TemporaryDirectory() as tmp:
            a = write_big(tmp, "a.big", {entry: TANK})
            b = write_big(tmp, "b.big", {entry: mesh("", "ROCK", (0, 0, 0), (1, 1, 1))})
            self.assertEqual([(x, y) for x, y, _ in zh_w3d.load_entries([a, b])], [("a.big", entry)])
            self.assertEqual([(x, y) for x, y, _ in zh_w3d.load_entries([b, a])], [("b.big", entry)])

    def test_missing_archive(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "w3d.jsonl"
            stderr = io.StringIO()
            with mock.patch.object(sys, "stderr", stderr):
                code = zh_w3d.main(["dump", str(Path(tmp) / "none.big"), "--out", str(out)], io.StringIO())
            self.assertEqual(code, 1)
            self.assertTrue(stderr.getvalue())
            self.assertFalse(out.exists())

    def test_failed_run_keeps_previous_dump(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "w3d.jsonl"
            out.write_text("old\n", encoding="utf-8")
            archive = Path(tmp) / "x.big"
            archive.write_bytes(b"not a big archive")
            with mock.patch.object(sys, "stderr", io.StringIO()):
                code = zh_w3d.main(["dump", str(archive), "--out", str(out)], io.StringIO())
            self.assertEqual(code, 1)
            self.assertEqual(out.read_text(encoding="utf-8"), "old\n")
            self.assertFalse(out.with_name("w3d.jsonl.tmp").exists())


@unittest.skipUnless(all(p.exists() for p in zh_w3d.DEFAULT_ARCHIVES), "retail archives not present")
class RealArchiveTest(unittest.TestCase):
    def assert_close(self, actual: list[float], expected: list[float]) -> None:
        self.assertEqual(len(actual), len(expected))
        for a, e in zip(actual, expected, strict=True):
            self.assertAlmostEqual(a, e, delta=0.01)

    def test_real_archives(self) -> None:
        entries = zh_w3d.load_entries(zh_w3d.DEFAULT_ARCHIVES)
        self.assertEqual(len(entries), 8896)
        rows, skips = zh_w3d.build_rows(entries)
        self.assertEqual(len(skips), 5)
        for skip in skips:
            self.assertTrue(skip.startswith("art\\w3d\\uisabotr_"), skip)
        by_entry = {r["entry"]: r for r in rows}

        leopard = by_entry["art\\w3d\\avleopard.w3d"]
        self.assertEqual(leopard["archive"], "W3D.big")
        turret = next(b for b in leopard["pivots"] if b["name"] == "TURRET")
        self.assert_close(turret["position"], [0.49, 0.03, 7.36])
        assert leopard["body"] is not None
        self.assert_close(leopard["body"]["size"], [44.36, 17.27, 10.85])
        self.assertIn("AVLEOPARD.TURRETFX01", leopard["excluded"])

        ranger = by_entry["art\\w3d\\airngr_skn.w3d"]
        self.assertEqual(ranger["hierarchy"], "AIRNGR_SKL")
        skin = next(m for m in ranger["meshes"] if m["name"] == "AIRNGR_SKN.AIRNGR-SKN")
        self.assertTrue(skin["skin"])
        assert ranger["body"] is not None
        self.assertAlmostEqual(ranger["body"]["max"][2], 14.55, delta=0.01)
        self.assert_close(ranger["body"]["size"], [3.7, 19.51, 14.61])

        barracks = by_entry["art\\w3d\\abbarracks.w3d"]
        assert barracks["body"] is not None
        self.assert_close(barracks["body"]["size"], [110.35, 88.12, 48.88])
        house = next(m for m in barracks["meshes"] if m["name"] == "ABBARRACKS.HOUSECOLOR04")
        self.assert_close(house["min"], [38.25, -29.13, 38.62])
        self.assert_close(house["max"], [42.8, -28.12, 46.31])


if __name__ == "__main__":
    unittest.main()
