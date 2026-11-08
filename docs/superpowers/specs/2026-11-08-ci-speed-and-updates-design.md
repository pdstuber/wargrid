# CI speed, action updates and Dependabot (design)

Status: **APPROVED by the user 2026-11-08** ("start with part 1"). Small change; not a milestone. No game behaviour changes.

## Why

A `Tests` run takes about 11 min (run 42413090409); the user wants faster feedback. Every job warns that Node 20 actions are forced onto Node 24, and setup-python/setup-go jobs print `DEP0040 punycode`. The user wants dependency updates automated.

## Measured (run 42413090409, `main`)

Critical path: `relay` 33 s → `godot` (linux 556 s, windows 597 s) → `compare-replays` 22 s. Inside a Godot job: editor suite 191–203 s (already 4 shards), warnings check 34–54 s, exported suite 280–293 s (single process), netplay 19–21 s. Repo is public: extra parallel jobs cost no minutes.

## Goals

- Shorter wall clock for `Tests`. Estimate 4–5 min, unmeasured; the result is measured, not assumed.
- No Node 20 deprecation warning; the punycode warning gone or its remaining source named.
- Dependabot for GitHub Actions, Go modules (`relay/`, `protocol/conformance/`), pip (`tools/requirements-dev.txt`, plus `gdtoolkit`) and Dockerfiles (`relay/`, `web/`).

## Non-goals and anti-goals

- No check dropped or weakened: same suites, same trace comparisons, same `TESTS PASSED` and netplay assertions on both platforms.
- No automatic Godot bumps: Dependabot cannot track it, and a bump needs checksums, templates and a replay check. Same for golangci-lint, actionlint and flyctl pins.
- WASM replay coverage: separate later project (part 3).

## Approaches

- **Picked:** shard the exported suite with the runner's existing `--shard`; split editor suite and export/exported suite/netplay into parallel jobs per platform; run the GDScript warnings check once on Linux; start the editor-suite job without waiting for `relay` (only netplay needs the relay binary); bump actions to current majors.
- Rejected: caching the Godot import across runs (import is not the bottleneck); fewer platforms or skipping the exported suite (weakens checks).

## Godot version

Weekly scheduled workflow that opens (or leaves open) one issue when a newer Godot stable release than the pinned one exists. My call; the user saw it proposed and did not object. Builder may drop it if it grows beyond a short script.

## Left to the builder

Job names and split details, whether `release.yml` reuses the new structure unchanged (it calls `tests.yml`), Dependabot schedule and grouping, handling of breaking changes in the action majors.

## Result (run 42460873826, `5a06254`, 2026-11-08)

Wall clock 3 min 30 s (was about 11 min). Jobs: Godot / Tests linux 115 s, windows 150 s; Godot / Exported build linux 146 s, windows 165 s (exported suite sharded 4 ways; locally on macOS 97 s → 46 s); Godot / Warnings 47 s; Relay / Test and conformance 31 s; Godot / Compare replays 8 s. Suite totals equal the baseline run 42413090409 (editor 482 cases / 136,033 checks, exported 482 / 136,016, both platforms); every replay comparison matched. Zero `Node.js 20` or `punycode` lines in the run log. Workflows / Lint failed on SC2015 in the new Godot check, which the runner's shellcheck reports and local shellcheck 0.11.0 does not; fixed in `b14ef3b`.

Added by the user during the run: jobs renamed and grouped by component, `tests.yml` renamed `ci.yml` (workflow `CI`), and CI skipped for pushes and pull requests that change only `docs/**` or Markdown outside `game/`.
