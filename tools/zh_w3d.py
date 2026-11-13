"""Dump model-space mesh bounding boxes and bone positions from Zero Hour's shipped W3D models as JSONL.

Local research tool: reads the retail archives in place; the output stays under build/ and is never committed. Usage:
    python3 tools/zh_w3d.py dump [archive ...] [--out PATH]
"""

import argparse
import json
import os
import struct
import sys
from collections.abc import Iterator
from pathlib import Path
from typing import NamedTuple, TextIO, TypedDict

from check_reference import read_big

Vec3 = tuple[float, float, float]
Quat = tuple[float, float, float, float]
Entry = tuple[str, str, bytes]

MESH, MESH_HEADER3 = 0x000, 0x01F
HIERARCHY, HIERARCHY_HEADER, PIVOTS = 0x100, 0x101, 0x102
HLOD, HLOD_HEADER, HLOD_LOD_ARRAY, HLOD_SUB_OBJECT = 0x700, 0x701, 0x702, 0x704
BOX = 0x740
HIDDEN, GEOMETRY_MASK, SKIN = 0x1000, 0x00FF0000, 0x00020000

MESH_HEADER = struct.Struct("<II16s16s9I3f3f3ff")
HIERARCHY_HEADER_STRUCT = struct.Struct("<I16sI3f")
PIVOT = struct.Struct("<16sI3f3f4f")
HLOD_HEADER_STRUCT = struct.Struct("<II16s16s")
SUB_OBJECT = struct.Struct("<I32s")
BOX_NAME_OFFSET = 8
NO_PARENT = 0xFFFFFFFF
_RUN = Path(os.environ.get("HOME", "")) / "CnC/run"
DEFAULT_ARCHIVES = [
    _RUN / "Command & Conquer Generals - Zero Hour/W3DZH.big",
    _RUN / "Command & Conquer Generals - Zero Hour/W3DEnglishZH.big",
    _RUN / "Command and Conquer Generals/W3D.big",
]
DEFAULT_OUT = Path(__file__).resolve().parent.parent / "build/zh_w3d/w3d.jsonl"


class Box(TypedDict):
    min: list[float]
    max: list[float]
    size: list[float]


class Mesh(TypedDict):
    name: str
    bone: int | None
    skin: bool
    hidden: bool
    min: list[float]
    max: list[float]


class Bone(TypedDict):
    name: str
    parent: int
    position: list[float]


class Row(TypedDict):
    entry: str
    archive: str
    hlod: str | None
    hierarchy: str | None
    meshes: list[Mesh]
    pivots: list[Bone]
    body: Box | None
    excluded: list[str]
    unresolved: list[str]


class Transform(NamedTuple):
    position: Vec3
    rotation: Quat


IDENTITY = Transform((0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0))


class RawMesh(NamedTuple):
    name: str
    attributes: int
    lo: Vec3
    hi: Vec3


class RawHierarchy(NamedTuple):
    name: str
    bones: list[tuple[str, int]]
    world: list[Transform]


class RawHlod(NamedTuple):
    name: str
    hierarchy: str
    subs: list[tuple[int, str]]


class Parsed(NamedTuple):
    meshes: list[RawMesh]
    hierarchy: RawHierarchy | None
    hlod: RawHlod | None
    boxes: set[str]


def walk(data: bytes, start: int, end: int) -> Iterator[tuple[int, int, int]]:
    pos = start
    while pos < end:
        if pos + 8 > end:
            raise ValueError(f"chunk header at {pos} crosses {end}")
        kind, raw = struct.unpack_from("<II", data, pos)
        payload = pos + 8
        stop = payload + (raw & 0x7FFFFFFF)
        if stop > end:
            raise ValueError(f"chunk {kind:#x} at {pos} overruns {end}")
        yield kind, payload, stop
        pos = stop


def unpack(layout: struct.Struct, data: bytes, start: int, end: int) -> tuple:
    if start + layout.size > end:
        raise ValueError(f"record at {start} overruns {end}")
    return layout.unpack_from(data, start)


def text(raw: bytes) -> str:
    return raw.split(b"\0", 1)[0].decode("latin-1")


def rotate(q: Quat, v: Vec3) -> Vec3:
    x, y, z, w = q
    tx, ty, tz = 2 * (y * v[2] - z * v[1]), 2 * (z * v[0] - x * v[2]), 2 * (x * v[1] - y * v[0])
    return (v[0] + w * tx + y * tz - z * ty, v[1] + w * ty + z * tx - x * tz, v[2] + w * tz + x * ty - y * tx)


def multiply(a: Quat, b: Quat) -> Quat:
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    )


def compose(parent: Transform, translation: Vec3, rotation: Quat) -> Transform:
    offset = rotate(parent.rotation, translation)
    position = (parent.position[0] + offset[0], parent.position[1] + offset[1], parent.position[2] + offset[2])
    return Transform(position, multiply(parent.rotation, rotation))


def parse_mesh(data: bytes, start: int, end: int) -> RawMesh:
    for kind, payload, stop in walk(data, start, end):
        if kind == MESH_HEADER3:
            f = unpack(MESH_HEADER, data, payload, stop)
            container, name = text(f[3]), text(f[2])
            return RawMesh(
                f"{container}.{name}" if container else name, f[1], (f[13], f[14], f[15]), (f[16], f[17], f[18])
            )
    raise ValueError("mesh without header")


def parse_pivots(data: bytes, start: int, end: int, count: int) -> RawHierarchy:
    bones: list[tuple[str, int]] = []
    world: list[Transform] = []
    for i in range(count):
        f = unpack(PIVOT, data, start + i * PIVOT.size, end)
        parent = -1 if f[1] == NO_PARENT else f[1]
        if parent >= i:
            raise ValueError(f"pivot {i} has parent {parent}")
        local = (f[2], f[3], f[4]), (f[8], f[9], f[10], f[11])
        world.append(compose(world[parent] if parent >= 0 else IDENTITY, *local))
        bones.append((text(f[0]), parent))
    return RawHierarchy("", bones, world)


def parse_hierarchy(data: bytes, start: int, end: int) -> RawHierarchy:
    name, count, pivots = "", 0, None
    for kind, payload, stop in walk(data, start, end):
        if kind == HIERARCHY_HEADER:
            _, raw_name, count, *_ = HIERARCHY_HEADER_STRUCT.unpack_from(data, payload)
            name = text(raw_name)
        elif kind == PIVOTS:
            pivots = payload, stop
    if pivots is None:
        raise ValueError("hierarchy without pivots")
    return parse_pivots(data, pivots[0], pivots[1], count)._replace(name=name)


def parse_hlod(data: bytes, start: int, end: int) -> RawHlod:
    name, hierarchy, subs, seen_array = "", "", [], False
    for kind, payload, stop in walk(data, start, end):
        if kind == HLOD_HEADER:
            name, hierarchy = (text(b) for b in HLOD_HEADER_STRUCT.unpack_from(data, payload)[2:])
        elif kind == HLOD_LOD_ARRAY and not seen_array:
            # shortcut: only LOD 0 of the HLOD is read; every retail HLOD has one LOD (2026-11-12 probe).
            seen_array = True
            for sub_kind, sub_payload, sub_stop in walk(data, payload, stop):
                if sub_kind == HLOD_SUB_OBJECT:
                    bone, raw = unpack(SUB_OBJECT, data, sub_payload, sub_stop)
                    subs.append((bone, text(raw)))
    return RawHlod(name, hierarchy, subs)


def parse_entry(data: bytes) -> Parsed:
    parsed = Parsed([], None, None, set())
    for kind, payload, stop in walk(data, 0, len(data)):
        if kind == MESH:
            parsed.meshes.append(parse_mesh(data, payload, stop))
        elif kind == HIERARCHY and parsed.hierarchy is None:
            parsed = parsed._replace(hierarchy=parse_hierarchy(data, payload, stop))
        elif kind == HLOD and parsed.hlod is None:
            parsed = parsed._replace(hlod=parse_hlod(data, payload, stop))
        elif kind == BOX:
            parsed.boxes.add(text(data[payload + BOX_NAME_OFFSET : payload + BOX_NAME_OFFSET + 32]).upper())
    return parsed


def num(v: float) -> float:
    return round(v, 3) + 0.0


def transform_box(lo: Vec3, hi: Vec3, t: Transform) -> tuple[list[float], list[float]]:
    corners = [rotate(t.rotation, (x, y, z)) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
    moved = [[c[i] + t.position[i] for i in range(3)] for c in corners]
    return [num(min(m[i] for m in moved)) for i in range(3)], [num(max(m[i] for m in moved)) for i in range(3)]


def make_mesh(raw: RawMesh, bone: int | None, transform: Transform) -> Mesh:
    skin = raw.attributes & GEOMETRY_MASK == SKIN
    lo, hi = transform_box(raw.lo, raw.hi, IDENTITY if skin else transform)
    return Mesh(name=raw.name, bone=bone, skin=skin, hidden=bool(raw.attributes & HIDDEN), min=lo, max=hi)


def resolve_meshes(parsed: Parsed, hierarchies: dict[str, RawHierarchy]) -> tuple[list[Mesh], list[str]]:
    if parsed.hlod is None:
        return [make_mesh(m, None, IDENTITY) for m in parsed.meshes], []
    by_name = {m.name.upper(): m for m in parsed.meshes}
    tree = hierarchies.get(parsed.hlod.hierarchy.upper())
    meshes: list[Mesh] = []
    unresolved: list[str] = []
    for bone, name in parsed.hlod.subs:
        raw = by_name.get(name.upper())
        if raw is None:
            if name.upper() not in parsed.boxes:
                unresolved.append(name)
        elif raw.attributes & GEOMETRY_MASK == SKIN:
            meshes.append(make_mesh(raw, bone, IDENTITY))
        elif tree is None or bone >= len(tree.world):
            unresolved.append(name)
        else:
            meshes.append(make_mesh(raw, bone, tree.world[bone]))
    return meshes, unresolved


def is_effect(mesh: Mesh) -> bool:
    return mesh["hidden"] or "FX" in mesh["name"].split(".", 1)[-1].upper()


def union(meshes: list[Mesh]) -> Box | None:
    if not meshes:
        return None
    lo = [num(min(m["min"][i] for m in meshes)) for i in range(3)]
    hi = [num(max(m["max"][i] for m in meshes)) for i in range(3)]
    return Box(min=lo, max=hi, size=[num(hi[i] - lo[i]) for i in range(3)])


def make_row(archive: str, entry: str, parsed: Parsed, hierarchies: dict[str, RawHierarchy]) -> Row:
    meshes, unresolved = resolve_meshes(parsed, hierarchies)
    own = parsed.hierarchy
    pivots = (
        [
            Bone(name=name, parent=parent, position=[num(c) for c in t.position])
            for (name, parent), t in zip(own.bones, own.world, strict=True)
        ]
        if own
        else []
    )
    return Row(
        entry=entry,
        archive=archive,
        hlod=parsed.hlod.name if parsed.hlod else None,
        hierarchy=(parsed.hlod.hierarchy if parsed.hlod else "") or (own.name if own else None),
        meshes=meshes,
        pivots=pivots,
        body=union([m for m in meshes if not is_effect(m)]),
        excluded=[m["name"] for m in meshes if is_effect(m)],
        unresolved=unresolved,
    )


def build_rows(entries: list[Entry]) -> tuple[list[Row], list[str]]:
    parsed: list[tuple[str, str, Parsed]] = []
    skips: list[str] = []
    for archive, entry, data in entries:
        try:
            parsed.append((archive, entry, parse_entry(data)))
        except (ValueError, struct.error) as error:
            skips.append(f"{entry}: {error}")
    hierarchies: dict[str, RawHierarchy] = {}
    for _, _, p in parsed:
        if p.hierarchy:
            hierarchies.setdefault(p.hierarchy.name.upper(), p.hierarchy)
    rows = [make_row(a, e, p, hierarchies) for a, e, p in parsed if p.meshes or p.hierarchy]
    return rows, skips


def load_entries(archives: list[Path]) -> list[Entry]:
    chosen: dict[str, tuple[str, str]] = {}
    for path in archives:
        for name, content in read_big(path.read_bytes()).items():
            if name.endswith(".w3d"):
                chosen.setdefault(name, (path.name, content))
    # read_big decodes latin-1, which round-trips every byte.
    return [(archive, name, content.encode("latin-1")) for name, (archive, content) in sorted(chosen.items())]


def dump(archives: list[Path], out: Path) -> tuple[int, int, int, int]:
    entries = load_entries(archives)
    rows, skips = build_rows(entries)
    for skip in skips:
        print(f"zh_w3d: skipped {skip}", file=sys.stderr)
    out.parent.mkdir(parents=True, exist_ok=True)
    partial = out.with_name(out.name + ".tmp")
    with partial.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")
    partial.replace(out)
    return len(entries), len(rows), sum(len(r["meshes"]) for r in rows), len(skips)


def main(argv: list[str], out: TextIO = sys.stdout) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["dump"])
    parser.add_argument("archives", nargs="*", type=Path, default=DEFAULT_ARCHIVES)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args(argv)
    try:
        entries, rows, meshes, skipped = dump(args.archives, args.out)
    except (OSError, ValueError) as error:
        args.out.with_name(args.out.name + ".tmp").unlink(missing_ok=True)
        print(f"zh_w3d: {error}", file=sys.stderr)
        return 1
    print(f"ZH_W3D entries={entries} rows={rows} meshes={meshes} skipped={skipped} out={args.out}", file=out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
