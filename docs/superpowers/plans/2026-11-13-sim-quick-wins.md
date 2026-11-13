# Sim Quick Wins Implementation Plan

**Status:** approved 2026-11-13 (user; questionnaire answers under "Questions, answered"), not started; refined for the night run 2026-11-13 late night after an Opus readiness review (SI2 rebuilt around an unloaded passenger, SI1 index reuse, SI4 power, scaling red and marker, no `~` in assignments, guide chapters 4 and 11). Written 2026-11-13 night as backup 1 of the Tighter gates night run; resume record: [verification file](../../reference/sim-quick-wins-verification.md).

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development, task by task. Run rules: `docs/night-run.md` (Coordinator rules) and `docs/milestone-prompt.md` (session start, stop conditions). Resume record: the verification file. Every task subagent also reads "Global Constraints", "Pinned values" and "Determinism notes" (`rg -n '^## ' <plan>`).

**Goal:** the night package "Sim quick wins" (`docs/packages.md`, package note; `docs/reference/simulation-reference-review.md` §5.1, §5.4 (a), §6 X1/X4/X6, "Review 2026-11-13"): splash victims from an index built from live positions; a per-tick hash ring carried in the desync report plus a bisect tool; the `step.advance` profiler zone split; a report-only scaling row before and after the index; one ledger row. **No trace re-pin.**

**Architecture:** no game behaviour change. `combat.gd` answers splash from a per-fire-pass cell index instead of scanning every object per shot. `simulation.gd` keeps 64 per-tick hashes of live state outside the snapshot; the lockstep desync report carries them; `tools/desync_bisect.py` replays a report's command log through the headless oracle with a hash per tick and names the first divergent tick and field. A new report-only runner times the combat open layout at five sizes.

**Tech stack:** typed GDScript (Godot 4.7.2), POSIX `sh`, Python 3.12 stdlib.

**Written against** `main` `4bd8711` (simulation files unchanged since `dcaad70`). Anchors below are `file:line` on that tree; Task 0 re-checks them and every task re-anchors by symbol on drift. Runs from `main` `2994adb` (Tighter gates merged: `game/scripts/` unchanged since `4bd8711`; `test_team_match.gd` restructured with the same pins; `run_netplay.sh` deletes its output folder unless `NETPLAY_OUT` is set), before the One controller night package (user, 2026-11-13). Find the desync-report call and the oracle by symbol anyway (`desync_report(`, `_replay_oracle`).

## Global Constraints

- Worktree `~/projects/wargrid-wt-simwins`, branch `sim-quick-wins` from `main` (Task 0 creates both). Agent shells reset their working directory: start every command with `cd <absolute worktree path> && ` and write log paths out in full; `$L` below stands for the absolute form of `~/projects/wargrid-overnight-work/sim-quick-wins/logs`. Never put `~` in a shell assignment (denied at night, 2026-11-13). `$L` holds every log and scratch file; never write logs into the repository. The resume record is the worktree's copy of the verification file.
- Every suite, benchmark, profile, scaling, netplay, conformance, lint, warnings and Python-check call: Bash `timeout: 600000`, output to a file in `$L`, judge by exit code plus marker (`TESTS PASSED`, `CHECKS PASSED 5`, `WARNINGS CHECKED`, `PYTHON TESTS PASSED`, `NETPLAY PASSED`, `CONFORMANCE PASSED`, `BENCHMARK PASSED 2` / `COMBAT BENCHMARK PASSED 10` / `LOCKSTEP BENCHMARK PASSED 1`, `PROFILE COMPLETE 10`, `SCALING COMPLETE 5`). On failure read only `rg -n 'FAIL|SCRIPT ERROR|ERROR:' <log>`. Anything that may run past 10 minutes runs with `run_in_background` and is waited on by its completion notice.
- Static gates: `sh tools/run_checks.sh` if it exists (Tighter gates), else `run_lint.sh`, `run_warnings.sh`, `run_python_checks.sh`, `run_shell_checks.sh`, `check_public.sh` one by one. GDScript changes pass lint and warnings; Python changes pass `run_python_checks.sh`; shell changes pass `run_shell_checks.sh`.
- While iterating: `WARGRID_TEST_ONLY=<suite file or case substring> sh tools/run_tests.sh`. The full suite is the gate before GREEN.
- Allowed at night: `sh tools/run_*.sh`, `sh tools/check_public.sh`, `python3 …`, `godot --headless …`, `git` without push or merge, `git worktree add`. Denied: `git push`, `git merge`, `gh pr`, `fly`, `sh tools/deploy_web.sh`, `sh tools/run_game.sh`, any visible window, any Zero Hour launch. A refused command goes to the morning list with its exact text; the task uses an allowed form or parks.
- New tests use only the simulation interface (`docs/reference/sim-interface.md`; `tools/test_sim_boundary.py`). Tests that must poke private state (field injection, same-tick removal) go into files already on that tool's allowlist (`test_combat.gd`, `test_defences.gd`, `test_lockstep.gd`), as named per task.
- Subagents never commit. The coordinator makes one local commit per GREEN task (pre-authorized by the night run handoff); never push.
- Edit with the Edit tool or asserted replacements. Scratch Godot scripts `quit()` on every path. Scratch mutations (red-by-mutation steps) are reverted with Edit and checked with `git diff --stat`.
- Comments: why only, one line, no diff narration. Remove the `shortcut:` comment above `splash_victims` (`combat.gd:511`) when Task 3 resolves it.
- **Don't touch:** `game/scripts/presentation/`, `game/scenes/`, `relay/`, `protocol/`, `game/data/`, `.github/`, every pinned constant and trace below, `game/tests/test_team_match.gd`, `game/tests/test_skirmish_match.gd`, `game/tests/test_replay.gd`, `game/tests/test_state_hash.gd`. Simulation files only where a task names them: `combat.gd` (Tasks 1, 3), `simulation.gd` (Tasks 1, 5). `.claude/` and the night settings file are the user's.

## Pinned values (none may change; any change is a stop condition)

Values on `4bd8711`; Task 0 reads them from the base tree and records them. A base value that already differs is recorded, not a stop (another package moved it); from then on the recorded value is the pin.

| # | Where | Value | Checked by |
|---|---|---|---|
| V1 | `game/tests/test_team_match.gd` `FINAL_DIGEST` | `3958ceaab11986af` | full suite |
| V2 | same file `TEAM_CORE_SERIES` | `8513092129969516499` | full suite |
| V3 | `game/tests/test_skirmish_match.gd` `S1_CORE_SERIES` | `4004499097874677431` | full suite |
| V4 | `test_state_hash.gd` `PINNED` `01e256834bdd4dfb`; `test_view_rows.gd` `EXPECTED_DIGEST` `7c7fbc8d…48a9e7`; `test_start_spots.gd` `SS6_PINNED` | unchanged | full suite |
| V5 | the four suite traces (`WARGRID_REPLAY_TRACE`, `WARGRID_ECONOMY_REPLAY_TRACE`, `WARGRID_COMBAT_REPLAY_TRACE`, `WARGRID_TEAM_REPLAY_TRACE`) | byte-identical to Task 0's `*-before.tsv` | `cmp` at Tasks 1, 3, 5, 8 |
| V6 | `tools/run_netplay.sh` match terminal tick | `9129` | Tasks 6, 8 |
| V7 | `tools/run_team_match.sh` | `won tick=39497 winner=2 units_peak=271` | Task 8 |
| V8 | no pinned line changes in tests | `git diff main -- game/tests \| rg '^-\s*const'` prints nothing | Task 8 |

Budgets: `docs/reference/performance.md`. `BUDGET EXCEEDED open hordes300 (regression ceilings held)` is accepted (user, 2026-11-07, until the perf work); any other exceeded row or a broken regression ceiling (`run_benchmark.sh` exit 1) is a stop. Never loosen a budget, a ceiling or `ASSUMED_SLOWDOWN`.

## Determinism notes (determinism rules, `docs/reference/determinism-rules.md`)

- **Splash index is not state.** Built inside `fire` / `fire_defences`, dropped at their end, never in the snapshot. Victims stay sorted by id (`splash_victims` sort kept), so cell iteration order never reaches behaviour. The victim predicate stays byte-for-byte today's (`_victim_centre(victim).distance_to(impact) - radius(kind) > radius + EDGE_EPS`, an existing `Vector2` site, float32); only the candidate set shrinks. The cell key uses float64 pair arithmetic (no new `Vector2` maths in a per-object loop) and the window adds `SPLASH_SLACK` so float32 rounding of the centre can never drop a candidate. No RNG draw moves: `_scatter` stays before the victim query.
- **Why build inside `fire`:** every object `fire` can splash keeps its position, filter state and table membership for the whole shot loop (damage applies after the loop, deaths after that), so "lazy at the first splash shot" equals "right before `Combat.fire`" and costs nothing on ticks without one. The lazy combat grid of `plan` is the wrong source (built before construction, production, container exits and movement; `combat.gd:94`, `:161-166`).
- **`fire_defences` gets its own lazy index (plan default; Question 1).** Removals inside `fire` can add splash victims before `fire_defences` runs: a dead container ejects its surviving passengers (`containers.gd:174-190` `_release` → `_exit_all`, they lose `container_id` and get exit positions) and a dead building with a rebuild hole opens a new unmasked hole record (`rebuild_holes.gd:48-53` `_open`). Reusing `fire`'s index and skipping removed ids would miss both.
- **Hash ring reads only.** No RNG draw, no write, not in the snapshot (so `state.hash()`, `core_check` and every digest stay as they are). Floats by raw bits (`x + 0.0` first, so `-0.0` equals `0.0`). Dictionaries iterate in insertion order, which the rules already make part of the behaviour. The ring is per client and never on the wire (network question left to netplay work, review §5.4).
- **Engine hash (plan default; Question 3).** The ring uses `hash()` of two `PackedInt64Array`s (native murmur3 over the bytes; little-endian on arm64, x86-64 and wasm32). Same standing as today's `state.hash()` in `StateHash.digest`. A ring mismatch is only reported, never acted on, so an engine difference cannot end a match.

## Same-tick and interaction cases

No new command and no AI rule in this package. The splash index changes where `fire` reads positions, so these cases are tested (Task 3) or covered by the oracle test:

| Case | Expected | Test |
|---|---|---|
| Unit moves into the blast on the firing tick | hit (live position) | structural: the index holds live records and the window adds `reach`, so this cannot go red; SI1 covers membership |
| Unit unloaded from a container this tick (`_apply_orders`, before `fire`) | candidate, hit inside the blast | SI2 |
| Unit spawned by production this tick | candidate | structural: the index is built inside `fire`, after `Production.step`; SI1 covers membership |
| Unit inside a container | never a victim | SI1 (oracle world has contained units), DF9 existing |
| Air unit | never a victim | SI1 |
| Masked rebuild hole | never a victim; its site is | RH12 existing |
| Victim killed earlier in the same volley | still hit by later shots (removal after the loop) | S7 `test_splash_last_builder_same_tick` existing |
| Building removed in `fire`, then a battery splash in `fire_defences` | removed object not hit; a hole it opened is hit | SI4 |
| Tick with no splash-weapon shot | no index built | SI3 |
| Attacker inside its own blast | skipped by id (units and defences) | SI1 |

## Review focus

1. Splash index: candidate window is a superset of today's hit set for every blast, victim radius and cell position; build count is one per fire pass with a splash shot; `fire_defences` never sees a stale index.
2. Hash ring: changes nothing in the snapshot or any digest; every covered field shows at its tick; cost per tick.
3. Bisect tool: command log → wire lines matches `Lockstep.log_lines`; seat verdicts come from ring rows of the same tick labels; exit codes.

## Risks and model routing

Riskiest first: (1) the index changing who gets hit (pinned traces; SI1-SI4 are written and red-by-mutation before the index exists, Task 3 Steps 1-2); (2) the ring's per-tick cost on every benchmark row (probe before wiring, Task 5 Step 1); (3) `hash()` of packed arrays being content-based and stable across processes (same probe). Nothing depends on (2) or (3) before Task 5.

| Task | What | Model |
|---|---|---|
| 0 | Baseline: worktree, import, suite and traces, pins, profile and benchmark before | Sonnet |
| 1 | Profiler zones: `step.advance` split, `combat.splash` | Sonnet |
| 2 | Scaling row runner; "before" run | Sonnet |
| 3 | Splash index (tests first) | Sonnet |
| 4 | After the index: profile and scaling rerun | Sonnet |
| 5 | Per-tick hash ring | Sonnet |
| 6 | Ring in the desync report; ring-aware `desync_diff.py`; netplay `perturb` | Sonnet |
| 7 | Oracle ring log; `tools/desync_bisect.py` | Sonnet |
| 8 | Docs and package gate (ledger row) | Sonnet |
| 9 | Fresh-context branch review, one fix round, `/ponytail-review` | **Opus (high)** |

Diagnosis of any unexpected red, trace difference or pin change goes to an Opus (high) agent before anything else (night run coordinator rules). Haiku is not used: every task has a load or anchor judgement.

---

### Task 0: Baseline

```text
Task: record the untouched tree's suite, traces, pins, profile zones and benchmark.
Owns: the verification file only.
Invariant: no repository file changes.
Boundary: the import must not be inside the timed runs; load average above 2.5 delays the benchmark.
Red: n/a (measurement).
Green: suite exit 0 with TESTS PASSED; four trace files; PROFILE COMPLETE 10; benchmark exit 0.
Stop: suite red on the untouched tree; a pin missing from its file.
```

- [ ] **Step 1:** `mkdir -p ~/projects/wargrid-overnight-work/sim-quick-wins/logs`; in `~/projects/wargrid`: `git worktree add ~/projects/wargrid-wt-simwins -b sim-quick-wins main`. In the worktree: `git status --short` empty, `git log --oneline -1` recorded; `pgrep -fl 'godot|generalszh'` (list others, kill nothing).
- [ ] **Step 2 (import):** `godot --headless --path game --import > $L/t0-import.log 2>&1; echo "exit=$?"` (fresh worktree; `run_warnings.sh` fails without it).
- [ ] **Step 3 (suite with traces):** `uptime > $L/t0-uptime.txt; WARGRID_REPLAY_TRACE=$L/replay-before.tsv WARGRID_ECONOMY_REPLAY_TRACE=$L/economy-before.tsv WARGRID_COMBAT_REPLAY_TRACE=$L/combat-before.tsv WARGRID_TEAM_REPLAY_TRACE=$L/team-before.tsv sh tools/run_tests.sh > $L/t0-suite.log 2>&1; echo "exit=$?"; uptime >> $L/t0-uptime.txt`. Record CASES, CHECKS, wall seconds, `wc -l $L/*-before.tsv`.
- [ ] **Step 4 (pins):** `rg -n 'FINAL_DIGEST|TEAM_CORE_SERIES|S1_CORE_SERIES|PINNED|EXPECTED_DIGEST' game/tests/*.gd`, `rg -n '9129' tools/run_netplay.sh`, `rg -n 'won tick' tools/run_team_match.sh`: record each against the table.
- [ ] **Step 5 (anchors):** re-read the anchors this plan cites (`rg -n` by symbol: `static func fire`, `fire_defences`, `_splash`, `splash_victims`, `func step`, `step.advance`, `core_check`, `func desync_report`, `_replay_oracle`, `_state_row`, `perturb)`, `static func _block`). Record drift in the evidence row.
- [ ] **Step 6 (profile before):** `sh tools/run_profile.sh > $L/t0-profile.log 2>&1` (background if it runs long). Record from `PROFILE` lines: `combat_contact` and `combat_contact.warmup` `step.combat_fire` max, `combat_hordes300` `step.combat_fire` max, `team_match` `step` mean and max, `step.advance` mean per scenario.
- [ ] **Step 7 (benchmark before, alone):** `uptime`; if the 1-minute load is above 2.5, note it and wait with a Monitor until-loop on `uptime` (at most 15 minutes; foreground `sleep` is blocked), else skip (Task 8's row compares with `main`'s last ledger row instead). `sh tools/run_benchmark.sh > $L/t0-bench.log 2>&1` (on branch `sim-quick-wins` it does not record: `perf_record.py` `auto_label` records only on a clean `main`). Record `WORST TICK` lines for contact, open, hordes300 and `tick_ms` p95/p99 per combat row.
- [ ] **Step 8:** fill the verification file's Baseline section; Task 0 GREEN.

---

### Task 1: Profiler zones: `step.advance` split, `combat.splash`

```text
Task: split step.advance into its four parts and time the splash victim query, with no behaviour change.
Owns: game/scripts/simulation/simulation.gd (step only), game/scripts/simulation/combat.gd (_splash only).
Invariant: V1-V5; zone names step.advance and step.combat_fire unchanged.
Boundary: Profiler off costs one bool check per begin/end; combat.splash is one zone per splash shot, no zone per victim.
Red: a run_profile.sh log of Task 0 has no advance.* or combat.splash zone (rg count 0).
Green: rg finds advance.move, advance.containers, advance.horde, advance.salvage and combat.splash in the new profile log; full suite green; traces cmp silent.
Stop: any trace or pin differs.
```

- [ ] **Step 1 (red):** `rg -c 'zone=(advance\.|combat\.splash)' $L/t0-profile.log` prints nothing or 0.
- [ ] **Step 2:** `simulation.gd` `step()`, the `step.advance` block (`:548-561`). Before:

  ```gdscript
  	for id in armed: before[id] = _entities[id].position
  	for id in ids:
  		var unit: Dictionary = _entities[id]
  		if unit.status == "moving": _advance(unit)
  		elif unit.status != "path_pending": unit.speed = 0.0
  	Containers.step(self)
  	Horde.step(self,armed)
  	Salvage.step(self)
  ```

  After:

  ```gdscript
  	for id in armed: before[id] = _entities[id].position
  	var part: int = Profiler.begin()
  	for id in ids:
  		var unit: Dictionary = _entities[id]
  		if unit.status == "moving": _advance(unit)
  		elif unit.status != "path_pending": unit.speed = 0.0
  	Profiler.end(&"advance.move", part)
  	part = Profiler.begin()
  	Containers.step(self)
  	Profiler.end(&"advance.containers", part)
  	part = Profiler.begin()
  	Horde.step(self,armed)
  	Profiler.end(&"advance.horde", part)
  	part = Profiler.begin()
  	Salvage.step(self)
  	Profiler.end(&"advance.salvage", part)
  ```

  The `before` and `moved` bookkeeping stays in the outer `step.advance` only.
- [ ] **Step 3:** `combat.gd` `_splash` (`:495-502`). Before:

  ```gdscript
  	for victim in splash_victims(sim, impact, radius, weapon.affects, unit):
  		if victim.id != target.id: _hit(shots, damage, sim, unit.id, victim, weapon, true)
  ```

  After:

  ```gdscript
  	var zone: int = Profiler.begin()
  	var victims: Array[Dictionary] = splash_victims(sim, impact, radius, weapon.affects, unit)
  	Profiler.end(&"combat.splash", zone)
  	for victim in victims:
  		if victim.id != target.id: _hit(shots, damage, sim, unit.id, victim, weapon, true)
  ```
- [ ] **Step 4:** full suite with the four trace variables to `$L/*-t1.tsv`, exit 0; `cmp` each against `*-before.tsv` silent; static gates.
- [ ] **Step 5 (profile, the splash "before"):** `sh tools/run_profile.sh > $L/t1-profile.log 2>&1`. Green check from Step 1's `rg` now counts ≥ 5 zone names. Record in "Splash before/after": `combat_contact` and `.warmup` `combat.splash` mean and max, `step.combat_fire` max; `team_match` `combat.splash` max; the four `advance.*` means per scenario (the zone split result). Review §3.3 measured 8.804 / 10.324 ms (sample) and 19.842 / 23.332 ms (warm-up) with a probe zone; expect the same order.

---

### Task 2: Scaling row runner; "before" run (X6)

```text
Task: a report-only runner times the combat open layout at 50, 100, 200, 400 and 800 units and lists zones that grow faster than the unit count.
Owns: game/scripts/debug/combat_workload.gd (create, _block), game/scripts/debug/profiler.gd (one accessor), game/benchmarks/run_scaling.gd (new), tools/run_scaling.sh (new).
Invariant: CombatWorkload.create("open") and every other layout unchanged (default per_side 150); run_benchmark.sh and run_profile.sh untouched; V1-V5.
Boundary: at every size a splash-weapon shot and some shot happen inside the timed window, or the runner fails.
Red: scratch: WARMUP set past the fight (e.g. 2000) makes the 50-unit size fail with "no shot inside the timed window".
Green: sh tools/run_scaling.sh exit 0, SCALING COMPLETE 5; combat benchmark unchanged in Task 8.
Stop: a size cannot fight inside the window without changing the layout's shape (report BLOCKED with the counts).
Without the night allow rule for tools/run_scaling.sh, run `godot --headless --path game --script res://benchmarks/run_scaling.gd > <log> 2>&1` and check `rg '^SCALING COMPLETE 5$' <log>` (Tasks 2 and 4).
```

Sizes are total units, both sides together (Question 2): 25, 50, 100, 200, 400 per side. Today's open row is 150 per side.

- [ ] **Step 1:** `combat_workload.gd`. `create(layout: String)` becomes `create(layout: String, per_side: int = 150)` and passes `per_side` to both `_block` calls. `_block` (`:46-56`) before:

  ```gdscript
  static func _block(sim: Simulation, player: int, front_x: int, direction: int, columns: int, top: int, interleave: bool) -> void:
  	@warning_ignore("integer_division")
  	var rows: int = 150 / columns
  	var placed: int = 0
  	for column in range(columns):
  		for row in range(rows):
  			var tank: bool = placed % 3 == 0 if interleave else placed < 50
  ```

  After:

  ```gdscript
  static func _block(sim: Simulation, player: int, front_x: int, direction: int, columns: int, top: int, interleave: bool, per_side: int = 150) -> void:
  	var rows: int = ceili(per_side / float(columns))
  	var placed: int = 0
  	for column in range(columns):
  		for row in range(rows):
  			if placed == per_side: return
  			@warning_ignore("integer_division")
  			var tank: bool = placed % 3 == 0 if interleave else placed < per_side / 3
  ```

  With 150 this places exactly today's units (10 rows of 15; tanks `placed < 50`). 400 per side: 27 rows from `top` 20, inside the 64 × 64 map.
- [ ] **Step 2:** `profiler.gd`: `static func zones() -> Array: return _series.keys()` (the runner needs the zone list; `_series` is private).
- [ ] **Step 3:** `game/benchmarks/run_scaling.gd` (`extends SceneTree`, pattern of `run_profile.gd` `_fixed`, no view): constants `WARMUP 300`, `SAMPLES 1800`, `SIZES [25, 50, 100, 200, 400]` (per side). Per size: `CombatWorkload.create("open", n)`; `Profiler.enabled = true`; step `WARMUP` ticks, `Profiler.reset()`, step `SAMPLES` ticks with `Profiler.end_tick()` after each; count window shots from `sim.combat_events()` (`type == "shot"`) and `Profiler.calls(&"combat.splash")`. Fail (`push_error`, `quit(1)`) if either is 0. Print, per size:

  ```text
  SCALING units=<2n> ticks=1800 step_mean=<ms> step_p99=<ms> step_max=<ms> shots=<k> splash_calls=<k>
  SCALING_ZONE units=<2n> zone=<z> mean_ms=<ms> max_ms=<ms>
  ```

  then, only when all five sizes ran, per zone with mean ≥ 0.005 ms at 800 units, `SCALING_GROWTH zone=<z> ratios=<r1>,<r2>,<r3>,<r4> superlinear=<yes|no>` where `r` is mean(2n)/mean(n) per doubling and `superlinear` means both of the last two ratios exceed 2.2, and `SCALING_SUPERLINEAR <zones or none>`; then `SCALING COMPLETE %d` with `SIZES.size()`, `quit(0)`. Header line like `run_profile.gd` (engine, os, cpu, `zones=inclusive profiled=true`). Scratch Godot rule: `quit()` on every path.
- [ ] **Step 4:** `tools/run_scaling.sh`: copy of `tools/run_profile.sh` with comment `# Combat open layout at five sizes; reports only, never gates.`, script `res://benchmarks/run_scaling.gd`, marker `^SCALING COMPLETE 5$`.
- [ ] **Step 5 (long sweep rule):** measure the 800-unit size alone first (scratch `SIZES [400]`), record seconds; then revert.
- [ ] **Step 6 (red):** scratch: count only shot events with `tick < 0` (none can match) → the runner exits 1 naming the window; revert. (A longer warm-up is not a reliable red: a 25-per-side fight can outlast it.)
- [ ] **Step 7 (before run):** `uptime`; `sh tools/run_scaling.sh > $L/t2-scaling.log 2>&1` exit 0. Record the `SCALING` and `SCALING_SUPERLINEAR` lines and the `combat.splash` growth row in "Scaling before/after". `assign_move.unavailable` (review X6's other expected zone) likely does not appear: the open layout orders only at tick 0, inside the warm-up; say so.
- [ ] **Step 8:** full suite green (workload change), static gates (shell and GDScript).

---

### Task 3: Splash index (§5.1)

```text
Task: splash victims come from a cell index built once per fire pass from live positions, only when a splash-weapon shot happens.
Owns: game/scripts/simulation/combat.gd (fire, fire_defences, _splash, splash_victims, new _splash_index, _centre_cell, SPLASH_SLACK), game/tests/test_combat.gd, game/tests/test_defences.gd, game/tests/run_tests.gd (`CASE_SECONDS` entry only, for a new case over 1 s).
Invariant: V1-V5 byte-identical; victims sorted by id; RNG draw order unchanged; splash_victims(sim, impact, radius, affects, attacker) without an index still answers correctly (RH12, S7 call it).
Boundary: the same-tick table above.
Red: SI1-SI4 written first; on today's code SI1, SI2, SI4 pass (full scan is the oracle) and SI3 fails (no index zone); each is then shown red by its mutation in Step 4.
Green: WARGRID_TEST_ONLY=test_combat and =test_defences; full suite; traces cmp silent.
Stop: any trace, digest or core series differs (do not re-pin: Opus diagnosis, then park).
```

- [ ] **Step 1 (tests, `test_combat.gd`, add to `cases()`):**
  - **SI1 `test_splash_index_matches_oracle`:** reuse `_oracle_world(rng)` as it is (it already has contained units, several owners and teams, buildings, a masked building and the air kind `usa_collector`). Copy today's `splash_victims` body into the test as `_oracle_splash(sim, impact, radius, affects, attacker)` (the full scan; prefix combat helpers with `Combat.` and use the test's `Definitions.radius`, which is `combat_definitions.gd`). Write it first with today's 5-argument `Combat.splash_victims(...)` (a call to `_splash_index` or a sixth argument is a parse error before Step 4). In Step 4, once the index exists, build it once per world (`var index: Dictionary = Combat._splash_index(sim, {})`) and pass it to every call; one query per world stays without an index (the default path), so the case does not rebuild the index per query. For 50 worlds × 20 impacts (random points on the world, plus each building's centre and each unit's position) × radii `[0.2, 0.52, 1.0, 1.8533333333333333]` × attackers (a unit, a building, `{"id": -1, "owner": k}`) compare the id lists. Check: `"SI1 indexed splash equals the full scan (%d queries, %d mismatches)"`, queries ≥ 10000 and mismatches 0. Time the case; over 1 s, add it to `CASE_SECONDS` in `game/tests/run_tests.gd`.
  - **SI2 `test_splash_hits_passenger_unloaded_this_tick`** (interface only: `spawn`, `issue_command`, `step`, `snapshot`, `combat_events`; radii from `definitions/`): a `usa_tank` of player 1 ordered to `attack` an enemy vehicle T (blast 0.2, no scatter); beside T a container of T's owner (a kind with `Containers.rules`, loaded with one infantry W through the interface). On the tick before the shooter's next shot tick F issue `unload` for that container, so `_apply_orders` releases W at F, placed so W's exit position lies inside the blast (0.2 + W's radius of T's centre). Tune the placement until W's exit position is inside on today's code. Checks: W gets a `splash` shot at F (`"SI2 a passenger unloaded on the firing tick inside the blast is hit"`); the shot list at F names W at most once.
  - **SI3 `test_splash_index_built_only_on_splash_ticks`:** add `const Profiler = preload("res://scripts/debug/profiler.gd")` to `test_combat.gd` if absent. Profiler on (`Profiler.reset()`, `Profiler.enabled = true`, off and reset at the end): a cannon tank duel for 200 ticks. Count ticks with a shot by a weapon whose `primary_radius > 0` (from `combat_events()` and `definitions/shared.gd`), compare with `Profiler.calls(&"combat.splash_index")`: equal (`"SI3 one index build per tick with a splash-weapon shot, none otherwise"`).
- [ ] **Step 2 (test, `test_defences.gd`):** **SI4 `test_defence_splash_sees_objects_fire_added`:** an FRC building with a `rebuild_hole` (e.g. `frc_barracks`, player 2, completed via `EconomyFixture`) at hp 1, a USA `usa_tank` of player 1 ordered to `attack` it, a USA `usa_defence` (Missile Battery, `battery` weapon, blast 0.2; `"powered": true`, so player 1 also gets a completed `usa_power_plant`) whose target is a player 2 vehicle standing beside the barracks so the blast reaches the barracks centre (0.2 + the hole kind's radius). Align the tank's first shot tick F and the battery's shot (set `combat.next_fire_tick` privately; the file is allowlisted). Checks: at F the barracks dies in `fire` (death event), its hole exists after the step, and the battery's shots at F include a `splash` shot on the hole id (`"SI4 a battery splash hits the rebuild hole fire opened this tick"`); no shot names the dead barracks' id after its death event.
- [ ] **Step 3:** `WARGRID_TEST_ONLY=test_combat sh tools/run_tests.sh > $L/t3-red-combat.log 2>&1` and `WARGRID_TEST_ONLY=test_defences …` on today's code: SI1, SI2, SI4 pass, SI3 fails (zone never called). Record.
- [ ] **Step 4 (implementation, `combat.gd`):**

  ```gdscript
  # Cell keys are float64 while _victim_centre rounds to float32; the slack keeps every candidate.
  const SPLASH_SLACK: float = 0.01
  
  # Built once per fire pass from live positions, so units moved, spawned or unloaded this tick are in it.
  static func _splash_index(sim: Simulation, box: Dictionary) -> Dictionary:
  	if not box.is_empty(): return box
  	var zone: int = Profiler.begin()
  	var cells: Dictionary = {}
  	var reach: float = 0.0
  	for pool: Dictionary in [sim._entities, sim._buildings]:
  		for victim: Dictionary in pool.values():
  			if Registry.air_kinds.has(victim.kind) or victim.has("container_id") or masked(victim): continue
  			var key: Vector2i = _centre_cell(victim)
  			if not cells.has(key): cells[key] = []
  			cells[key].append(victim)
  			reach = maxf(reach, CombatDefinitions.radius(victim.kind))
  	box.cells = cells
  	box.reach = reach
  	Profiler.end(&"combat.splash_index", zone)
  	return box
  
  static func _centre_cell(victim: Dictionary) -> Vector2i:
  	if not victim.has("origin"): return Vector2i(floori(victim.position[0] / GRID_CELL), floori(victim.position[1] / GRID_CELL))
  	var size: Vector2i = Definitions.building(victim.kind).footprint
  	return Vector2i(floori((victim.origin[0] + size.x * 0.5) / GRID_CELL), floori((victim.origin[1] + size.y * 0.5) / GRID_CELL))
  
  static func splash_victims(sim: Simulation, impact: Vector2, radius: float, affects: Array, attacker: Dictionary, index: Dictionary = {}) -> Array[Dictionary]:
  	if index.is_empty(): index = _splash_index(sim, {})
  	var cells: Dictionary = index.cells
  	var window: float = radius + index.reach + EDGE_EPS + SPLASH_SLACK
  	var victims: Array[Dictionary] = []
  	for y in range(floori((impact.y - window) / GRID_CELL), floori((impact.y + window) / GRID_CELL) + 1):
  		for x in range(floori((impact.x - window) / GRID_CELL), floori((impact.x + window) / GRID_CELL) + 1):
  			var key := Vector2i(x, y)
  			if not cells.has(key): continue
  			for victim: Dictionary in cells[key]:
  				if victim.id == attacker.id: continue
  				if (_victim_centre(victim).distance_to(impact) - CombatDefinitions.radius(victim.kind)) > radius + EDGE_EPS: continue
  				if affects.has("enemies" if hostile(sim, attacker.owner, victim.owner) else "allies"): victims.append(victim)
  	victims.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
  	return victims
  ```

  `_splash` gains a `box: Dictionary` parameter and passes `_splash_index(sim, box)` as the index inside the `combat.splash` zone. `fire` declares `var splash_box: Dictionary = {}` before its unit loop and passes it at `:366`; `fire_defences` declares its own `var splash_box: Dictionary = {}` before its loop and passes it at `:410` (Question 1). Delete the `shortcut:` comment at `:511`. Window check: blast ≤ 1.853, largest victim radius ≤ 2.2 today (3 × 3 footprint 2.12, `MAX_TARGET_RADIUS` 2.2), so at most ±4.07: 3 × 3 cells of 8.
- [ ] **Step 5 (red by mutation, scratch, revert each):** (a) `window = radius` (drop reach and slack): SI1 mismatches > 0; (b) build the index early: in `simulation.gd` `step()` call `Combat._splash_index(self, early)` on a scratch `static var` box right before `_apply_orders()` and let `fire` use that box: SI2 fails (W still had `container_id` at the build); (c) pass `fire`'s box into `fire_defences` (scratch static): SI4 fails; (d) build the box eagerly at the top of `fire`: SI3 fails. `git diff --stat` after the reverts shows only Steps 1, 2 and 4.
- [ ] **Step 6:** both test suites green; full suite with the four trace variables to `$L/*-t3.tsv`, `cmp` against `*-before.tsv` silent; V1-V4 pass in the suite; static gates.

---

### Task 4: After the index: profile and scaling rerun

```text
Task: measure the splash index against Tasks 1 and 2.
Owns: the verification file only.
Invariant: no repository file changes.
Boundary: same load rule as Task 0 (note uptime at start and end).
Red: n/a.
Green: PROFILE COMPLETE 10 and SCALING COMPLETE 5, exit 0.
Stop: none (report-only), unless a run fails.
```

- [ ] **Step 1:** `sh tools/run_profile.sh > $L/t4-profile.log 2>&1`. Record next to Task 1's: `combat_contact` (sample and warm-up) `combat.splash` mean/max, `combat.splash_index` mean/max/calls per tick, `step.combat_fire` max, `step` max; `team_match` the same; `combat_hordes300` `step.combat_fire` max (no splash weapon; expect unchanged, cause already found, see Question 6). Review proposal X1: contact `combat_fire` max below 2 ms; record met or not met, no stop.
- [ ] **Step 2:** `sh tools/run_scaling.sh > $L/t4-scaling.log 2>&1`. Fill "Scaling before/after" (step mean/p99/max per size, `combat.splash` ratios, the superlinear list before and after).

---

### Task 5: Per-tick hash ring (§5.4 a)

```text
Task: the simulation keeps the last 64 per-tick hashes of live state: units, buildings (hp, progress), sources (amount), player credits and the RNG, floats by raw bits.
Owns: game/scripts/simulation/simulation.gd (const, var, _init, step tail, _tick_hash, hash_ring), game/tests/test_lockstep.gd, docs/reference/sim-interface.md (one line).
Invariant: snapshot keys unchanged; V1-V5; no RNG draw.
Boundary: a change below 1/1024 shows (core_check misses it); match_over ticks add no row.
Red: HR1 and HR2 fail against a stub hash_ring() that returns an empty PackedStringArray (a missing method is a parse error, not a red); HR3 passes on the stub and goes red when the ring is put into _snapshot (scratch mutation).
Green: WARGRID_TEST_ONLY=test_lockstep; full suite; traces cmp silent.
Stop: any pin or trace differs; the probe shows hash() of packed arrays is not content-based (park the engine-hash path, use the FNV fallback, record).
```

- [ ] **Step 1 (probe, scratch script in `$L`, `quit()` on every path):** (a) two separately built `PackedInt64Array`s with equal content give equal `hash()`; flipping the lowest bit of one float's bits (via `PackedFloat64Array.to_byte_array().to_int64_array()`) changes it; run the script twice in two processes, same value printed. (b) Cost: time the `_tick_hash` body below over `TeamMatch.create()` stepped to tick 6000 and over `CombatWorkload.create("hordes300")`, 1000 calls each; record µs per call next to `step` means from Task 0. If (a) fails, use the fallback: one FNV-1a 64 loop over the same words (`h = -3750763034362895579`, the FNV offset basis as int64, because the hex literal exceeds INT64_MAX; per word `h = (h ^ w) * 0x100000001b3`, then `h ^= (h >> 32) & 0xFFFFFFFF`; relies on int64 wrap like `TEAM_CORE_SERIES`), and record its cost.
- [ ] **Step 2 (stub and tests, `test_lockstep.gd`, add to `cases()`):** stub `func hash_ring() -> PackedStringArray: return PackedStringArray()` in `simulation.gd`. Tests, two sims from the same setup (the file's existing world helper or `Skirmish.create()`):
  - **HR1 `test_hash_ring_names_injected_tick`:** for each mutation, a fresh pair stepped to tick 50; mutate sim B while `tick() == 50`; step both to 60. Mutations: an idle unit's position x `+= 1e-9`; unit hp `-= 1`; unit owner; building hp `-= 1`; building `work += 1` on an unfinished site (or a completed building's production head `work += 1`); source `boxes -= 1`; player credits `+= 1`; `_rng ^= 1`. Check per mutation: rows up to tick 50 equal, row 51 differs (`"HR1 %s change at tick 50 shows first at ring row 51"`).
  - **HR2 `test_hash_ring_shape`:** after 100 steps `hash_ring()` has 64 rows, ticks 37..100 in order, each `"<tick>\t<16 hex>"`; after 10 steps 10 rows (1..10); two identical sims give identical rings (`"HR2 ring holds the last 64 ticks, oldest first"`).
  - **HR3 `test_hash_ring_outside_snapshot`:** `snapshot()` has no ring key and `StateHash.digest(snapshot())` is equal for two sims whose rings were computed (`"HR3 the ring is not state"`).
  Run: HR1 and HR2 FAIL against the stub (named checks, not parse errors). Record.
- [ ] **Step 3 (implementation, `simulation.gd`):** `const StateHash = preload("res://scripts/simulation/state_hash.gd")` (no cycle: `state_hash.gd` preloads only the profiler), `const HASH_RING_SIZE: int = 64`, `var _hash_ring := PackedInt64Array()`, `_hash_ring.resize(HASH_RING_SIZE)` in `_init`. At the end of `step()`, after `_tick += 1` and before `Profiler.end(&"step", total)`:

  ```gdscript
  	zone = Profiler.begin()
  	_hash_ring[_tick % HASH_RING_SIZE] = _tick_hash()
  	Profiler.end(&"step.hash_ring", zone)
  ```

  ```gdscript
  # Live state, never the snapshot; floats by raw bits so a change below core_check's 1/1024 shows at its tick.
  func _tick_hash() -> int:
  	var words := PackedInt64Array([_tick, _rng])
  	var floats := PackedFloat64Array()
  	for unit: Dictionary in _entities.values():
  		words.append(unit.id)
  		words.append(unit.owner)
  		words.append(unit.hp)
  		floats.append(unit.position[0] + 0.0)
  		floats.append(unit.position[1] + 0.0)
  	for building: Dictionary in _buildings.values():
  		words.append(building.id)
  		words.append(building.hp)
  		words.append(building.get("work", 0))
  		var queue: Array = building.get("queue", [])
  		words.append(queue[0].work if not queue.is_empty() else -1)
  	for source: Dictionary in _sources.values():
  		words.append(source.id)
  		words.append(source.boxes)
  	for player: Dictionary in _players.values():
  		words.append(player.id)
  		words.append(player.credits)
  	return (hash(words) << 32) | hash(floats.to_byte_array().to_int64_array())
  
  func hash_ring() -> PackedStringArray:
  	var rows := PackedStringArray()
  	for t in range(maxi(1, _tick - HASH_RING_SIZE + 1), _tick + 1):
  		var h: int = _hash_ring[t % HASH_RING_SIZE]
  		rows.append("%d\t%08x%08x" % [t, (h >> 32) & StateHash.MASK, h & StateHash.MASK])
  	return rows
  ```

  Row label = the tick `snapshot().tick` would show after that step. "Progress" = construction `work` plus the production queue head's `work` (Question 4). Keep the `get` defaults: test fixtures inject buildings without `work` (`test_combat.gd` `_oracle_world` and the barracks dicts).
- [ ] **Step 4:** HR1-HR3 pass; scratch mutation `result.hash_ring = hash_ring()` in `_snapshot` makes HR3 fail, reverted; full suite with trace variables, `cmp` silent; static gates. `docs/reference/sim-interface.md` "State out": `hash_ring() -> PackedStringArray`: the last 64 per-tick hashes of live state (`"<tick>\t<16 hex>"`, oldest first), not in the snapshot, for desync reports only; never compare it across builds of different engine versions.
- [ ] **Step 5 (cost, X4):** `sh tools/run_profile.sh > $L/t5-profile.log 2>&1`; record `step.hash_ring` mean and its share of `step` mean for `team_match` and `combat_hordes300` (review proposal: under 3 %). Over 3 % is recorded, not a stop; a benchmark budget or ceiling broken by it in Task 8 is a stop.

---

### Task 6: Ring in the desync report; ring-aware `desync_diff.py`; netplay `perturb`

```text
Task: every desync report carries hash_ring, and desync_diff names the first tick where two reports' rings differ.
Owns: game/scripts/net/lockstep.gd (desync_report), game/scripts/net/headless_client.gd (one call), game/scripts/online_main.gd (one call), tools/desync_diff.py, tools/test_desync_diff.py, tools/run_netplay.sh (perturb scenario), game/tests/test_lockstep.gd (L6).
Invariant: first_difference unchanged (its tests stay green); exit codes unchanged; report keys only gain hash_ring; SK23 (test_skirmish.gd, report without a simulation) still passes.
Boundary: a report without a ring (older build) diffs as before.
Red: L6 ring check and the new desync_diff tests fail first.
Green: test_lockstep, test_skirmish, run_python_checks.sh, sh tools/run_netplay.sh perturb and match.
Stop: V6 changes.
```

- [ ] **Step 1 (red):** `test_lockstep.gd` `test_desync_detected` (`:240-255`): after the existing checks add `"L6 rings first differ at tick 41"`: `c.ls.desync_report(c.sim).hash_ring` of both clients, first differing row tick is 41 (the harness calls `hook` before `advance`, `test_lockstep.gd:59-62`, so the change made at tick 40 lands in row 41). `tools/test_desync_diff.py`: tests for `ring_divergence(first, second)`: equal rings → `None`; rows differing from tick 41 → `41`; disjoint ticks → `None`; a report without `hash_ring` → `None`. Both fail now.
- [ ] **Step 2:** `lockstep.gd:176-177` before:

  ```gdscript
  func desync_report() -> Dictionary:
  	return {"seat": _seat, "tick": _desync_tick, "hash_rows": hash_rows(), "command_log": _command_log, "snapshot": _hash_snapshot}
  ```

  After:

  ```gdscript
  func desync_report(sim: Simulation = null) -> Dictionary:
  	var report := {"seat": _seat, "tick": _desync_tick, "hash_rows": hash_rows(), "command_log": _command_log, "snapshot": _hash_snapshot}
  	if sim != null: report.hash_ring = sim.hash_ring()
  	return report
  ```

  Callers: `headless_client.gd:216` `_lockstep.desync_report(_sim)`; `online_main.gd:109` `_lockstep.desync_report(simulation)`.
- [ ] **Step 3:** `tools/desync_diff.py`:

  ```python
  def ring_divergence(first: dict, second: dict) -> int | None:
      a = dict(row.split("\t") for row in first.get("hash_ring", []))
      b = dict(row.split("\t") for row in second.get("hash_ring", []))
      return next((int(t) for t in sorted(set(a) & set(b), key=int) if a[t] != b[t]), None)
  ```

  In `__main__`, before the field path, print `ring diverges at tick <T>` when not `None`. Exit codes as today.
- [ ] **Step 4:** `tools/run_netplay.sh` `perturb)` (`:118-132`): after the `desync_diff` call also require `ring diverges at tick 41` in `$diff_out` (`fail "desync_diff did not name ring tick 41: $diff_out"`), and extend the Python block to assert `len(report["hash_ring"]) > 0` per seat.
- [ ] **Step 5:** `WARGRID_TEST_ONLY=test_lockstep`, `=test_skirmish` green; `sh tools/run_python_checks.sh`; `sh tools/run_netplay.sh perturb > $L/t6-perturb.log 2>&1` and `sh tools/run_netplay.sh match > $L/t6-match.log 2>&1` (V6, terminal tick 9129); full suite; static gates.

---

### Task 7: Oracle ring log; `tools/desync_bisect.py`

```text
Task: replay a desync report's command log headless with a hash on every tick, name the first divergent tick per seat, and diff the snapshots there.
Owns: game/scripts/net/headless_client.gd (_replay_oracle, _state_row), tools/compare_replays.py (first_divergence), tools/desync_bisect.py (new), tools/test_desync_bisect.py (new), tools/run_netplay.sh (perturb).
Invariant: the oracle without --ring-log behaves as today (replay_session.sh, test_playtest_replay.gd); compare_replays CLI output and tests unchanged.
Boundary: the report's ring may start after tick 1 and end a few ticks after its snapshot tick; a seat ring missing; two reports with different command logs.
Red: test_desync_bisect.py fails (module missing is not a red: write the tests against a stub module whose functions raise NotImplementedError).
Green: run_python_checks.sh; sh tools/run_netplay.sh perturb with the bisect assertions.
Stop: the local replay of the perturb reports matches neither seat (an oracle setup bug: Opus diagnosis, park).
```

- [ ] **Step 1 (oracle, `headless_client.gd` `_replay_oracle`, `:221-246`):** new argument `--ring-log PATH`: after each `sim.step()` append the last row of `sim.hash_ring()` to a `PackedStringArray`; write it with `_write_lines` next to the existing `hash-log` write. Rows are `"<tick>\t<16 hex>"` from tick 1, the format `compare_replays.read_trace` reads with `--interval 1`. `_state_row` (`:257`): `JSON.stringify(state, "", true, true)` (full precision, sorted, like the desync report) so a local snapshot and a report snapshot compare float for float.
- [ ] **Step 2 (`compare_replays.py`):** extract `first_divergence(traces: list[list[str]]) -> int | None` (index of the first row where values differ) and use it in `compare_traces`; message and exit codes unchanged.
- [ ] **Step 3 (tests first, `tools/test_desync_bisect.py`, stdlib `unittest`):** `wire_lines(command_log)` groups by `tick` in log order, one line per tick, `json.dumps({"commands": cmds, "seat": 0, "tick": t, "type": "tick"}, sort_keys=True)` (what `Lockstep.log_lines` writes and `Wire.decode` reads); `seat_verdict(report_ring, local_rows)` → `None` or the first differing tick over shared ticks; a fake `replay` (monkeypatched) drives `main()` for: two reports with different command logs (`COMMAND LOGS DIFFER`, exit 1); seat 1 matches and seat 2 diverges at 41 (exit 1, both `SEAT` lines and a `FIRST FIELD` line); all match (exit 0); `--client-b` with diverging ring logs (`CLIENTS DIVERGE AT TICK`). Run them against the stub: named failures.
- [ ] **Step 4 (`tools/desync_bisect.py`):** `usage: desync_bisect.py REPORT.json [REPORT_B.json] [--client-b CMD] [--out DIR]`. Client command: `WARGRID_CLIENT` (split on spaces, as `replay_session.sh`) or `godot --headless --path <repo>/game`, then `-- --netclient --replay-log <out>/commands.log --map <report.map> --seed <report.seed> --oracle-ticks <last ring tick or report tick> --ring-log <out>/ring-a.tsv` (pass 1), and pass 2 adds `--state-ticks <T-1>,<T>,<snapshot tick> --snapshot-dir <out>/a`. Imports `first_difference` / `_walk` and `ring_divergence` from `desync_diff.py`, `read_trace` / `first_divergence` from `compare_replays.py`. Output lines, exactly:

  ```text
  COMMAND LOGS DIFFER <path>
  RINGS DIVERGE AT TICK <T>            (two reports)   | RINGS AGREE
  SEAT <s> MATCHES LOCAL REPLAY        | SEAT <s> DIVERGES FROM LOCAL REPLAY AT TICK <T> | SEAT <s> HAS NO RING
  SEAT <s> FIRST FIELD <path>          (report snapshot against the local snapshot at the same tick)
  CLIENTS MATCH <n> TICKS              | CLIENTS DIVERGE AT TICK <T> FIRST FIELD <path>   (--client-b)
  SNAPSHOTS <dir>
  BISECT FAILED <reason>
  ```

  Exit 0 when everything matches, 1 when any divergence is named, 2 on usage, I/O or oracle failure (no `ORACLE FINAL` line). `subprocess.run(..., check=False)` with the return code checked (ruff PLW1510). Default `--out` is a `tempfile.mkdtemp()` printed in the `SNAPSHOTS` line.
- [ ] **Step 5 (end to end):** `tools/run_netplay.sh` `perturb)`: run `${PYTHON:-python3} "$repo_root/tools/desync_bisect.py" "$out/desync-seat1.json" "$out/desync-seat2.json" --out "$out/bisect"`, require exit 1 and the lines `RINGS DIVERGE AT TICK 41`, `SEAT 1 MATCHES LOCAL REPLAY`, `SEAT 2 DIVERGES FROM LOCAL REPLAY AT TICK 41`, and a `SEAT 2 FIRST FIELD` line containing `players`. `NETPLAY_OUT=$L/t7-netplay sh tools/run_netplay.sh perturb > $L/t7-perturb.log 2>&1` passes (`NETPLAY_OUT` keeps the reports and `bisect/` as evidence; without it the script deletes its output folder on a pass).
- [ ] **Step 6:** `sh tools/run_python_checks.sh`, `sh tools/run_shell_checks.sh`, `WARGRID_TEST_ONLY=test_playtest_replay` green, `sh tools/replay_session.sh` unaffected (covered by that suite), full suite, static gates.

---

### Task 8: Docs and package gate

```text
Task: docs describe the index, the ring and the tools; the final tree passes every local gate; one ledger row.
Owns: docs/guide/04-the-tick.md, docs/guide/08-combat.md, docs/guide/10-determinism-and-replays.md, docs/guide/11-multiplayer.md, docs/guide/12-performance-and-platforms.md, docs/guide/13-testing-and-tooling.md, docs/reference/determinism-rules.md, docs/reference/performance.md, docs/reference/simulation-reference-review.md, docs/STATUS.md, README.md (generated only), docs/reference/perf-history.csv (benchmark record only), the verification file.
Invariant: V1-V8.
Boundary: load average above 2.5 at the benchmark start (note, wait with a Monitor until-loop on `uptime` for at most 15 minutes, else morning item).
Red: n/a.
Green: every command below on the final tree, each recorded with the tree it ran on.
Stop: a pin differs; a budget or ceiling newly exceeded.
```

- [ ] **Step 1 (docs):** guide ch. 10: report step 5 (`:80`) gains the ring; step 6 (`:82`) the ring line of `desync_diff.py`; a new step for `desync_bisect.py`; the mermaid node after `desync_diff.py`; the Files list (`:144`) and footer (`:160`, "Checked against" = `git rev-parse --short HEAD` at the start of this task). Guide ch. 13: `tools/run_scaling.sh` (report-only) and `tools/desync_bisect.py` in the tool list. Guide ch. 8, "Damage is instant": one sentence that splash victims come from a cell index built once per fire pass (`fire_defences` builds its own), and the code trail gains the index function. Guide ch. 4: the tick pipeline diagram gains the hash-ring step at the end of `step()`. Guide ch. 11: where `desync_report` is described, the report now carries `hash_ring`. Guide ch. 12: `tools/run_scaling.sh` in the tool table (report only) and the `step.advance` sub-zones where the profile zones are named. Each changed chapter keeps the guide's simple-to-complex order and gets its `Checked against` footer (`AGENTS.md`, codebase guide rule). `determinism-rules.md` "Digest today": one sentence that the per-tick ring (engine `hash()` over raw words, not in the snapshot) only localises desyncs. `performance.md` History: one hand-written row for the splash and scaling evidence (contact `combat.splash` and `combat_fire` max before/after, scaling superlinear list before/after, `step.hash_ring` share), linking the verification file. `simulation-reference-review.md` "Review 2026-11-13": one line that §5.1, §5.4 (a), X6 and the zone split are implemented on branch `sim-quick-wins`. `docs/STATUS.md` night 3 row (`:25`): "implemented on branch `sim-quick-wins` (local, not pushed); CI, Windows and browser unverified". Then `python3 tools/roadmap.py` and `--check` exit 0; `sh tools/check_public.sh` exit 0; relative links in changed docs resolve.
- [ ] **Step 2 (gates):** full suite with the four trace variables to `*-final.tsv`, `cmp` each against `*-before.tsv` (V5); static gates; `sh tools/run_conformance.sh`; `sh tools/run_netplay.sh match` (V6), `perturb`, `relay-down`, `relay-term`; `sh tools/run_team_match.sh` (V7); V8; `git diff --stat main -- game/scripts/presentation game/scenes relay protocol game/data .github` empty.
- [ ] **Step 3 (benchmark, alone, last):** `pgrep -fl 'godot|generalszh'` shows none of this run's processes; `uptime`; `PERF_LABEL="Sim quick wins" sh tools/run_benchmark.sh > $L/t8-bench.log 2>&1`. Expected `BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1`, `recorded … rows`; `BUDGET EXCEEDED open hordes300` is the accepted line. Record contact `WORST TICK` against Task 0. No rendered rerun: presentation unchanged (Step 2's diff empty).
- [ ] **Step 4:** resume record names the morning items (see the verification file's "Unverifiable at night").

---

### Task 9: Fresh-context branch review (Opus, high)

- [ ] One fresh Opus (high) reviewer gets `git diff main...HEAD`, the changed paths, this plan's "Review focus", "Determinism notes" and "Same-tick and interaction cases", the verification file, and the instruction to name, per new test (SI1-SI4, HR1-HR3, L6 ring check, desync_diff and bisect tests, the scaling runner's window check), the production change that would make it fail. No repo-wide search.
- [ ] Fix critical and important findings in one round, test-first, by a Sonnet subagent; rerun the affected checks and the full suite with trace `cmp`; list minor findings in the morning summary. Then one `/ponytail-review` pass on the diff (over-engineering only); apply cuts, re-verify.

## Questions, answered (user, 2026-11-13)

All seven took the recommendation.

1. **`fire_defences` index.** The package note says the index also serves `fire_defences`, skipping objects `fire` removed. But `fire`'s removals can also add splash victims: surviving passengers ejected from a dead container, and the unmasked rebuild hole a dead building opens (see "Determinism notes"). Options: (a) `fire_defences` builds its own lazy index (the plan's default; exact; a second build only on ticks where a battery fires); (b) share and rebuild when `fire` removed anything; (c) share and skip removed ids (the note's wording; misses those two cases). **Recommendation: (a)**, simplest exact option, and battery shots are rare. **Answer: (a), own lazy index.**
2. **Scaling sizes.** "50, 100, 200, 400 and 800 units": total (25-400 per side; today's open row is 300 total) or per side (100-1600 total; 1600 does not fit the 64 × 64 open layout's 15 columns without a new shape). **Recommendation: total.** **Answer: total.**
3. **Ring hash function.** (a) engine `hash()` over two packed word arrays (native, fast, engine-defined like today's `state.hash()`); (b) an FNV-1a 64 loop in GDScript over the same words (own spec, Godot-version-proof, roughly 10-40× slower per tick, estimate). **Recommendation: (a)**, with (b) as the fallback if the Task 5 probe fails; the own digest spec in the determinism rules stays the long-term replacement for both. **Answer: (a), engine `hash()`; (b) only if the Task 5 probe fails.**
4. **Ring fields.** "Buildings (hp, progress)" read as construction `work` plus the production queue head's `work`; units as `core_check` (id, owner, hp, position). Add unit `status` or `combat.target_id`? **Recommendation: as written**; more fields cost per tick and the 30-tick digest still covers everything else. **Answer: as written.**
5. **Bisect second-client mode** (`--client-b`: replay on another build or platform, compare the two ring logs with `compare_replays.py`, diff the snapshots at the first divergent tick). About 20 lines on top of the seat mode. **Recommendation: keep**; it is the "glue over `compare_replays.py`" the note names and the only way to diff both sides at the divergent tick. **Answer: keep.**
6. **hordes300 `combat_fire` worst tick.** The profiler pass is already done (Tighter gates night, backup note `~/projects/wargrid-overnight-work/tighter-gates/hordes300-combat-fire.md`): one death fans out into about 20 retaliator `_go_home` move orders, each rescanning every entity in `_unavailable_cells`; a probe fix (a refcounted reservation map) cut that tick's `combat_fire` from 5.40 to 1.07 ms with digests equal. This package only re-reads the zone (evidence only, as the note says). Adopt the fix here, in Flatter worst ticks, or later? **Recommendation: Flatter worst ticks**, with the cross-check test the note asks for; it is a worst-tick fix and this package promised evidence only. **Answer: Flatter worst ticks, with the cross-check test; evidence note [hordes300 combat_fire](../../reference/hordes300-combat-fire.md).**
7. **Contact `combat_fire` target.** Review X1 proposes "contact `combat_fire` max below 2 ms" after the index. Gate or report? **Recommendation: report only**; no budget change without a ledger decision. **Answer: report only.**

## Decisions this plan relies on

- Package scope and "no trace re-pin" (user, 2026-11-13, package note "Sim quick wins").
- §5.4 (b) restore twin stays in the movement milestone (user, earlier; review "Review 2026-11-13").
- Exceeded `open` and `hordes300` rows accepted, never loosened (user, 2026-11-07, performance ledger).
- Per-tick hash on the wire stays a netplay question (review §5.4).
