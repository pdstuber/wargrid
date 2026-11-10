# Determinism rules note Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** approved (user, 2026-11-10), not started; runs as queue item 3 with the [interface plan](2026-11-09-sim-interface-note.md) (blueprint §7).

**Goal:** One note states the rules that keep the float simulation identical on every platform, including the canonical form of Wargrid's own state digest, and the existing static check grows to enforce the rules that a regex can enforce.

**Architecture:** `docs/reference/determinism-rules.md` documents today's behaviour with file:line (no code change) plus the digest specification that the [state digest plan](2026-11-09-state-digest-golden-scenarios.md) implements. `tools/test_sim_math.py` (today: trig and fractional `pow` ban) gains three banned patterns over `game/scripts/simulation/`: wall clock, any RNG but the in-tick xorshift, and Godot's `.hash()`, each with a named per-file exemption.

**Tech Stack:** Markdown; Python 3 `unittest`; `sh tools/run_python_checks.sh`.

**Spec:** [design answers, "Simulation core and state digest"](../../reference/design-answers-2026-11-08.md#simulation-core-and-state-digest-user-2026-11-09-late-evening): "floats with written determinism rules and a CI check", "0.0 and -0.0 hash the same", FNV-1a 64 with a fold, sorted keys, every field; fixed-point only with a port. Sources: [state digest research](../../reference/state-digest-research.md) §1-3 (it says the note "hosts the spec"), [sim core options](../../reference/sim-core-options.md) §1B determinism and §2 step 1, [engine portability](../../reference/engine-portability-and-horde-mode.md) couplings table and prep steps 1 and 6. Resume record: `docs/reference/sim-core-no-regret-verification.md` (shared; create it if this plan runs first).

**Model routing:** implementation Sonnet; the digest-spec section (Task 1 Step 3) is checked by the Opus (high) gate reviewer against the research note, word by word.

## Global Constraints

- No change under `game/`, `relay/`, `protocol/`; no trace or pin changes. The digest spec is written as **specified, not implemented** until the state digest plan ships (status label in the note).
- Rules describe today's code. Where today's code breaks a rule a port would need (float32 `Vector2` sites, Godot's seeded PCG32 for start spots, `AStarGrid2D` tie-breaks), the note records it as a **coupling**, not as a violation to fix (portability note "Things to avoid now": no `Vector2` conversion now).
- Quote primary sources as the research notes already quote them; do not add new external claims without fetching the page.
- "CI check" means the static bans in `tools/test_sim_math.py` plus the existing `godot-replays` trace comparison; no new runtime digest job (user, 2026-11-10).

## Review Focus

- **Spec is complete enough for a second implementation:** a reader can write the Python reference hasher from the note alone (tags, word order, string packing, float rules, key order, constants, fold, output format, unsupported values).
- **`-0.0` / NaN / int-vs-float rules** agree with the JSON desync dump (`JSON.stringify(report, "", true, true)`, `online_main.gd:87`, `headless_client.gd:214`), so the Python checker can verify a dump.
- **New check patterns** do not fire on today's tree except the named exemptions (`start_spots.gd` RNG, `state_hash.gd` `.hash()`), and each exemption names its reason.

---

## Risk first

1. **Spec ambiguity** that lets GDScript and Python disagree (key sort order, string packing, sign of shifts). Mitigation: exact word list in Task 1 Step 3; the state digest plan's Task 1 proves it with two implementations.
2. **A ban that hits legitimate code** (e.g. `OS.` in a debug helper inside `simulation/`). Mitigation: Step 1 of Task 2 runs the patterns on today's tree first; a hit outside the two expected ones is a stop, not a new exemption.

## File structure

- Create `docs/reference/determinism-rules.md` (about 1.5 pages).
- Modify `tools/test_sim_math.py` (patterns, exemptions, fixture asserts).
- Modify `AGENTS.md` (one line, "Implementation"), `docs/blueprint.md` §3 "Simulation constraints" item 4 (one link).

---

### Task 1: Write the rules note

```text
Task: docs/reference/determinism-rules.md states the simulation's number, order and randomness rules and the digest spec
Owns: docs/reference/determinism-rules.md, the shared verification file
Invariant: no code change; every rule about today's code cites file:line checked on this commit
Boundary: couplings a port must reproduce are listed separately from rules new code must follow
Red: n/a (docs)
Green: every citation opens on the cited code; links resolve; the spec section passes the gate reviewer's "write the hasher from this alone" check
Stop: a rule as written in the research notes is false for today's code (e.g. a trig call exists, an Object is in the snapshot)
```

- [ ] **Step 1: Verify each fact before writing it** (`rg`, read the line): xorshift `next_random` (`simulation.gd:57-63`) and `rng` in the snapshot; seeded `RandomNumberGenerator` in `start_spots.gd:19-20`, called at setup from `match_settings.gd:33`; trig and fractional `pow` ban (`tools/test_sim_math.py:5-6`) and precomputed `turn_cos` / `turn_sin`; `Vector2` construction sites (`rg -c 'Vector2\(' game/scripts/simulation`, 65 on 2026-11-09) and the float32 quote in the portability note; `Dictionary` insertion order and the `.keys()` loops it lists; sorted ids and sorted pending commands in `_snapshot` (`simulation.gd:633-650`, `_command_before`); `AStarGrid2D` settings (`grid_navigation.gd`); no `Time`, `OS`, nodes or signals in the folder.
- [ ] **Step 2: Write the rule sections**, one line each, rule then citation:
  - **Time:** ticks only; no wall clock, frame time or `Engine` state in `simulation/` (enforced, Task 2).
  - **Randomness:** in-tick randomness only through `next_random()`; its state is in the snapshot. Setup randomness (start spots) uses a seeded Godot RNG: a coupling (a port must reproduce PCG32 or switch to xorshift with one re-pin). No other RNG (enforced).
  - **Maths:** `sqrt` only among transcendental-like functions; no trig, `exp`, `log`, fractional `pow` (enforced since `test_sim_math.py`); trig values are literals.
  - **Float widths:** GDScript `float` is float64; `Vector2` is float32 and rounds at every construction (coupling, 65 sites). New sim code keeps positions as `[x, y]` float pairs and adds no new `Vector2` maths in per-unit loops (portability prep 6). Existing sites stay (converting re-pins everything).
  - **Order:** iteration follows `Dictionary` insertion order; never insert in an order that depends on input timing (network arrival, frame order); commands apply in `_command_before` order; the snapshot sorts entities by id.
  - **Pathfinding:** `AStarGrid2D` tie-breaking is Godot's (coupling; golden A* vectors are a later no-regret step, not this plan).
  - **Threads:** the simulation is single-threaded; any parallel step needs digest-equality evidence on native and web first (the perf spike's P1-P4 result in `performance.md` "Technology findings").
  - **Snapshot values:** only `null`, `bool`, `int`, `float`, `String`, `StringName`, `Array`, `Dictionary` with `String` keys; no `Object`, `Vector2`/`Vector2i`, packed arrays, or NaN; an `int` field never holds a float (state digest research §2 risks 3-4).
  - **Fixed-point:** not now; floats with these rules and the CI checks. Switch to integers (OpenRA-style 1024 per cell, `OpenRA.Game/WDist.cs:22`) only as part of a Rust port, with one re-pin (user, 2026-11-09). Name the upsides the user asked for: determinism by construction, free cross-language agreement, simpler hashing.
  - **Native code rules (for a later Rust or C++ core):** no implicit FMA (C++: `-ffp-contract=off` on every target; Rust: default, no `mul_add`), no fast-math, no relaxed SIMD, never hash NaN bits; quotes as in sim core options §1B.
  - **Checks:** `tools/test_sim_math.py` (static), the CI cross-platform trace comparison (`.github/workflows/ci.yml` job `godot-replays`, plus `tools/compare_local_traces.sh` for macOS), and native-vs-web digest equality (manual so far, `performance.md` "Digests" finding).
- [ ] **Step 3: Write the "State digest (specified)" section** exactly as follows (wording may be tightened, content not changed):
  - Input: a snapshot `Dictionary`. Output: 64-bit FNV-1a with a fold, printed as 16 lower-case hex characters, high 32 bits first (`"%08x%08x"`).
  - Hash: `h = 0xcbf29ce484222325`; for each 64-bit word `w`: `h = (h XOR w) * 0x100000001b3 mod 2^64`, then `h = h XOR (h >> 32)` with a logical shift (in GDScript `(h >> 32) & 0xFFFFFFFF`).
  - Word stream, depth-first, every field (no field list):
    - `null` → `0`
    - `bool` → `1`, then `0` or `1`
    - `int` → `2`, then the value as 64-bit two's complement
    - `float` → `3`, then the IEEE 754 binary64 bits of `x + 0.0` (so `-0.0` and `0.0` agree); NaN is not allowed in state (GDScript reports an error and hashes `0x7FF8000000000000`; the Python checker rejects it); infinities hash their bits
    - `String` / `StringName` → `4`, the UTF-8 byte length, then the bytes 8 per word, little-endian, the last word zero-padded
    - `Array` → `5`, the length, then each element
    - `Dictionary` → `6`, the entry count, then for each key in ascending Unicode code-point order: the key as a `String` item, then its value
    - anything else (and a non-`String` key) → `7`, then `typeof`, plus an error report: it is a rule violation, not a supported value
  - Why these choices, one line each: own spec so no engine upgrade or port changes it silently (research §2); sorted keys so insertion order is not part of the hash (research §2 risk 5); `x + 0.0` and int-vs-float tags so the JSON desync dump is a faithful input (research §3).
  - Scheduling: computed on hash ticks (every 30). If the one-shot walk is too slow, one digest is spread over the next 30 ticks (user); the value is identical, only when it is sent changes.
  - `core_check` (`state_hash.gd:16-34`) stays as the separate core series for `S1_CORE_SERIES` and `TEAM_CORE_SERIES`.
- [ ] **Step 4:** Check citations and links; add the evidence row (commit, facts checked, "docs only").

### Task 2: Extend the static check

```text
Task: tools/test_sim_math.py also bans wall clock, foreign RNG and Godot .hash() in game/scripts/simulation/
Owns: tools/test_sim_math.py, AGENTS.md (one line), docs/blueprint.md §3 item 4 (one link), the verification file
Invariant: test_simulation_clean stays green on today's tree with exactly two exemptions
Boundary: comments are ignored (existing split on '#'); identifiers that merely contain the words (e.g. a variable `os_name`, a key "seed") do not match
Red: new fixture asserts in test_fixture_fails ("var t = Time.get_ticks_msec()", "var r = randi()", "var g = RandomNumberGenerator.new()", "var h = state.hash()") fail before the patterns exist
Green: python3 -m unittest discover -s tools -p 'test_sim_math.py' and sh tools/run_python_checks.sh pass
Stop: any hit on today's tree other than RandomNumberGenerator/randi_range in start_spots.gd and .hash() in state_hash.gd
```

Patterns (word-bounded, applied after the existing comment strip):
- `CLOCK = re.compile(r"\b(Time|OS|Engine)\.")`
- `RNG = re.compile(r"\b(randi|randf|randi_range|randf_range|randfn|randomize|rand_from_seed)\s*\(|\bRandomNumberGenerator\b")`
- `NATIVE_HASH = re.compile(r"\.hash\s*\(\s*\)")`
- `EXEMPT = {"start_spots.gd": {"RNG"}, "state_hash.gd": {"NATIVE_HASH"}}`, each with a one-line why comment (setup-only seeded RNG, coupling; Godot hash until the state digest plan removes it, which also deletes this exemption).

- [ ] **Step 1:** Run the three patterns over today's tree in a scratch Python one-liner; expected hits only the two exempt files. Record the output.
- [ ] **Step 2:** Add the four fixture asserts (and one negative: `var os_name = "x"  # Time.now` gives no hit); run, expect FAIL.
- [ ] **Step 3:** Add the patterns and `EXEMPT` to `violations` (keep its signature; pass the file name in `test_simulation_clean`); run, expect PASS.
- [ ] **Step 4:** `AGENTS.md` "Implementation": one line, "Simulation code follows the [determinism rules](docs/reference/determinism-rules.md)." Blueprint §3 "Simulation constraints" item 4: append one link to the note. Run `sh tools/run_python_checks.sh`; update the resume record.

## Stop gate and exit

Exit gate (end of Task 2): Python and docs only, no Godot suite or benchmark needed (recorded with the tree). Opus (high) fresh-context review: citations true, spec complete and unambiguous (it writes a ten-line pseudo-hasher from the note and lists every question it had to guess), patterns and exemptions; for each new assert it names the change that makes it fail. Then `/ponytail-review`. Stop: commit, push, merge wait for the user.
