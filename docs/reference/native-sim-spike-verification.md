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
