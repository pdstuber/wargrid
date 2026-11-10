# Native sim spike: boundary note

Status: written by T2 of the [native sim spike plan](../superpowers/plans/2026-11-10-native-sim-spike.md) on 2026-11-10, tree `spike-native-sim-t2` (base 0570f6a). Describes the skeleton; the slice tasks (T5 horde, T6 movement) fill the buffer layouts in their own notes, `native-sim-spike-slice-horde.md` and `native-sim-spike-slice-move.md`, and must keep the rules below. Labels as in the other reference notes: **measured**, **source** (file:line read), **inferred**, **unverified**. Spec: [handoff](../native-sim-spike-prompt.txt) Stage 1 (paper part) and Stage 4.

## Layers

| Layer | Files | Owns |
|---|---|---|
| Core (no engine) | `native/core/` crate `wargrid_core`, no dependencies (`cargo tree -p wargrid_core` prints only itself, measured) | the slice rules; `Buffer` (one flat column), `Slice` trait, `first_difference`, fixture reader and writer |
| Godot adapter | `native/godot/` crate `wargrid_native` (cdylib): `WargridHorde`, `WargridMovement`, `WargridProbe` | conversion between packed arrays and core buffers, instance lifetime, error text |
| Standalone caller | `native/runner/` binary `wargrid_runner` (depends on the core only) | `replay <file>`: bit-for-bit check of recorded fixtures; `bench <file> <repeats>`: kernel time alone |
| GDScript bridge | `game/scripts/native/native_bridge.gd` | mode, lazy loading, timers, shadow comparison, fixture recording, `SLICE` lines; reads the clock, so it lives outside `scripts/simulation/` |
| GDScript slices | `game/scripts/simulation/native_horde.gd`, `native_move.gd` | packing, applying and comparing one slice; may read `sim._entities`; no clock |
| Hook | `simulation.gd` `static var native` (null by default), checked once around the movement loop and once at the `Horde.step` call | nothing; null runs the original lines |

`Simulation.native` is spike plumbing, not interface ([sim interface](sim-interface.md) is unchanged); only the bridge sets it.

## Modes and the hook

`NativeBridge.configure(mode, slices, timing = false, record = "") -> {ok, error}`. Any error leaves the bridge `off` with `Simulation.native == null`: an unknown mode or slice, no slice, a slice script that does not load, `record` outside `shadow`, an unwritable fixture path, or (any mode but `off`) a missing extension class (`extension missing: class WargridHorde not loaded`). `configure("off")` is the reset; tests that change the mode end with it.

- `off` without `timing`: the hook stays null. The only cost on the default path is the two null checks (source: the hook lines in `simulation.gd` `step()`).
- `off` with `timing`: the hook runs the slice's `step_gd` (a copy of the original lines) and times it as `gd`. Same game: `test_native_move.gd` `test_timed_off_keeps_digests` compares every tick's digest for 90 ticks (measured green).
- `shadow`: pack, native call, `step_gd`, then `compare`. GDScript decides; the native result is never applied.
- `native`: pack, native call, `apply`. A failed call (empty result) records the error and runs `step_gd` for that tick, so the game goes on and the `SLICE` line shows `mismatch=error ...`.
- `pass`: pack, `call_pass` (the adapter copies the inputs into output-sized buffers, no work), then `step_gd`. Its digests equal `off`.

The hook returns false for a slice that is not selected, and `simulation.gd` then runs its own lines, so `slices=horde` leaves movement on the original code.

Timers (microseconds, summed over the window the caller samples; `reset_report()` clears): `gd` around `step_gd` in every mode where it runs; `pack`, `call` (`call_native` or `call_pass`), `apply` in the native modes; `calls`, `entities` (size of buffer 0), `in_bytes`, `out_bytes` always. The caller times `sim.step()` and passes it to `record_tick(usec)`, which gives `ticks` and `tick_sum`. `slice_lines(row)` prints the plan's `SLICE` line; `mismatch=` carries the first shadow mismatch, else `error <text>`, else `none`.

## Slice interface

GDScript slice script (instance per `configure`, so it may hold state):

| Method | Contract |
|---|---|
| `step_gd(sim, ids)` | today's GDScript lines for the slice, unchanged; `ids` is the hook's list (`ids` for movement, `armed` for horde) |
| `pack(sim, ids) -> Array` | input buffers (packed arrays) for this tick |
| `call_native(core, inputs) -> Array` | `core.run(inputs)`; empty means error (the plan's `call`; `call` itself is `Object.call`) |
| `call_pass(core, inputs) -> Array` | `core.run_pass(inputs)` |
| `apply(sim, inputs, outputs)` | write the outputs into the entities |
| `compare(sim, inputs, outputs) -> {mismatch, expected}` | after `step_gd`: `expected` are GDScript's outputs packed like the native ones (recorded into fixtures), `mismatch` the first difference as `entity=<id> field=<name> gd=<value> native=<value>` with floats compared by bits, `""` when equal; must accept empty `outputs` |

Adapter class (one per slice): `run(inputs: Array) -> Array`, `run_pass(inputs: Array) -> Array`, `last_error() -> String`. The skeleton's `run` goes through the generic copying path (`lib.rs` `run_generic`: every packed array copied into a core `Buffer`, outputs copied back). A slice may replace it with a borrowing path (`as_slice()` on the packed array during the call) as long as `run_pass` does the same conversion work, so that `call - call_pass` is the kernel.

## Conventions every slice follows

**Ownership.** GDScript owns every entity; the native side owns no game state. Each tick the slice packs what it reads from `sim._entities` and applies what it writes. A native cache (for example routes handed over once) is allowed only if the slice note names it, says what refreshes it, and the digests and fixtures prove it; anything a cache holds is stale as soon as another system writes that field (routes: `_assign_route`, repaths, chases, containers).

**Buffer types.** Packed array to core buffer, with the fixture tag: `PackedByteArray` = `U8` (1), `PackedInt32Array` = `I32` (2), `PackedInt64Array` = `I64` (3), `PackedFloat32Array` = `F32` (4), `PackedFloat64Array` = `F64` (5). Every GDScript `float` travels as `F64` (GDScript floats are binary64; positions, speed and heading are stored as float64 even where their value was rounded through a `Vector2`). `F32` only where the core must reproduce a `Vector2` rounding and the slice note says so. Ids and ticks are `I64` (GDScript `int`); small enums, flags and kind indices may be `I32` or `U8`.

**Rows.** Structure of arrays: one buffer per field, row `i` of every per-entity buffer is the same entity. Buffer 0 is always the entity ids (`I64`), rows in the order the GDScript loop visits them (ascending id: `step()` sorts `ids`, and `armed` keeps that order; source `simulation.gd:517-522`). Order matters where a later row reads an earlier row's result in the same pass (horde levels, below). Per-kind or per-player parameters go in separate table buffers indexed by a small index the slice assigns (sorted kind names, so the index does not depend on spawn order).

**Ids, removal, reuse.** Ids come from `_next_entity_id`, which only grows (source `simulation.gd:84-86`; it is in the snapshot as `next_entity_id`), so an id is never reused within a match and a native cache keyed by id cannot alias a new unit. An entity that is gone is simply absent from buffer 0; the slice packs only ids still in `sim._entities` (`Horde.step` already skips removed ids, `horde.gd:18`). Neither slice removes or creates entities. `Containers.step` runs between the two slices and can hide units (`container_id`), so the horde slice packs after it, as today.

**Rejected input.** The core checks tags, lengths and every index read from an input before any work; on failure it returns an error, writes no output and changes no state. The adapter turns the error into an empty array plus `last_error()`; the bridge keeps the first error per slice and runs GDScript for that tick. No partial result is ever applied.

**Allocation and lifetime.** Input arrays belong to Godot (reference-counted, copy-on-write); the adapter reads them only during the call and never keeps a pointer or a packed array past it. Outputs are allocated by Rust and moved into fresh Godot packed arrays, which Godot then owns and frees. Rust may keep its own scratch vectors between calls; it never holds a Godot array.

**WASM memory growth.** Godot and the side module share one linear memory; `memory.grow` keeps every address valid inside WASM and only detaches JavaScript views of the old buffer (inferred from the WebAssembly memory model; no JavaScript touches these buffers in this design). Since nothing is held across a call, growth while a buffer is in use cannot leave a dangling pointer here. A probe that allocates during a call is T7's (unverified until then).

**No panic across the boundary.** Core functions return `Result`; slices validate before indexing. gdext wraps `#[func]` calls and reports a panic as a Godot error on desktop (unverified for 0.5.5); on the web build (`-enable-emscripten-cxx-exceptions=0`, `emscripten-wasm-eh=false`) a panic is expected to abort the module (inferred, T7 measures). Either way a panic is a bug, never an error path.

**Numbers.** Floats compared by bits everywhere (so `-0.0` differs from `0.0`). Rust: plain `+ - * /` and `sqrt` only, never `mul_add` or fast-math, no SIMD reductions that reorder sums ([determinism rules](determinism-rules.md) "Native code rules"). Each slice note carries the number audit of the handoff's Stage 5.

## Fixture file

Little-endian. Written by `NativeBridge.open_fixture` / `write_record` in `shadow` mode (`record=` option), read by `wargrid_core::fixture::read`. Both sides are tested against the same bytes (`test_native_horde.gd` `test_fixture_bytes`, `fixture.rs` `writes_documented_bytes`; measured green).

| Part | Bytes |
|---|---|
| header | `WGFX`, `u32` version (1) |
| record, repeated to end of file | `u8` slice-name length, name (UTF-8: `horde`, `move`), `i64` tick (`sim.tick()` during the step), `u32` input count, input buffers, `u32` output count, output buffers |
| buffer | `u8` tag (1-5 above), `u32` element count, the elements' raw bytes |

The outputs are GDScript's (`compare` returns them as `expected`). `wargrid_runner replay` keeps one core instance per slice for the whole file (a slice may carry state), recomputes each record and prints `REPLAY OK ticks=<n> records=<n>` or the first `REPLAY MISMATCH slice=.. tick=.. buffer=.. row=.. expected=.. got=..`. With the stubs it reads a 120-tick, two-slice recording and stops at `REPLAY ERROR slice=move tick=0 move: not implemented` (measured), which proves the format end to end.

## Stage 1 paper part: the two slices

### Horde step (`horde.gd` `Horde.step`, called at `simulation.gd` `step()` after `Containers.step`)

- **Reads** (source `horde.gd:15-101`): `armed` ids (sorted, `combat != null`); per member (`combat.has("horde")`): `id`, `owner`, `kind`, `position[0..1]` (float64), `has("container_id")`, `combat.horde_tick`, `combat.horde` (other units' level, read while the pass may already have changed it), and for a level change `combat.next_fire_tick`, `combat.shots_left`, `combat.ramp_level`; `sim._tick`; teams through `Combat.hostile` → `sim.team_of` (`_players[p].team`).
- **Writes:** `combat.horde_tick` (= tick + 30 for class infantry, else 31), `combat.horde` (0, 1 rubbed, 2 in horde), `combat.next_fire_tick` through `Combat.restart_wait` when the level crosses zero (`combat.gd:560-563`, `bonus_delay` `:523-528`), and the counter `sim._horde_checks`.
- **Order inside the pass:** members in `armed` order; a unit's own level does not depend on the visiting order of its neighbours (the count and the `rubbed` OR are order-free; the early return only fires at level 2), but it does read neighbours' `combat.horde` as already updated earlier in the same pass. That is the fixture case "a unit whose level changes in the same pass that a later unit reads". The grid is built once per pass, lazily at the first due unit, from positions that do not move during the pass; cell size = widest horde radius + 2 x largest unit radius over member kinds; keys `Vector2i(floori(x / size), floori(y / size))` (integers; no float32 site in this slice).
- **Missing from `snapshot()` but affecting later ticks:** nothing. `_horde_checks` is a diagnostic counter reset each step; the grid is rebuilt each pass; `Registry.radius_cache` is a cache of definition data.
- **Definitions** (all GDScript `const` dictionaries, so none loads without Godot): per kind `horde.count`, `horde.radius`, `horde.match` (`kind` or `class`), `class`, unit `radius` (row value, or a footprint formula for buildings, `combat_definitions.gd:16-27`), its weapon's `clip_size`, `delay_ticks`, `reload_ticks`, `ramp.percent`; `Shared.HORDE_RATE_PERCENT` (150). The core gets them as table buffers from the slice script; a later engine-free core would need them exported as data (not in scope).

### Movement of moving units (`simulation.gd` `step()` loop over `ids`, `_advance` `:599-626`, `locomotion.gd`)

- **Reads:** per entity `status`; for `moving`: `kind`, `position`, `route` (array of read-only `[x, y]`), `heading`, `speed`, `move_after`, and on arrival `order` (`Containers.entering`: `order.type == "enter"`); `sim._tick`.
- **Writes:** `heading` (from a `Vector2`, so its values are float32-rounded but stored as float64), `speed`, `position` (a new array), `route` (`route.slice(1)` per reached waypoint, a new array each time), and on arrival `order = null` (unless entering), `speed = 0.0`, `status = "arrived"`. Every entity whose status is neither `moving` nor `path_pending` gets `speed = 0.0`, so the slice's rows are all entities, not only moving ones, unless the slice splits them into two row sets (the slice note decides and says how `pass` does the same).
- **Float32 sites** (source; the audit is T6's): `Locomotion._desired` returns a `Vector2` (rounds `dx / length`), `turn` and `_wheel_turn` build and divide `Vector2`s, `angle_between` takes `Vector2` arguments; the heading comparison `desired.x != heading_x` mixes a float32-rounded value with a float64 one. What Godot's `Vector2` operators do with a float64 operand (`turned / sqrt(...)`) is part of T6's number audit (operators in `~/projects/wargrid-native-work/refs/godot-4.7.2-stable/`). Everything else (`_route_length_until`, the route walk in `_advance`) is float64 with `sqrt` only.
- **Missing from `snapshot()` but affecting later ticks:** nothing. Routes are in the snapshot (shared read-only arrays); the read-only flag (`_entity_copy` makes `unit.route` read-only) does not change behaviour. A native route cache would be the first such state and needs its refresh rule in the slice note.
- **Definitions:** per kind `speed`, `locomotor` (`air`, `wheels`, `legs`, `treads`, ...), `accel`, `brake`, `turn_cos`, `turn_sin`, `min_turn_speed` (`Registry.unit_view`, `definitions.gd` `UNIT_KEYS`); GDScript constants, passed in as table buffers.

## Sketch, not built: the whole-simulation contract

The same shape grows by adding calls, not by changing the slice rules:

1. `init(map, seats, definitions) -> core`: terrain, players, start units, and the definition tables as data (the step this spike skips by passing per-kind tables each tick).
2. `submit(tick, commands)`: tick-stamped commands in `_command_before` order (tick, player, sequence); validation results come back as events, as `command_results()` does today.
3. `advance()`: one tick; the core then owns the entities, so the per-tick packing of this spike disappears and is replaced by step 4.
4. Outputs per tick, three kinds kept apart: **events** (combat, command results, and what `SoundDirector`, `SoundPlayer` and `VisualDirector.collect_step` read today); **presentation state** (positions, headings, levels for drawing: the snapshot hand-off T7 measures); **canonical state** for hashing and later save and load (the specified [state digest](determinism-rules.md#state-digest-specified-not-implemented), engine-independent).
5. Ids stay stable and never reused; removal is an event.

Four formats with different requirements stay separate: this in-process boundary (fast, same binary, may change any release), the relay wire protocol (fixed by `protocol/vectors`), the replay trace (commands plus digests, long-lived), and the presentation snapshot (per frame, drawing only). Avoidance will add per-unit state (velocities, neighbours) to the snapshot and the hash; in this shape it is one more set of columns owned by the core, not a new boundary. A C ABI enters only if a non-Rust caller needs the core (the report decides).

## Build pipeline notes (measured 2026-11-10, this tree)

- `sh native/tools/build.sh mac`: 6.7 s; `web` (Emscripten 3.1.74, `-Zbuild-std`): 12.5 s, `wargrid_native.wasm` 405,602 bytes; `linux` (container, `rust:1.94-slim`, 1.94.1): build plus `cargo test -p wargrid_core` (6 tests) 35.8 s. All with warm crate caches, so not clean-build times.
- Known trap ("Conventions"): not reproduced in this tree. `build.sh place` after a first suite import and again after deleting `game/.godot` gave first import exit 0 both times; `place` still imports twice and requires the second to pass. Cause of the earlier crash unknown (the smoke project pointed its libraries outside `res://`; inferred, not tested).
- Outputs per tree in `~/projects/wargrid-native-work/build/<tree>/` (`mac`, `web-<emcc>`, `linux`), so parallel task trees do not overwrite each other; the linux crate cache is shared in `build/linux-registry`.
