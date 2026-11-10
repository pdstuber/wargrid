# Native simulation core spike: verification

Resume record and dated evidence for [the handoff](../native-sim-spike-prompt.txt) and [its plan](../superpowers/plans/2026-11-10-native-sim-spike.md). Labels: **measured** (run here), **source** (quoted file or fetched page), **inferred**, **unverified**. Rows below the resume record are append-only.

```text
Resume record (updated 2026-11-10 phase 2 done, coordinator)
Branch / base commit / working-tree state: spike-native-sim in ~/projects/wargrid-wt-native, head 298c313 (base dde868e); T8 may leave uncommitted rows/exports only outside the repo
Last green task / next incomplete task: T0-T7 green and integrated (T2 96000ae, T3 1d43859, T4 296b943, T5 0ccdcc0, T6 a8d6a67, T7 298c313); T8 (Deck baselines) running / T9
Changed paths since last commit: none
Last command / cases / checks / failures / exit / marker: per-task rows in ~/projects/wargrid-native-work/rows/
Known red case or blocker: suite red on spike-native-sim: test_map.gd:59,72 expects 11 presets, now 13 (T3); lib.rs test stubs_report_not_implemented stale. T9 fixes both. Deck W3 probe not yet run.
Environment: see previous record; Deck preflight OK
Approved decisions, pre-authorizations used, deferred gates: see handoff "Authorized for this run"
Usage so far: not recorded
Next exact action: dispatch T9 (opus, WT); retry Deck W3 probe when T8 frees the lock
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
- Steam Deck: `ssh deck@172.16.0.63` timed out at 20:22; the user sets it up before the run. Check: `sh ~/projects/wargrid-native-work/deck-preflight.sh <address>`.
- `pmset`: system sleep after 1 minute unless prevented; start the run under `caffeinate`.
- Emscripten 3.1.74 in `~/emsdk`, 4.0.20 in `~/projects/wargrid-native-work/emsdk-4.0.20`; neither is on `PATH`.
- Firefox on the Mac: a terms-accepted profile for the benchmark runs is `~/projects/wargrid-native-work/profiles/firefox-accepted` (created 2026-11-10; the user accepts the first-run page in it once); earlier spikes lost runs to that page.
- The handoff fact check found the stale lines fixed in the 2026-11-10 rewrite (queue order, art lab state, test counts, `bench_runner.gd` without hordes300 on `main`, the 5x line).
- A fresh-context builder check of handoff, plan and settings (2026-11-10, 27 findings) is folded into the plan: task worktrees with cherry-pick instead of one shared tree, exports from the working tree, timers split into packing, call and applying with K as a range, row ids, the warm row, a required-native test switch, rows files instead of parallel writes to this file.

## Task rows (copied by T9 from ~/projects/wargrid-native-work/rows/, 2026-11-10 22:50)

Copied verbatim, headings demoted. `t8.md` did not exist yet (T8 still running on the Deck); T12 copies it.

### T2 rows (skeleton, bridge and boundary note)

Tree `/Users/pdstuber/projects/wargrid-native-work/wt/t2`, branch `spike-native-sim-t2`, HEAD 0570f6a plus uncommitted T2 work. Host: Mac (Apple Silicon), macOS 27.2.1, Godot 4.7.2.stable.official.ed1daf0bf, rustc 1.96.0-nightly (03749d625 2026-03-14) via `native/rust-toolchain.toml`, clippy from stable. Raw logs in `/Users/pdstuber/projects/wargrid-native-work/logs/t2/`. All rows measured 2026-11-10 21:34-22:00 CET unless labelled.

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

- 2026-11-10, tree /Users/pdstuber/projects/wargrid-wt-native, host Mac: fetched live via WebFetch (excerpted by a small model, not raw): gdext book export-web, godot-cpp README, Godot Exporting for the Web, Compiling for the Web (latest, not 4.7), gdext #438, #1119. Result: all six fetched; quotes in docs/reference/native-sim-spike-candidates.md. Label: source. Raw copies from the same day: WORK/prep/toolchain-sources/. Not re-fetched: Godot PR 124118. Gap: "Emscripten 6.0.12+" on the latest compiling page looks odd; not reconciled.
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

Tree `/Users/pdstuber/projects/wargrid-native-work/wt/t6`, branch `spike-native-sim-t6`, HEAD 96000ae plus uncommitted T6 work. Host: Mac (Apple Silicon), macOS 27.2.1, Godot 4.7.2.stable.official.ed1daf0bf, toolchain from `native/rust-toolchain.toml`, clippy from stable. Other tasks (T5, T7) ran on the Mac at the same time: no row here is a timing row. Raw logs in `/Users/pdstuber/projects/wargrid-native-work/logs/t6/`. Measured 2026-11-10 21:52-22:14 CET unless labelled.

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

Tree: /Users/pdstuber/projects/wargrid-native-work/wt/t7 @ 96000ae + uncommitted T7 changes (working tree exported). Host: Mac (macOS 27.2.1, Apple M-series). Functional runs, NOT timing: single runs, Mac not checked quiet. Logs: WORK/results/<label>/ (run.txt, web-*.log, server.log), build logs WORK/logs/t7/.

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
`sh native/tools/web_run.sh deck firefox /Users/pdstuber/projects/wargrid-native-work/exports/t7-96000ae/W3 'probe=1&only=contact' t7-deck-w3 600` (from the t7 tree; record the Firefox version from the logged UA line). Also available: W3-4.0.20 in the same folder, and a panic run with `probe=panic`.

### T9 rows (integration and behaviour evidence, Stage 5)

Tree `/Users/pdstuber/projects/wargrid-wt-native`, branch `spike-native-sim`, HEAD e2693e7 plus the uncommitted T9 fixes below. Host: Mac (Apple M6), macOS 27.2.1, Godot 4.7.2.stable.official.ed1daf0bf, rustc 1.96.0-nightly (03749d625 2026-03-14) from `native/rust-toolchain.toml`, clippy from stable, Linux container `rust:1.94-slim` (rustc 1.94.1, x86-64). T8 ran on the Deck at the same time (lock held by T8 throughout): no row here is a timing row. Raw logs in `/Users/pdstuber/projects/wargrid-native-work/logs/t9/`. Measured 2026-11-10 22:22-22:50 CET. The extension is removed again at the end (`build.sh remove`, `REMOVED`); the final suite, netplay, lint and warnings ran on that final tree. Both slices (horde, move) green: no slice was left out.

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
