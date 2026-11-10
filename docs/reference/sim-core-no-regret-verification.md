Resume record (created 2026-11-10 by the coordinator; shared by the sim interface, determinism rules and state digest plans)
Branch / base commit / working-tree state: main / 874c6a3 / clean
Last green task / next incomplete task: interface Task 2 (gate review pending) / interface gate review (determinism Tasks 1-2 done and gate-reviewed; next: ponytail review, then commit)
Changed paths since last commit (both plans): docs/reference/sim-interface.md (new), docs/reference/determinism-rules.md (new), tools/test_sim_boundary.py (new), tools/test_sim_math.py, AGENTS.md, docs/blueprint.md
Last command / cases / checks / failures / exit / marker: none yet
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: both plans approved (user, 2026-11-10); local commits pre-authorized; push of main waits for the user's playtest
Next exact action: none; both notes committed locally, main push waits for the user's playtest. Previously: ponytail review of both diffs, then commit (local commits pre-authorized)

## Evidence rows (append-only)

### 2026-11-10 interface plan, Task 1 (tree 874c6a3 + untracked verification file)
Docs only, no suite run. Created `docs/reference/sim-interface.md`. Outside-caller counts (`rg` of Step 1; differs from the plan's 2026-11-09 expectation): snapshot 31, spawn 26, add_player 23, tick 19, issue_command 16, step 10, match_over 7, combat_events 6, command_results 5, add_supply_source 4, map_data 2, 1 each team_of, start_match, replace_blocked_cells, remove_object, preview_build. Extra: remove_object and diagnostic counters also have test callers; `begin_setup`, `setup_seat`, `occupied_cells` have no outside caller; `next_random` one (test_combat.gd:1183). Test files matching `sim\._[a-z_]+` now 27, not 26 (Task 2 settles the allowlist). Leaks (corrected by the gate review): debug/combat_workload.gd and movement_workload.gd read and write sim privates; net/headless_client.gd:171 writes `_sim._players`.
| 2026-11-10 determinism rules Task 1 (874c6a3, docs only, no suite run) | Checked on tree: xorshift `simulation.gd:49-63`, `rng` in snapshot `:648`, sorted snapshot `:636-645`, `_command_before` `:308`, 65 `Vector2(` in 14 files, `start_spots.gd:19-28`, `match_settings.gd:33`, A* settings `grid_navigation.gd:20-25`, no `Time`/`OS`/`Engine` in simulation/, desync dump `online_main.gd:87`, `headless_client.gd:214`, lockstep interval `lockstep.gd:34`. Wrote `docs/reference/determinism-rules.md`; digest spec marked specified-not-implemented | Note: `JSON.stringify` folds `-0.0` to `0.0` (research §3), spec uses `x + 0.0` so they agree. Task 2 (static check) not started; gate review pending |

### 2026-11-10 interface plan, Task 2 (tree 874c6a3 + untracked/modified docs, tools/test_sim_boundary.py new)
Docs and Python only, no Godot suite run. Red: stub `hits` returning [] failed `test_flags_private_read` (`test_private_names_found` already passed because `private_names` was real in the stub). Green: 6 tests pass (`python3 -m unittest`). The `run_python_checks.sh` exit 0 covered ruff and mypy only: `run_python_tests.sh` picks tests from `git ls-files`, and the file was untracked (gate review); the coordinator reruns after `git add`. ALLOWLIST has 30 files, not 26/27: the 27 from `rg 'sim\._[a-z_]+'` plus `test_announcer.gd:291` (`skirmish.simulation._players`), `test_factions.gd:285,289` (`Skirmish._default_map()`, a static private) and `test_art_lab.gd:134` (`variants._tick`, a name collision with sim `_tick`, false positive; renaming needs a change under game/tests, left alone). Mutation: copy of `combat_fixture.gd` (not allowlisted) with `var x = sim._entities` in a scratch tree made `test_new_files_clean` fail naming the file and `['_entities']`. Out of scope: the non-test leaks listed in the note. AGENTS.md and blueprint §3 link lines added. Gate review and ponytail-review pending.

### 2026-11-10 determinism rules plan, Task 2 (tree 874c6a3 + modified/untracked docs and tools)
Python and docs only, no Godot suite run. Step 1 scratch run over `game/scripts/simulation/*.gd`: hits only `start_spots.gd:19,27,28` (RNG) and `state_hash.gd:12` (`state.hash()`); no CLOCK hit. Red: the first of the four positive asserts failed (`[] is not true`) before the patterns; unittest stops at the first failure. Green: `test_sim_math.py` 2 tests OK; `sh tools/run_python_checks.sh` exit 0, "PYTHON TESTS PASSED". Two exemptions, each with a why comment. AGENTS.md and blueprint §3 item 4 link lines added. Gate review and ponytail-review pending.

### 2026-11-10 Interface gate review (tree: main 874c6a3 plus both plans' diff)

Opus (high), fresh context: FAIL on doc wording only. Allowlist exact (30 files), all citations land, guard logic right. Coordinator fixed: snapshot copy wording (route, map, terrain_cells are shared read-only), counters "benchmarks and tests only", all non-test leaks named, and the Task 2 row's python-checks claim. Rerun after `git add`: `sh tools/run_python_checks.sh` exit 0, PYTHON TESTS PASSED, now including test_sim_boundary.py.

### 2026-11-10 Determinism gate review fixes (tree 874c6a3 + modified/untracked docs and tools)
Opus gate review FAIL on small fixes, applied: `.keys()` sites re-checked with sed (containers/construction/production sorted; combat 370, 414 and simulation 329 unsorted), `last_sequences` wording, stale clause removed, NaN/non-String key detectable only in GDScript, digest details (a)-(h) added, all marked provisional. `test_sim_math.py` now `rglob`; without exemptions only `start_spots.gd` (RNG) and `state_hash.gd` (`.hash()`) hit. `assertFalse(violations("var t = MyTime.get()"))` already passed (the regex `\b` rejects `MyTime.`), so no red run. Verification rows corrected (Task 2 red run, resume record).

### 2026-11-10 Ponytail review and exit (tree: main 874c6a3 plus both plans' diff)

Lean pass: Ship. Applied cuts 1-4 (duplicated fixed-point, threads and dump text now link design answers and the ledger). Skipped 5-6 (one-line merges, not worth it). `sh tools/run_python_checks.sh` exit 0, PYTHON TESTS PASSED. No change under game/, relay/ or protocol/. Both plans at their exit gate.
