# Session notes

Working handoff record, not authoritative design. Follow [kickoff](kickoff.md) and [wrap-up](wrapup.md). Setup lives in [README](../README.md); design in [blueprint](../Wargrid_Kickoff_Blueprint.md).

## Session

2026-11-05 **M5.1 implemented on `m5.1-findings`, not merged; user playtest done (2026-11-05: "I just did a playtest, the rest look good", plus a production-queue label fix `294e20e`).** Tasks 0-9 done except the playtest and the merge. Branch pushed to origin through `8588f85`; local-only after that: the merge of `main` (relay hardening `c5205da`) and later doc commits. Verified: suite 220 cases / 104,551 checks / 0 failures on the merged tree; CI run 42017965845 green on `8588f85` (relay, relay-lint, Linux, Windows, compare-replays); `compare_local_traces.sh` MATCHED (netplay 281); rendered benchmark rerun passed (open, dense); relay `go test -race`, lint, conformance 33 and all nine netplay scenarios on the merged tree. Opus review (4 important findings fixed) and `/ponytail-review` done. Not verified: hint ring, paused label and resume outline on screen. Evidence and rulings: [M5.1 verification](reference/m5.1-verification.md).

2026-11-05 relay hardening **merged to `main`** (merge `58d13f2`, pushed) and deployed to fly `wargrid-relay-jvm`: drain on SIGINT/SIGTERM, per-room crash isolation, fail-fast config, `log/slog`. Verified on the final tree: `go test -race`, golangci-lint 0 issues, `run_conformance.sh` 33 cases, `run_netplay.sh` relay-term, relay-down and match passed; on fly the new binary logs `relay started … drain=3.5s` and the probe got `RELAY WELCOME`. Live drain on fly not yet observed (the machine was suspended at deploy). Detail below.

2026-11-05 Zero Hour parity harness spike **merged to `main`** (`c7497cc`, since pushed): docs, `tools/zh_parity/` and one CI line, no game code; level 1 done by harness, decision list open ([spike](reference/zero-hour-parity-spike.md)). M5.1 (branch `m5.1-findings`, separate session) can measure Zero Hour mechanics such as retaliation with the [parity harness](reference/zero-hour-parity-harness.md).

2026-11-05 relay stack spike between milestones, then the relay was **replaced by a Go port on `main`** (`4f38ce8`, pushed; `main` = `origin/main`). CI run 41950491714 green on `4f38ce8` (relay, relay-lint, Linux, Windows, compare-replays). Locally on the final tree: relay `go test -race`, golangci-lint 0 issues, `run_conformance.sh` 33 cases, all nine `run_netplay.sh` scenarios passed; fly `wargrid-relay-jvm` redeployed from that tree (remote match passed). Evidence: [relay stack spike](reference/relay-stack-spike.md), host comparison in [relay scaling](reference/relay-scaling.md#flyio-vs-railway-measured-2026-11-0405).

2026-11-04 M5 online spike **implemented and merged to `main`** (merge `55beae4`, pushed; `main` = `origin/main`). Tasks 0–11 done; exit gate met except the repeat friend match on the fixed build, which the user deferred to later (open, not met). Verified on `bba5482`: editor suite 192 cases / 104,432 checks / 0 failures, benchmark exit 0 (lockstep p99 0.060 ms vs 0.55), relay `gradlew test`, nine `run_netplay.sh` scenarios, CI green (relay, Linux, Windows, compare-replays), `compare_local_traces.sh` MATCHED (netplay 364), rendered benchmark passed (frame p95 4.3 / 5.9 ms, about 0.7 ms above M4.1, one run), Grok review and `/ponytail-review` done; HUD look is a user statement ("that looks fine"). Findings: [M5 findings](reference/m5-online.md); evidence: [M5 verification](reference/m5-verification.md). Earlier: M4.1 merged at `f2c5f9e` (playtest declared done by the user 2026-11-04, findings open); M3 detail in [M3 verification](reference/m3-verification.md), M4 in [M4 verification](reference/m4-verification.md).

## Pending user action

- M5.1: approve push of the unpushed commits (CI reruns on the final tree) and the merge of `m5.1-findings` into `main`.
- M5.1 parity item open: Zero Hour joined a Ranger at 70 units, Wargrid radius is 48; bisect with `retaliate_ranger` before any change. Return-home timing unmeasured.
- M4.1 playtest findings (user, 2026-11-04) are open; to be tackled outside M5, see [M4.1 verification](reference/m4.1-verification.md). Deferred minors: BM7 lane pin, R5 other-command coverage.
- `main` and `origin/main` at the relay hardening merge (`58d13f2`) plus doc follow-ups. Local branches `gpl-license`, `m5-online`, `spike-relay-improvements` (also on origin) and older milestone branches are merged and can be deleted (not done).
- Global agent rules: grok removed from the review route in `~/dotfiles/config/agents/AGENTS.md` (user, 2026-11-05); that dotfiles change is uncommitted and is the user's to commit. `grok` can be uninstalled.
- Spike harness (other ports, load driver, raw results) copied to `~/projects/wargrid-relay-spike`, outside git; delete when no longer wanted.
- M5 open items: repeat the friend match (macOS vs Windows on the fixed build) later; real fly bill later (user: "fine for now"); Railway check done in the 2026-11-05 [relay stack spike](reference/relay-stack-spike.md) (comparison in [relay scaling](reference/relay-scaling.md#flyio-vs-railway-measured-2026-11-0405); sleep/wake still untested); suspend during a live match unobserved.
- Choose a licence for original art and audio (code is GPL-3.0-or-later).
- Check in a fresh session whether the project skill settings shrank the skill listing (baseline 48,567 bytes; revert if not).

## Deferred experiments and research

- Relay scaling (user, 2026-11-04): the single-machine `--ha=false` relay is accepted for M5 only; user is not happy with it as the long-term approach. Placed in M9 (user, 2026-11-04): cloud-agnostic multi-machine relay (no provider-only routing, so no `fly-replay`), fly.io stays the host for now. Railway evaluation and the synthetic-room load test were done in the 2026-11-05 [relay stack spike](reference/relay-stack-spike.md): about one 3v3 room per shared-cpu-1x machine at the 6.25 % CPU baseline; M9 design inputs (batching, compact command log, Elixir-style room patterns) recorded there. Proposal review and options: [relay scaling](reference/relay-scaling.md).
- Project goal (user, 2026-11-04): also an architecture exploration. Over-engineering is acceptable; explore very scalable architectures from the start, from M6 on. M5 design stays as approved.
- Source/config-supported economy and combat values remain RETAIL_UNVERIFIED; departures stay explicit in reference/design notes.
- AI moods (Sleep, Alert 1.1, Aggressive 1.5) deferred to M8 bots (user, 2026-11-03).
- Retail map sizes vs our 48×32 cells: check before choosing the M6 full-scale map.
- Runtime parity harness: adopted 2026-11-05 ([spike](reference/zero-hour-parity-spike.md)); counts as level 1 with the source-build caveat; open: its decision list and the Chinook supply scenario. Decided 2026-11-05: M5.1 adds a retaliation parity scenario at Task 9; the combat-feel list (edge-to-edge range, Ranger cadence 4/4/22, tank splash, start delay and turning) and the Chinook scenario go to M6 planning, because range and cadence change every weapon number and would invalidate the skirmish and netplay pins and BM6 again.
- Retail `ForceIdleMSEC` INI value unread (code default 1 frame); `stop` re-acquire delay uses the existing 15-tick stagger instead.

## Next action

**Next session:** M5.1 push, CI and merge to `main` on approval. Then M6 planning (it also takes the combat-feel parity list). Still open separately: the repeat macOS-vs-Windows friend match on the Go relay.

**M4 complete and merged into local `main` (2026-11-03).** Evidence: [M4 verification](reference/m4-verification.md). Process changes adopted on `main`: [milestone prompt](milestone-prompt.md), [workflow retrospective](reference/2026-11-03-milestone-workflow-retrospective.md). Roadmap re-aimed at the long-term target (3v3 online with friends against bots, USA/China/GLA, Twilight-Flame-like full-scale map): blueprint §1, §7, §11, §14.

- **M5 online spike: merged to `main` (2026-11-04), repeat friend match open.** Still unobserved/owed: M9 list in [M5 findings](reference/m5-online.md) (dynamic delay first: command p95 ~190-205 ms against the 250 ms budget at a 4-tick delay). Historical handoff `prompt.txt`.
- **M4.1 implemented and merged to `main` (2026-11-04); user declared the playtest done 2026-11-04, findings open (see M4.1 verification).** Formerly next: user playtest (rally, enemy info, pile labels, opponent defence, 5–10 minute match). Evidence: [M4.1 verification](reference/m4.1-verification.md). The five items below are the original playtest notes, now all implemented:
  1. **Rally point per producer.** Zero Hour production exits read a rally point (`AIPlayer.cpp` 500/680, source revision `0a05454`). Today new units stay on the producer's perimeter, which also stalls production at about 8 infantry and 11 tanks. Touches production, a new command and the replay traces.
  2. **Opponent too passive.** Guard units only fire inside weapon range and never move, and the opponent never defends its base. Proposed: base defense (the same rule the scripted human needed in M4 Task 7) and reaction a bit beyond weapon range; check Zero Hour's idle acquisition range in source before choosing the distance. Changes the match outcome, so the scenario pin (tick 9943) must be recalibrated.
  3. **Selecting an enemy should show info.** `WorldView.pick_entity` only returns player 1 units; add read-only kind, owner and HP for enemy objects.
  4. **Collectors on one supply pile are hard to read.** One dock per pile is M3 design (Zero Hour docking); add visibility: pile label "docked 1 · waiting 2", collector state when selected.
  5. **"4: barracks" next to "S: stop".** HUD wording slip: base line says "1/2/3 build", the skirmish appends "4: barracks" elsewhere; make it one "1/2/3/4 build".
- **After M5:** M6 teams and full-scale map, M7 China and GLA (gate: Zero Hour spot checks S1–S3 run or deferred), M8 bots, M9 3v3 online.

## 2026-11-05 — Relay shutdown and crash isolation

- User request (branch `spike-relay-improvements`): signal handling and a production-readiness pass. Plan: `~/.claude/plans/i-ve-created-a-branch-declarative-wilkes.md`.
- Facts checked: fly sends SIGINT by default, `kill_timeout` 5 s default, 300 s max (docs.fly.io/reference/configuration); `http.Server.Shutdown` does not wait for WebSockets, so the registry tracks rooms. Old fly logs show the previous binary simply "exited with signal SIGINT".
- Built: on the first signal the listener closes, unfilled lobbies close, started matches run `WARGRID_DRAIN_MS` (3500, user: "4s is fine", lowered so drain + 1 s close grace stays under 5 s), then forced close; every room logs `MATCH END`; a second signal exits at once. `recover` per room plus gws `Recovery`; `room.post` never blocks on a dead room; non-integer env knobs exit 2. Tests in `relay/shutdown_test.go` (mutation-checked); `run_netplay.sh relay-term` now asserts end reason, timing, exit 0 and `MATCH END`.
- Not done (named, M9 or no payoff now): join rate limit, connection caps, bounded outbound queues, metrics endpoint, close frame for sockets that never sent `hello`. A second SIGINT from a non-interactive `sh` background job is ignored (shell starts it with SIGINT ignored; Go restores that); SIGTERM verified.

## 2026-11-05 — Zero Hour parity harness spike

Branch `spike-parity` (docs, `tools/zh_parity/`, one CI line; no game code). Upstream source cannot build on macOS and Wine fails under Rosetta for Linux in Apple `container`; the native fork `../GeneralsGameCode-macOS` (local branch `wargrid-parity`, `eb595cfc9`, never pushed) builds with Command Line Tools and runs headless and silent. User decisions ("go with your recommendations"): route adopted, counts as level 1 (M7 gate met, source-build caveat), harness in `tools/zh_parity/` for any milestone ([how-to](reference/zero-hour-parity-harness.md)), container/MinGW/Wine leftovers removed. Measured (source build): cruise speeds, turn rates, Ranger/Dozer acceleration match INI within 0.15% (Crusader lurches on its first frame); Crusader 60-frame interval matches; range is edge-to-edge (stationary maxima 122 and 183, +22%), Ranger burst 4/4/22 (time-to-kill +12%), tank shells splash neighbouring infantry, orders start moving after 3 frames. Open: the [decision list](reference/zero-hour-parity-spike.md#decision-list-proposal-for-the-next-combat-feel-work); Chinook supply scenario delivers no money (cause unknown). Rule learned: always `-headless -noaudio` (a windowed run blasted sound).

## 2026-11-05 — Relay stack spike and Go relay

- User request: compare relay stacks (Go + gws, Rust + Axum, current Kotlin, Elixir chosen as fourth) on performance, resources, fly fit, ease and maintenance, considering M9. Six builds passed one 35-case black-box suite; local Apple-container benchmarks, fly and Railway trial deployments, all temporary apps deleted. Findings and numbers: [relay stack spike](reference/relay-stack-spike.md).
- Key findings: fly's shared-CPU burst balance does not accrue while suspended, so a 3v3 room must fit the 6.25 % baseline (Go/Rust/Elixir about 5–6 % per room, Kotlin 23 % and throttled); the Kotlin/Ktor CIO relay burned CPU while idle (cause unverified); a raw per-frame reconnect log is infeasible on 256 MB; Railway works but adds about 28 ms per round trip from Bavaria.
- User decisions: replace the relay with the go-idiomatic port in the repo and on fly; keep the conformance suite; add golangci-lint; remove grok from reviews. User's fly org is on the legacy (free) Hobby plan (allowances in README Relay section).
- Mistakes caught during the day: Rust ports lacked `TCP_NODELAY` (hid write cost), first harness CPU windows were skewed by 2 s `container stats` calls, a fill run hung on a missing deadline, a commit message overstated the CPU gain (amended before push). The documented grok command hangs headless; replaced by a fresh-context reviewer.

## 2026-11-04 — M5 human matches

- Friend match (macOS editor run vs friend's Windows 11 export, Kulmbach): no desync, command p95 96.0 / 84.6 ms, but ticks ran at about 57/s: `online_main.gd` catch-up ran 2 ticks per frame permanently. Fixed with a bounded per-frame credit (`f82114f`, test first) plus the false "Connection to relay lost" after match end.
- Mac mini vs MacBook Air M1 at 30 Hz: 6,001 ticks, about 1.55 KB/s per client, command p95 191.4 / 205.0 ms (n=30 / 13), RTT p95 41.9 / 33.7 ms. End-screen text not confirmed by the user.
- User decisions: step 2 used two Macs; repeat friend match deferred ("confident they work"); play feedback filed as informal M4.1 playtest notes in [M4.1 verification](reference/m4.1-verification.md) (formal playtest still pending). Unreproduced: attack-move leaves units in the base standing when part of the army is engaged.
- Fly: idle autosuspend observed 71 s to about 7 min after last activity; resume 193-463 ms; no relay errors in the logs. AppCDS mapping unverified.

## 2026-11-04 — Relay scaling review

- Reviewed the user's rendezvous-hashing proposal (docs only, no relay code changed). User decisions: multi-machine relay and reconnect go into M9 (option a, not a separate milestone); fly.io stays the host for now; design is cloud-agnostic. Railway evaluation stays in M5 Task 11 (Claude's recommendation after the user chose to stay on fly; hands-on deploy needs a Railway account and approval). Recommended routing (app redirect, static worker list, client RTT placement, relay-side drain) is Claude's proposal, not decided. Evidence and unverified items: [relay scaling](reference/relay-scaling.md).

## 2026-11-04 — M5 Tasks 8–9

- Lockstep benchmark passes; relay deployed to `wargrid-relay-jvm` (fra, one machine, suspend). Native GraalVM build failed 4 times and was dropped (user); native app destroyed (user approved). Cold p50 about 3.2 s, manual suspend resume about 0.5 s, warm 78 ms, memory about 100 MiB (peak 128). Task 9 gate review rulings and unverified items: [M5 verification](reference/m5-verification.md).

## 2026-11-04 — M5 design and plan

- User intent: the spike shows how hard multiplayer is, as the thin foundation M9 builds on (not throwaway). Target: user and two friends (all in Bavaria) vs three bots over the internet; lobby later. User is a backend developer; richer fly.io services are fine in deploy config, but routing, discovery and placement stay cloud-agnostic (user, 2026-11-04).
- User decisions: approach A (dumb relay, clients stamp ticks) plus relay-owned membership, version check, desync report and tool, automated failure tests (after user recalled Generals online as unreliable; source shows P2P UDP with firewall probing and 42 "mismatch" fix commits in GeneralsGameCode `afc2a103f`); Kotlin + Ktor (CIO, required for GraalVM per ktor.io/docs/graalvm.html) with a GraalVM cold-start experiment; latency ≤ 250 ms p95 through fly `fra`; lockstep overhead 10% of a tick (0.55 ms p99 dev); exported builds in scope; friend match is a hard gate; implementation by Sonnet 5.5 medium with Opus preflights.
- Done: `flyctl` v0.5.3 installed (Homebrew), `fly auth login --code` completed from the user's phone. Godot probe: plain `JSON.stringify` drops float precision (`0.30000000000000004` → `0.3`); `JSON.parse_string` returns ints as floats; both handled in the plan. One builder check on the design (macOS CI dropped, offline path, cross-OS desync diff, budgets) folded in.
- Not done: no implementation, no tests run, no export templates installed, no fly app created or deployed. Unverified: export-template determinism vs editor binary, `--script`/`--headless` in release templates, Ktor WebSockets in a native image (all Task 1 or Task 9).

## 2026-11-04 — M4.1 exit gate

- Done: Tasks 4–9. Grok branch review (0 bugs) fixed marker kinds, idle enemy mode, O4 assertion, gated budget failure; `/ponytail-review` Ship. Pushed with approval; CI green, macOS traces matched, rendered movement rerun passed. User could not playtest today; window use for the rendered rerun was approved.
- Not verified: rally marker, enemy line and pile labels were never viewed by a person; reactor-marker and O4 assertions were not seen red.
- Deferred minors: BM7 lane pin, R5 other-command coverage.

## 2026-11-03 — M4.1 Tasks 2–3 and scan-rule changes

- Done: controller + vision (Task 2), scan at vision radius (Task 3), gate review of Task 3. Local suite 146 / 103,948 / 3 known red, exit 1; no CI, no rendered run, no benchmark rerun after the keep-target change.
- User decisions: removed the radius drop after checking Zero Hour (`AIAttackState::update`) and OpenRA (`AttackMoveActivity`): neither drops by distance. `stop` delays re-acquire to the next phase tick (Zero Hour idle `resetNextMoodCheckTime`; OpenRA scan interval 3–8). Unreachable scan target is dropped (reviewer finding).
- Mistake: first stall analysis came from design text only; user asked for source check, which changed the design. Review ran on the pre-change commit, so its stall advice was superseded.
- Open: test gaps and `_chases` snapshot question in the resume record; ponytail review and substantive review still due at the exit gate.

## 2026-11-03 — M4.1 design and plan

- User: opponent felt passive because their units stood still while user raided before tick 5400. User priority: stay close to the real game; current map acceptable for M4.1.
- Source (EA `0a05454`, root `INIZH.big` pinned hash): idle and attack-move scan at vision × `GuardOuterModifierHuman 2.2` / `GuardOuterModifierAI 1.333`; Ranger vision 100, Crusader 150. User chose retail values as-is, both sides; moods deferred to M8 ("as long as we add moods later").
- User decisions: rally replaced by setting a new one (no clear); presentation mockups approved; approach A (one milestone, simulation first); design approved.
- User cloned TheSuperHackers `GeneralsGameCode` into `../GeneralsGameCode` (head `afc2a103f`): cited scan functions differ only cosmetically from EA source. Deferred research: an instrumented build for S1–S3 runtime parity (macOS buildability unchecked).
- Deferred to M6: compare retail map sizes with 48×32 before choosing the full-scale map.
- Not done: nothing implemented, no tests run; `prompt.txt` (M4) moved to `docs/m4-prompt.txt`. Committed on `main` as `daa5575`.
- User decided: Wargrid code is GPL-3.0-or-later ("I see nothing speaking against this"); `LICENSE` added, AGENTS porting rule, blueprint §12 and README updated (`dde91fa`, on `main`; AGENTS reworded per user: own code by default, source read for ideas, ports only as exception). Open: licence for original art/audio. User also cloned `../OpenRA` (GPL-3.0-or-later, head `9636b63eae`): read `OpenRA.Game/Network` before planning M5; bot modules are M8 reading. "Smarter bots" is hearsay, unverified.

## 2026-11-03 — Performance open points and real-game verification

- Rendered benchmark was broken since M2 (untyped `[]` to typed `set_state`); fixed with regression `test_rendered_probe_ticks`, suite then 96 cases / 101,306 checks / exit 0 (now 97 / 101,355 with later tests and the builder-speed change; see below). Corrected rerun completed but **fails the frame budget** (about 3 fps, p95 320/340 ms; backlog grows). Simulation cost fine. Headless probe shows script-side `_draw` is 3–5 ms, so cost is renderer-side; rendered probe confirmed the per-tile terrain loop (about 8,200 canvas commands) costs about 80 ms/frame vs about 2 ms for a one-polygon-plus-multiline variant. Fix applied (`WorldView._draw_terrain`); real benchmark rerun: ~120 fps, zero backlog, frame p95 19.6/19.5 ms vs 16.7 budget (marginal fail, tail likely tick frames, unprofiled). Builder speed now 1.2 (user directed speed from `Locomotor.ini` ÷25; infantry 0.8/tank 1.2 go into M4 definitions; legacy vehicle stays 3.0). Suite 96 cases / 101,351 checks / exit 0. Frame-tail follow-up: plumbing is ~2.3 ms/tick headless; tick frames spend ~13 ms waiting in render submission (vsync on) vs ~2 ms with vsync off in an earlier probe, so the p95 tail is likely vsync pacing; untested. Vsync-off rerun done (`--disable-vsync`): frame p95 3.6/5.1 ms, max 15.8 ms, zero backlog: rendered benchmark passes; the vsync-on tail was display pacing. Decided by user: benchmark scene disables vsync itself (done; header `vsync=off`; frame p95 4.1/6.5 ms, dense max 19.5 ms). Raised by user: target is a low-end device/browser (WebAssembly). Done: [performance ledger](reference/performance.md) (assumed 6× slowdown, derived budgets: plumbing and rendered frame currently exceed, sim passes with ~12% margin; per-milestone History rows) and M4 plan Task9a combat benchmark (150 v 150, three layouts, sim-only budgets, no implementation yet). Not done: CI trend logging, machine-independent counters, web export spike. No `AGENTS.md` change (a one-line ledger rule there is optional). See [M2 verification](reference/m2-verification.md).
- M4 plan corrected: baseline/wall-time, watchdog is one 60 s suite budget (task7 gate ≤30 s), HP bars only selected/damaged, open decisions listed.
- New [Zero Hour verification plan](reference/zero-hour-verification.md): level 0 found ground speeds 2.5–3.75× faster than range scale implies; level 1 observation protocol proposed; gate before M5 proposed. Needs user decisions: speed scale, rendering fix, level 1 session.
- Item 2 (machine-independent counters): added `test_snapshot_size_ceiling` (open 79,481 / dense 80,345 nodes at the step-38 peak, busiest unit 322; mutation of the ceiling by 1 fails) and an engine draw-call print in the rendered benchmark (not yet run in a window). A* expansions not countable (built-in `AStarGrid2D`); canvas commands not observable headless. Plan Task9a adds `combat_work()` counter. [AGENTS.md](../AGENTS.md) updated: M4 reading list, performance ledger rule, rendered-benchmark etiquette, parity goal.
- Doc consistency sweep: counts (now 97 cases / 101,355 checks), rendered-gate status, speeds, vsync, M4 prompt and design aligned; historical M3 text kept with forward pointers.
- User approved the integration plan: branch `m4-prep` from `c441a7f` with three commits (benchmark/terrain fix, builder speed, docs), then push for CI, then fast-forward `main`, then fast-forward `m4-combat`. Each code commit passed the suite alone (97 cases / 101,310 then 101,355 checks). [CI run 41676948968](https://github.com/pdstuber/wargrid/actions/runs/41676948968) at `c11bf71`: Linux and Windows passed; the macOS job waited 15 minutes for a free runner and was cancelled with no steps run, so `compare-replays` was skipped. Substitute evidence, not CI: macOS traces generated locally on the same commit (97 cases / 101,359 checks incl. four trace-file checks, exit 0) matched the CI Linux and Windows traces, `REPLAYS MATCHED 1200` for both movement and economy. User approved fast-forwarding `main` on that basis; the macOS CI job was re-queued and remains unverified. Read git log/status and CI for current publication state. No M4 implementation. Code changes: `movement_benchmark.gd` (typed selection, vsync off, draw-call print), `world_view.gd` terrain, `economy_definitions.gd` builder speed, tests in `test_benchmark.gd` and `test_economy.gd`.

## 2026-11-03 — Prep for M4 Tasks 4, 5, 7 (for a Sonnet/medium run)

- User will run Sonnet 5.5 at medium effort on `prompt.txt`; asked for prep on the densest tasks. All four packages done, uncommitted on `m4-combat`:
  - **Refactor** (`simulation.gd`, behavior-preserving): `_validate_target`, `_assign_move`, target float normalization for any `target` field. Suite unchanged at 97 cases / 101,355 checks; benchmark sim p95 1.498 / 1.529 ms; `/ponytail-review` removed one unreachable guard.
  - **Envelope spike** (scratch, headless): [note](reference/m4-scenario-envelope.md) with timeline, army sizes, travel, 19-tick building-death stall, allocation cost. Main finding: production stops at 8 infantry / about 11 tanks unless units are moved; armies about 19 per side; attack-start range corrected to 9000..9800.
  - **Plan**: new "Code anchors and pitfalls" section (11 items), Tasks 4, 5, 7 split into checkpoints with stop conditions and stronger-model review requests.
  - **Test appendix**: [unrun red-test sketches](superpowers/plans/2026-11-03-m4-tests-4-5.md) for Tasks 4 and 5.
- User decision: the building-death stall and allocation cost are documented only, not fixed; the executor stops and reports if they block a test or budget.
- Not verified: the appendix tests (written before the API exists), and whether Sonnet at medium finishes. Nothing committed or pushed.

## 2026-11-03 — M4 planning

- User confirmed positive M2 playability and no M3 visual issues; corrected M4 playtest mention to M3. Reference notes updated; no M4 playtest or performance measurements inferred.

- User explicitly approved M4 design. Updated design/plan/prompt status; no implementation kickoff or inherited-gate deferral inferred.

- Added proposed design, source/config evidence and sequential Sol/Medium execution plan. No game-code changes or implementation kickoff.
- Read hash-verified root INIZH.big and pinned official source; selected rifle burst/reload, tank, health/armor and barracks values. Geometry, direct-hit simplifications and runtime parity remain explicitly provisional/unverified.
- Fresh Sol/Medium builder check resolved mixed armed selection and real match-duration assertions. Final scripted schedule/outcome must be measured and pinned during bounded task7 calibration.
- User subsequently authorized M4 branch and Sol prompt preparation: created `m4-combat` from local `main` at `c441a7f`, preserving uncommitted planning files; replaced root `prompt.txt` with M4 handoff. Historical M3 prompt remains `docs/m3-prompt.txt`. No implementation kickoff.
- Existing runtime test counts remain historical; no game tests or visible checks run for planning/preparation. No commit/push/PR/merge.

## 2026-11-03 — M3 playtest and wrap-up

- Implementation `303006b` already published on `m3-base-supplies`. Verified [M3 matrix](https://github.com/pdstuber/wargrid/actions/runs/41605911340): Linux/macOS/Windows and compare-replays successful at that exact head.
- Default launcher intentionally opens M2; supplied explicit M3 base-scene command. User then reported “test was looking good”; detailed checklist coverage and rendered measurements were not supplied.
- User requested documentation consistency and local merge into `main`. Updated current status, preserved historical evidence and fast-forwarded `main` through wrap-up commit `17f2f12`. No production changes or new implementation review needed; previous substantive review and Ponytail pass remain applicable.
- Post-merge headless verification passed: 95 cases / 101,305 checks / zero failures / exit 0; Python 6 tests / exit 0. Sandbox import needed a retry with macOS settings access; no code fix. Docs: 103 local links, zero missing.
- Publishing `main` still needs approval. No M4, PR, screenshots or rendered benchmark.

## 2026-11-01 — M0 local foundation

- [Execution plan](superpowers/plans/2026-11-01-m0-foundation.md) local checks complete; remote gate pending.
- [Verification record](reference/m0-verification.md) contains counts, failure probes, source provenance, review result and limits.
- Sole completed substantive review found no production defects; final Ponytail pass found no cuts. Grok attempt stalled, then fresh-context fallback completed.
- No engine upgrade, visible window, retail-data access, commit, push, PR or M1 work.

## 2026-11-01 — Session commands

- Added `.claude/commands/kickoff.md` and `.claude/commands/wrapup.md`, delegating to agent-neutral docs.
- Replaced Last Hearth paper-run/ruleset steps with Wargrid verification and document ownership. Existing task instructions override a redundant kickoff question.
- No checker script, game behavior or Git action added.

## 2026-11-01 — Wrap-up trial

- Fresh headless wrapper run: 11 cases / 199 checks / 0 failures, exit 0; final completion marker present. Old test agent retained restrictive sandbox and failed during import; fresh agent passed with current permissions. No game changes needed.
- Fixed stale planning-only status in AGENTS by linking README; blueprint local checkboxes now match evidence. Remote CI checkbox remains open. No design decision changed.
- Checked local documentation links/paths and handoff headings. Existing implementation reviews retained; no duplicate review.
- Proposed first commit includes initial user-authored planning/reference files, M0 implementation and session commands. No staging, branch creation or commit before approval. `.godot` cache ignored; scratch evidence stays outside repo. No active Wargrid background process found.
- Process deviations retained: grouped acceptance red/green cycle; stalled Grok attempt replaced by sole completed fresh-context review. Optional coverage gaps stay deferred.

## 2026-11-01 — First-commit approval

- User explicitly approved branch `m0-foundation` and first commit `Initialize Wargrid M0 foundation and session workflow`, covering all 26 authored files.
- Approval includes planning/reference documentation, M0 implementation/tooling/CI and session workflow. Cache and temporary evidence excluded.
- No push, PR or merge authorized. Next gate is remote CI after separate push approval.

## 2026-11-01 — M0 coverage follow-up

- C4 explicitly checks normalized float types on both axes before/after execution. C10 covers tick/player/sequence canonical queue order without weakening accepted sequence rules.
- Local suite: 11 cases / 209 checks, exit 0. Five independent scratch regressions each fail behavior assertions; production untouched.
- Corrected historical review assumption: existing deep Dictionary comparisons also detect removed float conversion on this build; new explicit checks improve diagnostic precision.
- User provided Actions log; GitHub CLI independently confirmed successful run for `20739d6`. Original remote gate passed, updated tests still local.
- No new commit, push, PR, merge or M1 work authorized.

- Coverage follow-up review complete: no findings; final Ponytail pass found no cuts. Grok timed out; fresh-context fallback was sole completed substantive review.

## 2026-11-01 — Group coverage and local integration

- Grok whole-branch review completed without defects; coverage limits prompted public-API tests for successful multi-entity orders and exact entity-ID snapshot order.
- C1/C12 additions pass: 12 cases / 212 checks, exit 0. Scratch first-member-only and reverse-ID mutations fail behavioral checks, exit 1. Production unchanged.
- User authorized pending M0 test/documentation commit and local merge into `main`; no push. Neither local nor remote `main` exists, so initialize local `main` at original M0 commit before fast-forwarding reviewed follow-up.
- Forced internal insertion reordering is unreachable through current API; no test-only mutation hooks added. Earlier Grok attempts were stopped too soon; whole-branch review eventually completed by waiting.

- Focused Grok follow-up review completed with no defects; final Ponytail pass found no cuts. Integration verification runs on local `main`; read Git log/status for exact commit/branch state.

## 2026-11-01 — M1 planning

- User requested an execution plan suitable for Sol at Medium; no implementation request yet.
- Inspected production kernel, all 12 existing cases, runner, scene, wrappers and CI. Fresh baseline: 12 cases / 212 checks / exit 0 via test subagent.
- Added bounded static-grid movement, projection/view/input contracts, intentional M0 test migrations, headless scene cases and async-runner failure probes. Prototype choices remain labeled; no parity claims.
- Updated current prompt, README, AGENTS and blueprint links. No game code, visible launch, commit or push.

## 2026-11-01 — M1 planning wrap-up

- Documentation-only scope: M1 plan plus AGENTS, README, blueprint, prompt and this handoff. No game, test, wrapper or engine changes; no game test rerun required.
- Checked 38 local Markdown links/paths, four kickoff handoff headings and diff whitespace. Proposed plan paths for future implementation are not existing-file claims.
- M0 remains implemented; M1 remains proposed, with implementation awaiting explicit kickoff. Existing local test evidence and remote/visual/reference limits remain unchanged.
- Proposed branch `m1-vehicle-plan`, commit `Plan M1 vehicle slice and handoff`; no staging, branch creation, commit or push before approval. No design decisions changed during wrap-up.

## 2026-11-01 — M1 planning commit approval

- User explicitly approved branch `m1-vehicle-plan` and six-file documentation commit `Plan M1 vehicle slice and handoff`.
- No push, PR, merge or M1 implementation authorized.

## 2026-11-01 — Commit reference and remote-state check

- Verified `20739d6` is original M0, `7d67481` is M0 coverage follow-up, and `1a3e316` is M1 planning. Historical baseline hashes remain correct; no game/test/tool/CI changes between the latter two.
- GitHub branch API confirms `main` at `7d67481`, `m1-vehicle-plan` at `1a3e316`; default branch is `main`. Branch publication is observed state, not an inferred approval history.
- [M0 follow-up CI](https://github.com/pdstuber/wargrid/actions/runs/41299222791) and [M1 planning CI](https://github.com/pdstuber/wargrid/actions/runs/41301269564) both completed successfully; fetched logs show 12 cases / 212 checks / 0 failures and `TESTS PASSED 212`.
- Earlier dated pending-CI/approval notes describe their historical checkpoints. Current handoff supersedes them. `prompt.txt` contains no commit hashes and needs no correction.

## 2026-11-01 — Final documentation wrap-up

- Verified published `m1-vehicle-plan` at `3c0f150`, successful remote CI and GitHub default `main`. Publication observed, not performed during wrap-up; M1 branch remains unmerged.
- Corrected stale CI summaries in README, blueprint and M0 evidence; refreshed current handoff. No design or implementation change. Historical commit baselines retained.
- Documentation-only checks: local links/paths, kickoff headings, diff whitespace and status consistency. No game rerun, visible check or implementation review required. No stray untracked files or active game/test processes found.
- Proposed commit on `m1-vehicle-plan`: `Refresh wrap-up and verified CI summaries`. Commit awaits approval; no push, PR or merge included. Tomorrow: review M1 plan on this branch and choose whether to start implementation.

## 2026-11-01 — M1 implementation

- Followed adopted vehicle plan in order: projection/navigation red/green, movement and named M0 migrations, view picking, scene/input/camera. Pulled async runner setup forward only to enable scene red tests; recorded in session ledger.
- Red evidence: helper 13 failures; movement 39; view picking 3; scene skeleton 24. Diagnosed wrong arrow constants with engine-key assertions and double-transformed headless mouse injection; fixed config/injector, preserved production coordinate conversion and tolerances.
- `sh tools/run_tests.sh`: 32 cases / 1089 checks / 0 failures, exit 0, final marker. Outside-root and fresh-cache copy match. Pinned-engine headless smoke exit 0; all eight runner failure probes exit 1, including actual watchdog timeout.
- Existing test agents kept old sandbox across allow-all switch; fresh agent picked up current permissions. No project workaround needed.
- Batched visible check authorized. Game launched without diagnostics; Computer Use denied Godot access. User screenshot and second recording confirm static scene/HUD plus selection, moving targets, arrival and camera pan. User confirms resize/zoom and ignored blocked/outside clicks. Basic visible smoke covered; HUD error text/post-transform re-selection explicitly checked headlessly, not separately captured in video. No commit, push, PR, merge, engine upgrade or sibling edits. Sole Grok review complete; test gaps closed and mutation-verified. Ponytail pass found no cuts.

## 2026-11-01 — M1 final handoff

- Final exact checkout, outside-root and fresh-cache suites each pass: 32 cases / 1089 checks / 0 failures, exit 0, `TESTS PASSED 1089`. Headless smoke exit 0. Eight runner probes exit 1.
- Three review regressions each pass old check and fail tightened check; production unchanged after review. Grok completed substantive report; capture-shell readonly-variable error means its exit code unknown, not an unfinished review. No duplicate substantive review. Final Ponytail lean pass: no cuts.
- Basic visible smoke supported by second user recording plus reports: selection, movement around obstacle, retargeting, arrival, pan, resize/zoom and ignored blocked/outside targets. HUD rejection text/post-transform re-selection established automatically, not separately recorded visually. No exhaustive feel/performance/reference claim.
- README, movement/verification notes and plan checkboxes reflect local evidence. No commit, push, PR or merge; M1 remote CI pending approved publication. Stop at M1.

## 2026-11-01 — M1 commit approval

- User explicitly authorized committing everything currently in repo, including pre-existing documentation changes and reviewed M1 implementation/tests/evidence. No push, PR or merge included. Read Git log/status for resulting commit.


## 2026-11-02 — recovery and M3 planning

- Reconciled README, AGENTS, blueprint, M2 plan, reference status and root prompt against actual unfinished checkout. Game code untouched. Fresh delegated Godot result: 54 cases / 95,914 checks / 42 failures / exit1; Python comparator6 tests/exit0. Test subagent interruption recovered; original usage-limit stop unverified.
- User chose Zero Hour research first, then source-informed playable M3 slice; approved design for detailed planning. Read pinned GeneralsMD source and hash-verified root INIZH.big selected configuration. Original archives/source unchanged; no EA implementation/assets added. Research limits and explicit fixes recorded in M3 reference.
- Added M3 design, detailed sequential Sol/Medium execution plan, source/config record and separate docs/m3-prompt.txt. One fresh design builder check found no consequential gaps; plan self-review mapped scope, signatures, tests and lifecycle boundaries. Planning only; M2 gates precede M3 execution.
- User authorized future local M2 completion commits, local main merge and creation of m3-base-supplies carrying full repo/preparation documents. Root prompt includes exact handoff and installs M3 root prompt only after branch switch; no push/PR or M3 implementation during that run. No Git action performed here.
- Documentation verification delegated: diff whitespace and local Markdown link targets checked; final result recorded in response. No game rerun after documentation-only changes, no rendered checks, no M2 implementation review claimed.
- Informal M4.1 playtest notes from the M5 friend match (user, 2026-11-04) now live in [M4.1 verification](reference/m4.1-verification.md); user later declared the playtest done (2026-11-04); findings open.
