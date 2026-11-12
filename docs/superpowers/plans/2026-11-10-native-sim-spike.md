# Native Simulation Core Spike Implementation Plan

**Status: written 2026-11-10 in the refinement session with the user, revised the same evening after a fresh-context builder check; run not started.** The user starts it with "run docs/native-sim-spike-prompt.txt".

> **For agentic workers:** run rules are in the handoff (`native-sim-spike-prompt.txt`, private) ("How this run works", "Night rules") and the [milestone prompt](../../milestone-prompt.md). The coordinator reads only the "Dispatch" section. A task subagent reads the handoff once, "Conventions", its own task and the files that task names. Skip the milestone prompt's session-start steps 2 and 3: T0 ran the baseline, and other tasks' files are expected to be dirty.

**Goal:** Measure whether Rust behind a Godot extension pays for itself in the browser on the Steam Deck: two real simulation slices ported behaviour-equal, their language gain K, hand-off cost H, effective gain E and the template tax T measured, and a report with one of four outcomes.

**Architecture:** A pure Rust crate holds the slice kernels and knows nothing about Godot. A gdext adapter crate converts packed arrays and exposes one small class per slice. GDScript packs entity state into flat buffers once per tick, calls the adapter and applies the outputs; a mode switch selects GDScript only (default), shadow comparison, native, or pass-through timing. A standalone Rust runner replays recorded buffers without Godot.

**Tech stack:** Godot 4.7.2, typed GDScript, Rust (gdext 0.5.5), Emscripten, the existing web bench runner and `tools/serve_web_bench.py`.

**Spec:** the handoff (`native-sim-spike-prompt.txt`, private) (Stages 2-6, decision rule, report order). Evidence so far and the resume record: [verification file](../../reference/native-sim-spike-verification.md).

## Conventions

Every task follows these; a task that cannot returns BLOCKED.

**Places.** `MAIN` = `/Users/pdstuber/projects/wargrid` (never edited by this run). `WT` = `/Users/pdstuber/projects/wargrid-wt-native` (branch `spike-native-sim`). `WORK` = `/Users/pdstuber/projects/wargrid-native-work` (nothing in it is tracked). A task marked "own tree" works in `WORK/wt/<task>` (branch `spike-native-sim-<task>`, created by the coordinator); every other task works in `WT`. Call the task's tree `TREE`. `WORK/smoke/` is a throwaway build from the evening before: read it for working configuration, never cite it as evidence.

**Every shell call starts with `cd TREE && `.** A subagent's shell returns to `MAIN` after each call, so a bare `sh tools/run_tests.sh` would test the wrong tree. Every log starts with `pwd` and `git rev-parse --short HEAD`. Long commands (suite, exports, browser runs, container builds) run in the background with `timeout: 600000`; wait for the completion notification.

**Time.** Run `date` at the start of a task and before each long step. Past the task's time box: write the state into the task's rows file and return `BLOCKED timebox`.

**Pins.** Never install or update a toolchain.
- gdext: `godot = { version = "=0.5.5", default-features = false, features = ["api-4-7"] }`; web builds add the features `experimental-wasm`, `experimental-wasm-nothreads`, `lazy-function-tables`.
- Rust: `native/rust-toolchain.toml` pins `nightly-2026-03-15` (installed with `rust-src` and `wasm32-unknown-emscripten`). Web builds use `-Zbuild-std`. That toolchain has no clippy: lint with `cargo +stable clippy -- -D warnings` (stable 1.99.1).
- Emscripten: 3.1.74 is the main version (`. ~/emsdk/emsdk_env.sh`); 4.0.20 (`. WORK/emsdk-4.0.20/emsdk_env.sh`) is used for one comparison build. Source the script inside the build script, never `emsdk activate`.
- Web `rustflags`: copy `WORK/smoke/rust/.cargo/config.toml`.
- Templates: the installed official 4.7.2 `web_dlink_nothreads_release`; Godot selects it when a preset has `variant/extensions_support=true` and `variant/thread_support=false`. Check for `index.side.wasm` in the export.
- Linux: `container run --rm --platform linux/amd64 -e RUSTUP_TOOLCHAIN=1.94.1 -e CARGO_TARGET_DIR=/out/target -v TREE/native:/src -v WORK/build/linux:/out docker.io/library/rust:1.94-slim ...` (the image's own compiler, so the toolchain file triggers no download). If the container service is down, do not try to start it: mark the Linux cells unverified and continue.

**Known trap (measured 2026-11-10).** The first `godot --headless --import` of a project with a fresh `.godot` cache and a gdext extension present crashes (exit 134, signal 11); the second import succeeds, and runs, editor quits and exports after it are clean. It is the first editor-mode import that sees a new extension: importing before placing does not avoid it, and a plain game run before that import does not find the extension's classes at all. So `build.sh place` and `export_tree.sh` import twice when the extension is present and require the second import to exit 0. Each such crash also raises a macOS "Godot quit unexpectedly" dialog; it blocks nothing, leave it. Record this in the report as a build-pipeline cost.

**Layout (tracked unless marked).**
- `native/Cargo.toml` (workspace), `native/rust-toolchain.toml`, `native/.cargo/config.toml`.
- `native/core/`: crate `wargrid_core`, **no dependencies**, features `horde` and `movement` (both default). Files `src/lib.rs`, `src/fixture.rs`, `src/horde.rs`, `src/movement.rs`.
- `native/godot/`: crate `wargrid_native` (`cdylib`; the name must differ from the Godot project's), depends on `wargrid_core` and `godot`; features `horde`, `movement`, `probe` (all default). One Godot class per file: `src/horde.rs` (`WargridHorde`), `src/movement.rs` (`WargridMovement`), `src/probe.rs` (`WargridProbe`).
- `native/runner/`: binary `wargrid_runner`, depends on `wargrid_core` only.
- `native/tools/build.sh`, `export_tree.sh`, `web_run.sh`, `deck.sh`, `fixhtml.py` (the four `.sh` names are fixed: the night settings allow them).
- `game/scripts/simulation/native_horde.gd`, `native_move.gd`: one slice each; may read `sim._entities`; no clock calls (`tools/test_sim_math.py` bans `Time.`, `OS.`, `Engine.` in this folder).
- `game/scripts/native/native_bridge.gd`: mode, lazy loading of the slice scripts and the extension classes, timers, shadow comparison, fixture recording. Outside the simulation folder because it reads the clock; it never reads a `_` member of the simulation.
- `game/benchmarks/native_fixture.gd`: a headless driver (workload, mode, slices, ticks, record path; prints `DIGEST` lines; quits on every path).
- `game/tests/test_native_horde.gd`, `test_native_move.gd` (registered in `game/tests/run_tests.gd` `SUITES` by T2).
- Untracked, placed by `build.sh place` and removed by `build.sh remove`: `game/wargrid_native.gdextension`, its `.uid`, `game/native_bin/`. Absent by default; `.gitignore` lists all three.
- A new script gets a tracked `.gd.uid` file from the import: report it with the changed paths. Run `git add -N <new files>` before lint and warnings, because `tools/run_warnings.sh` checks only files git knows.

**Slice interface.** The bridge treats a slice as opaque: a slice script provides `step_gd`, `pack`, `call`, `call_pass`, `apply` and `compare`, and its buffers are an `Array` of packed arrays. A slice may keep state on the native side (for example routes handed over once) as long as its section of the boundary note says when that state is refreshed and the digests prove it. The fixture file stores each buffer as type tag, length and raw bytes, so a slice can change its buffers without touching the bridge.

**Modes.** Selected only by the benchmark, the fixture driver and the tests through `NativeBridge.configure(mode, slices, timing)`. Not reachable from the game's menus. Every test that changes the mode sets it back to `off` before it returns.
- `off` (default): today's code path. The only cost allowed in `simulation.gd` is one check of a static reference per hook.
- `shadow`: GDScript decides. The native slice runs on the same inputs each tick and every output field is compared bit for bit (floats by their bytes, so `-0.0` differs from `0.0`); the first mismatch is kept as text with tick, entity id, field and both values. State is never changed by the native result.
- `native`: the native slice decides.
- `pass`: GDScript decides; in addition the inputs are packed and sent through a native call that copies them into output-sized buffers without work. Only for timing the hand-off. It must not change state: its digests equal `off`.

**Options.** The same keys everywhere: `only`, `native`, `slices`, `timing`, `probe`, `record`, `warm`. Desktop: space-separated `key=value` after `--` (`godot --headless --path game --script res://benchmarks/bench_runner.gd -- only=hordes300 native=shadow slices=horde,move`). Web: the page's query string (`?only=hordes300&native=shadow&slices=horde,move`; quote it in the shell).

**Row ids.** `move_open`, `move_dense`, `combat_open`, `combat_dense`, `contact`, `skirmish3v3`, `hordes300`, `team`. An unknown id fails loudly. With `only=`, the runner first runs one discarded warm row (`warm=contact` unless given), so every compared run has the same history; every row line carries `t_ms=` (milliseconds since page load or start).

**Timers.** With `timing` on, the bridge accumulates per slice, in microseconds over the sampled window:
- mode `off`: `gd` (the whole GDScript slice as it runs today);
- mode `native`: `pack` (selecting and packing), `call`, `apply`;
- mode `pass`: `pack`, `call_pass`;
- always: `calls`, `entities`, bytes sent each way, and the row's `tick_sum` (the sum of the tick times).
Sums over the window, never single-call timings. `NativeBridge.report()` returns them with the shadow mismatch text; `reset_report()` clears them.

**Ratios** (computed in the rows and the report from runs of one tree, one host, one session):
- kernel = `call - call_pass`.
- K is reported as a range: the upper end `gd / kernel` (GDScript's own data access counted as its work, the whole-port view), the lower end `(gd - pack) / kernel` (packing taken as a stand-in for that access). When the kernel is inside the A/A spread of the `call` sums, print "K at least x" instead of a value.
- H = `pack + call_pass + apply` per tick, also per entity in microseconds and bytes, and as a fraction of `gd`.
- E = `gd / (pack + call + apply)`.
- s on that host = slice `gd` sum / `tick_sum` of the `off` run.
- T = whole-tick time of `W2` / `W1` - 1, on p50 and p95.

**Benchmark lines** (printed and posted like today's): `SLICE <row> <slice> mode=<mode> gd_ms=<sum> pack_ms=<sum> call_ms=<sum> apply_ms=<sum> calls=<n> entities=<n> in_bytes=<n> out_bytes=<n> ticks=<n> tick_sum_ms=<sum> mismatch=<text or none>`; `DIGEST <row> tick=<n> <StateHash.digest>` every 300 ticks and at the end of a row; `PROBE <name> ...` for T7. The first `BENCH` line carries `t_ms=`. A selected slice that saw no entities fails the row loudly (`BENCH FAILED ...`) only where it must see some: `horde` on `hordes300`; `move` on `hordes300`, `move_open`, `move_dense`.

**Fixtures.** Recorded in `shadow` mode by `native_fixture.gd` with `record=<file>` (desktop only): every tick's packed inputs and the outputs **GDScript** produced. T2 fixes the binary format in the boundary note. `wargrid_runner replay <file>` recomputes the outputs and compares bit for bit (`REPLAY OK ticks=<n>` or the first difference), so a replay proves Rust equals GDScript on that platform; `wargrid_runner bench <file> <repeats>` times the kernel alone. Files live in `WORK/fixtures/`.

**Native tests must really run.** With `WARGRID_NATIVE_REQUIRED=1` in the environment a missing extension class is a test failure, and each native test file prints `NATIVE CASES RAN <n>`. A task's GREEN quotes that line. Without the variable the native cases are skipped and the always-on checks still count.

**Web configurations.** `export_tree.sh` copies the **working tree** of `TREE` (`git ls-files -co --exclude-standard`, so uncommitted work is included) to `WORK/exports/<task>-<short commit>/<name>/`, logs `git rev-parse HEAD` and `git status --short` next to it, patches `index.html` with `fixhtml.py` (page errors and unhandled rejections are posted to `/result`, so a failed load is a logged cause, not a timeout), and never exports from `TREE` itself.
- `W1`: preset `Web Bench`, no extension in the copy.
- `W2`: preset `Web Bench Dlink` (a copy of `Web Bench` with `variant/extensions_support=true`), no extension in the copy.
- `W3`: `W2` plus the placed extension; the URL selects the mode, so "loaded but unused" (`native=off`), shadow, native and pass-through are the same binary.
- `R1`: preset `Web Render Bench`; `R2`: preset `Web Render Bench Dlink`, no extension.

**Scripts.**
- `sh native/tools/build.sh <mac|web|linux|all|place|remove> [emcc=3.1.74|4.0.20]`: release libraries into `TREE/native/target` and `WORK/build/`; `place` copies the library set, writes the `.gdextension` with debug and release keys for every built platform and imports twice (see "Known trap"); `remove` deletes the extension file, its `.uid`, `game/native_bin/` and the stale entry in `game/.godot/extension_list.cfg`, then imports once.
- `sh native/tools/export_tree.sh <W1|W2|W3|R1|R2> [emcc=...]`: prints the export folder.
- `sh native/tools/web_run.sh <mac|deck> <firefox|safari|vivaldi> <export folder> <query string> <label> [timeout s] [noiso]`: serves the folder on that host's own localhost with `tools/serve_web_bench.py`, opens the page, waits for a result log, copies it to `WORK/results/<label>/`, closes what it opened and stops the server. Always started in the background. Rules: a lock file `WORK/locks/<host>` holding its pid (a lock whose pid is dead is taken over); a `trap` that stops the server and the browser it started on every exit; it fails at once if the port is in use; exit 3 with `DECK DOWN` when `WORK/deck-address.txt` is missing or the Deck does not answer; exit 4 with `NO RESULT` on a timeout. Browsers: Firefox on the Mac runs as a separate instance on a fresh copy of the terms-accepted profile `WORK/profiles/firefox-accepted` and only that instance is closed; Safari and Vivaldi are used only if they were not running when the script started (then the script quits them afterwards; otherwise it exits 5 with `BROWSER BUSY`). Firefox on the Deck runs as a `systemd-run --user` unit on a fresh profile seeded with a `user.js` (first-run pages off and the `termsofuse` lines read from the Deck's existing Firefox profile), under `kde-inhibit --power --screenSaver` where that tool exists, and the script kills its own profile's Firefox afterwards.
- `sh native/tools/deck.sh <push|run|fetch|clean> ...`: the SSH side, following the Deck how-to in `docs/reference/performance.md` ("Target factor measurement") and `docs/reference/perf-spike-verification.md` ("9 results (Deck web)": leftover Firefox instances and the terms popup spoiled runs there). Whether the Deck sleeps or blanks its screen on mains power is unverified: `NO RESULT` on the Deck is retried once, then treated as Deck down.

**Quiet Mac for timing.** Once at the start of a timing task: wait up to 10 minutes until `pgrep -fl 'godot|cargo|rustc|emcc'` is empty and `ps -Ao pcpu,comm -r | head -3` shows no process above 50 % CPU; then go on either way and tag the rows "loaded" if it never got quiet. Record `uptime` at the start and end of every run and `sw_vers -productVersion` once. No timing on the Mac while another task runs.

**Checks before GREEN.** For changed GDScript: `sh tools/run_lint.sh` and `sh tools/run_warnings.sh` pass. For Rust: `cargo test` for the touched crates and `cargo +stable clippy -- -D warnings`. For changed files under `tools/`: `PATH=/Users/pdstuber/projects/wargrid/tools/.venv/bin:$PATH sh tools/run_python_checks.sh` (a worktree has no `tools/.venv` of its own).

**Evidence.** A task writes its dated rows (tree, host, command, result, label, raw-log path) to `WORK/rows/<task>.md`, never to the verification file: parallel tasks would overwrite each other. T9 and T12 copy the rows into the verification file. Only the coordinator writes the resume record. Raw logs go to `WORK/results/` or `WORK/logs/<task>/` with the command that made them.

## Dispatch

Dispatch every task of a phase together; a task starts when everything in "After" is GREEN or was defaulted. `model` is the Agent tool's value. Brief for a task, with `<TREE>` filled in: "Read docs/native-sim-spike-prompt.txt, then 'Conventions' and '<task heading>' in docs/superpowers/plans/2026-11-10-native-sim-spike.md, in <TREE>. Your tree is <TREE>: start every shell call with `cd <TREE> &&`. Write your evidence rows to /Users/pdstuber/projects/wargrid-native-work/rows/<task>.md. Do not commit. Return GREEN or BLOCKED in at most ten lines with the changed paths."

| Phase | Task | Tree | Model | After | Time box | If BLOCKED or over time |
|---|---|---|---|---|---|---|
| 0 | T0 worktree and baseline | WT | coordinator | - | 30 min | suite red on the untouched tree, or the plan is missing in WT: stop the run |
| 0 | T1 Deck check | - | coordinator | - | 5 min | mark `DECK DOWN`, continue |
| 1 | T2 skeleton, bridge and boundary note | own | opus | T0 | 150 min | one fresh opus retry in a new tree `t2b` with the BLOCKED text; then skip T5-T7 and T9-T11, go to T12 with what exists |
| 1 | T3 benchmark and run scripts | own | sonnet | T0 | 120 min | one fresh sonnet retry in a new tree `t3b`; then later tasks use what works and say what is missing |
| 1 | T4 candidates and sources | WT | sonnet | T0 | 60 min | report section 3 marks the cells unverified |
| 2 | T5 horde slice | own | sonnet | T2, T3 | 150 min | one fresh opus retry in a new tree `t5b`; then the slice is left out |
| 2 | T6 movement slice | own | opus | T2, T3 | 180 min | handoff default: keep the first mismatch, integrate the slice anyway if `off` is unaffected, measure it labelled "not behaviour-equal" |
| 2 | T7 browser probe and snapshot probe | own | sonnet | T2, T3 | 120 min | record the cause class; continue |
| 2 | T8 Deck baselines (template tax) | WT | sonnet | T3, Deck up | 180 min | skip, list for the morning |
| 3 | T9 integration and behaviour evidence | WT | opus | T5, T6, T7 | 150 min | measure only what is green; say so in every row |
| 4 | T10 Mac measurements | WT | sonnet | T9, and T8 finished or skipped | 150 min | report the rows that exist |
| 4 | T11 Deck measurements | WT | sonnet | T9, Deck up, and T8 not running | 180 min | skip, list for the morning |
| 5 | T12 report | WT | opus | T10, T11 (finished or skipped) | 90 min | one fresh opus retry |
| 5 | T13 gate review | WT | opus, fresh context | T12 | 60 min | an empty or one-line review is failed: dispatch a second one |
| 5 | T14 fixes, lean review, morning summary | WT | opus, then coordinator | T13 | 90 min | list unfixed findings in the morning summary |

Coordinator recipes (exact commands; `<t>` is the task id in lower case):
- **Before an "own tree" task:** `cd /Users/pdstuber/projects/wargrid-wt-native && git worktree add /Users/pdstuber/projects/wargrid-native-work/wt/<t> -b spike-native-sim-<t> spike-native-sim`.
- **After GREEN from an "own tree" task:** `cd /Users/pdstuber/projects/wargrid-native-work/wt/<t> && git status --short`; every reported path must appear and every changed path must be in the reported list; then `git add <those paths> && git commit -m "<short message>"`; then `cd /Users/pdstuber/projects/wargrid-wt-native && git cherry-pick spike-native-sim-<t>`. Task trees stay on disk for the morning.
- **If the cherry-pick stops on a conflict:** `git cherry-pick --abort`, write "<t> not integrated: conflict in <path>" into the morning summary, treat the task as BLOCKED for the table's "After" column and tell T9 in its brief.
- **After GREEN from a WT task:** `cd /Users/pdstuber/projects/wargrid-wt-native && git status --short`; `git add <reported paths> && git commit -m "<short message>"`. Paths that belong to a task still running are left alone.
- **After every task:** append one line to `WORK/morning-summary.md` (task, GREEN or BLOCKED, key numbers, any default taken) and update the resume record.
- **Deck up** means T1 passed. If it failed, run T1 again when phase 2 starts and when phase 4 starts. Deck up at phase 4 runs T11 even if T8 never ran (T11 has its own baseline runs); T8 then follows T11 if the Deck is still up.
- Phase 4 is the only phase with Mac timing: dispatch T10 only when no other task is running on the Mac. T11 runs on the Deck and may overlap T10.
- A resume record that disagrees with `git log -1` of `spike-native-sim` in WT is the only tree mismatch that stops the run; dirty files of running tasks are normal.
- After T14: final commit, resume record, the one notification, end.

## Review Focus (T13)

- Is every number in the report's K, H, E, T table traceable to a raw log, formed on one tree, one host and one session, and larger than the A/A spread where it is called a gain?
- Do `pass` and `native` pack the same way, and is anything counted twice or left out (selection, the non-moving branch of the movement loop, applying)?
- Does the default path change? (`off` mode diff, the suite and the traces with the extension removed.)
- Shadow mode: can it miss a field the slice writes? Compare the field lists in the slice notes with the GDScript code.
- For each new test, the production change that makes it fail; and did the native cases really run (`NATIVE CASES RAN`)?
- Are G_inc and G_port labelled as estimates, with the two-slice K range, both values of p and the weakest assumption stated?
- Does anything claim "measured" for a candidate that was not built, or a Deck result that was a Mac result? Do compared web runs share warm-up history, template and quality setting?

## Tasks

### T0: Worktree and baseline (coordinator)

- [ ] `cd /Users/pdstuber/projects/wargrid && git status --short && git log --oneline -3`; `git worktree add /Users/pdstuber/projects/wargrid-wt-native -b spike-native-sim main`; `mkdir -p` `WORK/{build,exports,results,logs,fixtures,locks,rows,wt}`; start `WORK/morning-summary.md`.
- [ ] Guard: `cd WT && git ls-files docs/superpowers/plans/2026-11-10-native-sim-spike.md` prints the path. If it prints nothing, the documents were not committed on `main`: stop the run and say so.
- [ ] Resume record: base commit, `sw_vers -productVersion`, `godot --version`, `rustup toolchain list`, `rustc +nightly-2026-03-15 --version`, `container system status`, `pmset -g | grep -i sleep`, whether Safari and Vivaldi are running (`pgrep -x Safari`, `pgrep -x Vivaldi`).
- [ ] Baseline in WT, each to a log under `WORK/logs/baseline/`, summary lines only: `godot --headless --path game --import`; `sh tools/run_tests.sh`; `sh tools/run_lint.sh`; `sh tools/run_warnings.sh`; the python checks as in "Checks before GREEN". Record counts, exit codes and the completion marker. Python checks red at baseline is recorded and not a stop.

Green: suite passes with its completion marker on the untouched tree.

### T1: Deck check (coordinator)

- [ ] If `WORK/deck-address.txt` exists: `sh /Users/pdstuber/projects/wargrid-native-work/deck-preflight.sh "$(cat /Users/pdstuber/projects/wargrid-native-work/deck-address.txt)"`; copy its output into the morning summary. `RESULT: OK` means Deck up.
- [ ] Otherwise, or on `RESULT: FAIL`: write `DECK DOWN` with the output into the resume record and the morning summary; continue.

### T2: Skeleton, bridge and boundary note (opus, own tree)

Owns: `native/Cargo.toml`, `native/rust-toolchain.toml`, `native/.cargo/config.toml`, `native/core/Cargo.toml`, `native/core/src/lib.rs`, `native/core/src/fixture.rs`, `native/godot/Cargo.toml`, `native/godot/src/lib.rs`, `native/runner/**`, `native/tools/build.sh`, `game/scripts/native/native_bridge.gd`, `game/benchmarks/native_fixture.gd`, the hooks in `game/scripts/simulation/simulation.gd`, `.gitignore`, `game/tests/run_tests.gd` (two `SUITES` entries), `docs/reference/native-sim-spike-boundary.md`; and it creates the stubs later tasks fill: `native/core/src/horde.rs`, `movement.rs`, `native/godot/src/horde.rs`, `movement.rs`, `probe.rs`, `game/scripts/simulation/native_horde.gd`, `native_move.gd`, `game/tests/test_native_horde.gd`, `test_native_move.gd`.

Invariant: with the extension removed and mode `off`, the game behaves exactly as on `main`: suite, traces and pins unchanged.
Boundary: the extension is absent (the default) and a caller asks for `shadow`: `configure` reports that the extension is missing and stays `off`; nothing crashes.

- [ ] Read `simulation.gd:502-570` (tick order), `horde.gd`, `locomotion.gd`, `simulation.gd:586-626`, `docs/reference/sim-interface.md`, `docs/reference/determinism-rules.md`, `tools/test_sim_math.py`, `tools/test_sim_boundary.py`, and the working files in `WORK/smoke/` (`rust/Cargo.toml`, `rust/.cargo/config.toml`, `project/smokeext.gdextension`, `buildA.sh`).
- [ ] First step, recorded: reproduce the first-import crash of "Known trap" once in this tree after a first `place`, then make `build.sh place` handle it.
- [ ] Workspace, three crates and `build.sh` as in "Conventions". `cargo tree -p wargrid_core` shows no dependency. `wargrid_native` builds for macOS arm64 and for `wasm32-unknown-emscripten`. `build.sh linux` builds `wargrid_core`, `wargrid_runner` and `wargrid_native` and runs `cargo test -p wargrid_core` in the container (no Godot in that image: the "builds without Godot" proof). Linux is a soft item: on failure record the cause and mark it unverified.
- [ ] Hooks in `simulation.gd`: one static reference (null by default) checked at the horde call (`:555`) and around the movement loop (`:550-553`). When null, the existing lines run unchanged. No other edit to that file.
- [ ] `native_bridge.gd` with the modes, timers, shadow comparison, fixture recording and `report()` of "Conventions"; slice scripts and extension classes are loaded lazily, by name, only when selected, so a broken slice file cannot break `off`.
- [ ] `native_fixture.gd`: runs a named workload (`hordes300`, `move_open`, `move_dense` and a small one built with `spawn`) for N ticks in a given mode, prints `DIGEST` lines and the bridge report, records when asked.
- [ ] Stubs for both slices with the opaque interface of "Conventions" (each returns "not implemented"), a stub `WargridProbe`, and stub tests that assert only that the bridge is `off` by default and that asking for a mode without the extension stays `off`.
- [ ] Boundary note: the conventions every slice follows (who owns which state, what is copied each tick, buffer types, order of rows, entity id handling, removal and id reuse, rejected input, buffer reuse and lifetime, what a held buffer means when WASM memory grows, no panic across the boundary, the fixture file format) and, for the two slices, the Stage 1 paper part the handoff names (state read and written, what affects later ticks but is missing from `snapshot()`, which definitions load without Godot). Then the sketch, not built, of how this grows into the whole-simulation contract (handoff Stage 4, second bullet).

Red: the stub test "bridge is off by default" fails before the bridge exists. Green: suite, lint and warnings pass with the extension removed; `build.sh mac` and `build.sh web` succeed; with the extension placed, `godot --headless --path game --script res://benchmarks/native_fixture.gd -- ...` loads it and a stub call answers; the suite also passes with the extension placed and mode `off`. Stop: a trace or pin moves with mode `off` (handoff default).

### T3: Benchmark and run scripts (sonnet, own tree)

Owns: `game/benchmarks/bench_runner.gd`, `game/export_presets.cfg` (appended presets only), `native/tools/export_tree.sh`, `web_run.sh`, `deck.sh`, `fixhtml.py`, and an optional `--no-isolation` flag in `tools/serve_web_bench.py`.

Invariant: the existing presets are unchanged; a run without options prints the lines it prints today, in the same order, plus the new rows.
Boundary: `only=` naming an unknown row fails loudly instead of printing nothing.

- [ ] `bench_runner.gd`: row ids, options, the warm row, `t_ms=` and `DIGEST` lines as in "Conventions"; `hordes300` added (report-only). Do not reference `NativeBridge` (T7 adds that).
- [ ] Presets `Web Bench Dlink` and `Web Render Bench Dlink`: copies of `Web Bench` and `Web Render Bench` with `variant/extensions_support=true`; nothing else differs.
- [ ] `export_tree.sh` for `W1`, `W2`, `R1`, `R2` (T7 adds `W3`) with `fixhtml.py` (take the idea from `WORK/smoke/fixhtml.py`). Verify `W2` and `R2` contain `index.side.wasm` and `W1`, `R1` do not; record the export sizes.
- [ ] `web_run.sh` and `deck.sh` exactly as "Scripts" says. Read first: `docs/reference/performance.md:222-235` and `docs/reference/perf-spike-verification.md` sections "9 results (Deck web)" and "11 results (Mac web)".
- [ ] Smoke runs: `web_run.sh mac firefox <W1> 'only=contact' t3-w1` and the same for `W2` return logs with `BENCH DONE` and a `DIGEST` line; a deliberately broken export (delete `index.wasm`) returns a logged page error, not only a timeout; a second `web_run.sh` started while one runs waits or fails cleanly on the lock. If the Deck is up, one `W1` run there.

Green: the Mac smoke runs return logs; lint, warnings and (if `tools/` changed) the python checks pass; `godot --headless --path game --script res://benchmarks/bench_runner.gd -- only=hordes300` prints the `COMBAT hordes300` line. Stop: Firefox cannot be started as a separate instance (default: record it, use Vivaldi for the Mac runs).

### T4: Candidates and sources (sonnet, WT)

Owns: `docs/reference/native-sim-spike-candidates.md`.

- [ ] Fetch again and quote with the date: the gdext book's web export page, the godot-cpp README, Godot's "Exporting for the Web" and "Compiling for the Web" pages for 4.7, gdext issues #438 and #1119. If fetching is denied, use the copies of 2026-11-10 in `WORK/prep/toolchain-sources/` and the "Sources" list of the verification file, and say so.
- [ ] One table for candidates A-D and the baseline (handoff Stage 3) against web toolchain maturity, float defaults, safety, build cost, hand-off shape and migration cost. Every cell labelled source, inferred or unverified; nothing here is "measured". One short paragraph on other languages.
- [ ] What CI and hosting would have to change for a native core (templates, toolchains, headers, export size, the first-import crash, an engine upgrade's effect on the pins: Godot PR 124118). Describe only.

Green: the note exists, every quote has a URL and the fetch date.

### T5: Horde slice (sonnet, own tree)

Owns: `native/core/src/horde.rs`, `native/godot/src/horde.rs`, `game/scripts/simulation/native_horde.gd`, `game/tests/test_native_horde.gd`, `docs/reference/native-sim-spike-slice-horde.md`.

Invariant: in `native` mode every tick's snapshot digest equals the `off` run's.
Boundary: a unit whose level changes in a pass and a later unit in the same pass that counts it as a level-2 neighbour (`horde.gd:89`); a contained unit; units of hostile teams in range; fewer neighbours than the rule needs; no member due this tick; no members at all.

What the GDScript does (`horde.gd:15-101`; read it, these are the traps):
- Members are the armed entities with `combat.horde`, in `armed` order (ascending id). A unit is due when `horde_tick <= tick` and it has no `container_id`.
- The grid is built from all members only if at least one is due; cell size is the widest rule radius plus twice the largest kind radius over the member kinds (float64).
- A neighbour counts when it is another member, not contained, not hostile (`Combat.hostile`, `combat.gd:24`: same owner is friendly; team 0 is hostile to everyone; different teams are hostile), matches the rule (same kind, or same class) and `Combat._gap_between` (`combat.gd:59`) is at most the rule radius (float64 `sqrt`).
- Result 2 when `rule.count - 1 <= 0` or enough neighbours; otherwise 1 if any counted neighbour has level 2 **at that moment**, else 0. Due units are processed in order and each new level is visible to the next unit: the kernel must update levels in place in the same order.
- Outputs per due unit: the level, `horde_tick = tick + rate(kind)` (30 for infantry, 31 otherwise) and whether "has a bonus" changed. `Combat.restart_wait` (`combat.gd:560`) stays in GDScript and is applied from that flag, in the same unit order; `sim._horde_checks` grows by the number of due units.
- Positions are float64 pairs: send them as `PackedFloat64Array`. Kind data (rule radius, count, match mode, class, combat radius, rate) is static: send it once as a table, not every tick.

- [ ] Write the slice note first: the buffers (columns, types, order), the per-kind table, the outputs, and the number audit items of handoff Stage 5 that apply (there is no `Vector2` in this slice; `floori` of a float64 quotient, float64 `sqrt`, comparison order).
- [ ] Rust kernel with unit tests for the boundary cases, then the adapter class, then `native_horde.gd`.
- [ ] `test_native_horde.gd` through the public interface only (a workload or `spawn` plus commands, `snapshot`, `StateHash.digest`, `NativeBridge`): 600 ticks of a horde fight in `shadow` mode report no mismatch; a `native` run's digest equals an `off` run's at every 30th tick; a `pass` run's digests equal `off`; the boundary cases as small scenarios.
- [ ] Record `WORK/fixtures/horde-hordes300.bin` (2100 ticks, shadow mode) with `native_fixture.gd`; `wargrid_runner replay` on it on the Mac.

Red: the shadow test reports "not implemented" from the stub. Green: `build.sh mac && build.sh place` in this tree, then `WARGRID_NATIVE_REQUIRED=1 WARGRID_TEST_ONLY=test_native_horde sh tools/run_tests.sh` passes and prints `NATIVE CASES RAN <n>` with n above 0; the same file passes with the extension removed; `cargo test -p wargrid_core`; clippy, lint and warnings pass; `REPLAY OK`. Stop: a mismatch that survives the time box (handoff default).

### T6: Movement slice (opus, own tree)

Owns: `native/core/src/movement.rs`, `native/godot/src/movement.rs`, `game/scripts/simulation/native_move.gd`, `game/tests/test_native_move.gd`, `docs/reference/native-sim-spike-slice-move.md`.

Invariant: in `native` mode every tick's snapshot digest equals the `off` run's, on `move_open`, `move_dense` and `hordes300`.
Boundary: a unit that passes several waypoints in one tick; arrival exactly on the last waypoint (`distance <= remaining + 1e-5`); a zero-length step (`length < 1e-9`); `tick < move_after`; an air unit (heading snaps, constant speed); a wheeled unit below its turn speed; a unit entering a container on arrival (`Containers.entering` keeps `order`); the non-moving branch that zeroes `speed`.

What makes this slice hard (read `locomotion.gd` and `simulation.gd:599-626` fully):
- GDScript `float` is float64, `Vector2` is float32. Every `Vector2(...)` construction rounds to float32 (`locomotion.gd:16, 55, 74` and the returns of `_desired` and `turn`), reading `.x` widens back to float64, and `turned / sqrt(...)` (`:56`) is Godot's `Vector2::operator/(real_t)`: check in `WORK/refs/godot-4.7.2-stable/vector2.h` and `math_defs.h` (`real_t` is `float`) whether the divisor is narrowed to float32 before the division. Reproduce each site exactly; write each one down in the audit.
- `heading` is stored as an Array of floats that came from float32 components; `position`, `speed` and waypoints are float64.
- `unit.position = [x, y]` creates a new Array every tick, and the caller compares it with the Array kept in `before` (`simulation.gd:549, 559`); `route` is replaced by `route.slice(1)` and its waypoints are read-only and shared with snapshots. Applying outputs must keep these semantics.
- The loop at `simulation.gd:550-553` also zeroes `speed` for units that are neither moving nor waiting for a path; that branch stays GDScript and runs in every mode.
- Routes can be long. Sending every waypoint of every moving unit each tick may cost more than the slice saves; `_route_length_until` (`locomotion.gd:84`) stops early. Choose how routes cross the boundary (a bounded prefix with a proof that it is enough, or routes handed over once and kept on the native side until replaced), write the choice and its staleness rule into the slice note, and let the timers show its cost.
- Never use `mul_add`; no `f32::sqrt` where GDScript takes a float64 `sqrt`.

- [ ] Write the slice note first: buffers, the per-kind table (`speed`, locomotor, `turn_cos`, `turn_sin`, `brake`, `accel`, `min_turn_speed`), outputs (position, heading, speed, waypoints consumed, arrived), and the number audit per site.
- [ ] Rust kernel with unit tests for the boundary cases, the adapter class, then `native_move.gd`.
- [ ] `test_native_move.gd` through the public interface only: `shadow` over 600 ticks of a 300-unit move reports no mismatch; `native` digests equal `off` digests every 30th tick; `pass` digests equal `off`; the boundary cases as small scenarios.
- [ ] Record `WORK/fixtures/move-open.bin` and `move-hordes300.bin` (shadow mode); `wargrid_runner replay` passes on the Mac.

Red: the shadow test reports "not implemented". Green: as T5 with `WARGRID_TEST_ONLY=test_native_move`. Stop: a mismatch that survives the time box: write the first mismatching tick, entity, field and both values with the suspected site into the rows file and return BLOCKED (the table's default applies).

### T7: Browser probe and snapshot probe (sonnet, own tree)

Owns: `native/godot/src/probe.rs`, `game/benchmarks/native_probe.gd`, `game/benchmarks/bench_runner.gd` (bridge options, `SLICE` and `PROBE` lines), the `W3` case of `native/tools/export_tree.sh`.

Invariant: a run without native options prints exactly what T3's version prints.
Boundary: the page is opened with `native=shadow` in an export without the extension: the row prints `mismatch=extension missing`, the run still ends with `BENCH DONE`.

Build only the probe: `--no-default-features --features probe` for `wargrid_native`, so unfinished slice code of T5 and T6 is not compiled here. The slices are stubs in this tree: slice rows are T9's.

- [ ] `bench_runner.gd`: pass `native`, `slices`, `timing` to `NativeBridge.configure`; print `SLICE` lines per row from `NativeBridge.report()`; the zero-entity rule of "Benchmark lines".
- [ ] `WargridProbe`: `echo(PackedFloat64Array) -> PackedFloat64Array` (Stage 2's buffer in, computed buffer out); `snapshot_dicts(n) -> Array[Dictionary]` and `snapshot_packed(n)` returning packed arrays, both built from data the Rust side owns, with the key set and value types of one real `snapshot().entities` record from `hordes300` (read one at run time and print its keys into the log); `grow(megabytes)` that allocates enough to grow WASM memory while the caller holds a packed array; `panic_now()`.
- [ ] `native_probe.gd`, run by the bench runner with `probe=1`: `PROBE echo ok=...`; `PROBE snapshot gd_ms=... dicts_ms=... packed_ms=... n=400 repeats=...` (today's `sim.snapshot()` on `hordes300` against both native variants, summed over at least 300 repeats); `PROBE grow held_ok=...`; `panic_now` only with `probe=panic`, as the last action.
- [ ] `export_tree.sh W3` with Emscripten 3.1.74 and once with 4.0.20. Functional runs on the Mac (not timing): `web_run.sh mac <browser> <W3> 'probe=1&only=contact' ...` for Firefox, Safari (twice, each from a cold start) and Vivaldi; one Firefox run with `noiso`; one `probe=panic` run per browser, recording what the page does and what was logged; the 4.0.20 export once in Firefox. Record export sizes and the `t_ms=` of the first `BENCH` line for `W1`, `W2`, `W3`.
- [ ] If the Deck is up: the `W3` functional run once in Firefox on the Deck (the Stage 2 gate; record the Firefox version).

Green: `echo` answers in Firefox on the Mac and the other browsers' results are recorded either way; lint and warnings pass; the answers to handoff Stage 2's question list are in the rows file, each labelled. Stop: Rust fails to load in a browser (handoff default: name the cause class from the logged page error, continue with the others).

### T8: Deck baselines and template tax (sonnet, WT)

Owns: nothing in the repo; `WORK/results/deck-baseline/`. Deck only; it may run while the Mac builds.

- [ ] Measure one full `W1` run end to end first and note its duration. If it takes over 15 minutes, use `only=move_open,move_dense,combat_open,combat_dense,skirmish3v3,hordes300` for the interleaved runs and add one full run per configuration.
- [ ] `W1` and `W2`, three runs each, interleaved (W1 W2 W1 W2 W1 W2), the same `only=` list and warm row in both, fresh Firefox profile per run, `ACAD/online` and `/proc/loadavg` at start and end, `crossOriginIsolated` true in every log.
- [ ] `R1` and `R2`, three runs each, interleaved, report-only: same scene, same quality and interpolation setting in both (record which; if the auto-pick differs between runs, the pair is not compared), frame-time lines as the art lab Web rows (`docs/reference/art-lab-verification.md`).
- [ ] Rows: per row p50, p95, p99 and worst per run and the median; T on p50 and p95 with the A/A spread (the spread of the three `W1` runs); Q = `hordes300` p95 / 10 from `W1`; the rendered pair's ratio; export sizes.

Green: the logs carry `BENCH DONE` (or the rendered benchmark's completion line) and the rows are written. Stop: the Deck stops answering (handoff default).

### T9: Integration and behaviour evidence (opus, WT)

Owns: fixes inside the files of T2, T5, T6 and T7 that integration needs (named in the return); copies `WORK/rows/t2.md` to `t8.md` (those that exist) and its own Stage 5 rows into the verification file.

- [ ] If the coordinator's brief names a task that was not integrated, bring its owned paths over with `git checkout spike-native-sim-<t> -- <paths>` when that is safe, or leave it out and say so.
- [ ] `build.sh all` with default features; `cargo test` for the workspace; clippy; `build.sh place`.
- [ ] Row 5: with the extension **removed**: `sh tools/run_tests.sh`, `sh tools/run_netplay.sh match`, lint, warnings; trace checks as the suite contains them (`sh tools/compare_local_traces.sh` only if it runs without a CI run id). With the extension **placed** and mode `off`: the suite again, then with `WARGRID_NATIVE_REQUIRED=1` (quote both `NATIVE CASES RAN` lines). Counts equal T0's plus the new tests.
- [ ] Row 1: desktop `bench_runner.gd` with `native=shadow slices=horde,move timing=1` over all eight rows: every `SLICE` line says `mismatch=none`. Then `native=native`, `native=pass` and `native=shadow`: every `DIGEST` line of each equals the `native=off` run's (this is also the proof that `pass` and shadow do not perturb state).
- [ ] Row 2: the `native` run three times; identical `DIGEST` lines.
- [ ] Row 3: `wargrid_runner replay` on every fixture on the Mac and in the Linux container; if the Deck is up, also on the Deck (`deck.sh`). Identical results.
- [ ] Row 4: the `W3` export in Firefox on the Mac with `native=native&slices=horde,move&only=hordes300,move_open`: `DIGEST` lines equal the desktop run's. (The Deck half is T11's.)
- [ ] One check that the `macOS Bench` export of a working-tree copy runs with the extension (`build/macos/WargridBench.app/Contents/MacOS/... --headless -- native=native slices=horde,move only=hordes300`). If it does not load the extension, T10 uses the editor binary headless and labels its rows "editor build".
- [ ] If one slice is BLOCKED or not behaviour-equal, do all of the above with the green slice and say so in every row.

Green: the five rows are in the verification file with tree, host, command and result; a failing row names the first tick, entity and field. Stop: a trace or pin moves with mode `off` (handoff default).

### T10: Mac measurements (sonnet, WT)

Owns: nothing in the repo; `WORK/results/mac/`. Runs alone on the Mac ("Quiet Mac for timing"). In this order; stop where the time box ends and report what ran:

- [ ] Desktop (the build T9 named), rows `hordes300` and `move_open`, three runs per mode, interleaved: `native=off timing=1`, `native=native timing=1`, `native=pass timing=1`. Whole-tick p50, p95, p99, worst; the `SLICE` sums.
- [ ] Kernel alone: `wargrid_runner bench` on each fixture, labelled "kernel, not the gate".
- [ ] Firefox, `W3`, the same three modes and rows, three interleaved runs; then `W1`, `W2`, `W3 native=off` three interleaved runs with one `only=` list (the Mac's template tax); `probe=1` three times.
- [ ] One run per mode in Safari and in Vivaldi; one `native` run of the 4.0.20 export in Firefox.
- [ ] `R1` against `R2` in Firefox, three interleaved runs, same quality and interpolation setting, report-only.
- [ ] Clean and incremental build times of `build.sh mac` and `build.sh web`.
- [ ] Rows with K (range), H, E per slice and for both, s on this host, T, each with the A/A spread, per build and browser. Never multiply by F.

Green: rows written, every one with its raw-log path.

### T11: Deck measurements (sonnet, WT)

Owns: nothing in the repo; `WORK/results/deck/`. In this order; stop where the time box ends:

- [ ] `deck.sh push` the `W3` export of the T9 tree. Stage 5 row 4, Deck half: `native=native&slices=horde,move&only=hordes300,move_open` gives the same `DIGEST` lines as the Mac.
- [ ] Rows `hordes300` and `move_open`, three interleaved runs per mode (`off`, `native`, `pass`, all with `timing=1`), fresh Firefox profile per run, power and load recorded.
- [ ] `W3 native=off` three runs interleaved with three new `W1` runs, same `only=` list (the "extension loaded but unused" tax and, if T8 did not run, T and Q).
- [ ] `probe=1` three times (snapshot hand-off on the gate device).
- [ ] Rows: K (range), H, E per slice and together, s on the Deck, T, the measured whole-tick p95 with both slices native against `off`, each with its A/A spread. These are the decision rule's numbers.
- [ ] `deck.sh clean` removes only what the run created.

Green: rows written with raw-log paths. Stop: the Deck stops answering (handoff default).

### T12: Report (opus, WT)

Owns: `docs/reference/native-sim-spike.md`; copies `WORK/rows/t10.md` and `t11.md` into the verification file; one ledger row in `docs/reference/performance.md` only for runs that followed the ledger's protocol.

- [ ] Write the report in the handoff's order (sections 1-8) from the verification file, the boundary and slice notes and the candidates note. Evaluate the decision rule with the Deck numbers; if the Deck was down, evaluate it with the Mac Firefox numbers, labelled "not the gate", and the outcome is at most CONDITIONAL GO.
- [ ] G_inc with its ceiling for the measured s and for the largest share flat-buffer slices could cover (55.9 % on the Mac profile, with the target grid and scan). G_port with the lower end of the K range and, next to it, the upper end; with p in two versions, each for Dictionary-shaped and packed hand-off: p = probe cost / tick (the hand-off charged in full) and p = (probe cost - today's `snapshot()` cost) / tick (only the extra cost, since today's snapshot is outside the timed tick). All labelled estimates.
- [ ] The "re-evaluate later" recipe, the lockstep rule the recommendation relies on, the mapping onto sim-core-options §4.3, the first-import crash and the toolchain pins as maintenance cost, and the sentence that the packed-column GDScript comparison (§4.2 b) is still missing.

Green: every number in section 1 has a row in the verification file; links and paths resolve.

### T13: Gate review (opus, fresh context, WT)

Brief: the "Review Focus" list above, the report, the verification file, the boundary and slice notes and `git diff main...spike-native-sim`. Read-only. It returns findings ranked critical, important, minor, each with file and line.

### T14: Fixes, lean review, morning summary (opus, then coordinator)

- [ ] Subagent (opus): fix critical and important findings (test-first where code changes), record a ruling for each other finding in the verification file, then run `/ponytail-review` on the branch diff, apply its cuts and re-run "Checks before GREEN".
- [ ] Coordinator: final commit; resume record; finish `WORK/morning-summary.md` (outcome in one line, the K, H, E, T table, what was skipped or defaulted and why, what needs the user: Deck reruns, decisions, the push, deletable task trees); send the one notification.
