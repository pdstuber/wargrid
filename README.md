# Wargrid

A Godot isometric pixel-art RTS preserving Zero Hour's faction identity, strategic choices and pacing, while fixing defects and avoiding inherited performance problems.

**Current state:** M1 single-vehicle implementation passes local headless checks: static-grid movement, isometric view, selection/orders, pan/zoom and HUD. Basic visible smoke checked through user recording/reports; M1 remote CI pending. M0 including coverage additions passed [remote CI](https://github.com/pdstuber/wargrid/actions/runs/41299222791).

## Start here

- [Kickoff](docs/kickoff.md) and [wrap-up](docs/wrapup.md): `/kickoff` and `/wrapup` in Claude Code; portable instructions for any agent.
- [Session notes](docs/session-notes.md): current handoff, pending actions and next step.
- [Kickoff blueprint](Wargrid_Kickoff_Blueprint.md): scope, architecture and milestone gates; historical M0 tasks in §7.1.
- [M0 execution plan](docs/superpowers/plans/2026-11-01-m0-foundation.md): exact interfaces, concrete test cases and ordered verification steps.
- [M1 execution plan](docs/superpowers/plans/2026-11-01-m1-vehicle.md): adopted single-vehicle slice, exact movement/input contracts and acceptance cases.
- [Session prompt](prompt.txt): M1 kickoff scope; read current handoff before resuming existing work.
- [Agent instructions](AGENTS.md): development and verification rules.
- [Installation reference](docs/reference/installation.md): available game data, archive hashes and unresolved version questions.

The blueprint owns design and milestone decisions; milestone execution plans own their detailed implementation contracts. This README owns current setup and runnable commands. Reference notes record evidence; original behavior does not override deliberate Wargrid fixes.

## M1 vehicle slice

`game/` contains one custom-drawn desert scene, engine-light simulation and explicit test suites. `tools/` contains POSIX launch/test wrappers. Move commands now advance units; map, route and status belong to authoritative snapshots. Exact contracts live in [M1 plan](docs/superpowers/plans/2026-11-01-m1-vehicle.md); [M0 plan](docs/superpowers/plans/2026-11-01-m0-foundation.md) records foundation history.

Controls: left-click vehicle to select, empty click/Escape to deselect; right-click ground to move. WASD/arrows pan; wheel selects zoom 0.5/1/2. HUD reports selection, tick, status and rejected orders. Static obstacles require four-way routes; prototype choices and limits live in [movement note](docs/reference/movement.md).

## Setup and commands

Use Godot **4.7.2 stable**. Verified local build: `4.7.2.stable.official.ed1daf0bf`.
CI pins matching Linux archive and SHA-256 from [official release metadata](https://api.github.com/repos/godotengine/godot/releases/tags/4.7.2-stable), fetched 2026-11-01. No extra dependencies.

```sh
godot --version
sh tools/run_tests.sh
```

Test wrapper imports headlessly before tests, checks exit codes and engine diagnostics, then requires positive completion marker. `GODOT_BIN` accepts one executable path, including spaces. Both wrappers resolve project path from script location.

For explicit play sessions: `sh tools/run_game.sh`. This opens a window; routine verification stays headless.

Local suite: **32 cases, 1,089 checks, zero failures, exit 0**, `TESTS PASSED 1089`. Same results from outside repo root and fresh scratch copy without `.godot`. Headless 30-frame smoke exits 0 without diagnostics. Eight isolated failure probes exit 1, including abandoned coroutine caught by runner watchdog. See [M1 verification](docs/reference/m1-verification.md) for red/green evidence, deliberate M0 expectation migrations, runner probes and review.

[M0 follow-up CI](https://github.com/pdstuber/wargrid/actions/runs/41299222791) passed `7d67481`: 12 cases / 212 checks. Documentation follow-up `3c0f150` also [passed CI](https://github.com/pdstuber/wargrid/actions/runs/41301647871) with those counts. These historical runs do not verify M1. No M1 remote CI run without approved push. User recording confirms selection, movement/retargeting/arrival and pan. User reports resize/zoom work. User confirms blocked/outside targets are ignored. Feel, performance, cross-platform determinism and Zero Hour parity remain unverified. M1 remote CI remains pending; stop before M2.

## Local references

- EA source: `/Users/pdstuber/projects/CnC_Generals_Zero_Hour`; research Zero Hour under `GeneralsMD/`.
- User-owned game backups: `/Users/pdstuber/CnC`; leave `.tar.gz` files in place. See installation reference for archive selection.
- Tooling example: `/Users/pdstuber/projects/hells-verdict`; reuse choices are documented in blueprint §3. Specified wrapper and CI patterns adapted; no gameplay code copied.

These sibling projects and backups are research inputs, not future build/test dependencies. Keep original EA source and game assets outside Wargrid. Exact retail executable version, mod status and runtime behavior remain unverified.
