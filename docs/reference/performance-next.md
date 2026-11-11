# Performance: what next after the native sim spike (2026-11-11)

Analysis and experiment record. Written after the [native sim spike](native-sim-spike.md) ended CONDITIONAL GO (whole port only). Question from the user: where are the hot spots, and what else can be tried to reach the performance goals. Handoff for the follow-up work: [perf next prompt](../perf-next-prompt.txt). Budgets, F and history stay in the [performance ledger](performance.md); nothing here changes a budget, a gate or a pin.

Labels: **measured** (run on 2026-11-11, command given), **source** (quoted file or fetched page), **inferred** (arithmetic or reasoning on measured rows), **estimate** (not measured). Host for every measured row: the Mac mini (Apple M6, 12 cores, macOS 27.2.1, Godot 4.7.2.stable.official `ed1daf0bf`), tree `main` 91de974 unless a row says otherwise. No Steam Deck run was made (user, 2026-11-11: the Deck gets a break; the Mac mini is the measuring host for now).

## 1. Short answer

1. **The native spike's "hot loops are a dead end" was caused by the per-unit Dictionaries, not by Rust.** Measured today: when the state already lives in packed arrays, a Rust kernel is 34-58x faster than GDScript on the same arrays and the hand-off costs 0.1-0.4 % of the tick (it was 60-73 % in the native spike). Digests are bit-equal natively and in Firefox (section 5.4). A whole port is no longer the only native route. How much that buys depends on how much of a tick can run in such kernels: today about 56 % on hordes300 (2.07x by the native report's formula, just under its 2.2 line) and about 32 % on the 210-unit goal row (about 1.4x), so for the goal row kernels are a later option, and for a horde mode they are the enabler.
2. **Packed arrays alone, staying in GDScript, give about 1.5x on a real per-unit workload** (a toy loop gave 4x; section 5.3). That is not the 2.2x the native report asked for. Their big wins are at the boundaries: the copy for drawing is 9x cheaper and a snapshot copy is nearly free.
3. **Per tick the presentation hand-off costs more than the simulation.** On the 3v3 bot match: step 1.07 ms, `snapshot()` 0.51 ms, building the draw batch 0.80 ms (section 2). Each unit passes through three Dictionaries per tick (section 3). None of this is in the "simulation tick" budget row, and all of it runs inside one frame.
4. **The simulation runs at full speed on a worker thread in the browser**, and it does not block the main thread (a bench main thread with no game work kept 16.6 ms frames meanwhile); a threaded build cost 4-7 % on the simulation rows and was 7 % faster on the rendered rows, unexplained (section 5.2). Godot's "Separate" render thread is the wrong tool: twice as slow on desktop and not a working render path on the web.
5. **Splitting decisions over several ticks works**: staggering the neighbour loop over three ticks cut the horde tick by 45 % (section 5.3). This is the "split rates" the user chose.
6. **A speed-built web template gains nothing** (0-4 %, inside the noise, download +26 %; section 5.1). Closed.
7. **Recommended architecture** (section 7): keep GDScript as the language of the game; move per-unit state into packed arrays one system at a time, starting at the drawing boundary and with the movement milestone; put a Rust kernel only under systems that are measured hot (a horde mode's agents first); run the simulation on a worker thread. Each step is small, measurable and reversible, and none needs a big-bang port.

## 2. Where the time goes (measured)

`sh tools/run_profile.sh`, headless, profiler on, 300 warm-up plus 1800 sampled ticks (team match: whole match), load 1.2-1.4, log `~/projects/wargrid-perf-work/profile-main-2026-11-11.log`. Milliseconds per tick on the Mac mini; multiply by F = 5.5 for Firefox on the Steam Deck (inferred; the ledger's rule).

| Scenario (units) | `step` mean / p95 / max | `snapshot` mean | `view.batch` mean | hand-off / step |
|---|---|---|---|---|
| skirmish3v3 (210 fighting) | 0.70 / 1.30 / 1.72 | 0.32 | 0.47 | 1.13 |
| team match (3v3 bots, Ashfall, to the 45,000-tick cap) | 1.07 / 1.93 / 9.31 | 0.51 | 0.80 | 1.22 |
| combat open (300) | 1.16 / 1.85 / 2.96 | 0.53 | 0.77 | 1.12 |
| combat dense (300) | 1.00 / 1.88 / 3.24 | 0.48 | 0.69 | 1.17 |
| hordes300 (400 fighting) | 1.98 / 2.84 / 7.56 | 0.99 | 1.74 | 1.38 |
| movement open (300 moving) | 0.57 / 0.69 / 2.46 | 0.72 | 1.18 | 3.3 |
| large_196 | 1.61 / 1.69 / 2.33 | 1.05 | 1.50 | 1.58 |

Inside `step` (share of the `step` mean):

| Zone | skirmish3v3 | team match | combat open | hordes300 |
|---|---|---|---|---|
| `step.combat_plan` (target choice and per-unit bookkeeping, every armed unit, every tick) | 53 % | 38 % | 52 % | 40 % |
| `step.advance` (movement, horde bonus, containers) | 17 % | 30 % | 31 % | 48 % |
| `step.combat_fire` | 25 % | 12 % | 13 % | 7 % |
| `combat.build_grid` (rebuilt every tick, inside plan) | 9 % | 10 % | 8 % | 9 % |
| `combat.nearest` (inside plan) | under 6 % | under 4 % | 9 % | 7 % |
| `step.supply` | under 6 % | 11 % | under 4 % | 2 % |
| `step.ids` (keys plus sort every tick) | under 6 % | under 4 % | under 4 % | 2 % |

Readings:

- **Team match p95 is 1.93 ms against the 1.82 ms budget** (profiler on; the match now runs to the tick cap, so late-game unit counts are in the sample). The native spike saw the same row at 11.44 ms on Deck Firefox against 10 ms. This is the user's goal row (section 8) and it is slightly over. Not investigated further.
- **Worst ticks are 5-9x the mean**: team match 9.31 ms (of which `opponent.decide` 7.37 ms on one tick), contact 11.2 ms (`step.combat_fire` 10.3 ms, a synchronised volley), hordes300 7.56 ms. At F = 5.5 these are 40-60 ms, longer than one 33.3 ms tick. The ledger already lists them as watch items; they are what a player on a slow device would feel first.
- **One frame carries step + snapshot + batch + drawing.** Team match means: 2.38 ms, about 13 ms at F = 5.5; with the p95 values added up, up to about 21 ms against a 16.7 ms frame (inferred; adding p95 values overstates).
- The profile shares agree with the native spike's pre-run profile (its verification file, "Profile shares on HEAD"), which was taken on a loaded host.

## 3. Hot spots in the code (source)

| # | Where | What it does every tick | Why it is expensive |
|---|---|---|---|
| H1 | `simulation.gd:32` `_entities`, one `Dictionary` per unit with nested `Array` and `Dictionary` fields (`position`, `heading`, `destination`, `order`, `combat`, `route`) | every system reads and writes fields by string key | a string-keyed lookup per field access; the native spike measured that copying these fields out is 60-73 % of a GDScript slice's time on every host |
| H2 | `simulation.gd:599` `_advance` | `unit.position = [x, y]` | a new 2-element Array per moving unit per tick, plus `route.slice(1)` at every waypoint |
| H3 | `simulation.gd:628-648` `snapshot()` / `:592` `_entity_copy` | sorts all ids, duplicates every unit Dictionary and deep-copies each nested Array or Dictionary except `route`; also copies buildings, sources, pending commands, results, events | 0.5-1.0 ms per tick, about half of `step`; called once per tick by the game (`main.gd:215`), and again by `base_main.gd`, `main.gd` and `skirmish_main.gd` on clicks, hover and HUD lookups (32 `snapshot()` call sites under `game/scripts` outside the simulation, 14 of them in those three files) |
| H4 | `world_batch.gd:91-120` `WorldBatch.objects` | builds a new 16-key Dictionary per unit from the snapshot copy, with `atan2` for the heading | the third Dictionary layer per unit per tick; then `build()` (`:146`) sorts keys and appends meshes |
| H5 | `world_view.gd:179-199` `set_state` | shallow copy, depth sort of the entity list, point memory, structure key, then H4 | `view.batch` is 0.5-1.7 ms per tick, larger than `snapshot` on every row |
| H6 | `main.gd:218-222` `_show` | `state.entities.map(...)` then `selected_ids.filter(live.has)` | builds a list of all ids per tick and does a linear search per selected unit |
| H7 | `combat.gd:93-144` `Combat.plan` | walks every armed unit every tick: mode checks, target record lookup, range check, engage or chase | 37-53 % of `step`; only the enemy scan is on a cadence (8 ticks), the bookkeeping is not |
| H8 | `combat.gd:295` `_build_grid` (via `_grid`) | rebuilds the per-owner target grid from scratch each tick it is needed | 8-10 % of `step`; ledger rec 4 (persistent grid with incremental updates) was planned and not started |
| H9 | `simulation.gd:517-522` and `:548` | `_entities.keys()` plus sort, the `armed` list, a `before` position Dictionary | small (2-4 %), but pure overhead: ids are never reused and are inserted ascending |
| H10 | `main.gd:99-104` `_physics_process` | `step()` and `_refresh()` (snapshot, batch, HUD) in the same frame | at 30 ticks and 60 frames per second every second frame carries everything and the other one nothing |

## 4. New facts found today

### 4.1 Data layout microbenchmark (measured)

Scratch script (kept at `~/projects/wargrid-perf-work/access_bench.gd`; run with `godot --headless --script <file>`), editor build, 400 units, 3000 passes, the same move arithmetic in every variant, two runs within 1 %:

| Variant | ns per unit | Against today's shape |
|---|---|---|
| Dictionary with nested `[x, y]` arrays, a new array per move (today's shape) | 357 | 1.0 |
| flat Dictionary (scalar fields only) | 270 | 1.3x |
| typed object (class with typed fields) | 180 | 2.0x |
| packed arrays (one `PackedFloat64Array` / `PackedInt32Array` per field) | 84 | 4.2x |
| snapshot copy, Dictionary per unit plus two nested arrays | 410 | |
| snapshot copy, five packed arrays | 0.3 | about 1,400x |
| write x and y of 400 typed objects into one packed array | 45 | |

Limits: a toy loop on the native editor build; a real system also calls functions and looks things up in grids, which a layout change does not speed up. The ledger shows allocation-heavy work scales worse in WebAssembly than plain arithmetic (browser F 6.2-6.5 on the snapshot-heavy movement rows against 5.0-5.2), so the browser gain is probably not smaller (inferred, not measured). The native spike report assumed "GDScript's own cost is mostly Dictionary access" without a measurement; this is the first one.

### 4.2 The web template is built for size (source)

`platform/web/detect.py` at tag `4.7.2-stable` (fetched from github.com/godotengine/godot), `get_flags()`:

```python
        # Use -Os to prioritize optimizing for reduced file size. This is
        # particularly valuable for the web platform because it directly
        # decreases download time.
        # -Os reduces file size by around 5 MiB over -O3. -Oz only saves about
        # 100 KiB over -Os, which does not justify the negative impact on
        # run-time performance.
        # Note that this overrides the "auto" behavior for target/dev_build.
        "optimize": "size",
```

Production builds add thin LTO (`detect.py:172-173`). Desktop templates are built for speed, so part of the measured "WebAssembly is 1.6-1.8x slower than native release on the same hardware" (ledger, target factor measurement) could have been this flag rather than WebAssembly. Section 5.1 measured it: it is not.

### 4.3 Tick rates elsewhere (source)

| Engine | Simulation rate | Source |
|---|---|---|
| Zero Hour | 30 per second | `GameEngine/Include/Common/GameCommon.h:72` `LOGICFRAMES_PER_SECOND = 30` (`~/projects/CnC_Generals_Zero_Hour`) |
| Recoil | 30 | `rts/Sim/Misc/GlobalConstants.h:52` `GAME_SPEED = 30` (`a0240a9b5c`) |
| OpenRA | 25 at default speed | `mods/ra/mod.yaml:286-` `GameSpeeds`, third entry `Timestep: 40` ms (`9636b63eae`) |
| StarCraft II | 22.4 at "Faster" | Blizzard `s2client-proto` `docs/protocol.md:49`: "Uses the "faster" game speed (22.4 gameloops per second)" |
| Permafrost Engine | movement 20 / 10 / 5 / 1, combat 10 / 5 / 1 / 0.5, set separately | `src/game/movement.h:45-50`, `src/game/combat.h:48-53` (`083a99ca`) |

Wargrid already draws between ticks (the art lab's smooth movement), so a lower decision rate is not visible as stutter. Decision in section 8: split rates, not a lower global rate.

### 4.4 What the earlier thread work did and did not cover (source)

- Covered: parallel work inside a tick (2-3 % at 4 threads, a loss at 2; branch `perf-spike-parallel`), and the cost of a threaded web build in Firefox (+4.7 to +8.3 %; it boots with cross-origin isolation on the fly test app in Firefox and Vivaldi; Safari untested) ([ledger](performance.md), "Technology findings").
- Not covered: Godot's "Separate" render thread. The user asked for one measurement after the art lab (perf question Q11, 2026-11-09); `rg -i 'thread_model'` over `docs/` and `git log --all -S thread_model` find no run. The [levers note](art-perf-levers.md) §8 only reasons from source that it is forced off without threads and that WebGL stays on the browser's main thread.
- Not covered: the simulation as a whole on a worker thread, with rendering on the main thread. The determinism rule "single-threaded" is about work inside a tick; one thread running whole ticks in order does not break it (inferred).

## 5. Experiments run on 2026-11-11

Four experiments, run by subagents from written briefs (`~/projects/wargrid-perf-work/*-brief.md`); result files and raw logs are named per section. Every one checked that simulation digests stay identical.

### 5.1 Speed-built web template: no gain worth having (measured)

Result file `~/projects/wargrid-perf-work/opt-template-result.md`, raw logs `~/projects/wargrid-native-work/results/opt-{O,S,F}-{1,2,3}/`. Tree: worktree `spike-native-sim` 49784cf, preset `Web Bench` (its simulation equals `main`'s; the native path is off). Templates built from Godot `4.7.2-stable` (`ed1daf0bf`) with Emscripten 4.0.20: `S` = `scons platform=web target=template_release threads=no production=yes` (`-Os`, thin LTO: a rebuild of the official one as the control), `F` = the same plus `optimize=speed` (`-O3`). `O` = the official template. Mac Firefox, 9 full runs interleaved O S F, load 1.4-2.9 (about 5 during the first O run).

Tick ms, median of 3, p50 / p95:

| Row | O official | S own `-Os` | F own `-O3` | O ÷ F (p50, p95) | O ÷ S control |
|---|---|---|---|---|---|
| movement open | 0.92 / 1.02 | 0.92 / 1.02 | 0.90 / 0.98 | 1.02, 1.04 | 1.00, 1.00 |
| combat open | 1.74 / 2.68 | 1.74 / 2.70 | 1.72 / 2.64 | 1.01, 1.02 | 1.00, 0.99 |
| skirmish3v3 | 0.82 / 1.86 | 0.82 / 1.88 | 0.80 / 1.82 | 1.02, 1.02 | 1.00, 0.99 |
| hordes300 | 2.80 / 4.04 | 2.80 / 4.06 | 2.76 / 4.00 | 1.01, 1.01 | 1.00, 1.00 |
| team match | 1.38 / 3.04 | 1.38 / 3.06 | 1.38 / 3.02 | 1.00, 1.01 | 1.00, 0.99 |

- **Gain 0-4 %, inside the noise** (the spread within one build is up to 0.26 ms, and the control ratio also moves by up to 5 % on single runs).
- Cost: `index.wasm` grows from 39.5 MB to 55.3 MB raw and from 10.05 MB to 12.71 MB gzipped (+26 %), plus an own template build in CI.
- All 199 `DIGEST` lines per run are equal across the nine runs, so the flag is safe for lockstep; it is just not worth it.
- **Verdict: lever B is closed.** My guess that `-Os` explains part of the WebAssembly slowdown was wrong for this workload: the GDScript interpreter is not sped up by `-O3`. Not tried: `lto=full`, Chrome, the Deck.

### 5.2 Threads: "Separate" render thread, and the simulation on a worker (measured)

Result file `~/projects/wargrid-perf-work/threads/threads-result.md` (engine sources quoted there with path and line), raw web logs `~/projects/wargrid-native-work/results/thr-*/`. Tree: copies of worktree `spike-native-sim` 49784cf. Medians of 3 interleaved runs, 60 Hz display, quiet host, Firefox only.

**"Separate" render thread: closed.**

- Desktop, rendered benchmark (`godot --render-thread separate`, the engine's experimental warning confirms it was active): tick p95 roughly doubles, open 3.2 to 7.6 ms, dense 3.3 to 7.8, ashfall 3.2 to 6.9, horde 6.4 to 7.5. Frame-interval p50 rises from 0.3-0.65 ms to about 7 ms. Draw calls are identical. The cause of the 7 ms floor was not investigated.
- Web, threaded export with the setting on: it starts and finishes, but the console logs "Rendering thread not supported by this display server" and "Could not create render target, status: 36054". The WebGL context stays on the browser's main thread (`platform/web/display_server_web.cpp:1144`) and the web display server cannot move it. So it is not a working render path on the web, whatever its CPU numbers say; the picture was not inspected.
- Where the limit sits: the browser binds a WebGL context to the thread that created it (a worker needs an `OffscreenCanvas`; from knowledge, not fetched), and Godot's web platform never hands the context over (no `gl_window_make_current` in `platform/web`, no `OFFSCREENCANVAS_SUPPORT` link flag). So it is an engine limitation resting on a browser rule, not an operating system issue. Untested: the engine's build option `proxy_to_pthread` (`platform/web/detect.py:58-62`, the whole application in a worker).
- This settles the user's condition of 2026-11-09 ("threads in the browser build only once Separate proves fast"): Separate does not prove fast. The reason to use threads is the next result.

**The simulation on a worker thread: the probe passes.** Bench rows with `step()` and `snapshot()` per tick, either on the main thread (30 ticks per frame, as the bench runner always does) or on a `Thread` while the main thread keeps drawing frames:

| Row | No-threads build, main thread: tick p50 / p95 | Threaded build, main thread | Threaded build, worker | Main thread's frame interval while the worker runs |
|---|---|---|---|---|
| hordes300 | 2.80 / 4.06 | 2.94 / 4.22 | 2.96 / 4.28 | 16.6 ms (p95 about 18.4) |
| skirmish3v3 | 0.82 / 1.88 | 0.88 / 1.94 | 0.86 / 1.96 | 16.7 |
| team match | 1.40 / 3.06 | 1.46 / 3.20 | 1.48 / 3.24 | 16.6 |

- The worker runs the simulation at the speed of the main thread (within 1 %), natively too (hordes300 1.61 / 2.33 against 1.60 / 2.31).
- The threaded build costs 4-7 % on tick p50 against today's build on these rows, the same tax the perf spike measured. On the rendered web rows of the first part the threaded build was about 7 % faster instead (horde tick p50 10.10 to 9.40 ms, spread under 0.1); the opposite sign is not explained.
- The 16.6 ms frames are those of a bench main thread that did no game work while the worker ran. They show that the worker does not block the main thread; they do not show the frame time of a real game frame, which still has to build the batch and draw.
- Digests are identical across all configurations and equal the unmodified runner's.
- Not measured: handing the snapshot to the main thread (the probe discards it), Safari and Chrome, the Deck. The rendered web rows are the worst in the whole ledger and were seen again here: on the Mac in Firefox the horde layout's tick frame costs about 10 ms (p50) and 42-49 % of frame intervals exceed 25 ms. That is the cost a worker would take off the main thread, together with levers A1 and C.

### 5.3 Horde spike stage 1: simple agents in three data layouts (measured)

Throwaway code in worktree `../wargrid-wt-horde` (branch `spike-horde` from `main` 91de974, uncommitted): `game/scripts/horde_spike/` and `game/benchmarks/run_horde_spike.gd`; spec `~/projects/wargrid-perf-work/horde-spike-brief.md`, notes `horde/stage1-ready.md`, log `horde/native-matrix.log`. One algorithm in three storages (packed arrays; one Dictionary per agent shaped like today's units; typed objects): flow field toward a goal on Ashfall, a spatial hash rebuilt per tick, separation from up to 12 neighbours, move with wall slide, attack, 40 towers that kill agents, refill to N. All three print equal digests at ticks 300, 900 and 2100 for every row, and a one-digit change in one layout makes the run fail, so they do the same work.

Native editor build, headless, 300 warm-up plus 1800 ticks, two repeats (equal to 0.02 ms), load 1.1-1.6. Mean tick ms; "every tick" recomputes each agent's separation every tick, "every 3rd" staggers it over three ticks:

| Agents | Separation | Packed arrays | Typed objects | Dictionaries | Dictionaries ÷ packed |
|---|---|---|---|---|---|
| 500 | every tick | 1.25 | 1.60 | 1.77 | 1.42 |
| 1,000 | every tick | 2.24 | 3.07 | 3.46 | 1.54 |
| 1,000 | every 3rd | 1.24 | 1.65 | 1.89 | 1.52 |
| 2,000 | every tick | 4.12 | 5.87 | 6.70 | 1.63 |
| 2,000 | every 3rd | 2.17 | 3.02 | 3.48 | 1.60 |

Other rows: the write for drawing costs 0.089 ms for 1,000 agents from packed arrays (eight floats per agent into one buffer) against 0.825 ms when a 16-key Dictionary per agent is built as `WorldBatch.objects` does today (9x). Building the flow field for Ashfall (36,278 cells) takes 196 ms, for Dry Wells 43 ms.

Readings:

- **Packed arrays give 1.4-1.6x on a real neighbour workload, not the 4x of the toy loop.** In the packed version 69 % of the tick is the separation loop (1.54 of 2.24 ms), which is arithmetic and branching; the interpreter costs the same there whatever the storage. The layout change alone does not reach the 2.2x the native report asks for.
- **Split rates work**: staggering the separation over three ticks cuts the tick by 45 %.
- **The hand-off gain is large** (9x for the draw write, and section 4.1's near-free snapshot copy). Columns pay off most at the boundaries, which is lever C.
- **1,000 agents in GDScript are at the edge of the budget**: 1.24 ms here is about 6.8 ms at F = 5.5 for the horde alone, before the player's own units (inferred).
- **A flow field cannot be rebuilt inside a tick in GDScript**: 196 ms here is about a second on the target. It needs time slicing, sectors, or native code.
- These numbers change the reading of the native spike: its hot loops failed on the cost of copying state out of Dictionaries. With state already in packed arrays there is nothing to copy. Section 5.4 measures that.

Mac Firefox 160 (no-threads export with the official template, `horde/web-result.md`, two repeats, load 1.4 before and 3.5 right after the last run; all 24 digest triples equal the native ones). Mean tick ms:

| Agents | Separation | Packed arrays | Typed objects | Dictionaries | Dictionaries ÷ packed | Firefox ÷ native (packed) |
|---|---|---|---|---|---|---|
| 1,000 | every tick | 3.27 | 4.59 | 4.73 | 1.45 | 1.46 |
| 1,000 | every 3rd | 1.77 | 2.45 | 2.55 | 1.44 | 1.42 |
| 2,000 | every tick | 6.02 | 8.75-9.44 | 8.97 | 1.49 | 1.46 |
| 2,000 | every 3rd | 3.21-4.30 (noisy repeat) | 4.67-5.04 | 5.07 | about 1.5 | 1.5-2.0 |

The layout ratio is the same in the browser (1.45x). Typed objects lose their advantage there. The Dictionary layout also pays 1.1 ms (1,000) to 2.2 ms (2,000) per tick for the draw write against 0.1-0.4 ms. On the Steam Deck in Firefox, 1,000 agents with staggered separation would cost about 6-7 ms per tick (1.77 ms times the ledger's Deck Firefox ÷ Mac Firefox ratio of 3.5-4.1; inferred), which agrees with the F = 5.5 estimate above.

### 5.4 A Rust kernel on packed arrays

Result file `~/projects/wargrid-perf-work/native-columns/result.md`, raw web logs `~/projects/wargrid-native-work/results/nc-*/`. Throwaway code in worktree `../wargrid-wt-horde-native` (branch `spike-horde-native` from `spike-native-sim` 49784cf plus the horde spike files, uncommitted, extension left placed): `native/core/src/columns.rs` (the horde kernel of 5.3 in Rust, 6 unit tests), `native/godot/src/columns.rs` (adapter class), `game/scripts/horde_spike/horde_native.gd`. The packed arrays go to Rust as they are and new arrays come back; static tables (blocked grid, flow field, towers) are passed once. `native_pass` makes the same call with no work, which times the hand-off alone. Toolchain as in the native spike (gdext 0.5.5, Rust `nightly-2026-03-15` for the web, dlink template).

Mean tick ms, medians of 3, Ashfall (measured):

| Host | Agents, separation | GDScript on packed arrays | Rust on the same arrays | Hand-off alone | K (kernel gain) | E (effective gain) |
|---|---|---|---|---|---|---|
| Mac native | 1,000, every tick | 2.225 | 0.056 | 0.003 | 42 | 39.7 |
| Mac native | 1,000, every 3rd | 1.233 | 0.036 | 0.003 | 37 | 34.3 |
| Mac native | 2,000, every tick | 4.098 | 0.093 | 0.004 | 46 | 44.1 |
| Mac Firefox | 1,000, every tick | 3.486 (dlink template; 3.258 on today's template) | 0.082 | 0.013 | 51 | 42.5 (39.7 against today's template) |
| Mac Firefox | 2,000, every tick | 6.351 (6.020) | 0.110 | 0.009 | 63 | 57.7 (54.7) |
| Mac Firefox | 5,000, every tick | not run | 0.219 | | | |
| Mac Firefox | 10,000, every tick | not run | 0.393 (p95 0.440) | | | |

- **The hand-off is 0.1-0.4 % of the GDScript tick**, against 60-73 % in the native spike. So E is about equal to K: 34-58 here, against 1.35-1.54 there (measured).
- **Digests are equal** between Rust and the three GDScript layouts, natively and in Firefox, for 1,000 and 2,000 agents, and for 5,000 and 10,000 natively (measured).
- **Template tax** (GDScript on the dlink template against today's template, same workload): +7.0 % mean and +7.8 % p95 at 1,000 agents, +5.5 % and +5.6 % at 2,000, above the 1.4 % spread (measured). Same size as the native spike's 6-7 %.
- **10,000 agents cost 0.39 ms per tick in Firefox on the Mac**, about 1.4-1.6 ms on the Steam Deck by the ledger's ratio (inferred). GDScript on packed arrays needs 3.26 ms for 1,000.
- Limits: this kernel is the friendliest possible shape (flat numeric loops). Web timer resolution is 0.02 ms, so the web hand-off figure is at the clock step. Load during the web runs was 2.1-4.9. Not run: Dry Wells and staggered separation on the web, Linux, Windows, the Deck.

**What this changes.** The native spike concluded "hot loops are a dead end" and left only a whole port. That conclusion holds for Dictionary storage only. Its own condition for reopening hot loops was "at the measured T = 0.060: s 0.70 needs E ≥ 5.1" (native report, section 1). With packed arrays E is 34 or more. Using its formula G = 1 / ((1 + T)(1 - s) + s / E) with T = 0.065 and E = 40 (inferred): a share s of the tick of 0.56 in native kernels gives 2.07, 0.60 gives 2.27, 0.70 gives 2.97, 0.80 gives 4.29. The native spike's line was 2.20-2.26, so about 60 % of the tick in kernels passes it. Today's flat-buffer candidates (movement, horde bonus, target grid and scan) are 56 % of the hordes300 tick, which gives 2.07: close to the line, not over it, until part of the combat bookkeeping is in kernel shape too. Two qualifiers: that line was derived from hordes300, which is now a stress row and not the goal; and on the goal row skirmish3v3 the same candidates are only about 32 % of the tick (advance 17 %, grid 9 %, scan under 6 %; section 2), which gives about 1.4 after the template tax. **A whole port is therefore not the only route any more: packed arrays system by system, GDScript as the reference implementation, and a native kernel only where a system is hot.** Each step is small, reversible (the kernel is optional, the spike's shadow mode compares both every tick), and the first step (packed arrays) is the same for the pure GDScript path.

### 5.5 Horde spike stage 2: a playable throwaway scene (built, not playtested)

For the user to judge whether a horde mode makes sense; not a feature and not reviewed. Start: `cd ~/projects/wargrid-wt-horde && sh tools/run_game.sh res://scenes/horde_lab.tscn`. Notes: `~/projects/wargrid-perf-work/horde/stage2-ready.md`.

- What it is: Dry Wells, one USA player with a normal base, 30,000 credits, 12 tanks and 20 riflemen; waves at 45 s and then every 60 s (100, 200, 400, 800, then refilled to 1,000); enemies follow a flow field to the command building and bite what they touch; units and defences without a target of their own shoot the nearest enemy with their real weapon numbers; losing the command building ends it. The horde runs in packed arrays beside the real simulation and is drawn with one MultiMesh.
- Faked: no armour multipliers, range centre to centre, units do not chase the horde, enemies do not collide with units, one spike-only damage method in `simulation.gd`.
- Seen in one two-minute windowed run (2026-11-11, no input): it starts, waves walk in as thin lines along the flow field, riflemen shoot (shot lines visible), no error lines. Printed there: horde step 3.9-4.7 ms at 130-200 enemies alive (higher than the benchmark's 2.2 ms at 1,000 because the scene also does the shooting and biting lookups per tick in GDScript), flow field rebuild 43-70 ms per building change, which is a visible hitch.
- Not done: a 10-minute run in a window, any balance (headless with no input, the second wave overran the base in the builder's run), a look at readability with 1,000 enemies on screen.

## 6. Levers, ranked

Gain numbers are estimates unless section 5 has a row. "Trace" says whether replay traces and pins move.

| # | Lever | Attacks | Expected gain | Effort | Trace | Status |
|---|---|---|---|---|---|---|
| A1 | **Split a tick over its two frames**: `step()` in the physics frame, `_refresh()` (snapshot, batch, HUD) in the next rendered frame; if a frame is already late, do both at once | H10 | worst frame roughly halves when display rate is at least twice the tick rate; no total saving | S | none | not started |
| A2 | **Simulation and `snapshot()` on a worker thread** in a threaded build; the main thread only builds the batch and draws | H10, worst ticks | the main thread loses step and snapshot (about 60 % of the per-tick work); a slow tick delays the next tick instead of dropping frames; costs 4-7 % (measured) | M-L | none if ticks stay in order | **probe passed**, section 5.2; needs a design |
| A3 | Godot "Separate" render thread | C++ canvas and GL work only | twice as slow on desktop, not working on the web (measured) | | | **closed**, section 5.2 |
| B | Speed-built web template (`optimize=speed`) | everything in the browser | 0-4 %, inside the noise (measured) | own template build in CI; download +26 % | none (digests equal) | **closed**, section 5.1 |
| C | **View rows**: the simulation writes the few fields drawing needs (position, heading, kind index, owner, hp, flags, target) into packed arrays once per tick; `WorldBatch` reads those; the full `snapshot()` stays for hash ticks, tests and desync reports | H3, H4, H5, H6 | removes most of `snapshot` and the per-unit item Dictionary: about half of the hand-off (estimate) | M | none | not started; its read side is open item 2 of the native report |
| D1 | **Packed arrays as the simulation's storage**, migrated system by system, movement first (the movement milestone rewrites it anyway), GDScript throughout | H1, H2, H7 | about 1.5x on per-unit loops (measured on the horde workload); near-free snapshot copies | L, spread over milestones | none intended; needs the golden scenarios as the oracle first | recommended, section 7 |
| D2 | **A Rust kernel under a system that already lives in packed arrays**, GDScript version kept as reference and fallback | the interpreter cost of hot per-unit loops | 34-58x on that system (measured, section 5.4); costs the dlink template tax of 5.5-7.8 % on all remaining GDScript, the Rust web toolchain pins, a larger export, and "a panic aborts the page" | M per kernel after D1 | none (bit-equal digests measured) | recommended only where measured hot; a horde mode first |
| E | **Split rates** (user decision, section 8): movement and firing every tick, per-unit decisions every N ticks staggered by id, woken at once by an order, a hit or a lost target | H7 | 10-20 % of `step` on combat rows (estimate; an earlier deferral experiment, ledger 2f/2k, gained little and was dropped for feel); on the horde workload staggering by 3 gave 45 % (measured) | M | **re-pin** | not started |
| F | Persistent target grid with incremental updates (ledger rec 4); drop the per-tick id sort and the `before` Dictionary | H8, H9 | 8-12 % of `step` (profile shares) | M | none intended | not started |
| G | **Bound the worst ticks**: per-tick work budget for bot decisions and path bursts, staggered volleys | max ticks | removes 40-60 ms ticks on the target (estimate) | M | **re-pin** (the user's decision, ledger G16) | not started |
| H | Rust whole port | H1-H3, H7 | 3.3-4.6x projected by the native report, 1.34x on its downside | XL | none intended | no longer the only native route; D1 plus D2 reaches the same line step by step if about 60 % of the tick sits in kernels (section 5.4) |

Not pursued: a lower global tick rate (user chose split rates), a unit cap per match, a lower F, another engine.

Order of value for the user's goal (section 8): A1 is cheap and helps every row; C removes the largest single block of per-tick work without touching simulation behaviour; A2 takes the simulation out of the frame altogether; D1 is the architectural fix and the gateway to D2; D2 is what makes a horde mode of thousands possible; E, F and G are simulation tuning that waits for the next re-pin.

## 7. Recommended path

The target shape: **GDScript game logic on packed arrays, the simulation on a worker thread, drawing from a few packed arrays, and Rust kernels only under systems measured hot.** Steps, each with its own measurement and gate:

1. **Now, no behaviour change (the [plan](../superpowers/plans/2026-11-11-performance-next.md)):** A1 (tick split), then C (view rows: drawing reads packed arrays). Each gets a ledger row. C is the first packed-array boundary and gives the per-entity read cost the native report left open.
2. **Worker thread:** design A2 on top of C (the worker fills the view rows; the main thread swaps buffers), with a budget proposal re-derived from the new structure for the user (approved in principle, section 8). Production gets the cross-origin isolation headers only then, after a Safari check. The same headers are what a native extension needs on the web, so this step also prepares D2.
3. **Before any storage change:** the approved [golden scenarios plan](../superpowers/plans/2026-11-09-state-digest-golden-scenarios.md). The determinism rules forbid packed arrays in snapshot values today and 19 test files read `_entities`, so the engine-neutral digest and the golden scenarios must exist first. They are the oracle for D1 and D2 alike.
4. **Movement and pathing milestone on packed arrays (D1):** write the new movement state (position, heading, speed, route cursor) as packed arrays from the start, in kernel shape (flat arrays in, flat arrays out, static tables passed once), with the old Dictionary fields filled from them for the systems not yet moved. This avoids writing movement twice and leaves the door open for a kernel. Flow fields belong here too: 196 ms per build in GDScript is too slow, so they need time slicing, sectors, or a kernel. Combat follows in its own task, together with E, F and G and one re-pin.
5. **Native kernels where measured (D2):** only for a system that is already on packed arrays, is measured hot on a goal row or a horde row, and has a GDScript reference to compare against every tick (the spike's shadow mode). The first candidate is a horde mode's agents (new code, no legacy, 40x measured); then the movement and avoidance neighbour loops and the flow field build. Shipping the first kernel costs the dlink template tax (5.5-7.8 % on the remaining GDScript), so it must win more than that on the rows that matter; for the skirmish goal row alone that is not shown yet.
6. **Whole port:** not recommended now. Steps 1-5 reach its projected gain incrementally and keep every step reversible. It stays the fallback if the kernel share cannot reach about 60 % of the tick.
7. **Horde mode:** stage 2 of the horde spike is a playable throwaway scene so the user can judge the mode (approved, section 8; built on 2026-11-11, section 5.5). It is a design question, not a performance task. Its performance answer is already here: about 1,000 agents in GDScript are at the edge of the budget, 10,000 are comfortable with a kernel.

## 8. Decisions (user, 2026-11-11)

Recorded in the [design answers](design-answers-2026-11-08.md#performance-next-user-2026-11-11).

- Goal row: a 210-unit 3v3 must run smoothly in Firefox on the Steam Deck. 400 units fighting at once (hordes300) stays a reported stress row, not the goal.
- No performance problem is felt today; all playtesters have gaming PCs and no low-end tester exists yet. The motive is the ledger, a later horde mode, and fixing architectural base issues now so later work is easier.
- Horde mode size: 1,000 enemies "for now"; not thought through, a spike comes first so the user can see whether the mode makes sense.
- Threads: a threaded browser build may send the cross-origin isolation headers in production if the experiment shows a clear win. The user still wants threads plus the "Separate" render thread measured.
- Tick rate: split rates. Movement and firing stay at 30; unit decisions may run less often, staggered.
- Order: experiments first, then decide the data layout, before the movement milestone starts.
- Budgets may be re-derived from a new structure (simulation on its own thread or frame), as an explicit proposal with measurements and a ledger row; nothing is loosened silently.
- Measuring host: the Mac mini; the Steam Deck is not used for now. Windows and non-headless runs on the Mac mini are approved while the user is away (2026-11-11).

My calls, not user decisions: the horde spike ran its benchmark stage first; the extra experiment of section 5.4 (a Rust kernel on packed arrays), added after 5.3 showed the layout alone gives 1.5x; view rows (C) before any storage change; golden scenarios before D1.

## 9. Not verified

- No Steam Deck row. Every "on the target" number here is a Mac number times F = 5.5 or times the ledger's Deck Firefox ÷ Mac Firefox ratio (3.5-4.1).
- Only Firefox was measured; Safari and Chrome with a threaded or extension build are open.
- The 34-58x of section 5.4 is for one kernel of the friendliest shape. Combat bookkeeping (orders, modes, target records) will gain less; no number exists.
- The worker probe discards its snapshot; the cost of handing state to the main thread is unmeasured until lever C exists.
- A1, C, E (on combat), F and G are unmeasured estimates.
- The team match overrun (1.93 against 1.82 with the profiler on; 11.44 ms on Deck Firefox in the native spike) has no cause yet.
- The rendered web rows (about 10 ms per tick frame on the Mac in Firefox) have no zone breakdown in the browser.
- All spike code of today is throwaway and uncommitted in the worktrees `../wargrid-wt-horde` (branch `spike-horde`) and `../wargrid-wt-horde-native` (branch `spike-horde-native`); nothing was reviewed for keeping.
