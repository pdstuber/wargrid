# GDScript Static Checks Implementation Plan

**Status (2026-11-06):** Tasks 1 and 2 done and merged to `main` (`3e3aae0`); the user accepted the tests exemption. Task 3 skipped by the user (2026-11-06): its count step found 1,044 game-code findings, over the stop rule (see session notes (private)). Also done outside the plan: `sim` handles typed `Simulation` (the bot and scripted-human code keeps `RefCounted` because `SeatSim` is passed to it).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (native, sequential). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the GDScript code gets automated lint and static-typing checks in CI, comparable to `golangci-lint` for the relay, without changing game behaviour.

**Architecture:** two independent gates. (1) `gdlint` from gdtoolkit, run by `tools/run_lint.sh` and a new CI job. (2) Godot's own GDScript warnings promoted to errors in `game/project.godot`, checked per file by `tools/run_warnings.sh` as a step of the existing `godot` CI job. Warnings only reach the command line when they are errors, so errors are the only way to gate them.

**Tech Stack:** gdtoolkit 4.5.0 (pinned; parsed all 60 files on Godot 4.7.2 in the pilot), Godot 4.7.2 `--check-only`, POSIX `sh`.

**Spec:** none separately. This is a small tooling task (not a milestone; M6 is merged and the task is independent of the milestone sequence); the design is the user conversation of 2026-11-05 and the pilot below. User decisions: pilot first (done, repo untouched); make it a separate small task; enable the `unsafe_*` warnings "for everything except the snapshots".

## Pilot findings (2026-11-05, scratch copy, repo untouched)

The first pilot ran on the pre-M6 tree (60 `.gd` files); the numbers below are from it. **Re-run on the post-M6 tree (73 files):** `gdlint` 1,199 findings, 1,160 of them `max-line-length`; the rest are `class-definitions-order` 22, `max-returns` 5, `constant-name` 4, `unused-argument` 3, `max-public-methods` 2, and one each of `max-file-lines`, `function-name`, `class-variable-name`. After disabling five rules the same 9 findings remain to fix. The Godot warning counts were re-run too (see the end of this section). Treat every count here as a starting estimate and re-measure on the day.

- `gdlint` defaults: 1,016 findings in 60 files; 984 are `max-line-length` (limit 100; 984 lines are longer, the longest is 1,461 characters). The other 32: `class-definitions-order` 16, `max-returns` 5, `constant-name` 4 (`Zooms` in `scripts/main.gd`, `OwnerColors` in `scripts/presentation/world_view.gd`, `Neighbors` in `scripts/simulation/grid_navigation.gd`, `Suites` in `tests/run_tests.gd`), `unused-argument` 3, and one each of `max-public-methods`, `max-file-lines`, `function-name` (`Economy_depot`, `tests/test_production.gd:285`), `class-variable-name` (`_HASH_PATTERN`, `scripts/net/wire.gd:16`).
- Post-M6 Godot warning re-run (73 files, all 14 warnings as errors, same classification): game code 1,628 (`unsafe_property`/method 583, `unsafe_call_argument` 494, `inferred_declaration` 272, `untyped_declaration` 177, `return_value_discarded` 90, other 12); tests 6,163 (`unsafe_property`/method 2,875, `unsafe_call_argument` 1,668, `untyped_declaration` 977, `inferred_declaration` 382, `return_value_discarded` 256, other 5). The stop threshold in Task 3 was raised from about 400 to about 500 to match.
- `gdformat --check`: all 60 files would change. Not adopted.
- Godot warnings as errors, deduplicated, classified by message text (approximate): game code 1,367 (`unsafe_property_access` 521, `unsafe_call_argument` 404, `inferred_declaration` 202, `untyped_declaration` 151, `return_value_discarded` 81, other 8); tests 5,415.
- Of the game-code unsafe property/method findings, about 280 are on variables typed `RefCounted` (fixable with a real type) and about 160 on `Variant` (snapshot-derived). Most `unsafe_call_argument` findings pass `Variant` values from snapshot entries into typed parameters.
- `@warning_ignore_start("…")` / `@warning_ignore_restore("…")` regions suppress a warning inside the region and nowhere else (probe, Godot 4.7.2). Godot cannot scope a warning setting by directory or by data origin, so "except the snapshots" means exactly these regions.

## Global Constraints

- No behaviour change. Baseline first: record `sh tools/run_tests.sh` totals (the last recorded M6 pre-merge run was 272 cases / 112,704 checks / 0 failures; measure again, do not trust it) and `sh tools/compare_local_traces.sh` result on the starting tree; both must be identical at the end of every task.
- Do not rewrite arithmetic to silence a warning. `integer_division` is silenced with `@warning_ignore("integer_division")` where the integer result is intended; operands stay.
- Pin `gdtoolkit==4.5.0`. Do not adopt `gdformat`.
- Edit files with the Edit tool only; rename with a word-boundary match (a bare replace also rewrites longer names).
- Run on its own branch from `main` (suggested `static-checks`). Commits only with the user's approval; subagents never commit.
- Test output goes to a file; read only summary lines.

## Review Focus

- A gate that passes without checking anything (wrong path, zero files, engine failed to start): each script must fail on a probe and on an empty file list.
- A rename breaks a late-bound caller that only a running test notices (dictionary keys, string-based calls): the full suite counts must equal the baseline.
- An `integer_division` fix that changes a result: traces must still match.
- A new `.gd` file escaping the check: both scripts take their file list from `git ls-files`, never a hand-written list.
- Suppression regions that grow until the check means nothing: Task 3 reports region count and lines covered.

---

### Task 1: gdlint gate

**Files:**
- Create: `.gdlintrc`, `tools/run_lint.sh`
- Modify: `.github/workflows/tests.yml` (new job `gdscript-lint`), `README.md` (command), the 9 flagged lines named in the pilot findings and their callers

**Interfaces:**
- Produces: `sh tools/run_lint.sh` exits 0 only when `gdlint` prints `Success: no problems found`; the rule set in `.gdlintrc`.

- [ ] **Step 1: Write the failing check.** Create `tools/run_lint.sh`: resolve the repo root from the script location, `cd` there, run `gdlint game` capturing output to a temp file, print it, require exit 0 and the line `Success: no problems found`. Create `.gdlintrc` (YAML, read from the working directory) with `disable:` listing `max-line-length`, `class-definitions-order`, `max-returns`, `max-public-methods`, `max-file-lines` (my call: churn without value in this codebase; line length alone is 984 findings).
- [ ] **Step 2: Run it to verify it fails.** Run `sh tools/run_lint.sh`; expected: exit 1 with exactly the 9 remaining findings (4 `constant-name`, 1 `class-variable-name`, 1 `function-name`, 3 `unused-argument`). Install with `uv tool install gdtoolkit==4.5.0` (or `pip install gdtoolkit==4.5.0`) if `gdlint` is missing.
- [ ] **Step 3: Fix the 9 findings.** Constants become `UPPER_SNAKE` (`ZOOMS`, `OWNER_COLORS`, `NEIGHBORS`, `SUITES`) with every reference updated by word-boundary match; `_HASH_PATTERN` becomes `_hash_pattern`; `Economy_depot` becomes `economy_depot` after `rg` shows how the runner reaches it; the 3 unused arguments get a leading underscore (check no override relies on the name).
- [ ] **Step 4: Prove the gate can fail.** Add `game/probe.gd` containing `const BadName = [1]`, run `sh tools/run_lint.sh`, expect exit 1, delete the probe. The required `Success:` line is what stops a vacuous pass.
- [ ] **Step 5: Verify and wire CI.** `sh tools/run_lint.sh` exits 0; `sh tools/run_tests.sh > file` shows the baseline totals. Add job `gdscript-lint` to `tests.yml` beside `relay-lint` (`ubuntu-latest`, `timeout-minutes: 10`, `actions/checkout@v4`, `actions/setup-python@v5`, `pip install gdtoolkit==4.5.0`, `sh tools/run_lint.sh`). Add the command to the README commands list.
- [ ] **Step 6: Commit** after approval: `Add gdlint gate for GDScript`.

### Task 2: Godot warnings as errors (typing, unused, shadowing, integer division)

**Files:**
- Create: `tools/run_warnings.sh`
- Modify: `game/project.godot` (`[debug]` section), `.github/workflows/tests.yml` (step in the `godot` job), `README.md`, `AGENTS.md` (one line under Verification), game code and tests

**Interfaces:**
- Consumes: Task 1's branch state.
- Produces: `sh tools/run_warnings.sh` prints `WARNINGS CHECKED <n> FILES` and exits 0 only when every `git ls-files 'game/*.gd'` file loads under `--check-only` with no `SCRIPT ERROR` and `<n>` equals the tracked count.

- [ ] **Step 1: Write the script.** `tools/run_warnings.sh`: engine from `GODOT_BIN` (default `godot`) as in `tools/run_tests.sh`; for each tracked file run `"$engine" --headless --path "$repo_root/game" --check-only --script res://<path relative to game>` appending to a temp log; fail on any `SCRIPT ERROR:` or `ERROR:` line, on an engine exit code other than 0, and when the file count is 0.
- [ ] **Step 2: Enable the settings** under `[debug]` in `game/project.godot` as errors (value 2): `gdscript/warnings/untyped_declaration`, `unused_parameter`, `shadowed_variable`, `shadowed_variable_base_class`, `shadowed_global_identifier`, `integer_division`. Leave `inferred_declaration` off (`:=` is deliberate) and `return_value_discarded` off.
- [ ] **Step 3: Run it to verify it fails.** `sh tools/run_warnings.sh`; expect about 180 `untyped_declaration` and a few shadow, unused and integer-division findings in `scripts/`.
- [ ] **Step 4: Fix game code.** Add types; rename shadowing parameters (for example `owner` in `scripts/presentation/world_view.gd`); `_`-prefix unused parameters; `@warning_ignore("integer_division")` on each intended integer division. No operand or expression changes.
- [ ] **Step 5: Decide tests.** My call, flagged for the user: tests are exempt from `untyped_declaration` only (about 980 lambdas and fixtures post-M6) via `@warning_ignore_start("untyped_declaration")` at the top of each affected test file; every other warning in this task is fixed in tests too. If the user wants tests typed, replace the annotations with the types.
- [ ] **Step 6: Prove the gate can fail.** A probe `game/probe.gd` with `func f(unused):` makes `sh tools/run_warnings.sh` exit 1; delete the probe.
- [ ] **Step 7: Verify.** `sh tools/run_warnings.sh` exits 0 and prints the tracked file count; `sh tools/run_tests.sh > file` shows the baseline totals; `sh tools/compare_local_traces.sh` matches the baseline result.
- [ ] **Step 8: Wire CI and docs.** Add a step `sh tools/run_warnings.sh` to the `godot` job after the tests step; add one line to `AGENTS.md` Verification and the README commands. Commit after approval: `Treat typing, shadowing and unused GDScript warnings as errors`.

### Task 3: unsafe_* warnings except snapshot code (gated on a count)

**Files:**
- Modify: `game/project.godot`, game code and tests

**Interfaces:**
- Consumes: `tools/run_warnings.sh` from Task 2.
- Produces: `unsafe_property_access`, `unsafe_method_access`, `unsafe_call_argument` and `unsafe_cast` set to 2, with snapshot-derived code inside `@warning_ignore_start/restore` regions.

- [ ] **Step 1: Count first.** Enable the four settings as errors, run `sh tools/run_warnings.sh`, and write the counts per file into the PR or `docs/session-notes.md`. If game-code findings that are not snapshot-derived exceed about 500, stop and report to the user before editing.
- [ ] **Step 2: Fix what is not a snapshot.** Give `RefCounted`-typed handles (about 280 findings, mostly the `sim` parameter) a real type. Preload constants work as types, but a cyclic preload fails; where a cycle blocks it, use the narrowest fix that compiles and note it in a comment (one line, why). Input and node casts (`InputEvent`, `Node`) get explicit casts or typed locals.
- [ ] **Step 3: Region the snapshot code.** Around functions that read `Dictionary` snapshot entries (the opponent policy in `scripts/simulation/skirmish.gd`, scripted human, views, tests) wrap the function in `@warning_ignore_start("unsafe_property_access", "unsafe_call_argument", "unsafe_method_access")` and the matching `@warning_ignore_restore`. Regions go on functions, not whole files, so a typo outside a snapshot read is still caught. Whole-file annotations are allowed only in `tests/`.
- [ ] **Step 4: Verify.** `sh tools/run_warnings.sh` exits 0; suite totals and traces equal the baseline; report region count and covered lines; run `sh tools/run_benchmark.sh > file` once (hot-path files were touched) and compare the summary lines with the baseline taken at the start (M6 left user-accepted over-budget rows and exit 1, see [M6 verification](../../reference/m6-verification.md)); never loosen a budget, and say so if it was not run.
- [ ] **Step 5: Commit** after approval: `Enable unsafe GDScript warnings outside snapshot reads`.

---

**Self-review.** Coverage: gdlint (Task 1), typing/unused/shadow/int-division (Task 2), unsafe_* except snapshots (Task 3), CI and docs wiring (Tasks 1 and 2). The Task 3 stop rule keeps the user's "unsafe_* except snapshots" request from silently growing. Not verified: the exact `.gdlintrc` key spelling (Task 1 Step 2 proves it by running), the `Economy_depot` call path, whether a cyclic preload blocks typing the `sim` handle.
