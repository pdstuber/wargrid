# Wargrid development notes

Development status, setup, commands and operations for Wargrid's agent-driven workflow; players start at the [README](../README.md).

## Overview

Status: early development. `main` has three factions (USA, China, FRC), teams, three converted maps (Dry Wells, Broken Crown and Ashfall are selectable in the launcher; released in 0.10.0 on 2026-11-09), skirmish against a bot and online play (milestones M0–M7; M7 merged 2026-11-07 at its stop gate, CI green and macOS traces matching; its exit gate waits on the user's playtest; latest release 0.10.0). Per-milestone plans and evidence: [Start here](#start-here).

Developed with AI coding agents (Claude Code). [AGENTS.md](../AGENTS.md), the [blueprint](blueprint.md), `docs/superpowers/` and the [session notes](session-notes.md) are that workflow's plans, decisions and evidence.

## Start here

- [Kickoff](kickoff.md) and [wrap-up](wrapup.md): `/kickoff` and `/wrapup` in Claude Code; portable instructions for any agent.
- [Session notes](session-notes.md): current handoff, pending actions and next step.
- [Blueprint](blueprint.md): scope, architecture and milestone gates; the M0 task plan (old §7.1) is archived in [blueprint archive](reference/blueprint-archive.md).
- [M0 execution plan](superpowers/plans/2026-11-01-m0-foundation.md): exact interfaces, concrete test cases and ordered verification steps.
- [M1 execution plan](superpowers/plans/2026-11-01-m1-vehicle.md): adopted single-vehicle slice, exact movement/input contracts and acceptance cases.
- [M2 execution plan](superpowers/plans/2026-11-01-m2-groups.md): group movement contracts, implemented benchmarks and remaining acceptance gates.
- Current handoffs (2026-11-11): [performance next](perf-next-prompt.txt) is prepared and not started (analysis and four experiments done 2026-11-11: [note](reference/performance-next.md), [plan](superpowers/plans/2026-11-11-performance-next.md); the user starts it with "run docs/perf-next-prompt.txt"); the [overnight queue](overnight-2026-11-09-prompt.txt) is done: the [Zero Hour INI dump tool](zh-ini-dump-prompt.txt) is on `main`, [avoidance spike round 2](avoidance-round2-prompt.txt) is on `spike-avoidance` (no variant met the cap); [round 3](avoidance-round3-prompt.txt), round 4 ([plan](superpowers/plans/2026-11-10-avoidance-round4-spike.md)) and the [pathing timing spike](superpowers/plans/2026-11-10-pathing-timing-spike.md) (branch `spike-pathing`) are done; the movement and pathing milestone comes before the avoidance milestone (blueprint §7); the [native simulation core spike](native-sim-spike-prompt.txt) is done (2026-11-11, CONDITIONAL GO, whole port only; [report](reference/native-sim-spike.md), branch `spike-native-sim` pushed, docs on `main`) (the art lab and the interface and determinism notes are done, 2026-11-10; blueprint §7); the [art lab spike](art-lab-prompt.txt) has an approved [design](superpowers/specs/2026-11-10-art-lab-design.md) and [plan](superpowers/plans/2026-11-10-art-lab-spike.md) (2026-11-10); the lab is done and merged into `main` (`874c6a3`, pushed), the A/B winners are production defaults (`6024e7b`); see the [art lab verification](reference/art-lab-verification.md) resume record. The [sim interface](reference/sim-interface.md) and [determinism rules](reference/determinism-rules.md) notes are done (`6d002c9`). Handoffs live at `docs/<task>-prompt.txt`. Historical prompts: [converted maps playable](converted-maps-prompt.txt) (done 2026-11-09), [M3](m3-prompt.txt), [M4](m4-prompt.txt), [M4.1](m4.1-prompt.txt), [M5](m5-prompt.txt), [M5.1](m5.1-prompt.txt), [M6](m6-prompt.txt), [M7](m7-prompt.txt), and the post-M7 [performance spike prompt](performance-spike-prompt.txt) (done and merged to `main` 2026-11-08, pushed with `4c98b9a`; Steam Deck F re-check done: F 5.5 retained, browser re-measured 5.0-5.2 on the sim rows; gate values from the ledger's T3 table applied in Task 15, ultra and ponytail reviews done; remaining work (scaling sweep, memory proxy, P3 probe, persistent shared grid) is listed in the ledger; write-up and resume record in the [performance ledger](reference/performance.md) and [perf-spike-verification](reference/perf-spike-verification.md)).
- [GDScript static checks plan](superpowers/plans/2026-11-05-gdscript-static-checks.md) (small separate task, not a milestone; merged to `main` at `3e3aae0` on 2026-11-06, CI run 42185773054 green on the branch tip): Tasks 1 (`gdlint` gate, `sh tools/run_lint.sh`) and 2 (Godot typing, shadowing, unused-parameter and integer-division warnings as errors, `sh tools/run_warnings.sh`) are done, plus `Simulation`-typed `sim` handles outside the bot code. Task 3 (`unsafe_*` outside snapshot reads) is skipped by the user (2026-11-06): the count found 1,044 game-code findings, over the plan's stop rule of about 500; see session notes.
- Small tasks of 2026-11-07, both on `main`: [test environment plan](superpowers/plans/2026-11-07-test-environment.md) (`sh tools/deploy_web.sh test`, `-dev` versions on `main`, now `0.11.0-dev`; implemented in `68bcc0a`, deployed five times 2026-11-07/08 per `fly releases -a wargrid-web-test`) and [logo plan](superpowers/plans/2026-11-07-logo.md) (`73b48a4`).
- Converted maps playable (merged to `main` at `17e7f3d` on 2026-11-09, branch deleted; [plan](superpowers/plans/2026-11-08-converted-maps-playable.md), [design](superpowers/specs/2026-11-08-converted-maps-playable-design.md), [handoff](converted-maps-prompt.txt), resume record and every check row in [converted maps verification](reference/converted-maps-verification.md)): launcher map choice offline and online, relay protocol 2 (opaque `settings` and a relay-generated `seed` in `start`; clients check the host's map and agree on starts), Zero Hour's start-spot rule (`StartSpots.assign`), bot collectors per supply center (USA 2, China 3, FRC 5), converter supply center slot near supplies, Cancel and Copy while waiting, Credits panel. **Deployed 2026-11-09 from `main` at `17e7f3d` (user: no release now):** the relay (protocol 2, probe ok) and `wargrid-web-test` (`/health` 200). The production site ran 0.9.0 until the 0.10.0 release the same evening. Waves now target enemy bases and fight units met on the way (`DEFENCE_RADIUS`); pins moved by that fix were re-pinned (match tick 9024 in `run_netplay.sh match`), and `Fm1` is green again with its cap raised to 50,000 (match ends at tick 48,051). Conformance is 41 cases. **Open (M8):** wave size; on Ashfall a seat can still end a match without hitting a building (`china,china` seed 1 seat 1; [more maps](reference/more-maps.md#converted-maps-playable-2026-11-09)). **Known red:** none. **CI:** run 42600101613 green on `17e7f3d` (Linux and Windows; a first run failed on Windows because the Credits test helper assumed LF, fixed in `17e7f3d`). **macOS traces (2026-11-09, `compare_local_traces.sh 42600101613` on `412a16c`, docs-only after `17e7f3d`):** replay, economy, combat 1200 rows each, team 100, netplay 301 matched Linux and Windows. **Playtest done (user, 2026-11-09 evening, Safari, test app):** all three maps offline, Credits panel, Copy button, an online match MacBook vs Mac mini (command latency 185 ms, RTT 34 ms); details in the session notes. **Released 2026-11-09 as 0.10.0** (tag `v0.10.0` on `4f65de3`, release run 42650538019 green, relay and `wargrid-web` deployed, both `/health` 200, hand-written release notes): the task is done. `main` continues at `0.11.0-dev`. Findings, pin derivations and review minors are in the same section.
- [More maps](reference/more-maps.md) (small task, not a milestone; merged to `main` at `4c98b9a` on 2026-11-08, pushed): Dry Wells and Broken Crown converted from EA's GPL map sources; the launcher plays Dry Wells offline and online, while tests, replays and benchmarks keep `skirmish.json`; Tournament Desert's small supply piles are separate 50-box sources ([design](superpowers/specs/2026-11-08-small-supply-piles-design.md), [plan](superpowers/plans/2026-11-08-small-supply-piles.md)). Map choice in the launcher: see the converted maps entry above.
- Sound spike ([design](superpowers/specs/2026-11-08-sound-spike-design.md), [plan](superpowers/plans/2026-11-08-sound-spike.md), [evidence](reference/sound-spike.md), [handoff](sound-spike-prompt.txt), resume record [sound spike verification](reference/sound-spike-verification.md); small task, not a milestone; released in 0.9.0 on 2026-11-08, tag `v0.9.0`; merged to `main` by fast-forward after the user's confirmation, branch deleted): presentation-only audio with generated effects for every weapon, a vocoded announcer for the local player, five credited Ogg music tracks ([credits](../game/audio/CREDITS.md)), three volume sliders plus a Mute button and `M`. CI green on the exported builds and macOS traces matching (run 42511754481 on `251aee8`); the Firefox web check and the offline playtest are done, online is covered by tests only and a friend is playtesting. The cannon is at 0 dB and the Effects bus at -6 dB, set by ear.
- [M5.1 design](superpowers/specs/2026-11-05-m5.1-playtest-findings-design.md) (approved 2026-11-05), [plan](superpowers/plans/2026-11-05-m5.1-playtest-findings.md) and [source evidence](reference/m5.1-acquisition.md): the four friend-match findings. Covers the Zero Hour human acquisition rule and retaliation, per-unit group orders, and click and resume hints. Implemented and merged to `main` (`5d86caf`, 2026-11-05); user playtest done 2026-11-05 (queue-label fix, rest good), see [verification](reference/m5.1-verification.md).
- [M6 design](superpowers/specs/2026-11-05-m6-teams-full-map-design.md) (approved 2026-11-05), [plan](superpowers/plans/2026-11-05-m6-teams-full-map.md) and [source evidence](reference/m6-map-and-feel.md): teams, the Ashfall map converted from EA's GPL Twilight Flame source, Zero Hour combat and movement feel, scaling for 3v3. Implemented and merged to `main` (2026-11-05); CI green on Linux and Windows, user 1v1 playtest done (the four logged findings fixed 2026-11-06, not seen on screen). Evidence in [M6 verification](reference/m6-verification.md); known over-budget rows are listed there and in the performance ledger.
- [M7 design](superpowers/specs/2026-11-06-m7-factions-design.md) (approved 2026-11-06) with its [execution plan](superpowers/plans/2026-11-06-m7-factions.md) (planned 2026-11-06; implemented and merged to `main`; status and open items in the resume record of [M7 verification](reference/m7-verification.md)) and [faction evidence](reference/m7-factions.md): USA, China and FRC with signature mechanics, three stop gates.
- [M5 design](superpowers/specs/2026-11-04-m5-online-spike-design.md) and [plan](superpowers/plans/2026-11-04-m5-online-spike.md) (both approved 2026-11-04): lockstep over a Ktor relay on fly.io (relay replaced by a protocol-compatible Go port on 2026-11-05, see [Relay](#relay)); implemented and merged to `main` (Tasks 0–11; repeat friend match on the fixed build deferred by the user, open). Evidence: [M5 verification](reference/m5-verification.md).
- [M4.1 design](superpowers/specs/2026-11-03-m4.1-playtest-polish-design.md) (approved 2026-11-03) and [plan](superpowers/plans/2026-11-03-m4.1-playtest-polish.md): idle scan, base defence, rally points, presentation fixes; implemented and merged, user playtest done 2026-11-04 (findings open).
- [M3 plan](superpowers/plans/2026-11-02-m3-base-supplies.md), [approved design](superpowers/specs/2026-11-02-m3-base-supplies-design.md), [source evidence](reference/m3-economy.md) and [original kickoff prompt](m3-prompt.txt): adopted M3 contracts and source-supported values; runtime parity remains unverified.
- [M4 plan](superpowers/plans/2026-11-03-m4-combat.md), [approved design](superpowers/specs/2026-11-03-m4-combat-design.md) and [combat evidence](reference/m4-combat.md): implemented, verified and merged; see [M4 verification](reference/m4-verification.md).
- [Relay scaling](reference/relay-scaling.md): proposed cloud-agnostic multi-machine relay for M9, with fly.io and Railway evidence; not implemented.
- [Performance ledger](reference/performance.md): low-end/browser target, derived budgets (5.5× slowdown, measured on a Steam Deck browser run 2026-11-06; rerun with the `wargrid_bench` exports and the user's Steam Deck as a Linux/browser test device, both described there), measurement history; every milestone adds a row.
- [M4 scenario envelope](reference/m4-scenario-envelope.md) and [Task 4/5 test appendix](superpowers/plans/2026-11-03-m4-tests-4-5.md): measured economy/travel/navigation numbers and unrun red-test sketches that prepare M4 Tasks 4, 5 and 7.
- [Zero Hour verification plan](reference/zero-hour-verification.md): level 0 source/config findings plus the automated data check (`tools/check_reference.py`); level 1 (S1–S3, gate before M7) done 2026-11-05 by the [parity harness](reference/zero-hour-parity-harness.md) (`tools/zh_parity/`, headless runs of a native macOS Zero Hour source build; any milestone can measure a mechanic with it). Results and open decision list: [parity harness spike](reference/zero-hour-parity-spike.md).
- [Design questions](questions/README.md): researched wizard questions and their status; answers go to the blueprint and the [design answers](reference/design-answers-2026-11-08.md) (batch A, M7.5 scope and look, performance targets and HUD answered 2026-11-09).
- [Agent instructions](../AGENTS.md): development and verification rules.
- [Installation reference](reference/installation.md): available game data, archive hashes and unresolved version questions.

The blueprint owns design and milestone decisions; milestone execution plans own their detailed implementation contracts. These development notes own current setup and runnable commands. Reference notes record evidence; original behavior does not override deliberate Wargrid fixes.

## Milestone history

Older milestone state paragraphs (M3, M4.1, M4): [development history](reference/development-history.md). Evidence per milestone is in the files listed in [Start here](#start-here).

## Working tree and controls

`game/` contains a custom-drawn desert scene, engine-light simulation and explicit test suites. `tools/` contains launch/test wrappers and replay comparison. Controls of the M2 movement demo and the M3 base scene: [development history](reference/development-history.md).

M4 skirmish controls (on top of the base controls; the skirmish scene pans with the arrow keys only, because A and S are combat keys): 4 places a barracks (1/2/3 as before); E produces infantry at a barracks and a tank at a factory; right-click an enemy unit or building to attack with the selection (mixed infantry and tanks are one group; any unarmed member rejects the whole order with a HUD message); A then left-click ground attack-moves; S stops; Escape or right-click cancels attack-move mode. Victory, defeat or draw shows a Restart button, which rebuilds the whole match.

Shell keys (all scenes, M7 gate 2): F3 toggles the performance overlay (FPS, frame and sim step times, unit and building counts; online also command latency and RTT). Esc with nothing selected or pending opens the pause menu (Resume / Back to main menu / Quit; Quit is absent in the web build). Offline the match pauses while it is open; online the simulation keeps stepping and leaving disconnects this client (a forfeit message is deferred to M9). Not yet played by the user; evidence in [M7 verification](reference/m7-verification-archive-gate2.md#esc-menu-2026-11-07-tree-m7-factions-72b2ec7-plus-uncommitted-apple-m6).

## Setup and commands

Use Godot **4.7.2 stable**. Verified local build: `4.7.2.stable.official.ed1daf0bf`.
CI pins matching Linux archive and SHA-256 from [official release metadata](https://api.github.com/repos/godotengine/godot/releases/tags/4.7.2-stable), fetched 2026-11-01; `tools/install_godot.py` falls back to downloads.godotengine.org when GitHub fails. No extra dependencies.

```sh
godot --version
sh tools/run_tests.sh
WARGRID_TEST_ONLY=test_supply.gd sh tools/run_tests.sh   # only suites/cases whose file or name contains the text, one process, seconds; the full suite stays the gate. The editor import is skipped while nothing under game/ is newer than game/.godot/wargrid-imported (delete it to force one)
WARGRID_TEST_EXE=build/WargridTests.app/Contents/MacOS/Wargrid sh tools/run_tests.sh   # same suite, 4 shards, in an exported "macOS Tests" build (the binary, not the .app)
sh tools/run_lint.sh   # needs: uv tool install gdtoolkit==4.5.0
sh tools/run_warnings.sh   # typing, shadowing, unused-parameter and integer-division warnings as errors
python3 -m unittest discover -s tools -p 'test_*.py'
python3 tools/zh_ini.py dump   # Zero Hour INI blocks to build/zh_ini/inizh.jsonl (gitignored, never committed); needs the local retail archive
sh tools/run_python_checks.sh   # ruff format + lint, mypy, Python tests; needs: uv venv tools/.venv && uv pip install --python tools/.venv/bin/python -r tools/requirements-dev.txt
actionlint   # GitHub workflows, with shellcheck on run: blocks; needs: brew install actionlint shellcheck
sh tools/run_benchmark.sh
sh tools/run_team_match.sh   # three-faction 3v3 bots-only match on Ashfall, pinned cap line at tick 45000, about 2 min
```

Python tooling: ruff and mypy are configured in `tools/pyproject.toml`, pinned in `tools/requirements-dev.txt` (CI installs from the same file). Once per clone, `git config blame.ignoreRevsFile .git-blame-ignore-revs` makes `git blame` skip the formatting-only commits listed there (GitHub reads the file by itself); add the SHA of any future repo-wide reformat.

Profiling (report-only, never gates): `sh tools/run_profile.sh` prints per-zone timings for the benchmark workloads, the scripted skirmish match and a synthetic 196×196 map; the rendered benchmark takes `-- --profile` for the same zones plus a 196×196 leg. Results: [performance spike](reference/performance-spike.md).

Milestone runs follow the reusable [milestone prompt](milestone-prompt.md) (resume record, restart at gates, pre-authorized local commits, gate reviews). Token usage per session for the resume record: `python3 tools/session_usage.py <Claude session or Codex rollout files>`.

CI runs Linux and Windows and compares their replay traces. Workflow `CI` (`.github/workflows/ci.yml`) skips pushes that change only docs or Markdown; Dependabot (`.github/dependabot.yml`) proposes weekly updates for actions, Go modules, pip and Docker images, and `godot-release.yml` opens an issue when a newer Godot stable is out (Godot pins are bumped by hand). macOS was dropped from CI on 2026-11-03 because hosted macOS runners repeatedly failed to start within the job timeout; at each milestone gate compare this Mac against a CI run instead: `sh tools/compare_local_traces.sh RUN_ID` (runs the suite with all three trace paths, downloads that run's Linux and Windows traces with `gh`, prints `REPLAYS MATCHED 1200` per scenario).

Local reference check (needs the retail backup, never runs in CI): `python3 tools/check_reference.py "/path/Command & Conquer Generals - Zero Hour.tar.gz"` compares Wargrid's unit, building, weapon and armor values with the pinned Zero Hour INI data; see [Zero Hour verification](reference/zero-hour-verification.md).

Test wrapper imports headlessly before tests, checks exit codes and engine diagnostics, then requires positive completion marker. `GODOT_BIN` accepts one executable path, including spaces. Both wrappers resolve project path from script location.

For separately authorized play: `sh tools/run_game.sh` opens the launcher (pick factions, then start a skirmish or online match; real play uses Dry Wells, while opening `skirmish.tscn` directly, tests and benchmarks use the 48 × 32 `skirmish.json`, see [more maps](reference/more-maps.md)); `sh tools/run_game.sh res://scenes/skirmish.tscn` opens the M4 match directly (blue is you; controls below); `sh tools/run_game.sh res://scenes/base.tscn` opens M3 base; `sh tools/run_game.sh res://scenes/main.tscn` opens the M2 movement demo. Both open windows. Routine checks stay headless.

The ordinary suite ends with `TESTS PASSED <checks>`; current case and check counts live in the resume record of [M7 verification](reference/m7-verification.md), not here.

Rendered benchmark, separately authorized (opens a window): `sh tools/run_game.sh res://scenes/movement_benchmark.tscn`. It disables vsync itself (header shows `vsync=off`), uses 10 seconds wall-clock warmup and 60 seconds samples per layout at 1280×720/zoom 0.5, and reports tick timing, frame intervals, engine draw calls and 10-second backlog windows. First valid run 2026-11-03: frame p95 4.1/6.5 ms, zero backlog. Results and budgets: [performance ledger](reference/performance.md).

Historical M0-M3 suite counts, CI links and visible-check notes: [development history](reference/development-history.md).

## Relay

The relay is a Go program in `relay/` (net/http + [gws](https://github.com/lxzan/gws), one goroutine per room), protocol-compatible to the M5 Kotlin/Ktor relay it replaced on 2026-11-05 (user decision after the [relay stack spike](reference/relay-stack-spike.md)). Go version: `relay/go.mod`. `tools/run_netplay.sh` and `tools/run_conformance.sh` build it themselves unless `WARGRID_RELAY_BIN` names a binary. Known difference from the Kotlin relay: an invalid tick is checked in the room goroutine, so a reply to a message sent right after it (e.g. a `pong`) can arrive before its `error`; Godot is unaffected.

```sh
(cd relay && go test -race ./... && golangci-lint run)   # unit tests, protocol vectors, lint (config relay/.golangci.yml)
sh tools/run_conformance.sh                               # black-box protocol suite (protocol/conformance), prints CONFORMANCE PASSED <cases>
sh tools/run_netplay.sh match                             # two headless Godot clients through a local relay
```

Spike knobs, all off by default: `WARGRID_SEATS` (seats per room), `WARGRID_BATCH_MS` (one newline-joined message per recipient per interval; the current Godot client cannot read it), plus the test-only `WARGRID_TEST_DELAY_MS` and `WARGRID_SILENCE_MS`. A set but non-integer knob exits with status 2.

Shutdown: on SIGINT (fly's default `kill_signal`) or SIGTERM the relay stops accepting connections, closes lobbies that have not started, lets started matches run for `WARGRID_DRAIN_MS` (default 3500; plus 1 s close grace stays under fly's default 5 s `kill_timeout`), then closes the rest; every room logs `MATCH END`. A second signal exits immediately. Hour-long matches do not survive a deploy; that drain is M9 ([relay scaling](reference/relay-scaling.md)).

Logs (`fly logs -a wargrid-relay`): one line per connection open/close, room created, seat joined, match start and end; no client IPs. No metrics endpoint: Prometheus metrics were built and removed again on 2026-11-08 (the relay is plain WebSocket forwarding; they come back from git history if the game shows problems); fly's built-in machine and proxy metrics remain on [fly-metrics.net](https://fly-metrics.net). Suspend: the proxy suspends the machine when it sees no requests; internet scanners that found the new domain through Certificate Transparency (126 404s in its first 40 min) resume it, in about 0.2–0.3 s. A metrics scrape did not keep it awake. Details in the [relay metrics design](superpowers/specs/2026-11-08-relay-metrics-design.md#result-2026-11-08).

### Hosting

fly.io, region `fra`, one shared-cpu-1x 256 MB machine that suspends when idle. Rooms live in memory, so deploy exactly one machine (`--ha=false`; `fly machine list` must show one). App `wargrid-relay` behind `wss://relay.pdstuber.dev/ws` since 2026-11-08 (CNAME at Namecheap, Let's Encrypt cert issued by fly). The old app `wargrid-relay-jvm` (named before the Go port; fly apps cannot be renamed) was destroyed after the 0.7.0 release (2026-11-08), so v0.6.0 clients can no longer play online.

Status: 2026-11-08: deployed as `wargrid-relay`; `https://relay.pdstuber.dev/health` ok, probe `RELAY WELCOME 77`. Release 0.7.0 (run 42472020039) deployed it through the workflow with the new deploy token; probe `RELAY WELCOME 71`. Release 0.8.0 (run 42480130047) redeployed relay and web; both `/health` answer 200. First deploy log of the old `wargrid-relay-jvm` app: [development history](reference/development-history.md).

Capacity: a shared vCPU's 6.25 % baseline holds about one 3v3 room ([relay scaling](reference/relay-scaling.md#flyio-vs-railway-measured-2026-11-0405)).

Cost: the user's org is on fly's legacy (free) Hobby plan (user, 2026-11-05). Per [discontinued plans](https://docs.fly.io/about/discontinued-plans) (read 2026-11-05) it has "no monthly subscription fee" and keeps free allowances of "Up to 3 shared-cpu-1x 256mb VMs" and "100 GB North America & Europe" outbound. So the one relay machine costs nothing even when it runs all the time, and 100 GB covers roughly 120 hours a month of 3v3 play (about 220 KiB/s per room in JSON, [M5 findings](reference/m5-online.md#m9-list)).

Without the allowances, list prices ([pricing](https://fly.io/pricing.md)) are $2.53 a month for a started shared-cpu-1x 256 MB in `fra`, and $0.15 per GB of rootfs per month while stopped or suspended. Its "invoices under $5 are waived" applies to new users.

The bill itself was not read.

```sh
fly deploy relay -c $PWD/relay/fly.toml -a wargrid-relay --dockerfile $PWD/relay/Dockerfile --ha=false
godot --headless --path game -- --probe-relay wss://relay.pdstuber.dev/ws   # prints RELAY WELCOME <ms>
WARGRID_RELAY_URL=wss://relay.pdstuber.dev/ws WARGRID_MATCH_WAIT=600 sh tools/run_netplay.sh match
```

## Browser build

Single-threaded Godot web export (preset `Web`), served by static-web-server as its own fly app `wargrid-web` (`web/`), live at `https://wargrid.pdstuber.dev` since 2026-11-06 (CNAME at Namecheap, Let's Encrypt cert issued by fly; the apex CAA records allow only Let's Encrypt). The image carries brotli/gzip copies made at build time and `Cache-Control: no-cache` (SWS answers `If-Modified-Since` with 304), so a redeploy cannot pair a new `.wasm` with an old `.pck`. No cross-origin isolation headers: they are only needed with threads. The page talks to the same relay over `wss://`. Playtest builds go to the separate app `wargrid-web-test` and share that relay; the relay only puts equal build strings in one room, so `main` carries a `-dev` version between releases.

```sh
sh tools/deploy_web.sh                     # export, then fly deploy; needs a release version and explicit approval
sh tools/deploy_web.sh test                # same, to https://wargrid-web-test.fly.dev; needs a -dev version and explicit approval
fly certs add wargrid.pdstuber.dev -a wargrid-web   # then CNAME wargrid -> wargrid-web.fly.dev
container build -t wargrid-web web         # local image check, after exporting to web/site/
```

Verified by the user 2026-11-06: Safari loads the live site and plays a skirmish against the bot. Verified by the user 2026-11-08 (perf-spike branch, `b12e821`): a mixed match through the live relay, WASM build in a browser on a MacBook Air against the native macOS build on a Mac mini, about 10 minutes with fighting on both sides, no desync (floats in WASM versus native: closed for macOS arm64). Unverified: a browser-to-browser match through the relay, Chrome and Firefox on the live site, and a hidden tab (browsers pause or throttle it, which stalls lockstep for everyone).

## Release

A pushed tag `v<version>` runs [`release.yml`](../.github/workflows/release.yml) (plan: [release workflow](superpowers/plans/2026-11-06-release-workflow.md), evidence: [release verification](reference/release-verification.md)):

1. Set `config/version` in `game/project.godot` to `<version>`, commit, push. The tag must equal `v` plus that value: the relay only lets clients with equal versions share a room.
2. Push the tag. The full CI workflow runs on that commit, then Linux, Windows, macOS and Web are exported and packaged.
3. Approve the `production` Environment. The job deploys the relay (`wargrid-relay`), checks `/health`, deploys the web build (`wargrid-web`), checks `/health`, then publishes the three desktop zips as a GitHub Release.
4. Bump `config/version` on `main` to the next `-dev` version (`0.11.0-dev`), so local and test builds stay out of production rooms.

A prerelease tag (`v0.7.0-rc.1`) skips both fly deploys and publishes a GitHub prerelease only. A relay deploy ends matches in progress, so release when nobody is playing. Builds are unsigned; the first-start steps for players are in the [README](../README.md#play). Each zip's `README.txt` says so and links the source for its tag. Re-running a failed release redeploys both fly apps, which ends live matches again.

M5 measurements of the Kotlin relay and the native decision: [M5 verification](reference/m5-verification.md). Findings and M9 list: [M5 findings](reference/m5-online.md).

## Local references

- EA source: `~/projects/CnC_Generals_Zero_Hour`; research Zero Hour under `GeneralsMD/`.
- User-owned game backups: `~/CnC`; leave `.tar.gz` files in place. See installation reference for archive selection.
- Tooling example: `~/projects/hells-verdict`; reuse choices are documented in blueprint §3. Specified wrapper and CI patterns adapted; no gameplay code copied.

- OpenRA (GPL-3.0-or-later): `~/projects/OpenRA`; reading for M5 lockstep (`OpenRA.Game/Network`: `OrderManager.cs`, `SyncReport.cs`) and M8 bot structure (`OpenRA.Mods.Common/Traits/BotModules`). Reported to have smarter bots; unverified.
- TheSuperHackers patched Zero Hour source: `~/projects/GeneralsGameCode`; cross-check for EA source and known retail bugs.
- Art-direction archive (not a git repo, not vendored): `~/projects/wargrid-art-archive/`; interview images, GPT's QA images, validation, provenance and handoff notes from the 2026-11-09 art-direction pack. The kept parts are in `docs/art-direction/`; see blueprint §2.
- Native macOS Zero Hour fork (GPL, never vendored): `~/projects/GeneralsGameCode-macOS`, local branch `wargrid-parity` (`eb595cfc9`, never pushed); engine for the [parity harness](reference/zero-hour-parity-harness.md).

These sibling projects and backups are research inputs, not future build/test dependencies. Keep original EA source and game assets outside Wargrid. Exact retail executable version, mod status and runtime behavior remain unverified.
