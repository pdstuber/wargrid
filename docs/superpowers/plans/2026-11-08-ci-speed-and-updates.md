# CI speed, action updates and Dependabot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut `Tests` wall clock from about 11 min, remove the Node 20 / punycode warnings, and automate dependency updates.

**Architecture:** Run the exported suite sharded through the existing `tools/run_tests.sh` aggregation; split each platform's Godot job into an editor-suite job and an export job that run in parallel; bump every action to its current major; add `.github/dependabot.yml` and a weekly Godot release check.

**Tech Stack:** GitHub Actions, POSIX sh, Godot 4.7.2 headless.

**Spec:** [CI speed and updates design](../specs/2026-11-08-ci-speed-and-updates-design.md)

## Global Constraints

- No check dropped or weakened: same suites, trace comparisons, `TESTS PASSED` and netplay assertions on Linux and Windows.
- No game behaviour change: suite totals and replay traces equal the pre-change run (42413090409).
- Action majors (latest on 2026-11-08, `gh api repos/<r>/releases/latest`): `actions/checkout@v7`, `actions/setup-go@v7`, `actions/setup-python@v7`, `actions/cache@v6`, `actions/upload-artifact@v7`, `actions/download-artifact@v8`; `golangci/golangci-lint-action@v9` unchanged. Release notes list only the Node 24 runtime (runner ≥ 2.327.1, hosted runners fine) and download-artifact v8 failing on hash mismatch as breaking; the punycode fix is named in upload-artifact v6 and download-artifact v7.
- Artifact `replay-<platform>` keeps holding exactly the four editor traces: `tools/compare_local_traces.sh` downloads it by name.
- Commits: local only, with the user's approval; pushing (needed for every CI check in this plan) needs explicit approval.
- `timeout: 600000` on suite and export calls; redirect output to a file and read the summary lines.

## Review Focus

- Exported binary ignoring `--shard`: every shard runs all cases (4× checks) or none. Task 2 asserts summed CASES/CHECKS equal the unsharded run.
- Traces from a sharded exported run differ from unsharded (case order or partial writes). Task 2 compares them with `cmp`.
- Exported builds printing benign `ERROR:` lines, which `run_tests.sh` treats as failure. Task 2 surfaces it; report to the user, never filter it out silently.
- Windows Git Bash background processes and `wait` exit codes with `.console.exe`. Task 4 checks the Windows log shows the summed summary and that the CASES total matches Linux.
- Godot check opening a duplicate issue every week. Task 3 dispatches it twice.

---

### Task 1: Action bumps, Dependabot, gdtoolkit pin

**Files:**
- Modify: `.github/workflows/tests.yml`, `.github/workflows/release.yml` (every `uses:` line)
- Modify: `tools/requirements-dev.txt` (add `gdtoolkit==4.5.0`)
- Create: `.github/dependabot.yml`

- [ ] **Step 1:** Replace each action reference with the majors in Global Constraints (both workflows).
- [ ] **Step 2:** Add `gdtoolkit==4.5.0` to `tools/requirements-dev.txt`; `gdscript-lint` installs with `pip install -r tools/requirements-dev.txt`.
- [ ] **Step 3:** Create `.github/dependabot.yml`, `version: 2`, weekly, one group per entry (`patterns: ["*"]`) to keep PR count low:
  - `github-actions`, directory `/`
  - `gomod`, directories `/relay`, `/protocol/conformance`
  - `pip`, directory `/tools`
  - `docker`, directories `/relay`, `/web`
- [ ] **Step 4:** Verify: `actionlint` exits 0; `pip install -r tools/requirements-dev.txt` in a scratch venv then `sh tools/run_lint.sh` and `sh tools/run_python_checks.sh` pass.
- [ ] **Step 5:** Commit (with approval): `Bump GitHub Actions to Node 24 majors and add Dependabot`.

Dependabot reads its config only from the default branch: it takes effect after merge to `main`. Its validity shows under the repo's Insights → Dependency graph → Dependabot, checked in Task 4 only if merged.

### Task 2: Sharded exported suite in `run_tests.sh`

**Files:**
- Modify: `tools/run_tests.sh`

**Interfaces:**
- Produces: env `WARGRID_TEST_EXE` (path to an exported tests binary, may include no args). When set, `run_tests.sh` skips the import step and runs each shard as `"$WARGRID_TEST_EXE" --headless -- --shard="$i/$shards"`; aggregation, `ERROR:` scan and the `TESTS PASSED` line are unchanged.

- [ ] **Step 1: Baseline.** Export `macOS Tests` to the scratchpad (`sh tools/export_build.sh "macOS Tests" <scratch>/WargridTests.app`), run `<scratch>/WargridTests.app/Contents/MacOS/WargridTests --headless` once unsharded with the four `WARGRID_*_REPLAY_TRACE` vars and `WARGRID_VECTORS=$PWD/protocol/vectors` pointing into `<scratch>/base/`. Record the `CASES … CHECKS …` line and any `ERROR:` lines.
- [ ] **Step 2:** Implement the `WARGRID_TEST_EXE` branch (a small `if` around the import block and the shard command).
- [ ] **Step 3: Verify.** Same env with traces into `<scratch>/sharded/`, `WARGRID_TEST_EXE=<exe> sh tools/run_tests.sh`. Pass when: exit 0, `TESTS PASSED N` with N and CASES equal to Step 1, and `cmp` reports each of the four traces identical to Step 1. If Step 1 printed `ERROR:` lines, stop and report them.
- [ ] **Step 4:** `sh tools/run_tests.sh` without the variable still passes (editor path unchanged).
- [ ] **Step 5:** Commit (with approval): `Shard the exported test suite`.

### Task 3: Parallel CI jobs and the Godot release check

**Files:**
- Modify: `.github/workflows/tests.yml`
- Create: `.github/workflows/godot-release.yml`

**Interfaces:**
- Consumes: `WARGRID_TEST_EXE` from Task 2.
- Produces: workflow-level `env.GODOT_VERSION` in `tests.yml` (single line `  GODOT_VERSION: 4.7.2-stable`), read by `godot-release.yml`.

- [ ] **Step 1:** Hoist `GODOT_VERSION` and `TEMPLATES_SHA256` to workflow-level `env`. Split `godot` into:
  - `godot-suite` (matrix linux/windows, **no `needs`**): checkout, install Godot, `sh tools/run_tests.sh` with the four editor trace vars, upload `replay-<platform>` (the four editor traces), upload `test-results-<platform>` on failure.
  - `godot-export` (matrix, `needs: relay`): checkout, download `relay-bin`, install Godot, templates cache + install, `"$GODOT_BIN" --headless --path game --import`, both exports, exported suite via `WARGRID_TEST_EXE="$exe" sh tools/run_tests.sh` with the four `export-*` trace vars and `WARGRID_VECTORS`, netplay loop as today, uploads `replay-export-<platform>` (four `export-*` traces), `netplay-<platform>`, `wargrid-windows`, failure logs.
  - `gdscript-warnings` (ubuntu only): install Godot, import, `sh tools/run_warnings.sh`.
  - Matrix shared by YAML anchor if `actionlint` accepts it, else duplicated.
- [ ] **Step 2:** `compare-replays` `needs: [godot-suite, godot-export]`; download pattern stays `{replay,netplay}-*` (matches `replay-export-*`); comparison commands unchanged.
- [ ] **Step 3:** Create `godot-release.yml`: `schedule` weekly cron plus `workflow_dispatch`, `permissions: contents: read, issues: write`, one step with `GH_TOKEN: ${{ github.token }}`:
  - `latest` = `gh api repos/godotengine/godot/releases/latest --jq .tag_name`; `pinned` = `GODOT_VERSION` from `tests.yml`
  - exit 0 when equal, or when an open issue titled `Godot <latest> is available` exists
  - otherwise `gh issue create` with that title and a body naming the pinned version and the files holding the pin (`tests.yml`, `release.yml`, `tools/install_godot.py` checksums).
- [ ] **Step 4:** Verify locally: `actionlint` exits 0; run the Step 3 script body with `gh issue create` replaced by `echo` and confirm it prints the right versions.
- [ ] **Step 5:** Commit (with approval): `Run the Godot suite and export jobs in parallel`.

### Task 4: CI evidence and docs

**Files:**
- Modify: `docs/superpowers/specs/2026-11-08-ci-speed-and-updates-design.md` (Result section), `README.md` (CI paragraph near "CI runs Linux and Windows")

- [ ] **Step 1:** With push approval, push the branch; wait for `Tests`.
- [ ] **Step 2:** Pass when: all jobs green; `compare-replays` passes; both platforms' suite and exported CASES/CHECKS equal run 42413090409; `gh run view <id> --log | rg -c 'punycode|Node.js 20'` prints 0 (any remaining hit: name its action).
- [ ] **Step 3:** Record per-job durations and total wall clock against the 11 min baseline in the design's Result section; one README sentence for Dependabot and the Godot check.
- [ ] **Step 4 (after merge to `main`, which needs approval; `workflow_dispatch` only sees workflows on the default branch):** dispatch `godot-release.yml` twice. Pinned = latest: both runs exit without an issue. Otherwise the first opens one issue and the second opens none.
- [ ] **Step 5:** Commit (with approval): `Record the CI speed-up`.
