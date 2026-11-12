# Night run

`/prepare-night-run` turns an evening into a ready unattended run: the work picked, every open choice settled, a handoff with one start line. `/start-night-run <handoff>` checks the machine and coordinates the run until morning. Design: [night run commands](superpowers/specs/2026-11-12-night-run-commands-design.md). One-time setup: `/config` "Push when actions required" on, so questions reach the phone.

## Prepare

Runs while the user is reachable, at the PC or on the phone.

1. Read the session notes (`~/projects/wargrid-private/docs/session-notes.md`: Next action, Deferred experiments and research) and [packages](packages.md). Offer two or three ranked candidates that suit unattended work (no playtest, no visible window, no push); the user picks.
2. Pick one or two small independent backup tasks (research, reruns, tooling) for when the main task ends or parks.
3. Ask in questionnaire rounds until no open choice is left: up to four short questions per round, each with a recommendation, readable on a phone; send a `PushNotification` before each round.
4. Refine the plan so a Sonnet coordinator can run it: exact paths, verify commands, stop conditions.
5. Dispatch a fresh Opus (high) readiness review of the plan: vague steps, missing paths, commands behind an `ask` rule. Apply its fixes.
6. Check permissions against `~/projects/wargrid-overnight-work/night-settings.json`. Every `ask` rule in `.claude/settings.json` and `~/.claude/settings.json` is denied at night; read them, the plan must not need any. Never edit the settings file; when the run needs a new allow rule or folder, write a proposed copy beside the run's work and give the user a `! cp` line.
7. Write the handoff to `~/projects/wargrid-private/docs/<task>-prompt.txt`: the task and its plan, the backups in order, pre-approved actions (including which local commits are pre-authorized), the run's ledger path (resume record, rulings, morning summary beside it), run-specific rules, and the start line:

   ```text
   claude --remote-control --settings ~/projects/wargrid-overnight-work/night-settings.json --permission-mode auto --model sonnet
   /start-night-run ~/projects/wargrid-private/docs/<task>-prompt.txt
   ```

8. Commit the repository changes this preparation made (local commit, pre-authorized, user 2026-11-12); never push.
9. End with the start line to paste.

## Start

Runs at the PC, in the session started with the handoff's start line.

1. The argument is the handoff path. Missing or unreadable: say so and stop.
2. `ps -o args= -p $PPID` must contain `--remote-control` and `night-settings.json`. If either is missing, name it, print the handoff's start line and stop. A hybrid start (attended settings first) only when the handoff says so.
3. `pgrep -fl 'godot|generalszh'`: list processes of other sessions, never kill them. Tick-based work continues; stop only if the handoff runs benchmarks.
4. Keep the host awake: `caffeinate -ims -w $PPID` with `run_in_background` (system awake, display may sleep; other tools' assertions are harmless). Report the `pmset -g assertions` lines that keep the display on.
5. Post the Task / What / Status table, then coordinate under the rules below and the handoff.

## Coordinator rules

- **Coordinator** (the main session) reads only `AGENTS.md`, the handoff and the resume record. It never reads suite logs, diffs or plan task bodies.
- **One fresh subagent per task** (model per the plan's routing). Its brief names paths, not content: the resume record and the plan task heading. It runs session start steps 1–4 of the [milestone prompt](milestone-prompt.md), does the task test-first, runs lint and warnings, updates the resume record and verification rows, and returns at most ten lines: `GREEN` with counts, exit, marker and changed paths, or `BLOCKED` with the question, the options and its recommendation. It never commits.
- **After `GREEN`** the coordinator checks `git status --short` against the reported paths, makes the local commit if the handoff pre-authorizes it, and dispatches the next task.
- **Diagnose before asking.** Before asking a question that a default or a rule can decide, dispatch an Opus (high) agent to diagnose and recommend (G3.5: five phone questions in 30 minutes). Ask only for what stays a real choice, with the diagnosis and options.
- **Questions may go unanswered overnight** (user, 2026-11-12). `AskUserQuestion` blocks until answered, so a night run never calls it. Instead send a `PushNotification` with the question, the options and the choice taken, write it to the ledger, and keep working: a reversible choice takes the recommended option as `Ruling: <what> — <why> — <cost if wrong>`; an irreversible one parks the task and the run takes the next backup. A reply sent to the session overrides the ruling; continue a blocked subagent with `SendMessage` so its context is kept.
- **Stop conditions are never ruled on.** The [milestone prompt](milestone-prompt.md#stop-conditions) stop conditions (budget exceeded, assertion weakened, contract change, pinned outcome change) park the task for the user; the run takes the next backup.
- **Backups.** When the main task ends, parks or reaches its stop gate, take the handoff's backups in order.
- **No leftovers.** A subagent stops every loop or watcher it started before it returns; after each task the coordinator checks `pgrep -fl 'godot|generalszh'` and closes what the run started, never another session's processes.
- **Long commands.** Every suite, benchmark, netplay, lint and parity call passes `timeout: 600000`. Anything longer runs in the background; wait only for the completion notification or a `Monitor` with an until-loop, never `sleep N; cat`.
- **Opus work stays on Opus.** Plan or outline expansion, diagnosis and gate reviews go to an Opus (high) subagent even when the coordinator runs on Sonnet.
- **Compaction.** If the coordinator compacts, it writes the resume record and ends; the user starts it again. The record is the handoff; the conversation is not.

## Morning

The run ends with a final message and a morning summary file beside its ledger: results, every ruling with its cost, and what waits for the user. `/kickoff` asks the open choices as a questionnaire.
