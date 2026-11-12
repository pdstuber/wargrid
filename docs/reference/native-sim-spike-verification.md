# Native simulation core spike: verification

Resume record and dated evidence for the handoff (`native-sim-spike-prompt.txt`, private) and [its plan](../superpowers/plans/2026-11-10-native-sim-spike.md). Labels: **measured** (run here), **source** (quoted file or fetched page), **inferred**, **unverified**. Rows below the resume record are append-only.

```text
Resume record (updated 2026-11-10 run finished, coordinator)
Branch / base commit / working-tree state: spike-native-sim in ~/projects/wargrid-wt-native, base dde868e, clean; pushed by the user 2026-11-11 (49784cf); docs copied to main as 260d0c6
Last green task / next incomplete task: T0-T14 all green / none; the run is finished
Changed paths since last commit: none
Last command / cases / checks / failures / exit / marker: T14: cargo test 24 passed, clippy, lint, warnings, python checks exit 0; last suite run 737 cases 139594 checks 0 failures (T9, extension removed)
Known red case or blocker: none. Outcome CONDITIONAL GO (whole port only); open items in docs/reference/native-sim-spike.md
Approved decisions, pre-authorizations used, deferred gates: local commits only; no push, PR, merge or deploy
Usage so far: not recorded
Next exact action: user reads docs/reference/native-sim-spike.md and ~/projects/wargrid-native-work/morning-summary.md
```

## Stage 1 record (done 2026-11-10 with the user, before invocation)

- **Hypothesis:** compiled code is several times faster than GDScript on the same work, but data that stays in per-entity Dictionaries makes the hand-off dear enough that single hot loops cannot close the gap; the hand-off cost H decides between hot loops, a whole port and no port.
- **Workload and base:** `hordes300` (`game/scripts/debug/combat_workload.gd:118`, 400 fighting units), 300 warm-up plus 1800 sampled ticks; also `movement open` for the movement slice. Base: the `main` commit that holds this file.
- **Slices (user):** the horde step (`game/scripts/simulation/horde.gd:15`) and the movement of moving units (`simulation.gd:550-553`, `_advance` at `:599`, `locomotion.gd`), ported in parallel.
- **Timing boundaries:** per slice the GDScript work, the whole replacement path (packing, call, native work, unpacking, applying) and a pass-through with the same packing and no work; summed over the sampled window, never single calls; whole-tick p50, p95, p99 and worst as today.
- **Oracle:** shadow mode (both implementations on the same inputs every tick, outputs compared field by field, first mismatch reported with tick, entity and field), `StateHash.digest` lines between runs with the native path off and on, and recorded fixtures replayed by the standalone runner.
- **Platforms:** macOS arm64 native; Linux x86-64 (container on the Mac, then the Deck); WASM in Firefox, Safari and Vivaldi on the Mac; WASM in Firefox on the Deck (the gate). Windows: unverified (CI only).
- **Coverage ceiling (inferred from the shares below):** the two slices cover 40.7 % of the tick, so with no template tax their ceiling is 1 / (1 - 0.407) = 1.69, below the need 1.45 x 1.5 = 2.18. All flat-buffer candidates together (movement, horde step, target grid and scan: 55.9 %) reach 2.27 only with infinitely fast native code. Expected outcome class: hot loops cannot reach the line; the whole-port projection and H carry the verdict.
- **Planned experiments, time boxes and stop defaults:** the plan's dispatch table and the handoff's "Night rules".

## Pre-run evidence (2026-11-10 evening, tree `main` 57716a8, Apple M6, macOS 27.2.1 installed that evening)

Host note (measured): the macOS update left `ANECompilerService` at about 320 % CPU and load 5-11 during these runs, so the shares below are evidence and the milliseconds are not. `sh tools/run_profile.sh` still gave hordes300 `step` p95 2.842 ms, the ledger's 2.84-2.86.

### Profile shares on HEAD (measured, `sh tools/run_profile.sh`, profiler on; share of the `step` mean)

Sub-zones of `step.advance` come from a scratch copy with five extra zones (`~/projects/wargrid-native-work/prep/advance-subzones.patch`; logs `profile-head.log`, `profile-sub.log` there).

| Zone | hordes300 | combat open | combat dense | team match | movement open |
|---|---|---|---|---|---|
| `step` mean ms | 2.04 | 1.26 | 0.99 | 1.16 | 0.60 |
| `advance.move` | 21.4 % | 21.3 % | 22.1 % | 18.7 % | 76.4 % |
| `advance.horde` | 19.3 % | 2.4 % | 2.5 % | 4.7 % | 0.1 % |
| `combat.build_grid` | 8.5 % | 7.9 % | 8.2 % | 9.3 % | 0 |
| `combat.nearest` | 6.7 % | 9.2 % | 10.9 % | 1.4 % | 0 |
| `step.combat_plan` (all) | 39.9 % | 51.1 % | 50.8 % | 37.2 % | 0.2 % |
| `step.combat_fire` | 7.0 % | 12.5 % | 11.7 % | 11.9 % | 0.5 % |
| outside `step`: `snapshot` | 49.5 % | 45.8 % | 47.0 % | 47.9 % | 123 % |
| outside `step`: `view.batch` | 86.8 % | 65.0 % | 67.5 % | 74.3 % | 202 % |

Readings: the acquisition scan the handoff called an obvious candidate is 6.7 % (15.2 % with its grid); about 25 % of the tick is `Combat.plan`'s own per-unit bookkeeping with no kernel to extract; per tick the presentation side (`snapshot` 1.01 ms plus `view.batch` 1.77 ms) costs more than the simulation step (2.04 ms).

### Toolchain smoke build (measured; throwaway, `~/projects/wargrid-native-work/smoke/`, not Stage 2 evidence)

A hello-world gdext extension (one class, a `PackedFloat32Array` in, a computed one out) in a Godot 4.7.2 web export with `variant/extensions_support=true`, `variant/thread_support=false`:

| Rust | Emscripten | Result |
|---|---|---|
| stable 1.99.1, `api-4-7` | - | native macOS arm64: `SMOKE OK`, build about 6 s |
| nightly-2026-03-15 (1.96.0-nightly 03749d625) | 3.1.74 | **works**: Firefox 160, Safari 27.2, Vivaldi (Chrome 156); clean build 14.9 s |
| nightly-2026-05-30 (1.98.0-nightly 6368fd52c) | 3.1.74 | works (Firefox only tried) |
| nightly-2026-03-15 | 4.0.20 | **works** (Firefox 160, isolated); build 14.2 s |
| nightly 2026-11-09 (1.102.0) | - | not tried: `rustc -Z help` has no `emscripten-wasm-eh` flag any more |

- Loads with and without the cross-origin isolation headers in all three browsers (`crossOriginIsolated` 1 and 0).
- Safari posted nothing on its first cold load and worked on two retries; cause unknown. Repeat cold loads before trusting Safari.
- Sizes: extension 362 kB; engine `index.side.wasm` 44.1 MB plus `index.wasm` 1.5 MB (the extension-enabled template splits the engine).
- Recipe: `godot = { version = "=0.5.5", default-features = false, features = ["api-4-7"] }`, web features `experimental-wasm`, `experimental-wasm-nothreads`, `lazy-function-tables`; the gdext book's five `rustflags` (`smoke/rust/.cargo/config.toml`); `cargo +nightly-2026-03-15 build --release -Zbuild-std --target wasm32-unknown-emscripten` after `. ~/emsdk/emsdk_env.sh`; `.gdextension` keys `web.debug.wasm32` / `web.release.wasm32`, entry `gdext_rust_init`. `api-custom` is not needed.
- First import crash (measured, reproduced twice): with the native library present, `godot --headless --path project --import` on a fresh `.godot` cache ends with "Program crashed with signal 11" and exit 134 after "Loading docks"; the next import exits 0, and the run, `--editor --quit` and the web export after it are clean. Three imports on a warm cache: no crash. Order does not help: an import without the extension, then placing it, then importing crashes once all the same; and a plain game run between placing and that import does not find the extension's class (`SMOKE FAIL class Smoke missing`). So it is the first editor-mode import that registers a new extension. Scripts that place the extension or export from a fresh copy import twice; each crash raises a macOS crash dialog.
- `nightly-2026-03-15` has no clippy (`ls` of its `bin`); stable 1.99.1 has it.
- Not tested: panic behaviour, memory growth, a debug web build, Firefox on the Deck, Emscripten 4.0.20 in Safari and Vivaldi.

### Sources (fetched 2026-11-10; raw copies in `~/projects/wargrid-native-work/prep/toolchain-sources/`)

- Godot 4.7.2 web templates are built with Emscripten 4.0.20: `godot.js` in the local template holds `allocString("4.0.20")` (measured); `build-containers` branch 4.7 `Dockerfile.web`: `ENV EMSCRIPTEN_VERSION=4.0.20` (source).
- gdext book, `toolchain/export-web.md`: "We recommend version **3.1.74** when targeting Godot 4.3 or later"; "Web support in godot-rust is experimental"; "godot-rust cannot catch panics in Wasm yet ... your game will abort"; debugging only through Chrome's "C/C++ DevTools Support" (source).
- The 4.7.2 template uses legacy JavaScript exception handling (`__cpp_exception`, `__THREW__` in `godot.js`, measured), so the Rust side needs `-Z emscripten-wasm-eh=false`; that flag was removed from nightly in 2026-06 (gdext issue #1119, source), hence the pinned older nightly. Godot PR 124118 (merged to master 2026-10-06, a later release) builds the extension-enabled main module with Wasm exceptions, which will change this pin on an engine upgrade.
- Godot docs, exporting for the web: "Like thread support, enabling this feature requires the use of cross-origin isolation headers." The engine code checks isolation only when threads are on (`platform/web/js/engine/features.js`, source), and the smoke build loads without the headers (measured): the sentence is over-broad for a no-threads build.
- gdext 0.5.5 (2026-08-09), minimum Rust 1.94, features `api-4-7`, `experimental-wasm`, `experimental-wasm-nothreads` (source: its `Cargo.toml`).
- Godot's vector maths for the float audit: `~/projects/wargrid-native-work/refs/godot-4.7.2-stable/` (`vector2.h`, `vector2.cpp`, `math_defs.h`, `math_funcs.h`, tag `4.7.2-stable`); `real_t` is `float` in official builds (`math_defs.h:146`).

### Environment (measured)

- Linux x86-64 builds: `container run --rm --platform linux/amd64 docker.io/library/rust:1.94-slim` works on this Mac (rustc 1.94.1, gcc 14.2); image cached; the container service was started by hand (the user's auto-mode settings refuse `container system start`).
- Steam Deck: `ssh deck@<deck>` timed out at 20:22; the user sets it up before the run. Check: `sh ~/projects/wargrid-native-work/deck-preflight.sh <address>`.
- `pmset`: system sleep after 1 minute unless prevented; start the run under `caffeinate`.
- Emscripten 3.1.74 in `~/emsdk`, 4.0.20 in `~/projects/wargrid-native-work/emsdk-4.0.20`; neither is on `PATH`.
- Firefox on the Mac: a terms-accepted profile for the benchmark runs is `~/projects/wargrid-native-work/profiles/firefox-accepted` (created 2026-11-10; the user accepts the first-run page in it once); earlier spikes lost runs to that page.
- The handoff fact check found the stale lines fixed in the 2026-11-10 rewrite (queue order, art lab state, test counts, `bench_runner.gd` without hordes300 on `main`, the 5x line).
- A fresh-context builder check of handoff, plan and settings (2026-11-10, 27 findings) is folded into the plan: task worktrees with cherry-pick instead of one shared tree, exports from the working tree, timers split into packing, call and applying with K as a range, row ids, the warm row, a required-native test switch, rows files instead of parallel writes to this file.

## Task rows (copied by T9 from ~/projects/wargrid-native-work/rows/, 2026-11-10 22:50)

Copied verbatim, headings demoted. `t8.md` did not exist yet (T8 still running on the Deck); T12 copies it.

### T2 rows (skeleton, bridge and boundary note)

Tree `~/projects/wargrid-native-work/wt/t2`, branch `spike-native-sim-t2`, HEAD 0570f6a plus uncommitted T2 work. Host: Mac (Apple Silicon), macOS 27.2.1, Godot 4.7.2.stable.official.ed1daf0bf, rustc 1.96.0-nightly (03749d625 2026-03-14) via `native/rust-toolchain.toml`, clippy from stable. Raw logs in `~/projects/wargrid-native-work/logs/t2/`. All rows measured 2026-11-10 21:34-22:00 CET unless labelled.

| # | Command | Result | Label | Log |
|---|---|---|---|---|
| 1 | `WARGRID_TEST_ONLY=test_native sh tools/run_tests.sh` before the bridge existed | red: `Preload file "res://scripts/native/native_bridge.gd" does not exist`, suite failed to load, exit 1 | measured | `red.log` |
| 2 | `cargo test -p wargrid_core -p wargrid_runner` (Mac) | 6 passed, exit 0 | measured | `cargo-test-2.log` |
| 3 | `cargo tree -p wargrid_core` | only `wargrid_core v0.1.0`: no dependency | measured | `cargo-tree-core.log` |
| 4 | `sh native/tools/build.sh mac` | exit 0, 6.65 s (warm crate cache), `libwargrid_native.dylib` 1,532,512 B | measured | `build-mac-1.log` |
| 5 | `sh native/tools/build.sh web` (emcc 3.1.74, `-Zbuild-std`, wasm32-unknown-emscripten) | exit 0, 12.47 s (warm), `wargrid_native.wasm` 405,602 B | measured | `build-web-1.log` |
| 6 | `sh native/tools/build.sh linux` (container `rust:1.94-slim`, rustc 1.94.1, no Godot in the image) | build of core, runner and adapter plus `cargo test -p wargrid_core` 6 passed; `cargo tree` shows no dependency; exit 0, 35.8 s; ELF x86-64 runner and `.so` in `build/t2/linux/target/release/` | measured | `build-linux-1.log`, `build-linux-2.log` (rerun on the final tree) |
| 7 | `cargo +stable clippy --workspace --all-targets -- -D warnings` | exit 0 (first run flagged `default` on unit structs, fixed) | measured | `clippy-2.log` |
| 8 | Known trap reproduction: `build.sh place` after a first import, then again after `rm -rf game/.godot` | first import exit 0 both times: **not reproduced** in this tree; `place` still imports twice and requires the second | measured | `place-1.log`, `place-2-fresh-cache.log`, `import-place-*.log` |
| 9 | `godot --headless --path game --script res://benchmarks/native_fixture.gd -- only=small native=shadow slices=horde,move ticks=120 record=.../fixtures/t2-stub-small.bin` (extension placed) | `EXTENSION classes=WargridHorde,WargridMovement,WargridProbe probe=wargrid_native 0.1.0`; stubs answer `not implemented`; exit 0 | measured | `fixture-stub-shadow.log` |
| 10 | Same driver, modes `off`, `off timing=1`, `pass`, `native` (stubs) | `DIGEST small tick=120 0c657dea32740b04` in all four and in shadow: the hook leaves the game unchanged | measured | `fixture-stub-modes.log` |
| 11 | `native/target/release/wargrid_runner replay fixtures/t2-stub-small.bin` | `REPLAY ERROR slice=move tick=0 move: not implemented`, exit 1 (format parsed; stubs) | measured | shell output, row 9 file |
| 12 | `WARGRID_NATIVE_REQUIRED=1 sh tools/run_tests.sh`, extension placed, mode off | `CASES 736 CHECKS 139585 FAILURES 0`, `TESTS PASSED 139585`, `NATIVE CASES RAN 1` twice, exit 0 (baseline T0: 728 / 139569) | measured | `suite-placed.log` |
| 13 | `sh native/tools/build.sh remove` then `sh tools/run_tests.sh` | `REMOVED`; extension file, `native_bin/` and `extension_list.cfg` entry gone; `CASES 736 CHECKS 139587 FAILURES 0`, `TESTS PASSED 139587`, exit 0 (native cases skipped, always-on checks counted) | measured | `suite-removed.log` |
| 14 | `sh tools/run_lint.sh` | `Success: no problems found`, exit 0 | measured | `lint.log` |
| 15 | `sh tools/run_warnings.sh` (after `git add -N` of new files) | `WARNINGS CHECKED 143 FILES`, exit 0 | measured | `warn.log` |
| 16 | `PATH=.../wargrid/tools/.venv/bin:$PATH sh tools/run_python_checks.sh` (sim math and sim boundary checks see the new files) | `PYTHON TESTS PASSED`, exit 0 | measured | `py.log` |

Deviation from "Conventions" (recorded): build outputs go to `WORK/build/<tree>/{mac,web-<emcc>,linux}` instead of one shared `WORK/build/`, and the Linux container mounts `WORK/build/<tree>/linux` as `/out`, so parallel task trees cannot overwrite each other's libraries; the crate cache is shared in `WORK/build/linux-registry`. Slice method `call` is named `call_native` (`call` is `Object.call`); adapter methods are `run`, `run_pass`, `last_error`.

### T3 rows (2026-11-10, tree wt/t3, base 0570f6a plus uncommitted T3 work, Mac Apple M6, Godot 4.7.2 editor)

Labels: measured unless noted. Mac rows are smoke runs, not timing evidence (no quiet-host protocol).

| What | Command | Result | Raw log |
|---|---|---|---|
| hordes300 row, desktop | `godot --headless --path game --script res://benchmarks/bench_runner.gd -- only=hordes300` | exit 0; `COMBAT hordes300 ... p95 2.821`, 8 DIGEST lines (last tick=2100 816e76bc1461ee53) | logs/t3-hordes.log |
| unknown row / option | `-- only=bogus`, `-- foo=1` | `BENCH FAILED unknown row/option ...`, exit 1 (measured by log text; the shell exit shown was tail's) | - |
| W1 / W2 / R1 / R2 export | `sh native/tools/export_tree.sh <name>` | exit 0 each. W1, R1: no index.side.wasm, 51784 KB. W2, R2: index.side.wasm 44078870 B + index.wasm 1508095 B, 60236 KB. Presets differ only in extensions_support | exports/t3-0570f6a/*.log, *.git |
| Mac Firefox 160 W1 | `web_run.sh mac firefox W1 only=contact t3-w1` | OK, BENCH DONE, 7 DIGEST lines, contact p95 1.6 (smoke), isolated=1 | results/t3-w1/ |
| Mac Firefox 160 W2 | same, t3-w2 | OK, 7 DIGEST lines identical to W1, contact p95 1.8 (smoke) | results/t3-w2/ |
| digest parity | contact tick=2100 | desktop editor, web W1, web W2 all 081eeb3b3a0e77b4 | - |
| broken export (index.wasm removed) | `web_run.sh mac firefox <copy> only=contact t3-broken 60` | exit 7 `PAGE ERROR`, log holds `JSERR REJ Error: Failed loading file 'index.wasm'` | results/t3-broken/ |
| lock | second `web_run.sh mac ...` while one runs | exit 6 `LOCKED by pid <pid>` | - |
| Deck Firefox 159, W1 | `web_run.sh deck firefox W1 only=contact t3-deck-w1b 300` | OK, BENCH DONE, isolated=1, contact p95 5.9; Deck folder, units and profile removed afterwards (verified by ls and systemctl) | results/t3-deck-w1b/ |
| lint, warnings, python checks | run_lint.sh, run_warnings.sh, run_python_checks.sh | all pass (warnings checked 137 files) | logs/t3-*.log |

Unverified: a full no-option run of bench_runner (order of all rows, incl. 45000-tick team); Safari and Vivaldi paths of web_run.sh (written, not run); the Deck NO RESULT retry path; `noiso` flag end to end; W3 (T7).
Notes: first Deck attempt exposed two bugs (remote pkill matched its own ssh shell; port check lacked SO_REUSEADDR), both fixed. Deck bench tar xattr warnings avoided with `tar --no-xattrs`.
Option keys beyond `only` and `warm` are accepted and ignored until T5-T7.

### T4 rows

- 2026-11-10, tree ~/projects/wargrid-wt-native, host Mac: fetched live via WebFetch (excerpted by a small model, not raw): gdext book export-web, godot-cpp README, Godot Exporting for the Web, Compiling for the Web (latest, not 4.7), gdext #438, #1119. Result: all six fetched; quotes in docs/reference/native-sim-spike-candidates.md. Label: source. Raw copies from the same day: WORK/prep/toolchain-sources/. Not re-fetched: Godot PR 124118. Gap: "Emscripten 6.0.12+" on the latest compiling page looks odd; not reconciled.
- Output: docs/reference/native-sim-spike-candidates.md (new, untracked; no commit).

### T5 horde slice rows (2026-11-10, host Mac, tree wt/t5, base 96000ae + uncommitted work)

| What | Command | Result | Log |
|---|---|---|---|
| Native test | `build.sh mac && build.sh place`; `WARGRID_NATIVE_REQUIRED=1 WARGRID_TEST_ONLY=test_native_horde sh tools/run_tests.sh` | exit 0, `NATIVE CASES RAN 11`, CASES 5 CHECKS 33 FAILURES 0 | logs/t5 (scratchpad t5c.log) |
| Without extension | `build.sh remove`; same test without the env var | exit 0, CASES 5 CHECKS 10 FAILURES 0 | scratchpad t5b.log |
| Mutation | core `rubbed` made always false, rebuilt | suite fails: shadow mismatch `tick=25 entity=300 field=level gd=1 native=0`, native digests differ | scratchpad t5mut.log |
| Rust | `cargo test -p wargrid_core`; `cargo +stable clippy --workspace -- -D warnings` | 13 passed (7 horde); clippy clean | - |
| GDScript | `sh tools/run_lint.sh`; `sh tools/run_warnings.sh` | both pass (143 files) | - |
| Fixture | `native_fixture.gd -- only=hordes300 native=shadow slices=horde ticks=2100 record=...` | `mismatch=none`, 29,073,670 bytes, gd_ms=803.7 pack_ms=472.1 call_ms=20.8 entities=620719 (shadow run, not a timing row) | logs/t5/record.log |
| Replay | `wargrid_runner replay fixtures/horde-hordes300.bin` | `REPLAY OK ticks=2100 records=2100` | logs/t5/replay.log |
| Kernel alone | `wargrid_runner bench ... 5` | 6.939 us per call (10500 calls); debug-free release build, one-off, not an evidence row | logs/t5/bench.log |

Not covered by GDScript scenario: contained units (Rust unit test `contained_and_hostile_do_not_count` only). Test files use the Mac only; Linux and web not run.

### T6 rows (movement slice)

Tree `~/projects/wargrid-native-work/wt/t6`, branch `spike-native-sim-t6`, HEAD 96000ae plus uncommitted T6 work. Host: Mac (Apple Silicon), macOS 27.2.1, Godot 4.7.2.stable.official.ed1daf0bf, toolchain from `native/rust-toolchain.toml`, clippy from stable. Other tasks (T5, T7) ran on the Mac at the same time: no row here is a timing row. Raw logs in `~/projects/wargrid-native-work/logs/t6/`. Measured 2026-11-10 21:52-22:14 CET unless labelled.

| # | Command | Result | Label | Log |
|---|---|---|---|---|
| 1 | `sh native/tools/build.sh mac`, then `place` | exit 0; `PLACED macos first_import_exit=0 second_import_exit=0` (known trap not hit) | measured | `build-mac-1.log`, `place-1.log` |
| 2 | `native_fixture.gd -- only=<w> native=<off,shadow,native,pass> slices=move ticks=2100` for `move_open`, `move_dense`, `hordes300` | all 12 runs exit 0; the 7 `DIGEST` lines (every 300 ticks and the end) identical across the four modes per workload; shadow `mismatch=none` | measured | `modes-<w>-<mode>.log` |
| 3 | Same driver, `native=shadow record=WORK/fixtures/move-{open,dense,hordes300}.bin ticks=2100` | exit 0, `mismatch=none`; final `PREFIX` 4: 98,839,276 / 98,839,276 / 94,495,186 bytes (first recorded with prefix 8, then re-recorded; the files on disk are the prefix-4 ones) | measured | `record-{open,dense,hordes300}.log` |
| 4 | `native/target/release/wargrid_runner replay WORK/fixtures/move-<n>.bin` (Mac arm64) | `REPLAY OK ticks=2100 records=2100` for open, dense, hordes300 (prefix-8 and prefix-4 recordings) | measured | `replay-mac-<n>.log` |
| 5 | Fixture statistics (scratch reader of the fixture format) | prefix 4: open and dense: 547,564 rows, 97.3 % truncated to the prefix (94.5 % with 8), routes up to 99 waypoints, wheels only; hordes300: 527,522 rows, 90.2 % truncated (79.1 % with 8), routes up to 73, legs and treads only; **0 fallbacks**, at most 1 waypoint consumed per tick, no air rows | measured | `fixture-stats.log` (prefix 8), `p4-summary.log` (prefix 4) |
| 6 | `WARGRID_NATIVE_REQUIRED=1 WARGRID_TEST_ONLY=test_native_move sh tools/run_tests.sh`, extension placed | `NATIVE CASES RAN 10`, `CASES 4 CHECKS 33 FAILURES 0`, `TESTS PASSED 33`, exit 0 (prefix 8 and again with 4) | measured | `test-move-placed-3.log`, `test-move-placed-4.log` |
| 6b | Prefix sweep: shadow 2100 ticks of the three workloads with `PREFIX` 2, 3, 4 (scratch, reads the slice's `fallbacks`) | 0 fallbacks and no mismatch for every prefix; final choice 4. With 4, the DIGEST lines in off, native, pass and shadow equal the prefix-8 runs per workload (md5 `bde7a0f2`, `5cce409a`, `7194f6eb`) | measured | `prefix-fallbacks.log`, `p4-modes-<w>-<mode>.log`, `p4-summary.log` |
| 7 | `WARGRID_TEST_ONLY=test_native_move sh tools/run_tests.sh`, extension removed (`build.sh remove`) | `CASES 4 CHECKS 11 FAILURES 0`, `TESTS PASSED 11`, exit 0 (native cases skipped), final tree | measured | `test-move-removed-2.log` |
| 8 | `sh tools/run_tests.sh`, extension removed | `CASES 736 CHECKS 139591 FAILURES 2`, exit 1: both failures are `test_map.gd:59, 72` "MP5/MP9 eleven presets checked", which count 11 presets while T3 (commit 1d43859, in this base) appended two to `game/export_presets.cfg` (13 now). Pre-existing on the base, not T6; every other check passes | measured | `suite-removed.log` |
| 9 | `cargo test -p wargrid_core -p wargrid_runner -- --skip stubs_report_not_implemented` | 16 passed (11 new movement tests), exit 0 | measured | `cargo-test.log` |
| 10 | `cargo test -p wargrid_core` unskipped | 1 failure: `lib.rs` `stubs_report_not_implemented` expects the movement stub's "not implemented" (stale stub test in T2's `lib.rs`; T5 already edits the same line for horde). Delete the test at integration. | measured | `cargo-test-unskipped.log` |
| 11 | `cargo +stable clippy --workspace --all-targets -- -D warnings` | exit 0 | measured | `clippy.log` |
| 12 | `sh native/tools/build.sh web` (emcc 3.1.74) | exit 0 (compile only; no browser run in T6) | measured | `build-web-1.log` |
| 13 | `sh tools/run_lint.sh`; `sh tools/run_warnings.sh` | `Success: no problems found`; `WARNINGS CHECKED 143 FILES`; both exit 0, final tree | measured | `lint-2.log`, `warn-2.log` |
| 14 | Mutation: `turn` divides in float64 instead of narrowing the divisor to float32 (`Vector2::operator/(real_t)`), replay | `REPLAY MISMATCH slice=move tick=328 buffer=2 row=279 expected=0.866025447845459 (0x3febb67b00000000) got=0.8660253882408142 (0x3febb67ae0000000)` (open), tick 783 (hordes300): the float32 narrowing is real and the fixtures detect it; restored, `REPLAY OK` | measured | `mutation-divisor.log` |
| 15 | Mutation: `apply` without the non-moving branch (`speed = 0.0`) | the three workloads' digests do not notice (no unit leaves `moving` with speed there); the new `stop` scenario does: `FAIL: stop native: digests equal off every 1 ticks`; restored, green | measured | `mutation-rest.log`, `test-move-mutation-rest.log` |
| 16 | GDScript literal parse check: the 17 float literals of the slice as `PackedFloat64Array` bytes against Python `struct.pack('<d')` | equal | measured | scratch, result in this row |

Indicative only (loaded host, one run each, prefix 8, not evidence for K, H, E): `SLICE move_open move` over 2100 ticks, `pass`: `gd_ms=979.153 pack_ms=573.382 call_ms=8.354`; `native`: `pack_ms=579.104 call_ms=11.203 apply_ms=149.947`; hordes300 `pass` `gd_ms=1012.234 pack_ms=635.185 call_ms=11.762`, `native` `pack_ms=575.687 call_ms=12.710 apply_ms=135.456`. Packing is over half of the GDScript slice time on desktop; the kernel (`call - call_pass`) is about 3 ms per 2100 ticks. T10 measures this properly.

Choices recorded in `docs/reference/native-sim-spike-slice-move.md`: routes cross as a 4-waypoint prefix plus the full length; a kernel that would read past the prefix returns that row as `FALLBACK` and GDScript's `_advance` moves it (no native state, nothing can go stale). In `shadow`, a fallback row's expected value is the fallback row itself; 0 occurred.

Not covered by the workloads (row 5), covered instead by Rust unit tests and `test_native_move.gd` scenarios: air, several waypoints in one tick, the `1e-5` arrival tolerance, zero-length steps, an empty route, a short prefix; wheels from standstill, entering a container on arrival, a stop at speed. Not done in T6: Linux and WASM replays and browser runs (T9, T10, T11).

### T7 rows (browser probe and snapshot probe), 2026-11-10

Tree: ~/projects/wargrid-native-work/wt/t7 @ 96000ae + uncommitted T7 changes (working tree exported). Host: Mac (macOS 27.2.1, Apple M-series). Functional runs, NOT timing: single runs, Mac not checked quiet. Logs: WORK/results/<label>/ (run.txt, web-*.log, server.log), build logs WORK/logs/t7/.

#### Versions and commands (Stage 2: versions)
- Godot 4.7.2.stable (official), template web_dlink_nothreads_release 4.7.2 (its own banner: "Emscripten 4.0.20, single-threaded, GDExtension support").
- gdext godot 0.5.5 (`=0.5.5`, api-4-7, features experimental-wasm, experimental-wasm-nothreads, lazy-function-tables), runtime banner "godot-rust (API v4.7.stable.official, runtime v4.7.2.stable.official, safeguards balanced)".
- Rust nightly-2026-03-15, `-Zbuild-std`, target wasm32-unknown-emscripten, rustflags from native/.cargo/config.toml (SIDE_MODULE=2, default-visibility=hidden, link-native-libraries=no, emscripten-wasm-eh=false). Emscripten 3.1.74 (main) and 4.0.20 (comparison).
- Probe-only build: `cd native && cargo build --release -p wargrid_native --no-default-features --features probe[,godot/experimental-wasm,godot/experimental-wasm-nothreads,godot/lazy-function-tables -Zbuild-std --target wasm32-unknown-emscripten]` (4.0.20 with CARGO_TARGET_DIR=native/target/emcc-4.0.20). Then `sh native/tools/build.sh place [emcc=4.0.20]` (first/second import exit 0/0; the trap did not fire because the .godot cache already existed from an earlier plain import). wasm size 393634 B (3.1.74), 393370 B (4.0.20); dylib 1524672 B.
- Exports: `sh native/tools/export_tree.sh W1|W2|W3` and `W3 emcc=4.0.20` -> WORK/exports/t7-96000ae/{W1,W2,W3,W3-4.0.20}.
- Browsers: Firefox 160 (separate instance, fresh profile copy), Safari 27.2 (cold start each, quit by script), Vivaldi (UA Chrome/156). Run: `sh native/tools/web_run.sh mac <browser> <export> '<query>' <label> <timeout> [noiso]`.

#### Checks
- [measured] desktop probe: `godot --headless --path game --script res://benchmarks/bench_runner.gd -- only=contact probe=1` exit 0, all PROBE lines ok (WORK/logs/t7/desktop-probe.log).
- [measured] invariant: a run without native options prints the same BENCH/COMBAT/DIGEST/SLICE lines as T3's bench_runner (diff of the two outputs, t_ms/tick_ms stripped): identical, 10 lines, no SLICE lines.
- [measured] boundary: W2 (no extension) `native=shadow&slices=horde,move&only=contact` in Firefox: `SLICE contact - mode=shadow ... mismatch=extension missing`, then `BENCH DONE` (WORK/results/t7-ff-W2-shadow).
- lint `sh tools/run_lint.sh` exit 0; `sh tools/run_warnings.sh` exit 0 (144 files); `cargo +stable clippy -p wargrid_native --features probe -- -D warnings` clean; `cargo test -p wargrid_native` 0 tests ok. (tools/*.py unchanged: python checks not run; export_tree.sh is shell.)
- Note: with `--no-default-features --features probe`, stable rustc warns dead_code for lib.rs helpers (to_buffer, run_generic, answer) because the slices are off: expected, not an error.

#### Functional matrix, W3 (extension loaded), `probe=1&only=contact`
| label | browser | result | echo | grow held_ok | heap before->after (bytes) | first BENCH t_ms | cross_origin_isolated |
|---|---|---|---|---|---|---|---|
| t7-ff-w3 | Firefox 160 | OK, BENCH DONE | ok n=1024 | true | 260440064 -> 322043904 | 674 | 1 |
| t7-ff-w3-noiso | Firefox 160, noiso | OK | ok | true | same | 675 | 0 (extension works without COOP/COEP) |
| t7-safari-w3-1 | Safari 27.2 cold | OK | ok | true | 260440064 -> 320471040 | 634 | 1 |
| t7-safari-w3-2 | Safari 27.2 cold | OK | ok | true | same | 627 | 1 |
| t7-vivaldi-w3 | Vivaldi (Chrome 156) | OK | ok | true | 260440064 -> 322568192 | 790 | 1 |
| t7-ff-w3-emcc4020 | Firefox 160, extension built with Emscripten 4.0.20 | OK | ok | true | 260440064 -> 322043904 | 678 | 1 |
All: `PROBE keys match=true` (native dict key set and value types equal one real hordes300 entity at tick 100), digests identical to the GDScript run (f31c533ab4254fe3 ... 081eeb3b3a0e77b4). No Safari cold-load failure in two cold runs (smoke build had one).

#### Export size and time to first BENCH line (Firefox, `only=contact`, one run each, not timing)
| config | export size KB | first BENCH t_ms | contact tick p50/p95 ms |
|---|---|---|---|
| W1 (Web Bench) | 51804 | 677 | 0.38 / 1.68 |
| W2 (Dlink, no ext) | 60256 | 692 | 0.42 / 1.84 |
| W3 (Dlink + probe ext) | 60644 | 674 | 0.44 / 1.84 (probe run 0.44/1.84) |
W2/W1 on this single untimed run: p50 +10 %, p95 +10 %: the template tax T is T9/T10's measurement, not this row. W3 adds: index.side.wasm 44078870 B, wargrid_native.wasm 393634 B, index.js 2859484 B (W1: 279815 B), index.wasm 1508095 B (W1: 39514754 B).

#### Snapshot probe (400 entities, 300 repeats summed, ms; Mac, single run, not quiet-checked, labelled functional)
| where | today sim.snapshot() (whole snapshot) | native -> Array[Dictionary] | native -> packed columns |
|---|---|---|---|
| desktop (debug template, --script) | 388.0 | 1058.2 | 6.4 |
| Firefox 160 | 665.4 | 3151.0 | 9.8 |
| Firefox noiso | 666.0 | 3183.0 | 12.0 |
| Safari (2 runs) | 564.7 / 560.5 | 2809.8 / 2803.5 | 8.3 / 8.3 |
| Vivaldi | 610.3 | 3435.4 | 9.3 |
Reading [measured, caveat: snapshot-by-dict of 400 entities incl. 60-point routes, combat dicts]: building Godot Dictionaries from Rust owned data costs about 4.7-5.5x today's whole `sim.snapshot()` (which is a GDScript duplicate) in WASM; packed columns cost about 1.4-1.5 % of it. A native core that must hand presentation dictionaries per tick is not free: the hand-off must be packed columns or the presentation must read packed data. Packed shape: 10 columns (id, owner, position f64x2, hp, speed, move_after, route_len, route points f64x2, status u8, kind u8); order/combat sub-dicts are not in the packed variant (read-side decision for T12).

#### Panic and memory growth (Stage 2 questions)
- Rust panic (`probe=panic`, last action, interim result posted before the call):
  - Firefox: gdext panic hook logs `ERROR: [panic godot/src/probe.rs:158] probe panic` to console.error, then `Aborted(undefined)`; the page is dead (JSERR `RuntimeError: Aborted(undefined). Build with -sASSERTIONS for more info`, `___cxa_throw` in the stack), no `PROBE panic returned` line; process exit not applicable. Run verdict PAGE ERROR (rc 7), expected. Label t7-ff-w3-panic.
  - Safari: same abort (JSERR RuntimeError Aborted(undefined)); the panic message itself was not captured (no console capture in the Safari run). Label t7-safari-w3-panic.
  - Vivaldi: same (JSERR Uncaught RuntimeError Aborted(undefined)). Label t7-vivaldi-w3-panic.
  Cause class: panic unwinds as a C++ exception thrown with `___cxa_throw` and, with `emscripten-wasm-eh=false` and no catch, ends in abort. gdext's catch around #[func] does not recover on this target. A panic in the extension kills the game page in all three browsers: panics must be avoided or turned into error returns (the slices return `last_error`).
- Memory growth while a buffer is held: `grow(256)` (256 MB touched allocation inside the extension) while GDScript holds a 4096-element PackedFloat64Array: `held_ok=true fresh_ok=true` in every browser; HEAPU8.length grew by about 60 MB (260.4 MB -> 322.0 MB). Held packed arrays live in the wasm heap and are addressed by pointer, so growth does not invalidate them. No JS typed-array views are held by this code. [measured]
- Headers without threads: W3 ran with `noiso` (no COOP/COEP) in Firefox: OK, `cross_origin_isolated=0`. So the nothreads dlink build needs no COOP/COEP; only `Cache-Control`/MIME for `.wasm` and serving `index.side.wasm` and `wargrid_native.wasm` next to `index.html` (the server served all three with 200). The benchmark server sets COOP/COEP only for timer resolution. [measured on the Mac server; production hosting behaviour (fly/CDN) not checked]
- Debugging left: a panic gives the message line from the gdext hook and an unsymbolised wasm stack (function indices); `-sASSERTIONS` is not enabled in the template. Source-level debug of the side module in a browser was not tried [unverified].
- CI/hosting changes (describe only, none applied): web export needs the dlink template variant (`variant/extensions_support=true`), the extension library built on nightly with `-Zbuild-std` and `wasm32-unknown-emscripten`, an Emscripten install in CI, `native_bin/*.wasm` and `.gdextension` in the project at export, two extra files to deploy (`index.side.wasm`, `wargrid_native.wasm`), and larger download (export 51804 KB W1, 60256 KB W2, 60644 KB W3).
- Emscripten 4.0.20 vs 3.1.74 for the side module: both load and behave the same in Firefox (echo, snapshot, grow, identical numbers within noise); the 4.0.20 wasm is 264 B smaller. The template's own banner says Emscripten 4.0.20, so the 3.1.74 side module links into a 4.0.20 main module without trouble here. [measured, one browser]

#### Deck (Stage 2 gate)
[unverified] The W3 functional run on the Deck was NOT done. The Deck lock (WORK/locks/deck) was held by T8's back-to-back Deck runs from 22:11 to 22:23 (about 330 retries at 1 s, log WORK/logs/t7/deck-retry.log: all `LOCKED`), so the run never started. Stage 2 gate stays open. Command to run when the Deck is free (export is ready and kept):
`sh native/tools/web_run.sh deck firefox ~/projects/wargrid-native-work/exports/t7-96000ae/W3 'probe=1&only=contact' t7-deck-w3 600` (from the t7 tree; record the Firefox version from the logged UA line). Also available: W3-4.0.20 in the same folder, and a panic run with `probe=panic`.

### T9 rows (integration and behaviour evidence, Stage 5)

Tree `~/projects/wargrid-wt-native`, branch `spike-native-sim`, HEAD e2693e7 plus the uncommitted T9 fixes below. Host: Mac (Apple M6), macOS 27.2.1, Godot 4.7.2.stable.official.ed1daf0bf, rustc 1.96.0-nightly (03749d625 2026-03-14) from `native/rust-toolchain.toml`, clippy from stable, Linux container `rust:1.94-slim` (rustc 1.94.1, x86-64). T8 ran on the Deck at the same time (lock held by T8 throughout): no row here is a timing row. Raw logs in `~/projects/wargrid-native-work/logs/t9/`. Measured 2026-11-10 22:22-22:50 CET. The extension is removed again at the end (`build.sh remove`, `REMOVED`); the final suite, netplay, lint and warnings ran on that final tree. Both slices (horde, move) green: no slice was left out.

T9 fixes (integration):
- `game/tests/test_map.gd:59,72`: preset count 11 -> 13 (T3 appended `Web Bench Dlink` and `Web Render Bench Dlink`, authorized by the handoff; not a loosening: every preset is still checked for the notice and credits).
- `native/core/src/lib.rs`: stale `stubs_report_not_implemented` removed; its unknown-slice assertion kept as `unknown_slice_is_rejected`.
- `game/scripts/native/native_bridge.gd` `reset_report`: the warmup reset at tick 300 of every benchmark row wiped `mismatch` and `error`, so a shadow mismatch or a failed native call (which falls back to GDScript) in ticks 0-299 would have vanished from the `SLICE` line. Problems now survive the window reset; `configure` still clears them. Consequence: within one run a mismatch is reported on its row and repeated on later rows (its text carries the tick).

| Row | What | Command | Result | Label | Log |
|---|---|---|---|---|---|
| build | all targets | `sh native/tools/build.sh all` | exit 0, 42.5 s wall (warm caches): mac, web (emcc 3.1.74), linux (container, incl. `cargo test -p wargrid_core` 24 passed and `cargo tree -p wargrid_core`: no dependency) | measured | `build-all.log` |
| build | workspace tests | `cd native && cargo test --workspace` | 24 passed (core), 0 in the other crates, exit 0 | measured | `cargo-test.log` |
| build | clippy | `cargo +stable clippy --workspace --all-targets -- -D warnings` | exit 0 | measured | `clippy.log` |
| build | place | `sh native/tools/build.sh place` | `PLACED macos web.wasm32 linux.x86_64 first_import_exit=0 second_import_exit=0` (known trap not hit; `.godot` cache existed) | measured | `place.log` |
| 5 | suite, extension removed | `sh tools/run_tests.sh` | `CASES 737 CHECKS 139594 FAILURES 0`, `TESTS PASSED 139594`, exit 0 (T0: 728 cases; +9 cases from T2/T5/T6/T7 native suites) | measured | `suite-removed.log`, final tree: `suite-final.log` |
| 5 | netplay, extension removed | `sh tools/run_netplay.sh match` | `NETPLAY PASSED match 15.9 s` (final tree after `build.sh remove`: 14.1 s), exit 0 | measured | `netplay-removed.log`, final tree: `netplay-final.log` |
| 5 | lint, warnings | `sh tools/run_lint.sh`; `sh tools/run_warnings.sh` | `Success: no problems found`; `WARNINGS CHECKED 144 FILES`; both exit 0 | measured | `lint-*.log`, `warn-*.log` |
| 5 | traces | trace and pin checks inside the suite (replay, economy, combat, team traces and digest pins) | green as part of the suite above. `sh tools/compare_local_traces.sh` not run: it needs a CI run id (`gh run download`), so Linux/Windows trace comparison is unverified | measured / unverified | - |
| 5 | suite, extension placed, mode off | `sh tools/run_tests.sh` | `NATIVE CASES RAN 11`, `NATIVE CASES RAN 10`, `CASES 737 CHECKS 139639 FAILURES 0`, exit 0 | measured | `suite-placed.log` |
| 5 | suite, placed, required | `WARGRID_NATIVE_REQUIRED=1 sh tools/run_tests.sh` | `NATIVE CASES RAN 11`, `NATIVE CASES RAN 10`, `CASES 737 CHECKS 139639 FAILURES 0`, `TESTS PASSED 139639`, exit 0 | measured | `suite-req-placed.log` |
| 1 | shadow over all eight rows | `godot --headless --path game --script res://benchmarks/bench_runner.gd -- native=shadow slices=horde,move timing=1` | 16 `SLICE` lines (8 rows x 2 slices), all `mismatch=none`; horde saw entities on hordes300 (530,719) and team (1,572,700), move on every row; `BENCH DONE`, exit 0 | measured | `bench-r1-shadow.log` |
| 1 | digests per mode | same runner with no options (`pureoff`), `native=off timing=1`, `native=native`, `native=pass`, `native=shadow` (all `slices=horde,move timing=1`) | 199 `DIGEST` lines each (8 rows, team to the 45,000-tick cap); the DIGEST lines of off, native, pass and shadow are byte-identical to the no-option run (`cmp`), md5 of the pureoff DIGEST lines `ad523603dd498d596f4fd44d1dd0ad3d`. So `pass` and `shadow` do not perturb state, and native decides identically (native `apply_ms` > 0 and `calls=1800` per row show it did decide) | measured | `bench-r1-{pureoff,off,native,pass,shadow}.log` |
| 2 | native repeated | `native=native` three runs | DIGEST lines of the three runs identical to each other and to pureoff | measured | `bench-r1-native.log`, `bench-r2-native.log`, `bench-r3-native.log` (`r2` ran twice into one file; the three kept logs are three runs) |
| 3 | replay, Mac arm64 | `native/target/release/wargrid_runner replay WORK/fixtures/<f>.bin` | `REPLAY OK ticks=2100` for `horde-hordes300` (2100 records), `move-open`, `move-dense`, `move-hordes300` (2100 each) and the new `t9-hordes300-both` (4200 records, both slices, recorded on this integrated tree: `native_fixture.gd -- only=hordes300 native=shadow slices=horde,move ticks=2100 record=...`, mismatch none, final digest `816e76bc1461ee53`) | measured | `replay-mac.log`, `record-both.log` |
| 3 | replay, Linux x86-64 container | `container run --rm --platform linux/amd64 -v WORK/build/wargrid-wt-native/linux/target/release:/bin2 -v WORK/fixtures:/fx docker.io/library/rust:1.94-slim ... /bin2/wargrid_runner replay /fx/<f>.bin` | `uname -m` x86_64; `REPLAY OK` for the same five fixtures, same tick and record counts | measured | `replay-linux.log` |
| 3 | replay, Deck | not run: T8 held the Deck lock for the whole of T9 and a 320 MB copy plus CPU work would disturb its timing runs. Command for later: copy `WORK/build/wargrid-wt-native/linux/target/release/wargrid_runner` and `WORK/fixtures/t9-hordes300-both.bin` to the Deck folder, run `./wargrid_runner replay t9-hordes300-both.bin`, expect `REPLAY OK ticks=2100 records=4200`, clean the folder | unverified |  - |
| 3 | Windows | CI only (needs a push) | unverified | - |
| 4 | W3 in Mac Firefox 160 | `sh native/tools/export_tree.sh W3` (WORK/exports/wargrid-wt-native-e2693e7/W3, 60,720 KB, `index.side.wasm` and `wargrid_native.wasm` present); `sh native/tools/web_run.sh mac firefox <W3> 'native=native&slices=horde,move&timing=1&only=<row>' t9-ff-w3-native-<row> 900` for `hordes300` and `move_open` (the runner takes one row per `only=`, so two runs) | both `BENCH DONE`, `cross_origin_isolated=1`; the 7 DIGEST lines of each row equal the desktop `native` run's (diff empty); `SLICE ... mismatch=none`, horde 530,719 and move 442,998 entities on hordes300 | measured | `web-<row>.log`, `WORK/results/t9-ff-w3-native-{hordes300,move_open}/` |
| export | macOS Bench with extension | working-tree copy plus placed extension in `WORK/exports/t9-macos/src`, imported twice (exit 0, 0), `godot --headless --path <src>/game --export-release "macOS Bench" WORK/exports/t9-macos/WargridBench.app` (exit 0; `libwargrid_native.dylib` lands in `Contents/Frameworks`), then `.../Contents/MacOS/Wargrid --headless -- native=native slices=horde,move timing=1 only=hordes300` | `Initialize godot-rust ...`, `debug_build=false`, 7 DIGEST lines equal the editor native run (final `816e76bc1461ee53`), `SLICE` mismatch none, exit 0: T10 can use the exported release binary. Note the dylib is arm64 only inside a `universal` app (x86-64 Macs unverified) | measured | `export-macos.log`, `macos-bench-native.log` |

Indicative only (loaded host, single runs, not evidence for K, H, E), hordes300 desktop editor over the 1800 sampled ticks: off `gd_ms` horde 688.1, move 773.7; pass `pack_ms` 406.7 / 389.0, `call_ms` 4.7 / 7.3; native `call_ms` 18.2 / 10.0, `apply_ms` 8.6 / 107.6. Packing remains over half of the GDScript slice time; Firefox native: pack 750.7 / 701.2, call 40.9 / 29.4, apply 14.7 / 199.7 ms.

Not done in T9: Deck replay (above); Deck W3 (T11); Safari and Vivaldi digest runs (T7 covered them functionally with the probe); `compare_local_traces.sh` (needs a CI run id).

## Task rows (copied by T12 from ~/projects/wargrid-native-work/rows/, 2026-11-10)

Copied verbatim, headings demoted (`#` to `###`, `##` to `####`). T12 rows hold the arithmetic behind the [report](native-sim-spike.md) section 1.

### T8 rows (2026-11-10, tree ~/projects/wargrid-wt-native @ 1d43859, Deck Firefox 159 via native/tools/web_run.sh, mains power)

Exports (working tree of 1d43859, clean apart from the web_run/deck.sh edit below; git logs next to them): WORK/exports/wargrid-wt-native-1d43859/{W1,W2,R1,R2}. Sizes KB: W1 51784, W2 60236, R1 51784, R2 60236 (W2/R2 add index.side.wasm 44078870 B). Template tax in size: +8452 KB (+16.3 %).
Raw logs: WORK/results/t8-{w1-full,w1-2,w1-3,w2-1,w2-2,w2-3,r1-1..3,r2-1..3}/ (web-*.log plus run.txt with ACAD and /proc/loadavg at START and END). Loop logs: WORK/logs/t8-loop.log, t8-loop-r.log. Mac side: nothing timed.
Commands: `sh native/tools/web_run.sh deck firefox <export>/<W1|W2> 'warm=contact' t8-<label> 1500` (full run, all 8 rows), order W1 W2 W1 W2 W1 W2; renders `... <R1|R2> 'x=1' t8-<label> 900`, order R1 R2 R1 R2 R1 R2. Fresh profile per run (deck.sh). Analysis: scratchpad t8an.py / t8ran.py over the logs.

#### Duration and plan choice
One full W1 run (all 8 rows, warm=contact): 598 s (START 1794343383, END 1794343981), under 15 min, so all runs are full, no `only=` list. The `team` row is 465 s of it.

#### Checks
- All 6 W runs and 6 R runs: exit 0, `BENCH DONE` (W) / `RENDERED BENCHMARK PASSED 2` (R), `cross_origin_isolated=1` in all six W logs (R pages do not print the flag; served by the same isolating server).
- ACAD=1 at every START. Load (1 min) at START 0.80-1.61, at END 1.06-1.97; no other process on the Deck. All 12 runs unloaded by that measure (labelled: load average ~1.3 steady, the Firefox run itself).
- Rendered pair: zoom=0.5 quality=high interpolation=off in all six logs (fixed by the benchmark defaults, not auto-picked), layouts horde+ashfall, 300 units, 60 s sample, vsync=browser. Pair comparable.

#### W1 vs W2, tick_ms per run (ms), Deck Firefox. cols: run1 / run2 / run3 / median. W1 run1 = t8-w1-full.
| row | cfg | p50 | p95 | p99 | worst |
|---|---|---|---|---|---|
| move_open | W1 | 3.28/3.30/3.24 -> 3.28 | 3.90/3.84/3.96 -> 3.90 | 4.94/4.58/5.04 -> 4.94 | 17.20/17.60/16.96 -> 17.20 |
| move_open | W2 | 3.44/3.46/3.46 -> 3.46 | 4.10/4.20/4.18 -> 4.18 | 5.30/5.12/5.38 -> 5.30 | 18.74/18.48/19.00 -> 18.74 |
| move_dense | W1 | 3.34/3.40/3.30 -> 3.34 | 4.28/4.36/4.38 -> 4.36 | 4.92/5.12/5.36 -> 5.12 | 17.58/18.08/17.76 -> 17.76 |
| move_dense | W2 | 3.46/3.52/3.50 -> 3.50 | 3.96/4.02/4.02 -> 4.02 | 5.16/5.46/4.94 -> 5.16 | 18.66/19.08/18.84 -> 18.84 |
| combat_open | W1 | 6.28/6.28/6.24 -> 6.28 | 9.72/9.76/9.76 -> 9.76 | 11.34/11.38/11.50 -> 11.38 | 15.52/15.44/15.58 -> 15.52 |
| combat_open | W2 | 6.60/6.66/6.72 -> 6.66 | 10.32/10.34/10.40 -> 10.34 | 11.94/12.08/11.98 -> 11.98 | 16.46/16.52/16.70 -> 16.52 |
| combat_dense | W1 | 5.12/5.12/5.12 -> 5.12 | 9.24/9.24/9.32 -> 9.24 | 10.68/10.74/10.76 -> 10.74 | 15.64/15.82/16.64 -> 15.82 |
| combat_dense | W2 | 5.42/5.42/5.50 -> 5.42 | 9.88/9.82/9.90 -> 9.88 | 11.36/11.38/11.48 -> 11.38 | 16.44/16.68/16.50 -> 16.50 |
| contact | W1 | 1.28/1.30/1.30 -> 1.30 | 5.70/5.82/5.82 -> 5.82 | 7.92/8.10/8.06 -> 8.06 | 59.04/58.94/59.04 -> 59.04 |
| contact | W2 | 1.38/1.42/1.38 -> 1.38 | 6.18/6.26/6.20 -> 6.20 | 8.58/8.70/8.64 -> 8.64 | 63.48/63.46/63.60 -> 63.48 |
| skirmish3v3 | W1 | 2.86/2.88/2.90 -> 2.88 | 6.62/6.66/6.68 -> 6.66 | 7.42/7.46/7.46 -> 7.46 | 8.42/8.48/8.56 -> 8.48 |
| skirmish3v3 | W2 | 3.12/3.16/3.06 -> 3.12 | 7.06/7.10/7.08 -> 7.08 | 7.90/7.92/7.90 -> 7.90 | 8.96/9.12/9.12 -> 9.12 |
| hordes300 | W1 | 10.10/10.26/10.18 -> 10.18 | 14.62/14.80/14.64 -> 14.64 | 17.74/17.50/17.12 -> 17.50 | 38.38/38.90/39.08 -> 38.90 |
| hordes300 | W2 | 10.82/10.88/10.92 -> 10.88 | 15.50/15.52/15.58 -> 15.52 | 18.34/17.98/18.16 -> 18.16 | 41.54/41.84/42.38 -> 41.84 |
| team (45000 ticks) | W1 | 5.20/5.24/5.24 -> 5.24 | 11.38/11.48/11.44 -> 11.44 | 35.16/35.44/35.40 -> 35.40 | 69.06/70.98/69.86 -> 69.86 |
| team (45000 ticks) | W2 | 5.56/5.54/5.58 -> 5.56 | 12.10/12.12/12.18 -> 12.12 | 37.56/37.82/37.94 -> 37.82 | 71.56/72.44/72.26 -> 72.26 |

#### T = W2/W1 - 1 on medians, with the W1 A/A spread ((max-min)/median of the three W1 runs)
| row | T p50 | A/A p50 | T p95 | A/A p95 |
|---|---|---|---|---|
| move_open | +5.5 % | 1.8 % | +7.2 % | 3.1 % |
| move_dense | +4.8 % | 3.0 % | -7.8 % | 2.3 % |
| combat_open | +6.1 % | 0.6 % | +5.9 % | 0.4 % |
| combat_dense | +5.9 % | 0.0 % | +6.9 % | 0.9 % |
| contact | +6.2 % | 1.5 % | +6.5 % | 2.1 % |
| skirmish3v3 | +8.3 % | 1.4 % | +6.3 % | 0.9 % |
| hordes300 | +6.9 % | 1.6 % | +6.0 % | 1.2 % |
| team | +6.1 % | 0.8 % | +5.9 % | 0.9 % |

Reading: the dynamic-linking template costs about +5 to +8 % on tick time on every row, outside the A/A spread (0-3 %) on all p50 cells and all p95 cells except move_dense p95, which goes the other way (-7.8 %, W2 faster; unexplained, W1 move_dense p95 sits at the top of its own spread; not a template effect I can name). T is measured on the extension-less W2 build, so it is the pure template tax with no extension loaded.

#### Q (need)
Q = hordes300 p95 on W1 / 10 ms = 14.64 / 10 = **1.46** (median of three; runs 14.62/14.80/14.64; the 2026-11-08 row was 14.54 -> 1.45). hordes300 p99 17.50 vs the 20 ms target; worst 38.90 ms. Other rows p95 vs 10 ms: combat_open 9.76, combat_dense 9.24, move rows 3.9-4.4, skirmish 6.66, team 11.44 (above 10) on W1.

#### Rendered pair R1 / R2 (report-only), Deck Firefox 159, 60 s samples
Settings (all six runs, from the header): zoom=0.5 quality=high interpolation=off, vsync=browser, layouts horde (300 units) + ashfall. Medians of three, ms.
| metric | R1 | R2 | R2/R1 | R1 spread |
|---|---|---|---|---|
| horde tick p50 / p95 / p99 | 28.86 / 34.64 / 38.60 | 29.60 / 36.70 / 42.10 | 1.026 / 1.059 / 1.091 | 0.5 / 0.9 / 1.1 % |
| horde frame interval p50 / p95 / p99 | 32.86 / 73.46 / 266.06 | 32.72 / 200.74 / 310.74 | 0.996 / 2.733 / 1.168 | 0.4 / 3.2 / 1.9 % |
| horde CPU_FRAME total p50 / p95 / p99 | 28.24 / 71.32 / 260.42 | 25.96 / 196.28 / 304.08 | 0.919 / 2.752 / 1.168 | 5.4 / 3.6 / 2.1 % |
| ashfall tick p50 / p95 / p99 | 21.26 / 23.12 / 24.06 | 22.92 / 24.72 / 25.78 | 1.078 / 1.069 / 1.071 | 1.3 / 2.1 / 3.0 % |
| ashfall frame interval p50 / p95 / p99 | 26.66 / 32.66 / 33.36 | 28.64 / 36.26 / 37.92 | 1.074 / 1.110 / 1.137 | 6.9 / 0.4 / 0.9 % |
| ashfall CPU_FRAME total p50 / p95 / p99 | 18.04 / 23.08 / 24.22 | 19.92 / 26.80 / 27.78 | 1.104 / 1.161 / 1.147 | 1.2 / 2.1 / 3.2 % |
| draw calls (horde / ashfall max) | 4 / 23 | not extracted, same scene | | |
Reading: ashfall (steady scene) shows the template tax at +7 to +16 % on tick and frame. Horde frame tail (p95 73 -> 201 ms) is a different regime: the Deck cannot keep 30 Hz ticks there (tick p50 ~29 ms against a 33.3 ms tick), the frame-interval distribution is bimodal, and p95 lands on either side of the knee; R2 horde p95 spreads 172-237 ms across its own three runs. Do not read 2.7x as a template effect; the p50 (1.00) and tick ratios (1.03-1.09) are the usable horde numbers. Lines and raw samples: WORK/results/t8-r{1,2}-{1,2,3}/.

#### Changed repo files (not committed)
- `native/tools/web_run.sh`, `native/tools/deck.sh`: the completion grep and verdict now also accept `RENDERED BENCHMARK PASSED`; before this, an R run could only end in a timeout with `NO RESULT` (the plan's green line for the rendered benchmark was unreachable). `sh -n` passes; used for all R runs. Python checks not applicable (no .py change).

#### Unverified / not done
- No Mac comparison (T10's job). Safari/Vivaldi not touched. R pages' `crossOriginIsolated` not logged in the result (served by the same isolating server). Whether the Deck screen blanked during runs: no NO RESULT occurred in 12 runs. W1 runs 2 and 3 and all W2 runs ran back to back, so the first W1 run (t8-w1-full) had the coldest Deck (load 0.29 15-min average); its numbers are within the A/A spread.

### T10 rows (Mac measurements), 2026-11-10 23:04-23:40 CET

Tree ~/projects/wargrid-wt-native, built and exported from HEAD 1eb8f89 (working tree; only `native/tools/deck.sh` was dirty, by T11, not used here). Host Mac Apple M6, macOS 27.2.1 (`sw_vers`), Godot 4.7.2.stable.official, Firefox 160 (separate instance, fresh profile copy), Safari 27.2 and Vivaldi (Chrome 156) cold-started by web_run.sh, rustc 1.96.0-nightly (nightly-2026-03-15), Emscripten 3.1.74 (main), 4.0.20 (one comparison). Nothing else ran on the Mac; T11 ran on the Deck only.
Quiet check (plan rule): at the start no process matched `godot|cargo|rustc|emcc` and the top CPU process was 11 % (the claude CLI), so rows are NOT tagged "loaded" by the plan's rule. Load average was never below ~1.3 though (1.4-2.3 at run starts/ends, `uptime` is in each log): the Mac was shared with the user's session. Treat absolute numbers as "Mac, normal desktop background"; the A/A spread across the three interleaved runs is small (see below), so the ratios hold.
Never multiplied by F. Raw logs: desktop `WORK/results/mac/desktop/<row>-<mode>-<run>.log` (each starts with pwd, rev, uptime, command); Firefox/Safari/Vivaldi/render/probe `WORK/results/t10-<...>/web-*.log` with the run label equal to the folder; drivers `WORK/logs/t10/{builds,exports,desktop,web}.sh`, their outputs `WORK/logs/t10/{builds,exports,desktop,web-all,kernel}.log`, per-run web_run output `WORK/logs/t10/web-<label>.log`. Analysis script: scratchpad `t10an.py` (medians over the three runs, "(min-max)" in brackets is the A/A spread of that statistic). All 59 web_run invocations exit 0; 18 desktop runs exit 0 with `mismatch=none`.

Definitions as in Conventions: kernel = call(native) - call(pass); K range (upper gd/kernel, lower (gd-pack)/kernel, gd from the `off` run, pack from `pass`); H = pack + call_pass + apply (ms over the 1800 sampled ticks; per entity and per tick in us; bytes per entity in+out); E = gd/(pack+call+apply) all from the `native` run; s = slice gd / tick_sum of the `off` run. "both" = horde + move summed. Row `move_open` has no horde entities, so only move is listed there.

#### 1 Desktop, whole tick and slice sums (exported macOS Bench release app, extension loaded; `debug_build=false`)
Command: `WORK/exports/t10-macos/WargridBench.app/Contents/MacOS/Wargrid --headless -- native=<off|native|pass> slices=horde,move timing=1 only=<row>`, three runs per mode, interleaved off/native/pass per round, rows hordes300 and move_open. Label: measured, release app (not the editor build).
Whole tick (ms, median, spread in brackets), then slice ratios:

| desktop | hordes300 | off | n=3 p50 1.61 (1.61-1.61) p95 2.32 (2.31-2.33) p99 2.73 (2.73-2.73) worst 6.34 (6.28-6.37) |
| desktop | hordes300 | native | n=3 p50 1.33 (1.33-1.34) p95 2.05 (2.04-2.05) p99 2.47 (2.46-2.47) worst 6.08 (6.04-6.09) |
| desktop | hordes300 | pass | n=3 p50 2.01 (1.99-2.01) p95 2.70 (2.70-2.71) p99 3.11 (3.11-3.12) worst 6.76 (6.76-6.78) |
| desktop | move_open | off | n=3 p50 0.51 (0.51-0.52) p95 0.56 (0.56-0.56) p99 0.68 (0.68-0.68) worst 2.87 (2.85-2.89) |
| desktop | move_open | native | n=3 p50 0.37 (0.37-0.37) p95 0.39 (0.38-0.40) p99 0.44 (0.44-0.46) worst 2.87 (2.84-2.88) |
| desktop | move_open | pass | n=3 p50 0.72 (0.71-0.72) p95 0.76 (0.76-0.77) p99 0.87 (0.87-0.87) worst 2.90 (2.88-2.93) |

| desktop | hordes300 | horde | gd 568.8 ms, pack 331.2, call_pass 4.31, apply 7.3 | K 18.0-43.0 (kernel 13.23 ms, spread 0.31) | H 342.85 ms/1800 ticks = 0.646 us/entity = 190.5 us/tick = 60% of gd, 46 B in + 0 B out per entity | E 1.59 | s 19.5% |
| desktop | hordes300 | move | gd 609.9 ms, pack 296.0, call_pass 6.96, apply 90.9 | K 113.6-220.7 (kernel 2.76 ms, spread 0.10) | H 393.93 ms/1800 ticks = 0.889 us/entity = 218.8 us/tick = 65% of gd, 133 B in + 45 B out per entity | E 1.53 | s 20.9% |
| desktop | hordes300 | both | gd 1177.4 ms, pack 625.5, call_pass 11.27, apply 98.2 | K 34.5-73.6 (kernel 16.00 ms, spread 0.40) | H 735.00 ms/1800 ticks = 0.755 us/entity = 408.3 us/tick = 62% of gd, 86 B in + 21 B out per entity | E 1.56 | s 40.4% |
| desktop | move_open | move | gd 642.3 ms, pack 297.7, call_pass 6.76, apply 103.4 | K 138.7-258.5 (kernel 2.48 ms, spread 0.17) | H 407.84 ms/1800 ticks = 0.881 us/entity = 226.6 us/tick = 63% of gd, 135 B in + 45 B out per entity | E 1.58 | s 75.4% |
| desktop | move_open | both | gd 643.2 ms, pack 299.8, call_pass 9.28, apply 107.7 | K 144.3-270.3 (kernel 2.38 ms, spread 0.14) | H 416.81 ms/1800 ticks = 0.900 us/entity = 231.6 us/tick = 65% of gd, 135 B in + 45 B out per entity | E 1.54 | s 75.6% |

Whole-tick effect of native (desktop): hordes300 p50 1.61 -> 1.33 (-17 %), p95 2.32 -> 2.05 (-12 %), p99 -9 %; move_open p50 0.51 -> 0.37 (-27 %), p95 0.56 -> 0.39 (-30 %). Pass-through (hand-off cost only, GDScript still decides) costs +25 % (hordes300 p50) and +41 % (move_open p50).

#### 2 Kernel alone (Rust, no Godot), "kernel, not the gate"
Command: `native/target/release/wargrid_runner bench WORK/fixtures/<f>.bin 5`, three runs each, release build 1eb8f89 (native/target/release/wargrid_runner built 23:05, source identical to HEAD at that time), log `WORK/logs/t10/kernel.log` (pwd/HEAD in that log reads f3b91ff because the coordinator committed in between; the binary is the one measured above).
| fixture | slice | per call us (3 runs) | notes |
|---|---|---|---|
| horde-hordes300 | horde | 9.25 / 6.56 / 6.55 | first run cold; 2100 ticks x 5 repeats |
| move-open | move | 2.13 / 2.12 / 2.19 | |
| move-dense | move | 2.29 / 2.28 / 2.27 | |
| move-hordes300 | move | 2.38 / 2.28 / 2.20 | |
| t9-hordes300-both | horde / move | 6.67 / 6.66 / 6.70 and 2.17 / 2.22 / 2.23 | |
Cross-check with the in-Godot kernel (call - call_pass, desktop hordes300): horde 13.23 ms / 1800 = 7.35 us per tick, move 2.76 ms / 1800 = 1.5 us per tick. The Rust-only kernel is the same order; the in-engine figure includes the Godot-side buffer calls.

#### 3 Firefox 160, W3 (Dlink template + extension), three interleaved runs per cell (rows hordes300 and move_open; `native=<mode>&slices=horde,move&timing=1&only=<row>`; label: measured)

| W3 Firefox 160 | hordes300 | off | n=3 p50 3.10 (3.10-3.12) p95 4.48 (4.46-4.48) p99 5.26 (5.24-5.30) worst 12.46 (12.40-12.48) |
| W3 Firefox 160 | hordes300 | native | n=3 p50 2.62 (2.62-2.66) p95 4.04 (4.00-4.06) p99 4.86 (4.86-4.90) worst 12.04 (12.02-12.20) |
| W3 Firefox 160 | hordes300 | pass | n=3 p50 3.96 (3.94-3.96) p95 5.28 (5.28-5.30) p99 6.06 (6.04-6.12) worst 13.40 (13.34-13.68) |
| W3 Firefox 160 | move_open | off | n=3 p50 0.98 (0.98-0.98) p95 1.08 (1.08-1.08) p99 1.30 (1.30-1.32) worst 6.22 (5.74-6.66) |
| W3 Firefox 160 | move_open | native | n=3 p50 0.74 (0.74-0.76) p95 0.80 (0.80-0.82) p99 0.94 (0.92-0.98) worst 5.66 (5.64-5.68) |
| W3 Firefox 160 | move_open | pass | n=3 p50 1.42 (1.40-1.42) p95 1.52 (1.50-1.52) p99 1.74 (1.70-1.76) worst 5.76 (5.72-5.78) |

| W3 Firefox 160 | hordes300 | horde | gd 1119.4 ms, pack 689.5, call_pass 12.58, apply 13.4 | K 19.8-51.6 (kernel 21.70 ms, spread 0.82) | H 715.50 ms/1800 ticks = 1.348 us/entity = 397.5 us/tick = 64% of gd, 46 B in + 0 B out per entity | E 1.52 | s 19.9% |
| W3 Firefox 160 | hordes300 | move | gd 1186.5 ms, pack 631.8, call_pass 18.58, apply 177.3 | K 117.0-250.3 (kernel 4.74 ms, spread 1.56) | H 827.76 ms/1800 ticks = 1.869 us/entity = 459.9 us/tick = 70% of gd, 133 B in + 45 B out per entity | E 1.42 | s 21.1% |
| W3 Firefox 160 | hordes300 | both | gd 2305.9 ms, pack 1317.4, call_pass 31.46, apply 190.9 | K 37.8-88.2 (kernel 26.14 ms, spread 2.34) | H 1539.70 ms/1800 ticks = 1.581 us/entity = 855.4 us/tick = 67% of gd, 86 B in + 21 B out per entity | E 1.46 | s 40.9% |
| W3 Firefox 160 | move_open | move | gd 1253.0 ms, pack 635.3, call_pass 18.38, apply 196.7 | K 153.7-311.7 (kernel 4.02 ms, spread 2.00) | H 850.42 ms/1800 ticks = 1.837 us/entity = 472.5 us/tick = 68% of gd, 135 B in + 45 B out per entity | E 1.46 | s 76.3% |
| W3 Firefox 160 | move_open | both | gd 1254.7 ms, pack 639.6, call_pass 26.40, apply 204.2 | K 154.5-315.2 (kernel 3.98 ms, spread 1.90) | H 870.14 ms/1800 ticks = 1.879 us/entity = 483.4 us/tick = 69% of gd, 135 B in + 45 B out per entity | E 1.43 | s 76.4% |

Whole-tick effect of native in Firefox: hordes300 p50 3.10 -> 2.62 (-15 %), p95 4.48 -> 4.04 (-10 %), p99 5.26 -> 4.86 (-8 %); move_open p50 0.98 -> 0.74 (-24 %), p95 1.08 -> 0.80 (-26 %). Pass-through +28 % / +45 % (p50). Packing is 60-70 % of the GDScript slice time in every browser and on desktop: the hand-off is the cost, the kernel is negligible (K 18-43 horde, 114-259 move).

#### 4 Safari 27.2 (label: measured, ONE run per mode, no A/A spread; cold start each) (one run per mode, no A/A spread)

| W3 safari | hordes300 | off | n=1 p50 2.78 (2.78-2.78) p95 4.02 (4.02-4.02) p99 4.72 (4.72-4.72) worst 11.22 (11.22-11.22) |
| W3 safari | hordes300 | native | n=1 p50 2.32 (2.32-2.32) p95 3.58 (3.58-3.58) p99 4.34 (4.34-4.34) worst 10.66 (10.66-10.66) |
| W3 safari | hordes300 | pass | n=1 p50 3.52 (3.52-3.52) p95 4.74 (4.74-4.74) p99 5.46 (5.46-5.46) worst 11.88 (11.88-11.88) |
| W3 safari | move_open | off | n=1 p50 0.90 (0.90-0.90) p95 0.98 (0.98-0.98) p99 1.20 (1.20-1.20) worst 5.16 (5.16-5.16) |
| W3 safari | move_open | native | n=1 p50 0.66 (0.66-0.66) p95 0.68 (0.68-0.68) p99 0.74 (0.74-0.74) worst 5.20 (5.20-5.20) |
| W3 safari | move_open | pass | n=1 p50 1.28 (1.28-1.28) p95 1.34 (1.34-1.34) p99 1.58 (1.58-1.58) worst 5.26 (5.26-5.26) |

| W3 safari | hordes300 | horde | gd 986.4 ms, pack 592.8, call_pass 11.56, apply 11.5 | K 22.6-56.7 (kernel 17.40 ms, spread 0.00) | H 615.82 ms/1800 ticks = 1.160 us/entity = 342.1 us/tick = 62% of gd, 46 B in + 0 B out per entity | E 1.56 | s 19.5% |
| W3 safari | hordes300 | move | gd 1079.0 ms, pack 548.9, call_pass 16.32, apply 157.1 | K 177.9-362.1 (kernel 2.98 ms, spread 0.00) | H 722.34 ms/1800 ticks = 1.631 us/entity = 401.3 us/tick = 67% of gd, 133 B in + 45 B out per entity | E 1.49 | s 21.4% |
| W3 safari | hordes300 | both | gd 2065.4 ms, pack 1141.7, call_pass 27.88, apply 168.6 | K 45.3-101.3 (kernel 20.38 ms, spread 0.00) | H 1338.16 ms/1800 ticks = 1.374 us/entity = 743.4 us/tick = 65% of gd, 86 B in + 21 B out per entity | E 1.53 | s 40.9% |
| W3 safari | move_open | move | gd 1149.0 ms, pack 547.9, call_pass 14.60, apply 175.4 | K 150.3-287.2 (kernel 4.00 ms, spread 0.00) | H 737.90 ms/1800 ticks = 1.594 us/entity = 409.9 us/tick = 64% of gd, 135 B in + 45 B out per entity | E 1.56 | s 76.9% |
| W3 safari | move_open | both | gd 1150.1 ms, pack 551.2, call_pass 20.94, apply 181.5 | K 152.8-293.4 (kernel 3.92 ms, spread 0.00) | H 753.62 ms/1800 ticks = 1.628 us/entity = 418.7 us/tick = 66% of gd, 135 B in + 45 B out per entity | E 1.52 | s 77.0% |

#### 5 Vivaldi (label: measured, ONE run per mode, no A/A spread) (one run per mode, no A/A spread)

| W3 vivaldi | hordes300 | off | n=1 p50 3.04 (3.04-3.04) p95 4.40 (4.40-4.40) p99 5.15 (5.15-5.15) worst 12.04 (12.04-12.04) |
| W3 vivaldi | hordes300 | native | n=1 p50 2.54 (2.54-2.54) p95 3.91 (3.91-3.91) p99 4.74 (4.74-4.74) worst 11.63 (11.63-11.63) |
| W3 vivaldi | hordes300 | pass | n=1 p50 3.82 (3.82-3.82) p95 5.16 (5.16-5.16) p99 5.93 (5.93-5.93) worst 12.89 (12.89-12.89) |
| W3 vivaldi | move_open | off | n=1 p50 0.96 (0.96-0.96) p95 1.04 (1.04-1.04) p99 1.26 (1.26-1.26) worst 5.42 (5.42-5.42) |
| W3 vivaldi | move_open | native | n=1 p50 0.71 (0.71-0.71) p95 0.74 (0.74-0.74) p99 0.79 (0.79-0.79) worst 5.46 (5.46-5.46) |
| W3 vivaldi | move_open | pass | n=1 p50 1.34 (1.34-1.34) p95 1.42 (1.42-1.42) p99 1.66 (1.66-1.66) worst 5.56 (5.56-5.56) |

| W3 vivaldi | hordes300 | horde | gd 1082.0 ms, pack 645.2, call_pass 12.52, apply 12.7 | K 19.1-47.2 (kernel 22.90 ms, spread 0.00) | H 670.43 ms/1800 ticks = 1.263 us/entity = 372.5 us/tick = 62% of gd, 46 B in + 0 B out per entity | E 1.54 | s 19.5% |
| W3 vivaldi | hordes300 | move | gd 1142.0 ms, pack 569.6, call_pass 18.23, apply 174.1 | K 153.2-305.7 (kernel 3.73 ms, spread 0.00) | H 761.94 ms/1800 ticks = 1.720 us/entity = 423.3 us/tick = 67% of gd, 133 B in + 45 B out per entity | E 1.49 | s 20.6% |
| W3 vivaldi | hordes300 | both | gd 2224.0 ms, pack 1214.8, call_pass 30.75, apply 186.8 | K 37.9-83.5 (kernel 26.64 ms, spread 0.00) | H 1432.37 ms/1800 ticks = 1.471 us/entity = 795.8 us/tick = 64% of gd, 86 B in + 21 B out per entity | E 1.51 | s 40.1% |
| W3 vivaldi | move_open | move | gd 1204.7 ms, pack 563.5, call_pass 17.63, apply 194.4 | K 207.5-389.9 (kernel 3.09 ms, spread 0.00) | H 775.54 ms/1800 ticks = 1.675 us/entity = 430.9 us/tick = 64% of gd, 135 B in + 45 B out per entity | E 1.53 | s 75.9% |
| W3 vivaldi | move_open | both | gd 1206.5 ms, pack 567.4, call_pass 25.82, apply 201.6 | K 213.8-403.5 (kernel 2.99 ms, spread 0.00) | H 794.81 ms/1800 ticks = 1.717 us/entity = 441.6 us/tick = 66% of gd, 135 B in + 45 B out per entity | E 1.49 | s 76.0% |

#### 6 Emscripten 4.0.20 build of the extension (W3-4.0.20 export, Firefox, native, one run, label: measured)

| W3-4.0.20 Firefox | hordes300 | native | n=1 p50 2.62 (2.62-2.62) p95 4.00 (4.00-4.00) p99 4.88 (4.88-4.88) worst 11.98 (11.98-11.98) | horde call 34.1 pack 691.2 apply 13.4 ; move call 23.7 pack 634.3 apply 177.5 |
| W3-4.0.20 Firefox | move_open | native | n=1 p50 0.74 (0.74-0.74) p95 0.80 (0.80-0.80) p99 0.98 (0.98-0.98) worst 5.72 (5.72-5.72) | horde call 7.9 pack 3.6 apply 7.1 ; move call 22.4 pack 631.7 apply 195.3 |
Same whole tick as the 3.1.74 build (hordes300 native p50 2.62 vs 2.62, p95 4.00 vs 4.04): the Emscripten version does not move the result. Extension loads and runs (BENCH DONE).

#### 7 Template tax T on the Mac (Firefox, native=off, three interleaved runs each; W1 = Web Bench single template, W2 = Dlink template no extension, W3 = Dlink plus extension loaded but unused; label: measured)

| W1 | hordes300 | n=3 p50 2.82 (2.80-2.82) p95 4.10 (4.08-4.12) p99 4.82 (4.80-4.84) worst 10.94 (10.86-11.16) |
| W2 | hordes300 | n=3 p50 3.10 (3.10-3.10) p95 4.46 (4.46-4.48) p99 5.28 (5.24-5.30) worst 12.50 (12.42-12.50) |
| W3 | hordes300 | n=3 p50 3.10 (3.10-3.12) p95 4.50 (4.46-4.50) p99 5.28 (5.26-5.28) worst 12.46 (12.44-12.50) |
| T = W2/W1 - 1 | hordes300 | p50 +9.9% p95 +8.8% p99 +9.5% |
| T = W3/W1 - 1 | hordes300 | p50 +9.9% p95 +9.8% p99 +9.5% |
| T = W3/W2 - 1 | hordes300 | p50 +0.0% p95 +0.9% p99 +0.0% |
| W1 | move_open | n=3 p50 0.92 (0.92-0.96) p95 1.06 (1.04-1.10) p99 1.24 (1.22-1.30) worst 5.16 (5.14-5.30) |
| W2 | move_open | n=3 p50 0.98 (0.98-1.00) p95 1.08 (1.08-1.08) p99 1.32 (1.32-1.34) worst 6.36 (6.00-6.76) |
| W3 | move_open | n=3 p50 0.98 (0.98-0.98) p95 1.08 (1.08-1.08) p99 1.32 (1.32-1.32) worst 5.66 (5.64-6.44) |
| T = W2/W1 - 1 | move_open | p50 +6.5% p95 +1.9% p99 +6.5% |
| T = W3/W1 - 1 | move_open | p50 +6.5% p95 +1.9% p99 +6.5% |
| T = W3/W2 - 1 | move_open | p50 +0.0% p95 +0.0% p99 +0.0% |
W3 (extension loaded, unused) adds nothing over W2 (0.0 to +0.9 %); the whole tax is the dynamic-linking template (W2/W1): about +10 % hordes300, +6.5 % p50 / +1.9 % p95 move_open (move_open p95 is 1.06 vs 1.08 ms, inside the ~0.04 ms spread: read it as +2-7 %). Export size: W1 51,804 KB class vs W3 60.7 MB (see T7 rows), first BENCH t_ms about 0.68 s in all three.

#### 8 probe=1 (W3, Firefox, three runs; label: measured)

run 1: PROBE version wargrid_native 0.1.0 | PROBE echo ok=true n=1024 | PROBE keys match=true | PROBE snapshot gd_ms=678.160 dicts_ms=3239.500 packed_ms=9.200 n=400 repeats=300 sink=243000 | PROBE grow held_ok=true fresh_ok=true checksum=8355840 heap_before=260440064 heap_after=322043904
run 2: PROBE version wargrid_native 0.1.0 | PROBE echo ok=true n=1024 | PROBE keys match=true | PROBE snapshot gd_ms=673.060 dicts_ms=3153.240 packed_ms=9.480 n=400 repeats=300 sink=243000 | PROBE grow held_ok=true fresh_ok=true checksum=8355840 heap_before=260440064 heap_after=322043904
run 3: PROBE version wargrid_native 0.1.0 | PROBE echo ok=true n=1024 | PROBE keys match=true | PROBE snapshot gd_ms=671.660 dicts_ms=3183.920 packed_ms=9.260 n=400 repeats=300 sink=243000 | PROBE grow held_ok=true fresh_ok=true checksum=8355840 heap_before=260440064 heap_after=322043904
Snapshot probe: whole snapshot today 672-678 ms, native -> Array[Dictionary] 3,154-3,240 ms (4.7-4.8x slower than today), native -> packed columns 9.2-9.5 ms (73x faster), n=400 entities x 300 repeats. Memory growth holds (heap 260,440,064 -> 322,043,904 B).


| R1 | ashfall | tick p50 9.38 (9.36-9.40) p95 10.66 (10.52-10.74) | frame_interval p50 12.24 (11.90-13.46) p95 28.42 (28.40-28.54) p99 29.44 (29.32-29.56) |
| R1 | horde | tick p50 10.20 (10.08-10.42) p95 11.52 (11.34-11.60) | frame_interval p50 10.54 (10.28-10.56) p95 28.76 (28.56-28.82) p99 29.58 (29.58-29.64) |
| R2 | ashfall | tick p50 9.50 (9.44-9.72) p95 10.56 (10.44-10.64) | frame_interval p50 13.58 (11.84-16.66) p95 28.30 (28.18-28.68) p99 29.34 (29.28-29.64) |
| R2 | horde | tick p50 10.22 (10.16-10.52) p95 11.38 (11.34-11.70) | frame_interval p50 9.78 (9.64-10.40) p95 28.60 (28.50-28.94) p99 29.54 (29.30-29.70) |
| R2/R1 - 1 | horde | tick p50 +0.2% |
| R2/R1 - 1 | ashfall | tick p50 +1.3% |

#### 9 R1 vs R2 rendered benchmark (Firefox 160, three interleaved runs; same defaults zoom=0.5 quality=high interpolation=off, layouts horde+ashfall, 300 units, 60 s sample, vsync=browser; report-only; label: measured)
| R1 | ashfall | tick p50 9.38 (9.36-9.40) p95 10.66 (10.52-10.74) | frame_interval p50 12.24 (11.90-13.46) p95 28.42 (28.40-28.54) p99 29.44 (29.32-29.56) |
| R1 | horde | tick p50 10.20 (10.08-10.42) p95 11.52 (11.34-11.60) | frame_interval p50 10.54 (10.28-10.56) p95 28.76 (28.56-28.82) p99 29.58 (29.58-29.64) |
| R2 | ashfall | tick p50 9.50 (9.44-9.72) p95 10.56 (10.44-10.64) | frame_interval p50 13.58 (11.84-16.66) p95 28.30 (28.18-28.68) p99 29.34 (29.28-29.64) |
| R2 | horde | tick p50 10.22 (10.16-10.52) p95 11.38 (11.34-11.70) | frame_interval p50 9.78 (9.64-10.40) p95 28.60 (28.50-28.94) p99 29.54 (29.30-29.70) |
| R2/R1 - 1 | horde | tick p50 +0.2% |
| R2/R1 - 1 | ashfall | tick p50 +1.3% |

R2 (Dlink template) is within the spread of R1 on tick p50/p95 and frame interval p95/p99; no rendered penalty visible beyond noise. Frame interval p95 about 28.5 ms is the browser's vsync cadence in both.

#### 10 Build times (build.sh, warm rustup and registry caches, Apple M6; label: measured, one run each)
Driver `WORK/logs/t10/builds.sh`, output `builds.log`, cargo detail `build-detail.log`.
| build | wall |
|---|---|
| `build.sh mac` clean (`rm -rf native/target/release`, whole workspace) | 7 s |
| `build.sh mac` incremental (touch core/src/lib.rs) | under 1 s (0 s by whole-second clock; cargo "Finished" 0.55 s) |
| `build.sh web` clean (`rm -rf native/target/wasm32-unknown-emscripten`; rebuilds core, std through -Zbuild-std, godot-rust; emcc 3.1.74) | 13 s |
| `build.sh web` incremental (touch core/src/lib.rs) | 1 s |
Other pipeline costs seen: `build.sh place` plus 5 `export_tree.sh` exports plus one macOS export plus one web build with 4.0.20 took about 1.5 min in total (`exports.log`); the "Known trap" first-import crash did not occur (both imports exit 0, `.godot` cache existed).

#### 11 What was not done or is weak
- Safari, Vivaldi and the 4.0.20 build: one run each, so no A/A spread; K there is a single-run figure.
- `only=` takes one row, so the template tax uses hordes300 and move_open (each a separate interleaved set) rather than one list; other rows were not measured on the Mac.
- Desktop rows use the exported release app, not the editor build.
- Load average ~1.3-2.3 throughout though no heavy process ran (see header).
- Kernel-alone numbers are on the Mac only; Deck kernel is T11.

### T11 rows (Deck measurements), 2026-11-10 23:05-23:35 CET

Host: Steam Deck (address in WORK/deck-address.txt), Firefox 159.0 (Linux x86_64, from the logged UA line), mains power (`acad=1` at every START), 1-min load average at START/END 0.2-2.2 (Firefox itself; no other process; per-run values in `WORK/results/<label>/run.txt`). Fresh Firefox profile per run (deck.sh). Mac not used for timing. Run order per repeat i=1..3, per row (hordes300, then move_open): `off`, `native`, `pass`, `w3off`, `w1` (interleaved A B C D E, three repeats). 33 runs, all exit 0 (30 timed + 3 probes). Loop log `WORK/logs/t11-loop.log`; per-run stdout `WORK/logs/t11-<label>.out`; raw logs `WORK/results/t11-<cfg>-<row>-<i>/web-*.log`; analysis script output `WORK/logs/t11-analysis.txt` (script: scratchpad `t11an.py`, medians of three, spread = (max-min)/median).
Builds: W3 = `WORK/exports/wargrid-wt-native-e2693e7/W3` (T9 tree: HEAD e2693e7 plus the uncommitted T9 fixes; extension loaded; same binary for off/native/pass and w3off). W1 = `WORK/exports/wargrid-wt-native-1eb8f89/W1` (exported by T11 from the current working tree, no extension). Commands: `sh native/tools/web_run.sh deck firefox <export> '<query>' <label> 900`, queries `native=<off|native|pass>&slices=horde,move&timing=1&only=<row>`, plain `only=<row>` for w3off and w1. The runner takes ONE row per `only=` (a comma list fails with `unknown row`, log `WORK/results/t11-digest` is that failed attempt), so every cell is two runs.

Tool fix (repo, uncommitted): `native/tools/deck.sh` `run` passed the query through ssh unquoted, so a query with `&` was cut by the remote shell (`900: command not found`, NO RESULT). The query is now single-quoted (`"'$2'"`). T8 never hit it (its queries had no `&`). `sh -n` ok; python checks not applicable.

#### Stage 5 row 4, Deck half
`native=native&slices=horde,move` on `hordes300` and `move_open`: DIGEST lines equal the Mac's. All 15 runs of hordes300 (off, native, pass, w3off, w1) share one digest set, final `tick=2100 816e76bc1461ee53` (equals Mac desktop pureoff and native); all 15 of move_open share one set, final `tick=2100 d70092821feca211`. `SLICE ... mismatch=none` in native runs. Result: PASS. (Mac `move_open` digests were checked by T9 and are the same file set; I did not diff the Deck's move_open lines line by line against the Mac log, only across Deck runs.)

#### Whole-tick time, ms, medians of three (individual runs in analysis file), spread = A/A
| row | cfg | p50 | p95 | p99 |
|---|---|---|---|---|
| hordes300 | off (W3, ext loaded unused, timing=1) | 11.52 (3.3 %) | 16.16 (1.7 %) | 19.18 (2.7 %) |
| hordes300 | native both slices | 9.92 (1.6 %) | 14.42 (3.1 %) | 17.28 (2.0 %) |
| hordes300 | pass | 14.06 (2.4 %) | 18.80 (2.3 %) | 21.54 (4.2 %) |
| hordes300 | w3off (no timing) | 11.38 (0.5 %) | 15.84 (0.6 %) | 18.80 (3.9 %) |
| hordes300 | W1 | 11.10 (1.1 %) | 15.04 (0.5 %) | 18.00 (2.1 %) |
| move_open | off | 3.56 (1.7 %) | 4.46 (4.5 %) | 5.54 (7.9 %) |
| move_open | native both | 2.84 (1.4 %) | 3.76 (4.8 %) | 4.56 (1.8 %) |
| move_open | pass | 5.04 (2.4 %) | 6.70 (2.4 %) | 7.58 (6.3 %) |
| move_open | w3off | 3.50 (0.6 %) | 4.46 (3.1 %) | 5.42 (1.1 %) |
| move_open | W1 | 3.34 (1.2 %) | 4.04 (2.0 %) | 5.30 (3.0 %) |

Measured whole-tick effect, both slices native vs `off` (same binary, same timing=1): hordes300 p50 x0.861 (-13.9 %), p95 x0.892 (-10.8 %), p99 -9.9 %; move_open p50 x0.798, p95 x0.843. Pass-through (hand-off only, GDScript decides) makes the tick slower: hordes300 p95 x1.163, move_open p95 x1.502. Hordes300 p95 under native 14.42 ms vs the 10 ms budget: still 1.44, Q-relevant: native alone does not bring the worst row under budget on the Deck.

#### T (extension loaded but unused, `w3off` vs `W1`, no timing in either)
| row | T p50 | T p95 | A/A W1 p50 / p95 | A/A W3 p50 / p95 |
|---|---|---|---|---|
| hordes300 | +2.5 % | +5.3 % | 1.1 / 0.5 % | 0.5 / 0.6 % |
| move_open | +4.8 % | +10.4 % | 1.2 / 2.0 % | 0.6 / 3.1 % |
T4 note: T8 measured the dlink template alone (W2 vs W1) at +6.9 / +6.0 % (hordes300) and +5.5 / +7.2 % (move_open); loading the extension on top adds nothing outside the spread (W3off hordes300 is within T8's W2 band, move_open p95 +10.4 % has a 3.1 % spread). W1 here: hordes300 p95 15.04 vs T8's 14.64 (+2.7 %, Deck run-to-run drift between sessions; ratios use only same-session runs).

#### K (range), H, E, s per slice, Deck Firefox, sums over the 1800 sampled ticks (ms), medians of three
Definitions as in the plan Conventions (kernel = native `call` - pass `call_pass`; K upper = gd/kernel, K lower = (gd - pack)/kernel; H = pass `pack` + pass `call_pass` + native `apply`; E = gd/(pack+call+apply) all from the native run; s = slice gd / off `tick_sum`).
| row | slice | gd | pack | call_pass | call (native) | kernel | K | H (ms, % of gd, per entity) | E | s | spread gd / call |
|---|---|---|---|---|---|---|---|---|---|---|---|
| hordes300 | horde | 3883.4 | 2335.0 | 84.2 | 140.1 | 55.9 | 27.7 .. 69.5 | 2470.8, 64 %, 4.66 us (46 B in, 0.47 B out) | 1.543 | 0.189 | 0.4 / 2.4 % |
| hordes300 | move | 4206.7 | 2293.8 | 120.9 | 142.7 | 21.8 | 87.8 .. 193.1 | 3084.7, 73 %, 6.96 us (133 B in, 45 B out) | 1.347 | 0.204 | 4.1 / 0.6 % |
| move_open | move | 4528.2 | 2340.0 | 124.7 | 149.8 | 25.1 | 87.1 .. 180.3 | 3263.2, 72 %, 7.05 us | 1.355 | 0.731 | 2.1 / 4.7 % |
| move_open | horde | - | - | - | - | - | - | slice saw 0 entities there (allowed: `horde` must see entities only on hordes300); numbers meaningless, kernel inside noise: "K at least" not reportable | - | 0.002 | - |
Reading: the kernel is tiny (20-60 ms of ~4 s) so K is large, but the hand-off (packing, 2.3 s per slice in Firefox WASM) eats 64-73 % of the GDScript slice time, leaving E only 1.35-1.54 per slice. Both slices together on hordes300: gd 8090 ms of tick_sum 20377 ms (s_total 0.40); the whole tick shrinks only -11 % p95. Kernel spread: call spread 0.6-4.7 %, kernel is well above it for all three valid cells.
Bytes per entity (hordes300 horde): in 24,427,474 B / 530,719 = 46.0 B, out 247,646 B = 0.47 B; move: in 133.3 B, out 45.0 B per entity.

#### Probe (snapshot hand-off on the gate device), `probe=1&only=contact`, three runs
Raw: `WORK/results/t11-probe-{1,2,3}/`. All `PROBE echo ok=true n=1024`, `keys match=true`, `grow held_ok=true fresh_ok=true`, heap 260,505,600 -> 320,012,288 B. Snapshot hand-off, 400 entities x 300 repeats summed (ms):
| run | snapshot() | native dicts | packed |
|---|---|---|---|
| 1 | 2376.1 | 9766.9 | 56.6 |
| 2 | 2353.2 | 9871.7 | 55.5 |
| 3 | 2374.5 | 9497.3 | 57.7 |
Per-call: snapshot() 7.9 ms, dicts 32 ms, packed 0.19 ms per 400 entities. Deck/Mac (T7, single Firefox run: snapshot 665, dicts 3151, packed 9.8) = about 3.6 / 3.1 / 5.8 slower on the Deck, i.e. packed arrays are the only hand-off that stays cheap; building dictionaries for a native call is about 4x the whole snapshot(). The T7 Deck W3 functional probe (Stage 2 gate) is hereby done on the gate device with the T9 W3 build (the older t7-96000ae export was not used): Firefox 159 Deck, all probe lines ok.

#### Deck replay (T9 open item)
Copied `WORK/build/wargrid-wt-native/linux/target/release/wargrid_runner` (Linux x86-64, built in the rust:1.94 container) and the fixtures to `~/wargrid-native/t11-replay` on the Deck (x86_64): `./wargrid_runner replay t9-hordes300-both.bin` -> `REPLAY OK ticks=2100 records=4200`; `horde-hordes300.bin` -> `REPLAY OK ticks=2100 records=2100`. Log `WORK/logs/t11-deck-replay.log`. Folder removed afterwards (`rm -rf`; `~/wargrid-native` holds only `serve_web_bench.py` from the pushes). Native Rust equals GDScript bit for bit on the Deck. Windows still unverified.

#### Not done / caveats
- `deck.sh clean` for the whole run: each web_run cleaned its own label; no extra clean needed. Left on the Deck: `~/wargrid-native/serve_web_bench.py` (pushed by deck.sh each run).
- Three runs per cell, interleaved per row; the order across the two rows is hordes300 block then move_open block inside each repeat.
- No power/sleep problem observed (no NO RESULT). Whole-tick percentages from the runner's own `tick_ms` (p50/p95/p99 over 1800 ticks). G_inc, G_port and the verdict are T12's job.

### T12 rows (decision-rule arithmetic), 2026-11-10

Tree ~/projects/wargrid-wt-native (`spike-native-sim` ed9d868, report written uncommitted). No new measurement: every number below is arithmetic on the T8, T10, T11 rows (label inferred unless marked). Script: inline `python3 -I` in the T12 session, inputs typed from the rows and `WORK/logs/t11-analysis.txt`.

#### Inputs (measured, copied)
- Deck Firefox hordes300, sums over 1800 ticks (ms), T11 medians: horde gd 3883.4, pass pack 2335.0, call_pass 84.2, native call 140.1, apply 51.6, native pack 2325.1, entities 530,719; move gd 4206.7, pass pack 2293.8, call_pass 120.9, native call 142.7, apply 670.0, native pack 2309.4, entities 442,998; off tick_sum 20,377 (mean tick 11.32 ms).
- T: T8 W2/W1 - 1 hordes300 p50 +6.9 %, p95 +6.0 %; T11 W3off/W1 - 1 +2.5 % / +5.3 %. Q: T8 W1 hordes300 p95 14.64 ms (T11 W1 15.04).
- Snapshot probe, Deck Firefox, 400 entities x 300 (T11 runs 1-3): snapshot() 2376.1 / 2353.2 / 2374.5, dicts 9766.9 / 9871.7 / 9497.3, packed 56.6 / 55.5 / 57.7 ms; per call (mean of 3) 7.89, 32.37, 0.189 ms.
- Mac Firefox (T10, not the gate): both slices gd 2305.9, kernel 26.14, K 37.8-88.2, E 1.46, s 0.409; horde K lower 19.8; T W2/W1 +9.9 % p50, +8.8 % p95; snapshot 672-678, dicts 3154-3240, packed 9.2-9.5 ms per 300.

#### Derived (inferred)
| Quantity | Formula | Deck Firefox | Mac Firefox |
|---|---|---|---|
| both kernel | sum call - sum call_pass | 282.8 - 205.1 = 77.7 ms | 26.14 (T10) |
| K both | upper gd/kernel; lower (gd - pass pack)/kernel | 8090.1/77.7 = 104.1; (8090.1-4628.8)/77.7 = 44.5 | 88.2 / 37.8 (T10) |
| H both | pass pack + call_pass + apply | 4628.8 + 205.1 + 721.6 = 5555.5 ms = 3.09 ms/tick = 69 % of gd = 5.71 us per entity (973,717) | 1539.7 ms, 67 % (T10) |
| E both | gd / (native pack + call + apply) | 8090.1 / 5639.0 = 1.435 | 1.46 (T10) |
| s both | gd / tick_sum | 8090.1 / 20377 = 0.397 | 0.409 |
| need | Q x 1.5 | 1.464 x 1.5 = 2.20 (T11 W1: 2.26) | - |
| G_inc both | 1/((1+T)(1-s)+s/E), T 0.060 | 1/(0.6392+0.2767) = 1.09; ceiling 1/0.6392 = 1.56 | T 0.088: 1.08, ceiling 1.56 |
| G_inc horde / move alone | same, T 0.060 | 1.02 / 1.01 | - |
| G_inc at s 0.559 | same, E 1.435 | 1.17; ceiling 2.14 (T 0: 2.27) | - |
| floor per slice | s(1-1/E) vs T(1-s), T 0.060 | horde 0.067 > 0.049; move 0.053 > 0.048; both 0.119 > 0.036; at T 0.069 move 0.053 < 0.055 | - |
| p, dict full / extra | dicts/tick; (dicts - snapshot)/tick | 32.37/11.32 = 2.86; 24.48/11.32 = 2.16 | tick 3.13 ms: 3.40 / 2.68 |
| p, packed full / extra | packed/tick; (packed - snapshot)/tick | 0.0167; negative, taken as 0 | 0.0099; 0 |
| G_port = 1/(1/K + p) | K 27.7 (horde lower) / 44.5 (both lower) / 104.1 (both upper) | packed full 18.9 / 25.6 / 38.1; packed extra = K; dict full 0.35; dict extra 0.45-0.46 | K 19.8 / 37.8: packed full 16.6 / 27.5; dict full 0.29; dict extra 0.37 |
| sensitivity: packed + GDScript read side at per-entity H | p = (0.189 + 400 x H_entity)/11.32 | H 4.66 us: p 0.181, G_port 4.6; H 6.96 us: p 0.263, G_port 3.3 (K 27.7) | - |
| break-even p for G_port = 2.20 at K 27.7 | 1/2.20 - 1/27.7 | 0.42 (4.7 ms per tick) | - |
| measured whole tick, both native | p95 ratios | W1 15.04 / native 14.42 = 1.04; off 16.16 / 14.42 = 1.12; 14.42/10 = 1.44 of budget | 4.48 / 4.04 = 1.11 (off/native) |

#### Outcome derivation
Gate passed (T11). Stage 5 green except Windows (T9, T11). G_inc 1.09 < 2.20 and its best ceiling 2.14 < 2.20: hot loops fail. G_port with packed hand-off 18.9-104 > 2.20: only G_port reaches it -> CONDITIONAL GO, next step golden scenarios; §4.2 b missing.

#### Outputs
- docs/reference/native-sim-spike.md (new).
- docs/reference/native-sim-spike-verification.md: T8, T10, T11 and these T12 rows appended verbatim, headings demoted.
- docs/reference/performance.md: one History row (Deck Firefox runs of T8 and T11, ledger protocol: web export, isolated server on the Deck, Firefox via systemd-run, mains power, 3 interleaved runs).

### T14 rows (gate-review fixes and lean review), 2026-11-10

Tree ~/projects/wargrid-wt-native, `spike-native-sim` a517e5b plus uncommitted doc edits. No new measurement. Arithmetic: inline `python3 -I` on the T11 and T12 rows (label inferred). Raw per-run call sums re-read from `WORK/results/t11-{native,pass}-hordes300-{1,2,3}/web-*.log`.

#### Rulings on the T13 findings (`WORK/rows/t13.md`)
| # | Severity | Ruling | Where |
|---|---|---|---|
| 1 | important | Fixed. Headline G_port is now 3.3-4.6 (estimate): p = (0.189 ms + 400 × 4.66-6.96 µs) / 11.32 ms = 0.181-0.263, K 27.7 → 4.61 / 3.35 (K 44.5 → 4.91 / 3.51). Downside: read side at today's `snapshot()` per entity (7.89 ms / 400 = 19.7 µs) gives p 0.713, G_port 1.34. The p definition is written under the table. The p-clamped-to-0 column is labelled as holding only if the read side costs no more than today's snapshot. Correction to the review: the packed probe covers 9 of the 16 real keys and omits **7**, not 6 (`order`, `combat`, `destination`, `heading`, `max_hp`, `construction_id`, `collection`; `PROBE keys real=` in `WORK/results/t11-probe-1/web-20261110-233206.log`, `probe.rs` `snapshot_packed`). | report §1 outcome, table, reading bullets, performance case, §3, §4 probe |
| 2 | important | Fixed. Restated as the (s, E) pair that solves 1/((1+T)(1-s)+s/E) = 2.20. At T 0: s 0.56 needs E ≥ 41, s 0.70 needs E ≥ 4.5, s 0.80 needs E ≥ 3.1. At T 0.060: s 0.56 impossible, 0.70 needs 5.1, 0.80 needs 3.3. Correction to the review: E ≈ 3.1 goes with s ≈ 0.80, not 0.75 (s 0.75 needs 3.7). | report §1 "Evidence that would change this" |
| 3 | important | Fixed. One joint pass condition 1/K_lower + p ≤ 0.455 (0.442 for 2.26) for open items 2 and 3. Check: K 4 with p 0.42 gives 1.49 (fails); at p 0.263, K ≥ 5.22. Items 5 and 6 now have pass values. | report §1 open items, reading bullets, §6 item 3 |
| 4 | important | Fixed. Blockers now lead with the measured T8 overrun: dlink template alone moves `combat_open` p95 9.76 → 10.34 ms (EXCEEDED) and `combat_dense` 9.24 → 9.88. Same sentence added to the ledger row and to the matrix's maintenance cell. | report §1 Blockers, §3; `performance.md` spike row |
| 5 | minor | Fixed. Per-run kernels (call - call_pass, paired by run): horde 61.26 / 55.90 / 54.58 ms (12 %), move 21.78 / 23.64 / 19.78 ms (17 %), confirming the review. Horde lower K 25.3-28.4, move 81-97, now in the table. Using the horde lower K 25.3 leaves G_port at 3.3-4.5, so the headline is unchanged. | report §1 table |
| 6 | minor | Fixed. Q × 1.5 is shown as 2.20-2.26. G_inc is shown at both taxes: 1.09 at p95 (T 0.060), 1.08 at p50 (T 0.069). | report §1 outcome, table |
| 7 | minor | Fixed. `test_map.gd` is now "caused by this branch (T3, 1d43859), fixed in T9". Linux compatibility is now "core and runner only; Godot loading the `.so` unverified". Baseline determinism is now "source". Single-slice and "both" K/H/E now have the same label, "inferred from measured sums". | report §1 table, §3, §8 |
| 8 | minor | Fixed as an open item, since it needs a measurement. G_port is capped at 1 / (share of already-compiled work: `AStarGrid2D` path search, built-ins). That share on hordes300 is **unverified**, because the profile has no zone for it. A share above about 45 % puts the cap below 2.20. It is listed under "Evidence that would change this" and is to be measured with open item 2. | report §1 reading bullets, open items, evidence bullets |

The outcome is unchanged: CONDITIONAL GO, whole-port branch only. The margin is now about 1.5-2× (G_port 3.3-4.6 against 2.20-2.26), not 8×.

Not covered (T13's "not checked", outside this brief): shadow field lists against the GDScript code, and the production change that would make each new test fail.

#### Lean review (ponytail-review style, over-engineering only), `git diff main...spike-native-sim`, 49 files
- Shared files (`simulation.gd`: 2 hooks plus 1 static; `run_tests.gd`, `test_map.gd`, `.gitignore`, `serve_web_bench.py` `--no-isolation`; two appended presets): minimal. No cut.
- `native_bridge.gd`, `native_horde.gd`, `native_move.gd`, `bench_runner.gd` additions, `native/tools/*.sh`: each piece is required by the plan's Conventions (modes, timers, options, row ids, fixture format, run scripts). No speculative option or abstraction found. No cut.
- Rust: `wargrid_core` has no dependencies. The `Buffer` enum with the `Slice` trait is the runner's one generic path, and the features are plan-mandated. Two small findings, **not applied**:
  - (a) `native/godot/src/horde.rs` `pass()` repeats `run_generic` (about 8 lines). Making `run_generic` take a closure would remove it.
  - (b) `native/core/src/fixture.rs` `write` is `pub` but only tests use it; it could be `#[cfg(test)]`.

  Reason: both are behaviour-neutral, live in spike code that will not survive (handoff, "Moving ground"), and sit in the adapter whose measured binaries (W3 from e2693e7 plus the T9 fixes) the evidence rows cite. A post-measurement edit adds a rebuild and a re-placed native run for no gain.
- Verdict: no over-engineering worth a cut. The only edits are docs.

#### Checks (tree a517e5b plus these doc edits; logs `WORK/logs/t14/`)
- `cargo test --workspace`: exit 0, 24 passed.
- `cargo +stable clippy --workspace -- -D warnings`: exit 0.
- `sh tools/run_lint.sh`: exit 0, "no problems found".
- `sh tools/run_warnings.sh`: exit 0, 144 files checked.
- `run_python_checks.sh` (main's venv): exit 0, PYTHON TESTS PASSED.
- Suite not re-run: no GDScript changed since T9's green suite.
- Links: no link added. Edited anchors and paths were checked by hand.

#### Changed paths (uncommitted)
- docs/reference/native-sim-spike.md
- docs/reference/native-sim-spike-verification.md (these rows appended)
- docs/reference/performance.md (spike row: combat open overrun)
