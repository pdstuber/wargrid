# Wargrid

A Godot isometric pixel-art RTS preserving Zero Hour's faction identity, strategic choices and pacing, while fixing defects and avoiding inherited performance problems.

**Current state (2026-11-03):** M3 base/economy implementation (`303006b`): builder, reactor/depot/factory, paid FIFO production, power, finite supplies and flying collectors, plus separate base scene/HUD. Headless suite: **97 cases / 101,355 checks / zero failures / exit 0** (95/101,305 at the M3 commit, plus the rendered-probe regression, a snapshot-size ceiling test and a builder-speed change). M2 movement demo and 300-unit workloads remain intact; simulation budgets pass. Final M3 review/checkpoint lives in [M3 verification](docs/reference/m3-verification.md). M3 Linux/macOS/Windows tests and exact movement/economy replay comparisons passed CI. User reported a successful M3 playtest on 2026-11-03. User also confirmed positive M2 playability and no M3 visual issues. Rendered movement benchmark (2026-11-03): terrain draw fix took it from about 3 fps with growing backlog to about 120 fps with no backlog; the benchmark now runs with vsync off and frame p95 is 4.1/6.5 ms (passes the 16.7 ms budget; with vsync on it was 19.6/19.5 ms, which is display pacing; fast Apple M6 only); simulation budgets pass: see [M2 verification](docs/reference/m2-verification.md). Retail parity remains unverified ([verification plan](docs/reference/zero-hour-verification.md)); itemized visible checklist coverage was not supplied. `main` carries M3 plus the benchmark/terrain fix, builder speed change and M4 planning. CI at `c11bf71`: Linux and Windows passed; the macOS runner never started, so macOS evidence for this head is a local trace match against the CI Linux/Windows traces (see [session notes](docs/session-notes.md)), not a CI result.

**M4 status (2026-11-03, merged to `main`): implemented and verified; every listed M4 exit check has evidence (suite, replays across Linux/Windows/macOS, benchmarks with ledger rows, rendered rerun, reviews, user playtest). Not re-played: the two playtest fixes (HUD layout, attack focus). Retail parity remains the pre-M5 gate.** Infantry, tank, barracks, health/armor/weapons, attack / attack-move / guard, shared death cleanup, the fixed 48×32 mirrored scenario, a deterministic opponent, victory/draw/restart, the match HUD and exact combat replay are in. Headless suite at the M4 gate: **135 cases / 103,894 checks / zero failures / exit 0** (about 12 s; same from outside the repo root and from a fresh copy without `.godot`); Python comparator 6 tests OK; three same-host runs match all three traces (`REPLAYS MATCHED 1200` for movement, economy and combat). Benchmarks: movement `BENCHMARK PASSED 2` and combat `COMBAT BENCHMARK PASSED 3`, every layout inside the headless budget but with only 2–5% margin on two of them ([ledger](docs/reference/performance.md)). Evidence, reviews and rulings: [M4 verification](docs/reference/m4-verification.md). **Manual playability: user playtest 2026-11-03, "Game plays great!"** with two remarks (HUD text overlapped the Produce button; attack focus needed clearer feedback), both addressed afterwards and not yet re-played. Cross-platform replay: CI run 41713005327 (Linux, Windows) plus a local macOS comparison match all three traces. The rendered movement benchmark was rerun after the WorldView changes and passed (frame p95 4.0 / 5.2 ms, zero backlog). **Pending, not passed:** retail parity (all values are source/config-informed, not measured). The scripted six-minute scenario ends at tick 9943 with a win for the scripted human player; it proves determinism and progress, not balance.

## Start here

- [Kickoff](docs/kickoff.md) and [wrap-up](docs/wrapup.md): `/kickoff` and `/wrapup` in Claude Code; portable instructions for any agent.
- [Session notes](docs/session-notes.md): current handoff, pending actions and next step.
- [Kickoff blueprint](Wargrid_Kickoff_Blueprint.md): scope, architecture and milestone gates; historical M0 tasks in §7.1.
- [M0 execution plan](docs/superpowers/plans/2026-11-01-m0-foundation.md): exact interfaces, concrete test cases and ordered verification steps.
- [M1 execution plan](docs/superpowers/plans/2026-11-01-m1-vehicle.md): adopted single-vehicle slice, exact movement/input contracts and acceptance cases.
- [M2 execution plan](docs/superpowers/plans/2026-11-01-m2-groups.md): group movement contracts, implemented benchmarks and remaining acceptance gates.
- [Session prompt](prompt.txt): Sol/Medium M4 execution handoff; preparation is not implementation approval. Historical M3 instructions remain in [M3 prompt](docs/m3-prompt.txt).
- [M3 plan](docs/superpowers/plans/2026-11-02-m3-base-supplies.md), [approved design](docs/superpowers/specs/2026-11-02-m3-base-supplies-design.md), [source evidence](docs/reference/m3-economy.md) and [original kickoff prompt](docs/m3-prompt.txt): adopted M3 contracts and source-supported values; runtime parity remains unverified.
- [M4 plan](docs/superpowers/plans/2026-11-03-m4-combat.md), [approved design](docs/superpowers/specs/2026-11-03-m4-combat-design.md) and [combat evidence](docs/reference/m4-combat.md): source-informed design approved for Sol/Medium execution; implementation in progress, uncommitted on `m4-combat`: Tasks 0–4 done (113 cases / 101,543 checks), resume at plan step 4d; see [M4 verification](docs/reference/m4-verification.md).
- [Performance ledger](docs/reference/performance.md): low-end/browser target, derived budgets (assumed 6× slowdown), measurement history; every milestone adds a row.
- [M4 scenario envelope](docs/reference/m4-scenario-envelope.md) and [Task 4/5 test appendix](docs/superpowers/plans/2026-11-03-m4-tests-4-5.md): measured economy/travel/navigation numbers and unrun red-test sketches that prepare M4 Tasks 4, 5 and 7.
- [Zero Hour verification plan](docs/reference/zero-hour-verification.md): level 0 source/config findings plus the automated data check (`tools/check_reference.py`), level 1 reduced to three scripted-map spot checks; gate before M5.
- [Agent instructions](AGENTS.md): development and verification rules.
- [Installation reference](docs/reference/installation.md): available game data, archive hashes and unresolved version questions.

The blueprint owns design and milestone decisions; milestone execution plans own their detailed implementation contracts. This README owns current setup and runnable commands. Reference notes record evidence; original behavior does not override deliberate Wargrid fixes.

## Working tree and controls

`game/` contains a custom-drawn desert scene, engine-light simulation and explicit test suites. `tools/` contains launch/test wrappers and replay comparison. M3 extends authoritative snapshots with copied economy records, integer work/timers and command results. Economy contracts live in [M3 plan](docs/superpowers/plans/2026-11-02-m3-base-supplies.md); movement contracts live in [M2 plan](docs/superpowers/plans/2026-11-01-m2-groups.md); [M1 plan](docs/superpowers/plans/2026-11-01-m1-vehicle.md) and [M0 plan](docs/superpowers/plans/2026-11-01-m0-foundation.md) record baseline contracts.

M2 controls: left-click or drag selects; Shift adds, empty click/Escape clears. Right-click sends one group move. WASD/arrows pan; wheel selects zoom 0.5/1/2. Selection freezes camera until release/cancel. B toggles authored obstruction for repath testing; occupied edits reject with HUD feedback. Twenty vehicles start on 16×16 map. HUD shows selected/moving/pending/arrived/blocked counts. Prototype choices and limits live in [movement note](docs/reference/movement.md) and [group movement](docs/reference/group-movement.md).

M3 base controls: select builder, press 1/2/3 for reactor/depot/factory placement; hover snaps preview, left release submits once, Escape/right cancels. Placement/selection freeze pan/zoom. Right-click unfinished owned foundation resumes; collector right-click source gathers; ordinary ground click moves. Select building for Produce/E, exact-entry queue Cancel or unfinished-construction Cancel. HUD reports credits, power, work, queues and immediate/due rejection. B has no base-scene effect.

M4 skirmish controls (on top of the base controls; the skirmish scene pans with the arrow keys only, because A and S are combat keys): 4 places a barracks (1/2/3 as before); E produces infantry at a barracks and a tank at a factory; right-click an enemy unit or building to attack with the selection (mixed infantry and tanks are one group; any unarmed member rejects the whole order with a HUD message); A then left-click ground attack-moves; S stops; Escape or right-click cancels attack-move mode. Victory, defeat or draw shows a Restart button, which rebuilds the whole match.

## Setup and commands

Use Godot **4.7.2 stable**. Verified local build: `4.7.2.stable.official.ed1daf0bf`.
CI pins matching Linux archive and SHA-256 from [official release metadata](https://api.github.com/repos/godotengine/godot/releases/tags/4.7.2-stable), fetched 2026-11-01. No extra dependencies.

```sh
godot --version
sh tools/run_tests.sh
python3 -m unittest discover -s tools -p 'test_*.py'
sh tools/run_benchmark.sh
```

CI runs Linux and Windows and compares their replay traces. macOS was dropped from CI on 2026-11-03 because hosted macOS runners repeatedly failed to start within the job timeout; at each milestone gate compare this Mac against a CI run instead: `sh tools/compare_local_traces.sh RUN_ID` (runs the suite with all three trace paths, downloads that run's Linux and Windows traces with `gh`, prints `REPLAYS MATCHED 1200` per scenario).

Local reference check (needs the retail backup, never runs in CI): `python3 tools/check_reference.py "/path/Command & Conquer Generals - Zero Hour.tar.gz"` compares Wargrid's unit, building, weapon and armor values with the pinned Zero Hour INI data; see [Zero Hour verification](docs/reference/zero-hour-verification.md).

Test wrapper imports headlessly before tests, checks exit codes and engine diagnostics, then requires positive completion marker. `GODOT_BIN` accepts one executable path, including spaces. Both wrappers resolve project path from script location.

For separately authorized play: `sh tools/run_game.sh` opens the M4 match (blue is you; controls below); `sh tools/run_game.sh res://scenes/base.tscn` opens M3 base; `sh tools/run_game.sh res://scenes/main.tscn` opens the M2 movement demo (still the project's `run/main_scene`). Both open windows. User subsequently playtested M3 and reported it looked good; detailed coverage is recorded as unspecified. Routine checks stay headless.

Current ordinary suite passes **135 cases / 103,894 checks**, `TESTS PASSED 103894` (M3 baseline before M4: 97 / 101,355) (95 / 101,305 at `303006b`); both trace outputs add four file checks. Python comparator passes **6 tests / exit 0**. Headless benchmark runs two unpaced 300-unit/64×64 workloads, each 300 warmup + 1800 measured ticks, then drains active leg. `BENCHMARK PASSED 2` establishes workload validity; separate `BUDGET PASS/FAIL` reports simulation timing targets. See [M3 evidence](docs/reference/m3-verification.md) for regression measurements and [M2 baseline](docs/reference/m2-verification.md).

Rendered benchmark, separately authorized (opens a window): `sh tools/run_game.sh res://scenes/movement_benchmark.tscn`. It disables vsync itself (header shows `vsync=off`), uses 10 seconds wall-clock warmup and 60 seconds samples per layout at 1280×720/zoom 0.5, and reports tick timing, frame intervals, engine draw calls and 10-second backlog windows. First valid run 2026-11-03: frame p95 4.1/6.5 ms, zero backlog; the draw-call print has not run in a window yet. Results and budgets: [performance ledger](docs/reference/performance.md).

Historical M1 suite: **32 cases, 1,089 checks, zero failures, exit 0**, `TESTS PASSED 1089`. Same results from outside repo root and fresh scratch copy without `.godot`. Headless 30-frame smoke exited 0 without diagnostics. Eight isolated failure probes exited 1, including abandoned coroutine caught by runner watchdog. See [M1 verification](docs/reference/m1-verification.md) for evidence and review.

[M0 follow-up CI](https://github.com/pdstuber/wargrid/actions/runs/41299222791) passed `7d67481`. M1 commit `7b70a61` passed CI on [m1-vehicle-plan](https://github.com/pdstuber/wargrid/actions/runs/41322464510) and later [m2-groups](https://github.com/pdstuber/wargrid/actions/runs/41466145349), verified 2026-11-02. Both latter runs cover historical M1. [M2 matrix](https://github.com/pdstuber/wargrid/actions/runs/41591616563) at `4be6b7b` passed Linux/macOS/Windows and movement replay comparison, verified 2026-11-03. [M3 matrix](https://github.com/pdstuber/wargrid/actions/runs/41605911340) at `303006b` passed Linux/macOS/Windows and exact movement/economy replay comparison, verified 2026-11-03.

Historical M1 visible smoke is supported by user recording/reports. [M1 measurements](docs/reference/m1-validation.md) record limited headless performance and same-host ARM64/Rosetta replay evidence; these do not establish M2 performance, rendered frame times or cross-OS determinism. User confirmed positive M2 playability and no M3 visual issues; the full visible checklist was not reported item by item. Rendered frame time and backlog were measured 2026-11-03 on a fast development Mac: zero backlog, frame p95 4.1/6.5 ms with vsync off. Budgets for a low-end/browser target are stricter and two are currently exceeded: see the [performance ledger](docs/reference/performance.md). Headless measurements do not establish feel or frame timing. Zero Hour parity remains unverified. Stop at M3; no M4 expansion.

## Local references

- EA source: `/Users/pdstuber/projects/CnC_Generals_Zero_Hour`; research Zero Hour under `GeneralsMD/`.
- User-owned game backups: `/Users/pdstuber/CnC`; leave `.tar.gz` files in place. See installation reference for archive selection.
- Tooling example: `/Users/pdstuber/projects/hells-verdict`; reuse choices are documented in blueprint §3. Specified wrapper and CI patterns adapted; no gameplay code copied.

These sibling projects and backups are research inputs, not future build/test dependencies. Keep original EA source and game assets outside Wargrid. Exact retail executable version, mod status and runtime behavior remain unverified.
