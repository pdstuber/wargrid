# Own state digest and golden scenarios Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** approved (user, 2026-11-10), not started and not placed in blueprint §7; needs both other no-regret plans done first.

**Goal:** `StateHash.digest` becomes Wargrid's own 64-bit FNV-1a (with fold) over every snapshot field with sorted keys, a Python reference hasher proves the same value from JSON, three golden scenarios (commands in, digests out) pin it, and the CI replay traces use it instead of SHA-256 over `var_to_bytes`. One re-pin.

**Architecture:** The canonical word stream is specified in [determinism rules](../../reference/determinism-rules.md) "State digest" (written by the [determinism rules plan](2026-11-09-determinism-rules-note.md), which must be done first). Python (`tools/state_digest.py`) is written from the spec first and is the reference; GDScript (`state_hash.gd`) must match it on shared vectors. Golden scenarios are JSON fixtures under `game/tests/fixtures/golden/` (blueprint §5.5 location and shape) run by one suite that uses only the [simulation interface](../../reference/sim-interface.md) (the [interface plan](2026-11-09-sim-interface-note.md) must be done first, so its boundary guard covers the new suite). `core_check` is unchanged. Relay, `protocol/vectors` and conformance are unchanged (the relay checks the 16-hex format only, `relay/envelope.go:16`).

**Tech Stack:** typed GDScript (Godot 4.7.2), Python 3 standard library, the existing suite runner (`game/tests/run_tests.gd` `SUITES`), `tools/compare_replays.py` (already accepts 16 hex, `:20`).

**Spec:** [design answers, "Simulation core and state digest"](../../reference/design-answers-2026-11-08.md#simulation-core-and-state-digest-user-2026-11-09-late-evening) bullets 3-10 and the last one (no horde case until a horde mode is planned). Evidence and options: [state digest research](../../reference/state-digest-research.md) §1, §3 option C, §4 migration. Resume record: `docs/reference/sim-core-no-regret-verification.md` (shared).

**Model routing:** Tasks 1, 2, 4, 5 Sonnet (mid tier; the tests are the spec); Task 3, if triggered, Opus (high) because it touches lockstep scheduling; gate review Opus (high), fresh context.

## Global Constraints

- **One re-pin**: `PINNED` (`game/tests/test_state_hash.gd:6`) and `FINAL_DIGEST` (`game/tests/test_team_match.gd:13`) change once, in Task 5, together with the golden pins written in Task 4 by the same digest. No winner, end tick or `core_check` series (`S1_CORE_SERIES`, `TEAM_CORE_SERIES`) may change: the simulation is untouched; if any of those moves, stop.
- No simulation behaviour change: only `state_hash.gd`, `lockstep.gd` (Task 3 only), tests, fixtures, tools and docs.
- Budget: lockstep overhead p99 0.6 ms on the dev machine (`performance.md` budget table, F = 5.5). Never loosen it; if the one-shot digest misses it, Task 3 time-slices it (user), without a further question (user, 2026-11-10).
- No protocol bump, no relay change; old and new clients are kept apart by the game version (`relay/room.go:141-142`; `tools/release_version.py` makes every release tag a new `config/version`). Dev builds all send the same `config/version`, so two dev clients from different commits can share a room and desync; accepted (user, 2026-11-10), Task 5 bumps the dev version once for this change.
- `0.0` and `-0.0` hash alike; `1` and `1.0` do not; NaN in state is an error (determinism rules).
- No horde-style golden scenario (user).
- Benchmarks run alone on a quiet host; record `uptime` at start and end (user plays WoW sometimes; rerun a loaded row).

## Review Focus

- **Cross-language agreement on real data**, not only vectors: Task 5 runs the Python checker on the netplay `perturb` desync reports (full skirmish snapshots at tick 60), which catches int keys, `Vector2` or `Object` values that the vectors cannot.
- **Key order:** Godot `Array.sort()` on `String` keys must equal Python's code-point order; vector `unicode_keys` pins it.
- **Float bits:** `x + 0.0` before taking bits; `encode_double` / `decode_s64` are little-endian on every target (x86-64, ARM64, WASM).
- **Time-slice (if Task 3 runs):** the completion tick must be identical on every peer (budget in items, never in wall-clock time), or `_verify_hashes` (`lockstep.gd:195-202`) sees a missing own hash and reports a false desync.
- **Golden scenarios exercise their mechanics:** every command is accepted (`ok`) and the recorded final snapshot shows the intended outcome (route arrival, collected credits, deaths).

---

## Risk first

1. **The full walk is too slow on a hash tick** (research infers 0.8-1.2 ms on the dev machine against 0.6 ms). Task 2 measures it on `contact`, `hordes300` and Ashfall before anything depends on it; Task 3 exists for the likely overrun.
2. **GDScript and Python disagree** on some value class (string packing, key order, signed shifts, `-0.0`, inf). Task 1 and 2 share vectors; Task 5 adds the real-snapshot check.
3. **A snapshot holds a value outside the spec** (int key, `Vector2`, `Object`, NaN) somewhere no vector covers. The walker reports an `ERROR:` line, which fails the suite (`tools/run_tests.sh:40`) and the benchmark scripts; Task 5's perturb check catches the JSON-visible cases.
4. **Suite time grows**: the replay traces hash every tick (R1 twice 1,200, economy 1,200, combat 1,200 ticks). Measure the suite wall time before and after Task 5; report the delta (no budget exists for it).

## File structure

- Create `tools/state_digest.py` (reference hasher + CLI), `tools/test_state_digest.py`.
- Create `game/tests/fixtures/digest_vectors.json` (spec vectors as Godot JSON text plus digest).
- Modify `game/scripts/simulation/state_hash.gd` (walker; `digest` switches in Task 5).
- Create `game/tests/test_golden.gd`; add it to `SUITES` in `game/tests/run_tests.gd`.
- Create `game/tests/fixtures/golden/{move_wall_v1,economy_v1,combat_v1}.json` and matching `.snapshot.json`.
- Modify `game/tests/test_state_hash.gd`, `game/tests/test_replay.gd`, `game/tests/test_team_match.gd`, `tools/test_sim_math.py` (drop the `state_hash.gd` exemption), `tools/run_netplay.sh` (`perturb`: Python check).
- Modify (Task 3 only) `game/scripts/net/lockstep.gd`, `game/tests/test_lockstep.gd`.
- Docs: `docs/reference/determinism-rules.md` (status), `docs/reference/performance.md` (ledger row), the verification file.

---

### Task 1: Python reference hasher and spec vectors

```text
Task: tools/state_digest.py computes the spec digest of JSON values and verifies a desync report
Owns: tools/state_digest.py, tools/test_state_digest.py, game/tests/fixtures/digest_vectors.json
Invariant: implements determinism-rules.md "State digest" word for word; no Godot code touched
Boundary: bool is checked before int (Python bool is an int); NaN raises ValueError; a report without a hash row for its snapshot tick is an error, not a match
Red: test_negative_zero_equal, test_int_float_differ, test_key_order_free, test_string_padding (8 vs 9 bytes) fail with ImportError replaced by a stub returning ""
Green: python3 -m unittest discover -s tools -p 'test_state_digest.py' and sh tools/run_python_checks.sh
Stop: the spec leaves a choice open (record the question; do not guess)
```

Interfaces produced:
- `words(value: object) -> Iterator[int]` (unsigned 64-bit words), `digest(value: object) -> str` (16 hex).
- CLI `python3 tools/state_digest.py FILE.json`: if the JSON has `snapshot` and `hash_rows` (a desync report, `lockstep.gd:162`), print `STATE DIGEST <hex> tick=<t> row=<value> MATCH` (exit 0) or `MISMATCH` (exit 1), using the `hash_rows` entry `"<t>\t<value>"` for `t = snapshot.tick`; otherwise print `STATE DIGEST <hex>`.
- `digest_vectors.json`: `[{"name": str, "json": str, "digest": str}]`, where `json` is the exact text `JSON.stringify(value, "", true, true)` gives in Godot (Task 2 asserts that). Cases: `empty_dict` `{}`; `scalars` `{"a": null, "b": true, "c": 0, "d": -1, "e": 9007199254740993}`; `floats` `{"x": 1.0, "y": 0.1, "z": 1e99999}` (Godot writes inf as `1e99999`); `negative_zero` and `positive_zero` (same digest); `int_vs_float` `{"v": 1}` vs `{"v": 1.0}` (differ); `key_order` built in two insertion orders in Task 2 (same digest); `unicode_keys` keys `"Z"`, `"a"`, `"ä"`, `"é"`, `"z"`, `"日"`; `strings` `""`, `"12345678"`, `"123456789"`, `"ü"`; `nested` arrays of dicts of arrays.
- The pinned `digest` values come from this Python implementation (the reference); Task 2 must reproduce them independently. If Task 2 shows Godot formats a number differently from the hand-written `json` text (e.g. full-precision `0.1`), take Godot's text, recompute the pin in Python from it and record the change; the value must parse to the same double.

- [ ] Step 1: write the tests (properties above plus every vector equals its pin); run, expect FAIL.
- [ ] Step 2: implement (`struct.pack("<d", x + 0.0)`, UTF-8 bytes padded to 8, `sorted(d)` keys, mask every step to 64 bits); generate the vector pins once; run, expect PASS; `sh tools/run_python_checks.sh` exit 0.
- [ ] Step 3: verification row (counts, exit) and resume record.

### Task 2: GDScript walker matches the vectors; measure its cost

```text
Task: StateHash.full_digest(state) returns the spec digest and equals Python on every vector
Owns: game/scripts/simulation/state_hash.gd (add full_digest and private helpers only; digest unchanged), game/tests/test_state_hash.gd (new case test_spec_vectors), a scratch timing script (not committed)
Invariant: digest(), core_check() and every existing pin unchanged; suite green
Boundary: unsupported types and non-String keys push_error and hash tag 7 + typeof; NaN push_errors and hashes 0x7FF8000000000000
Red: H5 test_spec_vectors (for each vector: the GDScript literal stringifies to the vector's json text, and full_digest equals the pin; key_order built in two insertion orders) fails against a stub
Green: WARGRID_TEST_ONLY=test_state_hash sh tools/run_tests.sh, then the full suite, lint, warnings
Stop: a vector differs and the cause is not a GDScript bug (then the spec is ambiguous: ask)
```

Implementation decisions:
- Constants: offset basis as the signed literal `-3750763034362895579` (= `0xcbf29ce484222325`; the hex literal does not fit a signed 64-bit `int`), prime `1099511628211`, fold `h ^= (h >> 32) & 0xFFFFFFFF` (arithmetic shift, so mask). GDScript `int` wraps on overflow (`int.xml:7`).
- Float bits: one static 8-byte `PackedByteArray`; `encode_double(0, x + 0.0)`, `decode_s64(0)`.
- Strings: `to_utf8_buffer()`, `resize` to a multiple of 8, `decode_s64` per 8 bytes.
- Dictionary: collect keys, reject non-`String`/`StringName`, convert to `String`, `sort()`.
- Recursive walk, profiler zone `hash.full` around the top call.

- [ ] Step 1: write H5; run `WARGRID_TEST_ONLY=test_state_hash sh tools/run_tests.sh > <log> 2>&1` (timeout 600000), read the summary; expect FAIL.
- [ ] Step 2: implement; rerun; expect PASS. Full suite, `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`.
- [ ] Step 3 (risk 1): scratch script `game/benchmarks/scratch_digest.gd` (never committed, `quit()` on every path, deleted after): 60 snapshots each from `CombatWorkload.create("contact")` and `("hordes300")` after 300 warm-up ticks, and `TeamMatch.create()` stepped with `TeamMatch.step` for 9,000 ticks (Ashfall 3v3, well before its end near tick 24,000-33,000), one snapshot every 30 ticks after that; time `StateHash.digest` and `full_digest` on each (p50 / p99 / max, ms). Run alone, `uptime` before and after.
- [ ] Step 4: decision, recorded with the numbers: projected lockstep p99 = today's lockstep p99 (0.067 ms, `performance.md` budget table) − old digest p99 + `full_digest` p99. If the projection exceeds 0.6 ms on any of the three, Task 3 runs; otherwise Task 3 is skipped and the row says why.

### Task 3 (only if Task 2 Step 4 says so): spread one digest over the next 30 ticks

```text
Task: lockstep computes the digest of hash tick T incrementally and sends it once complete, at a tick every peer computes identically
Owns: state_hash.gd (an explicit-stack walk: begin(state) -> walk, advance(walk, items) -> bool, value(walk) -> String), lockstep.gd (finish_tick, desync_report), test_lockstep.gd, test_state_hash.gd
Invariant: the sliced value equals full_digest(state) for the same snapshot; hash.tick still names T; wire, relay and the 30-tick interval unchanged; _hash_snapshot is T's snapshot, so desync reports keep matching their row
Boundary: the item budget per tick is a constant (never time-based), and a walk still running at the next hash tick is finished synchronously first; match end or stop drops an unfinished walk
Red: L-slice tests: (1) sliced value == full_digest on the contact snapshot for budgets 1, 7 and 10000; (2) two lockstep instances fed the same ticks attach T's hash on the same packet tick; (3) a perturbed peer still ends ended_desync, with the report's snapshot tick equal to the hashed tick
Green: test_lockstep, test_state_hash, full suite; sh tools/run_benchmark.sh LOCKSTEP BUDGET PASS; tools/run_netplay.sh match and perturb
Stop: the budget cannot be met even sliced, or slicing needs a wire change
```

- [ ] Steps: write the three red tests, run (FAIL); implement; run the named suites, then the benchmark alone and the two netplay scenarios; record numbers and the chosen item budget with why.

### Task 4: Golden scenarios

```text
Task: three committed scenarios replay through the public interface and match their pinned digest series and final snapshot
Owns: game/tests/test_golden.gd, game/tests/run_tests.gd (SUITES entry), game/tests/fixtures/golden/*.json, tools/test_state_digest.py (golden check)
Invariant: test_golden.gd uses only sim-interface.md calls (tools/test_sim_boundary.py stays green with no allowlist change); pins come from StateHash.full_digest
Boundary: every command is issued when sim.tick() equals its tick (lockstep timing) and must return ok; a rejected command fails the scenario
Red: G1 test_golden_scenarios fails while the fixture pins are placeholders "0000000000000000"
Green: WARGRID_TEST_ONLY=test_golden sh tools/run_tests.sh, the Python golden check, full suite, lint, warnings
Stop: a scenario needs a call outside the interface, or its outcome (Step 3) does not happen
```

Fixture shape (blueprint §5.5 fields kept: `fixture_version`, `scenario_id`, `classification: "WARGRID_INTERNAL"`, `description`):
- `world`: `{"size": [w, h], "blocked": [[x, y], ...]}` → `Simulation.new(blocked, size)`; `players`: `[{"player", "credits", "controller", "team"}]` → `add_player`; `spawns`: `[{"owner", "position": [x, y] (cells), "kind"}]` → `spawn` (ids must equal 1..n in order, asserted); `sources`: `[{"origin", "boxes"}]` → `add_supply_source`; optional `start_match: [players]`.
- `commands`: the exact `issue_command` dictionaries (`tick, player, sequence, type` + payload).
- `ticks`, `digest_every` (30), `digests` (one per `digest_every` ticks), `final_digest`, `final_snapshot` (file name of the `JSON.stringify(snapshot, "  ", true, true)` text at the last tick).
- Runner asserts each digest, `final_digest`, and that the final snapshot text equals the file. With `WARGRID_GOLDEN_WRITE=1` it writes the actual digests and snapshot into the fixtures instead and **fails the case** ("golden written; rerun without WARGRID_GOLDEN_WRITE"), so a write never passes silently.
- The Python check (`test_golden_snapshots_match`): for every scenario, `digest(json.load(final_snapshot)) == final_digest`. Together with the GDScript text check this proves cross-language agreement on a real snapshot in CI (`run_python_checks.sh` runs in CI, `.github/workflows/ci.yml:282`).

Scenarios (units: 1 cell = 1.0 in sim positions; derive values from the cited tests, do not invent). These three, no full-skirmish case: `test_team_match.gd` `FINAL_DIGEST` covers the full match (user, 2026-11-10):
- `move_wall_v1`: the R1 world (`test_replay.gd` `_world`): wall at x = 8, 8 + 4 spawns, the 7 move commands, 1,200 ticks. Outcome: units end `arrived` near their targets.
- `economy_v1`: 32×32, player 1 with 50,000 credits, a builder at (4.5, 4.5), a 200-box source at (24, 4) (as `economy_fixture.make_world` and R3); build a power plant and a supply center, produce one collector, 1,800 ticks. Command ticks come from one dry run printing when each build completes; record them. Outcome: credits rise after the collector's first drop-off and boxes fall.
- `combat_v1`: two players on different teams, spawned infantry and tanks as in R4 (`_combat_world`, without the barracks and without `remove_object`, which is not a command), an `attack`, an `attack_move` and a `stop`, 900 ticks. Outcome: at least one death and shots in `combat_events`.

- [ ] Step 1: write `test_golden.gd` and the three fixtures with placeholder pins; register in `SUITES`; run `WARGRID_TEST_ONLY=test_golden`; expect FAIL on pins only (all commands ok).
- [ ] Step 2: `WARGRID_GOLDEN_WRITE=1` once, inspect each final snapshot for its outcome (Step 3 of the scenario list) and record it; rerun without the variable; expect PASS. Run it twice more: identical.
- [ ] Step 3: add the Python golden check; `sh tools/run_python_checks.sh`; full suite, lint, warnings, `python3 -m unittest discover -s tools -p 'test_sim_boundary.py'`.

### Task 5: Switch the digest everywhere (the one re-pin)

```text
Task: StateHash.digest is the spec digest; replay traces, pins and the desync check use it; Godot's Dictionary.hash() is gone
Owns: state_hash.gd (digest returns the walker value; full_digest folded into it; profiler zone hash.digest kept), test_state_hash.gd, test_replay.gd, test_team_match.gd, tools/test_sim_math.py (remove the state_hash.gd exemption), tools/run_netplay.sh (perturb), game/project.godot (`config/version` 0.11.0-dev → 0.12.0-dev, so pre- and post-digest dev clients cannot share a room), determinism-rules.md (status), performance.md (ledger row), the verification file
Invariant: winner, end tick and both core_check series unchanged; trace files stay "tick<TAB>16 hex"; compare_replays.py unchanged
Boundary: H2 sensitivity keeps every existing edit and adds "-0.0 equals 0.0", "1 vs 1.0 differ", "insertion order does not matter"; R2 (1e-12 and nested map) and R3 field checks keep passing with digest instead of SHA-256
Red: test_pinned_digest (H1) and TB3 final digest fail with the new digest (the expected re-pin), plus new H2 cases fail against the old digest ("-0.0 equals 0.0" passes today; "insertion order does not matter" fails today)
Green: full suite; sh tools/run_benchmark.sh (LOCKSTEP BUDGET PASS); tools/run_netplay.sh match and perturb; lint; warnings; sh tools/run_python_checks.sh
Stop: any outcome or core series change; a budget miss after Task 3; perturb's Python check reports MISMATCH
```

- [ ] Step 1: before editing, record the suite wall time and old `PINNED` / `FINAL_DIGEST` values.
- [ ] Step 2: write the new H2 cases; switch `digest`; replace `_hash` in `test_replay.gd` with `StateHash.digest` (delete `_hash`); remove the `.hash()` exemption in `tools/test_sim_math.py` (if the determinism plan added one). Run the suite; expect exactly H1 and TB3 red; record their new values; re-pin both (pre-approved by the user's "one re-pin"; record old → new).
- [ ] Step 3: `perturb` in `tools/run_netplay.sh`: after the report checks, run `python3 tools/state_digest.py` on both desync reports and require `MATCH`. Run `sh tools/run_netplay.sh match` and `perturb` (timeout 600000).
- [ ] Step 4: full suite (record wall time delta), lint, warnings, Python checks; `sh tools/run_benchmark.sh` alone with `uptime` at start and end; new ledger row in `performance.md` (lockstep p99 with the new digest, the Task 2 numbers for `hordes300` and Ashfall as report-only); `determinism-rules.md` "State digest" status to "implemented <commit>".
- [ ] Step 5: resume record; list for the gate the checks still pending: CI Linux and Windows traces (`godot-replays` job), `sh tools/compare_local_traces.sh <run id>` for macOS (a CI run from before the switch cannot be compared: different widths), and native-vs-web digest equality: Firefox `--headless` with its own profile first; if the web build does not run headless, one short windowed run in that profile via `open -a Firefox`, quit by the run and logged with open/close times (pre-approved, user, 2026-11-10).

## Stop gate and exit

Exit gate (end of Task 5), each result recorded with its tree: full suite; `sh tools/run_benchmark.sh` with the ledger row; no rendered rerun (no presentation change); CI on Linux and Windows plus `compare_local_traces.sh` for macOS after the user approves a push; netplay `match` and `perturb`; Opus (high) fresh-context gate review (brief: Review Focus, the re-pin values, the Task 2 numbers; it names for each new test the production change that makes it fail; mutations in read-only scratch copies only); then `/ponytail-review`. Native-vs-web digest check as in Task 5 Step 5; push, PR, merge wait for the user.

Stop conditions: those in the task contracts, plus any that `docs/milestone-prompt.md` "Stop conditions" lists.
