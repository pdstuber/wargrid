# Determinism rules (2026-11-10)

Rules that keep the float simulation identical on every platform, and the spec of Wargrid's own state digest. Checked against commit 874c6a3; code references re-checked and turned into symbols against `d20d827` (2026-11-12). Rules describe today's code; **couplings** are facts a port must reproduce, not violations to fix (converting them re-pins every trace). Sources: [state digest research](state-digest-research.md) §2-3, [sim core options](sim-core-options.md) §1B, [engine portability](engine-portability-and-horde-mode.md) couplings table and prep steps 1 and 6, [design answers](design-answers-2026-11-08.md) ("Simulation core and state digest").

Status labels: rules in "Rules" are **in force** (those marked *enforced* are checked by `tools/test_sim_math.py`, from the static-check task of the [plan](../superpowers/plans/2026-11-09-determinism-rules-note.md)). "State digest" is **specified, not implemented**; the [state digest plan](../superpowers/plans/2026-11-09-state-digest-golden-scenarios.md) implements it.

## Rules for new simulation code

- **Time:** ticks only. No wall clock, frame time or `Engine`/`OS`/`Time` state in `game/scripts/simulation/` (today none: `rg '\b(Time|OS|Engine)\.'` is empty there). *enforced*
- **Randomness:** in-tick randomness only through `next_random()`, a 32-bit xorshift (`simulation.gd`, seed `RNG_SEED`); its state is the snapshot field `rng` (`_snapshot()`). No `randi`, `randf`, `RandomNumberGenerator` or `randomize`. *enforced*, exempt: `start_spots.gd` (setup only, see couplings).
- **Maths:** `sqrt` is the only non-arithmetic float function. No trig, `exp`, `log`, fractional `pow` (libm differs per platform). *enforced* (`tools/test_sim_math.py`, `BANNED` and `POW`). Turn rates use precomputed literals `turn_cos` / `turn_sin` (kind definitions such as `definitions/usa.gd`; `locomotion.gd` `_wheel_turn` rebuilds a cosine with `sqrt`).
- **Positions:** keep positions as `[x, y]` float pairs; add no new `Vector2` maths in per-unit loops (portability prep 6). Existing `Vector2` sites stay.
- **Order:** iteration follows `Dictionary` insertion order, so never insert in an order that depends on input timing (network arrival, frame order). Commands apply sorted by `_command_before` (tick, player, sequence; `simulation.gd`, used in `_apply_orders` and `_snapshot`). `_snapshot` sorts entities by id, `last_sequences` by player and buildings/sources by id (`_sorted_copies`). Where code iterates `.keys()` unsorted (`combat.gd` `fire` and `fire_defences`, `simulation.gd` `_unavailable_cells`; the `.keys()` in `containers.gd` `_first_hub`, `construction.gd` `step` and `production.gd` `step` are sorted right after), the order is insertion order and is part of the behaviour.
- **Threads:** single-threaded. Any parallel step needs digest equality on native and web first; see the [ledger](performance.md) "Technology findings" for the one experiment.
- **Snapshot values:** only `null`, `bool`, `int`, `float`, `String`, `StringName`, `Array`, and `Dictionary` with `String` keys. No `Object` (a pointer hash would desync every match), `Vector2`/`Vector2i`, packed arrays or NaN. An `int` field never holds a float: `1` and `1.0` are different digest words (state digest research §2 risks 3-4).
- **Fixed-point:** not now. Floats with these rules and the checks below. Integers only with a port ([design answers](design-answers-2026-11-08.md#simulation-core-and-state-digest-user-2026-11-09-late-evening), user 2026-11-09).

## Couplings a port must reproduce

- **Engine-compiled maths:** `Vector2` methods (`length_squared`, `distance_squared_to`) checked for fused multiply-add on macOS arm64, Godot 4.7.2: none (audit probe 2026-11-11, 278,134 discriminating samples, probe script not kept). Re-check after an engine upgrade.
- **float32 at `Vector2`:** GDScript `float` is float64 but `Vector2` is float32 and rounds at each construction. 89 `Vector2(` sites under `game/scripts/simulation` (`rg -o`, 14 files; `combat.gd` 19, `destination_allocation.gd` 12, `production.gd` 11, `simulation.gd` 9; recounted 2026-11-12, the earlier 65 counted lines). A port rounds to f32 at exactly those sites. Also `Vector2i(position.floor())` (`simulation.gd` `spawn`).
- **Setup RNG:** start spots use Godot's seeded `RandomNumberGenerator` (PCG32; `start_spots.gd` `assign`, `randi_range`), called from `match_settings.gd`. A port reproduces PCG32 or switches to xorshift with one re-pin.
- **A\* tie-breaks:** `AStarGrid2D` with Manhattan heuristics, `DIAGONAL_MODE_NEVER`, no jumping (`grid_navigation.gd` `_init`); tie-breaking is Godot's and was not read in its source. Golden A\* vectors are a later no-regret step.
- **Dictionary insertion order** as above.
- **Digest today:** `state.hash()` (Godot, insertion order, pointer hash for Objects, folds `-0.0`/NaN) plus `core_check`, in `state_hash.gd`; `net/lockstep.gd` sends it on hash ticks. This is the digest matches use today; Wargrid's own digest below is not built yet.

## Native code rules (later Rust or C++ core)

- No implicit FMA. C++: `-ffp-contract=off` (or `-ffp-model=strict`) on every target, never fast-math. Rust: default is strict, never call `mul_add` (inferred from RFC 3514; not tested in codegen).
- No relaxed SIMD ("The relaxed SIMD instructions have nondeterministic results", WebAssembly `Nondeterminism.md`), never hash NaN bits, no libm trig. Quotes in sim core options §1B "Determinism, Rust against C++".

## Checks

- Static: `tools/test_sim_math.py` (run by `sh tools/run_python_checks.sh`).
- Cross-platform traces: CI job `godot-replays` (`.github/workflows/ci.yml`), and `tools/compare_local_traces.sh` for macOS.
- Native vs web digest equality: manual so far (`performance.md` "Technology findings", "Digests"). One mixed match through the relay, browser (WASM) against native macOS, was played by hand on 2026-11-08: about 10 minutes, no desync (corrected 2026-11-12; see [development notes](../development.md#browser-build)). Browser against browser is unverified.
- No runtime digest CI job (user, 2026-11-10).

## State digest (specified, not implemented)

Matches hash with `state_hash.gd` today (see "Digest today" above); this section specifies its replacement. Own spec so no Godot upgrade or port changes the value silently (research §2 risk 1). The reference implementations are GDScript (game) and Python (checker); the state digest plan's Task 1 proves they agree.

**Input and output.** Input: the snapshot `Dictionary` (`simulation.gd` `_snapshot`). Output: 64-bit FNV-1a with a fold, printed as 16 lower-case hex characters, high 32 bits first: `"%08x%08x" % [(h >> 32) & 0xFFFFFFFF, h & 0xFFFFFFFF]`.

**Hash.** All arithmetic is on unsigned 64-bit words (GDScript `int` wraps; Python masks with `2^64 - 1`). `h = 0xcbf29ce484222325`. For each 64-bit word `w` in the stream: `h = (h XOR w) * 0x100000001b3 mod 2^64`, then `h = h XOR (h >> 32)` with a **logical** shift (in GDScript `(h >> 32) & 0xFFFFFFFF`). The fold is per word, after the multiply.

**Word stream**, depth-first, every field (no field list; a new field is covered without code):

| Value | Words |
|---|---|
| `null` | `0` |
| `bool` | `1`, then `0` or `1` |
| `int` | `2`, then the value as 64-bit two's complement |
| `float` | `3`, then the IEEE 754 binary64 bits of `x + 0.0` (so `-0.0` and `0.0` agree) |
| `String` / `StringName` | `4`, the UTF-8 byte length, then the bytes 8 per word, little-endian, the last word zero-padded |
| `Array` | `5`, the length, then each element in order |
| `Dictionary` | `6`, the entry count, then for each key in ascending Unicode code-point order: the key as a `String` item (tag `4` ...), then its value |
| anything else | `7`, then `typeof(value)` (Godot `Variant.Type` number), plus an error report. A rule violation, not a supported value |

Floats: NaN is not allowed in state (GDScript reports an error and hashes `0x7FF8000000000000`). Only the GDScript side can detect NaN or a non-`String` key: the JSON dump writes NaN as `null` and stringifies every key, so the Python checker sees neither. Infinities hash their bits. Code-point order equals byte order of UTF-8; it differs from UTF-16 code-unit order only above U+FFFF.

**Desync dump.** `JSON.stringify(report, "", true, true)` (`online_main.gd`, `net/headless_client.gd`) keeps `int` vs float (integral floats get `.0`), round-trips doubles and writes `-0.0` as `0.0`, NaN as `null`, so the dump is a faithful input for the Python checker (research §3). A checker reading it maps a JSON integer to `int`, a number with `.`/`e` to `float`, `null` to `null`.

**Details the table leaves open** (all (coordinator, 2026-11-10, provisional until the state digest plan's two-implementation test); research §2-4 does not decide them, and nothing here contradicts it):

- (a) The root `Dictionary` is walked as an ordinary item: it starts with tag `6`, then the entry count.
- (b) A string is tag `4`, byte length, then `ceil(length / 8)` words. An empty string and a length that is a multiple of 8 add no padding word.
- (c) A non-`String` key is not a key item: the key is replaced by the words `7`, `typeof(key)`, then its value follows. Sorting happens first, on the `String` keys only; non-`String` keys come after them in insertion order. It is an error either way, so the order only has to be stable.
- (d) A `StringName` key counts as a `String` key (same words as `String`, sorted with them).
- (e) After tag `7` GDScript reports the error and continues; Python has no tag-7 case (a JSON dump holds only the types below), so it never emits `7`.
- (f) Python tests `bool` before `int` (`bool` subclasses `int`), so `true` hashes as tag `1`, not tag `2`.
- (g) The `typeof` numbers in tag `7` are Godot's `Variant.Type` values and have no Python equivalent; a snapshot with a tag-7 value is out of scope for the cross-check.
- (h) A desync report is `{seat, tick, hash_rows, command_log, snapshot}` (`lockstep.gd` `desync_report`); the checker hashes the `snapshot` member as the root, not the whole report.

**Why these choices.** Sorted keys: insertion order is not part of the hash (research §2 risk 5). `x + 0.0` and int-vs-float tags: the JSON dump is a faithful input (research §3). Type tags and lengths: no two different values produce the same word stream by shifting a boundary.

**Scheduling.** Computed on hash ticks (every 30, `net/lockstep.gd` `hash_interval`, `finish_tick`). If the one-shot walk is too slow, one digest is spread over the next 30 ticks (user); the value is identical, only when it is sent changes.

**`core_check`** (`state_hash.gd`) stays as the separate core series for `S1_CORE_SERIES` (`game/tests/test_skirmish_match.gd`) and `TEAM_CORE_SERIES` (`game/tests/test_team_match.gd`).
