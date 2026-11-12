import math
import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import zh_w3d

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


if __name__ == "__main__":
    unittest.main()
