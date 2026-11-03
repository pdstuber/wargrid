# Wargrid

A Godot isometric pixel-art RTS preserving Zero Hour's faction identity, strategic choices and pacing, while fixing defects and avoiding inherited performance problems.

**Current state (2026-11-03):** M3 base/economy implementation on `m3-base-supplies`: builder, reactor/depot/factory, paid FIFO production, power, finite supplies and flying collectors, plus separate base scene/HUD. Headless suite: **95 cases / 101,305 checks / zero failures / exit 0**. M2 movement demo and 300-unit workloads remain intact; simulation budgets pass. Final M3 review/checkpoint lives in [M3 verification](docs/reference/m3-verification.md). User explicitly accepted risk from deferred M2 visible/play/rendered/backlog gates and chose headless M3 verification. These gates remain pending; source parity and M3 cross-OS CI remain unverified. User authorized M3 commit and branch publication; remote M3 CI remains pending.

## Start here

- [Kickoff](docs/kickoff.md) and [wrap-up](docs/wrapup.md): `/kickoff` and `/wrapup` in Claude Code; portable instructions for any agent.
- [Session notes](docs/session-notes.md): current handoff, pending actions and next step.
- [Kickoff blueprint](Wargrid_Kickoff_Blueprint.md): scope, architecture and milestone gates; historical M0 tasks in §7.1.
- [M0 execution plan](docs/superpowers/plans/2026-11-01-m0-foundation.md): exact interfaces, concrete test cases and ordered verification steps.
- [M1 execution plan](docs/superpowers/plans/2026-11-01-m1-vehicle.md): adopted single-vehicle slice, exact movement/input contracts and acceptance cases.
- [M2 execution plan](docs/superpowers/plans/2026-11-01-m2-groups.md): group movement contracts, implemented benchmarks and remaining acceptance gates.
- [Session prompt](prompt.txt): original M3 task instructions; resume current checkpoint from session notes rather than restarting tasks.
- [M3 plan](docs/superpowers/plans/2026-11-02-m3-base-supplies.md), [approved design](docs/superpowers/specs/2026-11-02-m3-base-supplies-design.md), [source evidence](docs/reference/m3-economy.md) and [next prompt](docs/m3-prompt.txt): adopted M3 contracts and source-supported values; runtime parity remains unverified.
- [Agent instructions](AGENTS.md): development and verification rules.
- [Installation reference](docs/reference/installation.md): available game data, archive hashes and unresolved version questions.

The blueprint owns design and milestone decisions; milestone execution plans own their detailed implementation contracts. This README owns current setup and runnable commands. Reference notes record evidence; original behavior does not override deliberate Wargrid fixes.

## Working tree and controls

`game/` contains a custom-drawn desert scene, engine-light simulation and explicit test suites. `tools/` contains launch/test wrappers and replay comparison. M3 extends authoritative snapshots with copied economy records, integer work/timers and command results. Exact contracts live in [M2 plan](docs/superpowers/plans/2026-11-01-m2-groups.md); [M1 plan](docs/superpowers/plans/2026-11-01-m1-vehicle.md) and [M0 plan](docs/superpowers/plans/2026-11-01-m0-foundation.md) record baseline contracts.

M2 controls: left-click or drag selects; Shift adds, empty click/Escape clears. Right-click sends one group move. WASD/arrows pan; wheel selects zoom 0.5/1/2. Selection freezes camera until release/cancel. B toggles authored obstruction for repath testing; occupied edits reject with HUD feedback. Twenty vehicles start on 16×16 map. HUD shows selected/moving/pending/arrived/blocked counts. Prototype choices and limits live in [movement note](docs/reference/movement.md) and [group movement](docs/reference/group-movement.md).

M3 base controls: select builder, press 1/2/3 for reactor/depot/factory placement; hover snaps preview, left release submits once, Escape/right cancels. Placement/selection freeze pan/zoom. Right-click unfinished owned foundation resumes; collector right-click source gathers; ordinary ground click moves. Select building for Produce/E, exact-entry queue Cancel or unfinished-construction Cancel. HUD reports credits, power, work, queues and immediate/due rejection. B has no base-scene effect.

## Setup and commands

Use Godot **4.7.2 stable**. Verified local build: `4.7.2.stable.official.ed1daf0bf`.
CI pins matching Linux archive and SHA-256 from [official release metadata](https://api.github.com/repos/godotengine/godot/releases/tags/4.7.2-stable), fetched 2026-11-01. No extra dependencies.

```sh
godot --version
sh tools/run_tests.sh
python3 -m unittest discover -s tools -p 'test_compare_replays.py'
sh tools/run_benchmark.sh
```

Test wrapper imports headlessly before tests, checks exit codes and engine diagnostics, then requires positive completion marker. `GODOT_BIN` accepts one executable path, including spaces. Both wrappers resolve project path from script location.

For separately authorized play: `sh tools/run_game.sh res://scenes/base.tscn` opens M3 base; `sh tools/run_game.sh` retains M2 movement demo. Both open windows; neither was launched during M3 verification. Routine checks stay headless.

Current ordinary suite passes **95 cases / 101,305 checks**, `TESTS PASSED 101305`; both trace outputs add four file checks. Python comparator passes **6 tests / exit 0**. Headless benchmark runs two unpaced 300-unit/64×64 workloads, each 300 warmup + 1800 measured ticks, then drains active leg. `BENCHMARK PASSED 2` establishes workload validity; separate `BUDGET PASS/FAIL` reports simulation timing targets. See [M3 evidence](docs/reference/m3-verification.md) for regression measurements and [M2 baseline](docs/reference/m2-verification.md).

Rendered probe is implemented for a separately authorized session: `godot --path game res://scenes/movement_benchmark.tscn`. It uses 10 seconds wall-clock warmup and 60 seconds samples per layout at 1280×720/zoom 0.5, reporting tick timing, frame intervals and 10-second backlog windows. It was **not launched**.

Historical M1 suite: **32 cases, 1,089 checks, zero failures, exit 0**, `TESTS PASSED 1089`. Same results from outside repo root and fresh scratch copy without `.godot`. Headless 30-frame smoke exited 0 without diagnostics. Eight isolated failure probes exited 1, including abandoned coroutine caught by runner watchdog. See [M1 verification](docs/reference/m1-verification.md) for evidence and review.

[M0 follow-up CI](https://github.com/pdstuber/wargrid/actions/runs/41299222791) passed `7d67481`. M1 commit `7b70a61` passed CI on [m1-vehicle-plan](https://github.com/pdstuber/wargrid/actions/runs/41322464510) and later [m2-groups](https://github.com/pdstuber/wargrid/actions/runs/41466145349), verified 2026-11-02. Both latter runs cover historical M1. [M2 matrix](https://github.com/pdstuber/wargrid/actions/runs/41591616563) at `4be6b7b` passed Linux/macOS/Windows and movement replay comparison, verified2026-11-03. M3 CI now wires both movement and economy traces; its actual remote result awaits separately authorized publication.

Historical M1 visible smoke is supported by user recording/reports. [M1 measurements](docs/reference/m1-validation.md) record limited headless performance and same-host ARM64/Rosetta replay evidence; these do not establish M2 performance, rendered frame times or cross-OS determinism. M2/M3 visible play and rendered/backlog gates remain pending; user explicitly deferred them with risk accepted before M3. Headless measurements do not establish feel or frame timing. Zero Hour parity remains unverified. Stop at M3; no M4 expansion.

## Local references

- EA source: `/Users/pdstuber/projects/CnC_Generals_Zero_Hour`; research Zero Hour under `GeneralsMD/`.
- User-owned game backups: `/Users/pdstuber/CnC`; leave `.tar.gz` files in place. See installation reference for archive selection.
- Tooling example: `/Users/pdstuber/projects/hells-verdict`; reuse choices are documented in blueprint §3. Specified wrapper and CI patterns adapted; no gameplay code copied.

These sibling projects and backups are research inputs, not future build/test dependencies. Keep original EA source and game assets outside Wargrid. Exact retail executable version, mod status and runtime behavior remain unverified.
