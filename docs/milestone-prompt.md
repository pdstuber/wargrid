# Milestone prompt

Reusable execution rules for implementing one milestone. A task's handoff `docs/<task>-prompt.txt` names the milestone, its design, plan and verification file, its model choice and anything milestone-specific, then says "follow `docs/milestone-prompt.md`". Rules here do not override `AGENTS.md`; they fill in how a milestone run proceeds. Why these rules exist: [workflow retrospective](reference/2026-11-03-milestone-workflow-retrospective.md).

## Resume record

The milestone verification file (`docs/reference/mN-verification.md`) starts with this block. Overwrite it at every checkpoint; dated evidence rows below it stay append-only.

```text
Resume record (updated <date/time>)
Branch / base commit / working-tree state:
Last green task / next incomplete task:
Changed paths since last commit:
Last command / cases / checks / failures / exit / marker:
Known red case or blocker:
Approved decisions, pre-authorizations used, deferred gates:
Usage so far (python3 tools/session_usage.py <session files>):
Next exact action:
```

## Session start (coordinator steps 1–2; every task subagent steps 1–4)

1. Read `AGENTS.md`, then the resume record. Do not re-read finished tasks.
2. Run `git status --short` and `git log --oneline -3`; compare with the record. A mismatch is a blocker to report, not to repair silently.
3. Run the baseline once: `sh tools/run_tests.sh > <log> 2>&1`, then read only the summary lines. Lint, warnings and `sh tools/run_python_checks.sh` (ruff, mypy and the Python tests) may run at the same time; benchmarks always run alone.
4. Read only the active task: `rg -n '^#' <plan>` for headings, then that task's range, the interfaces it consumes, and decisions recorded since. The full design and plan are read once, at kickoff, in non-overlapping ranges.

## Unattended run

Fresh context per task keeps the token saving of the old restart rule (retrospective item 1) without a manual `/clear` (user, 2026-11-06).

- **Start.** The user runs `claude --remote-control --permission-mode auto --model sonnet` in the repo and says "run docs/<task>-prompt.txt". One-time setup: `/config` "Push when actions required" on, so questions reach the phone.
- **Coordinator** (the main session) reads only `AGENTS.md`, the task's `docs/<task>-prompt.txt` and the resume record. It never reads suite logs, diffs or plan task bodies.
- **One fresh subagent per task** (model per the plan's routing). Its brief names paths, not content: the resume record and the plan task heading. It runs session start steps 1–4, does the task test-first, runs lint and warnings, updates the resume record and verification rows, and returns at most ten lines: `GREEN` with counts, exit, marker and changed paths, or `BLOCKED` with the question, the options and its recommendation. It never commits.
- **After `GREEN`** the coordinator checks `git status --short` against the reported paths, makes the pre-authorized local commit and dispatches the next task.
- **After `BLOCKED` or any stop condition** the coordinator sends a `PushNotification`, asks with `AskUserQuestion` (stays open until answered; reaches the phone over Remote Control), then continues the same subagent with `SendMessage` so its context is kept.
- **Stop gate.** Dispatch the gate reviewer (below), record its findings, notify the user and end the session. Playtest, visible windows, push, PR, merge and outline expansion wait for the user.
- **No per-task reviewer subagents.** One review per stop gate.
- If the coordinator compacts, it writes the resume record and ends; the user starts it again. The record is the handoff; the conversation is not.
- Push only as plain `git push`: the ask rule matches the command prefix, so `git -C … push` would bypass it.
- **Long commands.** Every suite, benchmark, netplay, lint and parity call passes `timeout: 600000` (the suite takes about 78 s; the default 120 s timeout fired 57 times in two days). Anything longer runs in the background; wait only for the completion notification or a `Monitor` with a `description` and an until-loop, never `sleep N; cat` (blocked by the harness; 321 poll requests, about 5 % of tokens).
- **Diagnose before asking.** Before asking the user a question that a default or a rule can decide, dispatch an Opus (high) agent to diagnose and recommend (G3.5: five phone questions in 30 minutes). Ask only for what stays a real choice, with the diagnosis and options. The stop conditions below still need the user.
- **No leftovers.** A subagent stops every loop or watcher it started (until-loops, monitors) before it returns; after each task the coordinator checks `pgrep -fl 'godot|generalszh'` and closes what the run started, never another session's processes.
- **Opus work stays on Opus.** Plan or outline expansion and gate reviews go to an Opus (high) subagent even when the coordinator runs on Sonnet.

## Pre-authorized actions

Granted by the user on 2026-11-03 for milestone runs:

- a local commit after each green checkpoint (short message, never push);
- dispatching the gate review subagent at each stop gate;
- closing any window or background process the run started.

Still require explicit approval: push, PR, merge, visible game windows, design changes, relaxing any budget or assertion.

## Planning rules (used when the milestone plan is written)

- **Risk first.** Name the 3–5 riskiest contracts, interactions and costs. Task 1 writes their failing tests, or a load spike measured against the [performance ledger](reference/performance.md), before any task depends on them.
- **Interactions.** Every new command gets same-tick cases against every existing command and against removal of its target or actor. Every AI policy rule gets a test using the spec's own wording.
- **Benchmarks.** Each workload asserts that its mechanics happen inside the timed window, for example each weapon fires or chases and repaths occur. Startup, mass-order, placement and death spikes are reported separately.
- **Outcome tests.** Never recommend relaxing an assertion; one that fails on real behaviour is a defect until a measurement says otherwise. A tuned system (rates, timings, costs) gets an outcome test against the measured reference (e.g. credits per minute), not only an invariant (e.g. one collector per dock).
- **New entity states.** Each new state (contained, held, masked) is tested against all existing queries and commands (pick, target, validate, retaliate, salvage, bot), and the whole class is fixed at once (about eight findings came from the contained state).
- **Long sweeps.** Before a parity or benchmark sweep expected to take over 15 minutes, measure one row end to end and check for caps (frame cap, rate limits) first; the parity harness ran 157 minutes before a 27x speed-up was found.
- **Briefs state units.** A coordinator brief states units explicitly and checks them in the repo (e.g. 1 cell = 25 world units, [Zero Hour verification](reference/zero-hour-verification.md)) before it is sent.
- **Presentation.** HUD changes get a headless layout test, so that no control overlaps status text.
- **Task contracts.** Each task is written as:

  ```text
  Task: <one behavior>
  Owns: <files or helpers it may change>
  Invariant: <what must stay true>
  Boundary: <the edge or interaction case>
  Red: <named behavioral assertion, not a parse error>
  Green: <named test plus affected suite>
  Stop: <condition that needs the user>
  ```

## Gate review

At each stop gate, dispatch one fresh-context reviewer on the strongest available model. Give it a brief with:

- the changed contracts and the diff scope since the last review;
- the previous rulings and findings, which it must not re-raise unless a ruling is wrong;
- the evidence paths: verification file, ledger, plan section;
- the instruction to name, for each new test, the production change that makes it fail;
- read-only scratch copies only for mutations.

A cloud ultra review (`/code-review ultra`) runs only when the user asks; it is costly and its usage is limited. It reviews a branch against a base, so commit unrelated docs and tooling first on a scratch base branch, merge that into the branch, and review against the scratch base (M7: `m7-ultra-base`, `4c6cb53`; delete the scratch branch afterwards).

An empty or one-line report is a failed review. Record it and dispatch a second fresh-context reviewer at once with a narrower brief. Fix critical and important findings test-first, record rulings for the rest, then restart.

## Exit gate

All of the following, run on the final tree, with each result recorded with the tree it ran on:

- full suite;
- `sh tools/run_benchmark.sh` with a new ledger row, run alone on a quiet host with the `uptime` load average at start and end in the row;
- a rendered rerun if presentation changed;
- CI on Linux and Windows, plus `sh tools/compare_local_traces.sh <run id>` for macOS;
- one substantive review and one lean-only `/ponytail-review`;
- the user's playtest.

Report implemented, verified and pending separately.

## Stop conditions

Stop and ask when:

- a contract or phase order in the approved design would have to change;
- a budget is exceeded (a row the user already accepted as exceeded is recorded with its numbers, not re-asked; `run_benchmark.sh` then exits 1, so name the failing line);
- a pinned outcome changes (winner, a match no longer ending inside its window) or a stress ceiling would need a re-pin: record old and new values and ask for sign-off;
- an assertion would have to be weakened;
- calibration cannot meet a gate within its permitted parameters;
- the resume record disagrees with the tree.

Never skip failures, widen tolerances or silence diagnostics.
