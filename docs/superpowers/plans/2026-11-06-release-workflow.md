# Release Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pushing a `v*` tag builds Linux, Windows, macOS and Web from that commit after the full test suite passes on it. After one approval it deploys the relay, then the web build, to fly, and publishes the three desktop builds as a GitHub Release.

**Architecture:** A new `.github/workflows/release.yml` calls the existing `tests.yml` as a reusable workflow, so the release runs the same gates CI runs. The workflow stays thin: the version check, Godot install and packaging are small Python tools with unit tests, next to the existing ones in `tools/`. One `publish` job runs behind the GitHub Environment `production`, so a single approval covers relay, web and release, in that order, each step stopping the next on failure.

**Tech Stack:** GitHub Actions, Godot 4.7.2-stable headless export, Python 3.12 tools (ruff, mypy, unittest), flyctl, `gh` CLI inside Actions.

**Spec:** no separate design doc; the decisions below are the user's (2026-11-06) and travel with this plan.

## Decisions

- Trigger: a pushed tag matching `v*` (not a release branch).
- The relay is deployed by the workflow, before the web build.
- Desktop builds are unsigned for now (macOS ad-hoc signed by Godot's built-in signer, not notarized; Windows unsigned).
- Fly deploys sit behind the GitHub Environment `production` with the user as required reviewer.
- The repository becomes public (user action, after Task 0), so release downloads, the approval gate and GPL source availability work without a paid plan.
- Room matching on a simulation fingerprint instead of the exact version is a **separate task** (user, 2026-11-06). Not in this plan; until it lands, clients keep matching on the exact `application/config/version`.
- My call (planning default, not a user approval): a prerelease tag (`v0.7.0-rc.1`) builds and publishes a GitHub prerelease but **skips both fly deploys**, so a rehearsal never touches production.

## Global Constraints

- The tag must equal `v` + `application/config/version` in `game/project.godot`. The relay rejects rooms whose clients send different `build` strings (`relay/room.go:139`), so a release with a stale version would let different simulations share a room and desync.
- Godot `4.7.2-stable`, Linux zip `Godot_v4.7.2-stable_linux.x86_64.zip` SHA-256 `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`, export templates SHA-256 `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011` (values from `tests.yml`; pin, never `latest`).
- Fly apps: relay `wargrid-relay-jvm` (`relay/fly.toml`), web `wargrid-web` (`web/fly.toml`, `--dockerfile web/Dockerfile`, `--ha=false` as `tools/deploy_web.sh` does).
- Secrets: two fly deploy tokens scoped to one app each, stored as Environment secrets `FLY_API_TOKEN_RELAY` and `FLY_API_TOKEN_WEB`. Never print a token; never set `GITHUB_TOKEN` / `GH_TOKEN` in a shell (inside Actions, `GH_TOKEN: ${{ github.token }}` on the release step is the standard pattern and allowed).
- Every release zip carries `LICENSE` (GPL-3.0-or-later), the Godot license text and third-party notices of the exact engine, and `data/maps/NOTICE.md` (EA's copyright line for the converted map). No EA assets.
- Pushing a tag, pushing workflow changes, making the repo public and approving the `production` gate are the user's actions or need their explicit approval each time. Subagents never commit or push.
- Python tools pass `sh tools/run_python_checks.sh` (ruff format, ruff check, mypy) and `python3 -m unittest discover -s tools`.

## Review Focus

1. A tag whose commit fails any test job: nothing is built, deployed or released (`build` needs `tests`). Covered by the job graph in Task 4.
2. A tag that does not match `config/version` (or has no `v`): the run fails in its first job, before tests. Pinned in Task 1.
3. The relay deploy fails or its health check stays red: the web build is not deployed and no release is created. Covered by step order and `curl --retry` health checks in Task 4.
4. Re-running a release workflow after a partial failure (relay deployed, release step failed): the rerun must succeed instead of failing on "release already exists". Pinned in Task 4 (create-or-upload step).
5. The macOS zip loses the app's executable bit or symlinks during packaging: the app would not start. Pinned in Task 3 (`package` appends to Godot's own zip and a test checks the mode bits survive).

---

### Task 0: Pre-publication history scan (read-only)

**Files:**
- Create: `docs/reference/release-verification.md` (resume record in the milestone-prompt format, then this scan's results)

- [ ] **Step 1: Scan all history for secrets.** Run `git log --all -p | rg -n -i 'FlyV1 |fm[12]_[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{30,}|github_pat_|-----BEGIN [A-Z ]*PRIVATE KEY|aws_secret|api[_-]?key\s*[:=]\s*\S{12,}'` and `git log --all --name-only --format= | rg -i '(^|/)\.env|\.pem$|\.p12$|id_rsa'`. Expected: no hits; every hit is listed with commit and path, never with the value.
- [ ] **Step 2: Scan all history for EA material.** `git log --all --name-only --format= | sort -u | rg -i '\.(big|scb|csf|w3d|wnd|str|ini|tga|dds|wav|mp3)$'` and `git rev-list --objects --all | git cat-file --batch-check='%(objectsize) %(rest)' | sort -n | tail -20`. Expected: no EA file types; large objects are known (maps JSON, traces). Any `.ini` hit is checked by hand (it may be Wargrid's own).
- [ ] **Step 3: Record the results** in `docs/reference/release-verification.md` with the commands, hit counts and the tree they ran on. If anything is found, stop: rewriting public-bound history is the user's decision.
- [ ] **Step 4: Hand the user the public switch.** The user makes the repo public (GitHub Settings, Danger Zone) and creates the `production` Environment with themselves as required reviewer. Record their confirmation in the verification file.

### Task 1: Version guard

**Files:**
- Create: `tools/release_version.py`, `tools/test_release_version.py`

**Interfaces:**
- Produces: `read_version(project: Path) -> str` (value of `config/version` in a `project.godot`); `check_tag(tag: str, version: str) -> str` (returns `version`, raises `SystemExit` naming both values on mismatch); `is_prerelease(version: str) -> bool` (true when the version has a `-` suffix). CLI: `python3 tools/release_version.py TAG [PROJECT]` prints `version=<v>` and `prerelease=<true|false>`, one per line (appended to `$GITHUB_OUTPUT` by the workflow).

- [ ] **Step 1: Write the failing tests** in `tools/test_release_version.py` (unittest, like the other `test_*.py`):
  - `test_matching_tag`: `check_tag("v0.7.0", "0.7.0") == "0.7.0"`.
  - `test_prerelease`: `check_tag("v0.7.0-rc.1", "0.7.0-rc.1")` passes; `is_prerelease("0.7.0-rc.1")` is true, `is_prerelease("0.7.0")` false.
  - `test_mismatch_names_both`: `check_tag("v0.7.0", "0.5.1")` raises `SystemExit` whose message contains `v0.7.0` and `0.5.1`.
  - `test_tag_without_v`: `check_tag("0.7.0", "0.7.0")` raises `SystemExit`.
  - `test_reads_project`: a temp `project.godot` with `[application]` and `config/version="0.5.1"` gives `read_version(...) == "0.5.1"`; a file without the line raises `SystemExit`.
  - `test_reads_repo_project`: `read_version(Path("game/project.godot"))` returns a non-empty string (guards the real file's format).
- [ ] **Step 2: Run** `python3 -m unittest tools.test_release_version -v`. Expected: FAIL, module not found.
- [ ] **Step 3: Implement** the three functions and the CLI in `tools/release_version.py` (regex on `^config/version="(.+)"$`, multiline; typed, mypy-clean).
- [ ] **Step 4: Run** `python3 -m unittest discover -s tools` and `sh tools/run_python_checks.sh`. Expected: OK, all checks passed.
- [ ] **Step 5: Commit** `Add the release version guard`.

### Task 2: Shared Godot install, release templates, reusable Tests workflow

**Files:**
- Create: `tools/install_godot.py`
- Modify: `.github/workflows/tests.yml` (the inline "Install pinned Godot" heredoc becomes one call; `on:` gains `workflow_call:`; `push:` gains `branches: ['**']` so a tag push runs tests once, through `release.yml`)
- Modify: `tools/install_export_templates.py` (`WANTED` gains `macos.zip` and `web_nothreads_release.zip`, names checked against the locally installed 4.7.2 templates)

**Interfaces:**
- Produces: `python3 tools/install_godot.py` reading `GODOT_VERSION`, `GODOT_ZIP`, `GODOT_SHA256`, `GODOT_EXECUTABLE`, `RUNNER_TEMP`, `GITHUB_ENV` from the environment, exactly the current heredoc's contract (writes `GODOT_BIN=<path>` to `$GITHUB_ENV`, exits non-zero on checksum mismatch). `tests.yml` callable as `uses: ./.github/workflows/tests.yml`.

- [ ] **Step 1: Move the heredoc** from `tests.yml` into `tools/install_godot.py` unchanged in behaviour (typed `main() -> None`), and replace the step body with `"$PYTHON" tools/install_godot.py`.
- [ ] **Step 2: Extend** `WANTED` in `tools/install_export_templates.py` with `macos.zip` and `web_nothreads_release.zip`.
- [ ] **Step 3: Add** `workflow_call:` and `branches: ['**']` to `tests.yml`'s `on:`.
- [ ] **Step 4: Lint the workflow:** `go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7 .github/workflows/tests.yml`. Expected: no output, exit 0. Then `sh tools/run_python_checks.sh`. Expected: all checks passed.
- [ ] **Step 5: Commit** `Share the Godot installer and make Tests reusable`. CI proof needs a push (user approval): the Tests run on the branch must stay green with identical job names.

### Task 3: Release packaging

**Files:**
- Create: `tools/godot_licenses.gd`, `tools/package_release.py`, `tools/test_package_release.py`

**Interfaces:**
- Produces: `godot --headless --script tools/godot_licenses.gd -- OUT_PATH` writes `Engine.get_license_text()`, then every entry of `Engine.get_copyright_info()` and `Engine.get_license_info()` to `OUT_PATH`; `quit(0)` on success, `quit(1)` on every failure path.
- Produces: `package(platform: str, build: Path, out: Path, extras: list[Path]) -> Path` in `tools/package_release.py`; `platform` is `linux`, `windows` or `macos`. For `linux` / `windows`, `build` is a directory whose files are zipped flat. For `macos`, `build` is the zip Godot exported; it is copied to `out` and the extras are appended (`zipfile` mode `"a"`), so the app's mode bits and symlinks stay as Godot wrote them. Every zip also gets `README.txt` with that platform's first-run note (macOS: right-click Open or `xattr -dr com.apple.quarantine Wargrid.app`; Windows: SmartScreen "More info, Run anyway"; Linux: `chmod +x Wargrid.x86_64`). CLI: `python3 tools/package_release.py PLATFORM BUILD OUT EXTRA...`.

- [ ] **Step 1: Write the failing tests** in `tools/test_package_release.py`, building fixtures in a temp dir:
  - `test_linux_contents`: a build dir with `Wargrid.x86_64` (mode 0o755) plus extras `LICENSE`, `NOTICE.md`, `GODOT_LICENSES.txt` gives a zip with exactly those names plus `README.txt`, and `Wargrid.x86_64`'s `external_attr >> 16 & 0o777 == 0o755`.
  - `test_windows_contents`: `Wargrid.exe` and `Wargrid.console.exe` both present; README mentions `SmartScreen`.
  - `test_macos_appends_and_keeps_modes`: a fixture zip holding `Wargrid.app/Contents/MacOS/Wargrid` with mode 0o755 and one symlink entry; after `package("macos", ...)` both entries keep their `external_attr`, the extras and `README.txt` are present, and README contains `xattr -dr com.apple.quarantine`.
  - `test_empty_build_fails`: an empty build dir raises `SystemExit`.
  - `test_unknown_platform_fails`: `package("web", ...)` raises `SystemExit`.
- [ ] **Step 2: Run** `python3 -m unittest tools.test_package_release -v`. Expected: FAIL, module not found.
- [ ] **Step 3: Implement** `package` and the CLI (sorted entries for a stable listing; typed, mypy-clean), and `tools/godot_licenses.gd` (typed, `extends SceneTree`, reads the path after `--` from `OS.get_cmdline_user_args()`).
- [ ] **Step 4: Run** `python3 -m unittest discover -s tools`, `sh tools/run_python_checks.sh`, and `godot --headless --script tools/godot_licenses.gd -- <scratch>/godot_licenses.txt; echo $?` followed by `rg -c 'Godot Engine' <scratch>/godot_licenses.txt`. Expected: OK, checks pass, exit 0, a count of at least 1.
- [ ] **Step 5: Commit** `Package release zips with license notices`.

### Task 4: The release workflow

**Files:**
- Create: `.github/workflows/release.yml`
- Modify: `README.md` (new "Release" section after "Browser build": how to cut a release, the prerelease rule, the first-run notes, and that a relay deploy ends matches in progress), `AGENTS.md` (one line: for release changes, read this plan)

**Interfaces:**
- Consumes: `tools/release_version.py` CLI (Task 1), `tools/install_godot.py` and the reusable `tests.yml` (Task 2), `tools/godot_licenses.gd` and `tools/package_release.py` CLI (Task 3).
- Produces: workflow `Release`, jobs `version`, `tests`, `build`, `publish`.

- [ ] **Step 1: Write `release.yml`:**
  - `on: push: tags: ['v*']`; `permissions: contents: read` at top level; `concurrency: {group: release, cancel-in-progress: false}`.
  - `version` (ubuntu-latest): checkout, `python3 tools/release_version.py "$GITHUB_REF_NAME" >> "$GITHUB_OUTPUT"`; outputs `version`, `prerelease`.
  - `tests`: `needs: version`, `uses: ./.github/workflows/tests.yml`.
  - `build` (ubuntu-latest, `needs: [version, tests]`, timeout 30): checkout; Godot via `tools/install_godot.py` with the Linux pins from Global Constraints; templates via `tools/install_export_templates.py`; export with `tools/export_build.sh` to `build/release/linux/Wargrid.x86_64` (`Linux`), `build/release/windows/Wargrid.exe` (`Windows Desktop`), `build/release/macos/Wargrid.zip` (`macOS`; a `.zip` path because Godot exports a zip on a non-macOS host), `web/site/index.html` (`Web`); `godot_licenses.gd` to `build/release/GODOT_LICENSES.txt`; `package_release.py` three times to `release/Wargrid-<version>-<platform>.zip` with extras `LICENSE`, `game/data/maps/NOTICE.md`, `build/release/GODOT_LICENSES.txt`; upload artifacts `release-zips` (`release/*.zip`) and `web-site` (`web/site/`), `if-no-files-found: error`.
  - `publish` (ubuntu-latest, `needs: [version, build]`, `environment: production`, `permissions: contents: write`): checkout; download both artifacts; `superfly/flyctl-actions/setup-flyctl` pinned to a release tag with an exact `version`. If `prerelease` is `false`: `flyctl deploy relay -c relay/fly.toml -a wargrid-relay-jvm --ha=false` with `FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN_RELAY }}`, then `curl -fsS --retry 10 --retry-delay 6 --retry-all-errors https://wargrid-relay-jvm.fly.dev/health`; then the web deploy as `tools/deploy_web.sh` does it, without the export (site already in `web/site/`), with `FLY_API_TOKEN_WEB`, then `curl ... https://wargrid.pdstuber.dev/health`. Last: with `GH_TOKEN: ${{ github.token }}`, `gh release view "$GITHUB_REF_NAME"` and either `gh release upload "$GITHUB_REF_NAME" release/*.zip --clobber` (exists) or `gh release create "$GITHUB_REF_NAME" release/*.zip --title "Wargrid $VERSION" --generate-notes` plus `--prerelease` when `prerelease` is `true` (Review Focus 4).
- [ ] **Step 2: Lint:** `go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7`. Expected: no output, exit 0.
  Unverified until the rehearsal: Godot's built-in ad-hoc signer (`codesign/codesign=1` in the `macOS` preset) exporting from a Linux host. If that export fails, stop and ask; the fallback is a separate `macos-latest` job for the macOS export only (more runner minutes, the same packaging).
- [ ] **Step 3: Docs:** add the README "Release" section and the AGENTS line; check links and paths.
- [ ] **Step 4: Commit** `Add the tag-triggered release workflow`.

### Task 5: Setup and rehearsal (user steps marked)

**Files:**
- Modify: `docs/reference/release-verification.md` (evidence), `game/project.godot` (`config/version` for the rehearsal and the real release)

- [ ] **Step 1 (user):** `fly tokens create deploy -a wargrid-relay-jvm` and `fly tokens create deploy -a wargrid-web`; paste each into the `production` Environment as `FLY_API_TOKEN_RELAY` / `FLY_API_TOKEN_WEB`. The agent never sees or prints the values.
- [ ] **Step 2: Rehearsal version.** Set `config/version="<next>-rc.1"` (the user picks `<next>`; default proposal `0.7.0` for M7 gate 1), run the suite, commit `Prepare <next>-rc.1`.
- [ ] **Step 3 (approval):** push the branch and the tag `v<next>-rc.1`. Expected: `version`, `tests`, `build` green; `publish` waits for approval.
- [ ] **Step 4 (user):** approve. Expected: no fly deploy (prerelease), a GitHub prerelease with three zips.
- [ ] **Step 5: Smoke-test the zips** on macOS: unzip the macOS zip, clear quarantine, `Wargrid.app/Contents/MacOS/Wargrid --headless --quit-after 120; echo $?`. Expected: exit 0. Check each zip lists `LICENSE`, `NOTICE.md`, `GODOT_LICENSES.txt`, `README.txt`. Record in the verification file.
- [ ] **Step 6: Real release.** Set `config/version="<next>"`, commit, push and tag `v<next>` (approval), approve the gate. Expected: relay deployed and healthy, web deployed and healthy, release published. Then `WARGRID_RELAY_URL=wss://wargrid-relay-jvm.fly.dev/ws WARGRID_MATCH_WAIT=600 sh tools/run_netplay.sh match` (README) passes. Record everything with the tree and run ids.

## Not in this plan

- Room matching on a simulation fingerprint (separate task, user 2026-11-06).
- Code signing and notarization, Linux arm64, a Steam Deck build, auto-update, skipping the relay deploy when `relay/` is unchanged.
