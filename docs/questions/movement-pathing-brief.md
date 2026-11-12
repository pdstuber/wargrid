# Movement and pathing: brainstorm brief (2026-11-10)

Input and record of the movement brainstorm. It lists what is decided, how things work today, the options to compare, and where each question stands. Nothing here is decided unless it says so. Next step: the timing spike (question 9).

## Why

A playtester with competitive RTS experience said units "move strangely, probably because there is no 360° movement", and that the pathing grid looks as coarse as the building grid (user, 2026-11-10). Both points are true in the code (below). Unit avoidance depends on how units move, so this comes before the avoidance milestone.

## Decided (user, 2026-11-10; [design answers](../reference/design-answers-2026-11-08.md), "After round 3")

- Units path on a finer grid than buildings and drive at any angle, as Zero Hour does, "unless there is very good reason not to".
- Wargrid may use its own method, closer to what modern RTS games do, as long as it feels similar to Zero Hour.
- The brainstorm must investigate a navmesh and flow fields, not only a finer grid with smoothing.
- Unchanged: deterministic lockstep, the browser build as the main target, the performance budgets, the user's avoidance rules (rounds 1 to 4 of the avoidance spike, on branch `spike-avoidance`).

## How it works today

- One grid for everything: buildings, terrain and unit routes use the same cells. One cell is 25 Zero Hour world units, about one vehicle wide ([verification](../reference/zero-hour-verification.md)). Maps are 48x32 (test skirmish) to 194x187 (Ashfall) cells.
- Routes: Godot's `AStarGrid2D`, four directions only, no diagonals, Manhattan heuristic (`game/scripts/simulation/grid_navigation.gd:19-24`). A route is a list of cell centres, so a diagonal trip is a staircase.
- Units are points that move along those waypoints; today they pass through each other in transit and each has its own reserved goal cell (`destination_allocation.gd`).
- At most 8 route requests are served per tick (`simulation.gd:18`), so 300 units need about 38 ticks before all move.
- Six simulation files use the navigation (`simulation.gd`, `combat.gd`, `construction.gd`, `containers.gd`, `production.gd`, `supply_collection.gd`): every change reaches combat chasing, building placement, transports and harvesters.
- Budget: sim tick p95 1.82 ms with 300 units moving, on the development Mac; the browser is about 5.5x slower ([performance ledger](../reference/performance.md)). Today's movement row: 0.69 to 0.71 ms.
- Determinism: no trigonometry in the simulation; `Vector2` is 32-bit and rounds, GDScript floats are 64-bit ([determinism rules plan](../superpowers/plans/2026-11-09-determinism-rules-note.md), not yet written up).

## What Zero Hour does (source read 2026-11-10, EA source `0a05454`)

- Paths on cells of 10 world units (`AIPathfind.h:439`), finer than Wargrid's 25, with 8 directions at integer costs 10 and 14 (`AIPathfind.cpp:1673-1674`), then straightens the path with a line-of-sight pass so units drive at any angle (`Path::optimize`, `AIPathfind.cpp:474`).
- Caps pathfinding work at 5,000 searched cells per frame, not at a number of routes (`AIPathfind.cpp:1103`).
- A group of at least 3 infantry or 3 vehicles moving at least 100 world units (4 Wargrid cells) shares one route (`AIGroup.cpp:601`, `:638`; retail `aidata.ini:47-49`).
- Units are physical objects with a radius; the cell grid holds goal reservations and blocking marks, not unit positions. Details and citations: `~/projects/wargrid-overnight-work/avoidance/brainstorm/research.md` (outside the repo).

## Options to compare

| | How it works | Strong at | Weak at, or unknown |
|---|---|---|---|
| A. Finer grid plus smoothing | A* on smaller cells (for example 2x2 or 3x3 per building cell, 8 directions), then remove waypoints with a line-of-sight check or use an any-angle search (Theta*) | Closest to Zero Hour; fits today's code; deterministic with integer cells | 4x to 9x more cells: path cost and memory on large maps; smoothing cost per route |
| B. Navmesh | Walkable area as polygons; a path runs corner to corner (funnel algorithm), naturally at any angle | Few nodes, short searches, smooth paths; what many modern games use | Rebuilding the mesh when a building is placed or dies; determinism of Godot's `NavigationServer2D` unverified (likely not lockstep-safe); unit radius handling |
| C. Flow fields | One field per destination: every cell points toward the goal; all units with that goal read it | Very cheap per unit for big group orders and columns; no per-unit route | One field per distinct destination (many small orders cost memory and build time); still needs a grid; fine detail near the goal |
| D. Hybrid | Coarse search (today's grid or a navmesh) for the corridor, fine local movement inside it, or flow fields only for big groups | Can keep cost low where it matters | More code paths to test and keep deterministic |

### Research findings (Opus research agent, 2026-11-10; code reading and web sources, nothing run or measured)

Full notes with citations: `~/projects/wargrid-overnight-work/movement/research-navmesh-flowfields.md` (outside the repo). Cost figures are estimates from one measured flood fill (about 0.7 µs per cell on the development Mac).

- **A fits best.** It is exactly Zero Hour's method. Lockstep games OpenRA and 0 A.D. are grid-based too. The search stays in Godot's C++ `AStarGrid2D`; only the smoothing is new GDScript.
- **2x2 per building cell first.** Close to Zero Hour (12.5 against 10 units), and waypoint centres stay exact numbers; 3x3 brings rounding into waypoints. Connectivity and goal cells can stay on the building grid, because every blocker is building-cell sized.
- **B: Godot's `NavigationServer2D` is not safe for lockstep.** Changes apply "after the next physics frame", on a background thread by default, while the threadless browser build applies them differently; its geometry is 32-bit and its docs promise no determinism. A hand-written rectangle mesh (like Recoil's quadtree, QTPFS) could be deterministic but is much more GDScript. StarCraft II's navmesh is known only from secondary summaries; no primary slides or developer text were found.
- **C: flow fields are expensive in GDScript.** Supreme Commander 2 builds them only for 10x10 sectors along an A* corridor, caches them and rebuilds dirty sectors over time (Game AI Pro, chapter 23); its units push each other with physics, which we rejected. Estimate for Wargrid: 45 to 55 ms in the browser per distinct goal on Ashfall (corridor only, several ticks), over a second for a whole-map field. Fields lead to one goal, while Wargrid gives every unit its own goal cell, so the last stretch still needs per-unit steering. Recoil has no goal flow field (its `PathFlowMap` is a congestion map).
- **Shared group routes give most of a flow field's saving with A**, and build on avoidance round 4's column slice.
- **Determinism with diagonals:** path costs stop being whole numbers. Godot compiles with strict float rules on every desktop target, so results should match, but a native-against-browser trace check must prove it.
- **Proposal (the agent's, not decided):** A at 2x2 with Zero Hour-style smoothing and shared group routes; B or C only as a later hybrid if A's measured cost fails.

Not considered: Recoil-style soft pushing as the movement model (rejected for GDScript cost in the avoidance brainstorm); any method that needs threads (the browser build runs without them).

## Questions and answers (wizard run 2026-11-10)

Answers are recorded in the [design answers](../reference/design-answers-2026-11-08.md#movement-and-pathing-user-2026-11-10); this list only says where each question stands.

1. Base method (A, B or C): **not chosen; measure all three first** (user).
2. Grid size: **2x2 per building cell** (user).
3. Look while driving: no decision needed; per-kind turn rates and rolling turns already exist (`locomotion.gd`). Feel: **Zero Hour's weight, not snappier** (user).
4. Unit size decides where it fits: **a few size classes, Recoil-style** (user, revised the same day from "per unit kind"; one pathing layer per class).
5. Group moves, flow field or shared route: open; waits for the round 4 column feel session and the timing spike.
6. Order of work: **movement first, as its own milestone before avoidance** (user).
7. Path budget in searched cells per tick: proposed, measured in the spike.
8. Map cap 256 to 512 cells per side: needed for 2x2 on Ashfall; proposed, measured in the spike.
9. Measured cost: **timing spike right after avoidance round 4**, scratch scripts on Ashfall for all three methods at 2x2, every row labelled as a GDScript cost and re-read after the native simulation core spike (user).

Still missing: primary sources for StarCraft II and Planetary Annihilation.

## How to run it

One question at a time, Zero Hour's behaviour and a recommendation with each ([question rules](README.md)); record every answer in the design answers at once. A research step (read-only, cite file:line) before the first question; a measured spike before any choice is final.
