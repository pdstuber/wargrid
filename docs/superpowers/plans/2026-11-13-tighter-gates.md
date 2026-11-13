# Tighter Gates Implementation Plan

**Status:** written 2026-11-13 for an unattended Sonnet-coordinated night run; every choice below was settled by the user in the questionnaire of 2026-11-13 (see "Decisions").

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. Run rules: [night run](../../night-run.md#coordinator-rules) and [milestone prompt](../../milestone-prompt.md); resume record: [tighter gates verification](../../reference/tighter-gates-verification.md). Every task subagent also reads "Global Constraints" and "Pinned values" (`rg -n '^## ' <plan>`).

**Goal:** Close the gate holes and the slow paths the [tooling audit](../../reference/tooling-audit.md) found: findings 2 to 17, 19 and its six "Left out" points (finding 1 is done, 18 is deferred), plus two extras: the wrap-up benchmark loop and `run_warnings.sh` on a fresh worktree.

**Architecture:** No game behaviour changes. The test runner gets a real-time watchdog thread and a cost-based case deal; the wrapper stops its children; the team match is simulated once (plus a short side-by-side pair); CI builds the relay inside the export job; shell and Python tools get small fixes; one `tools/run_checks.sh` runs the five static gates.

**Tech Stack:** typed GDScript (Godot 4.7.2), POSIX `sh`, Python 3.12 (stdlib in every touched tool), GitHub Actions YAML.

**Spec:** [tooling audit](../../reference/tooling-audit.md) (findings by number; cited lines re-checked on `10b9423` while writing this plan, drift noted per task) and the package note "Tighter gates" in [packages](../../packages.md#package-notes).

## Global Constraints

- Worktree `~/projects/wargrid-wt-gates`, branch `tighter-gates` (base `main` `10b9423`). Agent shells reset their working directory: start every command with `cd ~/projects/wargrid-wt-gates && ` and give log paths in full.
- Logs and scratch files go to `~/projects/wargrid-overnight-work/tighter-gates/logs/` (Task 0 creates it); never into the repository. `$L` in this plan means that folder; shell variables do not survive between agent calls, so start each command with `L=~/projects/wargrid-overnight-work/tighter-gates/logs; cd ~/projects/wargrid-wt-gates && `.
- Every suite, benchmark, netplay, conformance, lint, warnings and Python-check call: Bash `timeout: 600000`, output to a log file, judge by exit code and summary lines (`CASES … CHECKS … FAILURES …`, `TESTS PASSED`, `WARNINGS CHECKED`, `PYTHON TESTS PASSED`, `NETPLAY PASSED`, `CONFORMANCE PASSED`). On failure read only `rg -n 'FAIL|SCRIPT ERROR|ERROR:' <log>`.
- Allowed at night: `sh tools/run_*.sh`, `sh tools/check_public.sh`, `python3 …`, `godot …`, `actionlint`, `shellcheck`, `git` without push or merge (`git worktree add` and `git rm` included), `go build` only where a step says so. Denied: `git push`, `git merge`, `gh pr`, `fly`, `sh tools/deploy_web.sh`, `sh tools/run_game.sh`, any visible window, any Zero Hour launch (parity work uses unit tests and fake launchers only).
- **Denied command:** a command the night permissions refuse (`kill`, `pgrep`, `git rm`, env-prefixed commands, `rm -rf` of scratch folders and similar can hit the auto classifier) goes on the morning list with its exact text; the task then uses an allowed alternative (prefer `sh <script in $L>` holding the command, the Edit tool, `git` forms), continues without it if the step is optional, or parks. Steps below already prefer allowed forms where cheap.
- CI-file changes are checked locally with `actionlint` and `shellcheck` only; the real CI run is a morning item (push needs approval). Windows behaviour of every change is unverifiable tonight; the verification file says so.
- Subagents never commit. The coordinator makes one local commit per GREEN task (pre-authorized, user 2026-11-13); never push.
- Edit with the Edit tool or asserted replacements only. Scratch Godot scripts `quit()` on every path. Scratch mutations are reverted with Edit and the revert is checked with `git diff --stat`.
- New GDScript is typed; `sh tools/run_lint.sh` and `sh tools/run_warnings.sh` pass after any `.gd` change. Python changes pass `sh tools/run_python_checks.sh`; shell changes pass `sh tools/run_shell_checks.sh`.
- **Don't touch:** `game/scripts/simulation/`, `game/scripts/net/`, `game/scripts/presentation/`, `relay/`, `protocol/`, `game/data/`, and every pinned constant and trace below. `game/tests/test_team_match.gd` may change only as Task 2 says. `.claude/` and the night settings file are the user's.
- Comments: why only, one line; no diff narration (`AGENTS.md`, code style).

## Pinned values (none may change; any change is a stop condition)

| # | Where | Value | Checked by |
|---|---|---|---|
| V1 | `game/tests/test_team_match.gd` `FINAL_DIGEST` | `3958ceaab11986af` | TB3, every suite run |
| V2 | same file `TEAM_CORE_SERIES` | `8513092129969516499` | TB4, every suite run |
| V3 | the four suite traces (`WARGRID_REPLAY_TRACE`, `WARGRID_ECONOMY_REPLAY_TRACE`, `WARGRID_COMBAT_REPLAY_TRACE`, `WARGRID_TEAM_REPLAY_TRACE`) | byte-identical to Task 0's files | `cmp` in Tasks 2 and 10 |
| V4 | `tools/run_netplay.sh` match terminal tick | `9129` | `sh tools/run_netplay.sh match` (Tasks 5, 10) |
| V5 | `tools/run_team_match.sh` line 13 | `won tick=39497 winner=2 units_peak=271` | Task 10 |
| V6 | every other `const` pin in `game/tests/` | unchanged | `git diff --stat main -- game/tests` lists only `run_tests.gd`, `test_runner.gd`, `test_team_match.gd` |

No trace re-pin in this package (user, 2026-11-13).

## Review Focus

1. **Watchdog thread** (Task 1): no data race on the case name, the thread is joined on every normal exit path, the kill really happens in real time.
2. **Team match merge** (Task 2): one run gives the same digest, series and trace as the three runs did; the pair still compares two simulations in one process.
3. **Case deal** (Task 3): every case runs exactly once; each process computes the same deal.
4. **CI graph** (Task 4): the export job still gets a relay on both platforms; nothing still needs `relay-bin` from another job; the concurrency rule cannot cancel `main`, tags, pull requests or the call from `release.yml`.
5. **Parity sweep stop** (Task 7): an interrupt stops every child group, starts no new job and re-raises.

## Risks and model routing

Riskiest first: the watchdog thread (Task 1) and the team match merge (Task 2, pinned values). Both are proven by probes before anything depends on them.

| Task | What | Findings | Model |
|---|---|---|---|
| 0 | Baseline: timed suite, traces, load | measurement | Sonnet |
| 1 | Real-time watchdog, killed runs stop their children | 2, 3 | Sonnet |
| 2 | One team match run plus a 3000-tick side-by-side pair | 5 | Sonnet |
| 3 | Cases dealt by cost; timed suite after 5 and 6 | 6 | Sonnet |
| 4 | CI: relay built in the export job, tool tests once, pinned gdlint, branch-only cancel | 7, 8, 9, 14 | Sonnet |
| 5 | Shell and tool cleanups: temp folders, benchmark load and helper, reference check timeout, netplay start wait | 13, 16, 17, 19, left-out 6 | Sonnet |
| 6 | Parity report fixes: pooled keys, stuck unit, zero-check exits, delta sign | 4, 10, 11, left-out 4 | Sonnet |
| 7 | Parity sweep: interrupt stops children, 503 retry, resume by code hash, saved error text, `probe_patriot.py` deleted | 12, left-out 1, 2, 3, 5 | Sonnet |
| 8 | Extras: wrap-up benchmark rule, `run_warnings.sh` on a fresh worktree | extras a, b | Sonnet |
| 9 | One checks command | 15 | Sonnet |
| 10 | Docs and package gate | all | Sonnet |
| 11 | Fresh-context branch review, one fix round | all | **Opus (high)** |

Diagnosis of any unexpected red goes to an Opus (high) agent ([coordinator rules](../../night-run.md#coordinator-rules)).

---

### Task 0: Baseline

```text
Task: record the untouched tree's suite time, traces and load.
Owns: the verification file only.
Invariant: no repository file changes.
Boundary: the import must not be inside the timed run.
Red: n/a (measurement).
Green: suite exit 0, TESTS PASSED, four trace files written.
Stop: suite not green on the untouched tree; load average above 4 for 15 minutes (note it, wait, retry once).
```

- [ ] **Step 1:** `mkdir -p ~/projects/wargrid-overnight-work/tighter-gates/logs`; `git status --short` empty; `git log --oneline -1` shows `10b9423` or a plan commit on top of it; `pgrep -fl 'godot|generalszh'` (list others, kill nothing).
- [ ] **Step 2 (import outside the timing):** `WARGRID_TEST_ONLY=test_runner sh tools/run_tests.sh > ~/projects/wargrid-overnight-work/tighter-gates/logs/t0-import.log 2>&1; echo "exit=$?"` (the stamp `game/.godot/wargrid-imported` is missing on this worktree, so this run imports).
- [ ] **Step 3 (timed run):** with `L=~/projects/wargrid-overnight-work/tighter-gates/logs`: `uptime > $L/t0-uptime.txt; start=$(date +%s); WARGRID_REPLAY_TRACE=$L/replay-before.tsv WARGRID_ECONOMY_REPLAY_TRACE=$L/economy-before.tsv WARGRID_COMBAT_REPLAY_TRACE=$L/combat-before.tsv WARGRID_TEAM_REPLAY_TRACE=$L/team-before.tsv sh tools/run_tests.sh > $L/t0-suite.log 2>&1; echo "exit=$? seconds=$(($(date +%s) - start))"; uptime >> $L/t0-uptime.txt` (timeout 600000). Expected exit 0, `TESTS PASSED`. The runner prints no per-process times; record wall seconds, CASES, CHECKS and both load lines.
- [ ] **Step 4 (team suite alone, for Task 2's comparison):** `start=$(date +%s); WARGRID_TEST_ONLY=test_team_match sh tools/run_tests.sh > $L/t0-team.log 2>&1; echo "exit=$? seconds=$(($(date +%s) - start))"` (timeout 600000).
- [ ] **Step 5:** `wc -l $L/*-before.tsv` (team: 100 lines). Write the Baseline section of the verification file and set Task 0 GREEN.

---

### Task 1: Real-time watchdog; killed runs stop their children (findings 2, 3)

```text
Task: a hung case is killed after 480 s of real time with its name; a killed run_tests.sh stops its Godot children.
Owns: game/tests/run_tests.gd, tools/run_tests.sh.
Invariant: a normal suite run prints the same summary lines; exit codes unchanged; exported builds still work.
Boundary: a case that blocks for seconds between frames (frame time is capped, real time is not); SIGTERM while four shards run.
Red: probe A (watchdog at 10 s does not fire on today's timer); probe B (children alive 3 s after SIGTERM).
Green: probes A and B after the change; WARGRID_TEST_ONLY=test_runner; full suite.
Stop: the watchdog line does not reach the log after a kill; a child survives SIGTERM and SIGKILL in the trap.
```

**Files:** `game/tests/run_tests.gd` (line 50 timer, lines 92-95 `_timeout`, quit paths at lines 57 and 85, `_active_case` writes at lines 10 and 70); `tools/run_tests.sh` (line 4 trap, line 22 `pids=""`).

- [ ] **Step 1 (red probe A, scratch):** Edit `run_tests.gd:50` `create_timer(180.0)` to `create_timer(10.0)`. Run `WARGRID_TEST_ONLY=test_team_match_prefix sh tools/run_tests.sh > $L/t1-redA.log 2>&1` (about 60 s of compute, about 33 frames, so the frame-capped timer adds only about 4 s). Expected: no `watchdog timeout` line, case completes (the hole). Revert the line; `git diff --stat` empty.
- [ ] **Step 2 (red probe B):** write `$L/kill-probe.sh`:

  ```sh
  cd ~/projects/wargrid-wt-gates || exit 1
  sh tools/run_tests.sh > "$1" 2>&1 &
  runner=$!
  i=0
  until [ "$(pgrep -P "$runner" -f run_tests.gd | wc -l)" -ge 4 ]; do i=$((i + 1)); [ $i -lt 120 ] || { echo "PROBE no shards"; exit 2; }; sleep 0.5; done
  kids=$(pgrep -P "$runner" -f run_tests.gd)
  kill -TERM "$runner"
  sleep 3
  alive=0
  for k in $kids; do kill -0 "$k" 2>/dev/null && { echo "ALIVE $k"; alive=$((alive + 1)); }; done
  wait "$runner"; echo "runner exit=$? alive=$alive"
  for k in $kids; do kill "$k" 2>/dev/null; done
  ```

  Run `sh $L/kill-probe.sh $L/t1-redB-suite.log > $L/t1-redB.log 2>&1`. Expected today: `alive=4` (the trap deletes the logs and does not exit). The final loop cleans up; then `pgrep -fl 'tests/run_tests.gd'` shows none of the probe's pids.
- [ ] **Step 3 (wrapper fix, finding 3):** replace `run_tests.sh:4` and move the `pids=""` from line 22 above the traps:

  ```sh
  pids=""
  trap 'rm -rf "$log_dir"' EXIT
  trap 'kill $pids 2>/dev/null; exit 1' HUP INT TERM
  ```

  Delete the old `pids=""` at line 22. The `exit 1` runs the EXIT trap (audit: checked on `/bin/sh`, dash, bash).
- [ ] **Step 4 (watchdog, finding 2):** replace the timer with a thread. Shape (names free, behaviour fixed):
  - `const WATCHDOG_SECONDS: int = 480` (user, 2026-11-13: per test process, no env override; CI processes take up to about 330 s today) with a one-line why comment.
  - `var _watchdog := Thread.new()`, `var _watchdog_stop: bool = false`, `var _case_lock := Mutex.new()`.
  - The per-case write of `_active_case` (line 70) happens under `_case_lock`; the thread reads it under the same lock. The initializer (line 10) needs no lock: the thread has not started yet.
  - Line 50 becomes `_watchdog.start(_watch.bind(Time.get_ticks_msec() + WATCHDOG_SECONDS * 1000))`.
  - `_watch(deadline_ms: int)`: loop `OS.delay_msec(200)` while not `_watchdog_stop` and `Time.get_ticks_msec() < deadline_ms`; if not stopped: `print("FAIL: watchdog timeout in ", <case under lock>)`, `remove_dir(PlaytestSession.dir)`, `OS.kill(OS.get_process_id())` (the same self-kill `game/scripts/net/headless_client.gd:181` uses). (`project.godot` sets `run/flush_stdout_on_print=true`, so the line is flushed before the kill.)
  - A helper `_stop_watchdog()` sets the flag and calls `wait_to_finish()`; call it before `quit(1)` at line 57 and before the final `quit(...)` at line 85. Delete `_timeout()`.
- [ ] **Step 5 (green probe A, scratch):** Edit `WATCHDOG_SECONDS` to `10`; rerun Step 1's command to `$L/t1-greenA.log`. Expected: `FAIL: watchdog timeout in test_team_match_prefix` about 10 s in, `FAIL: 1 of 1 shards did not finish`, exit 1. Revert to `480`; `git diff` shows only the intended change.
- [ ] **Step 6 (green probe B):** `sh $L/kill-probe.sh $L/t1-greenB-suite.log > $L/t1-greenB.log 2>&1`. Expected `alive=0`, runner exit non-zero, no `tests/run_tests.gd` process of the probe left. If a child survives SIGTERM: ruling, use `kill -KILL $pids` in the trap, rerun.
- [ ] **Step 7:** `WARGRID_TEST_ONLY=test_runner` exit 0; full suite exit 0 with Task 0's CASES and CHECKS; `rg -n 'Thread|WARNING' <suite log>` shows no thread-leak warning; `run_lint.sh`, `run_warnings.sh`, `run_shell_checks.sh` exit 0. Record evidence.

---

### Task 2: One team match run plus a side-by-side pair (finding 5)

```text
Task: one 20000-tick run produces the trace, the final digest and the core series; a 3000-tick pair checks two simulations in one process agree every 200 ticks.
Owns: game/tests/test_team_match.gd.
Invariant: V1, V2 and the team trace (V3) unchanged; TB3 build and tank checks unchanged.
Boundary: snapshot calls in a different pattern must not change any digest.
Red: scratch mutation in the new pair makes TB5 fail; scratch mutation of the series order makes TB4 fail.
Green: WARGRID_TEST_ONLY=test_team_match; cmp of the team trace; full suite.
Stop: V1, V2 or the team trace differs from Task 0 (that would mean snapshot() has side effects: park, do not re-pin).
```

**Files:** `game/tests/test_team_match.gd` lines 17-18 (`cases()`), 60-96 (`test_team_match_prefix`, `test_team_core_series`).

- [ ] **Step 1:** Rewrite `test_team_match_prefix` as the only full run. Per tick, in this order (keeps every snapshot at the same simulation state as today):

  ```gdscript
  for tick in range(PREFIX_TICKS):
  	if tick % TRACE_INTERVAL == 0:
  		var state: Dictionary = sim.snapshot()
  		rows.append("%d\t%s" % [tick, StateHash.digest(state)])
  		if state.entities.any(func(unit: Dictionary) -> bool: return unit.kind == "usa_tank"): tanks = true
  	if tick == BUILD_CHECK_TICK: built = _completed_buildings(sim)
  	TeamMatch.step(sim)
  	series = (series * 31 + StateHash.core_check(sim.snapshot())) & 0x7fffffffffffffff
  	if tick % 600 == 599: await runner.process_frame
  ```

  Keep the checks "TB3 trace has 100 rows", the per-seat build check, "TB3 a tank was produced", "TB3 final digest …", `_write_trace`, and move "TB4 team core series pinned, got …" here. Delete `test_team_core_series` and its `cases()` entry.
- [ ] **Step 2:** Add `const PAIR_TICKS: int = 3000` and `test_team_match_pair`: two `TeamMatch.create()` sims stepped together for `PAIR_TICKS` ticks, digests compared at every `tick % TRACE_INTERVAL == 0` and once more after the loop (16 comparisons), `await runner.process_frame` every 600 ticks. Checks: `"TB5 two runs in one process agree every 200 ticks up to tick %d, first divergence %d"` with `diverged == -1`, and the comparison count is 16. Add it to `cases()` after the prefix case.
- [ ] **Step 3 (red by mutation, scratch):** (a) in the pair, step `b` one extra time at tick 1000: TB5 FAIL; (b) in the prefix run, move the `series` line above `TeamMatch.step(sim)`: TB4 FAIL. Revert each; `git diff` shows only Steps 1-2.
- [ ] **Step 4:** `start=$(date +%s); WARGRID_TEAM_REPLAY_TRACE=$L/team-t2.tsv WARGRID_TEST_ONLY=test_team_match sh tools/run_tests.sh > $L/t2-team.log 2>&1; echo "exit=$? seconds=$(($(date +%s) - start))"` exit 0; `cmp $L/team-before.tsv $L/team-t2.tsv` silent. Record the seconds beside Task 0 Step 4's.
- [ ] **Step 5:** full suite exit 0 (CASES = baseline, since one case left and one came); `run_lint.sh`, `run_warnings.sh` exit 0. Record evidence.

---

### Task 3: Cases dealt by cost; timed suite after findings 5 and 6 (finding 6)

```text
Task: deal cases longest-first to the least loaded process, from a small cost table; equal costs give today's modulo deal.
Owns: game/tests/run_tests.gd (shard and its caller), game/tests/test_runner.gd.
Invariant: every case runs exactly once across processes; R1-R4 keep passing; --only still runs one process.
Boundary: ties (equal cost, equal load) break by lower index and lower process; empty cost list.
Red: R5 fails on the modulo deal.
Green: WARGRID_TEST_ONLY=test_runner; full suite; timed four-process run.
Stop: a case runs twice or never (CASES differs from Task 2's count).
```

**Files:** `game/tests/run_tests.gd` (`static func shard`, and its call `for i in shard(tests.size(), OS.get_cmdline_user_args()):`; anchor by text, Task 1 shifts the line numbers); `game/tests/test_runner.gd`.

- [ ] **Step 1 (costs, scratch):** temporarily add before `var completed: Variant = await test.call(self)` the line `var t0: int = Time.get_ticks_msec()` and after it `print("CASE_MS ", _active_case, " ", Time.get_ticks_msec() - t0)`; run `WARGRID_TEST_SHARDS=1 sh tools/run_tests.sh > $L/t3-case-ms.log 2>&1` (one process, about 170 s); `rg '^CASE_MS' $L/t3-case-ms.log | sort -k3 -n -r | head -15 > $L/t3-slow.txt`. Revert; `git diff --stat` empty.
- [ ] **Step 2 (stub):** add a third parameter `costs: PackedFloat64Array = PackedFloat64Array()` to `shard()` that is ignored for now (today's behaviour); the caller still passes nothing.
- [ ] **Step 3 (red):** add `test_shards_by_cost` to `test_runner.gd`: `Runner.shard(6, PackedStringArray(["--shard=0/2"]), PackedFloat64Array([5.0, 1, 1, 1, 1, 1]))` is `[0]` and `--shard=1/2` gives `[1, 2, 3, 4, 5]` (`"R5 the slow case gets a process to itself"`); with equal costs `[1.0, 1, 1, 1, 1]` and 2 shards the deal equals the modulo deal (`"R5 equal costs keep the modulo deal"`). `WARGRID_TEST_ONLY=test_runner`: R5's first check FAILs, the second passes.
- [ ] **Step 4 (green):** implement: order indices by cost descending, ties by index; give each to the process with the smallest load, ties to the lower process; return that process's indices ascending (run order stays suite order). An empty `costs` means cost 1 each. In `_run`, build `costs` from `const CASE_SECONDS := {...}` (method name to seconds, the cases from `t3-slow.txt` of 1 s or more, rounded to 0.1 s) with a default of `0.1` for any other case; one-line why comment (the slowest process bounds the run). Pass it in the `for i in shard(tests.size(), …)` call.
- [ ] **Step 5:** `WARGRID_TEST_ONLY=test_runner` exit 0; full suite exit 0, CASES equal to Task 2.
- [ ] **Step 6 (measurement):** repeat Task 0 Step 3's timed run on this tree (traces to `*-t3.tsv`), `cmp` each against `*-before.tsv`. Record wall seconds and load beside Task 0's (audit estimate: slowest process 87 s to about 47 s; a timed run includes process start and contention). `run_lint.sh`, `run_warnings.sh` exit 0.

---

### Task 4: CI changes (findings 7, 8, 9, 14)

```text
Task: build the relay inside the export job; run the Python tool tests once; lint with the pinned gdlint; cancel superseded runs on branches only.
Owns: .github/workflows/ci.yml, tools/run_python_tests.sh, tools/run_lint.sh.
Invariant: every check that ran before still runs somewhere; the export job's netplay step gets a relay binary at the same path on both platforms; release.yml's call of ci.yml is unaffected.
Boundary: workflow_call from release.yml; pushes to main; pull requests.
Red: probe for 8 (a broken test_install_godot.py passes run_python_tests.sh) and for 9 (run_lint.sh fails without a gdlint on PATH).
Green: the same probes pass after; actionlint; shellcheck; run_python_checks.sh; run_lint.sh.
Stop: actionlint reports an error that needs a structural change beyond this task.
```

Line anchors on `10b9423`: `ci.yml:20-30` godot-lint job, `:100` `needs: relay-test`, `:117-120` download `relay-bin`, `:149-160` netplay step (`:153` relay path), `:232-235` cross-builds, `:238` conformance prefix, `:239-244` upload `relay-bin`, `:284` `GITHUB_PATH` line, `:286-304` Tool tests step; `run_python_tests.sh:6`; `run_lint.sh:2`.

- [ ] **Step 1 (red probes):** (8) scratch Edit: add `assert False` as the first line of `test_cached_archive_skips_download` in `tools/test_install_godot.py`; `sh tools/run_python_tests.sh > $L/t4-red8.log 2>&1` exits 0 today (the file is excluded). Revert. (9) `env PATH=/usr/bin:/bin:/opt/homebrew/bin sh tools/run_lint.sh > $L/t4-red9.log 2>&1` fails today (`gdlint: not found`).
- [ ] **Step 2 (finding 8):** `run_python_tests.sh:6` becomes `tests=$(git ls-files -co --exclude-standard 'tools/test_*.py' 'tools/*/test_*.py')` (the test mocks every `urlretrieve`, `tools/test_install_godot.py:39,77`, and writes only into its temp dir; checked 2026-11-13). In `ci.yml` delete the `GITHUB_PATH` line (`:284`) and the whole "Tool tests" step (`:286-304`).
- [ ] **Step 3 (finding 9):** `run_lint.sh` becomes:

  ```sh
  #!/bin/sh
  cd "$(dirname -- "$0")/.." || exit 1
  sh tools/ensure_venv.sh || exit 1
  PATH="$PWD/tools/.venv/bin:$PATH" # the pinned gdtoolkit lives in the tools venv
  exec gdlint game
  ```

  In `ci.yml`, add `- run: sh tools/run_lint.sh` to the Tools job right after `sh tools/run_python_checks.sh` (the venv exists by then), and delete the `godot-lint` job (`:20-30`).
- [ ] **Step 4 (finding 7):** in `godot-export`: delete `needs: relay-test` and the `download-artifact` step for `relay-bin`; after checkout add

  ```yaml
      - uses: actions/setup-go@v7
        with:
          go-version-file: relay/go.mod
          cache-dependency-path: relay/go.sum
      - name: Build relay for the netplay step
        working-directory: relay
        run: CGO_ENABLED=0 go build -trimpath -o "../relay-bin/relay-${{ matrix.platform }}${{ matrix.platform == 'windows' && '.exe' || '' }}" .
  ```

  The netplay step keeps its `WARGRID_RELAY_BIN` path. In `relay-test`: delete the "Build relay for the Godot export jobs" step and the `relay-bin` upload; the conformance step becomes `run: sh tools/run_conformance.sh` (it builds its own relay when the variable is unset, `run_conformance.sh:6,11`). Then `rg -n 'relay-bin' .github/workflows` lists only the new build line and the netplay step.
- [ ] **Step 5 (finding 14):** top level, after `permissions`:

  ```yaml
  concurrency: # only branch pushes share a group; main, tags, pull requests and the release call get one group per run
    group: ci-${{ startsWith(github.ref, 'refs/heads/') && github.ref != 'refs/heads/main' && github.ref || github.run_id }}
    cancel-in-progress: true
  ```

  Why per-run groups and not `cancel-in-progress: false` on `main`: GitHub cancels an older *pending* run in the same group even without `cancel-in-progress` ("any existing `pending` job or workflow in the same concurrency group will be canceled", GitHub docs "Control the concurrency of workflows and jobs", read 2026-11-13), so three quick pushes to `main` would lose the middle result. In a called workflow "the `github` context is always associated with the caller workflow" (GitHub docs "Reusing workflow configurations", read 2026-11-13): `release.yml` runs on a tag ref, so it gets `ci-<run_id>`, never its own `release` group.
- [ ] **Step 6 (green):** Step 1's probes: (8) with the scratch `assert False` the script now prints `FAIL: tools/test_install_godot.py` and exits 1, revert, exits 0 with `PYTHON TESTS PASSED`; (9) the same `env PATH=…` command exits 0. `actionlint` exit 0; `sh tools/run_shell_checks.sh` exit 0; `sh tools/run_python_checks.sh` exit 0. Optional local proof of the build line: `cd relay && CGO_ENABLED=0 go build -trimpath -o $L/relay-ci . && cd .. && WARGRID_RELAY_BIN=$L/relay-ci sh tools/run_netplay.sh match > $L/t4-netplay.log 2>&1` ends `NETPLAY PASSED match` (V4).
- [ ] **Step 7:** record evidence, including: CI run, the Windows export build and the cancel rule are unverified until a pushed branch runs (morning). Morning item before the push: deleting the `Godot / Lint` job breaks a branch-protection rule that requires it; check with `gh api repos/{owner}/{repo}/branches/main/protection --jq '.required_status_checks.contexts'` (a read, user's morning; not at night).

---

### Task 5: Shell and tool cleanups (findings 13, 16, 17, 19; left-out point 6)

```text
Task: netplay/conformance delete their own temp folder on success; the benchmark prints the load at start and on every exit, through one helper; check_reference times out and shows Godot's error; relay-down/relay-term stop the relay after the match started, not after a fixed 2 s.
Owns: tools/run_netplay.sh, tools/run_conformance.sh, tools/run_benchmark.sh, tools/check_reference.py, tools/test_check_reference.py, tools/test_perf_charts.py (RunBenchmarkTest only).
Invariant: NETPLAY_OUT folders are kept; failure paths keep their folder and print it; benchmark checks and output lines unchanged apart from the two uptime lines.
Boundary: a failing netplay run; an early benchmark exit; Godot exiting non-zero or hanging.
Red: TMPDIR probe keeps a folder; GODOT_BIN=false benchmark prints no load line; new check_reference tests fail.
Green: the same probes and tests pass after; shell checks; Python checks; relay-down and relay-term pass.
Stop: any netplay scenario fails twice in a row after the change (park, diagnose with Opus).
```

- [ ] **Step 1 (finding 13, red):** `mkdir -p $L/tmp13 && TMPDIR=$L/tmp13 sh tools/run_conformance.sh > $L/t5-red13.log 2>&1; ls $L/tmp13` shows one `tmp.*` folder (BSD `mktemp -d` honours `TMPDIR`). Clear it with `rm -rf $L/tmp13/*`.
- [ ] **Step 2 (finding 13, fix):** `run_conformance.sh`: after `echo "CONFORMANCE PASSED $total"` (line 39) add `rm -rf "$out"`. `run_netplay.sh`: after the final `echo "NETPLAY PASSED …"` (line 195) add `[ -n "$NETPLAY_OUT" ] || rm -rf "$out"` (CI passes `NETPLAY_OUT` and keeps its folders). Green: Step 1 again, `ls $L/tmp13` empty; also `TMPDIR=$L/tmp13 sh tools/run_netplay.sh match` ends `NETPLAY PASSED match`, folder empty (V4 holds).
- [ ] **Step 3 (left-out 6):** in `run_netplay.sh` `relay-down|relay-term` (line 179 `sleep 2`): replace with a wait until both `$out/s1.log` and `$out/s2.log` contain `^NETCLIENT MAP` (the line `headless_client.gd:125` prints at match start; same loop shape as the code wait, 100 x 0.2 s, `fail "match did not start"`), then `sleep 1` so both peers pass tick 0 (the scenario fails if an end tick is 0). Green: `sh tools/run_netplay.sh relay-down` and `relay-term`, each `NETPLAY PASSED`.
- [ ] **Step 4 (findings 16 and 19, red):** the regression guard is `RunBenchmarkTest` in `tools/test_perf_charts.py` (`:531`, runs a copy of `run_benchmark.sh` with a stub Godot). Add one test there: the script's output starts with an `uptime` line and ends with one, on a passing run and on an early failure (stub exits 1 on import). It fails today. Also `GODOT_BIN=false sh tools/run_benchmark.sh > $L/t5-red16.log 2>&1` exits 1 with no `load average` line.
- [ ] **Step 5 (fix):** in `run_benchmark.sh`: first command after `repo_root=…` is `uptime`; replace line 4 with `trap 'uptime; rm -rf "$log_dir"' EXIT` and `trap 'exit 1' HUP INT TERM`; add one helper and use it for the import and the three scripts (lines 6-34):

  ```sh
  run() { # LOG ARGS...: one headless Godot run; its log is printed, a non-zero exit or an ERROR line fails the script
  	log=$log_dir/$1; shift
  	"$engine" --headless --path "$repo_root/game" "$@" >"$log" 2>&1
  	code=$?
  	cat "$log"
  	[ "$code" -eq 0 ] || exit 1
  	if grep -E 'ERROR:|SCRIPT ERROR:' "$log"; then exit 1; fi
  }
  run import.log --import
  run tests.log --script res://benchmarks/run_movement.gd
  ```

  (and `combat.log`, `lockstep.log` likewise); keep every `grep -Eq`/`grep -c` line after its call unchanged. `run_profile.sh` and `run_team_match.sh` stay as they are (audit). Green: the new test and every existing `RunBenchmarkTest` case pass (`python3 tools/test_perf_charts.py`; they guard the helper's exit and `ERROR:` behaviour); Step 4's command prints two `load average` lines, exit 1. The full benchmark runs at the package gate (Task 10), not here.
- [ ] **Step 6 (finding 17):** tests first in `tools/test_check_reference.py`, patching `check_reference.subprocess.run`: (a) a `CompletedProcess` with `returncode=1`, `stdout=""`, `stderr="SCRIPT ERROR: boom"` makes `wargrid_definitions()` raise `RuntimeError` whose text contains `boom`; (b) the call gets `timeout=300`. Both fail today: with `subprocess.run` mocked, `check=True` never raises, so (a) gets "Godot printed no WARGRID_DEFINITIONS line" without `boom`; (b) no timeout is passed. Fix `check_reference.py:206`: `subprocess.run(command, capture_output=True, text=True, check=False, timeout=300)`; on a non-zero return code raise `RuntimeError` with the exit code and the last 20 lines of stderr.
- [ ] **Step 7:** `sh tools/run_shell_checks.sh`, `sh tools/run_python_checks.sh`, `python3 tools/test_check_reference.py`, `python3 tools/test_perf_charts.py` exit 0. Record evidence.

---

### Task 6: Parity report fixes (findings 4, 10, 11; left-out point 4)

```text
Task: pooled metrics use every run's keys; a stuck unit gives a FAIL row instead of a crash; the reference check and the parity report fail on zero checks; every delta reads Wargrid minus Zero Hour.
Owns: tools/zh_parity/analyze.py, tools/check_reference.py (main only), tools/test_zh_parity.py, tools/test_check_reference.py.
Invariant: analyze.py --self-test passes; existing tests unchanged in meaning.
Boundary: first run lacks a metric; all speeds zero; empty trace folder; --only with no kinds.
Red: each new test fails on today's code (missing key, StopIteration, exit 0, wrong sign).
Green: python3 tools/test_zh_parity.py; python3 tools/test_check_reference.py; run_python_checks.sh.
Stop: none expected beyond the global ones.
```

Tests first, all in `tools/test_zh_parity.py` unless named:

- [ ] **Finding 4:** runs `[short, good, good]` (short = a unit that fired once, no shot interval) and `[good, good, short]` give the same pooled key set. Fix `analyze.py:568`: `for key in dict.fromkeys(k for m in per_run for k in m):`.
- [ ] **Finding 10:** `movement()` and `turning()` on a trace whose speeds are all 0 do not raise; `movement` returns `top_speed` 0.0 and `start_delay_frames` None, so `verdict(0.0, 30, 3)` is FAIL in `report`. Fix `analyze.py:165`: `start = next((f for f, v in sp if v > 0), None)`, and when `None` return early `{"start_delay_frames": None, "top_speed": 0.0, "peak_speed": 0.0, "accel": None, "frames_to_top": None, "braking": None}` (the medians below fail on empty data). Same at `:187`: `start_delay_frames` is `None` when no frame moves.
- [ ] **Finding 11 (parity report):** `--json` and `--report md` on an empty folder exit non-zero with `no traces under <dirs>` (run `analyze.py` as a subprocess in the test). Fix in the `__main__` block (`:792-797`): before printing, `if not find_traces(dirs): raise SystemExit(f"no traces under {', '.join(map(str, dirs))}")` for each of the two modes.
- [ ] **Finding 11 (reference check, `tools/test_check_reference.py`):** `main([str(archive), "--wargrid-json", str(wargrid), "--skip-hash", "--only"], out)` with the fixture archive and JSON of `test_cli_reports_and_fails_on_difference` (shape at `tools/test_check_reference.py:146-147`; without `--wargrid-json` it runs real Godot) prints `REFERENCE CHECK FAILED 0 rows` and returns 1. Fix `check_reference.py:229-234`: zero rows print FAILED and return 1 (`ok = differing == 0 and results`).
- [ ] **Left-out 4 (delta sign, user 2026-11-13: Wargrid minus Zero Hour everywhere, as `faction-income-parity.md` reads):** in `md_report`, `got` is the measured Zero Hour value and `exp` the Wargrid value. Today `credits_per_min` rows already read Wargrid against Zero Hour (`analyze.py:628`, `(exp / got - 1)`); every other row is the flipped one (`:626`, `got - exp`). Test first, one `md_report` call pinning both: a `move_*` `top_speed` row with measured 20 and Wargrid 22 shows delta `2`, and a `collect_*` `credits_per_min` row with measured 100 and Wargrid 110 shows `+10 %`. The first fails today (`-2`). Fix `:626`: `fmt(round(exp - got, 3))`; `:628` stays. No committed table uses `md_report`'s delta column (checked 2026-11-13).
- [ ] **Green:** all three Python test files and `python3 tools/zh_parity/analyze.py --self-test` exit 0; `sh tools/run_python_checks.sh` exit 0. Record evidence.

---

### Task 7: Parity sweep (finding 12; left-out points 1, 2, 3, 5)

```text
Task: Ctrl-C or SIGTERM on a sweep stops every child group, starts no new job and re-raises; exit 143 is final; the boot loop retries HTTP 503; resume reruns traces written by other code; a failed job's output is kept; probe_patriot.py is deleted.
Owns: tools/zh_parity/parity.py, tools/test_zh_parity.py, tools/zh_parity/probe_patriot.py (delete), docs/reference/parity-harness-improvements.md (line 32), docs/packages.md (line 73, last sentence).
Invariant: no Zero Hour launch; existing Sweep tests keep their meaning; kill_run unchanged.
Boundary: interrupt while one job runs and others are queued; a child stopped by hand (exit 143).
Red: new tests fail on today's code.
Green: python3 tools/test_zh_parity.py; run_python_checks.sh.
Stop: a fix needs a real game to verify (park that point, keep the rest).
```

Anchors on `10b9423`: `parity.py:85-94` boot loop, `:126-133` `call`, `:107-114` provenance, `:758-760` `pending`, `:766-792` `sweep` (`:787` `code == 2`), `:795-818` `child_launcher`.

- [ ] **Finding 12 (tests first, fake launchers):** (a) with 1 lane and 3 jobs, a launcher that raises `KeyboardInterrupt` on the first job: `sweep` re-raises `KeyboardInterrupt`, the other two jobs never launch, and `stop_group` (patched) was called for a pidfile `out/pids/<n>` of kind `sweep` written before the sweep; (b) with `retries=1`, a launcher returning `("fail", 143)` is not retried (one `runs.jsonl` line; with `retries=0` the test would pass before the fix). Fix: a `threading.Event` `stop`; in `work()`, check it before `free.get()` (return `False` when set) and wrap the `launch` call in `except BaseException: stop.set(); raise` (a launcher's exception is stored on its future while the same worker thread picks up the next job, so the event must be set in the worker, not only in the main thread). Inside the `with ThreadPoolExecutor` block wrap the `sum(...)` in `try/except BaseException`: set the event, `pool.shutdown(wait=False, cancel_futures=True)`, `stop_group(pid)` for every `read_pidfiles(out)` entry except `os.getpid()`, re-raise. The `except` must sit inside the `with`, or `__exit__` waits for the running jobs first. `:787` becomes `if code in (2, 143):` with a one-line why (stopped by hand or config error).
- [ ] **Left-out 1 (503):** test: `Game.boot(log_path, {"GEN_FPS_CAP": "0"})` on an object built with `Game.__new__`, `proc` a stub whose `poll()` returns `None`, `parity.git_rev` patched to return `"x"`, `time.sleep` patched out, and `urllib.request.urlopen` patched (so the `HTTPError` to `ApiError` mapping in `call` is exercised): the first two `/healthz` requests raise `urllib.error.HTTPError(url, 503, …)`; after that the fake answers by path: `/healthz` `{"inGame": true, "frame": 7}` (constant frame, so `stable_frame` returns), `/session` `{"headless": true, "seed": 1}`, `/control` `null`, `/players` a list with one `controller: "external"`, one `controller: "human"` with a non-Observer side, one `side: "Civilian"`, one `controller: "computer"` with an empty name (each with `index`, `side`, `name`). `FakeGame` (`test_zh_parity.py:395`) has only `command`, so this needs its own fake. Boot completes; fails today (a 503 becomes `RuntimeError`, not `OSError`). Fix: `call` raises `ApiError(RuntimeError)` carrying `code` (existing `except RuntimeError` callers keep working); the boot loop also catches `ApiError` with `code == 503`.
- [ ] **Left-out 2 (resume):** test: a finished trace whose header lacks `"code"` or carries another value is pending again; one with the current value is not. Fix: `CODE = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()[:12]`, written by `write()` into every trace header (`parity.py:697`: `{"scenario": name, "code": CODE, **meta}`; not in `Game.provenance`, because `bisect()` writes the `reach_*` traces with its own meta, `:724-730`), and `pending` counts a trace as finished only when its `# {json}` header has `code == CODE`. Update `put_trace` callers in existing Sweep tests to pass `code=parity.CODE` where they mean "finished".
- [ ] **Left-out 3 (error text):** test with a fake child (a `sys.executable -c` script printing `boom` and exiting 1, via a patched script path or a small launcher factory): after the job, `out/rep1/<name>.out` contains `boom` and the `runs.jsonl` line for the failed attempt names that path. Fix in `child_launcher`: child stdout and stderr appended to `out/rep{rep}/{name}.out`; `work()` adds `"output"` to the line when the status is not `ok`.
- [ ] **Left-out 5:** `rg -n 'probe_patriot' tools game .github` shows only the file itself; `git rm tools/zh_parity/probe_patriot.py` (user yes, 2026-11-13). Docs: `parity-harness-improvements.md:32` drops "deleting `probe_patriot.py`;" (say it was deleted 2026-11-13 with Tighter gates); `packages.md:73` last sentence ("Deleting … still needs the user's yes.") becomes "`probe_patriot.py` deleted (user, 2026-11-13)." Archive files (`m7-verification-archive-*`) stay as history.
- [ ] **Green:** `python3 tools/test_zh_parity.py`, `python3 tools/zh_parity/analyze.py --self-test`, `sh tools/run_python_checks.sh`, `sh tools/check_public.sh` exit 0. Record evidence; note "not run against the real game" (night rule).

---

### Task 8: Extras: wrap-up benchmark rule; warnings on a fresh worktree

```text
Task: a benchmark record commit no longer makes main look unbenchmarked; run_warnings.sh imports the project when the class cache is missing.
Owns: tools/perf_record.py (auto_label), tools/test_perf_charts.py, docs/wrapup.md (step 1), tools/run_warnings.sh.
Invariant: perf rows still record only on a clean main or with a label; the commit column stays HEAD(+dirty).
Boundary: HEAD is a record commit or a docs-only commit.
Red: new auto-label test; the fresh-worktree probe.
Green: python3 tools/test_perf_charts.py; probe after the fix; run_warnings.sh on this worktree.
Stop: none expected.
```

- [ ] **Extra a (rule, user 2026-11-13):** label and wrap-up use the last commit that touched what the benchmark runs: pathspec `game tools/run_benchmark.sh tools/perf_record.py tools/perf_chart.py` (`game/` holds the benchmark scripts and `project.godot`; `run_benchmark.sh` calls `perf_record.py` and `perf_chart.py`). Docs-only and record commits never trigger a run. On `10b9423` it gives `c88ba13`, equal to today's newest `auto` row, so no spurious run after the change.
- [ ] **Extra a (red):** in `AutoRecordTest` add a test (put a `game/x` file in the fixture repo before its init commit): commit a change to `README.md`, then one to `docs/a.md`, then `auto()`: the label is `auto <sha of the init commit>`; then commit a change under `game/` and `auto()` again: the label is that commit. The first half fails today (`perf_record.py:142` labels with `rev-parse --short HEAD`).
- [ ] **Extra a (fix):** in `perf_record.py`, add `MEASURED = ("game", "tools/run_benchmark.sh", "tools/perf_record.py", "tools/perf_chart.py")` beside `GENERATED` (`:125-129`, which stays for the dirty check); `auto_label` labels with `_git("log", "-1", "--format=%h", "HEAD", "--", *MEASURED)`. `docs/wrapup.md:5` step 1: replace "is not `git rev-parse --short main`" with "is not the last `main` commit that touched what the benchmark runs (`git log -1 --format=%h main -- game tools/run_benchmark.sh tools/perf_record.py tools/perf_chart.py`, the same pathspec as `MEASURED` in `tools/perf_record.py`)".
- [ ] **Extra b (red, reproduced while writing this plan):** `git worktree add --detach ~/projects/wargrid-overnight-work/tighter-gates/fresh HEAD`; `sh ~/projects/wargrid-overnight-work/tighter-gates/fresh/tools/run_warnings.sh > $L/t8-redb.log 2>&1` exits 1 with `Identifier "PlaytestSession" not declared` (no `game/.godot`, so no global class cache).
- [ ] **Extra b (fix):** in `run_warnings.sh`, after `cd "$repo_root"`: when `game/.godot/global_script_class_cache.cfg` is missing, run `"$GODOT_ENGINE" --headless --path game --import >"$log_dir/import.log" 2>&1`, and on a non-zero exit print that log and `exit 1`. One-line why comment (`--check-only` resolves `class_name` only through the import's class cache). Green: copy the fixed script into the scratch worktree (`cp tools/run_warnings.sh ~/projects/wargrid-overnight-work/tighter-gates/fresh/tools/`), rerun: exit 0, `WARNINGS CHECKED`. Then `git worktree remove --force ~/projects/wargrid-overnight-work/tighter-gates/fresh` (if denied, list it for the morning).
- [ ] **Green:** `python3 tools/test_perf_charts.py`, `sh tools/run_python_checks.sh`, `sh tools/run_shell_checks.sh`, `sh tools/run_warnings.sh` exit 0. Record evidence.

---

### Task 9: One checks command (finding 15)

```text
Task: tools/run_checks.sh runs ensure_venv once, then the five static gates at once, one PASS/FAIL line each.
Owns: tools/run_checks.sh (new), AGENTS.md (line 50), docs/development.md (commands block).
Invariant: each gate script unchanged and still runnable alone.
Boundary: two gates failing at once; Ctrl-C.
Red: GODOT_BIN=false makes exactly the warnings gate fail.
Green: the probe; a clean run with five PASS lines; shell checks.
Stop: none expected.
```

- [ ] **Step 1:** write `tools/run_checks.sh`: `cd` to the repo root; `sh tools/ensure_venv.sh || exit 1` first (one-line why: three gates call it, and two parallel venv builds can break each other); then start `run_lint`, `run_warnings`, `run_python_checks`, `run_shell_checks`, `check_public` in the background, each to its own log in a `mktemp -d` folder; `pids=""` and the two-trap pattern of Task 1 (`EXIT` removes the folder, `HUP INT TERM` kills the five gate processes and exits 1; their own children, e.g. `run_warnings.sh`'s Godot checks, are not killed: Ctrl-C reaches the whole foreground group anyway, and a `kill -TERM` of the script leaves at most a few seconds of work, so mark it in the trap's line as `# shortcut: TERM stops the gates, not their children; start each gate in its own process group if that ever matters`); wait for each in a fixed order and print `PASS <name>` or `FAIL <name>`; after the five lines print each failing log; last line `CHECKS PASSED 5` only when all passed; exit 1 otherwise.
- [ ] **Step 2 (probe):** `GODOT_BIN=false sh tools/run_checks.sh > $L/t9-red.log 2>&1` exits 1 with `FAIL run_warnings` and four PASS lines; `sh tools/run_checks.sh > $L/t9-green.log 2>&1` exits 0 with `CHECKS PASSED 5`. Record wall seconds of the green run (audit estimate about 8 s; the sum of the five alone is about 17 s).
- [ ] **Step 3:** `AGENTS.md:50`: add "(`sh tools/run_checks.sh` runs lint, warnings, Python, shell and public checks at once)"; leave the other rules. `docs/development.md` commands block: one line `sh tools/run_checks.sh   # the five static gates at once, one PASS/FAIL line each`. `sh tools/run_shell_checks.sh` exit 0.

---

### Task 10: Docs and package gate

```text
Task: docs describe the new gates; the final tree passes every local gate and the benchmark.
Owns: docs/guide/13-testing-and-tooling.md, docs/development.md, docs/STATUS.md, docs/reference/tooling-audit.md, README.md (generated only), docs/reference/perf-history.csv and docs/reference/performance.md (benchmark record only), the verification file.
Invariant: V1-V6.
Boundary: load average above 2.5 (benchmark refused, noted).
Red: n/a.
Green: all commands below on the final tree.
Stop: any pinned value differs; a budget newly exceeded (hordes300 is already accepted as exceeded: record, do not re-ask).
```

- [ ] **Step 1 (docs):** guide chapter 13: watchdog bullet (`:54`, now a real-time thread, 480 s per process, kills its process), `--shard` sentence (`:57`, dealt by cost), static checks (`:139-143`: venv `gdlint`, `test_install_godot.py` no longer excluded, `run_checks.sh`, warnings import), CI section (`:147-176`: diagram and bullets without the lint job and without the relay job feeding the export job; Tools job runs lint; concurrency rule), footer "Checked against" set to `git rev-parse --short HEAD` at the start of Task 10 (the tree the docs were checked against; this task's own commit comes after). `docs/development.md:66`: drop "needs: uv tool install gdtoolkit==4.5.0" (the venv provides it). `docs/STATUS.md:15` state: "implemented on branch `tighter-gates` (local, not pushed); CI, Windows and the CI timing unverified". `docs/reference/tooling-audit.md` "Review 2026-11-13": one line that findings 2-17, 19 and the left-out points are implemented on `tighter-gates` (link this plan and the verification file). Then `python3 tools/roadmap.py` and `python3 tools/roadmap.py --check` exit 0; `sh tools/check_public.sh` exit 0; relative links in changed docs resolve.
- [ ] **Step 2 (gates):** full suite with the four trace variables to `*-final.tsv`, `cmp` each against `*-before.tsv` (V3); `sh tools/run_checks.sh` (`CHECKS PASSED 5`); `sh tools/run_conformance.sh`; `sh tools/run_netplay.sh match` (V4), `relay-down`, `relay-term`; `sh tools/run_team_match.sh` (V5); `git diff --stat main -- game/tests` (V6); `git diff --stat main -- game/scripts relay protocol game/data` empty; `actionlint` exit 0.
- [ ] **Step 3 (benchmark, alone, last):** `pgrep -fl 'godot|generalszh'` shows none of this run's processes; `uptime`; if the 1-minute load is above 2.5, note it and skip (morning item). Else `PERF_LABEL="Tighter gates" sh tools/run_benchmark.sh > $L/t10-bench.log 2>&1` (its first and last lines now show the load). Expected `BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1`, a `recorded … rows` line; `BUDGET EXCEEDED open hordes300` is the accepted row. No rendered rerun (presentation unchanged; `git diff main -- game/scripts/presentation game/scenes` empty).
- [ ] **Step 4:** record every result with the tree it ran on; the resume record names the morning items.

---

### Task 11: Fresh-context branch review (Opus, high)

- [ ] One fresh Opus (high) reviewer gets: `git diff main...HEAD`, the changed file paths, this plan's Review Focus, the verification file, and the instruction to name, per new test or probe, the production change that would make it fail. No repo-wide search.
- [ ] Fix critical and important findings in one round, test-first, by a Sonnet subagent; re-run the affected checks and the full suite; list minor findings in the morning summary. Then one `/ponytail-review` pass on the diff (over-engineering only); apply cuts, re-verify.

## Decisions (user, 2026-11-13 questionnaire)

1. Finding 5: one full team-match run gives trace, final digest and core series, plus a short side-by-side pair (about 3000 ticks) comparing every 200 ticks; no trace re-pin; any pinned change stops.
2. Finding 2: real-time watchdog thread, 480 s per test process, prints `FAIL: watchdog timeout in <case>` and kills its own process; no env override.
3. Finding 8: drop the `test_install_godot.py` exclusion if the test mocks every download (it does, checked 2026-11-13), and delete the CI step.
4. Finding 14: cancel superseded runs on branches only; `main` keeps one result per commit; the rule must not affect `workflow_call`.
5. `tools/zh_parity/probe_patriot.py`: delete if nothing references it (only archive docs do).
6. Order: gate holes, speed, CI and tool cleanups, parity, the two extras, the checks command last.
7. Local commits: one per GREEN task by the coordinator; never push; one Opus (high) review at the end.
8. Wrap-up benchmark rule (extra a): compare the newest `auto` row with the last `main` commit that touched what the benchmark runs; docs-only commits never trigger a run.
9. Parity delta sign: Wargrid minus Zero Hour on every row.
