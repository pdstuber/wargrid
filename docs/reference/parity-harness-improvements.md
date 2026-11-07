# Parity harness improvements (review and plan, 2026-11-07)

Review of `tools/zh_parity/` (`parity.py`, `analyze.py`, `probe_patriot.py`) and of the improvised sweep scripts from the M7 supply work, with a ranked list and a step-level plan. Status: **proposed**, nothing implemented. Reviewer: Opus (high), read-only on the repo while another agent edited `parity.py` / `analyze.py` (supply `collect_*`). Execute only after that agent is done and its changes are committed or handed over.

Provenance: Wargrid `m7-factions` @ `b7c9ae3` plus the other agent's uncommitted harness changes (`PORT` / `GEN_API_PORT`, `step(n)`, `record(batch=)`, `COLLECTORS`, `collect()`, `pool()`); fork `~/projects/GeneralsGameCode-macOS` branch `wargrid-parity` @ `eb595cfc9`; Apple M-series, 12 cores. Measurements below are mine, port 3950, `-headless -noaudio`, scratch dir `/private/tmp/claude-501/-Users-pdstuber-projects-wargrid/77c02dce-6b2d-4f3e-b2bf-73a55134f5e7/scratchpad/review/`. Labels: **measured**, **source read**, **proposed**, **unverified**.

## 1. Findings

### Speed: the 30 Hz engine loop is the bottleneck, not HTTP

- **Source read.** While paused, the engine advances one forced step per main-loop iteration (`GameEngine.cpp` lines 1099-1110, `consumePendingStep`), and every API request waits for the next `serviceRequests()` drain at the top of an iteration (line 1092). On macOS the loop is capped at `GEN_FPS_CAP`, default 30 (`FramePacer.cpp` `getActualFramesPerSecondLimit`, lines 152-185). So every sequential request costs about 33 ms, and `step n` still takes n loop iterations.
- **Source read.** The `/control speed` action does not lift that cap on macOS: `getActualFramesPerSecondLimit` ignores `setFramesPerSecondLimit` under `__APPLE__`. Only the env var counts.
- **Measured.** `record()` costs 5 sequential requests per frame (`step`, at least one `/healthz` poll, `/units`, `/resources`, a `/healthz` check).

| `GEN_FPS_CAP` | `/healthz` round trip | `record()` per frame | `step(150)` | idle game CPU | `move_crusader` + `range_crusader`, wall |
|---|---|---|---|---|---|
| 30 (today) | 34.3 ms | 173 ms | 5.25 s | 1.7 % | 106 s |
| 0 (uncapped) | 0.41 ms | 6.3 ms | 0.02 s | 101 % (one core) | 8 s |

- **Measured.** The traces are the same with either cap. `move_crusader` matched exactly between cap 30 and cap 0, and between two cap 0 runs, once frames were taken relative to `order_frame` and ids by first appearance. `range_crusader` matched the same way, except that the absolute `lastShotFrame` moves with the start frame. The analyze metrics were identical.
- **Measured.** Boot to a stable paused frame takes about 2 s warm. The harness doc says about 20 s, which is stale.
- Consequence: about 27x faster per recorded frame and about 13x end to end on short scenarios. A collect run of 6600-15000 frames goes from 19-43 min to roughly 1-2 min (**estimate** from the per-frame cost). `batch=n` is no longer needed for speed, and its equality with unbatched sampling is unproven (m7-supply-parity-measured.md, "Harness speed-up").
- Cost: an uncapped paused game spins one core. The frame limiter spin-waits the last 2 ms of each loop (`FrameRateLimit.cpp`), so any cap of 500 or more is also a full spin. Lanes must drop from "as many as you like" to about `cores / 2`, because Python also needs CPU at speed. Lane throughput is **unverified**; measure it in step 4.

### Reliability

| Failure seen | Cause | Fix (where) |
|---|---|---|
| `KeyError` (r1: all names passed as one string) | names are looked up only when their turn comes | validate every name, and glob, before the first launch; suggest close matches (Python) |
| harness driving the wrong game (latent, not seen) | if an orphan already holds the port, the new game fails to bind ("failed to bind ... port in use?"), and `/healthz` answers from the orphan | refuse to start when the port or port+1 is bound; optionally check the listener pid (Python); `pid` in `/healthz` (fork) |
| orphaned games (PID 47210 had parent 1; T1/T3 "Terminated: 15") | Python's default SIGTERM handler exits without running `finally`, and `Popen` shares the lane's process group | SIGTERM handler raising `SystemExit`; `start_new_session=True` plus `os.killpg` in `close()`; the runner kills each job's process group (Python); idle-exit watchdog (fork) |
| everyone's games killed at once (happened during this review, 19:22) | someone ran `pkill -f generalszh_api` / `parity.py`, which hits every lane of every agent | the runner records pids per run dir; `--kill DIR` kills only those. Document "never pkill broadly while another agent runs" |
| possible endless loop | `step()` polls `/healthz` with no deadline; if logic stops (game end, stall) it spins forever | deadline in `step()` (Python) |
| `buildObjectNow failed` | builder ordered in its spawn frame, or a spot next to the spawned dock | already worked around (wait 10 frames, retry the scan); keep and document |
| raw-spawned depot never takes deposits; legality accepts a depot 5 units from a spawned dock | **source read:** the fork's `spawn` only calls `newObject` and `setPosition`. Map objects also get `setLayer`, `onBuildComplete()` on every create module, `team->setActive()` and `addObjectToPathfindMap` (`GameLogic.cpp` 1955-1969) | complete structures in `spawn` like map objects (fork). **Risk to current numbers:** the spawned neutral `SupplyDock` is probably not a pathfinding obstacle, so collector travel near the pile may differ from a map warehouse (**unverified**) |
| shared files across lanes | every game writes `~/Documents/Command and Conquer Generals Zero Hour Data/Replays/00000000.rep` (3.7 MB each) and the debug logs next to the exe | per-lane `GEN_USER_DATA` (absolute path, Python; boot with it **unverified**). Exe-dir logs need the fork; low value |
| "no clear strip" (r4) | Killing Fields has no flat 1000-unit, 200-wide strip | already worked around (narrower, sloped strip); make the map selectable with `ZH_PARITY_MAP` (Python), find a flat map later |
| run-to-run spread | seed is `GetTickCount()` (`SkirmishGameOptionsMenu.cpp` 616). The API player's faction is random; `GEN_AUTO_FACTION` only knows the CWC names `russia`/`usa` → `FactionUSA`, which does not exist in Zero Hour (source read) | record the seed (`/session`) and side in meta (Python); `GEN_AUTO_SEED` and Zero Hour faction names (fork) |

### Analysis

- Trace format: a TSV with a JSON meta line. Reach traces use other columns (`gap/fired/moved`), and money rides in the `health` column. That works; do not migrate old traces. Add provenance to meta instead.
- `EXPECT` hard-codes Wargrid values and has drifted. **Evidence:** `move_scout` expects 75 ("3.0 cells/s"), but `usa_light_vehicle.speed` is 2.4 cells/s = 60 since M7 Task 8 (m7-verification.md decision list). Range and reach rows print FAIL for the known geometry offsets that the decision list already accepted.
- Pooling exists only for `collect_*` credits/min (`pool()`). There is no spread for other metrics, no JSON output and no markdown table. The decision tables in m7-verification.md and m7-supply-parity-measured.md were copied by hand.
- The Wargrid side of the supply comparison lives in a scratch script (`wg_supply2.gd`) that is not in the repo.

### Testability and docs

- `analyze.py --self-test` covers the metrics with synthetic rows and runs in CI (`tests.yml` line 234). Nothing tests `parity.py` (strip search, stop predicates, name handling). There is no one-command smoke run.
- Traces stay outside git (AGENTS.md, harness doc), so test fixtures must be synthetic, not trimmed real traces.
- The harness doc lacks: `collect_*`/`reach_*` in the scenario table, `retreat`/`ungarrison`/`sell`/`/commands`, the quirks above, `ZH_PARITY_PORT`, and the measured start-up time.

## 2. Ranked improvements (benefit / effort)

| # | Improvement | Where | Effort | Benefit |
|---|---|---|---|---|
| 1 | `GEN_FPS_CAP=0` in the game env (override `ZH_PARITY_FPS_CAP`) | Python, 1 line | minutes | **13-27x per lane, measured** |
| 2 | Process hygiene: own session plus `killpg`, SIGTERM → `SystemExit`, port pre-check, `step()` deadline, per-lane `GEN_USER_DATA` | Python, ~30 lines | 1 h | no orphans spinning a core, no wrong-game reads, no hangs. **Required before #1 becomes the default** |
| 3 | Names validated up front (glob, suggestions), atomic trace write (tmp, then rename), meta provenance (seed, side, fork and Wargrid commit, fps cap, schema 1) | Python, ~25 lines | 1 h | no late `KeyError`; partial traces never count as done; reproducible records |
| 4 | Sweep in `parity.py`: `--lanes N --repeats R --timeout S --retries K`, resumable (skips finished traces), `runs.jsonl`, `--kill DIR`, `--list` | Python, ~90 lines | 2-3 h | replaces `runall.sh`, `lane.sh`, `job.sh` and xargs; restart-safe |
| 5 | `analyze.py`: `--json`, pooling across `rep*/` dirs for every metric (n, median, min, max, spread), `--report md` decision table, `--same A B` normalised trace equality | Python, ~90 lines | 2-3 h | decision lists generated instead of copied; equivalence checks for any change |
| 6 | Tests: `tools/zh_parity/test_analyze.py` and `test_parity.py` (unittest, synthetic, fake game), CI lines; `--smoke` (one short scenario plus a metric check, local only) | Python | 2 h | safe refactors; a 10 s "harness works" check |
| 7 | Wargrid values from source: a Godot dump of definitions read by `EXPECT`; the supply sim promoted from scratch into the repo; `--wargrid` join in the report | Godot plus Python | 3 h | no stale expectations (scout 75 vs 60); a `compare-wargrid` flow |
| 8 | Docs: a 10-line scenario recipe, full verb list, quirks, run and sweep commands | docs | 1 h | the next milestone adds scenarios without archaeology |
| 9 | Deletions: `batch` parameter and `collect_truck_6_b5` (made moot by #1); `probe_patriot.py` (question answered; **user decides**) | Python | 15 min | less code |
| F1 | `spawn` completes structures like map objects | fork, ~10 lines C++ | 1 h + 15 min build | depots and docks spawn ready: no builder or power-plant phase (about 700-1200 frames per collect run), correct pathfinding and legality around docks |
| F2 | `GEN_AUTO_SEED=<n>`; `GEN_AUTO_FACTION` takes a Zero Hour template name (`FactionAmerica`, `FactionChina`, `FactionGLA`) | fork, ~10 lines | 30 min + build | reproducible runs, repeats over chosen seeds, no random-faction prerequisite branch |
| F3 | While paused with no pending step, the loop waits on the request queue's condition variable (timeout 33 ms) instead of spinning; `GEN_API_IDLE_EXIT=<s>` exits after s seconds without requests; `pid` in `/healthz` | fork, ~25 lines | 2 h + build | uncapped speed at about 0 % idle CPU → about 2x the lanes; SIGKILL-proof orphan cleanup |
| F4 | `/units?ids=` filter (only if profiling shows `/units` JSON dominates the 6.3 ms) | fork | 1 h | **unverified** gain; skip unless measured |

Order: 1+2 together, 3, 4, 5, 6, 8, 9, 7; then fork F1, F2, F3 as one fork gate with user approval. Expected sweep throughput after Python steps 1-4: about 10-20x (13-27x per lane, fewer lanes). Fork F3 roughly doubles that again (**estimate**).

Not proposed: a JSON manifest file. `SCENARIOS` is already the manifest (name → factory with parameters), and `--list` plus globs cover selection. Also not proposed: a new trace format, threads in `Game`, or a `/sample` endpoint. At 0.4 ms per request the request count no longer matters.

## 3. Execution plan (Sonnet, medium)

Rules for the executor: read this file, the harness doc and `tools/zh_parity/*.py` first. Games always run `-headless -noaudio`. Never write to `~/CnC/parity/traces`; use `--out` under the session scratch dir. Never `pkill -f generalszh_api` or `pkill -f parity.py`; kill only pids you started. Before any game run, `ps -axo pid,command | rg generalszh_api` must show no other agent's games, or use ports at least 4000 and say so. Subagents never commit. Python checks: `sh tools/run_python_checks.sh`. After each step, report counts, exit status and the tree it ran on.

### Step 0: preflight

1. Confirm with the coordinator that the `collect_*` agent is finished and that `git status --short tools/zh_parity` shows only expected changes.
2. Baseline: `python3 -I tools/zh_parity/parity.py --out $S/base move_crusader range_crusader turn_crusader` at today's cap (about 3 min). Keep it for step 1.
3. Verify: `python3 tools/zh_parity/analyze.py --self-test` prints `self-test OK`, and `sh tools/run_python_checks.sh` exits 0.

### Step 1: uncapped loop and process hygiene (#1, #2), Python

In `Game.__init__` / `close()`:
1. Env: `GEN_FPS_CAP=os.environ.get("ZH_PARITY_FPS_CAP", "0")`, plus `GEN_USER_DATA` set to an absolute per-port dir under the out dir's parent (`<out>/../userdata/<port>/`, created). If the game does not boot with it, drop `GEN_USER_DATA`, record that, and continue.
2. Before `Popen`: refuse to start (RuntimeError naming the port) if `socket.create_connection(("127.0.0.1", p), 0.2)` succeeds for `p in (PORT, PORT + 1)`.
3. `Popen(..., start_new_session=True)`; `close()` runs `os.killpg(proc.pid, SIGTERM)`, waits 10 s, then `SIGKILL` (ignore `ProcessLookupError`).
4. Module level in `main()`: `signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))` so `finally: g.close()` runs.
5. `step()`: deadline of `30 + n / 30` seconds wall; past it, raise `RuntimeError(f"no progress past frame {f}")`.

Verify:
- The step 0 scenarios at cap 0 equal the baseline under `analyze.py --same` (from step 5; until then, the normalisation snippet in the step 5 spec, run inline).
- `kill -TERM <python pid>` during a run leaves no `generalszh_api` with that game's pid (check with `ps -p`).
- A second run on the same port while the first is alive fails fast with the port message.
- Wall time for the two baseline scenarios is about 10 s.

### Step 2: names, atomic writes, provenance (#3), Python

1. `resolve(names) -> list[str]`: expand `fnmatch` globs over `[*SCENARIOS, *REACH]`. An unknown name exits 2 before any launch and prints `difflib.get_close_matches`. An empty list means all.
2. `write()` writes `<name>.tsv.tmp`, then `os.replace` (the same for the reach probe table).
3. Meta gains `schema: 1`, `scenario`, `seed` (`/session` → `seed`), `side` (the API player's side from `/players`), `fps_cap`, `fork` (`git -C <fork> rev-parse --short HEAD`, or `"unknown"`), `wargrid` (`git rev-parse --short HEAD` plus `+dirty`). Fetch these once in `Game.__init__` and store them on `g.provenance`; `run_once` merges them into meta.

Verify: `parity.py nosuch` exits 2 with a suggestion; `parity.py 'move_cru*'` runs exactly `move_crusader`; the trace meta shows the new keys; `--self-test` and the python checks pass.

### Step 3: sweep and kill (#4), Python

Add flags to the existing `main()` (no subcommands, so today's command line keeps working): `--repeats R` (default 1), `--lanes N` (default `max(1, os.cpu_count() // 2 - 1)`), `--timeout S` (default 900 per job), `--retries K` (default 1), `--list`, `--kill DIR`.

- With `R == 1 and N == 1`, run in-process as today.
- Otherwise: jobs are `(rep, name)` for rep 1..R. A job is done when `<out>/rep<r>/<name>.tsv` exists, so done jobs are skipped (resume).
- Run each job as a child `sys.executable -I parity.py --out <out>/rep<r> <name>` with `ZH_PARITY_PORT = base + 2 * lane`, `start_new_session=True`, and `wait(timeout)`. On timeout, `killpg`.
- Write each child's pid to `<out>/pids/<pid>` and remove it on exit.
- Append one JSON line per attempt to `<out>/runs.jsonl`: `{"scenario", "rep", "attempt", "lane", "port", "status": "ok|fail|timeout", "seconds", "exit"}`. Retry failures up to K times. Exit 2 (config error) is not retried.
- Use a plain `concurrent.futures.ThreadPoolExecutor(N)` with a lane queue. No new dependency.
- `--kill DIR`: for every pid file, if `ps -p <pid> -o command=` contains `parity.py`, `killpg` it; then delete the file.
- `--list` prints the resolved names, one per line.

Verify:
- `--repeats 2 --lanes 3 'move_ranger' 'move_crusader' 'turn_*'` completes; `runs.jsonl` has one `ok` per job.
- Rerunning the same command launches nothing.
- Kill one child game by pid mid-run: that job retries and succeeds.
- `--kill` on a live sweep leaves no game of that sweep.
- Record wall time and lane CPU (`ps -o %cpu`) for 3, 5 and 8 lanes, and set the default lanes to the best throughput without CPU above 90 %.

### Step 4: analysis output (#5), Python

1. `analyze.py --json DIR...`: one line per trace found in `DIR/*.tsv` and `DIR/rep*/*.tsv`: `{"schema": 1, "scenario", "rep", "path", "meta", "metrics"}`.
2. `analyze.py --report md DIR... [--wargrid FILE]`: group by scenario across reps.
   - Numeric metric: `n`, median, min, max, spread = (max - min) / |median|.
   - String metric: most common value and the number of distinct values.
   - `credits_per_min`: today's `pool()` estimator.
   - Print a markdown table with the columns `scenario | metric | measured (source build) | runs | spread | Wargrid | delta | verdict | note`, from `EXPECT` plus every `collect_*` scenario.
   - Keep the current tab report as the default output.
3. `EXPECT` rows may carry `accepted=<value>` for decided offsets (range and reach geometry). A measured value within tolerance of `accepted` gives verdict `ACCEPTED` instead of FAIL.
4. `analyze.py --same A.tsv B.tsv`: normalise (frame and `lastShotFrame` minus `order_frame`; ids renumbered by first appearance) and print `same` or the first differing row; exit 1 when they differ.
5. Fold `report_pool` / `--pool` into this (deletion).

Verify: the self-test (extended with a two-rep pooling case, an `ACCEPTED` case and a `--same` case) passes; the report on the step 3 sweep dir prints one row per `EXPECT` metric with runs = 2.

### Step 5: tests and smoke (#6), Python

1. Move the `self_test()` body into `tools/zh_parity/test_analyze.py` (unittest, synthetic rows only, as in `tools/test_*.py`). Keep `--self-test` as a thin call to it, or replace the CI line in `.github/workflows/tests.yml` (one line, plus one line for `test_parity.py`).
2. `tools/zh_parity/test_parity.py` with a `FakeGame`, no engine:
   - `settled`, `dead_for`
   - `clear_strip` on a synthetic base64 map (finds the strip, raises when there is none)
   - `resolve` (globs, unknown name)
   - sweep resume (finished traces are skipped)
   - `place_depot` retries on `illegal build location` and re-raises other errors
3. `parity.py --smoke`: runs `move_crusader` into a temp dir, asserts `top_speed` within 3 of 30 and `start_delay_frames` 3, prints `smoke OK <seconds>`. Local only, not CI (needs the fork and game data).

Verify: both test files exit 0 with `python3 tools/zh_parity/test_*.py`; `--smoke` prints `smoke OK` in under 15 s; the python checks pass (typed: annotate new functions).

### Step 6: docs (#8) and deletions (#9)

Update `docs/reference/zero-hour-parity-harness.md`. Link it, do not duplicate this file.

- Run and sweep commands: `--lanes/--repeats/--timeout/--retries/--kill/--list/--smoke`, plus `ZH_PARITY_PORT`, `ZH_PARITY_FPS_CAP` and `ZH_PARITY_MAP` if added.
- Start-up about 2 s and about 6 ms per recorded frame (measured).
- Complete the scenario table (`collect_*`, `reach_*`, `ramp_*`, `horde_*`).
- The verb list from the fork doc: `retreat`, `ungarrison`, `sell`, `/commands`.
- A quirks list:
  - spawned structures are incomplete (until F1)
  - a builder needs about 10 frames after its spawn before `build_structure`
  - the legality check can accept spots overlapping a spawned dock
  - idle collectors ignore piles beyond 700 units
  - the API player's faction and seed are random (recorded in meta)
  - Killing Fields has no flat 1000-unit strip
  - `lastShotFrame` is absolute
  - money is stored in the `health` column of `money` rows
  - `/control speed` does nothing for paused stepping on macOS
  - never `pkill` broadly
- "Add a scenario in 10 lines": a worked `fire()`-style example plus its `EXPECT` row and test.

Deletions: `record(batch=)`, `collect(batch=)` and `collect_truck_6_b5`, unless the user wants the batch pair measured first. Ask the user about `probe_patriot.py`.

Verify: links resolve (`rg -o '\]\(([^)]+)\)'` on the changed docs, check that each path exists); the python checks pass.

### Step 7: Wargrid values from source (#7), Godot plus Python

1. `tools/zh_parity/wargrid_values.gd` (typed, `quit()` on every path): load `res://scripts/simulation/definitions/definitions.gd` and print one JSON object `{kind: {speed, weapon range, ...}}`, using the fields `EXPECT` needs. Invoke Godot the way `tools/run_tests.sh` does.
2. In `analyze.py`, `EXPECT` rows name `(wargrid_kind, field, scale)` instead of a literal, for speed and range rows (e.g. `("usa_light_vehicle", "speed", 25)`). Literal values stay allowed for derived metrics (burst patterns, TTK).
3. Promote `wg_supply2.gd` from scratch to `tools/zh_parity/wargrid_supply.gd`: typed; output one JSON line per `collect_<kind>_u<units*10>[_xN]` name with `credits_per_min` and phases.
4. `analyze.py --report md --wargrid <(godot ... wargrid_values.gd) ...` joins both.

Verify: the report shows `move_scout` Wargrid = 60, not 75. The supply rows equal the "Wargrid today" column of m7-supply-parity-measured.md for the same tree (or the step reports the difference). `sh tools/run_lint.sh` and `sh tools/run_warnings.sh` pass if they cover `tools/`. The python checks pass.

### Step 8: fork gate (F1-F3); needs explicit user approval before editing the fork

All in `~/projects/GeneralsGameCode-macOS` on `wargrid-parity`, local only, never pushed. Rebuild with the harness doc's command (about 15 min). Commit in the fork only with approval.

- **F1**: in `executeCommand` `spawn` (`ExternalControlSystem.cpp`), after `setPosition`, copy the map-object setup from `GameLogic.cpp` 1955-1969: `setLayer(TheTerrainLogic->getLayerForDestination(&pos))`, `onBuildComplete()` for every create module, `team->setActive()`, `TheAI->pathfinder()->addObjectToPathfindMap(obj)` when `obj->isKindOf(KINDOF_STRUCTURE)`. Verify:
  - a spawned `ChinaSupplyCenter` next to a spawned `SupplyDock` produces deposits
  - `build_structure` 5 units from a spawned dock is now rejected
  - `collect_truck_u1625` with the built depot vs the spawned depot vs a map warehouse (Python-only control scenario) agree in `cycle_frames` within the repeat spread. If they differ, report the difference: it bears on the M7 supply numbers.
- **F2**: `GEN_AUTO_SEED`: if set, `setSeed(atoi)` instead of `GetTickCount()` (both call sites, 616 and 1531). `GEN_AUTO_FACTION`: if the value is a player template name, use it directly. The harness passes `ZH_PARITY_SEED` and `ZH_PARITY_FACTION`, and the sweep uses seed = rep. Verify: two runs with the same seed give `--same` traces for a `collect_*` scenario; `/players` shows the pinned side.
- **F3**: `ExternalControlInterface` gains `waitForRequest(ms)`, a CV wait on `m_queueMutex` until `m_inbound` is non-empty or the timeout passes. `GameEngine::update` calls it when the game is paused and there are no pending steps. Add `GEN_API_IDLE_EXIT` (the server thread tracks the last request time; past the limit, the logic thread sets `TheGameEngine->setQuitting(TRUE)`) and `pid` in `/healthz`. Verify:
  - idle paused CPU under 5 % at `GEN_FPS_CAP=0`
  - `record()` per frame still about 6 ms
  - an orphaned game exits after the idle limit
  - the harness checks the `/healthz` pid against its child
- F4 only if a profile of step 3 shows `/units` parsing above half of the per-frame time.

## 4. Unverified / gaps

- Throughput with several uncapped lanes, and Python's CPU share at speed: not measured (step 3).
- Booting with `GEN_USER_DATA`: not tried.
- Equality between capped and uncapped runs was shown only for `move_crusader` and `range_crusader` (deterministic, no AI). Collect runs vary with the random seed, so equality there needs F2.
- That the spawned dock skews collector travel is a hypothesis from the source read; the F1 control run settles it.
- The 20 s start-up in the harness doc may have been a cold-cache figure; 2 s is warm.
