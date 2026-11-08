# M0 foundation implementation plan

> **For agentic workers:** Use `superpowers:executing-plans` task by task. Follow project instructions for test execution and one final review; no reviewer per task.

**Goal:** a launchable Godot project whose command/state foundation and headless runner are demonstrably correct.

**Architecture:** one `RefCounted` simulation class, one scene calling `step()`, and small explicit test suites. Tests advance simulation directly without waiting for frames.

**Tech stack:** typed GDScript, Godot Compatibility renderer, POSIX shell wrappers, GitHub Actions. No new libraries.

**Spec:** [Kickoff blueprint](../../blueprint.md), especially §§3, 5 and 7.1. This plan specifies M0 details left open there and owns M0 API names, data shapes and concrete acceptance cases.

## Global constraints

- Work in `~/projects/wargrid`. Read `AGENTS.md` and `README.md`; preserve existing files and user changes.
- Use `game/project.godot`; `res://` means `game/`. Compatibility rendering, 30 simulation ticks/second.
- M0 only: move commands record orders without moving entities. No pathfinding, selection, sprites, combat, economy, RNG, event bus, hashing, save/load, fixture parser or multiplayer.
- Checks stay headless. No visible windows, engine installation/upgrades, commits, pushes or PRs without required authorization.
- Source checkout and retail backups are unnecessary for M0. Do not inspect/extract them or depend on them in builds.
- Hell's Verdict references: `tools/run_tests.sh`, `tools/run_game.sh`, `.github/workflows/tests.yml`, and relevant `AGENTS.md` rules. Adapt patterns, not FPS config or its large test suite. Leave sibling project untouched. If unavailable, this plan is sufficient.
- Follow current personal/project skills and model-routing instructions; do not import another project's workflow exceptions.

## Review focus

- Rejection must not partially mutate entities, queues or accepted sequence counters: C5–C7.
- Caller-owned data and returned snapshots must not alias live state: C8–C9.
- Tick boundaries and ordering must not depend on insertion order: C2–C4, C10.
- Empty groups, invalid types and non-finite numbers must be rejected before conversion/indexing: C1, C7.
- Empty tests, runtime errors and early returns must not pass: task 1 probes.

## Task 1 — project and trustworthy runner

**Create:** `game/project.godot`, `game/scenes/main.tscn`, `game/scripts/main.gd`, `game/tests/run_tests.gd`, `game/tests/test_simulation.gd`, `tools/run_tests.sh`, `tools/run_game.sh`, `.gitignore` if absent.

**Scene:** root `Node`, attached `res://scripts/main.gd` extending `Node`, no children/assets. Set `run/main_scene` to `res://scenes/main.tscn` under `[application]`, `renderer/rendering_method` to `gl_compatibility` under `[rendering]`, and `common/physics_ticks_per_second` to `30` under `[physics]`. Connect simulation in task 2.

**Runner interface:**

- `run_tests.gd` extends `SceneTree`; explicitly preload suites, no filesystem discovery.
- Suite extends `RefCounted`; `cases() -> Array[Callable]` returns an explicit list. Each test accepts the runner, performs checks and returns `true` only at its final line. Bare/early returns do not count as completion.
- Runner exposes `check(condition: bool, message: String) -> void`, counts checks and records failures. Messages name case and expected/actual value.
- Each test must execute at least one check and return exactly `true`. Failed checks remain failures even when test returns `true`. Empty suite/case lists fail.
- Only after every case completes without failures, print one final `TESTS PASSED <positive integer>` line and `quit(0)`. Otherwise report failures and `quit(1)`.
- Wrapper requires process success, positive completion marker, and no Godot `ERROR:`/`SCRIPT ERROR:` diagnostics. Check import logs too. A runtime error in one case followed by another passing case cannot produce a green wrapper result. Ordinary invalid game commands return structured errors, not engine diagnostics.

**Wrappers:** POSIX `sh`; resolve absolute repository path from script location. Use `${GODOT_BIN:-godot}` as one quoted executable path; never `eval`. Test wrapper imports headlessly, then runs `res://tests/run_tests.gd`, both with `--path "$repo_root/game"`. Launch wrapper uses `exec`, same path resolution and forwards `"$@"`. No `--fixed-fps 60` and no launch wrapper invocation during tests.

- [x] Run `godot --version`; record result instead of assuming previously observed `4.7.2.stable.official.ed1daf0bf` still applies.
- [x] Create minimal project, runner and temporary positive smoke case. `sh tools/run_tests.sh` must exit 0 and report positive count.
- [x] In a scratch copy in system temporary directory, run each independent failure probe below. Do not alter unrelated user files or add permanent failure-mode switches.

| Probe | Required wrapper result |
|---|---|
| Change true check to false | Nonzero, assertion failure shown |
| Empty suite/case list | Nonzero, zero-tests failure shown |
| Syntax error in test suite | Nonzero, diagnostic shown |
| Test returns before any check | Nonzero, incomplete/empty case shown |
| Test checks once then returns without `true` | Nonzero, incomplete case shown |
| Runtime error inside test | Nonzero even if later tests run |
| Syntax error in `main.gd` during import | Nonzero; import diagnostic not ignored |

- [x] Restore valid baseline, rerun successfully and record probe exit codes. A hanging probe is a runner defect; terminate only your own process and fix it.
- [x] Ignore `.godot/`, build output, `.DS_Store`, `local.env`. Preserve authored scenes and generated `.gd.uid` files. No export/signing setup.

## Task 2 — command/state kernel, test first

**Create:** `game/scripts/simulation/simulation.gd`.
**Update:** `game/tests/test_simulation.gd`, `game/scripts/main.gd`.

### Exact API

```gdscript
extends RefCounted

func spawn(owner: int, position: Vector2) -> int
func issue_command(command: Dictionary) -> Dictionary
func step() -> void
func snapshot() -> Dictionary
```

Fresh instance per match. `spawn` accepts positive owner and finite position, returning increasing IDs starting at 1. Invalid values return `-1`, without state change or consuming an ID. No deletion/ownership-transfer API in M0.

`issue_command` returns `{"ok": true, "error": ""}` on acceptance; otherwise `{"ok": false, "error": <nonempty explanation>}`. Test boolean and explanation presence, not exact prose. Validate all fields before conversion or state mutation. Ignore extra keys; queue only defined fields.

```json
{"tick": 0, "player": 1, "sequence": 0, "type": "move", "entity_ids": [1], "target": [3.5, 4.0]}
```

- `tick`, `player`, `sequence`: actual integers, not floats/strings/booleans. Tick at least current tick; player positive; sequence nonnegative and strictly greater than that player's last accepted sequence (initially -1).
- `type`: string `move`. `entity_ids`: nonempty Array of distinct positive integers, all existing and owned by player. One invalid member rejects whole command.
- `target`: Array of exactly two finite numbers; reject booleans. Normalize coordinates to floats. No map bounds in M0.
- Acceptance stores independent copies and updates player's last accepted sequence. Rejection leaves full snapshot unchanged; rejected sequence can be retried with corrected input.
- `step()` consumes commands for current tick in `(tick, player, sequence)` order, then increments tick once. Future commands remain queued. Revalidate entity existence/ownership before applying whole group; an invalidated command is consumed without changing entity orders. No new public APIs just to expose that future-facing guard.
- Move sets each entity's order to `{"type": "move", "target": [x, y]}`. Position stays unchanged. Later same-tick order replaces earlier order. Accepted sequence is not rolled back after execution.

### Snapshot

Return an independent Dictionary with exactly these fields. Nested arrays/maps cannot alias live state. Build sorted copies without mutating simulation.

```json
{
  "tick": 0,
  "next_entity_id": 2,
  "entities": [{"id": 1, "owner": 1, "position": [1.0, 2.0], "order": null}],
  "pending_commands": [],
  "last_sequences": []
}
```

Entities sorted by ID; pending commands by `(tick, player, sequence)`; `last_sequences` contains `{"player": 1, "sequence": 0}` records sorted by player, only for players with accepted commands. Fresh state: tick 0, next ID 1, three empty arrays. Compare Dictionaries/Arrays directly; no hash or JSON serializer. Preserve fractional values.

### Acceptance cases

Fresh simulation per case unless stated otherwise. Explicitly preload `res://scripts/simulation/simulation.gd`. Write failing behavioral assertions before implementing each group; bootstrap valid syntax/stubs so a parse error is not the only red-test evidence.

| ID / test name | Arrange and act | Required assertions |
|---|---|---|
| C1 `test_spawn` | Spawn owner 1 at `(1,2)`, owner 2 at `(0,0)`. Try owner 0 and non-finite position, then valid spawn. | IDs 1,2; invalid returns -1 with snapshot unchanged; next valid ID 3. Float positions, null orders. |
| C2 `test_tick_zero` | Spawn ID 1; issue example command above; inspect, then step. | Before: tick 0, null order, one pending. After: tick 1, empty queue, target `[3.5,4.0]`, position unchanged. |
| C3 `test_future_tick` | Queue tick 2 move; step twice, inspect, step again. | Tick 2 snapshot still null order and pending command; tick 3 has applied order. |
| C4 `test_same_tick_replacement` | ID 1 receives tick 0 seq 0 target `[3,4]`, then seq 1 target `[8,9]`; step. | Final target `[8.0,9.0]`, position unchanged, last accepted seq 1. |
| C5 `test_atomic_rejection` | IDs 1/2 owned by players 1/2. Player 1 orders `[2]`, `[999]`, `[1,2]`. | Each rejected with explanation and full snapshot unchanged. Corrected seq 0 for `[1]` then succeeds. |
| C6 `test_sequences` | Accept player 1 seq 4; reject 4 and 3; accept 5. Player 2 seq 0 orders its own entity. Step, then submit tick 0 with fresh seq. | Rejection unchanged; independent per-player sequences; past tick rejected. |
| C7 `test_malformed_commands` | Vary one field of valid example at a time. | Reject missing required fields; float/string/bool tick/player/sequence; negative tick/seq; player 0; unsupported type; empty/duplicate/non-array IDs; bool/float ID; wrong-length/non-array/string/bool/non-finite target. Snapshot unchanged. Finite fractional target accepted. |
| C8 `test_command_copy` | Issue command, mutate caller target and ID arrays; step. | Original ID gets original target; queued command unaffected by caller mutation. |
| C9 `test_snapshot_copy` | Mutate returned entity position, pending target and sequence record. Repeat for applied order after step. | Fresh snapshots equal state before external mutations in both cases. |
| C10 `test_canonical_pending_order` | Equivalent worlds enqueue player 2 then 1 versus player 1 then 2; own entities, seq 0 each. | Pre-step snapshots equal with sorted records; post-step snapshots equal. |
| C11 `test_repeatability` | Two worlds: same entity `(1,2)`, tick 0 seq 0 target `[3.5,4]`, tick 3 seq 1 target `[8,9]`; step 1,000 times. | Full snapshots equal; tick 1000, target `[8.0,9.0]`, unchanged position, queue empty, next ID 2, seq 1. No-op implementation fails. |

Example of C2's core assertions (add case name and actual values to diagnostics; other cases follow the table):

```gdscript
func test_tick_zero(runner) -> bool:
    var sim = Simulation.new()
    var id: int = sim.spawn(1, Vector2(1, 2))
    var result: Dictionary = sim.issue_command({
        "tick": 0, "player": 1, "sequence": 0, "type": "move",
        "entity_ids": [id], "target": [3.5, 4.0],
    })
    runner.check(result.ok, "C2 move accepted")
    runner.check(sim.snapshot().entities[0].order == null, "C2 queued, not applied")
    sim.step()
    var state: Dictionary = sim.snapshot()
    runner.check(state.tick == 1, "C2 tick advanced")
    runner.check(state.pending_commands.is_empty(), "C2 command consumed")
    runner.check(state.entities[0].order.target == [3.5, 4.0], "C2 order applied")
    runner.check(state.entities[0].position == [1.0, 2.0], "C2 no movement in M0")
    return true
```

`Simulation` above is the suite's preloaded script constant. This example is specification text, not code already executed or verified.

- [x] Implement C1–C11 and minimal kernel (execution deviation: one acceptance-group red/green run; see [evidence](../../reference/m0-verification.md)). Replace temporary smoke case with real cases. Report case count separately from check/assertion count.
- [x] Main script preloads simulation, creates one instance, calls `step()` exactly once in `_physics_process(_delta)`. No extra accumulator. Main scene needs no entities yet.
- [x] Headless smoke from repo root: `godot --headless --path game --quit-after 5`. Check exit status and diagnostics. This verifies launch, not visuals or exact physics-tick count from five render iterations.

## Task 3 — CI, documentation and handoff

**Create:** `.github/workflows/tests.yml`.
**Update:** `README.md`; `AGENTS.md` only if verified workflow requires correction.

- [x] Verify official Godot release artifact/checksum for local version; do not trust copied Hell's Verdict hash alone. Pin same version in README/CI. If unavailable, continue local work and document CI blocker; no silent engine upgrade.
- [x] One Ubuntu Godot job, `timeout-minutes: 10`, push/PR/manual triggers, verified download, then `sh tools/run_tests.sh`. Retain useful failure logs as artifacts; never upload retail backups. No publishing.
- [x] Run wrapper from repo root and `/private/tmp` using absolute path: identical positive case/check counts. Verify `GODOT_BIN` with absolute path and a temporary executable symlink whose path contains spaces.
- [x] Fresh scratch copy without `.godot` cache must import and pass. Do not delete another session's cache or discard user edits.
- [x] Update README with actual version, commands, results, limits and CI status. Remote CI pending push approval is not remote CI passing; report local implementation and remote gate separately.
- [x] Run required single substantive review and final Ponytail review. Fix findings; re-run affected checks. No duplicate substantive reviewers.
- [x] Report changed files, commands, counts, exit codes, failure-probe evidence, review result and remaining visual/CI/reference gaps. Stop at M0; no automatic M1, commit, push or PR.

## If blocked

Diagnose actual errors; do not weaken tests or remove requirements to get green. Retry after a concrete change or new evidence. Continue independent tasks when possible. If missing information, permission or environment access blocks progress, report exact blocker and ask one focused question. Never invent successful commands, approvals, reviews or game observations.
