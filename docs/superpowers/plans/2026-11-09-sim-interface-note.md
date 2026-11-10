# Simulation interface note Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** approved (user, 2026-11-10), not started; runs as queue item 3 with the [determinism rules plan](2026-11-09-determinism-rules-note.md) (blueprint §7).

**Goal:** One short note names the simulation's public interface (setup and commands in, snapshot and events out), and a Python check stops new test files from reading simulation internals.

**Architecture:** The note `docs/reference/sim-interface.md` lists only what code outside `game/scripts/simulation/` already calls today, with file:line, so it documents the boundary instead of designing a new one. A guard test `tools/test_sim_boundary.py` collects every `_`-prefixed member declared in the simulation scripts and fails when a test file outside a frozen allowlist accesses one through a dot. No game code changes.

**Tech Stack:** Markdown; Python 3 standard library `unittest`; ruff and mypy via `sh tools/run_python_checks.sh`.

**Spec:** [design answers, "Simulation core and state digest"](../../reference/design-answers-2026-11-08.md#simulation-core-and-state-digest-user-2026-11-09-late-evening) bullets 1-2 (user, 2026-11-09 late evening); background [sim core options](../../reference/sim-core-options.md) §2 steps 3-4 and Q1-Q2. Resume record and evidence: `docs/reference/sim-core-no-regret-verification.md` (shared with the [determinism rules](2026-11-09-determinism-rules-note.md) and [state digest](2026-11-09-state-digest-golden-scenarios.md) plans; whichever runs first creates it).

**Model routing:** implementation Sonnet (mid tier); gate review Opus (high), fresh context.

## Global Constraints

- Docs plus one Python test only. No change under `game/`, `relay/` or `protocol/`; no trace or pin changes.
- The guard test `tools/test_sim_boundary.py` with its frozen, shrink-only allowlist is approved (user, 2026-11-10).
- The 26 test files that read internals today are **not migrated** (user: "the 19 existing test files that read internals are not migrated now"; `rg -l 'sim\._[a-z_]+' game/tests` finds 26 on 2026-11-09, the options note's 19 is older). They are frozen in the allowlist.
- The note describes today's surface. It adds no methods, renames nothing and builds no adapter (blueprint §3.9; sim core options "Avoid").
- Units: positions in the interface are cells as floats (`spawn(owner, Vector2(1.25, 1.25))`), not world units; say so in the note.

## Review Focus

- **Note matches code.** Every listed method exists with the stated signature (cite `simulation.gd:<line>`), and every method called from outside the folder is listed. Check: the `rg` in Task 1 Step 1 against the note.
- **Guard catches the real pattern** (`sim._entities[1].hp`, `world.sim._buildings`, `b._tick`) and ignores a test's own helper (`Replay.new()._world(runner)` is a test method, not a sim member) only when the name is not a sim member. Fixture tests in Task 2.
- **Ratchet:** an allowlisted file that no longer reads internals fails the guard until it is removed from the list, so the list only shrinks.

---

## Risk first

1. **The note drifts from the code** the day it lands. Mitigation: derived from `rg`, cited by line, and the guard test makes the boundary executable for tests.
2. **False positives** when a test helper shares a name with a sim private (`_world`, `_tick`). Mitigation: the guard reports file and name; the fix is renaming the test helper, never widening the allowlist for a new file.

## File structure

- Create `docs/reference/sim-interface.md` (about one page).
- Create `tools/test_sim_boundary.py`.
- Modify `AGENTS.md` (one line under "Implementation"), `docs/blueprint.md` §3 "Architecture" (one link line under the diagram).

---

### Task 1: Write the interface note

```text
Task: docs/reference/sim-interface.md lists the public simulation surface with file:line
Owns: docs/reference/sim-interface.md, docs/reference/sim-core-no-regret-verification.md
Invariant: no code change; every entry is called from outside game/scripts/simulation/ today or is a documented setup entry tests need
Boundary: methods that exist only for benchmarks (combat_work, horde_checks, scan_chases, retaliations, navigation_builds, navigation_local_updates, allocation_calls) are listed as "diagnostic counters, not interface"
Red: n/a (docs); the Step 1 rg output is the checklist
Green: every rg hit maps to a note entry; links resolve
Stop: a method outside callers use is private (starts with _) or undocumentable without a code change
```

- [ ] **Step 1: Collect today's surface.**
  Run: `rg -o '\b[a-z_]*(sim|simulation)\.[a-z][a-z_]*\(' game/scripts --glob '!game/scripts/simulation/**' -N | sed 's/.*\.//' | sort | uniq -c | sort -rn` and `rg -n '^(static )?func [a-z]' game/scripts/simulation/simulation.gd game/scripts/simulation/skirmish.gd game/scripts/simulation/map_data.gd game/scripts/simulation/state_hash.gd`.
  Expected on 2026-11-09 (re-check, do not trust): `spawn` 24, `snapshot` 23, `add_player` 21, `issue_command` 15, `tick` 14, `match_over` 7, `step` 6, `add_supply_source` 3, `map_data` 2, then 1 each `team_of`, `start_match`, `replace_blocked_cells`, `remove_object`, `preview_build`, `command_results`, `combat_events`. Also `MapData.create`, `Skirmish.create`, `StateHash.digest`. Copy the counts into the verification file.
- [ ] **Step 2: Write the note** with exactly these sections, each entry one line `name(signature)`, what it is for, `file:line`:
  - **Construct and set up** (before tick 0): `Simulation.new(blocked_cells, size)` (`simulation.gd:52`), `add_player`, `spawn`, `add_supply_source`, `replace_blocked_cells`, `remove_object` (say who calls it and when, per Step 1), `begin_setup` / `setup_seat` / `start_match`, `MapData.create(map, seats)`, `Skirmish.create(...)`.
  - **Commands in:** `issue_command(command) -> {ok, error}` (`simulation.gd:154`); fields `tick, player, sequence, type` plus the payload fields per type from `_payload_fields` (list the types and fields as a table, cite the line). Rule: a command is the only way to change the game after setup; same-tick order is by `sequence` (cite `_command_before`).
  - **Advance:** `step()` (one tick); `tick()`; `match_over()`. Lockstep drives it through `advance(sim)` / `finish_tick(tick, state)` (`lockstep.gd:88, 111`).
  - **State out:** `snapshot()` (`simulation.gd:628`): the top-level keys, sorted entities, and the rule that a snapshot is a deep copy the caller may keep; `StateHash.digest(snapshot)` as the only state fingerprint.
  - **Events out:** `combat_events()`, `command_results()` (and that both also appear in the snapshot).
  - **Read-only queries:** `map_data`, `preview_build`, `occupied_cells`, `team_of`.
  - **Not interface:** `_`-prefixed members; the diagnostic counters (Boundary above); `next_random()` (sim-internal RNG step, public only for tests; say whether any outside caller exists per Step 1).
  - **Rule for tests (user, 2026-11-09):** new tests set up, command and check the game only through the sections above (plus static unit data from `definitions/`); the 26 files in `tools/test_sim_boundary.py`'s allowlist are grandfathered and are migrated only when touched for another reason. One line on why: a native or repacked core can then run the same tests.
  Keep it under about 70 lines. Status label at the top: "Describes the code at <commit>; update in the same change as any public method."
- [ ] **Step 3: Check** every entry against Step 1 (no outside caller missing, no private listed), every `file:line` opens on the named function, links resolve. Create the verification file with the resume record block from `docs/milestone-prompt.md` and one evidence row (commit, Step 1 counts, "docs only, no suite run").

### Task 2: Guard test for new tests

```text
Task: tools/test_sim_boundary.py fails when a non-allowlisted test file reads a simulation private member
Owns: tools/test_sim_boundary.py, AGENTS.md (one line), docs/blueprint.md §3 (one link line), the verification file
Invariant: no change under game/; the allowlist equals the set of test files with hits at this commit
Boundary: a test's own `_helper` whose name is not declared in game/scripts/simulation/ is not a hit; `self._x` is not a hit
Red: test_flags_private_read on the fixture text "var hp = sim._entities[1].hp" with a fake private set {"_entities"} fails before the function exists (ImportError is not enough: write the fixture tests first, then run them against a stub that returns [])
Green: python3 -m unittest discover -s tools -p 'test_sim_boundary.py' and sh tools/run_python_checks.sh pass
Stop: a hit appears in a file created after 2026-11-09 (it must be fixed, not allowlisted: ask)
```

Rules the implementer cannot infer:
- `private_names(root) -> set[str]`: every name matching `^\s*(static\s+)?(var|const|func)\s+(_[a-z0-9_]+)` in `game/scripts/simulation/**/*.gd`.
- `hits(text, names) -> list[str]`: strip `#` comments per line (as `tools/test_sim_math.py:violations` does), then every `(?<!self)\.(_[a-z0-9_]+)\b` whose group is in `names`.
- `ALLOWLIST: frozenset[str]` of file names under `game/tests/` (`*.gd`, fixtures included) that have hits at this commit, generated once with the two functions and pasted sorted, one per line.
- Tests: `test_flags_private_read` (fixture text above → `["_entities"]`), `test_ignores_own_helper` (`Replay.new()._world(runner)` with names `{"_entities"}` → `[]`), `test_ignores_comment` (`# sim._entities` → `[]`), `test_new_files_clean` (every test file not in `ALLOWLIST` has no hits; message names file and members), `test_allowlist_still_needed` (every allowlisted file still has hits, so the list only shrinks), `test_private_names_found` (the real set contains `_entities` and `_buildings`, so an empty glob cannot pass).

- [ ] **Step 1:** Write the six tests with a stub module body; run `python3 -m unittest discover -s tools -p 'test_sim_boundary.py' -v`. Expected: `test_flags_private_read` and `test_private_names_found` FAIL.
- [ ] **Step 2:** Implement the two functions; generate and paste `ALLOWLIST`; run again. Expected: all six pass. Record the allowlist size (expected 26, re-check) and any file that differs from `rg -l 'sim\._[a-z_]+' game/tests` with the reason.
- [ ] **Step 3:** Mutation check (scratch copy only, never the tree): add `var x = sim._entities` to a copy of a non-allowlisted test file in a temp directory pointed at by a patched root, confirm `test_new_files_clean` fails; record the line.
- [ ] **Step 4:** `AGENTS.md` "Implementation": one line, "New tests use only the [simulation interface](docs/reference/sim-interface.md); `tools/test_sim_boundary.py` enforces it." Blueprint §3 under the architecture diagram: one link line to the note. Run `sh tools/run_python_checks.sh` (exit 0) and update the resume record.

## Stop gate and exit

Exit gate (end of Task 2): docs and Python only, so no Godot suite or benchmark is required (state that in the verification row, with the tree). Opus (high) fresh-context gate review of the diff against this plan: note matches code, guard rules, allowlist exactness; it names for each new test the change that makes it fail. Then `/ponytail-review` on the diff. Stop: commit, push and merge wait for the user.

Stop conditions: see the task contracts; also any need to change a public method's signature to describe it.
