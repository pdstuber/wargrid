# Performance ledger

Status: **TARGET-DERIVED BUDGETS PROPOSED; TWO OF FOUR CURRENTLY EXCEEDED; EXISTING GATES UNCHANGED**. One place to track performance across milestones for a low-end target, including a browser (WebAssembly) build. Measurements on this Mac are weak evidence for that target; this note makes the assumption explicit and replaceable.

## Target device (assumption, not measured)

- **Slowdown factor F = 6** relative to the development machine (Apple M6, 12 cores). This is a chosen planning number, not a measurement. Replace it with the factor from a real web export under Chrome CPU throttling or on real low-end hardware as soon as one exists; every derived budget below is `target budget ÷ F`. I have no data on how GDScript performs under WebAssembly, and render/GPU slowdown need not equal CPU slowdown.
- Simulation 30 Hz: a tick is 33.3 ms. Render goal 60 fps: 16.7 ms.

## Budgets

Existing gates (unchanged, in `game/benchmarks/run_movement.gd` and the rendered probe): sim-only tick p95 ≤ 8 ms and p99 ≤ 16 ms on the development machine; rendered frame p95 ≤ 16.7 ms. The sim gate is about 5× looser than the current cost, so it does not protect a low-end target.

| Metric | Share chosen on target | Target budget | Dev-machine budget (÷F) | Current (dev machine) | Status |
|---|---|---:|---:|---:|---|
| Sim-only tick p95 (300 units moving, includes command allocation) | 30% of a tick | 10 ms | 1.67 ms | 1.50 open / 1.53 dense | passes, about 9–10% margin (headless benchmark 2026-11-03) |
| Sim-only tick p99 | 60% of a tick | 20 ms | 3.3 ms | 1.57 / 1.60 | passes |
| Presentation plumbing per tick (`snapshot` + view deep copy + sort) | 15% of a tick | 5 ms | 0.83 ms | about 1.9 ms (0.69 + 0.67 + 0.57, scratch probe, not a repo tool yet); snapshot size is gated by node count below | **exceeded** |
| Rendered frame interval p95 (300 units, vsync off, includes tick frames) | full frame | 16.7 ms | 2.8 ms | 4.1 open / 6.5 dense | **exceeded** |

Watch items, no gate: worst sim tick 7.8 ms on the dev machine (command ticks, path queue burst), which would be about 47 ms on the target, longer than a tick. Dense-map worst rendered frame 19.5 ms.

Derived budgets are proposals. Do not loosen a budget or the factor to make a row pass; either optimize, or ask the user to change the target. M4 snapshots add combat fields, so plumbing will grow; the cheapest fix is probably to stop copying the whole state twice per tick (not designed).

## History

All rows: this Mac, Godot 4.7.2, Compatibility renderer, 64×64 map, 300 units, unpaced headless unless noted. Sources are the linked notes; scratch logs are outside the repo.

| When / milestone | Metric | Open | Dense | Source |
|---|---|---|---|---|
| M3 final (before `303006b`) | sim-only tick p50 / p95 / p99 / max (ms) | 0.950 / 1.452 / 1.495 / 7.803 | — / 1.487 / 1.548 / 7.789 | [M3 verification](m3-verification.md) |
| 2026-11-03 before terrain fix | rendered frame p95; frames in 60 s; backlog | 320 ms; 205; growing (140 ticks) | 340 ms; 189; growing (244 ticks) | [M2 verification](m2-verification.md) |
| 2026-11-03 terrain fix, vsync on | rendered frame p95; backlog | 19.6 ms; none | 19.5 ms; none | same |
| 2026-11-03 terrain fix, vsync off (benchmark disables it) | rendered frame p50 / p95 / p99 / max (ms) | 1.2 / 4.1 / 6.4 / 13.1 | 1.6 / 6.5 / 10.2 / 19.5 | same |
| 2026-11-03 headless benchmark after terrain/speed changes | sim-only tick p50 / p95 / p99 / max (ms) | 0.979 / 1.500 / 1.573 / 8.031 | 1.007 / 1.526 / 1.601 / 8.058 | `sh tools/run_benchmark.sh`, `BUDGET PASS` both |
| 2026-11-03 same run | in-scene tick p95 (step + plumbing + label) | 4.56 ms | 4.79 ms | same |
| 2026-11-03 scratch headless probe | step / snapshot / view copy / sort p50 | 0.32 / 0.69 / 0.67 / 0.57 ms | 0.33 / 0.72 / 0.68 / 0.58 ms | same |

M4 rows pending; see the combat benchmark in the [M4 plan](../superpowers/plans/2026-11-03-m4-combat.md) Task9a.

## Rule per milestone

A milestone exit gate is not met until: `sh tools/run_benchmark.sh` passes, the rendered benchmark was rerun if presentation changed (`sh tools/run_game.sh res://scenes/movement_benchmark.tscn`, header must show `vsync=off`), and this ledger has a new History row with measured values against the budget table, with the machine named. Missing or exceeded rows are reported as exceeded, never as passed.

## Machine-independent counters

Wall-clock numbers vary with hardware; these do not, so they can gate in ordinary headless tests.

| Counter | Where | Current | State |
|---|---|---|---|
| Snapshot size in nodes (each dictionary key, value and array element counts 1) for the 300-unit workload at its peak, 38 steps into leg 0 | `test_snapshot_size_ceiling` in `test_benchmark.gd` | open 79,481; dense 80,345 (peak, after 38 steps); busiest unit 322 | **gated ceiling.** The snapshot is deep-copied twice per tick, so growth is plumbing cost. A change that adds fields fails the test; raise the ceiling deliberately and add a History row. M4's added unit fields will trip it by design (Task1). |
| Path queue peak and drain after a 300-unit group command | printed by both benchmarks | peak 292, drain 38 ticks | reported, not gated beyond the existing 3000-tick leg limit and the 8-queries-per-tick cap |
| Engine draw calls per rendered frame (`RENDER_TOTAL_DRAW_CALLS_IN_FRAME`) | `movement_benchmark.gd` `RENDERED SAMPLE ... draw_calls` | earlier scratch probe: about 601 | added 2026-11-03, **no rendered run yet with the benchmark print**; renderer batching dependent, so only comparable on one renderer |
| Combat target checks per tick | planned in M4 Task9a | — | not implemented |

Not feasible or not done:

- **Canvas commands per frame, in tests.** No headless API reports them (the dummy renderer reports zero draw calls) and `draw_*` methods cannot be overridden to count. The terrain regression is covered by the rendered benchmark instead.
- **A\* node expansions.** Navigation uses Godot's built-in `AStarGrid2D.get_id_path`, which exposes no work counter; counting would mean reimplementing it. The 8-queries-per-tick cap plus the queue figures above are the available proxies. Worst command-tick spike (7.8 ms on the dev machine) is probably this work, unproven.

## Not covered yet

CI does not run any benchmark; trend logging on the Linux/Windows/macOS runners (slower than the dev machine) is a candidate. A web export under CPU throttling would replace F with a measurement.
