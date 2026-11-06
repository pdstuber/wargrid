import math
import os
import struct
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import convert
import refpack

TYPE_INT, TYPE_ASCII = 1, 3


def astr(text):
    return struct.pack("<H", len(text)) + text.encode("latin-1")


def chunk(ids, name, version, payload):
    return struct.pack("<IHi", ids[name], version, len(payload)) + payload


def synthetic_file(objects):
    names = ["HeightMapData", "ObjectsList", "Object", "waypointID", "waypointName"]
    ids = {n: i + 1 for i, n in enumerate(names)}
    toc = b"CkMp" + struct.pack("<i", len(names))
    for n in names:
        toc += bytes([len(n)]) + n.encode() + struct.pack("<I", ids[n])
    heights = struct.pack("<iiiiiii", 4, 4, 1, 1, 2, 2, 16) + bytes(range(16))
    body = b""
    for template, x, y, props in objects:
        d = struct.pack("<H", len(props))
        for key, value in props:
            if isinstance(value, int):
                d += struct.pack("<i", (ids[key] << 8) | TYPE_INT) + struct.pack("<i", value)
            else:
                d += struct.pack("<i", (ids[key] << 8) | TYPE_ASCII) + astr(value)
        body += chunk(ids, "Object", 3, struct.pack("<ffffi", x, y, 0.0, 0.5, 7) + astr(template) + d)
    return toc + chunk(ids, "HeightMapData", 4, heights) + chunk(ids, "ObjectsList", 3, body)


def raw_map(w_cells, h_cells, cliff_cells=(), cliff_samples=(), starts=(), sources=()):
    w, h = int(w_cells * 2.5), int(h_cells * 2.5)
    cliff = [False] * (w * h)
    for cx, cy in cliff_cells:
        for j in range(int(cy * 2.5), int((cy + 1) * 2.5)):
            for i in range(int(cx * 2.5), int((cx + 1) * 2.5)):
                cliff[j * w + i] = True
    for i, j in cliff_samples:
        cliff[j * w + i] = True
    objects = []
    for seat, (cx, cy) in enumerate(starts, 1):
        props = {"waypointName": f"Player_{seat}_Start"}
        objects.append(
            dict(
                template="*Waypoints/Waypoint",
                x=cx * 25 + 12.5,
                y=cy * 25 + 12.5,
                z=0.0,
                angle=0.0,
                flags=0,
                props=props,
            )
        )
    for cx, cy in sources:
        objects.append(
            dict(template="SupplyDock", x=cx * 25 + 12.5, y=cy * 25 + 12.5, z=0.0, angle=0.0, flags=0, props={})
        )
    return dict(
        width=w,
        height=h,
        border=0,
        boundary=(w, h),
        heights=[0] * (w * h),
        cliff=cliff,
        water_polygons=[],
        objects=objects,
    )


def wall(x0, x1, h_cells):
    return [(x, y) for x in range(x0, x1) for y in range(h_cells)]


class RefpackTest(unittest.TestCase):
    def test_refpack_literals_and_copies(self):
        stream = bytes([0x10, 0xFB, 0, 0, 17])
        stream += bytes([0xE0]) + b"abcd"
        stream += bytes([0x01, 3]) + b"X"
        stream += bytes([0x80, 0, 0])
        stream += bytes([0xC0, 0, 7, 0])
        stream += bytes([0xFC])
        self.assertEqual(refpack.decode(stream), b"abcdXbcdddddXbcdd")


class ReadMapTest(unittest.TestCase):
    def test_chunks_roundtrip(self):
        data = synthetic_file(
            [
                ("*Waypoints/Waypoint", 100.0, 200.0, [("waypointID", 5), ("waypointName", "Player_1_Start")]),
                ("*Waypoints/Waypoint", 300.0, 400.0, [("waypointID", 6), ("waypointName", "Player_2_Start")]),
                ("SupplyDock", 50.0, 60.0, []),
            ]
        )
        raw = convert.read_map(data)
        self.assertEqual((raw["width"], raw["height"], raw["border"], raw["boundary"]), (4, 4, 1, (2, 2)))
        self.assertEqual(raw["heights"], list(range(16)))
        self.assertEqual(len(raw["cliff"]), 16)
        self.assertEqual(raw["water_polygons"], [])
        self.assertEqual(
            [o["template"] for o in raw["objects"]], ["*Waypoints/Waypoint", "*Waypoints/Waypoint", "SupplyDock"]
        )
        first = raw["objects"][0]
        self.assertEqual((first["x"], first["y"], first["flags"]), (100.0, 200.0, 7))
        self.assertEqual(first["props"], {"waypointID": 5, "waypointName": "Player_1_Start"})

    def test_cliff_fallback_from_heights(self):
        self.assertTrue(convert.derive_cliffs(2, 2, [0, 0, 0, 16])[0])
        self.assertFalse(convert.derive_cliffs(2, 2, [0, 0, 0, 15])[0])
        self.assertFalse(any(convert.read_map(synthetic_file([]))["cliff"]))


class ResampleTest(unittest.TestCase):
    def test_resample_half_rule(self):
        # cell (0,0) covers samples [0, 2.5): half of the 6.25 sample areas is 3.125.
        over = raw_map(4, 4, cliff_samples=[(0, 0), (1, 0), (0, 1), (2, 2)])  # 3 + 0.25
        self.assertEqual(convert.resample(over)["cells"][0][0], "#")
        under = raw_map(4, 4, cliff_samples=[(0, 0), (1, 0), (0, 1)])  # 3.0
        grid = convert.resample(under)
        self.assertEqual(grid["cells"][0][0], ".")
        self.assertEqual(grid["size"], [4, 4])
        self.assertEqual(len(grid["heights"]), 4)

    def test_water_polygon_blocks(self):
        raw = raw_map(4, 4)
        raw["water_polygons"] = [[(0, 0), (50, 0), (50, 50), (0, 50)]]
        cells = convert.resample(raw)["cells"]
        self.assertEqual(cells[0][:2], "~~")
        self.assertEqual(cells[2][:2], "..")


class PlaceTest(unittest.TestCase):
    def test_lost_route_fails(self):
        raw = raw_map(80, 30, cliff_cells=wall(38, 42, 30), starts=[(10, 15), (70, 15)], sources=[(16, 15), (64, 15)])
        for i in range(95, 105):
            raw["cliff"][37 * raw["width"] + i] = False
        with self.assertRaisesRegex(convert.ConvertError, "route lost: 1-2"):
            convert.convert(raw, "T", "n")

    def test_every_start_has_slots_and_supply(self):
        starts = [(10, 15), (70, 15), (40, 15)]
        sources = [(16, 15), (64, 15)]
        ring = [(x, y) for x in range(26, 55) for y in range(1, 30) if max(abs(x - 40), abs(y - 15)) >= 3]
        with self.assertRaisesRegex(convert.ConvertError, "no slots: seat 3"):
            convert.convert(raw_map(80, 30, cliff_cells=ring, starts=starts, sources=sources), "T", "n")
        with self.assertRaisesRegex(convert.ConvertError, "no supply: seat 3"):
            convert.convert(raw_map(80, 30, starts=starts, sources=sources), "T", "n")

    def test_slots_ordered_and_apart(self):
        raw = raw_map(80, 30, starts=[(10, 15), (70, 15)], sources=[(16, 15), (64, 15)])
        out = convert.convert(raw, "T", "n")
        first = out["starts"][0]
        self.assertEqual((first["seat"], first["cell"]), (1, [10, 15]))
        self.assertEqual(first["slots"]["power_plant"], [12, 13])  # ring 2, y then x ascending, ring clear of the builder
        footprints = []
        for kind, size in (("power_plant", 2), ("supply_center", 3), ("barracks", 2), ("factory", 3), ("command_center", 3), ("defence", 1)):
            x, y = first["slots"][kind]
            footprints.append({(i, j) for i in range(x, x + size) for j in range(y, y + size)})
        for n, a in enumerate(footprints):
            for b in footprints[n + 1 :]:
                self.assertFalse(a & b)
        self.assertEqual(out["sources"][0], {"origin": [15, 14], "boxes": 400})

    def test_edge_source_stays_inside_map(self):
        raw = raw_map(80, 30, starts=[(10, 15), (70, 15)], sources=[(16, 15), (79, 29)])
        out = convert.convert(raw, "T", "n")
        self.assertEqual(out["sources"][1]["origin"], [77, 27])


class RouteTest(unittest.TestCase):
    def test_route_matrix_straight_and_diagonal(self):
        open_grid = [[True] * 20 for _ in range(20)]
        starts = [dict(seat=1, cell=[0, 0]), dict(seat=2, cell=[10, 0]), dict(seat=3, cell=[10, 10])]
        m = convert.route_matrix(open_grid, 10.0, starts)
        self.assertAlmostEqual(m[(1, 2)], 100.0, places=9)
        self.assertAlmostEqual(m[(1, 3)], 100.0 * math.sqrt(2), places=9)
        walled = [[not (x == 5 and y != 19) for x in range(20)] for y in range(20)]
        m = convert.route_matrix(walled, 10.0, starts[:2])
        self.assertAlmostEqual(m[(1, 2)], 10 * (8 * math.sqrt(2) + 32), places=9)

    def test_start_metrics_rows(self):
        grid = dict(size=[30, 10], cells=["." * 30] * 10)
        placed = dict(
            starts=[dict(seat=1, cell=[2, 5]), dict(seat=2, cell=[27, 5])], sources=[dict(origin=[5, 4], boxes=400)]
        )
        rows = convert.start_metrics(grid, placed, {(1, 2): 625.0})
        self.assertEqual(
            rows,
            [
                dict(seat=1, buildable=150, supply=3, routes={2: 625.0}),
                dict(seat=2, buildable=150, supply=22, routes={1: 625.0}),
            ],
        )


if __name__ == "__main__":
    unittest.main()
