# Test Environment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `sh tools/deploy_web.sh test` deploys the local web build to `https://wargrid-web-test.fly.dev/`, and a test build can never share a relay room with production.

**Architecture:** Extend the existing local `tools/deploy_web.sh` with an optional target argument and a version guard that runs before anything is deleted or exported. Bump `main` to `0.7.0-dev` so test and local builds carry a prerelease build string the relay keeps apart from `0.6.0`.

**Tech Stack:** POSIX sh, flyctl, Godot 4.7.2 headless export (unchanged).

**Spec:** `docs/superpowers/specs/2026-11-07-test-environment-design.md`

## Global Constraints

- Test app `wargrid-web-test` (created by the user 2026-11-07), URL `https://wargrid-web-test.fly.dev/`; production app `wargrid-web`, URL `https://wargrid.pdstuber.dev`.
- No test relay, no custom domain, no GitHub workflow or Environment changes.
- Prerelease = `config/version` contains `-`, the same rule as `is_prerelease` in `tools/release_version.py`.
- Real fly deploys need the user's explicit approval. Subagents never deploy, commit or push.
- Agent shells use BSD `sed`.

## Review Focus

1. A typo'd target (`sh tools/deploy_web.sh tset`) must refuse, not fall through to a production deploy. Pinned in Task 1 Step 2.
2. A refused run must leave `web/site/` untouched: the guard runs before `rm -rf`. Pinned in Task 1 Step 2.
3. A dev version deployed to production by hand must refuse. Pinned in Task 1 Step 3.
4. `game/project.godot` with no `config/version` line gives an empty version. Test must refuse it (no `-`); production must refuse it too rather than deploy a build with an empty build string. Pinned in Task 1 Step 2.
5. The test deploy must actually serve: `/health` on the test URL answers after the deploy. Pinned in Task 2 Step 3.

---

### Task 1: Target argument and version guard

**Files:**
- Modify: `tools/deploy_web.sh`
- Modify: `README.md` (Browser build command block, around line 149)

**Interfaces:**
- Produces: `sh tools/deploy_web.sh [test]`. No argument: app `wargrid-web`, health URL `https://wargrid.pdstuber.dev/health`, requires a version **without** `-`. `test`: app `wargrid-web-test`, health URL `https://wargrid-web-test.fly.dev/health`, requires a version **with** `-`. Any other argument: prints `usage: sh tools/deploy_web.sh [test]` to stderr, exits 1. Refusals print `deploy_web: <target> needs <rule>, config/version is "<v>"` to stderr and exit 1.

- [ ] **Step 1: Implement the guard in `tools/deploy_web.sh`**, before the existing `rm -rf`. Read the version with `sed -n 's/^config\/version="\(.*\)"$/\1/p' "$repo_root/game/project.godot"`. Pick app, health URL and rule with one `case "$1"`. Production requires a non-empty version without `-`. Keep the existing export, licence copy and `fly deploy ... -a "$app" ... --ha=false` lines. Afterwards: `curl -fsS --retry 10 --retry-delay 6 --retry-all-errors "$health"` (same flags as `release.yml`).

- [ ] **Step 2: Verify the refusals on the current tree (`config/version="0.6.0"`)** without touching fly:
  - `ls web/site > <scratch>/before 2>&1; sh tools/deploy_web.sh test; echo "exit $?"; ls web/site 2>&1 | diff <scratch>/before -`, where `<scratch>` is the session scratchpad. Expected: refusal message naming `0.6.0`, `exit 1`, empty diff.
  - `sh tools/deploy_web.sh tset; echo "exit $?"`. Expected: usage line, `exit 1`.
  - Empty version: copy the script and a `project.godot` without a version line into a scratch repo layout (`<scratch>/tools/deploy_web.sh`, `<scratch>/game/project.godot`), then run both targets there. Expected: both refuse, `exit 1`, and no `fly` call. Remove the scratch tree afterwards.

- [ ] **Step 3: Verify the production refusal for a dev version** in the same scratch layout, with `config/version="0.7.0-dev"`: `sh <scratch>/tools/deploy_web.sh; echo "exit $?"`. Expected: refusal naming `0.7.0-dev`, `exit 1`.

- [ ] **Step 4: `shellcheck tools/deploy_web.sh`** if installed (`command -v shellcheck`). Expected: no findings. Otherwise record it as unverified.

- [ ] **Step 5: README.** Add under the existing `deploy_web.sh` line: `sh tools/deploy_web.sh test                # same, to https://wargrid-web-test.fly.dev; needs a -dev version and explicit approval`. Add one sentence to the Browser build paragraph: test builds use the production relay, and the relay never mixes build strings in one room.

- [ ] **Step 6: Commit** (only with the user's approval):

```bash
git add tools/deploy_web.sh README.md docs/superpowers/specs/2026-11-07-test-environment-design.md docs/superpowers/plans/2026-11-07-test-environment.md
git commit -m "Deploy the web build to a test app" -m "Test builds share the production relay; a prerelease version keeps them out of production rooms."
```

### Task 2: Dev version and first test deploy

**Files:**
- Modify: `game/project.godot:5`

- [ ] **Step 1: Bump** `config/version="0.6.0"` to `config/version="0.7.0-dev"` (Edit tool).

- [ ] **Step 2: Suite and Python checks on the bumped tree.** Redirect output to the scratchpad and read only the summary lines: `sh tools/run_tests.sh`, `python3 -m unittest discover -s tools`. Expected: `TESTS PASSED <n>` and `OK`. No failure should mention the version.

- [ ] **Step 3: Ask the user for approval, then run `sh tools/deploy_web.sh test`.** Expected: fly deploy succeeds and `curl` on `https://wargrid-web-test.fly.dev/health` exits 0. The user opens the URL and confirms the launcher loads. A test-vs-test relay match is optional and only on the user's request.

- [ ] **Step 4: Commit** (only with the user's approval):

```bash
git add game/project.godot
git commit -m "Start 0.7.0-dev" -m "Dev and test builds must not share relay rooms with the 0.6.0 release."
```

Note: `m7-factions` carries its own `config/version` line. Whichever branch merges second resolves that one-line conflict to `0.7.0-dev`.
