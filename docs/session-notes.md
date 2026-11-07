# Session notes

Working handoff record, not authoritative design. Follow [kickoff](kickoff.md) and [wrap-up](wrapup.md). Setup lives in [README](../README.md); design in [blueprint](../Wargrid_Kickoff_Blueprint.md).

## Session

2026-11-06 **M7 planned** (docs only, uncommitted on `main`; no code or tests touched). [Execution plan](superpowers/plans/2026-11-06-m7-factions.md): Tasks 0-11 are gate 1 at step level, gate 2 (China) and gate 3 (FRC, exit) are outlines; root `prompt.txt` is the handoff. User decisions this session: survival follows Zero Hour (`GameLogic.cpp:1630`, `Team.cpp:1711-1726`: a seat survives while it owns a building flagged `counts_for_victory`, foundations and holes count, units never do); performance task is trace-preserving fixes only (the design's two candidates already landed in M6 11a/11b); four extra Zero Hour behaviours in scope (Humvee passengers fire, powered defences go dark, Red Guard trains 2, passenger damage on transport death); wider match windows pre-approved (1v1 terminal tick 8000-17999, team cap 45000); execution on Sonnet (medium), Opus (high) only for gate reviews and for expanding the gate 2 and 3 outlines. Found: combat `dense` is over its own stress ceiling (2.665 / 4.228 against 2.52 / 4.02, bench runner) but `run_benchmark.sh` stops at `open` and never reports it; Task 1 makes it report every layout. Per-unit values, defeat rule, docking, tunnel, salvage and hole findings are in [M7 evidence](reference/m7-factions.md#per-unit-values-extracted-at-planning-config-2026-11-06) (config and source, not measured). Not verified: the plan has not been read by a cold Sonnet pass; no task has run.

2026-11-06 **Slowdown factor measured, F = 5.5** (merged to local `main` at `8e53e34`, plus `fec86c2` for the Deck docs; not pushed). Steam Deck over SSH plus web exports: Deck native 3.4–4.2× the idle Mac editor build, Firefox/WebAssembly on the Deck 4.9–5.45×; user chose the browser as a target next to desktop, so F = 5.5 (budgets 1.82 / 3.64 / 0.91 / 3.04 / 0.6 ms; `run_combat.gd`, `run_lockstep.gd` updated). Kept as a recalibration tool: `WargridBenchRunner` (`wargrid_bench` feature tag, presets `Web Bench` / `macOS Bench` / `Linux Bench`) and `tools/serve_web_bench.py` (cross-origin isolation, else browsers round timers to 1 ms). Results, caveats and rerun commands: [performance ledger](reference/performance.md#target-factor-measurement-2026-11-06). Stress ceilings unchanged, so `run_benchmark.sh` still exits 1 on combat stress. Deck cleaned (only today's folders removed; `HearthSpike` kept); the user keeps `sshd` and the Mac key on the Deck, so it is a standing Linux and browser test device ([how to use it](reference/performance.md#target-factor-measurement-2026-11-06)).

2026-11-06 **M7 design approved** (docs only, committed on `main`). [Design](superpowers/specs/2026-11-06-m7-factions-design.md) and [evidence](reference/m7-factions.md) hold every decision from the brainstorm (roster, mechanics, Command Centers, faction choice offline and online, three stop gates, performance task first with time box and fallback, capability data, own names `usa` / `china` / `frc`, generic display names, my calls on docking, survival and the bot). Blueprint §1, §7 (Ashfall task before M7, M7 rewritten, ground batch A replaces M7.1, M7.6 HUD, ground batch B after fog, Later) and §14 updated; AGENTS and README link the design. Builder check done (5 questions answered in the design). Not verified: no code or tests touched.

2026-11-06 **Zero Hour retaliation parity closed** (`f12c5a5` on local `main`, not pushed; docs, `tools/zh_parity/parity.py` scenarios `retaliate_bisect` and `retaliate_return`, no game code). Join radius: no discrepancy, the old "48 units" was a unit slip (Wargrid 4.8 cells = 120 units, same as the source's 120 + victim radius; measured cutoff between 125 and 130 units). Return home after the attacker dies: 10 ticks in Wargrid against 7-11 frames in Zero Hour (measured, source build; Wargrid side from an untracked scratch script). Leash-driven return and the 2.2x return rescan still unmeasured. Evidence: [M5.1 verification](reference/m5.1-verification.md).

2026-11-06 **M6 playtest findings fixed and merged to local `main`** (`d53c559`, not pushed; branch `m6-playtest-findings` still exists). Four presentation/HUD fixes (enemy order crosses hidden, health bar above the target box, Victory/Restart centred, build and E keys explain themselves); suite 277 / 112,744 / 0, lint and warnings pass, traces byte-identical. Not seen on screen. Evidence: [M6 verification](reference/m6-verification.md#playtest-findings-fixed-2026-11-06).

2026-11-06 **GDScript static checks Tasks 1–2 merged to `main`** (`3e3aae0`, pushed; branch `static-checks` still exists locally and on origin). [Plan](superpowers/plans/2026-11-05-gdscript-static-checks.md) run natively as the user chose. Done: `gdlint` gate (`tools/run_lint.sh`, `.gdlintrc`, CI job `gdscript-lint`); Godot typing, shadowing, unused-parameter and integer-division warnings as errors (`tools/run_warnings.sh`, `[debug]` in `game/project.godot`, step in the `godot` CI job); tests exempt from `untyped_declaration` only via a top-of-file annotation (user accepted); `sim` handles typed `Simulation` in 22 files. Verified: suite 273 cases / 0 failures (check count 112,730 or 112,737 between runs, cause not investigated), the four replay traces byte-identical before and after on this Mac (the plan's `compare_local_traces.sh` needs a CI run id, so a same-host before/after `cmp` replaced it), netplay `match`, `kill`, `stall`, `perturb`, benchmark summary rows equal to `main` (both exit 1, the M6 over-budget rows; timings within noise, one run each), CI run 42185773054 green on Linux, Windows, lint and compare-replays. Not run: the rendered benchmark and rendered scenes. Reviews: one fresh Opus review of Tasks 1–2 (no Critical; docs fixed, `run_lint.sh` simplified) and `/ponytail-review`; the later `Simulation` typing change had no separate review. Bug found by the suite, not by the checker: `SeatSim` is passed to the bot and scripted-human code as a read-only view (`snapshot`, `tick`, `issue_command`, `map_data`), so those parameters stay `RefCounted` on purpose.

**Task 3 (`unsafe_*` except snapshots) skipped (user, 2026-11-06, after the recommendation below).** Count on the post-merge tree before the `Simulation` typing: 1,044 game-code findings (about 364 on `RefCounted`, about 550 `Variant` snapshot reads, about 100 `InputEvent`/`Node`) and 4,543 in tests, over the plan's stop rule of about 500. After typing `sim` the experiment showed about 819 left, a soft count because compile cascades hid some. Typed handles already turn an unknown member into a compile error, so the gate would mainly add region upkeep and a benchmark rerun. Cyclic preloads work in Godot 4.7.2. Left untyped on purpose: `navigation: RefCounted` handles.

2026-11-05 **GDScript static checks planned** (separate small task, not a milestone): pilot on a scratch copy, repo untouched, 73 `.gd` files, `gdlint` 1,199 findings. The user asked for the `unsafe_*` warnings "for everything except the snapshots", planned as Task 3. Also done that day: M6 close-out notes (below) and `prompt.txt` moved to `docs/m6-prompt.txt`, the way M5.1 was closed.

2026-11-05 **M6 implemented and merged to `main`** (merge `de647e1`; README, AGENTS and blueprint record CI green on Linux and Windows and the user 1v1 playtest done, minor findings open). This entry only brings the notes level with those documents: the M6 wrap-up was not written when it merged, so the final CI run, the user's playtest findings and the open budget items are in [M6 verification](reference/m6-verification.md) (last pre-merge resume record: 272 cases / 112,704 checks / 0 failures; user-accepted over-budget rows, `run_benchmark.sh` exit 1; a WebAssembly budget spike wanted on a separate branch). Not re-verified here.

2026-11-05 **M8 bots refined, documentation only** (merged to `main`; docs only). User decisions: fog of war before the bots (new M7.9); bots fair (same rules, team-vision-only information, human-plausible command budget at every level); hardest level beats the user and friends regularly; about five levels with selectable play styles; strong bot first (M8), ladder and styles after (M8.1). Blueprint §7, §11, §14 updated, all scope labelled proposed; user-supplied research moved to [fair bots research](reference/fair-bots-research.md) with a status note (claims checked against primary sources the same day: they hold, with corrections: OpenRA bots ignore fog, Zero-K CAI has its own `maphax` FIXME, microRTS deprecated 2025, Petra also penalises easy levels; SparCraft wiki claims not checked; Zero Hour has three difficulties and its shroud handling is not audited). Not verified: no code or tests touched. Next: user approval of the M7.9/M8/M8.1 scope before any planning; attention-budget numbers decided at M8 planning from evidence.

2026-11-05 **M6 planned** (`main`, documentation only, no game code; since implemented and merged, see above). Approved design, source evidence, execution plan and root `prompt.txt`; AGENTS.md map-data exception; blueprint §7/§12/§14 and README updated. Verified: local links and paths in the changed docs; no tests run (docs only). Decisions and the cheaper-model plan check: see the M6 planning section below.

2026-11-05 **M5.1 implemented and merged to `main`** (merge `5d86caf`; branch deleted locally and on origin; `main` = `origin/main` at `becf439` plus this wrap-up). User playtest done ("I just did a playtest, the rest look good"; one finding, the production-queue label, fixed in `294e20e`). Verified: suite 220 then 221 cases / 104,553 checks / 0 failures; CI run 42019783157 green on `ff117f8` (relay, relay-lint, Linux, Windows, compare-replays), whose game, relay, tools and protocol code equals `main`; `compare_local_traces.sh` MATCHED (netplay 281, on `8588f85`); rendered benchmark rerun passed (open, dense); relay checks and all nine netplay scenarios passed on the merged tree. Opus review (4 important findings fixed) and `/ponytail-review` done. Not verified on screen by me: hint ring, paused label, resume outline (covered only by the user's sentence). Open: parity item (Zero Hour joined a Ranger at 70 units, Wargrid 48; bisect before changing; return-home timing unmeasured). Evidence and rulings: [M5.1 verification](reference/m5.1-verification.md). Blueprint now also has proposed M7.1 roster fill and M7.5 art pass (opens with a sprite vs stylised-geometry spike, since the user likes the rectangle look); scope of both not approved.

2026-11-05 relay hardening **merged to `main`** (merge `58d13f2`, pushed) and deployed to fly `wargrid-relay-jvm`: drain on SIGINT/SIGTERM, per-room crash isolation, fail-fast config, `log/slog`. Verified on the final tree: `go test -race`, golangci-lint 0 issues, `run_conformance.sh` 33 cases, `run_netplay.sh` relay-term, relay-down and match passed; on fly the new binary logs `relay started … drain=3.5s` and the probe got `RELAY WELCOME`. Live drain on fly not yet observed (the machine was suspended at deploy). Detail below.

2026-11-05 Zero Hour parity harness spike **merged to `main`** (`c7497cc`, since pushed): docs, `tools/zh_parity/` and one CI line, no game code; level 1 done by harness, decision list open ([spike](reference/zero-hour-parity-spike.md)). M5.1 (branch `m5.1-findings`, separate session) can measure Zero Hour mechanics such as retaliation with the [parity harness](reference/zero-hour-parity-harness.md).

2026-11-05 relay stack spike between milestones, then the relay was **replaced by a Go port on `main`** (`4f38ce8`, pushed; `main` = `origin/main`). CI run 41950491714 green on `4f38ce8` (relay, relay-lint, Linux, Windows, compare-replays). Locally on the final tree: relay `go test -race`, golangci-lint 0 issues, `run_conformance.sh` 33 cases, all nine `run_netplay.sh` scenarios passed; fly `wargrid-relay-jvm` redeployed from that tree (remote match passed). Evidence: [relay stack spike](reference/relay-stack-spike.md), host comparison in [relay scaling](reference/relay-scaling.md#flyio-vs-railway-measured-2026-11-0405).

2026-11-04 M5 online spike **implemented and merged to `main`** (merge `55beae4`, pushed; `main` = `origin/main`). Tasks 0–11 done; exit gate met except the repeat friend match on the fixed build, which the user deferred to later (open, not met). Verified on `bba5482`: editor suite 192 cases / 104,432 checks / 0 failures, benchmark exit 0 (lockstep p99 0.060 ms vs 0.55), relay `gradlew test`, nine `run_netplay.sh` scenarios, CI green (relay, Linux, Windows, compare-replays), `compare_local_traces.sh` MATCHED (netplay 364), rendered benchmark passed (frame p95 4.3 / 5.9 ms, about 0.7 ms above M4.1, one run), Grok review and `/ponytail-review` done; HUD look is a user statement ("that looks fine"). Findings: [M5 findings](reference/m5-online.md); evidence: [M5 verification](reference/m5-verification.md). Earlier: M4.1 merged at `f2c5f9e` (playtest declared done by the user 2026-11-04, findings open); M3 detail in [M3 verification](reference/m3-verification.md), M4 in [M4 verification](reference/m4-verification.md).

## Pending user action

- Worktree `../wargrid-wt` (branch `spike-wasm`) is clean: its browser-build work is merged into `main` at `d02dcbe` (`main` = `origin/main`). Delete the worktree and branch if no longer wanted.
- After each gate playtest, start an Opus (high) session to expand the next gate's outline in the M7 plan to steps (gate 2 after gate 1, gate 3 after gate 2). Execution stays on Sonnet (medium).
- M6 playtest fixes are not seen on screen (headless only); a rendered look would also settle whether a target box still covers a building's health bar (only unit bars were moved and tested). Minor: the new "Choose one builder" / "Select a production building" messages stay until the next command, like the older error lines.
- GDScript static checks: Task 3 skipped (decided). Open, optional: delete the merged `static-checks` branch (local and origin); type the `navigation: RefCounted` handles the same way as `sim`.
- Review the new `Simulation` typing only if wanted: it had the suite, traces, netplay and CI but no separate reviewer.
- Approve (or change) the proposed M7.9 fog, M8 and M8.1 scope in blueprint §7 (all labelled proposed, 2026-11-05); the attention-budget numbers are chosen at M8 planning from evidence.
- Decide the proposed M7.5 art pass scope (blueprint §7); M7.1 is replaced by ground batches A and B (user, 2026-11-06).
- M5.1 parity: retaliation join radius settled 2026-11-06 (no discrepancy, the earlier "48 units" was a unit slip; see [M5.1 verification](reference/m5.1-verification.md#retaliation-parity-check-measured-source-build-scenario-retaliate_ranger-2026-11-05)). Return home after the attacker dies measured the same day (10 ticks vs 7-11 frames, matches); the leash-driven return and the return rescan are still unmeasured.
- M4.1 playtest findings (user, 2026-11-04) are open; to be tackled outside M5, see [M4.1 verification](reference/m4.1-verification.md). Deferred minors: BM7 lane pin, R5 other-command coverage.
- `main` pushed 2026-11-06 (user approval; `main` = `origin/main` at `2b532ac`). Delete the merged local branches `m6-playtest-findings` and `spike-target-factor` (never on origin) if wanted. Local branches `gpl-license`, `m5-online`, `spike-relay-improvements` (also on origin) and older milestone branches are merged and can be deleted (not done).
- Global agent rules: grok removed from the review route in `~/dotfiles/config/agents/AGENTS.md` (user, 2026-11-05); that dotfiles change is uncommitted and is the user's to commit. `grok` can be uninstalled.
- Spike harness (other ports, load driver, raw results) copied to `~/projects/wargrid-relay-spike`, outside git; delete when no longer wanted.
- M5 open items: repeat the friend match (macOS vs Windows on the fixed build) later; real fly bill later (user: "fine for now"); Railway check done in the 2026-11-05 [relay stack spike](reference/relay-stack-spike.md) (comparison in [relay scaling](reference/relay-scaling.md#flyio-vs-railway-measured-2026-11-0405); sleep/wake still untested); suspend during a live match unobserved.
- Choose a licence for original art and audio (code is GPL-3.0-or-later).
- Check in a fresh session whether the project skill settings shrank the skill listing (baseline 48,567 bytes; revert if not).

## Deferred experiments and research

- Relay scaling (user, 2026-11-04): the single-machine `--ha=false` relay is accepted for M5 only; user is not happy with it as the long-term approach. Placed in M9 (user, 2026-11-04): cloud-agnostic multi-machine relay (no provider-only routing, so no `fly-replay`), fly.io stays the host for now. Railway evaluation and the synthetic-room load test were done in the 2026-11-05 [relay stack spike](reference/relay-stack-spike.md): about one 3v3 room per shared-cpu-1x machine at the 6.25 % CPU baseline; M9 design inputs (batching, compact command log, Elixir-style room patterns) recorded there. Proposal review and options: [relay scaling](reference/relay-scaling.md).
- Project goal (user, 2026-11-04): also an architecture exploration. Over-engineering is acceptable; explore very scalable architectures from the start, from M6 on. M5 design stays as approved. **Relaxed by the user 2026-11-05:** one relay machine is acceptable for now ("we could get pretty far with it"); it is not highly available, so high-availability options are still worth exploring in M9 (options and an assessment in [relay scaling](reference/relay-scaling.md#high-availability-options-proposed-2026-11-05)). The "not happy with a single machine" and "very scalable from the start" wording above is superseded.
- Source/config-supported economy and combat values remain RETAIL_UNVERIFIED; departures stay explicit in reference/design notes.
- AI moods (Sleep, Alert 1.1, Aggressive 1.5) deferred to M8 bots (user, 2026-11-03).
- Map analyzer proposal (user-supplied, GPT-written; [proposal](reference/map-analyzer-proposal.md)): superseded by the conversion decision. Its route-length matrix and per-start metrics went into M6 Task 2 (report-only); parked: chokepoint/alternative-route analysis for M8 bots, a validator for more maps, per-unit clearance, PNG/HTML reports.
- Retail map sizes vs our 48×32 cells: superseded by the M6 decision to convert Twilight Flame; M6 Task 1 records its real size and border.
- Runtime parity harness: adopted 2026-11-05 ([spike](reference/zero-hour-parity-spike.md)); counts as level 1 with the source-build caveat; open: its decision list and the Chinook supply scenario. Decided 2026-11-05: M5.1 adds a retaliation parity scenario at Task 9; the combat-feel list and the Chinook scenario went to M6 planning, and the user decided all four items in favour of Zero Hour behaviour (see the M6 planning section; plan Tasks 6–10).
- Retail `ForceIdleMSEC` INI value unread (code default 1 frame); `stop` re-acquire delay uses the existing 15-tick stagger instead.

## Next action

**Next session:** the M7 plan and `prompt.txt` are written (uncommitted until approved). Options at kickoff:
1. **Run M7 gate 1:** a fresh session on Sonnet (medium), "resume from prompt.txt", starting at Task 0. Optional first: a cold read of the [plan](superpowers/plans/2026-11-06-m7-factions.md) by a fresh model for gaps.
   Or first the small **Ashfall playable** task (blueprint §7, before M7): it has no design yet, so a short brainstorm first.
2. **M6 leftovers:** the over-budget simulation rows are now M7's first task (design §1); optionally the leash-driven retaliation return timing ([M5.1 verification](reference/m5.1-verification.md)). The playtest findings and the join-radius bisect are done. Still open separately: the repeat macOS-vs-Windows friend match on the Go relay. Relay hardening is done and deployed; M9 owns its next changes (one machine is acceptable for now, availability options and the `performance-1x` question are in [relay scaling](reference/relay-scaling.md)).

**M4 complete and merged into local `main` (2026-11-03).** Evidence: [M4 verification](reference/m4-verification.md). Process changes adopted on `main`: [milestone prompt](milestone-prompt.md), [workflow retrospective](reference/2026-11-03-milestone-workflow-retrospective.md). Roadmap re-aimed at the long-term target (3v3 online with friends against bots, USA/China/GLA, Twilight-Flame-like full-scale map): blueprint §1, §7, §11, §14.

- **M5 online spike: merged to `main` (2026-11-04), repeat friend match open.** Still unobserved/owed: M9 list in [M5 findings](reference/m5-online.md) (dynamic delay first: command p95 ~190-205 ms against the 250 ms budget at a 4-tick delay). Historical handoff `prompt.txt`.
- **M4.1 implemented and merged to `main` (2026-11-04); user declared the playtest done 2026-11-04, findings open (see M4.1 verification).** Formerly next: user playtest (rally, enemy info, pile labels, opponent defence, 5–10 minute match). Evidence: [M4.1 verification](reference/m4.1-verification.md). The five items below are the original playtest notes, now all implemented:
  1. **Rally point per producer.** Zero Hour production exits read a rally point (`AIPlayer.cpp` 500/680, source revision `0a05454`). Today new units stay on the producer's perimeter, which also stalls production at about 8 infantry and 11 tanks. Touches production, a new command and the replay traces.
  2. **Opponent too passive.** Guard units only fire inside weapon range and never move, and the opponent never defends its base. Proposed: base defense (the same rule the scripted human needed in M4 Task 7) and reaction a bit beyond weapon range; check Zero Hour's idle acquisition range in source before choosing the distance. Changes the match outcome, so the scenario pin (tick 9943) must be recalibrated.
  3. **Selecting an enemy should show info.** `WorldView.pick_entity` only returns player 1 units; add read-only kind, owner and HP for enemy objects.
  4. **Collectors on one supply pile are hard to read.** One dock per pile is M3 design (Zero Hour docking); add visibility: pile label "docked 1 · waiting 2", collector state when selected.
  5. **"4: barracks" next to "S: stop".** HUD wording slip: base line says "1/2/3 build", the skirmish appends "4: barracks" elsewhere; make it one "1/2/3/4 build".
- **After M5:** M6 teams and full-scale map, M7 China and GLA (gate: Zero Hour spot checks S1–S3 run or deferred), M7.1 roster, M7.5 art, M7.9 fog of war, M8 bots, M8.1 difficulty levels and styles, M9 3v3 online.

## 2026-11-05 — M6 planning decisions

User decisions (2026-11-05, planning only; plan `~/.claude/plans/nifty-sprouting-globe.md`):
- Headless is enough for M6; 1v1 skirmish stays on 48×32, no big-map presentation.
- Parity decision list: edge-to-edge range, Ranger cadence 4/4/22, Crusader splash, and all three movement items (3-frame start delay, acceleration/braking, turn-in-place).
- Map converted from EA's GPL-3 (+ additional terms) `Twilight Flame.map` in `~/projects/CnC_Modding_Support` (`3aad8e4`) by a repo tool; EA notice and terms kept, own map name, AGENTS.md map-data rule to be amended. Matters most: scale, elevation, start positions, attack routes.
- Elevation affects passability only (cliffs block, ramps connect).
- One M6 (not split M6/M6.1); feel changes before final measurement.
- Teams confirmed: up to 8 seats with team ids, hostility = different team, team victory; bot seats run the existing skirmish policy; lockstep stays 2-seat. Splash hurts allies (source default). Firing ignores heading (no turrets) in M6.
- Done: evidence note `docs/reference/m6-map-and-feel.md`, design (builder-checked, approved), execution plan `docs/superpowers/plans/2026-11-05-m6-teams-full-map.md`; AGENTS.md map-data exception, blueprint §7/§12/§14 and README updated. Plan checked for cheaper-model execution by two cold Sonnet-medium reads (11 then 6 high/medium gaps, all fixed: model routing per task, Task 1 values table, per-tick movement rule, start-delay trigger, epsilons, provisional re-pins with Task 12 confirming). Root `prompt.txt` written. Not committed. Next: `/wrapup`, then a fresh-session kickoff with "resume from prompt.txt".

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

- Friend match (macOS editor run vs friend's Windows 11 export): no desync, command p95 96.0 / 84.6 ms, but ticks ran at about 57/s: `online_main.gd` catch-up ran 2 ticks per frame permanently. Fixed with a bounded per-frame credit (`f82114f`, test first) plus the false "Connection to relay lost" after match end.
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
