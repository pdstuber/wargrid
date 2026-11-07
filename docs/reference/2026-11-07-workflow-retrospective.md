# Workflow retrospective (2026-11-06 to 2026-11-07)

Status: **PROPOSED (2026-11-07), nothing adopted.** Written by a read-only Opus analysis of the Claude Code transcripts of the last two days. It follows the [M0–M4 retrospective](2026-11-03-milestone-workflow-retrospective.md) and does not repeat its adopted items (restart at checkpoints, fresh subagent per task, interaction tests, one gate reviewer, pre-authorized commits, bounded reads). Each recommendation is tagged **[evidence]** (counted in the transcripts) or **[judgement]** (reasoned, not measured).

## Scope and method

- **Sources:** 36 main sessions and 94 subagent transcripts under `~/.claude/projects/-Users-pdstuber-projects-wargrid*/` modified on or after 2026-11-06, including the `-wt` and `-wt-2` worktrees. Parsed with small stream scripts (usage per request, tool calls, tool-result sizes and errors, tool wall time). Totals agree with `tools/session_usage.py` (coordinator: 54,750,897 processed, 249 requests).
- **Main subject:** the coordinator session `77c02dce-6b2d-4f3e-b2bf-73a55134f5e7` (short name `wargrid-5e [2acd58]`), 12:00–20:26 UTC on 2026-11-07: gate 3 (G3.1–G3.5), gate 3 review, ultra review, playtest fixes, economy parity rework, parity harness, Opus reviews, rendered rerun. Earlier milestone runs: `cf1e101b` (gate 1), `b6dc7faa` (gate 2), `61d689f5` (gate 3 planning).
- "Processed" means input plus cached input per request, summed, as in the earlier retrospective. Times are UTC from the transcripts.
- This analysis itself (`agent-a1f3a421e…`) is excluded from all counts.

## Measured usage

| Group | Agents | Processed | Requests |
|---|---:|---:|---:|
| All sessions, two days | 36 main + 94 sub | 822 M | 5,701 |
| Coordinator `77c02dce` (Sonnet) | 1 | 54.8 M | 249 |
| Its 31 subagents | 31 | 152.4 M | 1,425 |
| Gate 1 run `cf1e101b` + subagents | 1 + 19 | 49.9 M + 71.9 M | 250 + 902 |
| Gate 2 run `b6dc7faa` + subagents | 1 + 22 | 35.0 M + 54.5 M | 185 + 721 |
| Gate 3 planner `a8224204e` (Opus, 36 min) | 1 | 42.4 M, context up to 531 k | 120 |
| M6.5 sound planner `a4e975bd5` (Opus, 90 min) | 1 | 36.7 M, context up to 538 k | 129 |

By subagent model and kind (two days): Sonnet implementers 37 agents / 168 M; Opus plan or decide 6 / 90 M (79 M of it the two plan writers above); Opus reviews 11 / 50 M; Sonnet research 13 / 29 M. The four short Opus decision agents of the economy rework cost 3.0–3.8 M each.

The five most expensive subagents of `77c02dce`:

| Agent | Task | Wall | Processed | Note |
|---|---|---:|---:|---|
| `aa369a089` | parity harness: supply cycle (Sonnet) | 157 min | 30.6 M | 86 sleep polls, 117 min inside sleeps, 15.2 M on poll requests |
| `a0e03593f` | playtest fixes P1–P3 (Sonnet) | 25 min active | 13.8 M | scope pushed three times, P2 result superseded by T1–T4 |
| `a94f2e5f2` | G3.5 matches, parity, ledger (Sonnet) | 74 min | 11.4 M | five stops, one diagnosis withdrawn |
| `a9cd620d8` | ultra review fixes (Sonnet) | 37 min | 10.8 M | nine findings, all test-first |
| `ab0bbf10c` | fresh Opus review after the ultra fixes | 12 min | 10.0 M | found the stale converter and a non-discriminating test |

## Findings

### 1. Where tokens and wall time went

- **Waiting on the 120 s Bash timeout** [evidence]. The suite median is 78 s, p90 121 s (37 pure suite runs in `77c02dce`); suite plus lint plus warnings in one call exceeds the default 120 s. 57 calls over two days ended in "did not complete within its 120s timeout and was moved to the background", and the agent then polled. Over two days: 27 blocked `sleep N; cat …` calls, 10 `Monitor` calls without the required `description`, in 23 different agents. 321 requests were sleep or poll requests, 45.3 M processed (5.5 % of everything). Worst: the harness agent (15.2 M, half its total), Task 10 `ae3567347` (4.9 M), G3.5 (2.8 M).
- **The suite crossed the earlier retrospective's 30 s filter trigger** [evidence]. 260 full-suite runs longer than 30 s in two days, about 5.9 h of tool wall time (some concurrent). Task agents ran the full suite 6–33 times each (gate 1 review fixes `ad330076b`: 33; Task 10: 26; G2.1: 21). The gate 3 review fixer improvised a scratch `WG_ONLY` filter in `run_tests.gd` and reverted it, which shows the need.
- **The measuring tool was not profiled before a two-hour sweep** [evidence]. The Zero Hour harness ran capped at 30 Hz (`GEN_FPS_CAP`). An Opus review (`a2339182d`, 12 min, 4.7 M) found it two hours in: a recorded frame went from 173 ms to 6.3 ms (27×), and six truck jobs took 40 s on three lanes against about 7 min per capped run.
- **The coordinator context grew without a restart** [evidence]. 45 k at 12:00 to 387 k at 20:26, linear, with 51 user prompts and several side topics (ultrareview mechanics, Fly Sprites, ssh to the MacBook, calibration loops). A restart at the four phase ends (gate 3 done, ultra fixes done, economy rework done) simulates to 20.6 M instead of 54.8 M (−62 %). The milestone prompt says to end at a stop gate; the run continued past the exit gate into new work in the same session.
- **The append-only verification file is the biggest repeated read** [evidence]. `m7-verification.md` is 152 KB (811 lines, the resume record alone about 4 KB). It entered contexts 135 times in reads over 2 KB, 1.6 M characters (about 400 k tokens fresh, then carried in every later request of that agent). The 124 KB plan entered 84 times (1.0 M characters). The gate 3 planner read the verification file whole three times (50–53 k characters each).
- **Opus plan writers read everything** [evidence]. The two plan writers reached 531 k and 538 k context and cost 79 M together, about as much as all eleven Opus reviews (50 M) plus the four Opus decision agents.

### 2. Failure and rework

Tool errors were low: 126 errors in 5,701 requests. By kind: blocked sleep 27, wrong path or zsh glob 24, grep no-match exit 1 18, other non-zero 15, `Monitor` without description 10, permission denied or rejected 8 (one broad `pkill`, one large `rm`), Python traceback 7 (scenario `KeyError` in the harness), lower-case `bash` tool name 7, GNU `sed -i 's/…'` instead of BSD `sed -i ''` 3, Godot parse or script error 2. Only the waiting errors are systematic.

Rework, by root cause:

| Incident | What happened | Cost | Class |
|---|---|---|---|
| Shared dock cell, three signals | Gate 2 review minor M6 "a source and a nearby depot can share dock cells", skipped as latent. G3.1 (12:12) the literal Lb2 assertion failed on 72/1500 ticks for the same overlap; the coordinator recommended and the user accepted the relaxed form ("false positives"). Playtest (15:51): 20,000 credits in a minute, root cause "a shared dock cell". | Playtest fix, then the whole economy rework (about 3.5 h, about 73 M across 11 subagents) | design assumption: tests checked "no stacking", nobody checked the rate |
| Playtest fix scope grew in steps | Footprint 4×5 (15:58), then clearance rules (16:02), then the 5 % rate target, then the builder-collector hint. The fixer ran beside two research agents and sat idle on a red tree with six moved pins for about an hour. Pins moved four times (playtest tree, T1/T2, T3, T4). | `a0e03593f` 13.8 M; pins re-measured four times | split too late: fix started before the research it depended on |
| 3.6× stop line | The Opus design agent `a048e4961` wrote "if ZH reaches 3.6× one worker, ZH does not hold the dock". The measured 3.66× tripped it; the revision `a38d5967b` found a held pile gives about 3.66× and an unheld one about 4.0×. | one Opus revision (3.0 M, 10 min) plus a skipped pending test | arithmetic in a plan without its derivation |
| Wrong constant in a brief | The coordinator's placement-research brief said "10 world units per cell, verify"; the repo says 1 cell = 25 units (10 is Zero Hour's pathfinding cell). The coordinator also mis-ordered the minimum distances once and corrected itself. | caught by "verify", no rework | coordinator restating numbers |
| Fm1 starvation found at T4 | Both sides starved from tick about 20,000. The Opus decision agent `a562780fe` found in 8 min that `skirmish.json` held 200-box piles, an M3 test value, against Zero Hour's 400. | one blocked executor round | test-map data never compared to source |
| Hard-coded fixtures | 38 supply tests failed after the footprint change because positions were literal; T4 then changed literal tick values in Su2, Su4–Su6, Gt1, Gt2, Lb1. | part of `a0e03593f` and `a7a756e40` | fixtures bound to geometry and timing constants |
| G3.5 stop chain | Five phone questions in 30 min (13:12–13:43). One diagnosis ("slow, far seat") was withdrawn after a 90,000-tick run. Four of the five recommended options were "investigate" or "diagnose first", and the user took the recommended option every time. | 5 round trips, 74 min agent | stops asked before diagnosis |
| Benchmark exit 1 | `run_benchmark.sh` exits 1 on rows the user accepted until the spike. 13 of 30 invocations over two days were non-zero or exceeded, so the exit code no longer separates a new regression from the known rows. | repeated re-reading of benchmark logs in four agents | exit status overloaded |
| Stale docs | Four subagents in two days did only doc reconciliation (`a40322727`, `a4e468673`, `aaaff0c2a`, part of `a04cd9c99`). The gate 3 review minor 2 found wrong check counts in the records. AGENTS.md line 7 (1,287 characters of milestone status) was edited in 8 commits since 2026-11-06. | 4 agents, about 9 M | status and counts copied by hand into several files |

Review findings by origin:

- **Gate 3 Opus review** (`a861d2537`, 9.2 M): I1 dead loop on a removed id (same-tick death), I2 a container inside a tunnel (missing state combination), I3 three mutation gaps in the bot tests, minor 2 stale counts, minor 4 picking an occupied hub, minor 7 enter after hub death on the same tick.
- **Ultra review** (cloud, free) on the whole branch after the gate 3 fixes: nine real findings. Three were the new *contained or passenger state* against existing queries: F2 group command, F3 box select and right-click target, F6 retaliation target. F4 mixed air and ground waiters on one pile deadlocked (missing state combination); F5 killer death in the same volley (same tick); F1 HUD text in setup; F7 bot state on a throwaway wrapper (netplay path, design assumption); F8 unvalidated `--faction` (trust boundary); F9 a stale reference departure.
- **The contained state recurs across all three reviews.** Gate 1 finding 1 (the bot targeted contained units) and findings 3–4 (passenger order and free slots); gate 3 minor 4 (`pick_entity`); ultra F2, F3, F6. The gate 3 fixer wrote "drag-select `pick_entities` and `pick_target` still include contained units (not asked)", and the ultra review then raised exactly that. The planning rule covers new *commands* against existing commands; it does not cover a new *entity state* against existing queries.
- **Post-ultra Opus review** (`ab0bbf10c`): the map converter still wrote 3×3 piles (tool against data), Gd9 never discriminated (mutation gap), the Pl1 corner case, and the open two-helicopter lockout ruling.

### 3. Coordination

- **User questions:** 12 `AskUserQuestion` and 7 `PushNotification` in `77c02dce`; the user picked the recommended option in 9 of 11 answered choices. Over two days 66 of 90 recorded answers were the recommended option.
- **Avoidable by a default:** the five G3.5 questions (diagnose first), and the Lb2 question, where the recommendation was to relax an assertion that turned out to hide the playtest bug.
- **Unattended mode worked once Opus decided** [evidence]. After the user's 17:00 instruction ("decide as many things unattended as you can, spawn an Opus high agent if unsure") there was one question in 3.4 h (the rendered tail), and four Opus decision agents settled the cycle design, the ground model, Fm1 (200 → 400 boxes) and the harness speed-up. The user signed off all five open items in one message at 19:31.
- **Status pings:** six user status questions in `77c02dce` ("is the worker agent on the right track? This is taking forever…", "I can see many of the commands failing in the harness agent"), all during the long harness run. 13 task notifications reached the user's view.

### 4. What worked and should stay

- **Fresh subagent per task with a short return** [evidence]: G3.1–G3.4 took 10–23 min and 2.4–7.5 M each, no restarts, no status reconstruction.
- **Opus for decisions, Sonnet for execution** [evidence]: the Opus decision agents were the best value per token: `a562780fe` (8 min, 3.8 M) found the Fm1 cause first time; `a2339182d` found the 27× harness speed-up; `a38d5967b` overturned a wrong plan assumption.
- **Measured parity instead of formulas** [evidence]: the formula in the parity research was 6.6–37 % off the measured cycle; the measured table drove a data-only fix that lands every gated row within 2 %.
- **Mutation checks named in the record** [evidence]: they found the non-discriminating Gd9, and the gate 2 and gate 3 records name the production change behind each test.
- **The ultrareview base-commit trick** [evidence]: `/ultrareview 4c6cb53` with the merge base reviewed the whole branch (113 files, +6,650/−965) for free and found nine real defects after a full Opus gate review.
- **Read-only research agents writing one named doc** [evidence]: economy parity, placement rules and Fly Sprites each cost 0.3–1.8 M and never collided with an implementer.
- **Lean ponytail reviews** [evidence]: 0.3–0.6 M each; gate 2 cut 88 lines for 52.

## Recommendations (prioritised)

1. **Run suites in the foreground with a long timeout; wait only by notification** [evidence]. Rule: every suite, benchmark, netplay or lint call passes `timeout: 600000`; anything longer runs with `run_in_background` and the agent ends its turn or uses `Monitor` with `description` and an until-loop. Never `sleep N; cat`. Gain: removes most of the 57 timeouts, 37 waiting errors and 321 poll requests (about 45 M per two days, 5 %). Cost: one paragraph. Where: `docs/milestone-prompt.md` (task brief), `AGENTS.md` "Verification".
2. **One `tools/run_checks.sh` that runs and summarises** [evidence + judgement]. It prints, in one call, the load average, the tree id (`git rev-parse HEAD` plus `git stash create` or a diff hash), and only the summary lines of suite, lint, warnings, Python checks and optionally benchmark or netplay, with `--only=<suite or case>` passed to the runner. It appends one line to a baseline cache file keyed by tree id, so the next task subagent skips its baseline when the coordinator just committed that exact tree. Gain: fewer full runs (6–33 per task today), no hand-copied counts, no 120 s timeouts. Cost: a small shell script plus a case filter in `game/tests/run_tests.gd`. Where: `tools/`, `docs/milestone-prompt.md` session start step 3.
3. **Give the benchmark an accepted-rows exit code** [judgement]. Keep printing every exceeded row; return 0 for a clean run, 3 when only rows listed in the ledger as user-accepted are exceeded, 1 otherwise. No budget changes, so the "never loosen" rule holds. Gain: 13 of 30 runs stop needing a manual log read. Cost: small. Where: `tools/run_benchmark.sh`, `docs/reference/performance.md`.
4. **Extend the interaction rule to new entity states** [evidence]. Planning rule: every new entity state (contained, passenger, hole, under construction) gets a row against every existing query and command: pick, box select, right-click target, group command, bot targeting, retaliation, splash, salvage. A fixer that sees a sibling case "not asked" fixes the class or returns BLOCKED. Gain: the contained-state class gave about eight findings across gate 1 (findings 1, 3, 4), gate 3 (I2, minor 4) and ultra (F2, F3, F6). Cost: one bullet. Where: `docs/milestone-prompt.md` "Planning rules" and the task brief.
5. **Never recommend relaxing an assertion; an assertion that fails on real behaviour is a defect until a measurement says otherwise** [evidence]. Lb2 and gate 2 M6 both pointed at the shared dock cell 3.5 h before the playtest did. For any system tuned against Zero Hour, add an outcome test (rate, time, count) next to the invariant test. Gain: the economy rework would have started at G3.1, not after a playtest. Cost: none. Where: `docs/milestone-prompt.md` "Stop conditions".
6. **Diagnose before asking; route diagnosis to Opus** [evidence]. When a stop is a failed check with an unknown cause, the coordinator dispatches an Opus (high) diagnosis agent at once and asks the user only with a diagnosis and options. Ask only for design or contract changes, budgets and approvals. Gain: the G3.5 chain (five questions, one withdrawn diagnosis) becomes one question; Fm1 shows the Opus route takes about 8 min. Cost: about 4 M per diagnosis. Where: `docs/milestone-prompt.md` "Unattended run", model routing in `prompt.txt`.
7. **Profile any measuring tool before a long sweep** [evidence]. Before a sweep longer than 15 min: one measured row, its wall time, the projected total, and a check of the obvious caps (frame cap, lanes, batch step). A Sonnet tool-building task over 30 min gets an Opus review of the tool first. Gain: the 27× harness speed-up would have saved most of the 157 min run and the six status pings. Cost: a few minutes. Where: `docs/reference/zero-hour-parity-harness.md`, `docs/milestone-prompt.md` planning rules.
8. **Split the verification file and keep counts out of prose** [evidence]. Close each gate into its own archive file (`m7-verification-gate1.md` …) and keep the live file to the resume record, the open rulings and the current gate. README, AGENTS.md, session notes and plans carry no case or check counts and no milestone status sentence beyond one line; they link the verification file. Gain: the 1.6 M characters re-read from one 152 KB file shrink to the live part; fewer doc-reconciliation agents (four in two days); a smaller AGENTS.md also helps every request's cache. Cost: one mechanical split per gate. Where: `docs/milestone-prompt.md` "Resume record", `AGENTS.md` line 7, README.
9. **Restart the coordinator at phase ends, not only at stop gates** [evidence]. Phase ends: exit gate reached, a review's fixes committed, a side project (ultrareview mechanics, machine setup) finished. Simulated saving on `77c02dce`: 62 % of its 54.8 M. Cost: one resume-record write per restart. Where: `docs/milestone-prompt.md` "Unattended run".
10. **Plan writers get a bounded reading list** [evidence + judgement]. The gate 3 and M6.5 planners each passed 530 k context. Give them the design, the active gate outline, the decisions list and the code paths it touches, never the whole verification log; write one gate per agent. Gain: roughly half of 79 M per two plans (estimate). Where: `docs/milestone-prompt.md` "Planning rules".
11. **Briefs carry paths, not numbers; stop lines carry their derivation** [evidence]. The 10-units-per-cell brief and the 3.6× line were both numbers without a source or formula. A brief names the doc that holds the constant; a plan stop condition states how its threshold was derived. Gain: avoids a revision round like `a38d5967b`. Cost: none. Where: task brief template, planning rules.
12. **Fixtures relative to layout, timings from definitions** [judgement, from evidence]. Supply and economy tests place depots and piles relative to a layout helper and read load and unload ticks from the definitions, so a footprint or timing change moves no literal. Gain: the 38 position-only fixture failures and the T4 literal edits disappear. Cost: one refactor of `test_supply.gd` helpers, in its own task. Where: `game/tests/`.
13. **One playtest finding, one order: research, decide, then fix** [evidence]. A fixer that depends on research starts after it, not beside it. A new scope request from the user mid-task goes to a new task with its own brief instead of being pushed into a running agent. Gain: the four pin re-measurements and the idle red tree of the economy rework. Where: `docs/milestone-prompt.md`.

Not recommended: more reviewers per gate. The data show one Opus gate review plus one free ultra review per branch and one lean review is enough; the ultra review found what the gate review missed because it saw the whole branch, not because a second local reviewer was needed.

## Standard task brief (proposal for recommendation 1, 2, 4, 11)

```text
Task: <one behaviour>  Model/effort: <sonnet medium | opus high>
Read: AGENTS.md; resume record (docs/reference/mN-verification.md lines 5-20); plan task <heading> via rg -n '^#' then that range
Owns: <files>   Must not touch: <files other agents own>
Facts: <doc path and line for every constant; no numbers copied here>
New state or command: <list>; interaction rows required against <queries/commands>
Red/Green/Stop: as in the plan task contract
Checks: sh tools/run_checks.sh [--only=...] with timeout 600000; background only for runs > 10 min, then wait by notification
Return: at most ten lines: GREEN or BLOCKED, counts, tree id, changed paths; no logs
```

## Limits

- Token counts are processed volume, not money; Opus and Sonnet prices differ.
- The poll cost counts whole requests that only waited; some of those requests also read a log.
- Wall-time totals include concurrent agents and the user's own machine load (WoW sessions).
- Review-finding classes are this analysis's reading of the records in `m7-verification.md`, not the reviewers' own labels.
- Not checked: Codex sessions, CI time, and whether the earlier retrospective's items 8–10, 13 and 14 were adopted since.
