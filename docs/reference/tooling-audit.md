# Tooling audit: scripts, test runner and CI (2026-11-13)

Status: findings and recommendations only. Nothing was changed. Tree: `d0cc99d`, clean.

## The short version

- **Three gates have holes.** The local checks skip files git does not track yet (so a brand-new file is never checked before the push), the test suite's 180 s watchdog does not measure real time, and a killed test run leaves its Godot processes behind. Findings 1 to 3.
- **Half of the test suite's time is one match, simulated three times.** Fixing that and dealing the cases to the four processes by cost takes the slowest test process from about 87 s to about 47 s (computed from per-case times, not a timed full run). Findings 5 and 6.
- **CI waits for the relay tests before it starts the slowest job.** Removing that wait saves about 25 s on a normal run and up to about 90 s on a cold cache. With findings 5 and 6, a run should drop from a median of 6 minutes to roughly 4 to 5 (estimate, not measured). Finding 7.
- The other local checks are already fast (lint 3.3 s, warnings 7.7 s, Python checks 5.5 s, shell checks 0.3 s, public check 0.2 s). No work needed there.

What this covers: the shell wrappers in `tools/`, the test runner `game/tests/run_tests.gd`, the three workflows in `.github/workflows/`, and the Python tools. Assumed load: one developer plus coding agents on one Mac, and GitHub-hosted runners for CI. The repository is public, so CI minutes are free; what costs is the wait for a result.

## Measurements

All local numbers: 12-core Mac, load average about 2 while measuring, Godot 4.7.2.

**CI, all 74 runs so far:** 49 green, 24 red, 1 cancelled. Green runs: median 369 s, fastest 237 s, slowest 549 s. On `main` since 2026-11-08 12:00 UTC: 26 green, 3 red. Every download failure in the history is from the GitHub outage on 2026-11-08 morning and was fixed that day (mirror fallback, cache, authenticated downloads); none since.

**CI run 43411259035, where the time goes:**

| Job | Total | Largest step |
|---|---|---|
| Godot / Exported build (windows) | 421 s | exported suite 327 s, netplay 33 s |
| Godot / Tests (linux) | 365 s | suite 334 s |
| Godot / Exported build (linux) | 321 s | exported suite 261 s |
| Godot / Tests (windows) | 303 s | suite 285 s |
| Relay / Lint | 75 s | golangci-lint 60 s |
| Tools | 52 s | Python checks 26 s, tool tests 19 s |
| Relay / Test and conformance | 44 s (145 s in run 43398423570) | `go test -race` 14 s (59 s) |
| Docker, Godot / Lint, Workflows / Lint, Compare replays | 38, 34, 7, 7 s | |

The suite runs four times per CI run and takes 3 to 4 times as long there as on the Mac.

**Test suite, every case timed alone in one process:** 808 cases, 203.6 s in total.

| Case | Time |
|---|---|
| `test_team_match_prefix` | 60.3 s |
| `test_team_core_series` | 47.0 s |
| `test_frc_skirmish_match` | 11.7 s |
| `test_mirror_match_script` | 8.2 s |
| the other 804 cases | 76.4 s |

Ten cases are 75 % of the suite. One 20000-tick team match, stepped alone, takes 30.9 s.

**How the cases land on the four processes today** (case number modulo 4): 68.1 s, 16.9 s, 31.8 s, 86.9 s. The run is as slow as the slowest process: 87 s. Dealt by cost, the slowest would be 60.3 s, which is the longest single case. These sums come from the per-case times above; they leave out process start and the slowdown from four processes running at once, and no full four-process run was timed for this note.

## Must fix

1. **The local gates skip files that git does not track yet** (`tools/check_public.sh:8,21,28`, `tools/run_warnings.sh:7,10`, `tools/run_python_tests.sh:6`, `tools/run_shell_checks.sh:5`)
   - **What this is:** These four scripts ask git for the list of files to check (`git ls-files`, `git grep`).
   - **Problem:** Git lists only files it already tracks. A new file is untracked until `git add`, and the gates run before that. So a new `.gd` file is not warning-checked, a new Python test file is not run, a new `.sh` is not linted, and a new document is not scanned for home paths or the private word list. CI then finds it, but for the public check that is after the push, when the leak is already public.
   - **Fix:** `git ls-files -co --exclude-standard …` in all five `git ls-files` calls (tracked plus new files, ignored files stay out; `run_warnings.sh` has two that must stay in step) and `git grep --untracked …` in `check_public.sh`. Verified on this file while it was untracked: plain `git grep` did not see it, `git grep --untracked` did.
   - **If we skip it:** "All checks pass" keeps meaning "all old files pass", and the public check cannot stop a leak in a new file.

2. **The suite's watchdog does not measure real time** (`game/tests/run_tests.gd:50`)
   - **What this is:** A 180 s timer that should stop a hung test and name the case.
   - **Problem:** The timer counts frame time, and Godot caps how much time one frame may add: the frame step is cut to `max_physics_steps_per_frame` physics steps, default 8, about 0.13 s (Godot `main/main.cpp`, read on the master branch, not the 4.7.2 tag). A case that computes for seconds between frames adds almost nothing. Probe: a 4 s timer did not fire during 20 s of blocking work spread over 10 frames. CI shows the same: its suite steps take 261 to 334 s, nearly all of it inside the test processes, and the 180 s timer never fires. A truly stuck case therefore runs until the caller gives up: 25 minutes per CI job, 600 s for an agent. No such hang is recorded so far.
   - **Fix:** Replace the timer with a thread that checks real time in short sleeps (`OS.delay_msec`, a stop flag, `wait_to_finish()` at the normal end), prints `FAIL: watchdog timeout in <case>` and kills its own process. About a dozen lines, keeps the case name, works in exported builds. Untested sketch. Pick the limit from CI, where one process takes up to 330 s.
   - **If we skip it:** A hang costs 25 minutes of CI per job and gives no case name.

3. **A killed test run leaves its Godot processes running** (`tools/run_tests.sh:4`)
   - **What this is:** The script starts up to four Godot processes in the background and waits for them.
   - **Problem:** Its signal handler deletes the log folder and does not exit or stop the children. Tested with one test process (`WARGRID_TEST_ONLY`): after `kill -TERM` the script ran on to its end without its logs, and the Godot process was still running three seconds later. With four processes the script keeps waiting for the others (shown with a stand-in script on `/bin/sh`, not with Godot). The leftovers burn up to four cores for up to 90 s, which distorts a benchmark or the next test run started right after. Whether the agent harness's timeout kills the whole process group I did not check; a plain `kill` does not.
   - **Fix:** Set `pids=""` first, then two traps: `trap 'rm -rf "$log_dir"' EXIT` and `trap 'kill $pids 2>/dev/null; exit 1' HUP INT TERM`. The `exit` in the second still runs the first (checked on `/bin/sh`, dash and bash with a stand-in script).
   - **If we skip it:** Timed-out runs keep loading the machine, and benchmark rows taken right after are wrong without anyone knowing why.

4. **The pooled parity report silently drops metrics** (`tools/zh_parity/analyze.py:568`)
   - **What this is:** It merges the metrics of several repeated runs of one scenario into one row.
   - **Problem:** It takes the list of metrics from the first run only. If run 1 lacks a metric (a unit that fired once has no shot interval), that metric vanishes from the pooled result even when runs 2 and 3 have it, and the decision-list row is skipped without a MISSING mark. Confirmed by running: order short, good, good gives 3 metrics; good, good, short gives 7.
   - **Fix:** `for key in dict.fromkeys(k for m in per_run for k in m):`.
   - **If we skip it:** A parity decision can rest on a report that lost rows, and nothing says so.

## Should fix

5. **One team match is simulated three times per suite run** (`game/tests/test_team_match.gd:60-96`)
   - **What this is:** `test_team_match_prefix` runs the same 20000-tick match twice side by side and compares them every 200 ticks. `test_team_core_series` runs it a third time for a per-tick check value.
   - **Problem:** One run takes 30.9 s, so about 93 s of the suite's 204 s is this one match. CI pays that four times per run.
   - **Fix:** Let one run produce the trace, the final digest and the core series (about 47 s), and delete the other two runs. What goes away is the check "two runs in one process agree every 200 ticks". The pinned final digest, the pinned core series and CI's comparison of the 100-row trace across four builds still catch a run that differs from the recorded one. They do not catch state shared between two simulations living in one process, which only the side-by-side run can show. This is a test-design choice, so it is yours.
   - **If we skip it:** The longest case stays at 60 s, and no amount of parallel processes gets the suite under that.

6. **Cases are dealt to the test processes by position, not by cost** (`game/tests/run_tests.gd:18-34`)
   - **What this is:** Process `i` of 4 takes every case whose number modulo 4 is `i`.
   - **Problem:** The slow cases land where they land. Today: 68, 17, 32 and 87 s. One process idles for 70 s while another holds the run.
   - **Fix:** A small cost table in the runner for the handful of slow cases (everything else counts as cheap), then deal the cases longest-first to the least loaded process. Each process computes the same deal, so no coordination is needed. About 12 lines; `test_runner.gd` tests `shard()` and changes with it. Result, computed from the per-case times: slowest process 87 s to 60 s alone, to about 47 s with finding 5. After finding 5, raising the cap of 4 processes on the Mac is worth one more measurement.
   - **If we skip it:** Every full gate run, local and CI, is about a third longer than it needs to be.

7. **CI's slowest job waits for the relay tests** (`.github/workflows/ci.yml:100`, `:117-120`, `:232-244`)
   - **What this is:** The exported-build job needs a relay binary for its netplay step. It gets it as an artifact from the relay test job, so it cannot start before that job ends.
   - **Problem:** The relay job takes 44 s on a good day and 145 s on a cold cache, and all of it is added in front of the longest job. The slowest green run in the history (549 s) is exactly that case. The binary is only used five minutes into the export job.
   - **Fix:** Build the relay inside the export job (`actions/setup-go` plus one `go build` in `relay/`, about 20 s with a warm cache) and point the netplay step (`ci.yml:153`) at that binary. Delete `needs: relay-test`, the artifact upload and download, the two cross-builds in the relay job and the `WARGRID_RELAY_BIN=` prefix of the conformance step (`ci.yml:238`); `run_conformance.sh` builds its own relay when that variable is unset. The build adds to the export job, so the net saving is the relay job's time minus the build: about 25 s on a normal run (44 s job), about 90 s on a cold Go cache (145 s job). Estimate.
   - **If we skip it:** Every CI run carries the relay job's time in front of its slowest job.

8. **CI runs the Python tool tests twice, the second time from a hand-kept list** (`.github/workflows/ci.yml:286-304`)
   - **What this is:** `run_python_checks.sh` already runs every tracked `test_*.py` and the `analyze.py` self-test. The "Tool tests" step then runs 17 lines by name: 16 test files and the self-test.
   - **Problem:** 16 of the 17 lines repeat work, about 19 s, and the list drifts: it lacks five test files the script finds by itself. On 2026-11-13 it turned `main` red (run 43379347607) because this step ran outside the venv and found no numpy. Its only unique line is `test_install_godot.py`. The script excludes that file with a comment saying it downloads Godot, but the test replaces every download with a mock (`tools/test_install_godot.py:39,77`), so the exclusion looks stale.
   - **Fix:** Drop the exclusion in `run_python_tests.sh:6` and delete the whole step, plus the `GITHUB_PATH` line before it that exists only for this step (`ci.yml:284`). If the exclusion has a reason the comment does not give, keep it and reduce the step to `python3 tools/test_install_godot.py`.
   - **If we skip it:** A list that must be kept in step by hand, and has already failed once for a reason that was not a bug.

9. **`run_lint.sh` uses whatever `gdlint` is on the PATH** (`tools/run_lint.sh:2`, `docs/development.md:65`)
   - **What this is:** The GDScript style check. CI installs the pinned version from `tools/requirements-dev.txt`; locally it is a separate install the development notes ask for by hand.
   - **Problem:** Both are 4.5.0 today. Dependabot bumps the pin (it already bumped ruff twice), and then CI lints with a newer version than the Mac, so lint passes locally and fails in CI or the other way round.
   - **Fix:** Do what `run_shell_checks.sh` does: `sh tools/ensure_venv.sh` and put `tools/.venv/bin` first on the PATH. Then move the lint line into CI's Tools job and delete the `godot-lint` job and the install note in the development notes.
   - **If we skip it:** One confusing red run on the first gdtoolkit bump.

10. **One trace where the unit never moves crashes every parity report** (`tools/zh_parity/analyze.py:165`, also `:187`)
    - **What this is:** The movement metric looks for the first frame with speed above zero.
    - **Problem:** If the unit is stuck, there is no such frame and `next()` raises `StopIteration`. `report`, `--json` and `--report md` all die, so one bad trace hides every other result. This is likely when a new mover scenario is first tried. Confirmed by running.
    - **Fix:** `next(..., None)` and return early when it is `None` (top speed 0, no start delay), so the row shows FAIL. The early return matters: the median two lines below fails on empty data too. Same at `:187`.
    - **If we skip it:** A stuck unit costs a debugging detour instead of one FAIL line.

11. **Two tools exit 0 after checking nothing** (`tools/check_reference.py:234`, `tools/zh_parity/analyze.py:792-801`)
    - **What this is:** The reference check and the parity report.
    - **Problem:** `check_reference.py ARCHIVE --only` prints `REFERENCE CHECK PASSED 0 rows, 0 differ`. `analyze.py --json` or `--report md` on a mistyped folder prints an empty result and exits 0. The project rule is "fail on zero checks". Confirmed by running.
    - **Fix:** `return 0 if differing == 0 and results else 1`, and print FAILED instead of PASSED for zero rows; in `analyze.py`, exit with "no traces under …" when the trace list is empty.
    - **If we skip it:** A typo reads as a pass.

12. **Ctrl-C on a parity sweep hangs and leaves the games running** (`tools/zh_parity/parity.py:787-792`, `:802-807`)
    - **What this is:** The sweep runs several Zero Hour instances in parallel, each in its own session.
    - **Problem:** Ctrl-C reaches only the parent. It then waits for the running jobs, up to the 900 s timeout, while the games keep their cores. If the children are stopped by hand they exit 143, and the sweep starts each of them again because only exit code 2 counts as final. The wait was confirmed with a fake launcher and SIGTERM (not Ctrl-C itself); the retry by reading.
    - **Fix:** In the sweep, on any exception stop every child group from the pidfiles and re-raise; treat 143 like 2.
    - **If we skip it:** Stopping a sweep means hunting game processes by hand.

13. **Netplay and conformance runs never delete their temp folder** (`tools/run_netplay.sh:5`, `tools/run_conformance.sh:5`)
    - **What this is:** Each run makes a temp folder with logs and a freshly built relay binary, and prints its path on most failures.
    - **Problem:** It is kept on success too. Right now 42 such folders hold 452 MB in the temp directory. macOS clears them after some days, so it is bounded, but it is half a gigabyte of binaries nobody reads.
    - **Fix:** On success, `rm -rf "$out"` when the script made the folder itself (not when `NETPLAY_OUT` was given). Keep it on failure.
    - **If we skip it:** Disk clutter only.

## Nice to have

14. **Quick pushes to one branch each run the full CI** (`.github/workflows/ci.yml`, top level)
    - **What this is:** The workflow has no `concurrency` setting.
    - **Problem:** On 2026-11-12 three runs on `main` started within 17 seconds (43136250586, 43136277934, 43136284107) and all ran to the end, 11 jobs each.
    - **Fix:** A `concurrency` group per branch with `cancel-in-progress`. Whether `main` is included is a choice: cancelling there loses the result for the older commit, and leaving it out means the case above stays as it is. The workflow is also called from `release.yml`, so read GitHub's rules for concurrency in called workflows first; I did not verify that part.
    - **If we skip it:** Slower results on the newest push, nothing worse.

15. **The five static gates are five commands**
    - **What this is:** Lint, warnings, Python checks, shell checks and the public check, each named separately in the instructions.
    - **Problem:** Together they take 17 s one after another. For an agent each is also a separate tool call, and one is easy to forget.
    - **Fix:** One `tools/run_checks.sh` that runs `ensure_venv.sh` once, then starts all five in the background, waits, and prints one PASS or FAIL line each; about 8 s wall time. The venv step must come first: three of the five call it, and two copies building `tools/.venv` at once can break each other. Then the instructions name one command.
    - **If we skip it:** Nothing breaks; the wrap-up stays five steps.

16. **The benchmark does not record the host load** (`tools/run_benchmark.sh`)
    - **What this is:** The milestone prompt asks for the `uptime` load average at start and end in the exit-gate benchmark row.
    - **Problem:** That is a manual step around the script, so it gets forgotten or taken at the wrong moment.
    - **Fix:** Print `uptime` as the first line of the script and again in its existing EXIT trap, so the early exits print it too.
    - **If we skip it:** Rows without load numbers need a rerun.

17. **`check_reference.py` can hang and hides Godot's error** (`tools/check_reference.py:206`)
    - **What this is:** It runs a Godot script to dump Wargrid's definitions.
    - **Problem:** No timeout, so a script error before `quit()` hangs it. When Godot exits non-zero, the traceback shows the command but throws away Godot's own message. Found by reading; not run.
    - **Fix:** `check=False, timeout=300`, and raise with the last lines of stderr on a non-zero exit.
    - **If we skip it:** A slower diagnosis the day a definition is renamed.

18. **The exported builds run the whole suite again** (`.github/workflows/ci.yml:138-148`)
    - **What this is:** CI runs all 808 cases in the editor and again in the exported build, on two platforms.
    - **Problem:** Not a bug. The two exported suite steps are about a third of CI's compute (588 of 1667 job-seconds in run 43411259035) and the exported Windows job is the slowest one. What only the export can show is a file missing from the export and release-build behaviour.
    - **Fix:** A decision, not a recommendation: keep it, or run only the trace cases and the scene tests there. Do findings 5 to 7 first and see whether this still matters.
    - **If we skip it:** Nothing changes.

19. **`run_benchmark.sh` repeats one block three times** (`tools/run_benchmark.sh:11-34`, same shape in `run_profile.sh` and `run_team_match.sh`)
    - **What this is:** Run a Godot script, print its log, check the exit code, check for `ERROR:`.
    - **Problem:** The `ERROR:` check appears seven times in these three scripts, four of them in `run_benchmark.sh`.
    - **Fix:** One small shell function inside `run_benchmark.sh`; about 10 lines less there. The copies in the other two scripts stay.
    - **If we skip it:** Nothing breaks.

## Left out

Six smaller points, all in the parity harness or cosmetic: the boot loop does not retry an HTTP 503 from the game (`parity.py:92`, unconfirmed), sweep resume trusts traces written by older code, a failed sweep job's error text is saved nowhere, the delta column's sign is flipped on `credits_per_min` rows, `probe_patriot.py` is still waiting for its deletion to be approved, and the fixed `sleep 2` before the relay is stopped in the `relay-down` and `relay-term` netplay scenarios (no failure seen so far).

Checked and healthy: `zh_ini.py`, `zh_w3d.py`, `zh_map/`, `audio/`, `playtest_session.py`, `session_usage.py`, `install_godot.py`, `install_export_templates.py`, `compare_replays.py`, `package_release.py`, `release_version.py`, `ensure_venv.sh`, `release.yml`, `godot-release.yml`.

## Verdict

Healthy overall. Fix finding 1 first (two-word changes, and it guards the public repository), then 2 and 3 in one edit of the test runner, then the three speed items 5, 6 and 7.

Lean: about 45 lines and one CI job less (findings 7, 8, 9, 19).

Every code claim in this note was checked a second time by an independent reviewer before it was committed; its corrections are included.

## Review 2026-11-13

The claims behind each fix were checked again on `main` at `b766258`; none of the cited lines had changed. Placed by the user (questionnaire, 2026-11-13):

- Finding 1: done at the review (tracked plus untracked files in all four gates).
- Findings 2 to 17, 19 and the six "left out" points: night package Tighter gates, first in the night lane ([packages](../packages.md#package-notes)). Finding 5: one full run plus a short side-by-side pair instead of one run only. Finding 14: branches only.
- Finding 18: deferred; decided after findings 5 to 7 have landed and CI time is measured again.

## Not checked

- The relay's Go code and `protocol/conformance` (only how CI and the scripts drive them).
- The fixes themselves: none was applied or tested, except the `git grep --untracked` behaviour in finding 1 and the trap order in finding 3 (stand-in script).
- A full four-process suite run with the proposed case deal (findings 5 and 6 are computed from per-case times).
- Windows behaviour of any proposed shell change.
- Whether the agent harness kills a whole process group on timeout (finding 3).
- GitHub's rules for `concurrency` in a called workflow (finding 14).
- The parity harness against the real game: its findings come from reading, unit tests and a fake launcher.
- CI time after the fixes is an estimate scaled from local measurements.
