# c1 Dock Rebuild Implementation Plan

**Status:** written 2026-11-12 night for an unattended Sonnet-coordinated run; the plan's choices were settled by the user (2026-11-12), see "Decisions" at the end.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. Run rules: [night run](../../night-run.md#coordinator-rules) and [milestone prompt](../../milestone-prompt.md); resume record: [c1 dock rebuild verification](../../reference/c1-dock-rebuild-verification.md). Every task subagent also reads "Global Constraints" and, for Tasks 2-4, "Pinned values expected to change" (`rg -n '^## ' <plan>`).

**Goal:** Make c1 Wargrid's only dock rule: a collector's stand at a pile or depot keeps today's length, but only a per-kind lock window at its end is exclusive; the lead before it overlaps other collectors. FRC income leaves hold's per-pile cap (frc7 close 1590 to about 2550; Zero Hour 2850).

**Architecture:** Lock windows are capability data in each collector's `collects` row (`lock.source.lead/box`, `lock.depot.lead/work`) under `definitions/`. `supply_collection.gd` gains one non-exclusive phase per target (`lead_source`, `lead_depot`) before the existing admit; there is no model switch. The gated multi-collector targets move to the re-measured steady window in the same branch.

**Tech Stack:** typed GDScript (Godot 4.7.2), the suite runner `game/tests/run_tests.gd`, `sh tools/run_*.sh`.

**Spec:** design answers "Dock option C follow-up" and "frc7 gap follow-up" (user, 2026-11-12 night) and the [dock-hold note](../../reference/dock-hold-experiment.md) sections "Option C and saturation", "What c1 and c2 are", decision items 1, 3, 5, 6. Both arrive on this branch in Task 1 (until then: `git -C ~/projects/wargrid-wt-dock show dock-hold:docs/reference/dock-hold-experiment.md`). Numbers source: `game/scripts/experiments/dock_c.gd` (`RATIOS` c1) and `dock_split.gd` (depot lead/work) on branch `dock-hold`. Expected rows: `~/projects/wargrid-dock-work/c/wargrid-c1.txt`.

## Global Constraints

- Worktree `~/projects/wargrid-wt-c1`, branch `c1-dock-rebuild` (base `main` c2ea952). The run (coordinator and every subagent) uses `~/projects/wargrid-wt-c1`; `~/projects/wargrid-wt-dock` is only read. Agent shells reset their working directory: start every command with `cd ~/projects/wargrid-wt-c1 && ` and give log paths in full. Branch `dock-hold` is read-only evidence; no code from `game/scripts/experiments/`, `dock_queue.gd`, `dock_metrics.gd` or `dock_probe.gd` comes over.
- One dock rule, no `dock_model` switch, no faction branch: kind literals only under `game/scripts/simulation/definitions/` (`tools/test_faction_guard.py`).
- c1 numbers (source of truth; Task 2 pins them): per-load box = `round(ceil(boxes x box_value x 184 / 300) / (boxes + 1))` ticks, source lead = `(boxes + 1) x load_ticks - (boxes + 1) x box`; depot lead + work = `unload_ticks`, work = Zero Hour depot lock clipped to the stand (split's table).

  | kind | source lead / box (lock) | depot lead / work |
  |---|---|---|
  | `frc_builder` (boxes 1, load 42, unload 45) | 38 / 23 (46) | 6 / 39 |
  | `china_collector` (boxes 4, load 38, unload 37) | 5 / 37 (185) | 0 / 37 |
  | `usa_collector` (boxes 8, load 43, unload 213) | 18 / 41 (369) | 60 / 153 |

- Lone full-load cycles stay identical to the tick (lead + lock = today's stand). A partial load (pile running out) stands `lead + (k + 1) x box`, not `(k + 1) x load_ticks`; that is the rule, pinned in Task 2.
- New tests use only the [simulation interface](../../reference/sim-interface.md) plus `definitions/` data (`tools/test_sim_boundary.py`); files already on its allowlist (`test_supply.gd`, `test_supply_parity.gd`, `test_skirmish_scene.gd`) keep their style. [Determinism rules](../../reference/determinism-rules.md): integer ticks, ordered containers.
- Accepted margins (user, 2026-11-12): USA overshoot up to +5 %; frc7 close and far rows reported, not judged.
- **Trace rule (pre-authorized, user, 2026-11-12):** only the traces in "Pinned values expected to change" below may be regenerated, each with old and new value recorded in the verification file. A changed winner, a match leaving its window, or any unlisted trace or pinned value change parks the task.
- Every suite, benchmark, lint and netplay call: Bash `timeout: 600000`, output to a file under `~/projects/wargrid-dock-work/c1/` (created at plan review), judge by exit code and summary lines (`CASES … CHECKS … FAILURES …`, `TESTS PASSED`). On failure read only `rg -n 'FAIL|SCRIPT ERROR|ERROR:' <log>`.
- Denied at night: push, merge, PR, `fly`, `sh tools/deploy_web.sh`, `sh tools/run_game.sh` (no rendered benchmark, no window). Subagents never commit; the coordinator makes one local commit after each GREEN task, pre-authorized (user, 2026-11-12); never push.
- Edit with the Edit tool or asserted replacements only; scratch Godot scripts `quit()` on every path.

## Pinned values expected to change (the only ones Task 4 may regenerate)

Regenerate each with the command given; the failure line prints the new value (`rg -n 'FAIL' <log>`). Record old, new and the reason ("collector stands overlap under c1") per row.

| # | Where | Old | Must still hold | Regenerate |
|---|---|---|---|---|
| P1 | `game/tests/test_skirmish_match.gd` `S1_CORE_SERIES` | 6600229479106917126 | — | `WARGRID_TEST_ONLY=test_skirmish_core_series sh tools/run_tests.sh` ("S1 core series pinned, got …") |
| P2 | same file `TERMINAL_TICK` | 8569 | `WINNER` 1; 7000 <= terminal <= 17999 | `WARGRID_TEST_ONLY=test_mirror_match_script` ("S1 pinned outcome, got …"); P1 uses the same constant: rerun P1 after |
| P3 | same file `CHINA_TERMINAL_TICK` | 11220 | `CHINA_WINNER` 2; status won inside `CHINA_TICK_CAP` 45000; "Cs1 horde level 2, ramp level 2, truck delivery and a quantity pair all happened" passes | `WARGRID_TEST_ONLY=test_china_skirmish_match` ("Cs1 pinned outcome, got …") |
| P4 | same file `FRC_TERMINAL_TICK` | 48051 | `FRC_WINNER` 1; status won inside `FRC_TICK_CAP` 50000 | `WARGRID_TEST_ONLY=test_frc_skirmish_match` ("Fm1 pinned outcome, got …") |
| P5 | `game/tests/test_team_match.gd` `FINAL_DIGEST` | 91106ae278c29044 | TB3 builds, tank, 100 rows, no divergence | `WARGRID_TEST_ONLY=test_team_match_prefix` ("TB3 final digest …") |
| P6 | same file `TEAM_CORE_SERIES` | 1748824102688385527 | — | `WARGRID_TEST_ONLY=test_team_core_series` ("TB4 … got …") |
| P7 | `game/tests/test_view_rows.gd` `EXPECTED_DIGEST` | 6882f9ca…0880 | fixture unchanged | `WARGRID_TEST_ONLY=test_view_reads_digest_is_pinned` ("VR1 view reads digest, got …") |
| P8 | `game/tests/test_skirmish_scene.gd` `HUD_TEXTS` | 6 strings | "HUD1 fixture: every case has its unit" passes unedited | `WARGRID_TEST_ONLY=test_hud_summaries_are_pinned` ("HUD1 pinned summary texts, got …") |
| P9 | `tools/run_team_match.sh` line 13 `units_peak=261` | 261 | `won tick=39497 winner=2 units_peak=271`: won inside the 45000 cap, winner 2 (user, 2026-11-13) | `sh tools/run_team_match.sh > LOG 2>&1` (prints `TEAM MATCH …`) |
| P10 | `tools/run_netplay.sh` line 91 `9024` | 9024 | both peers and the oracle agree, `match_over` | `sh tools/run_netplay.sh match > LOG 2>&1` ("terminal tick X, pinned 9024"; night run approved (user, 2026-11-12)) |

Expected unchanged (a change parks): `test_state_hash.gd` `PINNED` (no collector in that world), `test_world_batch.gd` `GOLDEN_*` (static state), `test_start_spots.gd` `SS6_PINNED`, `test_map.gd` MP3, `test_replay.gd` (repeatability only, no stored trace), single-collector `TARGETS` rows in `test_supply_parity.gd` (rates identical to the digit). Cross-OS CI traces compare one commit with itself; they need a CI run after push (user, morning).

Spec tests rewritten by rule (Task 2, values in its table, not traces): `test_supply.gd` Su2, Su4, Su6 (unloading), Gt1, Gt2, Lb1, Gd11, Sp1, Sp3, Sp4; fixture `_pile_world` in `test_skirmish_scene.gd`. Targets moved by decision (Task 3): `MULTI` and `FOUR_HELICOPTERS_GAP_9` in `test_supply_parity.gd`.

## Review Focus

1. **Pile emptied by another collector during a lead:** the lead-ender must never load or hold a lock (DL7, Task 2).
2. **Partial loads** (small piles, `delete_when_empty`, last box): stand = lead + (k + 1) x box (Sp1, Gt2, Gd11 rewritten, Task 2).
3. **Same-tick lead end:** two leads ending on one tick give the lock to the lower id, also for a mixed air/ground pile, not `_ahead`'s air-first order (DL4, Task 2; decided (user, 2026-11-12)).
4. **A collector in its lead is neither docked nor waiting** in view rows, the pile label and the HUD line (`lead_source` shows as the phase text) (DL9, Task 2; no presentation change, decided (user, 2026-11-12)).
5. **Benchmark mechanics:** `docks` still needs queued trucks inside the window (`waiting_ticks_window > 0`); c1 shortens waits (Task 5 records the line).

## Risks and model routing

Riskiest contract first: the lock rule against every collector command on the same tick (Task 2, Opus). Thin margins, measured: Chinook x2 steady +4.3 % and Laborer x4 -4.3 % against 5 %.

| Task | What | Model |
|---|---|---|
| 1 | Baseline, docs from `dock-hold`, lone-cycle pin | Sonnet |
| 2 | c1 lock data and rule, spec tests, hold-timing checks rewritten | **Opus (high)**: same-tick matrix, rule-derived timing values |
| 3 | MULTI targets on the steady window | Sonnet |
| 4 | Re-pin listed traces | Sonnet |
| 5 | Headless benchmark and ledger row | Sonnet |
| 6 | Docs: economy guide, status, note | Sonnet |
| 7 | Exit checks on the final tree | Sonnet |
| 8 | Fresh-context branch review and lean pass | **Opus (high)** |

---

### Task 1: Baseline, docs from dock-hold, lone-cycle pin

```text
Task: record the baseline; bring the decision docs; pin today's lone collector cycles.
Owns: docs/reference/dock-hold-experiment.md, docs/reference/design-answers-2026-11-08.md, game/tests/test_dock_lock.gd (new), game/tests/run_tests.gd, the verification file.
Invariant: no game behaviour change; full suite green.
Boundary: the pin passes on main and fails on a one-tick change to a load delay.
Red: DL0 fails under a scratch mutation (frc load_ticks 42 -> 43).
Green: WARGRID_TEST_ONLY=test_dock_lock; full suite.
Stop: suite not green on the untouched tree; INCOME lines differ from wargrid-hold.txt; the docs import conflicts with lines main has that dock-hold lacks.
```

**Files:** Create `game/tests/test_dock_lock.gd` (+ its generated `.gd.uid`); modify `game/tests/run_tests.gd` (append `preload("res://tests/test_dock_lock.gd")` as the last `SUITES` entry), `docs/reference/dock-hold-experiment.md`, `docs/reference/design-answers-2026-11-08.md`.

- [ ] **Step 1: Baseline.** `sh tools/run_tests.sh > ~/projects/wargrid-dock-work/c1/t1-baseline.log 2>&1; echo "exit=$?"`. Expected `TESTS PASSED`, exit 0. Record CASES / CHECKS. Then `WARGRID_TEST_ONLY=test_income_openings sh tools/run_tests.sh > ~/projects/wargrid-dock-work/c1/t1-income.log 2>&1`; then `cd ~/projects/wargrid-dock-work/c1 && rg '^INCOME' t1-income.log > t1-income-lines.txt && rg '^INCOME' ../wargrid-hold.txt | sed 's/ model=hold$//' > t1-hold-lines.txt && diff t1-income-lines.txt t1-hold-lines.txt`. Expected: no output (8 lines each).
- [ ] **Step 2: Docs (decided (user, 2026-11-12)).** Replace the note with dock-hold's version: `git -C ~/projects/wargrid-wt-c1 show dock-hold:docs/reference/dock-hold-experiment.md > docs/reference/dock-hold-experiment.md`. Append dock-hold's two sections to the end of main's design answers, after main's "Dock-hold experiment (user, 2026-11-12)" section: `git -C ~/projects/wargrid-wt-c1 show dock-hold:docs/reference/design-answers-2026-11-08.md | sed -n '/^## Dock option C follow-up/,$p'`, appended with a blank line between. Verify: `rg -n '^## ' docs/reference/design-answers-2026-11-08.md | tail -3` shows "Dock-hold experiment", "Dock option C follow-up", "frc7 gap follow-up"; `git diff --stat` shows only additions in the design answers; `rg -n '^## ' docs/reference/dock-hold-experiment.md` includes "Option C and saturation (2026-11-12)" and "Decision list for the user". Before replacing, `git diff main dock-hold -- docs/reference/dock-hold-experiment.md | rg -c '^-[^-]'` must print 10 (main's old answer, decision items 1, 5, 6 and Reproduce lines, which dock-hold rewrote; counted 2026-11-12); another count means main gained text since: STOP.
- [ ] **Step 3: DL0 test.** `test_lone_cycles_pinned`: for each kind in `["usa_collector", "china_collector", "frc_builder"]` and gap in `[3, 9]`, `Parity.new().layout(kind, gap, 1).sim` (`const Parity = preload("res://tests/test_supply_parity.gd")`), step up to 30000 ticks and record the `view_state().tick` of the first 9 credit changes (`view_state().players[0].credits`). Check equality with `const LONE_DEPOSITS := {kind: {gap: [9 ticks]}}`. Message: `"DL0 a lone %s at gap %d deposits on the same ticks as before c1, got %s"`. First run prints the lists (`print("DL0 %s gap %d %s" % …)`); paste them into `LONE_DEPOSITS`, then remove the print. Header as other tests (`@warning_ignore_start("untyped_declaration")`, `extends RefCounted`, `cases()`).
- [ ] **Step 4: Red by mutation.** Edit `frc.gd` `"load_ticks": 42` -> `43`, run `WARGRID_TEST_ONLY=test_dock_lock`, expect DL0 FAIL for `frc_builder` only; revert with Edit; `git diff --stat game/scripts` empty.
- [ ] **Step 5: Green.** `WARGRID_TEST_ONLY=test_dock_lock` exit 0; full suite exit 0 (CASES baseline + 1); `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/run_python_checks.sh`, `sh tools/check_public.sh` exit 0. Update the resume record and evidence rows.

---

### Task 2: c1 lock data and rule (Opus)

```text
Task: one dock rule: lead (not exclusive), then the lock window (exclusive) at piles and depots.
Owns: definitions/usa.gd, china.gd, frc.gd (collects rows), supply_collection.gd, game/tests/test_dock_lock.gd, game/tests/test_supply.gd, game/tests/test_skirmish_scene.gd (_pile_world only).
Invariant: DL0 unchanged; single-collector TARGETS rows unchanged; INCOME lines equal the c1 evidence.
Boundary: every collector command and every removal on the tick a lead would end and while locked.
Red: DL1-DL5, DL7, DL9 and DL8's lead rows fail on the Task 1 tree (no lock data, no lead phase); DL6 and DL8's locked rows may already pass there (they guard the lock release).
Green: test_dock_lock, test_supply.gd, test_skirmish_scene (S1 pile labels), test_supply_parity single rows, test_income_openings lines.
Stop: INCOME lines differ from wargrid-c1.txt; a test_supply check outside the table below fails; a rewritten value differs from the table and your own derivation from the rule disagrees with the measurement; DL0 fails; a DL1-DL9 expectation fails with Step 4's code exactly as given (never change the expectation or the rule to make it pass).
Known red after this task (fixed in Tasks 3 and 4, record them): test_multi_collector_rates (old window), P1-P8.
```

**Interfaces produced:** `Registry.collects(kind).lock` = `{"source": {"lead": int, "box": int}, "depot": {"lead": int, "work": int}}`; collection phases `lead_source`, `lead_depot` (non-exclusive, counting `remaining_ticks`, not in `_admit`'s waiting set, no `WAITING_SOURCE` flag).

- [ ] **Step 1: Failing spec tests in `test_dock_lock.gd`** (interface only; read phases from `view_state().units` as `units.phases[units.phase[i]]`, cargo, `target_id` and `remaining_ticks` from `snapshot().entities[*].collection`). Consts: `Fixture = preload("res://tests/economy_fixture.gd")`, `Registry = preload("res://scripts/simulation/definitions/definitions.gd")`. Helpers: `phases_of(view) -> Dictionary` (id to phase; copy `dock-hold:game/tests/test_dock_models.gd` `phases_of`), `pair_world(boxes: int, delete_when_empty: bool, extras: bool = false) -> Dictionary`: `Fixture.make_world(10000, Vector2i(48, 24))`, `Fixture.add_completed(sim, 1, "frc_supply_center", Vector2i(2, 10))`, pile `sim.add_supply_source(Vector2i(8, 9), boxes, Vector2i(4, 5), delete_when_empty)`, laborers (`sim.spawn(1, …, "frc_builder")`) at `Vector2(7.5, 10.5)` and `Vector2(7.5, 12.5)`, when `extras` the DL8 objects below, then one `gather` for both; returns `{sim, source, first, second}` plus `hub`, `other` when `extras` (first = lower id). Every case first asserts it reached the state it tests (a lead tick seen, a holder and a waiter seen), so none passes vacuously. Cases (add to `cases()`):
  - `test_lock_data_follows_the_rule` (DL1): for each kind, with `c := Registry.collects(kind)`, `loads := c.boxes + 1`, `earned := (c.boxes * c.box_value * 184 + 299) / 300`, `box := (2 * earned + loads) / (2 * loads)` (integer division, `@warning_ignore("integer_division")`): `c.lock.source.box == box`, `c.lock.source.lead == loads * c.load_ticks - loads * box`, `c.lock.source.lead >= 0`, `c.lock.depot.lead + c.lock.depot.work == c.unload_ticks`; and the table in Global Constraints exactly. Message "DL1 %s pile lock is %d ticks per load from 184 ticks per 300 credits, got %s".
  - `test_lone_lock_window` (DL2): per kind, `Parity.new().layout(kind, 3, 1).sim`; record runs of consecutive phases of the collector for 3000 ticks; the first source visit is `lead_source` x `lock.source.lead` then `loading` x `loads * lock.source.box`; the first depot visit is `lead_depot` x `lock.depot.lead` then `unloading` x `lock.depot.work`; a zero lead has no lead run (truck depot). "DL2 a lone %s stands lead %d then holds the pile %d ticks".
  - `test_lead_is_not_exclusive` (DL3): mirror of `test_split_overlaps_lead_in` (`Parity.new().layout("frc_builder", 3, 2).sim`), 1500 ticks: some tick has one `loading` and at least one `lead_source`; no tick has two `loading` or two `unloading`.
  - `test_two_leads_end_on_one_tick` (DL4): `pair_world(400, false)`: both leave `lead_source` on the same tick; then first is `loading`, second `waiting_source` ("the lower id takes the lock"). Mirror of `test_split_same_tick_arrival` in `dock-hold:game/tests/test_dock_models.gd`. Mixed pile (decision 1), same case: world as `pair_world` but spawn one laborer at `Vector2(7.5, 10.5)` first, then a `usa_collector` at the pile centre `Vector2(10.0, 11.5)`; gather only the laborer; step until it is `lead_source` with `remaining_ticks == 19`, then gather the Chinook (due this tick; its 18-tick lead then ends on the laborer's tick). Check both leave `lead_source` on one tick, then the laborer is `loading` and the Chinook `waiting_source` ("DL4 mixed pile: the lower id takes the lock, not air first").
  - `test_stop_during_lead` (DL5): mirror of `test_split_stop_during_lead` (stop first while `lead_source`; second still reaches `loading`; first never again in `lead_source`, `waiting_source`, `loading`).
  - `test_removal_while_locked` (DL6): mirror of `test_split_release_on_removal` (remove holder: waiter `loading` after one step; stop holder: same; `pair_world(1, true)`: after the pile vanishes no collector is in `lead_source`, `waiting_source` or `loading`).
  - `test_pile_empties_during_lead` (DL7): `pair_world`-like world with 1 box and `delete_when_empty` false (the pile stays at 0 boxes), second laborer spawned one cell further west (`Vector2(6.5, 12.5)`) so it is still in its lead when first takes the box. Precondition check: some tick shows second in `lead_source` while `view_state().sources` has the pile at 0 boxes (if not, move the spawn within `x` 5.5-6.5 until it holds; never drop the check). Then: second is never `loading`, its cargo stays 0.
  - `test_commands_in_lead_and_lock` (DL8), the same-tick matrix. For state `lead`: step the world until first is `lead_source` with `remaining_ticks == 1`, then send the command (due this tick; it applies in the step in which the lead would end). For state `locked`: step until first is `loading` and second `waiting_source`, then send. Fresh world per row, `pair_world(400, false, true)`; its extra objects, added before the gather: `hub := Fixture.add_completed(sim, 1, "frc_defence", Vector2i(30, 18))`, `other := sim.add_supply_source(Vector2i(24, 9), 400)`. Rows and expectations after one `step()` (and 300 more ticks where stated):

    | row | payload for first | lead | locked |
    |---|---|---|---|
    | move | `move` to `[20.5, 20.5]` | accepted; first never `loading` at this pile in 300 ticks; second `loading` within 1 step of its lead end | accepted; second `loading` after the step |
    | stop | `stop` | as move | as move |
    | attack_move | `attack_move` to `[20.5, 20.5]` | as move | as move |
    | enter | `enter`, `target_id` hub | as move | as move |
    | build | `build`, `builder_id` first, `building_kind` `frc_supply_center`, `origin` `[30, 2]` | as move | as move |
    | resume_build | `resume_build`, `builder_id` first, `building_id` a foundation left by a third laborer spawned at `Vector2(34.5, 6.5)` right after `pair_world` (`build` as above, one `step()`, then `stop` it) | as move | as move |
    | gather other | `gather`, `source_id` other | first `target_id == other` after the step; second as move | same; second `loading` after the step |
    | gather same | `gather`, `source_id` source | first `lead_source` with `remaining_ticks == lock.source.lead` after the step (lead restarts); second takes the lock first | lock freed: second `loading` after the step; first `lead_source` restarted |
    | attack | `attack`, `target_id` hub | `Fixture.send` result not ok ("Attack requires armed units"); the step runs as without a command: first `loading`, second `waiting_source` | rejected; first still `loading`, second `waiting_source` |
    | remove actor | `sim.remove_object(first)` instead of a command | second `loading` within 1 step of its lead end | second `loading` after the step |
    | remove pile | `sim.remove_object(source)` | both `target_id` null, cargo unchanged | same |

    Plus one depot row: a laborer in `lead_depot` with cargo 1 when its depot is removed keeps cargo 1 and `target_id` null after the step. Message format "DL8 %s during %s: …".
  - `test_lead_is_not_queued_in_view` (DL9): during a `lead_source` tick the unit's `units.queue[i] == -1` and `units.flags[i] & ViewRows.WAITING_SOURCE == 0` (`const ViewRows = preload("res://scripts/simulation/view_rows.gd")`).
- [ ] **Step 2: Red.** `WARGRID_TEST_ONLY=test_dock_lock sh tools/run_tests.sh > ~/projects/wargrid-dock-work/c1/t2-red.log 2>&1`: assertion failures only (DL1 fails on the missing `lock` key: guard with `c.has("lock")` checks so it reports, not crashes), no `SCRIPT ERROR`, DL0 passes.
- [ ] **Step 3: Lock data.** In `collects` of each row, append the `lock` entry after `"box_value": 75`:
  - `usa.gd`: `"box_value": 75}` -> `"box_value": 75, "lock": {"source": {"lead": 18, "box": 41}, "depot": {"lead": 60, "work": 153}}}`
  - `china.gd`: `"box_value": 75}` -> `"box_value": 75, "lock": {"source": {"lead": 5, "box": 37}, "depot": {"lead": 0, "work": 37}}}`
  - `frc.gd`: `"box_value": 75}` -> `"box_value": 75, "lock": {"source": {"lead": 38, "box": 23}, "depot": {"lead": 6, "work": 39}}}`
  (each file has exactly one `"box_value": 75}`; assert with `rg -c`). `load_ticks` / `unload_ticks` stay as the stand (DL1 uses them).
- [ ] **Step 4: Rule in `game/scripts/simulation/supply_collection.gd`.**
  - `_admit`, insert directly before `var waiting_before: bool = false`:
    ```gdscript
    	var lock: Dictionary = Registry.collects(unit.kind).lock
    	var lead: int = lock.depot.lead if depot else lock.source.lead
    	# Only the lock window is exclusive; the lead overlaps other collectors, as Zero Hour's dock grants do.
    	if lead > 0 and collection.phase.begins_with("flying_"):
    		collection.phase = "lead_depot" if depot else "lead_source"
    		collection.remaining_ticks = lead
    		sim._stop_unit(unit)
    		return
    ```
    and replace `collection.remaining_ticks = Registry.collects(unit.kind).unload_ticks if depot else Registry.collects(unit.kind).load_ticks` with `collection.remaining_ticks = lock.depot.work if depot else lock.source.box`.
  - `step`, replace `		if collection.phase == "loading":` with
    ```gdscript
    		if collection.phase.begins_with("lead_"):
    			collection.phase = "waiting_depot" if collection.phase == "lead_depot" else "waiting_source"
    			collection.remaining_ticks = sim._tick
    			_admit(sim,unit,target)
    		elif collection.phase == "loading":
    ```
    and replace `			collection.remaining_ticks = Registry.collects(unit.kind).load_ticks` with `			collection.remaining_ticks = Registry.collects(unit.kind).lock.source.box`.
  - Nothing else in the file changes (`_ahead`, `release`, `object_removed`, view rows untouched).
- [ ] **Step 5: Rewrite the hold-timing checks in `game/tests/test_supply.gd`** to the rule (only these; messages renamed to the new numbers). Timings count from the step that sets the phase, as the existing tests do.

  | case | old | new (c1) |
  |---|---|---|
  | Su2 stationary Chinook | after 1 step `loading` rem 43; `steps(42)` rem 1; step: cargo 1 rem 43; `steps(343)` full, loading | after 1 step `lead_source` rem 18; `steps(17)` rem 1; step: `loading` rem 41 cargo 0; `steps(40)` rem 1 cargo 0; step: cargo 1 rem 41 boxes 7; `steps(327)` cargo 8 `loading` boxes 0; step: `seeking` |
  | Su2 depot | rem 213; `steps(212)`; step +600 | rem 153; `steps(152)`; step +600 |
  | Su4 waiting | `steps(342)` cargo 7 rem 1; `steps(44)`; step: low rem 43 | `steps(344)` cargo 7 rem 1; `steps(42)`; step: low rem 41 |
  | Su4 choices | `steps(87)` then step | `steps(101)` then step (lead 18 + 2 x 41, release, seek) |
  | Su6 unloading | `if phase == "unloading": Fixture.steps(sim,212)` | `Fixture.steps(sim,152)` |
  | Gt1 | rem 38; 190 loading ticks | rem 37; 185 |
  | Gt2 | `steps(114)`, `steps(38)` | `steps(111)`, `steps(37)` |
  | Lb1 | rem 42; 84 loading ticks; depot rem 45; `steps(44)` | rem 23; 46; rem 39; `steps(38)` |
  | Gd11 | `delay := …load_ticks` (4 x 43) | `delay := Registry.collects("usa_collector").lock.source.box` (4 x 41) |
  | Sp1 | `2 * load_ticks - 1`; `steps(unload_ticks)`; truck `steps(4 * load_ticks)` | `2 * lock.source.box - 1`; `steps(lock.depot.work)`; truck `steps(4 * lock.source.box)` |
  | Sp3, Sp4 | `steps(load_ticks - 1)` | `steps(Registry.collects("usa_collector").lock.source.box - 1)` |

  `test_skirmish_scene.gd` `_pile_world`: `Fixture.steps(sim, 3)` -> `Fixture.steps(sim, 19)` (arrival tick plus the Chinook's 18-tick lead; both leads end on tick 19, first loads, second waits).
- [ ] **Step 6: Green and fidelity.** `WARGRID_TEST_ONLY=test_dock_lock`, `=test_supply.gd`, `=test_supply_pile_labels`, `=test_collector_rates_match_zero_hour`: exit 0. `WARGRID_TEST_ONLY=test_income_openings sh tools/run_tests.sh > ~/projects/wargrid-dock-work/c1/t2-income.log 2>&1`; `rg '^INCOME' ~/projects/wargrid-dock-work/c1/t2-income.log` must equal `rg '^INCOME' ~/projects/wargrid-dock-work/c/wargrid-c1.txt | sed 's/ model=c1$//'` (write both to files beside the log and `diff`: empty; mismatch: STOP). Paste the 8 INCOME lines into the evidence row (Task 6 copies its numbers from there). Mutation proofs (each reverted, `git diff` back to the green tree): (a) drop `and collection.phase.begins_with("flying_")` from the lead check (lead restarts after waiting) -> name the DL cases that fail; (b) make the lead exclusive (set `target.active_collector_id = unit.id` in the lead branch) -> DL3 fails. Full suite: record CASES / CHECKS / FAILURES and list every failing case; allowed failing cases are exactly `test_multi_collector_rates` and the P1-P8 cases; anything else: STOP. Lint, warnings, python checks exit 0.

---

### Task 3: MULTI targets on the steady window

```text
Task: gate the multi-collector rows on the 300-600 s steady window against the re-measured Zero Hour values.
Owns: game/tests/test_supply_parity.gd.
Invariant: single-collector TARGETS and rate() unchanged.
Boundary: a pile that empties before the window ends (short flag).
Red: before Step 2 the suite file does not compile (`steady_rate` not found, `layout` takes no `boxes`): expected, record the SCRIPT ERROR line as the red.
Green: WARGRID_TEST_ONLY=test_supply_parity.
Stop: any steady value differs from wargrid-c1.txt; a row needs a tolerance change; the 2 % check of test_steady_rate_window fails (870.0 against 868.2 expected; never widen it).
```

Decided (design answers "Dock-hold experiment", user 2026-11-12): all MULTI targets change to the re-measured steady values, together with the dock change; source: [dock-hold note, Zero Hour re-measure](../../reference/dock-hold-experiment.md#zero-hour-re-measure).

- [ ] **Step 1: Failing tests.** `test_steady_rate_window`: `steady_rate(layout("frc_builder", 3, 2).sim, 0)` is within 2 % of `rate(layout("frc_builder", 3, 2).sim, 17)` and not short. `test_steady_rate_stops_at_empty_pile`: a `layout("china_collector", 9, 2)`-shaped world whose pile has 40 boxes (add a `boxes: int = 400` parameter to `layout`) gives `short == true`, `pile_empty_s > 0`, `per_min == 0.0`.
- [ ] **Step 2: Port `steady_rate(sim, gather_tick: int) -> Dictionary` and `pile_is_empty(view) -> bool`** verbatim from `git -C ~/projects/wargrid-wt-c1 diff main dock-hold -- game/tests/test_supply_parity.gd` (constants `STEADY_FROM_SECONDS := 300`, `STEADY_TO_SECONDS := 600`, `SHORT_SECONDS := 450`; returns `{per_min, pile_empty_s, short}`), without the `model` parameter.
- [ ] **Step 3: Targets and gate.** `MULTI` -> `["usa_collector", 9, 2, 2760.0]`, `["frc_builder", 3, 2, 870.0]`, `["frc_builder", 3, 4, 1725.0]`, `["china_collector", 9, 2, 1680.0]`, `["china_collector", 9, 4, 2940.0]`; comment above it: `# kind, gap, collector count, Zero Hour credits/min on the 300-600 s steady window: re-measure in docs/reference/dock-hold-experiment.md.` `FOUR_HELICOPTERS_GAP_9 := 3120.0`, its comment: `# Not gated: three or more Chinooks are outside the openings (user, 2026-11-12).` `test_multi_collector_rates` checks `not steady.short and within(steady.per_min, row[3])` with `steady := steady_rate(layout(row[0], row[1], row[2]).sim, 0)`, message `"Ep4/Ep6/Ep7 %d x %s gap %d steady 300-600 s within 5%% of Zero Hour %.0f/min, got %.1f"`, and prints `"Ep4 steady %d x %s gap %d %.1f"`; `test_four_helicopters_reported` prints the steady value the same way.
- [ ] **Step 4: Green and fidelity.** `WARGRID_TEST_ONLY=test_supply_parity` exit 0. Printed steady values must be exactly 2880.0, 870.0, 1650.0, 1680.0, 2880.0 and Chinook x4 2880.0 (`wargrid-c1.txt` `DOCK c1 multi` lines); mismatch: STOP. Full suite: failing cases only P1-P8. Lint, warnings exit 0.

---

### Task 4: Re-pin the listed traces

```text
Task: regenerate P1-P10 by the documented commands under the trace rule.
Owns: test_skirmish_match.gd, test_team_match.gd, test_view_rows.gd, test_skirmish_scene.gd (HUD_TEXTS), tools/run_team_match.sh, tools/run_netplay.sh.
Invariant: every "Must still hold" column holds; nothing outside P1-P10 changes.
Stop: a winner changes, a match leaves its window or cap, the team match gets a winner, HUD1's fixture check fails, netplay peers disagree, or any unlisted value changes. Record old and new and park.
```

- [ ] **Step 1:** Run each regenerate command of P1-P8 (one `WARGRID_TEST_ONLY` run each, logs `t4-P<n>.log`), read the new value from its FAIL line, check the "Must still hold" column in the same log, then edit the constant. P2 before P1 (same constant). For P8 read the whole message (`rg -n -A7 'HUD1 pinned' <log>`: each entry's trailing newline prints as a real line break) and write the six strings in the constant's current form, each ending in the `\n` escape.
- [ ] **Step 2:** `sh tools/run_team_match.sh > t4-team.log 2>&1`; take `units_peak` from the `TEAM MATCH` line if it reads `cap tick=45000 winner=null`; edit line 13. Rerun: exit 0.
- [ ] **Step 3 (approved at night (user, 2026-11-12)):** `sh tools/run_netplay.sh match > t4-netplay.log 2>&1`; take X from "terminal tick X, pinned 9024", edit line 91; rerun: `match terminal tick X`, exit 0. If the command is denied by the night settings, record "P10 pending (netplay not run)" and continue; Task 7 then reports it as unverified.
- [ ] **Step 4:** Full suite exit 0, `TESTS PASSED`. `sh tools/run_shell_checks.sh` exit 0. Evidence row: table of P1-P10 old -> new.

---

### Task 5: Headless benchmark and ledger row

```text
Task: measure the rebuilt rule headless and record it.
Owns: docs/reference/performance.md (one new History row).
Invariant: no budget, ceiling or F changed.
Stop: run_benchmark.sh exits non-zero; the `BUDGET EXCEEDED` line (printed with exit 0 while regression ceilings hold) names a layout other than the accepted `open` and `hordes300` (combat p95); COMBAT DOCKS waiting_ticks_window 0.
```

- [ ] **Step 1:** `pgrep -fl 'godot|generalszh'` (none of this run's); `uptime`; `sh tools/run_benchmark.sh > ~/projects/wargrid-dock-work/c1/t5-bench.log 2>&1; echo "exit=$?"`; `uptime`. Expected: `BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1`; last line may be `BUDGET EXCEEDED open hordes300 (regression ceilings held)`. Record the `COMBAT DOCKS` line.
- [ ] **Step 2:** Append one row after the "2026-11-12 P1 playtest helper exit gate, rendered" row, in that row's shape: "2026-11-12/13 c1 dock rebuild, headless (tree `<sha>` + uncommitted?, branch `c1-dock-rebuild`; Apple M6; `sh tools/run_benchmark.sh` alone; `uptime` start / end; log path; **measured**)", the PASSED lines and p95 / p99 per layout, the `COMBAT DOCKS` line, the judgement against the P1 headless row (only `supply_collection.gd` and definitions changed), "Rendered rerun: not needed, `git diff main --stat -- game/scripts/presentation game/scenes` empty" (check it), source `[c1 dock rebuild verification](c1-dock-rebuild-verification.md)`. Load over 2.0 at start: tag "host under load", rerun once right away (no waiting loop); keep both rows if still loaded.

---

### Task 6: Docs

```text
Task: make the living docs state c1.
Owns: docs/guide/07-economy.md, docs/STATUS.md (F3 row), docs/reference/dock-hold-experiment.md (status line and decision items 1 and 3), docs/reference/faction-income-parity.md (decision items 1 and 2: one "Adopted" line each).
Invariant: no "(user, DATE)" tag invented; numbers copied from evidence rows, not recomputed.
Stop: a claim needs a number no evidence row has.
```

- [ ] **Step 1: `docs/guide/07-economy.md`.** Steps 5-7 (`rg -n '^5\. |^6\. |^7\. ' docs/guide/07-economy.md`): the truck first stands a 5-tick lead that does not lock the pile, then holds it for 37 ticks per box plus one more (185 ticks), stand still 190; Laborer lead 38 then 46; Chinook 18 then 369; depots: truck 37 locked, Laborer 6 + 39, Chinook 60 + 153. Phase table: add row `lead_source`, `lead_depot` | arrived, standing before the lock window; does not hold the dock | timer ends, then `_admit`. "One collector per source and per depot" paragraph: one collector per lock window. "Only some kinds collect" sentence: `collects` also carries `lock` (lead and box or work per target). The "leading candidate cause" and "This is evidence, not a number change" paragraphs: replace with what was adopted (c1, user 2026-11-12) and the measured rows from the verification file (frc5 close steady 2085, frc7 close 2550 against Zero Hour 2850, reported not judged). Rule table row "One collector holds a dock at a time": "Only the lock window is exclusive". "Of which at the docks" cycle row: keep 227 and add "(lock 222: 185 pile, 37 depot)".
- [ ] **Step 2:** `docs/STATUS.md` F3: append "Adopted c1 (user, 2026-11-12 night); rebuilt on `c1-dock-rebuild`, not merged; rows in [c1 dock rebuild verification](reference/c1-dock-rebuild-verification.md)". Note status line and items 1, 3, and `docs/reference/faction-income-parity.md` decision items 1, 2: one sentence each, "Adopted: c1, user 2026-11-12 night; rebuild plan [c1 dock rebuild](../superpowers/plans/2026-11-12-c1-dock-rebuild.md)".
- [ ] **Step 3:** Check links and paths (`rg -n '\]\(' <changed files>` and open each relative target), `sh tools/check_public.sh` exit 0.

---

### Task 7: Exit checks on the final tree

```text
Task: run every gate once on the final tree and record it.
Owns: the verification file.
Stop: any check fails.
```

- [ ] Full suite (`TESTS PASSED`, exit 0), `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/run_python_checks.sh`, `sh tools/run_shell_checks.sh`, `sh tools/check_public.sh`, `sh tools/run_team_match.sh` (pinned line), `sh tools/run_netplay.sh match` if Task 4 ran it; `git diff main --stat`; `git diff main -- game/scripts/presentation game/scripts/net relay protocol` empty. Record each with the tree (`git rev-parse --short HEAD` plus "+ uncommitted" if dirty). Unverified and pending for the user: CI on Linux and Windows plus `sh tools/compare_local_traces.sh RUN_ID` (needs a push), playtest, rendered check (not needed unless the review finds a presentation change).

---

### Task 8: Fresh-context review and lean pass (Opus)

```text
Task: one substantive review of the whole branch and one lean-only pass.
Stop: a critical or important finding that changes the rule, a target or a pin parks for the user; others are fixed by a Sonnet fix task, then Task 7 reruns.
```

- [ ] **Step 1:** Fresh Opus (high) reviewer, no implementation context. Brief: `git -C ~/projects/wargrid-wt-c1 diff main...HEAD` (and working tree), this plan's Global Constraints and Review Focus, the verification file, `~/projects/wargrid-dock-work/c/wargrid-c1.txt`, the docs changed in Task 6 (code claims checked against code). It must name, for each new test (DL0-DL9, steady tests), the production change that makes it fail; check every P1-P10 re-pin against the trace rule; check docs claims against the code; no repo-wide search.
- [ ] **Step 2:** `/ponytail-review` on the same diff (over-engineering only). Apply cuts that keep every test green and never remove a test, a check or a pinned value; rerun the affected suites.
- [ ] **Step 3:** Record findings and rulings in the verification file; fixes test-first in a Sonnet fix task; then Task 7 again. End state: reviewed, green branch; one local commit per GREEN task (user, 2026-11-12); never push.

---

## Decisions (user, 2026-11-12)

1. Same-tick lead end, also on a mixed air/ground pile: the lower id takes the lock (DL4 pins it; caveat stays in the note).
2. Collectors standing their lead count as neither docked nor waiting in the pile label and HUD; no presentation change (DL9).
3. `dock-hold`'s note and its two design-answer sections come onto this branch, docs only (Task 1 Step 2).
4. One local commit after each GREEN task on `c1-dock-rebuild`, pre-authorized; never push.
5. `sh tools/run_netplay.sh match` may run at night to re-pin 9024 (Task 4 Step 3).
6. FRC bot collector count (`bot_collectors_per_supply_center`) stays 5 in this branch.
