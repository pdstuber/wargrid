# Native sim spike: horde slice

Status: written by T5 of the [native sim spike plan](../superpowers/plans/2026-11-10-native-sim-spike.md) on 2026-11-10, tree `spike-native-sim-t5`. Rules of the boundary: [boundary note](native-sim-spike-boundary.md). Source: `game/scripts/simulation/horde.gd:15-101`, `combat.gd:24,59,560`. Code: `native/core/src/horde.rs`, `native/godot/src/horde.rs`, `game/scripts/simulation/native_horde.gd`.

## Input buffers (`WargridHorde.run(inputs)`, 12 buffers)

Rows are the armed entities with `combat.horde`, in `armed` order (ascending id). Entities absent from `_entities` are skipped.

| # | Type | Content |
|---|---|---|
| 0 | I64 | entity id |
| 1, 2 | F64 | position x, y (float64, as stored) |
| 3 | I32 | kind index into the kind table |
| 4 | I32 | owner |
| 5 | I32 | team of the owner (`sim.team_of`, 0 = unknown player, hostile to all) |
| 6 | U8 | 1 when `container_id` is set |
| 7 | I64 | `combat.horde_tick` |
| 8 | U8 | `combat.horde` (level 0, 1, 2) before the pass |
| 9 | I64 | one element: `sim._tick` |
| 10 | F64 | kind table: per kind rule radius, combat radius |
| 11 | I32 | kind table: per kind count, match (0 kind, 1 class), class index, re-check rate in ticks |

Kind table: every unit kind with a `horde` rule, sorted by name; class index from the sorted class names. It is static definition data, so buffers 10 and 11 are sent on the first successful call of a slice instance and empty afterwards. The core keeps the table (the only native state of this slice) and replaces it when a call carries a new one. The GDScript side resends it only if a member's kind is missing from the index (a test kind added later). Any error before the first success keeps it resending. A call with rows and no table is refused.

## Output buffers (due units only, in row order)

| # | Type | Content |
|---|---|---|
| 0 | I32 | input row of the due unit |
| 1 | U8 | new level |
| 2 | I64 | new `horde_tick` (tick + rate) |
| 3 | U8 | 1 when "has a bonus" (level above 0) changed |

A unit is due when `horde_tick <= tick` and it is not contained. `apply` writes tick and level, calls `Combat.restart_wait` in the same unit order for flagged units, and adds the number of due units to `sim._horde_checks`. The kernel updates its own level column in place in row order, so a unit sees the levels earlier due units got in the same pass (fixture case in `horde.rs` `earlier_level_is_visible_to_later_unit`, both orders). `run_pass` runs the same conversions and returns zeroed buffers of these shapes (it counts due rows to size them).

## Number audit (handoff Stage 5, items that apply)

- No `Vector2` in this slice: nothing is rounded to float32; positions stay float64 end to end.
- Cell key: `floori(px / size)` is `floor` of a float64 quotient; GDScript stores it in a `Vector2i` (int32), the core casts with `as i32` (saturates where GDScript wraps; unreachable for map-sized coordinates, **inferred**). Cell size `widest + 2 * largest` over the member kinds only, plain `max`.
- Distance: `sqrt(ox*ox + oy*oy) - ra - rb`, then clamp at 0 (`maxf(0, ...)`), compared with `>` against the rule radius; same operation order, float64 `sqrt`, no `mul_add`.
- Neighbour test order does not change the result (count and the "any level-2 neighbour" OR are order free; the early return fires only at level 2).
- Integer fields: ids and ticks I64, `Vector2i` neighbour offsets wrap.

## Evidence

Rows in the run's `rows/t5.md` and, after T9, the verification file.
