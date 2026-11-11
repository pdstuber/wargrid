# Native sim spike: movement slice

Status: written by T6 of the [native sim spike plan](../superpowers/plans/2026-11-10-native-sim-spike.md) on 2026-11-10, tree `spike-native-sim-t6`. Follows the [boundary note](native-sim-spike-boundary.md). Labels: **measured**, **source** (file:line read), **inferred**, **unverified**. The slice is a probe of float-heavy code; the movement milestone will rewrite `_advance`, so this code is not meant to survive.

## What the slice covers

The movement loop of `Simulation.step()` (`simulation.gd:552-556`): for every id, `_advance(unit)` when `status == "moving"` (`simulation.gd:602-628` with `Locomotion.step`, `locomotion.gd`), else `speed = 0.0` unless `status == "path_pending"`.

- **Rust** (`native/core/src/movement.rs`): `Locomotion.step` (air snap, turn, wheel turn, `angle_between`, `heading_factor`, `move_after`, braking, acceleration) and the route walk of `_advance`.
- **GDScript, every mode** (`native_move.gd`): selecting the rows, the non-moving branch (`speed = 0.0`, done in `apply` from the list `pack` keeps), and on arrival `Containers.entering` / `order = null` / `status = "arrived"`.

## Routes: a bounded prefix with a fallback

Each tick `pack` sends the first `PREFIX` = 4 waypoints of each route and the route's full length. The kernel reads waypoints through one accessor; asking for index `j` with `count <= j < length` stops that row and returns it with flag `FALLBACK` and zeros. `apply` runs GDScript's `sim._advance(unit)` for such a row, so a too-short prefix costs time, never correctness: the rows the kernel answers are exact, the others are GDScript's. No native state, so nothing can go stale and a fixture replays without history.

Why a short prefix is normally enough (inferred, measured below): the kernel reads route[0] (`_desired`), then `_route_length_until` stops at the first waypoint where the summed length reaches both the braking distance at full speed (`cap² / 2 brake`, at most 3.24 cells, `frc_light_vehicle`) and one step (`cap / 30`); the walk of `_advance` reads no further than one waypoint past the step length, except through the `1e-5` tolerance on chains of near-duplicate waypoints. Measured over 2100 shadow ticks of `move_open`, `move_dense` and `hordes300`: routes up to 99 waypoints, at most 1 waypoint consumed per tick, and **0 fallbacks with a prefix of 2, 3, 4 or 8**. 4 keeps two waypoints of margin over the measured minimum at half the packing of 8; a map with denser waypoints or faster wheels may fall back more, which costs time only. The slice instance's `fallbacks` counter is not in the `SLICE` line (the bridge format is fixed); read it as `NativeBridge._parts.move.slice.fallbacks` in a scratch run.

In `shadow` the expected row for a fallback row is the fallback row itself (GDScript cannot know which waypoint the kernel would have read), so those rows are covered by the digests, not by the field comparison. Their count is reported (0 so far).

## Buffers

Rows: the moving units in ascending id order (the loop order). Per-row buffers have `n` elements.

| # | Input | Type | Per |
|---|---|---|---|
| 0 | entity id | I64 | row |
| 1 | kind index into buffer 13 | I32 | row |
| 2, 3 | position x, y | F64 | row |
| 4, 5 | heading x, y | F64 | row |
| 6 | speed | F64 | row |
| 7 | `move_after` | I64 | row |
| 8 | waypoints sent (`min(route.size(), 4)`) | I32 | row |
| 9 | full route length | I32 | row |
| 10, 11 | waypoint x, y, the rows' prefixes back to back | F64 | waypoint |
| 12 | `sim.tick()` | I64 | 1 |
| 13 | kind table, 7 columns per kind: `speed`, locomotor (0 other, 1 wheels, 2 air), `accel`, `brake`, `turn_cos`, `turn_sin`, `min_turn_speed` (absent keys 0.0, never read for that locomotor) | F64 | kind |

The kind index is assigned once per slice instance from the sorted `Registry.units()`; a kind added later (test kinds) is appended. The table (about 20 kinds) travels every tick as the same cached `PackedFloat64Array`; it is not native state.

| # | Output | Type |
|---|---|---|
| 0, 1 | new position x, y | F64 |
| 2, 3 | new heading x, y (float32 values widened) | F64 |
| 4 | new speed (0.0 on arrival) | F64 |
| 5 | waypoints consumed | I32 |
| 6 | flags: 1 arrived, 2 fallback | U8 |

`apply` per row: fallback → `sim._advance(unit)`; else heading written as a new array only when a component differs (`!=`), `speed` and `position` (a new array, as `_advance` does) always, `route = route.slice(consumed)` when `consumed > 0` (a new array, the waypoint arrays stay shared), and on arrival the GDScript order rule and `status = "arrived"`. Then the non-moving ids get `speed = 0.0`.

`run_pass` validates the same inputs and copies position, heading and speed into the seven output buffers (consumed and flags zero) through the same generic copying path as `run`, so `call - call_pass` is the kernel.

Rejected input: wrong buffer count or type, a per-row length that is not `n`, a negative count or one above the length, waypoint buffers that do not sum to the counts, a kind index out of the table, a table not a multiple of 7, an unknown locomotor code: error, no output.

## Number audit

| Site (source) | GDScript | Rust |
|---|---|---|
| `_desired` `dx / length` (`locomotion.gd:72-74`) | float64 `sqrt` and divide, then `Vector2(...)` rounds each to float32 | `f64` ops, `as f32` (round to nearest) |
| `desired != Vector2.ZERO` (`:14, 78`) | `Vector2::operator!=`, float32 compare (`vector2.h:271`) | `f32` compare |
| `desired.x != heading_x` (`:14`) | float32 widened to float64 against float64 | `d.0 as f64 != hx` |
| `Vector2(heading_x, heading_y)` (`:16`) | float64 heading rounded to float32 | `as f32` |
| `angle_between` (`:38-49`) | `.x` widened, all float64, `absf`, `maxf`, `minf`, polynomial in literal order | same order, `abs`, `maxf`/`minf` as below |
| `heading_factor` (`:58-63`) | float64 | same |
| `turn` dot and cross (`:52-53`) | widened float64 | same |
| `turn` `Vector2(hx c - s·hy·t, s·hx·t + hy c)` (`:54`) | float64 left to right (`(sign*hy)*sin`), rounded to float32 | same order, `as f32` |
| `turned / sqrt(...)` (`:55`) | `sqrt` float64 of widened components; `Vector2::operator/(real_t)` (`vector2.h:254`, `real_t` is `float`, `math_defs.h:146`), so the divisor is narrowed to float32 and each component divided in float32 (measured: dividing in float64 instead breaks the `move-open` replay at tick 328, heading x off by one float32 ulp) | `n as f32`, then `f32` divide |
| `_wheel_turn` (`:34-37`) | float64, `sqrt(1 - s²)` float64 | same |
| `heading = [turned.x, turned.y]` (`:22, 78`) | float32 widened, stored as float64 | `as f64` |
| `_route_length_until`, braking, `minf` chain, route walk (`:25-31, 83-97`, `simulation.gd:603-628`) | float64, `sqrt` only, `2.0 * brake * remaining` left to right | same, no `mul_add` (Rust never contracts without it) |
| `minf`, `maxf` | `MIN(a, b)` = `a < b ? a : b`, `MAX` = `a > b ? a : b` (inferred from Godot's `typedefs.h`, not in the local refs) | `if a < b {a} else {b}`, `if a > b {a} else {b}` |
| `tick < move_after` | int64 | `i64` |
| int/float conversions | none in the slice (counts are ints, all maths float) | none |
| overflow, shifts | none | none |
| NaN | unreachable: every divisor is a `sqrt` of a sum of squares checked `>= 1e-9` (`_desired`), `> 0` (`turn`: a normalised vector rotated), `max(...) > 0` (`heading_factor`, `_wheel_turn`: kind speeds are positive), or `distance > remaining + 1e-5 >= 1e-5` (walk) | same |
| signed zero | a heading component is `-0.0` only if `dx / length` rounds to `-0.0` in float32 (`|dx| / length < 1.4e-45`); positions differ by at least an ulp of ~1e-15, so unreachable (inferred). `apply`'s `!=` would treat it as equal; the shadow compare is by bits and would report it | bits |
| literals | GDScript parses them with its own `String::to_float`; all 17 slice literals equal bit for bit to correctly rounded parsing (measured, Python `struct.pack` against GDScript's bytes) | Rust literals |
| iteration order | ascending id; rows independent (`_advance` touches only its unit) | row order |
| ties | `distance <= remaining + 1e-5`, `>= cos_step`, `cross < 0.0`, `y > x`, `dot < 0.0`, `angle <= 9.0` exactly as written | same |

## Coverage

- Workloads (measured, Mac, 2100 ticks): `move_open` and `move_dense` move only wheels (`usa_light_vehicle`), `hordes300` only legs and treads; none passes two waypoints in one tick and none flies.
- So air, several waypoints per tick, the arrival tolerance, zero-length steps, an empty route and a short prefix are covered by the Rust unit tests, and air, wheels from standstill, treads, entering a container on arrival and a stop at speed (the non-moving branch) by `test_native_move.gd` scenarios (shadow, native and pass, digest every tick).

## Results

See `~/projects/wargrid-native-work/rows/t6.md` (copied into the verification file by T9).
