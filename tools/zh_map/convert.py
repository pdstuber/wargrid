"""Convert an EA Zero Hour .map (GPL, CnC_Modding_Support) into a Wargrid map JSON.

Format evidence: docs/reference/m6-map-and-feel.md. Usage: convert.py <map> <out.json> <name>
"""

import collections
import heapq
import json
import math
import os
import struct
import sys
from typing import Any

sys.path.insert(0, os.path.dirname(__file__))
import refpack

CELL = 25.0
SAMPLE = 10.0
HEIGHT_SCALE = 0.625
# Mirrors SOURCE_FOOTPRINT in game/scripts/simulation/definitions/definitions.gd; keep in step.
SOURCE_W, SOURCE_H = 4, 5
CLIFF_STEP = 9.8
NOTICE = (
    "Converted from an Electronic Arts map source (Copyright 2025 Electronic Arts Inc., "
    "GPL-3.0 with EA's additional terms). Modified; not the original. "
    "Terms, source path and revision: game/data/maps/NOTICE.md."
)
# StartingBoxes and DeleteWhenEmpty in object/civilianbuilding.ini (INIZH.big); no map override.
# The 1 x 1 pile footprint is Wargrid's choice so Dry Wells' piles do not overlap.
SOURCES = {"SupplyDock": (400, (SOURCE_W, SOURCE_H), False), "SupplyPileSmall": (50, (1, 1), True)}
FOOTPRINTS = (
    ("power_plant", 2),
    ("supply_center", 3),
    ("barracks", 2),
    ("factory", 3),
    ("command_center", 3),
    ("defence", 1),
)
# Mirror BUILD_EDGE_MARGIN in definitions.gd and the supply_center supply_clearance in usa.gd; keep in step.
EDGE_MARGIN = 1
MAX_RING = 12
SUPPLY_REACH = 20


class ConvertError(Exception):
    pass


class _Reader:
    def __init__(self, data, pos=0):
        self.b, self.p = data, pos

    def take(self, fmt):
        v = struct.unpack_from("<" + fmt, self.b, self.p)[0]
        self.p += struct.calcsize(fmt)
        return v

    def raw(self, n):
        v = self.b[self.p : self.p + n]
        self.p += n
        return v

    def ascii(self):
        return self.raw(self.take("H")).decode("latin-1")

    def unicode(self):
        return self.raw(2 * self.take("H")).decode("utf-16-le")


def load(path):
    with open(path, "rb") as f:
        raw = f.read()
    if raw[:4] != b"EAR\0":
        raise ConvertError("not an EAR map")
    data = refpack.decode(raw[8:])
    if len(data) != struct.unpack_from("<I", raw, 4)[0]:
        raise ConvertError("size mismatch")
    return read_map(data)


def derive_cliffs(w, h, heights):
    cliff = [False] * (w * h)
    for j in range(h - 1):
        for i in range(w - 1):
            corners = [
                heights[j * w + i],
                heights[j * w + i + 1],
                heights[(j + 1) * w + i],
                heights[(j + 1) * w + i + 1],
            ]
            cliff[j * w + i] = (max(corners) - min(corners)) * HEIGHT_SCALE > CLIFF_STEP
    return cliff


def _read_dict(r, names):
    out = {}
    readers = [lambda: bool(r.take("B")), lambda: r.take("i"), lambda: r.take("f"), r.ascii, r.unicode]
    for _ in range(r.take("H")):
        key_type = r.take("i")
        out[names[key_type >> 8]] = readers[key_type & 0xFF]()
    return out


def _chunks(r, end, names):
    while r.p < end:
        cid, version, size = r.take("I"), r.take("H"), r.take("i")
        yield names[cid], version, r.p, r.p + size
        r.p += size


def _read_cliff_bits(c, version, w, h):
    n = c.take("i")
    if n != w * h:
        raise ConvertError("BlendTileData size")
    c.raw(2 * n * 2)
    if version >= 6:
        c.raw(2 * n)
    if version >= 5:
        c.raw(2 * n)
    row = (w + 1) // 8 if version == 7 else (w + 7) // 8
    bits = c.raw(h * row)
    return [bool((bits[j * row + (i >> 3)] >> (i & 7)) & 1) for j in range(h) for i in range(w)]


def read_map(data):
    r = _Reader(data)
    if r.raw(4) != b"CkMp":
        raise ConvertError("not a chunk file")
    names = {}
    for _ in range(r.take("i")):
        name = r.raw(r.take("B")).decode()
        names[r.take("I")] = name
    raw: dict[str, Any] = dict(water_polygons=[], objects=[], cliff=None)
    for name, version, start, end in _chunks(r, len(data), names):
        c = _Reader(data, start)
        if name == "HeightMapData":
            w, h = c.take("i"), c.take("i")
            border = c.take("i") if version >= 3 else 0
            bounds = (
                [(c.take("i"), c.take("i")) for _ in range(c.take("i"))]
                if version >= 4
                else [(w - 2 * border, h - 2 * border)]
            )
            if c.take("i") != w * h:
                raise ConvertError("HeightMapData size")
            raw.update(width=w, height=h, border=border, boundary=bounds[0], heights=list(c.raw(w * h)))
        elif name == "BlendTileData" and version >= 7:
            raw["cliff"] = _read_cliff_bits(c, version, raw["width"], raw["height"])
        elif name == "ObjectsList":
            for _, over, os_, _oe in _chunks(c, end, names):
                o = _Reader(data, os_)
                x, y, z, angle = o.take("f"), o.take("f"), o.take("f"), o.take("f")
                flags, template = o.take("i"), o.ascii()
                raw["objects"].append(
                    dict(
                        template=template,
                        x=x,
                        y=y,
                        z=z,
                        angle=angle,
                        flags=flags,
                        props=_read_dict(o, names) if over >= 2 else {},
                    )
                )
        elif name == "PolygonTriggers":
            raw["water_polygons"] += _read_water(c, version)
    if raw["cliff"] is None:
        raw["cliff"] = derive_cliffs(raw["width"], raw["height"], raw["heights"])
    return raw


def _read_water(c, version):
    out = []
    for _ in range(c.take("i")):
        c.ascii()
        if version >= 4:
            c.ascii()
        c.take("i")
        water = bool(c.take("B")) if version >= 2 else False
        river = bool(c.take("B")) if version >= 3 else False
        if version >= 3:
            c.take("i")
        pts = [(c.take("i"), c.take("i"), c.take("i")) for _ in range(c.take("i"))]
        if (water or river) and pts:
            out.append((pts[0][2], [(x, y) for x, y, _ in pts]))  # every point of a polygon shares one height
    return out


def _inside(poly, x, y):
    hit = False
    for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1], strict=True):
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
            hit = not hit
    return hit


def _ground(raw, x, y):
    i = min(int(x // SAMPLE) + raw["border"], raw["width"] - 1)
    j = min(int(y // SAMPLE) + raw["border"], raw["height"] - 1)
    return raw["heights"][j * raw["width"] + i] * HEIGHT_SCALE


def _wet(raw, x, y):
    return any(_inside(p, x, y) and _ground(raw, x, y) < level for level, p in raw["water_polygons"])


def _overlap(a0, a1, b0, b1):
    return max(0.0, min(a1, b1) - max(a0, b0))


def _cliff(raw, i, j):
    return raw["cliff"][(j + raw["border"]) * raw["width"] + i + raw["border"]]


def resample(raw):
    bx, by = raw["boundary"]
    scale = CELL / SAMPLE
    w, h = int(bx * SAMPLE // CELL), int(by * SAMPLE // CELL)
    cells, heights = [], []
    for cy in range(h):
        y0 = cy * scale
        row, hrow = "", []
        for cx in range(w):
            x0 = cx * scale
            area = sum(
                _overlap(y0, y0 + scale, j, j + 1) * _overlap(x0, x0 + scale, i, i + 1)
                for j in range(int(y0), math.ceil(y0 + scale))
                for i in range(int(x0), math.ceil(x0 + scale))
                if _cliff(raw, i, j)
            )
            if _wet(raw, (cx + 0.5) * CELL, (cy + 0.5) * CELL):
                row += "~"
            else:
                row += "#" if area >= 0.5 * scale * scale else "."
            pts = [
                raw["heights"][(j + raw["border"]) * raw["width"] + i + raw["border"]] * HEIGHT_SCALE
                for j in range(math.ceil(y0), int(y0 + scale) + 1)
                for i in range(math.ceil(x0), int(x0 + scale) + 1)
                if j + raw["border"] < raw["height"] and i + raw["border"] < raw["width"]
            ]
            hrow.append(round(10 * sum(pts) / len(pts)))
        cells.append(row)
        heights.append(hrow)
    return dict(size=[w, h], cells=cells, heights=heights)


def _open(grid, x, y):
    w, h = grid["size"]
    return 0 <= x < w and 0 <= y < h and grid["cells"][y][x] == "."


def _box(x, y, size):
    return {(i, j) for i in range(x, x + size) for j in range(y, y + size)}


def _rect(x, y, w, h):
    return {(i, j) for i in range(x, x + w) for j in range(y, y + h)}


def _seat_of(obj):
    name = str(obj["props"].get("waypointName", ""))
    if name.startswith("Player_") and name.endswith("_Start"):
        return int(name[len("Player_") : -len("_Start")])
    return 0


def _find_slot(grid, size, taken):
    w, h = grid["size"]
    bx, by = taken["builder"]
    for d in range(2, MAX_RING + 1):
        for y in range(by - d, by + d + 1):
            for x in range(bx - d, bx + d + 1):
                if max(abs(x - bx), abs(y - by)) != d:
                    continue
                inside = _box(x, y, size)
                grown = _box(x - 1, y - 1, size + 2)  # the 1-cell ring is the pile clearance and keeps buildings apart
                if (
                    all(EDGE_MARGIN <= i < w - EDGE_MARGIN and EDGE_MARGIN <= j < h - EDGE_MARGIN for i, j in inside)
                    and all(_open(grid, i, j) for i, j in inside)
                    and all(_open(grid, i, j) for i, j in grown if 0 <= i < w and 0 <= j < h)
                    and not grown & taken["cells"]
                ):
                    return [x, y], inside
    return None, None


def place(grid, raw):
    sources: list[dict[str, Any]] = []
    source_cells: set[tuple[int, int]] = set()
    for o in raw["objects"]:
        if o["template"] in SOURCES:
            boxes, (sw, sh), delete = SOURCES[o["template"]]
            c = (int(o["x"] // CELL), int(o["y"] // CELL))
            w, h = grid["size"]
            origin = [min(max(c[0] - sw // 2, 0), w - sw), min(max(c[1] - sh // 2, 0), h - sh)]
            cells = _rect(origin[0], origin[1], sw, sh)
            if cells & source_cells:
                raise ConvertError("sources overlap")
            source_cells |= cells
            source = dict(origin=origin, boxes=boxes)
            if (sw, sh) != (SOURCE_W, SOURCE_H):
                source["footprint"] = [sw, sh]
            if delete:
                source["delete_when_empty"] = True
            sources.append(source)
    seats = sorted((_seat_of(o), o) for o in raw["objects"] if _seat_of(o))
    starts = []
    for seat, o in seats:
        cell = (int(o["x"] // CELL), int(o["y"] // CELL))
        if not _open(grid, *cell):
            raise ConvertError(f"start not open: seat {seat}")
        taken = dict(builder=cell, cells={cell} | source_cells)
        slots = {}
        for kind, size in FOOTPRINTS:
            origin, footprint = _find_slot(grid, size, taken)
            if origin is None:
                raise ConvertError(f"no slots: seat {seat}")
            slots[kind] = origin
            taken["cells"] |= footprint
        if not any(
            max(abs(s["origin"][0] + 1 - cell[0]), abs(s["origin"][1] + 1 - cell[1])) <= SUPPLY_REACH for s in sources
        ):
            raise ConvertError(f"no supply: seat {seat}")
        starts.append(dict(seat=seat, cell=list(cell), slots=slots))
    return dict(starts=starts, sources=sources)


def route_matrix(passable, step_units, starts):
    h, w = len(passable), len(passable[0])
    out = {}
    for a, sa in enumerate(starts):
        dist = {tuple(sa["cell"]): 0.0}
        heap = [(0.0, tuple(sa["cell"]))]
        while heap:
            d, (x, y) = heapq.heappop(heap)
            if d > dist[(x, y)]:
                continue
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if (
                        (dx or dy)
                        and 0 <= nx < w
                        and 0 <= ny < h
                        and passable[ny][nx]
                        and (not (dx and dy) or (passable[y][nx] and passable[ny][x]))
                    ):
                        nd = d + (math.sqrt(2) if dx and dy else 1.0)
                        if nd < dist.get((nx, ny), math.inf):
                            dist[(nx, ny)] = nd
                            heapq.heappush(heap, (nd, (nx, ny)))
        for sb in starts[a + 1 :]:
            out[(sa["seat"], sb["seat"])] = dist.get(tuple(sb["cell"]), math.inf) * step_units
    return out


def passable_cells(grid):
    return [[c == "." for c in row] for row in grid["cells"]]


def passable_samples(raw):
    bx, by = raw["boundary"]
    return [
        [not _cliff(raw, i, j) and not _wet(raw, (i + 0.5) * SAMPLE, (j + 0.5) * SAMPLE) for i in range(bx)]
        for j in range(by)
    ]


def start_metrics(grid, placed, matrix):
    rows = []
    for s in placed["starts"]:
        bx, by = s["cell"]
        buildable = sum(_open(grid, x, y) for x in range(bx - 12, bx + 13) for y in range(by - 12, by + 13))
        supply = min(max(abs(o["origin"][0] - bx), abs(o["origin"][1] - by)) for o in placed["sources"])
        routes = {(b if a == s["seat"] else a): v for (a, b), v in matrix.items() if s["seat"] in (a, b)}
        rows.append(dict(seat=s["seat"], buildable=buildable, supply=supply, routes=routes))
    return rows


def route_widths(passable, starts):
    """Narrowest 4-neighbour corridor (Chebyshev clearance) between a start and its two nearest starts."""
    h, w = len(passable), len(passable[0])
    clear = [
        [0 if not passable[y][x] else (1 if x in (0, w - 1) or y in (0, h - 1) else 10**9) for x in range(w)]
        for y in range(h)
    ]
    queue = collections.deque((x, y) for y in range(h) for x in range(w) if clear[y][x] < 10**9)
    while queue:
        x, y = queue.popleft()
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and clear[ny][nx] > clear[y][x] + 1:
                    clear[ny][nx] = clear[y][x] + 1
                    queue.append((nx, ny))

    def reach(a, b, t):
        if clear[a[1]][a[0]] < t:
            return False
        seen, q = {a}, collections.deque([a])
        while q:
            x, y = q.popleft()
            if (x, y) == b:
                return True
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= n[0] < w and 0 <= n[1] < h and n not in seen and clear[n[1]][n[0]] >= t:
                    seen.add(n)
                    q.append(n)
        return False

    pairs = set()
    for s in starts:
        near = sorted((o for o in starts if o is not s), key=lambda o: math.dist(o["cell"], s["cell"]))[:2]
        pairs |= {tuple(sorted((s["seat"], o["seat"]))) for o in near}
    cell = {s["seat"]: tuple(s["cell"]) for s in starts}
    out = {}
    for a, b in sorted(pairs):
        t = 0
        while reach(cell[a], cell[b], t + 1):
            t += 1
        out[(a, b)] = t
    return out


def convert(raw, name, notice):
    grid = resample(raw)
    placed = place(grid, raw)
    matrix = route_matrix(passable_cells(grid), CELL, placed["starts"])
    for pair, length in matrix.items():
        if math.isinf(length):
            raise ConvertError(f"route lost: {pair[0]}-{pair[1]}")
    return dict(
        name=name,
        notice=notice,
        size=grid["size"],
        cells=grid["cells"],
        heights=grid["heights"],
        starts=placed["starts"],
        sources=placed["sources"],
    )


def write_json(out, path):
    parts = [
        f'  "name": {json.dumps(out["name"])}',
        f'  "notice": {json.dumps(out["notice"])}',
        f'  "size": {json.dumps(out["size"])}',
        '  "cells": [\n' + ",\n".join(f'    "{r}"' for r in out["cells"]) + "\n  ]",
        '  "heights": [\n'
        + ",\n".join("    " + json.dumps(r, separators=(",", ":")) for r in out["heights"])
        + "\n  ]",
        '  "starts": [\n' + ",\n".join("    " + json.dumps(s) for s in out["starts"]) + "\n  ]",
        '  "sources": [\n' + ",\n".join("    " + json.dumps(s) for s in out["sources"]) + "\n  ]",
    ]
    with open(path, "w") as f:
        f.write("{\n" + ",\n".join(parts) + "\n}\n")


def report(raw, out):
    grid = dict(size=out["size"], cells=out["cells"])
    placed = dict(starts=out["starts"], sources=out["sources"])
    fine = route_matrix(
        passable_samples(raw),
        SAMPLE,
        [
            dict(seat=s["seat"], cell=[int(o["x"] // SAMPLE), int(o["y"] // SAMPLE)])
            for s in out["starts"]
            for o in raw["objects"]
            if _seat_of(o) == s["seat"]
        ],
    )
    coarse = route_matrix(passable_cells(grid), CELL, out["starts"])
    print("route lengths (world units): pair, source grid, resampled grid, ratio")
    for pair in coarse:
        print(f"  {pair[0]}-{pair[1]}  {fine[pair]:8.1f}  {coarse[pair]:8.1f}  {coarse[pair] / fine[pair]:.3f}")
    print("route widths (Chebyshev clearance t, width >= 2t-1 cells): pair, t")
    for pair, t in route_widths(passable_cells(grid), out["starts"]).items():
        print(f"  {pair[0]}-{pair[1]}  {t}")
    print("start metrics: seat, buildable cells within 12, supply Chebyshev, routes")
    for row in start_metrics(grid, placed, coarse):
        print(f"  {row['seat']}  {row['buildable']}  {row['supply']}  {row['routes']}")


def main(argv):
    raw = load(argv[1])
    try:
        out = convert(raw, argv[3], NOTICE)
    except ConvertError as e:
        print(f"convert failed: {e}", file=sys.stderr)
        return 1
    write_json(out, argv[2])
    report(raw, out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
