# Wargrid

A Godot isometric pixel-art RTS preserving Zero Hour's faction identity, strategic choices and pacing, while fixing defects and avoiding inherited performance problems.

**Current state (2026-11-03):** M3 base/economy implementation (`303006b`): builder, reactor/depot/factory, paid FIFO production, power, finite supplies and flying collectors, plus separate base scene/HUD. Headless suite: **97 cases / 101,355 checks / zero failures / exit 0** (95/101,305 at the M3 commit, plus the rendered-probe regression, a snapshot-size ceiling test and a builder-speed change). M2 movement demo and 300-unit workloads remain intact; simulation budgets pass. Final M3 review/checkpoint lives in [M3 verification](docs/reference/m3-verification.md). M3 Linux/macOS/Windows tests and exact movement/economy replay comparisons passed CI. User reported a successful M3 playtest on 2026-11-03. User also confirmed positive M2 playability and no M3 visual issues. Rendered movement benchmark (2026-11-03): terrain draw fix took it from about 3 fps with growing backlog to about 120 fps with no backlog; the benchmark now runs with vsync off and frame p95 is 4.1/6.5 ms (passes the 16.7 ms budget; with vsync on it was 19.6/19.5 ms, which is display pacing; fast Apple M6 only); simulation budgets pass: see [M2 verification](docs/reference/m2-verification.md). Retail parity remains unverified ([verification plan](docs/reference/zero-hour-verification.md)); itemized visible checklist coverage was not supplied. `main` carries M3 plus the benchmark/terrain fix, builder speed change and M4 planning. CI at `c11bf71`: Linux and Windows passed; the macOS runner never started, so macOS evidence for this head is a local trace match against the CI Linux/Windows traces (see [session notes](docs/session-notes.md)), not a CI result.

**M4.1 status (2026-11-04, merged to `main` at `f2c5f9e`): implemented and verified; user playtest done (user statement 2026-11-04, via the online matches; findings open)** (retail idle scan, opponent base defence, rally points, enemy inspect, pile labels, gated `skirmish3v3` benchmark). Suite 160 / 104,024 / 0; benchmarks, CI (Linux, Windows) and macOS trace match pass; rendered movement rerun frame p95 3.6 / 5.2 ms. Evidence: [M4.1 verification](docs/reference/m4.1-verification.md). Open: playtest findings in the M4.1 verification file, retail parity.

**M4 status (2026-11-03, merged to `main`): implemented and verified; every listed M4 exit check has evidence (suite, replays across Linux/Windows/macOS, benchmarks with ledger rows, rendered rerun, reviews, user playtest). Not re-played: the two playtest fixes (HUD layout, attack focus). Next: M4.1 playtest polish, then M5 online spike, toward the long-term target of 3v3 online with friends (blueprint §1 and §7). Retail parity (spot checks S1–S3) is the gate before M7 factions.** Infantry, tank, barracks, health/armor/weapons, attack / attack-move / guard, shared death cleanup, the fixed 48×32 mirrored scenario, a deterministic opponent, victory/draw/restart, the match HUD and exact combat replay are in. Headless suite at the M4 gate: **135 cases / 103,894 checks / zero failures / exit 0** (138 / 103,910 on `main` after the two playtest fixes) (about 12 s; same from outside the repo root and from a fresh copy without `.godot`); Python comparator 6 tests OK; three same-host runs match all three traces (`REPLAYS MATCHED 1200` for movement, economy and combat). Benchmarks: movement `BENCHMARK PASSED 2` and combat `COMBAT BENCHMARK PASSED 3`, every layout inside the headless budget but with only 2–5% margin on two of them ([ledger](docs/reference/performance.md)). Evidence, reviews and rulings: [M4 verification](docs/reference/m4-verification.md). **Manual playability: user playtest 2026-11-03, "Game plays great!"** with two remarks (HUD text overlapped the Produce button; attack focus needed clearer feedback), both addressed afterwards and not yet re-played. Cross-platform replay: CI run 41713005327 (Linux, Windows) plus a local macOS comparison match all three traces. The rendered movement benchmark was rerun after the WorldView changes and passed (frame p95 4.0 / 5.2 ms, zero backlog). **Pending, not passed:** retail parity (all values are source/config-informed, not measured). The scripted six-minute scenario ends at tick 9943 with a win for the scripted human player; it proves determinism and progress, not balance.

## Start here

- [Kickoff](docs/kickoff.md) and [wrap-up](docs/wrapup.md): `/kickoff` and `/wrapup` in Claude Code; portable instructions for any agent.
- [Session notes](docs/session-notes.md): current handoff, pending actions and next step.
- [Kickoff blueprint](Wargrid_Kickoff_Blueprint.md): scope, architecture and milestone gates; historical M0 tasks in §7.1.
- [M0 execution plan](docs/superpowers/plans/2026-11-01-m0-foundation.md): exact interfaces, concrete test cases and ordered verification steps.
- [M1 execution plan](docs/superpowers/plans/2026-11-01-m1-vehicle.md): adopted single-vehicle slice, exact movement/input contracts and acceptance cases.
- [M2 execution plan](docs/superpowers/plans/2026-11-01-m2-groups.md): group movement contracts, implemented benchmarks and remaining acceptance gates.
- Session prompt: none active (a root `prompt.txt` is written when a milestone is kicked off; preparation is not implementation approval). Historical prompts: [M3](docs/m3-prompt.txt), [M4](docs/m4-prompt.txt), [M4.1](docs/m4.1-prompt.txt), [M5](docs/m5-prompt.txt), [M5.1](docs/m5.1-prompt.txt), [M6](docs/m6-prompt.txt).
- [GDScript static checks plan](docs/superpowers/plans/2026-11-05-gdscript-static-checks.md) (small separate task, not a milestone; merged to `main` at `3e3aae0` on 2026-11-06, CI run 42185773054 green on the branch tip): Tasks 1 (`gdlint` gate, `sh tools/run_lint.sh`) and 2 (Godot typing, shadowing, unused-parameter and integer-division warnings as errors, `sh tools/run_warnings.sh`) are done, plus `Simulation`-typed `sim` handles outside the bot code. Task 3 (`unsafe_*` outside snapshot reads) is skipped by the user (2026-11-06): the count found 1,044 game-code findings, over the plan's stop rule of about 500; see session notes.
- [M5.1 design](docs/superpowers/specs/2026-11-05-m5.1-playtest-findings-design.md) (approved 2026-11-05), [plan](docs/superpowers/plans/2026-11-05-m5.1-playtest-findings.md) and [source evidence](docs/reference/m5.1-acquisition.md): the four friend-match findings. Covers the Zero Hour human acquisition rule and retaliation, per-unit group orders, and click and resume hints. Implemented and merged to `main` (`5d86caf`, 2026-11-05); user playtest done 2026-11-05 (queue-label fix, rest good), see [verification](docs/reference/m5.1-verification.md).
- [M6 design](docs/superpowers/specs/2026-11-05-m6-teams-full-map-design.md) (approved 2026-11-05), [plan](docs/superpowers/plans/2026-11-05-m6-teams-full-map.md) and [source evidence](docs/reference/m6-map-and-feel.md): teams, the Ashfall map converted from EA's GPL Twilight Flame source, Zero Hour combat and movement feel, scaling for 3v3. Implemented and merged to `main` (2026-11-05); CI green on Linux and Windows, user 1v1 playtest done (the four logged findings fixed 2026-11-06, not seen on screen). Evidence in [M6 verification](docs/reference/m6-verification.md); known over-budget rows are listed there and in the performance ledger.
- [M7 design](docs/superpowers/specs/2026-11-06-m7-factions-design.md) (approved 2026-11-06) with its [execution plan](docs/superpowers/plans/2026-11-06-m7-factions.md) (planned 2026-11-06, not started; gate 1 at step level, gates 2 and 3 outlines) and [faction evidence](docs/reference/m7-factions.md): USA, China and FRC with signature mechanics, three stop gates.
- [M5 design](docs/superpowers/specs/2026-11-04-m5-online-spike-design.md) and [plan](docs/superpowers/plans/2026-11-04-m5-online-spike.md) (both approved 2026-11-04): lockstep over a Ktor relay on fly.io (relay replaced by a protocol-compatible Go port on 2026-11-05, see [Relay](#relay)); implemented and merged to `main` (Tasks 0–11; repeat friend match on the fixed build deferred by the user, open). Evidence: [M5 verification](docs/reference/m5-verification.md).
- [M4.1 design](docs/superpowers/specs/2026-11-03-m4.1-playtest-polish-design.md) (approved 2026-11-03) and [plan](docs/superpowers/plans/2026-11-03-m4.1-playtest-polish.md): idle scan, base defence, rally points, presentation fixes; implemented and merged, user playtest pending.
- [M3 plan](docs/superpowers/plans/2026-11-02-m3-base-supplies.md), [approved design](docs/superpowers/specs/2026-11-02-m3-base-supplies-design.md), [source evidence](docs/reference/m3-economy.md) and [original kickoff prompt](docs/m3-prompt.txt): adopted M3 contracts and source-supported values; runtime parity remains unverified.
- [M4 plan](docs/superpowers/plans/2026-11-03-m4-combat.md), [approved design](docs/superpowers/specs/2026-11-03-m4-combat-design.md) and [combat evidence](docs/reference/m4-combat.md): implemented, verified and merged; see [M4 verification](docs/reference/m4-verification.md).
- [Relay scaling](docs/reference/relay-scaling.md): proposed cloud-agnostic multi-machine relay for M9, with fly.io and Railway evidence; not implemented.
- [Performance ledger](docs/reference/performance.md): low-end/browser target, derived budgets (5.5× slowdown, measured on a Steam Deck browser run 2026-11-06; rerun with the `wargrid_bench` exports and the user's Steam Deck as a Linux/browser test device, both described there), measurement history; every milestone adds a row.
- [M4 scenario envelope](docs/reference/m4-scenario-envelope.md) and [Task 4/5 test appendix](docs/superpowers/plans/2026-11-03-m4-tests-4-5.md): measured economy/travel/navigation numbers and unrun red-test sketches that prepare M4 Tasks 4, 5 and 7.
- [Zero Hour verification plan](docs/reference/zero-hour-verification.md): level 0 source/config findings plus the automated data check (`tools/check_reference.py`); level 1 (S1–S3, gate before M7) done 2026-11-05 by the [parity harness](docs/reference/zero-hour-parity-harness.md) (`tools/zh_parity/`, headless runs of a native macOS Zero Hour source build; any milestone can measure a mechanic with it). Results and open decision list: [parity harness spike](docs/reference/zero-hour-parity-spike.md).
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
sh tools/run_lint.sh   # needs: uv tool install gdtoolkit==4.5.0
sh tools/run_warnings.sh   # typing, shadowing, unused-parameter and integer-division warnings as errors
python3 -m unittest discover -s tools -p 'test_*.py'
sh tools/run_python_checks.sh   # ruff format + lint, mypy; needs: xargs -n1 uv tool install < tools/requirements-dev.txt
sh tools/run_benchmark.sh
```

Python tooling: ruff and mypy are configured in `tools/pyproject.toml`, pinned in `tools/requirements-dev.txt` (CI installs from the same file). Once per clone, `git config blame.ignoreRevsFile .git-blame-ignore-revs` makes `git blame` skip the formatting-only commits listed there (GitHub reads the file by itself); add the SHA of any future repo-wide reformat.

Profiling (report-only, never gates): `sh tools/run_profile.sh` prints per-zone timings for the benchmark workloads, the scripted skirmish match and a synthetic 196×196 map; the rendered benchmark takes `-- --profile` for the same zones plus a 196×196 leg. Results: [performance spike](docs/reference/performance-spike.md).

Milestone runs follow the reusable [milestone prompt](docs/milestone-prompt.md) (resume record, restart at gates, pre-authorized local commits, gate reviews). Token usage per session for the resume record: `python3 tools/session_usage.py <Claude session or Codex rollout files>`.

CI runs Linux and Windows and compares their replay traces. macOS was dropped from CI on 2026-11-03 because hosted macOS runners repeatedly failed to start within the job timeout; at each milestone gate compare this Mac against a CI run instead: `sh tools/compare_local_traces.sh RUN_ID` (runs the suite with all three trace paths, downloads that run's Linux and Windows traces with `gh`, prints `REPLAYS MATCHED 1200` per scenario).

Local reference check (needs the retail backup, never runs in CI): `python3 tools/check_reference.py "/path/Command & Conquer Generals - Zero Hour.tar.gz"` compares Wargrid's unit, building, weapon and armor values with the pinned Zero Hour INI data; see [Zero Hour verification](docs/reference/zero-hour-verification.md).

Test wrapper imports headlessly before tests, checks exit codes and engine diagnostics, then requires positive completion marker. `GODOT_BIN` accepts one executable path, including spaces. Both wrappers resolve project path from script location.

For separately authorized play: `sh tools/run_game.sh` opens the M4 match (blue is you; controls below); `sh tools/run_game.sh res://scenes/base.tscn` opens M3 base; `sh tools/run_game.sh res://scenes/main.tscn` opens the M2 movement demo (still the project's `run/main_scene`). Both open windows. User subsequently playtested M3 and reported it looked good; detailed coverage is recorded as unspecified. Routine checks stay headless.

Current ordinary suite on `main` (M4.1 merged) passes **160 cases / 104,024 checks**, `TESTS PASSED 104024` (138 / 103,910 before M4.1; 135 / 103,894 at the M4 gate; M3 baseline before M4: 97 / 101,355).

Rendered benchmark, separately authorized (opens a window): `sh tools/run_game.sh res://scenes/movement_benchmark.tscn`. It disables vsync itself (header shows `vsync=off`), uses 10 seconds wall-clock warmup and 60 seconds samples per layout at 1280×720/zoom 0.5, and reports tick timing, frame intervals, engine draw calls and 10-second backlog windows. First valid run 2026-11-03: frame p95 4.1/6.5 ms, zero backlog; the draw-call print has not run in a window yet. Results and budgets: [performance ledger](docs/reference/performance.md).

Historical M1 suite: **32 cases, 1,089 checks, zero failures, exit 0**, `TESTS PASSED 1089`. Same results from outside repo root and fresh scratch copy without `.godot`. Headless 30-frame smoke exited 0 without diagnostics. Eight isolated failure probes exited 1, including abandoned coroutine caught by runner watchdog. See [M1 verification](docs/reference/m1-verification.md) for evidence and review.

[M0 follow-up CI](https://github.com/pdstuber/wargrid/actions/runs/41299222791) passed `7d67481`. M1 commit `7b70a61` passed CI on [m1-vehicle-plan](https://github.com/pdstuber/wargrid/actions/runs/41322464510) and later [m2-groups](https://github.com/pdstuber/wargrid/actions/runs/41466145349), verified 2026-11-02. Both latter runs cover historical M1. [M2 matrix](https://github.com/pdstuber/wargrid/actions/runs/41591616563) at `4be6b7b` passed Linux/macOS/Windows and movement replay comparison, verified 2026-11-03. [M3 matrix](https://github.com/pdstuber/wargrid/actions/runs/41605911340) at `303006b` passed Linux/macOS/Windows and exact movement/economy replay comparison, verified 2026-11-03.

Historical M1 visible smoke is supported by user recording/reports. [M1 measurements](docs/reference/m1-validation.md) record limited headless performance and same-host ARM64/Rosetta replay evidence; these do not establish M2 performance, rendered frame times or cross-OS determinism. User confirmed positive M2 playability and no M3 visual issues; the full visible checklist was not reported item by item. Rendered frame time and backlog were measured 2026-11-03 on a fast development Mac: zero backlog, frame p95 4.1/6.5 ms with vsync off. Budgets for a low-end/browser target are stricter and two are currently exceeded: see the [performance ledger](docs/reference/performance.md). Headless measurements do not establish feel or frame timing. Zero Hour parity remains unverified. Stop at M3; no M4 expansion.

## Relay

The relay is a Go program in `relay/` (net/http + [gws](https://github.com/lxzan/gws), one goroutine per room), protocol-compatible to the M5 Kotlin/Ktor relay it replaced on 2026-11-05 (user decision after the [relay stack spike](docs/reference/relay-stack-spike.md)). Go version: `relay/go.mod`. `tools/run_netplay.sh` and `tools/run_conformance.sh` build it themselves unless `WARGRID_RELAY_BIN` names a binary. Known difference from the Kotlin relay: an invalid tick is checked in the room goroutine, so a reply to a message sent right after it (e.g. a `pong`) can arrive before its `error`; Godot is unaffected.

```sh
(cd relay && go test -race ./... && golangci-lint run)   # unit tests, protocol vectors, lint (config relay/.golangci.yml)
sh tools/run_conformance.sh                               # black-box protocol suite (protocol/conformance), prints CONFORMANCE PASSED <cases>
sh tools/run_netplay.sh match                             # two headless Godot clients through a local relay
```

Spike knobs, all off by default: `WARGRID_SEATS` (seats per room), `WARGRID_BATCH_MS` (one newline-joined message per recipient per interval; the current Godot client cannot read it), plus the test-only `WARGRID_TEST_DELAY_MS` and `WARGRID_SILENCE_MS`. A set but non-integer knob exits with status 2.

Shutdown: on SIGINT (fly's default `kill_signal`) or SIGTERM the relay stops accepting connections, closes lobbies that have not started, lets started matches run for `WARGRID_DRAIN_MS` (default 3500; plus 1 s close grace stays under fly's default 5 s `kill_timeout`), then closes the rest; every room logs `MATCH END`. A second signal exits immediately. Hour-long matches do not survive a deploy; that drain is M9 ([relay scaling](docs/reference/relay-scaling.md)).

### Hosting

fly.io, region `fra`, one shared-cpu-1x 256 MB machine that suspends when idle. Rooms live in memory, so deploy exactly one machine (`--ha=false`; `fly machine list` must show one). The app name stays `wargrid-relay-jvm` (fly apps cannot be renamed) although it now runs the Go relay.

Status: Go relay deployed at `wss://wargrid-relay-jvm.fly.dev/ws` (2026-11-05):
- Deploy took 54 s; image 3.6 MB.
- Godot probe `RELAY WELCOME 64`; warm 55–78 ms.
- Cold start after a stop 1.3–1.8 s; resume after a suspend 0.33–0.51 s.
- Remote `run_netplay.sh match` PASSED.
- Redeployed 2026-11-05 with shutdown drain and crash isolation (`58d13f2`); log shows `relay started … drain=3.5s`, probe `RELAY WELCOME` 1837 ms (cold start). A live drain on fly is not yet observed.

Capacity: a shared vCPU's 6.25 % baseline holds about one 3v3 room ([relay scaling](docs/reference/relay-scaling.md#flyio-vs-railway-measured-2026-11-0405)).

Cost: the user's org is on fly's legacy (free) Hobby plan (user, 2026-11-05). Per [discontinued plans](https://docs.fly.io/about/discontinued-plans) (read 2026-11-05) it has "no monthly subscription fee" and keeps free allowances of "Up to 3 shared-cpu-1x 256mb VMs" and "100 GB North America & Europe" outbound. So the one relay machine costs nothing even when it runs all the time, and 100 GB covers roughly 120 hours a month of 3v3 play (about 220 KiB/s per room in JSON, [M5 findings](docs/reference/m5-online.md#m9-list)).

Without the allowances, list prices ([pricing](https://fly.io/pricing.md)) are $2.53 a month for a started shared-cpu-1x 256 MB in `fra`, and $0.15 per GB of rootfs per month while stopped or suspended. Its "invoices under $5 are waived" applies to new users.

The bill itself was not read.

```sh
fly deploy relay -c $PWD/relay/fly.toml -a wargrid-relay-jvm --dockerfile $PWD/relay/Dockerfile --ha=false
godot --headless --path game -- --probe-relay wss://wargrid-relay-jvm.fly.dev/ws   # prints RELAY WELCOME <ms>
WARGRID_RELAY_URL=wss://wargrid-relay-jvm.fly.dev/ws WARGRID_MATCH_WAIT=600 sh tools/run_netplay.sh match
```

## Browser build

Single-threaded Godot web export (preset `Web`), served by static-web-server as its own fly app `wargrid-web` (`web/`), live at `https://wargrid.pdstuber.dev` since 2026-11-06 (CNAME at Namecheap, Let's Encrypt cert issued by fly; the apex CAA records allow only Let's Encrypt). The image carries brotli/gzip copies made at build time and `Cache-Control: no-cache` (SWS answers `If-Modified-Since` with 304), so a redeploy cannot pair a new `.wasm` with an old `.pck`. No cross-origin isolation headers: they are only needed with threads. The page talks to the same relay over `wss://`.

```sh
sh tools/deploy_web.sh                     # export, then fly deploy; needs explicit approval
fly certs add wargrid.pdstuber.dev -a wargrid-web   # then CNAME wargrid -> wargrid-web.fly.dev
container build -t wargrid-web web         # local image check, after exporting to web/site/
```

Verified by the user 2026-11-06: Safari loads the live site and plays a skirmish against the bot. Unverified: a browser-to-browser match through the relay, a mixed browser and desktop match (floats in WASM versus native), Chrome and Firefox on the live site, and a hidden tab (browsers pause or throttle it, which stalls lockstep for everyone).

## Release

A pushed tag `v<version>` runs [`release.yml`](.github/workflows/release.yml) (plan: [release workflow](docs/superpowers/plans/2026-11-06-release-workflow.md), evidence: [release verification](docs/reference/release-verification.md)):

1. Set `config/version` in `game/project.godot` to `<version>`, commit, push. The tag must equal `v` plus that value: the relay only lets clients with equal versions share a room.
2. Push the tag. The full Tests workflow runs on that commit, then Linux, Windows, macOS and Web are exported and packaged.
3. Approve the `production` Environment. The job deploys the relay (`wargrid-relay-jvm`), checks `/health`, deploys the web build (`wargrid-web`), checks `/health`, then publishes the three desktop zips as a GitHub Release.

A prerelease tag (`v0.7.0-rc.1`) skips both fly deploys and publishes a GitHub prerelease only. A relay deploy ends matches in progress, so release when nobody is playing. Builds are unsigned: macOS needs right-click Open (or `xattr -dr com.apple.quarantine Wargrid.app`), Windows SmartScreen needs More info, Run anyway; each zip's `README.txt` says so.

M5 measurements of the Kotlin relay and the native decision: [M5 verification](docs/reference/m5-verification.md). Findings and M9 list: [M5 findings](docs/reference/m5-online.md). M5 status: implemented and locally verified (Tasks 0–11); reviews, CI on the final tree and the HUD look are done; the repeat friend match on the fixed build is deferred by the user to a later date and remains open (see verification file).

## Local references

- EA source: `/Users/pdstuber/projects/CnC_Generals_Zero_Hour`; research Zero Hour under `GeneralsMD/`.
- User-owned game backups: `/Users/pdstuber/CnC`; leave `.tar.gz` files in place. See installation reference for archive selection.
- Tooling example: `/Users/pdstuber/projects/hells-verdict`; reuse choices are documented in blueprint §3. Specified wrapper and CI patterns adapted; no gameplay code copied.

- OpenRA (GPL-3.0-or-later): `/Users/pdstuber/projects/OpenRA`; reading for M5 lockstep (`OpenRA.Game/Network`: `OrderManager.cs`, `SyncReport.cs`) and M8 bot structure (`OpenRA.Mods.Common/Traits/BotModules`). Reported to have smarter bots; unverified.
- TheSuperHackers patched Zero Hour source: `/Users/pdstuber/projects/GeneralsGameCode`; cross-check for EA source and known retail bugs.
- Native macOS Zero Hour fork (GPL, never vendored): `/Users/pdstuber/projects/GeneralsGameCode-macOS`, local branch `wargrid-parity` (`eb595cfc9`, never pushed); engine for the [parity harness](docs/reference/zero-hour-parity-harness.md).

These sibling projects and backups are research inputs, not future build/test dependencies. Keep original EA source and game assets outside Wargrid. Exact retail executable version, mod status and runtime behavior remain unverified.

## License

Code: GPL-3.0-or-later, see [LICENSE](LICENSE). Not affiliated with or endorsed by Electronic Arts; no EA assets, data or trademarks are included. Licence for original art and audio: undecided.
