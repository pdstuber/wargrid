# Wargrid

A Godot isometric pixel-art RTS preserving Zero Hour's faction identity, strategic choices and pacing, while fixing defects and avoiding inherited performance problems.

**Current state:** M0 local foundation implemented: launchable scene, command/state kernel and headless behavior tests. Original M0 commit passed [remote CI](https://github.com/pdstuber/wargrid/actions/runs/41296904731); test coverage additions verified locally. No movement or gameplay yet.

## Start here

- [Kickoff](docs/kickoff.md) and [wrap-up](docs/wrapup.md): `/kickoff` and `/wrapup` in Claude Code; portable instructions for any agent.
- [Session notes](docs/session-notes.md): current handoff, pending actions and next step.
- [Kickoff blueprint](Wargrid_Kickoff_Blueprint.md): scope, architecture and milestone gates; historical M0 tasks in §7.1.
- [M0 execution plan](docs/superpowers/plans/2026-11-01-m0-foundation.md): exact interfaces, concrete test cases and ordered verification steps.
- [M1 execution plan](docs/superpowers/plans/2026-11-01-m1-vehicle.md): proposed single-vehicle slice, exact movement/input contracts and acceptance cases.
- [Session prompt](prompt.txt): paste into a new coding-agent session to implement M1; not an instruction to rebuild M0.
- [Agent instructions](AGENTS.md): development and verification rules.
- [Installation reference](docs/reference/installation.md): available game data, archive hashes and unresolved version questions.

The blueprint owns design and milestone decisions; milestone execution plans own their detailed implementation contracts. This README owns current setup and runnable commands. Reference notes record evidence; original behavior does not override deliberate Wargrid fixes.

## M0 foundation

`game/` contains Godot project, one scene, engine-light simulation and explicit test suites. `tools/` contains POSIX launch/test wrappers. Move commands store orders; positions stay unchanged. Exact APIs and acceptance cases live in [M0 execution plan](docs/superpowers/plans/2026-11-01-m0-foundation.md).

## Setup and commands

Use Godot **4.7.2 stable**. Verified local build: `4.7.2.stable.official.ed1daf0bf`.
CI pins matching Linux archive and SHA-256 from [official release metadata](https://api.github.com/repos/godotengine/godot/releases/tags/4.7.2-stable), fetched 2026-11-01. No extra dependencies.

```sh
godot --version
sh tools/run_tests.sh
```

Test wrapper imports headlessly before tests, checks exit codes and engine diagnostics, then requires positive completion marker. `GODOT_BIN` accepts one executable path, including spaces. Both wrappers resolve project path from script location.

For explicit play sessions: `sh tools/run_game.sh`. This opens a window; routine verification stays headless.

Local behavior suite: **12 cases, 212 checks, exit 0**. Before kernel implementation, valid stubs produced 37 behavioral failures (11 cases, 184 checks, exit 1; no parse errors). Scratch runner probes each exited 1: false assertion, empty case list, suite parse error, return before checks, return after check without completion, runtime error followed by passing case, and main-script import parse error. Restored smoke baseline: 1 case, 1 check, exit 0. See [verification record](docs/reference/m0-verification.md).

[Remote CI](https://github.com/pdstuber/wargrid/actions/runs/41296904731) passed commit `20739d6`: 11 cases / 199 checks. Current test additions (212 checks) have not run remotely. Original M0 exit gate passed. M1 planning requested; implementation awaits an explicit kickoff. No visual, game-feel, performance, cross-platform determinism or Zero Hour parity validation. No M1 implementation started.

## Local references

- EA source: `/Users/pdstuber/projects/CnC_Generals_Zero_Hour`; research Zero Hour under `GeneralsMD/`.
- User-owned game backups: `/Users/pdstuber/CnC`; leave `.tar.gz` files in place. See installation reference for archive selection.
- Tooling example: `/Users/pdstuber/projects/hells-verdict`; reuse choices are documented in blueprint §3. Specified wrapper and CI patterns adapted; no gameplay code copied.

These sibling projects and backups are research inputs, not future build/test dependencies. Keep original EA source and game assets outside Wargrid. Exact retail executable version, mod status and runtime behavior remain unverified.
