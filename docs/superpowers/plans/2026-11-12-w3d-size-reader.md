# W3D Size Reader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `python3 tools/zh_w3d.py dump` reads the retail W3D archives in place and writes one JSONL row per `.w3d` entry with model-space mesh bounding boxes, a composed body box and bone positions, so unit and building proportions can be measured instead of guessed from INI `Geometry` (a collision shape: Ranger cylinder radius 7, height 13).

**Architecture:** One module `tools/zh_w3d.py` in the style of `tools/zh_ini.py`. It reuses `read_big` from `tools/check_reference.py`, walks W3D chunks, reads only mesh headers (`W3dMeshHeader3Struct` Min/Max), hierarchy pivots and HLOD sub-object bindings, composes bone transforms and writes rows under `build/`. Tests build invented W3D chunks in memory; one real-archive test runs only when the retail archives exist.

**Tech Stack:** Python 3.12 standard library (`struct`, `json`, `argparse`), `unittest`; ruff and mypy via `sh tools/run_python_checks.sh`.

**Spec:** idea in the session notes (private), user 2026-11-10: a small tool like `tools/zh_ini.py` that reads the retail `.big` archives in place and dumps per-model mesh bounding boxes and bone positions; sizes and proportions only (unit vs building scale, hull/turret/barrel, infantry height and width); no vertices, textures or traced outlines; output under `build/`, never committed. Handoff: the night-run prompt (private). Resume record and evidence: [w3d size reader verification](../../reference/w3d-size-reader-verification.md).

**Format source (read only):** `~/projects/GeneralsGameCode` @ `afc2a103f` (HEAD on 2026-11-12). `Generals/Code/Libraries/Source/WWVegas/WW3D2/w3d_file.h`: chunk ids 346, 351, 409–411, 478–482, 486; `W3dChunkHeader` 534; mesh flags 1183 (`HIDDEN` `0x1000`), 1189–1192 (geometry mask `0x00FF0000`, `SKIN` `0x00020000`); `W3dMeshHeader3Struct` 1233–1263 (Min 1258, Max 1259); `W3dHierarchyStruct` 1384, `W3dPivotStruct` 1392; `W3dHLodHeaderStruct` 2079, `W3dHLodSubObjectStruct` 2093; `W3dBoxStruct` 2129. Size mask: `Core/Libraries/Source/WWVegas/WWLib/chunkio.h:86`. Pivot transform `T * R(q)` with `q = (x, y, z, w)`: `Core/Libraries/Source/WWVegas/WW3D2/htree.cpp:289-312`, `Core/Libraries/Source/WWVegas/WWMath/quat.h:203-221`. Archive precedence (Zero Hour archives load first, then the Generals install with `overwrite = FALSE`, appended): `Core/GameEngine/Source/Common/System/BIGFileSystem.cpp:89-98`, `Core/GameEngine/Source/Common/System/ArchiveFileSystem.cpp:158-169`; uncertainty: the lookup side of that multimap was not read.

## Global Constraints

- EA data never enters the repository: output only under `build/zh_w3d/` (`build/` is gitignored), never committed; test fixtures are invented bytes built in the test; tracked docs quote single derived values with entry and mesh name only (AGENTS.md, reference handling). Archives are read in place, never copied.
- Read only chunk headers, mesh headers, hierarchy and HLOD chunks. No vertices, faces, textures, materials, animation or traced outlines.
- Default archives, in precedence order (first archive holding an entry wins; user, 2026-11-12): `$HOME/CnC/run/Command & Conquer Generals - Zero Hour/W3DZH.big`, `$HOME/CnC/run/Command & Conquer Generals - Zero Hour/W3DEnglishZH.big`, `$HOME/CnC/run/Command and Conquer Generals/W3D.big` (note the two spellings: `&` for Zero Hour, `and` for Generals; all three exist, checked 2026-11-12). Default output `build/zh_w3d/w3d.jsonl` relative to the repo root. No hash pin (no pinned hash exists for W3D archives; the evidence row records `shasum -a 256`).
- Standard library only; typed; `sh tools/run_python_checks.sh` and `sh tools/check_public.sh` pass. No change under `game/`, `relay/`, `protocol/`, `.github/` or to `AGENTS.md`; no Godot suite run (Python and docs only, as in the zh-ini dump run).
- No GUI, no Godot side, no scale table applied to the game.
- Worktree `~/projects/wargrid-wt-w3d`, branch `w3d-size-reader`. The coordinator makes one local commit after each GREEN task, never pushes (user, 2026-11-12). Subagents never commit; `git add -N` on new files is allowed (`tools/run_python_tests.sh` finds tests with `git ls-files`).

## Settled choices

1. **What the `body` box leaves out: (a) (user, 2026-11-12).** (a) hidden-flag meshes and meshes whose name contains `FX` (chosen: at least 288 retail mesh names start with `MUZZLEFX`, `TURRETFX`, `BURNERFX` and similar; the hidden flag marks only 48 meshes in all, and the INI names flash meshes per weapon, e.g. `WeaponMuzzleFlash = PRIMARY TurretFX` on `AmericaTankCrusader`); (b) hidden-flag meshes only (Leopard body becomes `[60.49, 17.27, 15.19]`, Ranger `[4.98, 24.09, 14.61]`); (c) no `body`, per-mesh boxes only.
2. **Generals `W3D.big` in the default archives: (a) (user, 2026-11-12).** (a) yes, after the two Zero Hour archives (chosen: the Ranger skin and the Crusader's `AVLeopard` exist only there); (b) Zero Hour archives only, as the 2026-11-10 note named them (the motivating examples are then missing).

## Review Focus

- **Effect meshes inflating the body box** (`TURRETFX01` muzzle flash stretches a tank's length by a third): body excludes them and names them in `excluded`. Test in Task 1.
- **Rigid meshes are stored in bone space** (a turret mesh's box sits at the origin, its bone 7 units up): boxes must be transformed by the composed bone transform, rotation included. Test in Task 1.
- **A malformed entry** (five `uisabotr_*.w3d` entries in `W3DZH.big` overrun their chunk sizes) must skip that entry with a message, never abort the dump or emit garbage. Test in Task 1.
- **Skins whose hierarchy lives in another entry** (`airngr_skn.w3d` uses `AIRNGR_SKL`): the hierarchy is resolved across entries. Test in Task 1.
- **The same entry in Zero Hour and Generals archives** (96 entries): the Zero Hour copy wins. Test in Task 2.

## File structure

- Create `tools/zh_w3d.py`: chunk walk, row building (Task 1); `load_entries`, `dump`, `main` (Task 2).
- Create `tools/test_zh_w3d.py`: synthetic tests (Task 1), dump/CLI and real-archive tests (Task 2).
- Modify (Task 2): `docs/development.md:68`, `docs/guide/13-testing-and-tooling.md` (lines 27, 105, 107, after 113, 212), `docs/reference/w3d-size-reader-verification.md`.

## Session start for every task

Steps 1, 2 and 4 of [milestone prompt session start](../../milestone-prompt.md#session-start-coordinator-steps-12-every-task-subagent-steps-14). Step 3 baseline is `sh tools/run_python_checks.sh > ~/projects/wargrid-overnight-work/night-2026-11-13/w3d/py-base.log 2>&1; echo "exit=$?"` (timeout 600000). If `~/projects/wargrid-wt-w3d/tools/.venv` is missing, first run `ln -s ~/projects/wargrid/tools/.venv ~/projects/wargrid-wt-w3d/tools/.venv` (ignored through `.git/info/exclude`).

---

### Task 1: Chunk walk and rows (Sonnet)

**Files:**
- Create: `~/projects/wargrid-wt-w3d/tools/zh_w3d.py`
- Create: `~/projects/wargrid-wt-w3d/tools/test_zh_w3d.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `Entry = tuple[str, str, bytes]`: (archive file name such as `"W3D.big"`, entry name such as `"art\\w3d\\x.w3d"`, raw bytes).
  - `walk(data: bytes, start: int, end: int) -> Iterator[tuple[int, int, int]]`: yields `(chunk_type, payload_start, payload_end)`; size is `raw & 0x7FFFFFFF`; raises `ValueError` when a header or payload crosses `end`.
  - `build_rows(entries: list[Entry]) -> tuple[list[Row], list[str]]`: rows in input order and skip messages `"<entry>: <reason>"`.
  - TypedDicts: `Box{min, max, size: list[float]}`, `Mesh{name: str, bone: int | None, skin: bool, hidden: bool, min: list[float], max: list[float]}`, `Bone{name: str, parent: int, position: list[float]}`, `Row{entry: str, archive: str, hlod: str | None, hierarchy: str | None, meshes: list[Mesh], pivots: list[Bone], body: Box | None, excluded: list[str], unresolved: list[str]}`.

**Rules (decided; the implementer writes the code):**
- Chunk ids: `MESH 0x000`, `MESH_HEADER3 0x01F`, `HIERARCHY 0x100`, `HIERARCHY_HEADER 0x101`, `PIVOTS 0x102`, `HLOD 0x700`, `HLOD_HEADER 0x701`, `HLOD_LOD_ARRAY 0x702`, `HLOD_SUB_OBJECT 0x704`, `BOX 0x740`. Recurse by chunk type, not by the sub-chunk flag (containers: `MESH`, `HIERARCHY`, `HLOD`, `HLOD_LOD_ARRAY`); ignore every other chunk.
- Structs (little endian): mesh header `"<II16s16s9I3f3f3ff"` (116 bytes; MeshName then ContainerName; Min at offset 76, Max at 88); hierarchy header `"<I16sI3f"`; pivot `"<16sI3f3f4f"` (60 bytes: name, parent, translation, euler, quaternion x,y,z,w; parent `0xFFFFFFFF` is root, output `-1`); HLOD header `"<II16s16s"` (Name, HierarchyName); sub-object `"<I32s"` (bone index, `CONTAINER.MESH`); box `"<II32s4B3f3f"` (name at offset 8). Names: bytes up to the first NUL, latin-1. A mesh's full name is `CONTAINER.MESH` (just `MESH` when the container is empty); match sub-objects to meshes and hierarchies by upper-cased name.
- Bone world transform: `world[i] = (world[p].pos + rotate(world[p].q, t[i]), world[p].q * q[i])`, root `(t, q)`. A parent index not smaller than its own index raises `ValueError` (entry skipped). Rotation (active, as `quat.h:203-221`):

```python
def rotate(q: Quat, v: Vec3) -> Vec3:
    x, y, z, w = q
    tx, ty, tz = 2 * (y * v[2] - z * v[1]), 2 * (z * v[0] - x * v[2]), 2 * (x * v[1] - y * v[0])
    return (v[0] + w * tx + y * tz - z * ty, v[1] + w * ty + z * tx - x * tz, v[2] + w * tz + x * ty - y * tx)
```

- Mesh model-space box: rotate the 8 corners of Min/Max by the bone transform, then min/max. Skin meshes (`attributes & 0x00FF0000 == 0x00020000`) and meshes in entries without an HLOD (`bone: None`) use identity. The bone's hierarchy is the HLOD's HierarchyName, looked up in an index of every entry's own hierarchy (first entry in input order wins). A rigid mesh whose hierarchy or bone index is missing goes to `unresolved`, as does a sub-object naming neither a mesh nor a `BOX` chunk. Sub-objects naming a `BOX` chunk (collision/pick boxes) are dropped silently.
- `meshes` lists resolved sub-objects in HLOD order (all meshes in file order when there is no HLOD). `body` is the union over `meshes` that are not `hidden` (`attributes & 0x1000`) and whose part after the dot does not contain `FX` (upper-cased; settled choice 1, user 2026-11-12); those names go to `excluded`. `body` is `None` when nothing remains.
- `hierarchy` is the HLOD's HierarchyName, else the entry's own hierarchy name, else `None`. `pivots` lists only the entry's own hierarchy, with composed model-space positions.
- Emit a row only for entries with a mesh or a hierarchy (animation-only entries give none). Every float output is `round(v, 3) + 0.0` (the `+ 0.0` turns `-0.0` into `0.0`).
- Shortcut comment to keep in the code: `# shortcut: only LOD 0 of the HLOD is read; every retail HLOD has one LOD (2026-11-12 probe).`

- [ ] **Step 1: Write the failing tests** in `tools/test_zh_w3d.py`. Builders (invented bytes; keep them in the test file):

```python
S = math.sqrt(0.5)  # 90 degrees about z: (0, 0, S, S)
ROOT = ("ROOTTRANSFORM", -1, (0.0, 0.0, 0.0), (0.0, 0.0, 0.0, 1.0))

def chunk(kind: int, payload: bytes, sub: bool = False) -> bytes:
    return struct.pack("<II", kind, len(payload) | (0x80000000 if sub else 0)) + payload

def mesh(container: str, name: str, lo, hi, attributes: int = 0) -> bytes:
    head = struct.pack("<II16s16s9I3f3f3ff", 0x40002, attributes, name.encode(), container.encode(), *[0] * 9, *lo, *hi, 0, 0, 0, 0)
    return chunk(0x000, chunk(0x01F, head), sub=True)

def hierarchy(name: str, pivots) -> bytes:
    head = struct.pack("<I16sI3f", 0x40001, name.encode(), len(pivots), 0, 0, 0)
    body = b"".join(struct.pack("<16sI3f3f4f", n.encode(), p & 0xFFFFFFFF, *t, 0, 0, 0, *q) for n, p, t, q in pivots)
    return chunk(0x100, chunk(0x101, head) + chunk(0x102, body), sub=True)

def hlod(name: str, hier: str, subs) -> bytes:
    lods = chunk(0x703, struct.pack("<If", len(subs), 0.0)) + b"".join(chunk(0x704, struct.pack("<I32s", b, s.encode())) for b, s in subs)
    return chunk(0x700, chunk(0x701, struct.pack("<II16s16s", 0x10000, 1, name.encode(), hier.encode())) + chunk(0x702, lods, sub=True), sub=True)

def box(full_name: str) -> bytes:
    return chunk(0x740, struct.pack("<II32s4B3f3f", 0, 0, full_name.encode(), 0, 0, 0, 0, 0, 0, 0, 1, 1, 1))

TANK = (
    hierarchy("TANK", [ROOT, ("HULL", 0, (1, 0, 0), (0, 0, S, S)), ("GUN", 1, (2, 0, 1), (0, 0, 0, 1))])
    + mesh("TANK", "HULL", (0, 0, 0), (2, 1, 1)) + mesh("TANK", "GUN", (0, 0, 0), (1, 0.5, 0.5))
    + mesh("TANK", "MUZZLEFX01", (0, 0, 0), (5, 5, 5)) + mesh("TANK", "SECRET", (-9, -9, -9), (9, 9, 9), 0x1000)
    + box("TANK.PICKBOX")
    + hlod("TANK", "TANK", [(1, "TANK.HULL"), (2, "TANK.GUN"), (2, "TANK.MUZZLEFX01"), (0, "TANK.SECRET"), (0, "TANK.PICKBOX"), (0, "TANK.GHOST")])
)
```

Tests and their assertions (exact values; compare float lists with `assertEqual` after the tool's rounding):
- `test_walk_masks_sub_chunk_flag`: `list(zh_w3d.walk(chunk(0x100, b"abcd", sub=True), 0, 12)) == [(0x100, 8, 12)]`.
- `test_walk_overrun_raises`: `walk` over `struct.pack("<II", 0x0, 99) + b"x"` raises `ValueError`.
- `test_bone_positions_compose_rotation`: row for `[("W3D.big", "tank.w3d", TANK)]`: `[(b["name"], b["parent"], b["position"]) for b in row["pivots"]] == [("ROOTTRANSFORM", -1, [0.0, 0.0, 0.0]), ("HULL", 0, [1.0, 0.0, 0.0]), ("GUN", 1, [1.0, 2.0, 1.0])]`.
- `test_rigid_mesh_box_in_model_space`: mesh `TANK.HULL` has `bone 1`, `min [0.0, 0.0, 0.0]`, `max [1.0, 2.0, 1.0]`; `TANK.GUN` has `min [0.5, 2.0, 1.0]`, `max [1.0, 3.0, 1.5]`.
- `test_body_excludes_hidden_and_fx`: `row["body"] == {"min": [0.0, 0.0, 0.0], "max": [1.0, 3.0, 1.5], "size": [1.0, 3.0, 1.5]}`; `row["excluded"] == ["TANK.MUZZLEFX01", "TANK.SECRET"]`; `TANK.SECRET` mesh has `hidden True`.
- `test_box_dropped_missing_listed`: `row["unresolved"] == ["TANK.GHOST"]`; no mesh named `TANK.PICKBOX`; `[m["name"] for m in row["meshes"]] == ["TANK.HULL", "TANK.GUN", "TANK.MUZZLEFX01", "TANK.SECRET"]`; `set(row) == {"entry", "archive", "hlod", "hierarchy", "meshes", "pivots", "body", "excluded", "unresolved"}`; `row["archive"] == "W3D.big"`.
- `test_skin_uses_hierarchy_from_other_entry`: entries `("W3D.big", "soldier_skl.w3d", hierarchy("SOLDIER_SKL", [ROOT, ("HAND", 0, (0, 0, 3), (0, 0, 0, 1))]))` and `("W3D.big", "soldier_skn.w3d", mesh("SOLDIER_SKN", "BODY", (-1, -1, 0), (1, 1, 4), 0x20000) + mesh("SOLDIER_SKN", "RIFLE", (0, 0, 0), (0, 2, 0.5)) + hlod("SOLDIER_SKN", "SOLDIER_SKL", [(0, "SOLDIER_SKN.BODY"), (1, "SOLDIER_SKN.RIFLE")]))`: skin row `hierarchy == "SOLDIER_SKL"`, `pivots == []`, `BODY` `skin True` with `min [-1.0, -1.0, 0.0]`, `RIFLE` `min [0.0, 0.0, 3.0]`, `max [0.0, 2.0, 3.5]`, `body["size"] == [2.0, 3.0, 4.0]`; the skeleton row has `meshes == []`, `body is None`, `hlod is None`, `hierarchy == "SOLDIER_SKL"`.
- `test_missing_hierarchy_rigid_unresolved`: the skin entry above alone (no skeleton entry): `unresolved == ["SOLDIER_SKN.RIFLE"]`, `body["size"] == [2.0, 2.0, 4.0]`.
- `test_no_hlod_mesh_identity`: `mesh("", "ROCK", (-1, -2, 0), (1, 2, 3))` alone: one mesh `name "ROCK"`, `bone None`, `min [-1.0, -2.0, 0.0]`; `hlod is None`; `body["size"] == [2.0, 4.0, 3.0]`.
- `test_bad_entry_skipped`: entries `("W3D.big", "bad.w3d", struct.pack("<II", 0x0, 99))` and the tank: one row (`tank.w3d`), skips `== [...]` of length 1 starting with `"bad.w3d: "`.
- `test_animation_only_no_row`: `chunk(0x200, b"\0" * 8, sub=True)` alone gives no row and no skip.
- `test_parent_after_child_skipped`: hierarchy with pivots `[ROOT, ("A", 2, (0, 0, 0), (0, 0, 0, 1)), ("B", 0, (0, 0, 0), (0, 0, 0, 1))]` gives no row and one skip.

- [ ] **Step 2: Run, expect failure.** `cd ~/projects/wargrid-wt-w3d && python3 tools/test_zh_w3d.py > ~/projects/wargrid-overnight-work/night-2026-11-13/w3d/t1-red.log 2>&1; echo "exit=$?"`. Expected: exit 1, `ModuleNotFoundError: No module named 'zh_w3d'` (or `AttributeError`).

- [ ] **Step 3: Implement** `walk`, `build_rows` and the TypedDicts in `tools/zh_w3d.py` per the rules above. Module docstring like `zh_ini.py`'s: purpose, "Local research tool: reads the retail archives in place; the output stays under build/ and is never committed.", usage `python3 tools/zh_w3d.py dump [archive ...] [--out PATH]`. Small functions (one per chunk kind, `rotate`, transform composition, box transform).

- [ ] **Step 4: Run, expect pass.** Same command into `t1-green.log`. Expected: exit 0, `OK`, 12 tests.

- [ ] **Step 5: Gates.** `git add -N tools/zh_w3d.py tools/test_zh_w3d.py`; `tools/.venv/bin/ruff format tools/zh_w3d.py tools/test_zh_w3d.py` (the venv's ruff, which the checks use; a `ruff` on `PATH` may be another version); `sh tools/run_python_checks.sh > ~/projects/wargrid-overnight-work/night-2026-11-13/w3d/t1-py.log 2>&1; echo "exit=$?"` (timeout 600000). Expected: exit 0, last line `PYTHON TESTS PASSED`. On failure read only `rg -n 'error|FAIL|Error' <log>`.

- [ ] **Step 6: Record and hand back.** Update the resume record and add an evidence row (tree, command, test count, exit). Return `GREEN` with counts, exit and changed paths. Coordinator local commit (pre-authorized, user 2026-11-12): `Add W3D chunk reader for model sizes`.

**Stop (park, do not improvise):** a listed assertion fails and the fix would change the stated rules or expected values; mypy or ruff needs a config change; any test would need EA bytes.

---

### Task 2: Dump, CLI, real-archive check and docs (Sonnet)

**Files:**
- Modify: `~/projects/wargrid-wt-w3d/tools/zh_w3d.py`, `~/projects/wargrid-wt-w3d/tools/test_zh_w3d.py`
- Modify: `~/projects/wargrid-wt-w3d/docs/development.md`, `~/projects/wargrid-wt-w3d/docs/guide/13-testing-and-tooling.md`, `~/projects/wargrid-wt-w3d/docs/reference/w3d-size-reader-verification.md`

**Interfaces:**
- Consumes: `Entry`, `Row`, `build_rows` (Task 1); `check_reference.read_big(data: bytes) -> dict[str, str]` (lower-cased names, latin-1 text); `test_check_reference.big(files: dict[str, str]) -> bytes`.
- Produces: `DEFAULT_ARCHIVES: list[Path]`, `DEFAULT_OUT: Path`, `load_entries(archives: list[Path]) -> list[Entry]`, `dump(archives: list[Path], out: Path) -> tuple[int, int, int, int]` (w3d entries, rows, meshes, skipped), `main(argv: list[str], out: TextIO = sys.stdout) -> int`.

**Rules:**
- `load_entries`: `.w3d` entries only, sorted by entry name, each from the first archive in the list that has it; bytes via `text.encode("latin-1")` with the comment `# read_big decodes latin-1, which round-trips every byte.`
- `dump` writes `out.name + ".tmp"` then renames (as `zh_ini.dump`); skip messages go to stderr as `zh_w3d: skipped <message>`.
- `main`: `argparse` with `command` choices `["dump"]`, `archives` `nargs="*"` defaulting to `DEFAULT_ARCHIVES`, `--out` default `DEFAULT_OUT`. On `OSError`/`ValueError`: remove the `.tmp`, print `zh_w3d: <error>` to stderr, return 1. Success line on `out`: `ZH_W3D entries=<n> rows=<n> meshes=<n> skipped=<n> out=<path>`.

- [ ] **Step 1: Write the failing tests** in `tools/test_zh_w3d.py` (reuse Task 1 builders; wrap bytes for `big()` with `.decode("latin-1")`; every archive and `out` in a `tempfile.TemporaryDirectory()`, as `test_zh_ini.DumpTest`, never in the worktree):
  - `test_dump_and_cli`: archive `x.big` with `art\w3d\tank.w3d` = `TANK` and `art\w3d\notes.txt`; `main(["dump", str(archive), "--out", str(out)], stream)` returns 0; output matches `r"^ZH_W3D entries=1 rows=1 meshes=4 skipped=0 out="`; one JSONL row with the Task 1 key set.
  - `test_first_archive_wins`: `a.big` and `b.big` both hold `art\w3d\tank.w3d` (`a` = `TANK`, `b` = `mesh("", "ROCK", (0, 0, 0), (1, 1, 1))`); `load_entries([a, b])` gives one entry from `"a.big"`; with `[b, a]` from `"b.big"`.
  - `test_missing_archive`: as `test_zh_ini.DumpTest.test_missing_archive` (exit 1, stderr text, no output file).
  - `test_failed_run_keeps_previous_dump`: existing `out` with `old\n` and a file that is not a BIG archive: exit 1, `out` still `old\n`, no `.tmp`.
  - `RealArchiveTest` (`@unittest.skipUnless(all(p.exists() for p in zh_w3d.DEFAULT_ARCHIVES), "retail archives not present")`), one `test_real_archives` building rows once: `len(load_entries(...)) == 8896`; 5 skips, all starting with `art\w3d\uisabotr_`; by entry (`assertAlmostEqual(..., delta=0.01)` per value):
    - `art\w3d\avleopard.w3d`: `archive "W3D.big"`, pivot `TURRET` position `[0.49, 0.03, 7.36]`, `body["size"] [44.36, 17.27, 10.85]`, `"AVLEOPARD.TURRETFX01" in excluded`.
    - `art\w3d\airngr_skn.w3d`: `hierarchy "AIRNGR_SKL"`, mesh `AIRNGR_SKN.AIRNGR-SKN` `skin True`, `body["max"][2] 14.55`, `body["size"] [3.7, 19.51, 14.61]`.
    - `art\w3d\abbarracks.w3d`: `body["size"] [110.35, 88.12, 48.88]`; mesh `ABBARRACKS.HOUSECOLOR04` `min [38.25, -29.13, 38.62]`, `max [42.8, -28.12, 46.31]` (rotated bone chain).
  These values come from an independent read-only probe (`~/projects/wargrid-overnight-work/night-2026-11-13/w3d/compose.py`), not from this code; a mismatch is a stop, not a re-pin.

- [ ] **Step 2: Run, expect failure** (`python3 tools/test_zh_w3d.py` into `t2-red.log`; `AttributeError` on `main`/`load_entries`).

- [ ] **Step 3: Implement** `DEFAULT_ARCHIVES`, `DEFAULT_OUT`, `load_entries`, `dump`, `main` per the rules.

- [ ] **Step 4: Run, expect pass**, then the real dump: `cd ~/projects/wargrid-wt-w3d && python3 tools/zh_w3d.py dump > ~/projects/wargrid-overnight-work/night-2026-11-13/w3d/dump.log 2>&1; echo "exit=$?"`. Expected: exit 0, five `zh_w3d: skipped art\w3d\uisabotr_` lines, last line `ZH_W3D entries=8896 rows=<n> meshes=<n> skipped=5 out=.../build/zh_w3d/w3d.jsonl`. Then `git status --short` shows nothing under `build/`. Record `shasum -a 256` of the three archives in the evidence row (hash only, no paths beyond `~`).

- [ ] **Step 5: Docs** (edit exactly these, nothing else):
  - `docs/development.md`, after line 68 (`python3 tools/zh_ini.py dump ...`) add:
    `python3 tools/zh_w3d.py dump   # Zero Hour model sizes (mesh boxes, body box, bone positions) to build/zh_w3d/w3d.jsonl (gitignored, never committed); needs the local retail archives`
  - `docs/guide/13-testing-and-tooling.md`: line 27 `(\`zh_ini.py\`, \`check_reference.py\`, \`zh_parity/\`)` becomes `(\`zh_ini.py\`, \`zh_w3d.py\`, \`check_reference.py\`, \`zh_parity/\`)`; heading line 105 `three separate tools` becomes `four separate tools` (no link targets that anchor, checked 2026-11-12); line 107 `Three tools support that.` becomes `Four tools support that.`; after the zh_ini bullets (after line 113) add:

    ```markdown
    **`tools/zh_w3d.py`: model sizes, not models.** `python3 tools/zh_w3d.py dump` reads the retail W3D archives in place (Zero Hour first, then Generals `W3D.big`, as the game loads them) into `build/zh_w3d/w3d.jsonl`, one row per `.w3d` entry: each mesh's bounding box moved into model space through its bone, a `body` box over the visible meshes (hidden and `*FX*` effect meshes are listed in `excluded`), and bone positions. INI `Geometry` is a collision shape, not the visible body; this measures the body. It reads headers only: no vertices, textures or outlines. Cite as entry plus mesh or bone name, for example `jq -c 'select(.entry=="art\\w3d\\avleopard.w3d") | .body' build/zh_w3d/w3d.jsonl`; a skin's bones are on the row of its hierarchy (`select(.hierarchy=="AIRNGR_SKL" and .hlod==null)`).
    ```
  - line 212 `- \`tools/zh_ini.py\`, \`check_reference.py\` — INI dump and value comparison; \`tools/test_zh_ini.py\`, \`test_check_reference.py\`.` gains after it: `- \`tools/zh_w3d.py\` — model size dump; \`tools/test_zh_w3d.py\`.`

- [ ] **Step 6: Gates.** `sh tools/run_python_checks.sh > .../t2-py.log 2>&1; echo "exit=$?"` (exit 0, `PYTHON TESTS PASSED`; the real-archive test ran: `python3 tools/test_zh_w3d.py -v 2>&1 | rg real_archives` shows `ok`, not `skipped`). `sh tools/check_public.sh > .../t2-public.log 2>&1; echo "exit=$?"` (exit 0, `PUBLIC CHECK PASSED`). Check each changed doc link resolves (`rg -n 'zh_w3d|w3d-size-reader' docs`).

- [ ] **Step 7: Record and hand back** (resume record, evidence rows for tests, dump, hashes, gates). Coordinator local commit (pre-authorized, user 2026-11-12): `Add the W3D size dump and its usage note`.

**Stop (park):** real-archive values differ from the pins by more than 0.01; entry count is not 8896 or skips are not the five `uisabotr_` entries; the dump writes anything outside `build/`; `check_public.sh` fails on a line this task wrote and rewording does not fix it.

---

### Task 3: Fresh review (Opus, read-only)

**Files:** none changed by the reviewer; the coordinator writes the verdict into the verification file's Gate result.

- [ ] **Step 1:** A fresh Opus subagent that has not seen the implementation gets: this plan path, `git -C ~/projects/wargrid-wt-w3d diff main...w3d-size-reader` (plus uncommitted changes), the changed file paths and the format source citations above. No repo-wide search. It uses `ponytail:ponytail-review` for the over-engineering pass.
- [ ] **Step 2:** It checks the struct formats and offsets against `w3d_file.h` at `afc2a103f`, the transform order against `htree.cpp:289-312` and `quat.h:203-221`, that no EA bytes or decoded data are tracked (`git diff --stat` lists only the five paths of this plan's File structure, plus this plan file if the night preparation committed it), and runs mutation checks in a scratch copy under `~/projects/wargrid-overnight-work/night-2026-11-13/w3d/mut/` (never in the worktree; copy `zh_w3d.py`, `test_zh_w3d.py`, `check_reference.py` and `test_check_reference.py`, and confirm the unmutated copy passes before any mutation): drop the `FX` exclusion, use identity bone transforms, conjugate the quaternion, remove the overrun check, reverse archive precedence. Each must turn `python3 test_zh_w3d.py` red; name the test that fails.
- [ ] **Step 3:** It returns PASS or FAIL with findings (file:line, severity) in at most 15 lines. FAIL findings become a fix task for a fresh Sonnet subagent, then a re-check by a fresh Opus reviewer. Then stop: merge and push wait for the user.

## Stop conditions

[Milestone prompt stop conditions](../../milestone-prompt.md#stop-conditions) apply, plus the per-task stops above. Never re-pin a real-archive value, widen the 0.01 delta or skip a test to go green.
