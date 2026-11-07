# Parity harness improvements: measured findings and the pending fork gate (2026-11-07)

Review of `tools/zh_parity/` by an Opus reviewer. Python steps 1-6 and the Python part of 7 are implemented (record: [m7-verification](m7-verification.md), "Parity harness improvements"); usage lives in [zero-hour-parity-harness](zero-hour-parity-harness.md). Fork: `~/projects/GeneralsGameCode-macOS` branch `wargrid-parity` @ `eb595cfc9`; Apple M-series, 12 cores.

## Measured findings

- **The 30 Hz engine loop was the bottleneck, not HTTP.** While paused the engine advances one step per main-loop iteration (`GameEngine.cpp` 1099-1110) and every API request waits for the next drain (line 1092). On macOS `/control speed` does not lift the cap (`getActualFramesPerSecondLimit` ignores it under `__APPLE__`); only `GEN_FPS_CAP` counts.

| `GEN_FPS_CAP` | `/healthz` round trip | `record()` per frame | `step(150)` | idle game CPU | `move_crusader` + `range_crusader`, wall |
|---|---|---|---|---|---|
| 30 | 34.3 ms | 173 ms | 5.25 s | 1.7 % | 106 s |
| 0 (now the default) | 0.41 ms | 6.3 ms | 0.02 s | 101 % (one core) | 8 s |

- Traces are the same with either cap: `move_crusader` and `range_crusader` matched exactly between cap 30 and cap 0, and between two cap 0 runs, once frames are relative to `order_frame` and ids renumbered by first appearance (`analyze.py --same`). Collect runs vary with the random seed, so equality there needs F2.
- Boot to a stable paused frame takes about 2 s warm.
- An uncapped paused game spins one core (the limiter spin-waits the last 2 ms; any cap of 500 or more is also a full spin), so lanes are capped at 6 and default to cpus/2. Six `collect_truck_6` jobs took 35 s on 3 lanes and 30 s on 6.
- Supply proof: `collect_truck_u1625` x3 uncapped pooled 1288.2 credits/min against the measured 1294 (-0.45 %, spread 4.7 %).
- A raw-spawned structure is unfinished: the fork's `spawn` only calls `newObject` and `setPosition`, while map objects also get `setLayer`, `onBuildComplete()` on every create module, `team->setActive()` and `addObjectToPathfindMap`. So a spawned depot never takes deposits and the legality check accepts spots next to a spawned dock; depots are built by a builder.
- The seed is `GetTickCount()` (`SkirmishGameOptionsMenu.cpp` 616). The API player's faction is random; `GEN_AUTO_FACTION` only knows the CWC names `russia`/`usa`, and `FactionUSA` does not exist in Zero Hour (source read).
- Every game writes `00000000.rep` (3.7 MB) and debug logs into the shared user dir; the harness now uses a per-lane `GEN_USER_DATA`.
- Killing everyone's games with a broad `pkill -f generalszh_api` happened once; `--kill DIR` kills only the pids a sweep recorded.

## Pending fork gate (needs explicit user approval; edits the fork, local only, never pushed)

Rebuild with the harness doc's command (about 15 min); commit in the fork only with approval.

- **F1: `spawn` completes structures like map objects.** In `executeCommand` `spawn` (`ExternalControlSystem.cpp`), after `setPosition`, copy the map-object setup from `GameLogic.cpp` 1955-1969. Gain: no builder or power-plant phase (about 700-1200 frames per collect run), correct pathfinding and legality around docks. Verify: a spawned `ChinaSupplyCenter` next to a spawned `SupplyDock` produces deposits; `build_structure` 5 units from a spawned dock is rejected; `collect_truck_u1625` with a built depot, a spawned depot and a map warehouse agree in `cycle_frames` within the repeat spread (if not, it bears on the M7 supply numbers; the "spawned dock skews travel" claim is a hypothesis until then).
- **F2: `GEN_AUTO_SEED=<n>`; `GEN_AUTO_FACTION` takes a Zero Hour template name** (`FactionAmerica`, `FactionChina`, `FactionGLA`). `setSeed(atoi)` at both call sites (616, 1531). Gain: reproducible runs and repeats over chosen seeds. Verify: two runs with one seed give equal traces.
- **F3: idle wait and `pid` in `/healthz`.** While paused with no pending step the loop waits on the request queue (timeout 33 ms) instead of spinning; `GEN_API_IDLE_EXIT=<s>` exits after s seconds without requests. Verify: idle paused CPU under 5 % at `GEN_FPS_CAP=0`, `record()` still about 6 ms per frame, an orphaned game exits, the harness checks the pid against its child.
- F4 (`/units?ids=` filter) only if a profile shows `/units` JSON dominates the 6.3 ms; unverified gain.

Also waiting for the user: deleting `probe_patriot.py`; the Wargrid supply script (`wg_supply2.gd`) is still scratch-only.
