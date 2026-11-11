# Simulation on a worker thread: design (2026-11-12)

Status: **proposed, design only. Nothing built, no thread, no benchmark, no header change.** Task T5 of the [performance next plan](../plans/2026-11-11-performance-next.md) (the plan now links this file name). Written against `perf-next` at 96334d6 (T1 clock and T4 view rows in the tree). Lever A2 of the [performance note](../../reference/performance-next.md) (sections 5.2, 6, 7 step 2, 8). Waits for stop gate 3 and the user.

Labels: **measured** (a row in the [verification file](../../reference/performance-next-verification.md), the note or `~/projects/wargrid-perf-work/threads/threads-result.md`), **source** (file:line at 96334d6, or Godot `4.7.2-stable` in `~/projects/wargrid-perf-work/godot`), **inferred** (arithmetic on measured rows), **estimate** (not measured). Host for every measured number: the Mac mini. No Steam Deck number exists; every "target" number is a Mac number times F = 5.5.

Rules: no simulation behaviour or trace change, ticks stay in order on one thread ([determinism rules](../../reference/determinism-rules.md), "Threads"), typed GDScript, no generic framework, no budget changed (section 7 is a proposal).

## 1. Recommendation

**Go in two stages; the thread itself is "later", decided by one measurement.**

1. **Go now (steps 1-6, section 9): the boundary, single-threaded.** A `SimPump` owns the simulation; scenes send it commands and receive one immutable result per tick; no main-thread code reads the live simulation. It runs inline on the main thread in every build, so no thread, no headers, no tax, the same `PresentationClock` split. It is worth doing on its own only modestly (input handlers stop taking full snapshots: 12 sites, section 3.5), but it is the part that has to touch the scenes, the lockstep and the input code, and it keeps the movement milestone's new code off the live simulation. Without it the thread is a big-bang change; with it the thread is one small, reversible step.
2. **Later (steps 7-8): the worker.** Switch the pump to a `Thread` in threaded builds and measure in the browser on the real scene. Go only if section 10 holds. Production headers come after that and a macOS Safari check, and every fly deploy needs explicit approval (user, 2026-11-11).

Why not "go" for the thread straight away: the probe (section 2) showed the worker runs at full speed and does not block the main thread, but it never handed state back, never ran the real scene, and the goal row has no felt problem on any tester's machine (user, note section 8). The gain on the target is inferred, not measured, and no Deck exists for now. Why not "no-go": the main-thread work per tick drops by about 60-70 % on every row (estimate, section 6), and the worst ticks (bot decisions, 7.4 ms on the Mac, about 40 ms on the target) leave the frame entirely; nothing else in the lever table does that.

## 2. What is measured

| Fact | Value | Label |
|---|---|---|
| Tick time on a worker vs the main thread, same threaded build (Firefox, Mac) | hordes300 p50 2.96 vs 2.94, skirmish3v3 0.86 vs 0.88, team 1.48 vs 1.46 ms: equal within 1-2 % | measured (threads-result Part 2) |
| Main-thread frame interval while the worker ran | 16.6 ms p50 / 18.4 p95 / 18.7 max (web), 6.9 native; that main thread did no game work | measured |
| Threaded web build tax on sim rows | +4.3 % (team), +5.0 % (hordes300), +7.2 % (skirmish3v3) tick p50 | measured |
| Threaded build on the rendered web rows | about 7 % faster (horde 10.10 to 9.40 ms), unexplained | measured |
| Digests | identical across no-threads main, threaded main, threaded worker, native main and worker | measured |
| Hand-off cost back to the main thread | not measured: the probe discarded its snapshot | gap |
| After T4, hand-off sum per tick (view_state + view.sort + view.batch), mean | skirmish3v3 0.537, team_match 0.951, hordes300 1.927, movement_open 1.303 | measured (T4 task 7) |
| `view_state()` alone, mean | skirmish3v3 0.160, hordes300 0.444; team_match 0.058 on its first 1,800 ticks only | measured (T4 task 2) |
| `step`, mean / p95 / max | skirmish3v3 0.705 / 1.313; team_match 1.071 / 1.929 / 9.31 (of which `opponent.decide` 7.37); hordes300 1.987 / 2.850 | measured (T0 profile, note section 2) |
| Combat workload in the real skirmish scene path (scripted attack-move, no bot, no buildings), uncapped, native, about 169 units alive | physics frame with the split (step + sound collect) p50 0.98 ms; without the split (step + refresh) 1.82 | measured (split A/B) |
| Threaded test app with COOP/COEP on iOS Safari | boots to the menu; lobby creates a match code through the relay under COEP | reported by the user, not measured |

The split A/B rows capped at 60 fps show 4-5x larger tick times than uncapped on the same tree (skirmish3v3 tick p50 4.8 vs 0.98 ms). That is a host effect (probably clock frequency at low load; not verified), so this design takes gains from CPU time per tick, not from capped frame intervals.

## 3. Design

### 3.1 Ownership: one pump, one owner thread

New `game/scripts/sim_pump.gd` (`extends RefCounted`; outside `simulation/`, because it uses `Thread` and `OS`, which that folder may not use). It owns the `Simulation` from creation to teardown. Exactly one thread ever calls into the simulation: the main thread in inline mode, the worker in worker mode. Ticks run in order on that one thread, so the determinism rule "single-threaded" holds as written (note section 4.4).

The unit of work is a **job**, one per tick:

```text
job    = {commands: Array, opponents: bool, want_snapshot: bool, preview: Dictionary or null}
result = {tick, view: Dictionary (view_state), events: Array, results: Array,
          issued: Array (issue_command results of this job's commands),
          snapshot: Dictionary or null, digest: String, preview: Dictionary or null, skipped: bool}
```

`run_job(job) -> Dictionary` is the only function that touches the simulation: if `match_over()`, return `skipped`; issue the commands in order (collect each `{ok, error}`); `Skirmish.issue_opponent(sim)` when `opponents`; `step()`; copy `combat_events()` and `command_results()` (`duplicate(true)`: they are live views cleared by the next step, sim-interface "Events out"); `view_state()`; on hash ticks `snapshot()` and `StateHash.digest`; answer a placement preview with `preview_build`. **The same `run_job` runs in both modes**: inline mode calls it from `_physics_process`, worker mode from the thread loop. That is the plan's "same pump called on the main thread" fallback, and it means every scene test exercises the code the worker runs.

Worker mode is one long-lived `Thread` per match with a `Mutex` around two Arrays (`_jobs`, `_results`) and a `Semaphore` posted once per job. Loop: wait, pop one job under the lock, `run_job` outside the lock, append the result under the lock. `post(job)` and `take() -> Array` are the scene's only calls. Cap: at most `MAX_QUEUED = 2` jobs waiting; a physics tick that finds the queue full posts nothing (game time slows, as Godot's physics-step cap does today).

Mode choice: worker when `not OS.has_feature("nothreads")` and the scene did not ask for inline. Godot's web export adds the feature `threads` or `nothreads` from `variant/thread_support` (source: `platform/web/export/export_plugin.cpp:357-361`); desktop exports always have threads. Tests, `run_profile.sh`, the benchmarks, the labs and the headless netplay client always run inline.

Rejected: a mutex around the live simulation so the main thread may still call `snapshot()` and `preview_build()` between ticks. Smaller diff, but every input event can block the frame for a whole tick (10-50 ms on the target), and a forgotten unlocked read is a crash that no test finds reliably.

### 3.2 What runs where

| Work | Today | Worker mode |
|---|---|---|
| `step()` | main, physics frame | worker |
| Bot decisions (`Skirmish.issue_opponent`, a `snapshot()` every 30 ticks, `skirmish.gd:67-72`) | main, before `step` (`skirmish_main.gd:39-42`) | worker, inside the job; this is the 7.37 ms worst tick of the team match |
| `view_state()` (0.16-0.44 ms) | main, refresh frame | worker; the result carries it |
| Event copies for sound and visuals | read live after the step (`skirmish_main.gd:53-56`) | worker copies, main replays them |
| Hash-tick `snapshot()` and `StateHash.digest` (every 30 ticks, `online_main.gd:57`, `lockstep.gd:111-118`) | main | worker; the lockstep gets snapshot and digest from the result |
| Placement preview (`preview_build`, per mouse move while placing, `base_main.gd:174`) | main, live query | a job field; the answer comes with the next result |
| `view.sort`, `view.batch`, HUD, sound `update`, drawing, input, transport, lockstep bookkeeping | main | main |

### 3.3 Hand-off out

- **The view state is the hand-off unit** (T4 decision 1). It is built fresh per call, holds packed columns and deep copies (`_sorted_copies` and `_player_snapshots` use `duplicate(true)`, `simulation.gd:719-739`), and the `map` arrays are shared read-only (sim-interface "State out"). Godot's rule fits that: "In GDScript, reading and writing elements from multiple threads is OK, but anything that changes the container size (resizing, adding or removing elements) requires locking a mutex" (source: docs.godotengine.org, 4.4 "Thread-safe APIs", fetched 2026-11-12). Nothing writes a published result after publishing, so no lock is needed beyond the queue.
- **Main drains every frame, in `_process`.** For each result in order: `collect_step(tick, events, results)` on the sound player and the visual director (every tick, never dropped); in online play `finish_tick` and rejections (section 3.4); remember `issued` errors for the HUD. Then **one** `set_view` with the newest view only. When two results arrive in one frame the picture skips a tick, as it already does today when two steps run before a refresh.
- **`command_results` of skipped views are merged.** Today, since T1, when two steps run before one refresh, the first tick's `command_results` never reach `_refresh_hud` (`main.gd:107`, `presentation_clock.gd:16-21`: the second `stepped()` keeps the first pending), so a rejection can be lost (inferred from the code, no test covers it). The drain appends the `command_results` of every drained result into the newest view before `_refresh_hud`. This also fixes the inline path.
- **Interpolation** keeps its clock: `_tick_usec` is set when a view arrives (`world_view.gd:248`). In worker mode arrival times jitter by the step time; the alpha clamps at 1 (`world_view.gd:284`), so a late tick shows as units briefly holding position, not as a frame hitch (estimate; checked in step 8).

### 3.4 Commands in, lockstep and determinism

- **Skirmish (one human, bots in the simulation).** `_submit` stamps `player` and `sequence` from the scene's own counter and posts the command; `run_job` sets `tick = sim.tick()` on the owner thread, so a command always applies at the next step, as today (`main.gd:275`). The scene no longer reads `last_sequences` (`main.gd:277-278`): only this scene issues commands for `local_player`, and a gap in sequences is allowed (sim-interface: sequence must increase). **Behaviour change (presentation only):** a validation error (`issue_command` returning `ok: false`, `simulation.gd:154-160`) reaches `_error` and the rejection sound one tick later (at most 33 ms plus a frame), in inline mode too, so tests see the worker's behaviour.
- **Online (lockstep).** The lockstep and the transport stay on the main thread (a browser WebSocket lives there). `Lockstep.advance(sim)` (`lockstep.gd:88-109`) is split: `take(tick) -> Variant` does every check it does today (ended, left seat, `can_step`, `_verify_hashes`, latency samples, packet erase) and returns the commands in seat order, or null; `record(tick, issued)` appends the command log and the own-seat rejections. `online_main._step_simulation` posts one job per taken tick (up to `CATCH_UP_STEPS`, as today) and calls `finish_tick(result.tick, result.snapshot, result.digest)` when the result arrives; `finish_tick` takes the digest instead of computing it (`lockstep.gd:111-118`). `wants_snapshot` is decided on the main thread for the tick the job will produce.
- **Why this is safe for determinism.** Commands are stamped with their packet tick by the lockstep before they reach the simulation, so arrival timing never changes which tick a command applies to; `run_job` issues them in the same seat order `advance` uses today. The pipeline is self-limiting: own hashes for tick h are recorded in `finish_tick(h)`, which also sends the own packet for h + delay; `take(h + delay)` needs that packet, so it can never run before the hash it verifies exists. With `MAX_QUEUED = 2` and the default delay 4 (`lockstep.gd:34`) the own seat never waits on itself. `run_job` returns `skipped` once the match is over, mirroring `advance`'s `match_over` check, so an in-flight job cannot step past the end.
- **Desync report.** `_hash_snapshot` is the worker's hash-tick snapshot, handed over like the view state (copies, plus read-only `route`, `map` and `terrain_cells` arrays that nothing can mutate). `desync_report()` and `_write_report` stay on the main thread unchanged (`lockstep.gd:162-163`, `online_main.gd:81-89`).
- **Replays, traces, headless clients** (`net/headless_client.gd`, `--replay-log`, `tools/run_netplay.sh`) stay inline and synchronous. A worker-mode game client and headless clients must agree; step 7 adds that check.

### 3.5 Every main-thread read of the live simulation, after the change

| Today (96334d6) | Reads | Replacement |
|---|---|---|
| `main.gd:62` `_reset_camera` `snapshot().map.size` | map size | `view.map.size` of the first result (or `map_data()` before the pump starts) |
| `main.gd:202` `_matching_ids` | unit kind, contained | `_view` rows (`kinds`, `CONTAINED`) |
| `main.gd:273-278` `_submit` | `tick`, `last_sequences` | scene counter; tick stamped by `run_job` |
| `main.gd:107, 110`, `main.gd:265` `simulation.tick()` | clock, hint tick | tick of the newest result |
| `base_main.gd:41` `_hint_point`, `:217`, `:234`, `:265`, `:275`, `:282` | buildings, sources | `view.buildings`, `view.sources` |
| `base_main.gd:148` `_builder`, `:260` `_container` (unit host) | unit kind, owner | rows (`kind`, `owner`; units have no `completed`, today's default `true`) |
| `base_main.gd:174` `preview_build` | placement check | job `preview`, answer in the next result; the ghost shows the last answer (today it is recomputed per tick anyway, key `[kind, origin, tick]`, `:171`) |
| `skirmish_main.gd:136` `_enemy_at`, `:173` `_order_defence` | unit owner; building | rows; `view.buildings` |
| `skirmish_main.gd:37, 141` `match_over()`, `:223` `team_of()` | match status, team | `view.match.status`; `view.players[].team` |
| `skirmish_main.gd:53-56` `_collect_sound` | live events | result `events` / `results` |
| `online_main.gd:28` `_lockstep.start(snapshot())` | tick 0 state | taken inline before the worker starts (or job 0) |

The scene keeps the last drained view as `_last_view`, so every input handler reads the same tick the player sees. In worker mode the scene's `simulation` member is `null`: any read this table missed fails loudly in the worker-mode scene tests instead of racing. Tests in inline mode keep using `main.simulation` as today (about 150 uses in the scene suites).

### 3.6 Pause, speed, restart, teardown

- **Pause** (skirmish, `main.gd:103`): the scene stops posting jobs; the worker idles on its semaphore; a job already queued finishes and is shown. Online never pauses (`online_main.gd:39-40`).
- **Speed:** no game-speed control exists (`physics_ticks_per_second=30`, `project.godot:46`). A future one posts more or fewer jobs per physics tick; nothing else changes.
- **Restart** (`skirmish_main.gd:99-122`): `pump.stop()`, drop queued results, create the new simulation, warm the caches (3.7), start a new pump. Same order in inline mode.
- **Teardown** (scene change, `_leave`, window close): `_exit_tree` calls `pump.stop()`: set `_quit` under the lock, post the semaphore, `wait_to_finish()`. It waits for at most the job in flight (one tick). A `Thread` freed while running is an engine error, so the scene test checks this path.

### 3.7 Thread-safety rules for code the worker runs

- **Static caches written lazily** are the real race: `Definitions._unit_cache`, `_building_cache`, `_profile_cache`, `radius_cache`, `_extra` (`definitions/definitions.gd:15-19`), `Combat._reach_by_kind` (`combat.gd:80`), `Skirmish._skirmish_map` (`skirmish.gd:21`). The HUD reads `Definitions` on the main thread too (`base_main.gd:43, 82, 138`), so a first lookup on both threads at once inserts into one Dictionary from two threads. Rule: the pump fills every cache for every kind before the worker starts, then calls `make_read_only()` on them; a late insert becomes a loud error, not a race. `DestinationAllocation.last_cells_examined` (`destination_allocation.gd:3`) is a diagnostic int, benchmarks only.
- **Profiler** (`debug/profiler.gd:6-11`) is static and not thread-safe. Worker mode refuses `Profiler.enabled`; profiling runs inline (`run_profile.sh` already does).
- **No scene tree, no `Node`, no `Resource` writes** on the worker ("Interacting with the active scene tree is NOT thread-safe", same Godot page). `run_job` touches only the simulation and the result Dictionary.

### 3.8 The PresentationClock split

In worker mode the split is not needed: the physics frame only posts a job (microseconds), and the refresh runs in whichever `_process` first sees a result. The step is off the main thread altogether, which is what the split approximated. In inline mode (no-threads web build, tests, labs) the clock stays exactly as it is, and its tests RF3-RF5 keep driving `_physics_process` synchronously. So `presentation_clock.gd` does not change; worker mode simply bypasses `stepped()`. The F3 overlay shows "worker" instead of the split share in that mode. Open review finding 4 (online stall counted in the split share) is unaffected by this design.

## 4. Failure modes

| Failure | What the player sees | Handling |
|---|---|---|
| Slow tick on the worker (team match 9.3 ms Mac, about 51 ms target: inferred) | units hold position for about one tick, frame rate unchanged; game time catches up within 1-2 ticks at the worker's mean load (section 6) | none needed; queue cap 2 bounds the backlog; worst-tick bounds stay lever G |
| Worker always slower than 33.3 ms (stress rows on a slow device) | the game runs slower than real time, smoothly | as today's physics cap; reported as the W2 row (section 7) |
| Main thread slow (big draw) | lower frame rate; Godot runs extra physics steps, so jobs keep game time | none; this is the case the worker helps |
| Hidden browser tab (no frames) | simulation stops, as today | unchanged |
| Worker died (script error in `run_job`) | no new results | `_process` sees the thread not alive without `_quit`: skirmish shows an error and ends the match, online ends with `ended_protocol`-style status "simulation stopped"; step 7 tests it with an injected error |
| Build without threads (`nothreads`) | the same game, single-threaded with the split | inline pump, today's budgets |
| Threaded build served without COOP/COEP | Godot refuses to start (iOS check: a threaded build only boots with isolation; inferred from the user's report) | a deploy error, not recoverable at run time; new check in `tools/test_deploy_web.py` (it has none today): threaded `Web` preset if and only if the headers are in `web/sws.toml` |

## 5. Builds, tax and cross-origin isolation

- **Two builds?** Recommended: **one web build at a time**, no loader that picks between a threaded and a no-threads build. Production stays on today's `nothreads` build until the go; after the go it switches to the threaded build plus headers. A dual build doubles the export (about 40 MB `index.wasm` each), CI time and the test matrix, and buys only browsers without `SharedArrayBuffer` under isolation and embedding in third-party iframes, neither of which Wargrid has today. The single-threaded fallback is the inline pump inside the same code, not a second build; desktop exports are always threaded and get worker mode with no header question (native worker equals native main: measured).
- **Tax:** the threaded build costs 4-7 % on sim rows (measured). In worker mode it lands on the worker, which has large headroom on the goal row (section 6); it matters only where the worker is the bottleneck (hordes300 on a slow device). The 7 % gain on the rendered rows is unexplained and is not counted.
- **Headers** (`Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp`): two lines in `web/sws.toml` (the test app's copy in `~/projects/wargrid-perf-work/threaded-deploy/web/sws.toml` has exactly that diff) and `variant/thread_support=true` in the `Web` preset (`game/export_presets.cfg:237`). What breaks: any cross-origin subresource without CORP or CORS (none in the export today: the shell's only external URLs are `og:` meta tags for link previews, which the page does not load), opener links to and from other origins (none), embedding Wargrid in another site's iframe (none). The relay WebSocket is not a COEP subresource; the user saw lobby creation work under COEP on iOS (reported). Godot's PWA option `ensure_cross_origin_isolation_headers` (a service worker that adds the headers, `export_plugin.cpp:239`) is not needed: we control the server.
- **Status:** iOS Safari boots the threaded test app (reported). macOS Safari: untested (user checks later, nothing waits on it). Chrome: untested. A second client joining through the relay under COEP: untested. Thread performance in Safari: untested. **Decision (user, 2026-11-11): production headers only after a measured thread win and a Safari check; every fly deploy needs explicit approval at that time.**

## 6. Expected gain

Mean ms per tick, Mac native headless, from the measured rows of section 2. "Main with worker" = hand-off sum minus `view_state` (both measured, in different harnesses, so the difference is an **estimate**); team_match uses 20-30 % of its hand-off for `view_state` (the skirmish and hordes ratios), because its whole-match `view_state` was not measured.

| Row | Main thread today (step + hand-off) | Main with worker (estimate) | Cut (estimate) | Worker per tick (step + view_state, estimate) | Target ×5.5: main today → with worker (estimate) |
|---|---|---|---|---|---|
| skirmish3v3 (goal) | 0.705 + 0.537 = 1.24 | 0.38 | 69 % | 0.87 | 6.8 → 2.1 |
| team_match (goal) | 1.071 + 0.951 = 2.02 | 0.67-0.76 | 62-67 % | 1.26-1.35 | 11.1 → 3.7-4.2 |
| hordes300 (stress) | 1.987 + 1.927 = 3.91 | 1.48 | 62 % | 2.43 | 21.5 → 8.1 |

- **Worst ticks leave the frame:** team_match max 9.31 ms with `opponent.decide` 7.37 (measured) is about 51 ms on the target (inferred), three dropped frames today; with the worker the main thread does not see it.
- **Real scene:** with the split, the physics frame (step + sound collect) is 0.98 ms p50 and step + refresh 1.82 (measured, uncapped, scripted attack-move load with about 169 units alive, not a bot-driven 210-unit match). The worker removes the first and `view_state` from the second, leaving about 0.7 ms per tick on the main thread (estimate, about -60 %).
- **Browser:** the horde render bench's tick frame was about 10 ms p50 in Firefox before T4 (measured). On native it fell from 4.9 to 3.6 ms with T4 (measured) and step plus `view_state` are about 2.4 of that; scaled the same way, a worker would leave about 3 ms of the 10 on the browser's main thread (estimate, the weakest number here).
- **Not a gain:** total CPU per tick rises by the tax (4-7 %) plus copies of events and the queue (not measured; small).

## 7. Budget proposal (for the user; no budget changed)

The ledger's budgets assume the step, the hand-off and drawing share one frame. With the worker they do not, so the rows split by thread. Same method as the ledger (share of the target tick or frame, ÷ F = 5.5), plus the measured threaded-build tax (÷ 1.07, the top of 4-7 %) because F was measured on a no-threads build. **These apply only to builds that run the worker; the no-threads build and inline mode keep today's budgets unchanged.**

| Proposed row | Measures | Share on target | Target | Dev machine | Estimate today (section 6) | Against today's row |
|---|---|---|---|---:|---|---|
| W1 worker tick p95 | `run_job`: step + bots + `view_state` + event copies (+ snapshot and digest on hash ticks online) | 60 % of a tick | 20 ms | **3.40** | skirmish3v3 about 1.5, team_match about 2.0-2.2, hordes300 about 3.3 (sums of p95s, overstated) | replaces sim-only p95 1.82 (30 %): **looser**, because a slow tick no longer drops frames; 40 % headroom lets the backlog drain |
| W2 worker tick p99 | same | 100 % of a tick | 33.3 ms | **5.66** | not estimated | replaces p99 3.64 (60 %): looser; above it game time falls behind |
| M1 main presentation per published tick | `view.sort` + `view.batch` + HUD + sound update (`view_state` moves to W1) | 30 % of a frame | 5 ms | **0.85** | skirmish3v3 0.38 pass, team_match 0.67-0.76 pass, hordes300 1.48 exceeded, movement_open about 1.0 exceeded | replaces plumbing 0.91 (15 % of a tick, the same 5 ms): slightly **tighter** after the tax, new definition |
| Rendered frame p95 | unchanged | full frame | 16.7 ms | 3.04 | | unchanged; it becomes the main gate, and tick frames no longer carry the step |
| Lockstep overhead p99 | unchanged (digest moves to W1) | 10 % of a tick | 3.3 ms | 0.6 | | unchanged |

Worst worker tick stays a watch item without a gate (lever G). Candidly: W1 and W2 are looser than the rows they replace. That is the point of the new structure, and it is only honest if the worker actually ships on the target build; while production is no-threads, today's rows bind and the worker buys nothing in the ledger. Any adoption is a ledger row with the step-8 measurements, never a silent change.

## 8. Risks

1. **The gain is never measured on a slow device.** Every target number is Mac × 5.5. The worker could ship and still miss frames on a Deck if drawing itself is the limit (the rendered web rows suggest drawing matters: about 10 ms per horde tick frame in Firefox on the Mac). Mitigation: step 8 measures the main thread's remaining cost in the browser; the decision is labelled Mac-only.
2. **Data races in shared static state.** Lazily filled `Definitions` and combat caches are read from both threads (3.7). A race is a rare crash or a corrupt lookup, not a test failure. Mitigation: warm and `make_read_only` before start, `simulation = null` in worker mode, a worker-vs-inline digest test that runs a whole bot match.
3. **Online is touched.** Splitting `Lockstep.advance` and moving the digest to the worker changes the code every online match runs. Mitigation: no wire or hash change (`protocol/vectors` untouched), the existing lockstep tests and LOCKSTEP benchmark unchanged, `run_netplay.sh match`, and one mixed check (worker-mode client against headless clients) before the go.
4. **Production headers.** One wrong header pairing and the web game does not start at all (threaded build without isolation), or a future third-party resource breaks under COEP. Mitigation: the deploy test pairs preset and headers; Safari checks; the user's approval per deploy.
5. **Smaller ones:** one tick of extra input-to-feedback delay for command errors and placement previews (presentation only); interpolation jitter from arrival times (step 8 looks); worker death handling is new code.

## 9. Steps (test-first, small; each is one fresh Sonnet subagent and one GREEN)

Every step: suite, lint, warnings, `run_benchmark.sh` when `game/scripts/` changes; pins, traces, digests, VR1, WB18, HUD1 unchanged; the netplay `match` scenario after steps 3-6.

1. **Input handlers on the view state.** Red first: a scene test per handler group (`_matching_ids`, `_builder`/`_container`, `_context_order`, `_unload_selected`, `_set_rally`, `_produce_selected`, `_enemy_at`, `_order_defence`, `_hint_point`) asserting `Profiler.calls(&"snapshot") == 0` per input event, plus the existing HUD and order expectations. Then the table of 3.5 (rows, `view.buildings`, `view.sources`), `_last_view`. Pass: zero snapshots per input event; every existing order test unchanged.
2. **Command errors through results.** Characterize first: list the tests that assert `_error` or a rejection sound right after `_submit`. Then `_submit` stops reading `last_sequences` and the tick, and the error comes from the next tick's issue results; listed tests add one `_physics_process` call (an intended change, named in the verification row). Pass: same texts and sounds one tick later.
3. **`SimPump` inline.** Red first: digest test, pump-driven skirmish with bots vs direct `step()` over 900 ticks, equal every 30 ticks; and "two jobs before one drain keep every tick's events and merge `command_results`" (fails on today's T1 path). Then `sim_pump.gd` with `run_job`, `post`, `take`; `main.gd`, `skirmish_main.gd` post jobs and drain in `_process` through the unchanged clock. Pass: RF1-RF7, sound and visual expectations unchanged.
4. **Lockstep split.** `take`, `record`, `finish_tick(tick, state, digest)`; `online_main.gd` on the pump. Pass: lockstep tests and `test_online_scene.gd` unchanged values; LOCKSTEP benchmark PASS; netplay `match`.
5. **Preview through the job.** Red first: the placement ghost reflects `preview_build` for the cursor after one tick. Pass: placement tests unchanged except the one-tick wait.
6. **Cache warm-up and freeze.** `Definitions` and combat warm and `make_read_only` at pump start. Pass: a full bot match inline with frozen caches gives the same digests (any late insert errors).
7. **Worker mode.** `Thread`, `Mutex`, `Semaphore` in the pump; `simulation = null` in worker mode; Profiler refused. Tests (bounded waits, never a hang): worker vs inline digests equal over a 900-tick bot match; pause posts nothing and the tick stays put; restart joins the old thread; scene freed with a job in flight joins cleanly; an injected error in `run_job` ends the match with the message. Netplay: one worker-mode seat against headless seats, if `run_netplay.sh` can host a scene client (not checked; else a loopback-transport scene test).
8. **Measure (coordinator; rendered windows and a test-app deploy need the user's yes).** Threaded export on the test app, Firefox on the Mac, 60 Hz display: real skirmish scene with skirmish3v3 and team match loads, worker vs inline in the same build, interleaved A B, 4 runs each; plus the no-threads build inline as the tax reference; native desktop the same. Report main-thread CPU per tick frame, frame p50/p95/p99/max, worker tick p95/p99, A/A spreads. Ledger row with W1/W2/M1 labelled as the section 7 proposal.
9. **Production (separate approval).** Headers in `web/sws.toml`, `thread_support=true`, deploy-test pairing; macOS Safari check by the user; deploy only on the user's explicit yes.

Steps 1-6 are the "go now" stage; 7-8 the "later" stage; 9 is the user's.

## 10. What the go/no-go hinges on (after step 8)

Go for worker mode in production only if all hold:

1. **Main-thread win in the browser:** on the real scene in Firefox, worker mode lowers main-thread CPU per tick frame by at least twice the A/A spread on both goal loads, and frame p95/p99 are not worse. A win that shows only in the headless bench does not count.
2. **The worker keeps up:** worker tick p95 inside the proposed W1 (3.40 ms) on the goal rows, measured in the threaded build.
3. **Identical simulation:** worker, inline and headless digests equal, including one mixed online match.
4. **Safari:** macOS Safari boots and plays a skirmish; iOS already boots (reported).
5. **The fallback is untouched:** the no-threads build passes everything it passes today, with today's budgets.

If 1 fails, keep the inline pump (it costs nothing) and drop the thread. If 4 fails, stay on the no-threads build in production and keep the worker on desktop and the test app.

## 11. Not verified

- The hand-off of a result to the main thread in a threaded build (queue, copies, refcounts) has no measurement.
- The team match's whole-match `view_state` cost; section 6 brackets it.
- Why capped-60 runs on the Mac are 4-5x slower per tick than uncapped (assumed frequency scaling).
- Whether `run_netplay.sh` can drive a scene client in worker mode.
- Chrome, macOS Safari, any thread timing in Safari, a second relay client under COEP, the Deck.
- Whether Godot's web `Thread` start or `Semaphore` has a per-call cost worth noticing at 30 posts per second (the probe used one thread for a whole row, no semaphore).
