# Pathing Timing Spike Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** approved (user, 2026-11-10), not started. Starts only after avoidance round 4 has finished its timed runs.

**Goal:** Measure, in GDScript on the Ashfall map at 2x2 pathing cells per building cell, what three pathing methods cost: a finer grid with path straightening, a hand-written rectangle navmesh, and flow fields.

**Architecture:** Benchmark scripts only, under `game/benchmarks/pathspike/` on a new branch `spike-pathing`. They load Ashfall through the existing workload, build a fine blocked-cell array, and time each method on the same 200 start/goal pairs for unit widths 1, 2 and 3 cells. No file under `game/scripts/` changes. A small check script proves each algorithm on hand-made maps before anything is timed. The result is an evidence note; choosing a method is the user's decision afterwards.

**Tech Stack:** typed GDScript on Godot 4.7.2 headless (`AStarGrid2D`, `AStar2D`, packed arrays), Python 3 standard library for the table.

**Spec:** [design answers](../../reference/design-answers-2026-11-08.md#movement-and-pathing-user-2026-11-10), "Movement and pathing (user, 2026-11-10)"; background and research in the [movement and pathing brief](../../questions/movement-pathing-brief.md).

**Model routing:** one fresh mid-tier implementer per task (Sonnet); a fresh-context reviewer on the strongest available model for Task 6; the coordinator (the session running this plan) makes every commit.

## Global Constraints

- Evidence only. No design decision, no change under `game/scripts/`, no test change, no merge, no push. The note ends with a proposal; the user chooses the method.
- Branch `spike-pathing` in worktree `~/projects/wargrid-wt-path`. Never switch the branch of `~/projects/wargrid` or touch `~/projects/wargrid-wt-avoid`. Local commits on `spike-pathing` are made by the coordinator only (authorized by approving this plan); subagents never commit, push, rebase or change branches. A subagent may run `git add -N <new file>` so that `tools/run_warnings.sh` sees new files.
- `PW` = `~/projects/wargrid-overnight-work/movement/spike` (logs, results, table script). Nothing from `PW` goes into the repo.
- Grid scale 2 (user): one building cell is 2x2 pathing cells. Ashfall is 194x187 building cells, so 388x374 pathing cells.
- Unit widths 1, 2 and 3 pathing cells stand in for "size per unit kind" (user). Which kind gets which width is not part of this spike.
- Every number is a GDScript cost on the development Mac. The note labels them so, and gives the browser figure only as "projected, x5.5" (the slowdown factor in `docs/reference/performance.md`). They are re-read after the native simulation core spike.
- One Godot process at a time on the whole machine. Before every run: `pgrep -fl godot` must print nothing, and `pgrep -fl 'World of Warcraft'` must print nothing; write `uptime` into the log before and after. If either process is running, wait; never time a run beside another.
- Every Godot call: output redirected to a file under `PW/logs/`, Bash tool `timeout: 600000`. Read only the `PATHSPIKE` lines and any line containing `ERROR`.
- Every script that extends `SceneTree` calls `quit()` on every path (a script error otherwise hangs until the timeout).
- Typed GDScript, no comments except a one-line why. `sh tools/run_lint.sh` and `sh tools/run_warnings.sh` pass in the worktree before each commit. `run_warnings.sh` rejects integer division: write `floori(a / float(b))`, as `avoidance.gd` does.
- Timed regions contain only the measured call: no printing, no pair generation, no array building for the report. Run each timed loop once untimed first (warm-up).
- Use `Time.get_ticks_usec()` and report milliseconds with four decimals. Use `preload` constants, not class names, to reach other scripts.

## Review Focus

- **A timed number that measures the wrong thing.** Check that pair generation, checks and printing are outside every timed region, and that warm-up ran.
- **Different work per method.** All three use the same pairs from `FineMap.pairs(...)` with seed `20261110`, valid for width 3, so every pair is valid for widths 1 and 2 too.
- **A wrong algorithm that is fast.** `run_check.gd` passes before any timing; `run_mesh.gd` also asserts on real Ashfall that the rectangles cover every free cell exactly once.
- **Corner cutting.** No path, line check or flow step may pass diagonally between two blocked cells or past a blocked corner. Each has a check case.
- **Noise.** Three runs per script on a quiet machine; the table shows the median and the spread (max minus min) of each number.

## File structure

- `game/benchmarks/pathspike/fine_map.gd`: load Ashfall, widen blockers for a unit width, build an `AStarGrid2D`, make the pairs, print result lines.
- `game/benchmarks/pathspike/smooth.gd`: line-of-sight test and path straightening on the cell array.
- `game/benchmarks/pathspike/rect_mesh.gd`: rectangle navmesh (method B).
- `game/benchmarks/pathspike/flow_field.gd`: flow fields (method C).
- `game/benchmarks/pathspike/run_check.gd`: correctness checks on hand-made maps.
- `game/benchmarks/pathspike/run_grid.gd`, `run_mesh.gd`, `run_flow.gd`: the timed runs for A, B and C.
- `docs/reference/pathing-timing-spike.md` (on `spike-pathing`): the evidence note.
- Outside the repo: `PW/context.md`, `PW/scripts/table.py`, `PW/logs/`, `PW/results/`.

Result line format, used by every run script and read by `table.py`:

```text
PATHSPIKE method=<grid|mesh|flow> metric=<name> <key>=<value> <key>=<value> ...
```

Keys are printed in sorted order. Times are in milliseconds with four decimals (`"%.4f"`). A distribution is reported as `n`, `p50`, `p95`, `max` (from `Stats.summary` in `res://scripts/debug/timing_stats.gd`).

---

### Task 0: Setup (coordinator)

- [ ] **Step 1:** Confirm avoidance round 4 has no timed run in progress (`pgrep -fl godot` prints nothing).
- [ ] **Step 2:** `cd ~/projects/wargrid && git worktree add ../wargrid-wt-path -b spike-pathing main`
- [ ] **Step 3:** `mkdir -p ~/projects/wargrid-overnight-work/movement/spike/{logs,results,scripts}`
- [ ] **Step 4:** Import the project once: `godot --headless --path ~/projects/wargrid-wt-path/game --import > PW/logs/import.log 2>&1`. Expected: exit 0 and no line containing `ERROR`.
- [ ] **Step 5:** Write `PW/context.md` with: the plan's path; the worktree path; the Global Constraints above copied verbatim; and "Do only the task you were given. Report in under 12 lines: files changed, check and lint results with log paths, numbers asked for, and anything in the plan that did not match the code."

### Task 1: Shared map, straightening and the check script

**Files:**
- Create: `game/benchmarks/pathspike/fine_map.gd`, `game/benchmarks/pathspike/smooth.gd`, `game/benchmarks/pathspike/run_check.gd`

**Interfaces:**
- Consumes: `MovementWorkload.create("ashfall")` (`res://scripts/debug/movement_workload.gd`) returns a `Simulation`; `sim._navigation.snapshot()` is `{"size": [194, 187], "blocked_cells": [[x, y], ...]}` in building cells.
- Produces, in `fine_map.gd` (`extends RefCounted`):
  - `const SCALE: int = 2`
  - `static func load_ashfall() -> Dictionary` returning `{"size": Vector2i(388, 374), "solid": PackedByteArray, "coarse": RefCounted}`. `solid` has `size.x * size.y` bytes, index `y * size.x + x`, 1 = blocked; every blocked building cell `(x, y)` sets the four cells `(2x, 2y)`, `(2x + 1, 2y)`, `(2x, 2y + 1)`, `(2x + 1, 2y + 1)`. `coarse` is `sim._navigation`.
  - `static func dilate(solid: PackedByteArray, size: Vector2i, width: int) -> PackedByteArray`: cell `(x, y)` is 1 when any cell of the block `x .. x + width - 1`, `y .. y + width - 1` is blocked or lies outside the map. Width 1 returns a copy.
  - `static func grid(solid: PackedByteArray, size: Vector2i, diagonal: bool) -> AStarGrid2D`: `region = Rect2i(Vector2i.ZERO, size)`, `cell_size = Vector2.ONE`, `jumping_enabled = false`; when `diagonal`: `diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES` and both heuristics `AStarGrid2D.HEURISTIC_OCTILE`; otherwise `DIAGONAL_MODE_NEVER` and `HEURISTIC_MANHATTAN`; then `update()`, then `set_point_solid(cell)` for every blocked cell.
  - `static func pairs(astar: AStarGrid2D, solid: PackedByteArray, size: Vector2i, count: int, seed_value: int) -> Array[Vector2i]`: a flat list `[from0, to0, from1, to1, ...]` of `count` pairs. Draw cells with a `RandomNumberGenerator` whose `seed` is `seed_value` (`randi_range(0, size.x - 1)`, then `randi_range(0, size.y - 1)`, `from` first, then `to`). Reject a pair when either cell is blocked in `solid`, when `absi(dx) + absi(dy) < 100`, or when `astar.get_id_path(from, to)` is empty.
  - `static func emit(method: String, metric: String, fields: Dictionary) -> void`: prints one result line in the format above; floats with `"%.4f"`, everything else with `str`.
  - `static func path_length(cells: Array[Vector2i]) -> float`: sum of straight distances between consecutive cells.
- Produces, in `smooth.gd` (`extends RefCounted`):
  - `static func clear_line(solid: PackedByteArray, size: Vector2i, a: Vector2i, b: Vector2i) -> bool`
  - `static func pull(solid: PackedByteArray, size: Vector2i, cells: Array[Vector2i]) -> Array[Vector2i]`

`clear_line` walks every cell the straight line between the two cell centres touches, integers only. Use exactly this body:

```gdscript
static func clear_line(solid: PackedByteArray, size: Vector2i, a: Vector2i, b: Vector2i) -> bool:
	var dx: int = absi(b.x - a.x)
	var dy: int = absi(b.y - a.y)
	var sx: int = 1 if b.x > a.x else -1
	var sy: int = 1 if b.y > a.y else -1
	var x: int = a.x
	var y: int = a.y
	var error: int = dx - dy
	var steps: int = dx + dy
	dx *= 2
	dy *= 2
	while steps > 0:
		if solid[y * size.x + x] != 0: return false
		if error > 0:
			x += sx
			error -= dy
			steps -= 1
		elif error < 0:
			y += sy
			error += dx
			steps -= 1
		else:
			if solid[y * size.x + x + sx] != 0 or solid[(y + sy) * size.x + x] != 0: return false
			x += sx
			y += sy
			error += dx - dy
			steps -= 2
	return solid[b.y * size.x + b.x] == 0
```

`pull` keeps the first cell, then walks forward: while the line from the last kept cell to the next candidate is clear it skips the candidate; when the line is not clear it keeps the cell before the candidate and continues from there; it always keeps the last cell. A list of fewer than three cells is returned unchanged.

`run_check.gd` (`extends SceneTree`, `_initialize` defers `_run`): each named case below is exactly one call of a local `_check(condition: bool, name: String)` (combine a case's conditions with `and`), which counts and prints `FAIL <name>` on false. At the end it prints `PATHSPIKE CHECK PASSED <count>` and `quit(0)`, or `PATHSPIKE CHECK FAILED <failures>` and `quit(1)`.

- [ ] **Step 1: Write `run_check.gd` with these cases** (helper `_map(width: int, height: int, blocked: Array[Vector2i]) -> PackedByteArray` builds a hand-made map):
  - `dilate_w1`: on a 4x4 map with `(2, 2)` blocked, width 1 equals the input.
  - `dilate_w2`: same map, width 2: blocked cells are exactly `(1, 1)`, `(2, 1)`, `(1, 2)`, `(2, 2)` plus every cell with `x == 3` or `y == 3`.
  - `line_open`: 5x5 open map, `clear_line((0, 0), (4, 3))` is true.
  - `line_wall`: 5x5 with `(2, 2)` blocked, `clear_line((0, 0), (4, 4))` is false and `clear_line((0, 0), (4, 0))` is true.
  - `line_corner`: 5x5 with `(1, 0)` blocked, `clear_line((0, 0), (1, 1))` is false.
  - `pull_stairs`: 6x6 open, `pull([(0,0), (1,0), (1,1), (2,1), (2,2)])` equals `[(0,0), (2,2)]`.
  - `pull_wall`: 6x6 with `(1, 1)` blocked, `pull([(0,0), (1,0), (2,0), (2,1), (2,2)])` equals `[(0,0), (2,0), (2,2)]`.
  - `grid_diagonal`: 4x4 open, `grid(map, size, true).get_id_path((0,0), (3,3))` has 4 cells.
  - `grid_no_corner_cut`: 4x4 with `(1, 0)` blocked, the path from `(0, 0)` to `(1, 1)` from the diagonal grid has 3 cells.
  - `ashfall_size`: `load_ashfall().size == Vector2i(388, 374)` and the number of blocked fine cells is 4 times `coarse.snapshot().blocked_cells.size()`.
  - `pairs_repeat`: two calls of `pairs` with `count = 10` and seed `20261110` on the width-3 Ashfall grid return the same list of 20 cells.
- [ ] **Step 2:** Create `fine_map.gd` and `smooth.gd` with every function returning an empty or false value. Run `godot --headless --path ~/projects/wargrid-wt-path/game --script res://benchmarks/pathspike/run_check.gd > PW/logs/check-stub.log 2>&1; echo "exit=$?" >> PW/logs/check-stub.log`. Expected: `PATHSPIKE CHECK FAILED` with most cases failing, exit 1.
- [ ] **Step 3:** Implement both files.
- [ ] **Step 4:** Run the check into `PW/logs/check-1.log`. Expected: `PATHSPIKE CHECK PASSED 11`, `exit=0`.
- [ ] **Step 5:** `git add -N game/benchmarks/pathspike`; `sh tools/run_lint.sh > PW/logs/lint-1.log 2>&1` and `sh tools/run_warnings.sh > PW/logs/warnings-1.log 2>&1` in the worktree. Expected: both exit 0.
- [ ] **Step 6:** Coordinator commits "Pathing spike: fine map, straightening, checks".

### Task 2: Method A, finer grid plus straightening

**Files:**
- Create: `game/benchmarks/pathspike/run_grid.gd`

**Interfaces:**
- Consumes: everything from Task 1. `coarse.route(from: Vector2, to: Vector2) -> Array[Vector2]` is today's four-direction route in building cells.

`run_grid.gd` (`extends SceneTree`) prints these lines, all with `method=grid`. `W` runs over widths 1, 2, 3; `solid_W = FineMap.dilate(solid, size, W)`; the pairs come from `FineMap.pairs(grid of width 3, solid_3, size, 200, 20261110)`.

| metric | What is timed | Fields besides `n p50 p95 max` |
|---|---|---|
| `route_today` | `coarse.route(Vector2(from) / 2.0 + Vector2(0.25, 0.25), Vector2(to) / 2.0 + Vector2(0.25, 0.25))` per pair (today's baseline) | `cells_p50` (route size) |
| `build` | once per `W`: `dilate`, then `grid(solid_W, size, true)` | `width`, `dilate_ms`, `grid_ms`, `mem_bytes` (`OS.get_static_memory_usage()` after minus before the two calls); no distribution |
| `update` | once per `W`: mark the 8x8 block at the first pair's `from` cell blocked in a copy of `solid`, then `dilate` again and `set_point_solid` on the 8x8 block grown by `W - 1` cells to the left and top | `width`, `dilate_ms`, `set_solid_ms`; no distribution |
| `search` | per pair: `astar_W.get_id_path(from, to)` | `width`, `cells_p50` |
| `smooth` | per pair: `Smooth.pull(solid_W, size, path)` on the path just found | `width`, `before_p50`, `after_p50` (waypoint counts) |
| `group300` | width 2 only, see below | `individual_ms`, `shared_ms`, `trunk_cells`; no distribution |

`group300`: the 300 units stand on the fine cells `(2x, 2y)` for building cells `x` in 4..23 and `y` in 107..121 (the block the Ashfall workload spawns). The goal `G` is the `to` cell, among the 200 pairs, with the longest non-empty width-2 path from the first unit's cell. `individual_ms` is the total time of 300 times search plus `pull` from each unit's cell to `G`. `shared_ms` is the time of one search plus `pull` from the first unit's cell to `G` (the trunk), plus 300 searches from each unit's cell to the join cell `raw[mini(30, raw.size() - 1)]`, where `raw` is the trunk's search path before `pull` (the pulled trunk has only a few waypoints, so indexing it would put the join cell on `G`).

- [ ] **Step 1:** Write the script: load, build, pairs, one untimed warm-up pass over all pairs, then the timed passes, then the lines above, then `print("PATHSPIKE DONE grid")` and `quit(0)`. Any empty path for a pair: `push_error` and `quit(1)`.
- [ ] **Step 2:** Run once into `PW/logs/grid-try.log`. Expected: 1 `route_today`, 3 `build`, 3 `update`, 3 `search`, 3 `smooth`, 1 `group300` line, then `PATHSPIKE DONE grid`, `exit=0`, no `ERROR`.
- [ ] **Step 3:** Sanity: `search` `cells_p50` is at least 100; `smooth` `after_p50` is smaller than `before_p50`; `route_today` `cells_p50` is at least 50. If not, the pairs or the scale are wrong: stop and report.
- [ ] **Step 4:** Lint and warnings as in Task 1 Step 5 (`lint-2.log`, `warnings-2.log`).
- [ ] **Step 5:** Coordinator commits "Pathing spike: method A, finer grid".

### Task 3: Method B, rectangle navmesh

**Files:**
- Create: `game/benchmarks/pathspike/rect_mesh.gd`, `game/benchmarks/pathspike/run_mesh.gd`
- Modify: `game/benchmarks/pathspike/run_check.gd` (add cases)

**Interfaces:**
- Produces, in `rect_mesh.gd` (`extends RefCounted`):
  - `const TILE: int = 32`
  - `static func build_tile(solid: PackedByteArray, size: Vector2i, tile: Vector2i) -> Array[Rect2i]`
  - `static func build(solid: PackedByteArray, size: Vector2i) -> Dictionary` returning `{"rects": Array[Rect2i], "cell_rect": PackedInt32Array, "astar": AStar2D, "links": int}`
  - `static func link(rects: Array[Rect2i], cell_rect: PackedInt32Array, size: Vector2i) -> Dictionary` returning `{"astar": AStar2D, "links": int}` (used by `build`, and timed alone as the relink cost)
  - `static func path(mesh: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]`

Rules:
- `build_tile` covers the free cells of the tile `x0 = tile.x * TILE .. min(x0 + TILE, size.x) - 1` (same for `y`) with rectangles that never leave the tile. Row by row: find the maximal runs of free cells in the row; a run with the same start and end as a rectangle that ended in the row above extends that rectangle by one row; any other run starts a new rectangle. A `Rect2i` inside an array cannot be changed in place: read it, change it, write it back.
- `build` runs `build_tile` for every tile (rows of tiles top to bottom, tiles left to right), fills `cell_rect` (rectangle index per cell, -1 for blocked), then calls `link`.
- `link` adds one `AStar2D` point per rectangle (`add_point(index, Vector2(rect.position) + Vector2(rect.size) / 2.0)`), then for every rectangle looks at the cells just right of its right edge and just below its bottom edge; when such a cell belongs to another rectangle and the two are not connected yet (`are_points_connected`), `connect_points(a, b)` and count it.
- `path` returns `[from]`, then two cells for every pair of consecutive rectangles `A`, `B` on `astar.get_id_path(cell_rect[from], cell_rect[to])`, then `[to]`; empty when either cell is blocked or no path exists. The two cells are the crossing point: `A` and `B` share part of an edge; take the middle cell of the shared stretch (lower index when the stretch has an even length) on `A`'s side, then the cell next to it on `B`'s side. Example, `B` to the right of `A`: `y = (maxi(A.position.y, B.position.y) + mini(A.end.y, B.end.y) - 1) / 2` rounded down, cells `(A.end.x - 1, y)` then `(A.end.x, y)`. A rectangle is convex and free, so every straight piece of this path is clear. Never use rectangle centres: the line between two centres can cross a blocked cell.

`run_mesh.gd` prints these lines with `method=mesh`, same pairs and widths as Task 2:

| metric | What is timed | Fields |
|---|---|---|
| `build` | once per `W`: `RectMesh.build(solid_W, size)` | `width`, `ms`, `rects`, `links`, `mem_bytes` |
| `tile_rebuild` | once per `W`: after blocking the same 8x8 block as Task 2, `build_tile` for every tile the block grown by `W - 1` touches | `width`, `ms`, `tiles` |
| `relink_full` | once per `W`: `RectMesh.link(rects, cell_rect, size)` on the built mesh (upper bound for updating the graph after a building change) | `width`, `ms` |
| `search` | per pair: `RectMesh.path(mesh_W, from, to)` | `width`, `n p50 p95 max`, `rects_p50` (path size) |
| `smooth` | per pair: `Smooth.pull(solid_W, size, path)` | `width`, `n p50 p95 max`, `after_p50` |
| `length_ratio` | untimed: `path_length` of the straightened mesh path divided by `path_length` of the straightened grid path (`grid(solid_W, size, true)`) for the same pair | `width`, `p50`, `p95`, `max` |

Before timing, for each `W`, assert on Ashfall: the sum of rectangle areas equals the number of free cells in `solid_W`, and every free cell's `cell_rect` is 0 or more. On failure `push_error` and `quit(1)`.

- [ ] **Step 1: Add check cases to `run_check.gd`:**
  - `mesh_open`: 4x4 open map: `build` gives exactly 1 rectangle `Rect2i(0, 0, 4, 4)` and 0 links.
  - `mesh_hole`: 4x4 with `(1, 1)` blocked: the areas sum to 15, no rectangle contains `(1, 1)`, and `cell_rect` is -1 only at `(1, 1)`.
  - `mesh_tiles`: 40x8 open map: 2 rectangles (the tile border at `x = 32` splits it) and 1 link.
  - `mesh_path`: on `mesh_hole`, `path((0, 0), (3, 3))` starts with `(0, 0)`, ends with `(3, 3)`, every consecutive pair of it passes `clear_line`, and the same holds after `Smooth.pull`.
  - `mesh_blocked`: on `mesh_hole`, `path((1, 1), (3, 3))` is empty.
- [ ] **Step 2:** Run the check with `rect_mesh.gd` as stubs (`PW/logs/check-stub-3.log`). Expected: the five new cases fail, the 11 old ones pass.
- [ ] **Step 3:** Implement `rect_mesh.gd`; run the check (`PW/logs/check-3.log`). Expected: `PATHSPIKE CHECK PASSED 16`.
- [ ] **Step 4:** Write `run_mesh.gd` (warm-up pass, then timed passes, `PATHSPIKE DONE mesh`, `quit(0)`); run into `PW/logs/mesh-try.log`. Expected: 3 lines of each metric, `exit=0`, no `ERROR`.
- [ ] **Step 5:** Sanity: `length_ratio` `p50` is between 1.0 and 1.5. Outside that range: stop and report (the mesh path or the straightening is wrong).
- [ ] **Step 6:** Lint and warnings (`lint-3.log`, `warnings-3.log`); coordinator commits "Pathing spike: method B, rectangle navmesh".

### Task 4: Method C, flow fields

**Files:**
- Create: `game/benchmarks/pathspike/flow_field.gd`, `game/benchmarks/pathspike/run_flow.gd`
- Modify: `game/benchmarks/pathspike/run_check.gd` (add cases)

**Interfaces:**
- Produces, in `flow_field.gd` (`extends RefCounted`):
  - `const DX: Array[int] = [1, 0, -1, 0, 1, -1, -1, 1]` and `const DY: Array[int] = [0, 1, 0, -1, 1, 1, -1, -1]` (directions 0 to 3 straight, 4 to 7 diagonal)
  - `static func integrate(solid: PackedByteArray, size: Vector2i, goal: Vector2i, mask: PackedByteArray = PackedByteArray()) -> PackedInt32Array`: cost to the goal per cell, -1 when unreachable; a straight step costs 10 and a diagonal step 14 (Zero Hour's values, `AIPathfind.cpp:1673-1674`); a diagonal step is allowed only when both cells beside it are free; with a non-empty `mask`, cells whose mask byte is 0 are treated as blocked.
  - `static func directions(cost: PackedInt32Array, size: Vector2i) -> PackedByteArray`: per cell the direction index (0 to 7) of the neighbour with the lowest cost among those `integrate` could step to, the lowest index on ties, 255 for unreachable cells and for the goal.
  - `static func corridor(size: Vector2i, cells: Array[Vector2i], radius: int) -> PackedByteArray`: 1 for every cell within `radius` cells (in both x and y) of any cell in `cells`, else 0.

`integrate` uses a ring of 15 buckets (every step costs less than 15, so a cell with cost `c` sits in bucket `c % 15`). Use exactly this structure:

```gdscript
static func integrate(solid: PackedByteArray, size: Vector2i, goal: Vector2i, mask: PackedByteArray = PackedByteArray()) -> PackedInt32Array:
	var cost := PackedInt32Array()
	cost.resize(size.x * size.y)
	cost.fill(-1)
	var buckets: Array[PackedInt32Array] = []
	for i in range(15): buckets.append(PackedInt32Array())
	var masked: bool = not mask.is_empty()
	var start: int = goal.y * size.x + goal.x
	cost[start] = 0
	buckets[0].append(start)
	var pending: int = 1
	var current: int = 0
	while pending > 0:
		var slot: int = current % 15
		var bucket: PackedInt32Array = buckets[slot]
		if bucket.is_empty():
			current += 1
			continue
		buckets[slot] = PackedInt32Array()
		for index in bucket:
			pending -= 1
			if cost[index] != current: continue
			var y: int = floori(index / float(size.x))
			var x: int = index - y * size.x
			for d in range(8):
				var nx: int = x + DX[d]
				var ny: int = y + DY[d]
				if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y: continue
				var next: int = ny * size.x + nx
				if solid[next] != 0 or (masked and mask[next] == 0): continue
				if d >= 4 and (solid[y * size.x + nx] != 0 or solid[ny * size.x + x] != 0): continue
				var total: int = current + (14 if d >= 4 else 10)
				if cost[next] == -1 or total < cost[next]:
					cost[next] = total
					buckets[total % 15].append(next)
					pending += 1
	return cost
```

`run_flow.gd` prints these lines with `method=flow`. The goals are the `to` cells of the first 20 pairs; each distribution has `n = 20`.

| metric | What is timed | Fields |
|---|---|---|
| `field_full` | per goal and `W`: `integrate(solid_W, size, goal)` | `width`, `n p50 p95 max`, `cells_p50` (reachable cells) |
| `directions_full` | per goal and `W`: `directions(cost, size)` on that field | `width`, `n p50 p95 max` |
| `field_corridor` | per goal and `W`: `integrate(solid_W, size, goal, mask)` plus `directions`, where `mask = corridor(size, grid path of the pair, 16)` is built outside the timed region | `width`, `radius=16`, `n p50 p95 max`, `cells_p50` |
| `corridor_mask` | per goal, width 2: building the mask alone | `n p50 p95 max` |
| `lookup300` | once: 300 reads of `directions[...]` for the unit cells of Task 2's `group300` | `ms` |
| `memory` | computed, not timed: `size.x * size.y * 5` | `bytes_per_field` |

- [ ] **Step 1: Add check cases to `run_check.gd`:**
  - `flow_open`: 5x5 open map, goal `(0, 0)`: cost of `(4, 0)` is 40, of `(4, 4)` is 56, of `(1, 2)` is 24.
  - `flow_wall`: 5x5 with `(1, 0)`, `(1, 1)`, `(1, 2)`, `(1, 3)` blocked, goal `(0, 0)`: cost of `(2, 0)` is 100 (four steps down to `(2, 4)`, two left to `(0, 4)`, four up; no diagonal is allowed past the wall's end because `(1, 3)` is blocked), and cost of `(1, 1)` is -1.
  - `flow_corner`: 3x3 with `(1, 0)` blocked, goal `(0, 0)`: cost of `(1, 1)` is 20, not 14.
  - `flow_directions`: on `flow_open`, `directions` gives 6 at `(4, 4)` (towards `(3, 3)`), 2 at `(4, 0)`, 255 at `(0, 0)`.
  - `flow_mask`: on `flow_open` with `corridor(size, [(0,0), (1,0), (2,0), (3,0), (4,0)], 0)` as mask: cost of `(4, 0)` is 40 and cost of `(0, 1)` is -1.
  - `flow_follow`: on Ashfall width 2, for the first pair: starting at `from` and stepping by `directions` reaches `to` within `cost[from] / 10 + 1` steps.
- [ ] **Step 2:** Run the check with `flow_field.gd` as stubs (`check-stub-4.log`): the six new cases fail. Implement; run (`check-4.log`). Expected: `PATHSPIKE CHECK PASSED 22`.
- [ ] **Step 3:** Write `run_flow.gd`; run into `PW/logs/flow-try.log`. Expected: 3 `field_full`, 3 `directions_full`, 3 `field_corridor`, 1 `corridor_mask`, 1 `lookup300`, 1 `memory` line, `PATHSPIKE DONE flow`, `exit=0`.
- [ ] **Step 4:** Sanity: `field_full` `cells_p50` at width 1 is over 100,000; `field_corridor` `cells_p50` is well below `field_full`'s. Otherwise stop and report.
- [ ] **Step 5:** Lint and warnings (`lint-4.log`, `warnings-4.log`); coordinator commits "Pathing spike: method C, flow fields".

### Task 5: Measured runs and the table

**Files:** outside the repo only.

- [ ] **Step 1:** Write `PW/scripts/table.py` (standard library only): arguments are log files; it reads every `PATHSPIKE method=` line, groups by `method`, `metric` and `width` (blank when absent), and for each numeric field prints the median over the files and the spread (max minus min). Output is a Markdown table per method, written to stdout.
- [ ] **Step 2:** Run in this order, one at a time, each after the quiet check in Global Constraints, each with `uptime` written before and after: `run_check.gd` (`check-final.log`, must pass), then three rounds of `run_grid.gd`, `run_mesh.gd`, `run_flow.gd` (`grid-1.log`, `mesh-1.log`, `flow-1.log`, then `-2`, then `-3`).
- [ ] **Step 3:** `python3 -I PW/scripts/table.py PW/logs/grid-[123].log PW/logs/mesh-[123].log PW/logs/flow-[123].log > PW/results/table.md`.
- [ ] **Step 4:** If any timed field's spread is more than 20 % of its median, run that script three more times and rebuild the table from all six; say so in the note.

### Task 6: Evidence note, review, stop

**Files:**
- Create: `docs/reference/pathing-timing-spike.md` on `spike-pathing`

- [ ] **Step 1:** Write the note with these parts, in this order:
  1. Status line: "MEASURED, EVIDENCE ONLY. GDScript on the development Mac; no simulation change; no decision." plus the commit, the date and the load range.
  2. What was measured and how (map, scale 2, widths 1 to 3, 200 pairs, seed, three runs, the check script's result).
  3. One table per method from `PW/results/table.md`.
  4. A comparison table with one row per question and one column per method, filled only from measured lines:
     - one long route for a width-2 unit (search plus straightening, p50 and p95): `grid` `search` + `smooth`; `mesh` `search` + `smooth`; flow: `field_corridor` p50 and p95 (one field serves every unit with that goal);
     - a 300-unit order to one spot: `grid` `group300` `individual_ms` and `shared_ms`; mesh: 300 times its per-route p50; flow: one `field_corridor` plus `lookup300`;
     - placing one building: `grid` `update`; `mesh` `tile_rebuild` and `relink_full`; flow: every live field is rebuilt (`field_corridor` per field);
     - cost of unit size: the same rows at widths 1, 2 and 3, and the build and memory cost times the number of widths;
     - memory: `mem_bytes` and `bytes_per_field`;
     - path quality: `length_ratio` for the mesh; waypoint counts before and after straightening;
     - today's baseline: `route_today`.
  5. Each time also as "projected browser, x5.5", in a column marked as a projection.
  6. Context for reading the numbers, with sources: the 1.82 ms tick budget and today's movement row (`docs/reference/performance.md`), 8 route requests per tick (`simulation.gd:18`), Zero Hour's 5,000 searched cells per frame (`AIPathfind.cpp:1103`).
  7. What was not measured: any method inside the simulation, a real browser run, determinism across platforms (`AStarGrid2D` diagonal costs and `AStar2D` distances are floats inside the engine), a native core, real unit widths per kind, the Steam Deck.
  8. A recommendation labelled "a proposal; the user decides", and the open questions.
- [ ] **Step 2:** Fresh-context reviewer on the strongest available model: recompute every number in the note from `PW/logs`, read the three run scripts for the Review Focus items, and report errors separately from nits. Apply the fixes.
- [ ] **Step 3:** Coordinator commits "Pathing spike: evidence note" on `spike-pathing`, adds one line to `docs/session-notes.md` on `main` (state and where the note is), and stops. Committing on `main`, pushing, merging and choosing a method wait for the user.

## Stop conditions

A check case that cannot be made to pass; a sanity step outside its range; a run with an `ERROR` line; a machine that never gets quiet; any need to change a file under `game/scripts/` or `game/tests/`. Record what happened in `PW/results/blocked.txt` and stop; do not work around it.

## Not in this plan

Building any method into the simulation; mapping unit kinds to widths; shared group routes inside the simulation (avoidance round 4 measures a column slice); the path budget in searched cells per tick (proposed from this spike's numbers afterwards); a browser export; the native core; the movement milestone's design.
