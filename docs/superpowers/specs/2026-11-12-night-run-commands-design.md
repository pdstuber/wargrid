# Night run commands (design, 2026-11-12)

Two project commands that turn the hand-made overnight setups of 2026-11-06 to 2026-11-12 into a routine: `/prepare-night-run` while the user is still reachable, `/start-night-run` at the PC right before leaving.

## Why

Each unattended run so far was prepared by hand: pick the task, ask "enough work for the night?", refine the plan for a Sonnet coordinator, settle questions up front, check permissions, write a handoff with the start line. Handoffs repeat the same coordinator rules. Recurring failures: approval-needing steps (push, game window) denied under the night settings, doubt about which settings file was active, a manual attended-to-night switch, the host going to sleep (2026-11-05).

## Goals

- Prepare: one routine that ends with a ready private handoff and a start line.
- Start: machine checks, then the generic coordinator rules, then the handoff.
- Generic rules live once.

Non-goals: new scripts or tools; changing the night settings file (the user edits it, see below); scheduling runs automatically.

Anti-goals: a run that stalls on an unanswered question or a permission prompt; a handoff that depends on an approval-needing command.

## Decisions (user, 2026-11-12)

- Night settings (`~/projects/wargrid-overnight-work/night-settings.json`) from the start; the hybrid attended-then-switch start only when asked by name.
- Prepare offers two or three ranked candidates from the session notes (Next action, deferred list) and `docs/packages.md`; the user picks.
- Prepare also readies one or two small independent backup tasks (research, reruns, tooling); the run takes them in order when the main task ends or parks.
- A fresh Opus readiness review of the plan always runs before the night: vague steps, missing paths, commands that need approval.
- Prepare asks in phone-friendly questionnaire rounds (up to four short questions, a recommendation each, a push notification before each round).
- The run may always ask, but questions may go unanswered overnight: it asks, then keeps working (the recommended option as a logged ruling when reversible, otherwise it parks the task and moves to a backup); a later answer overrides.
- Sonnet coordinator and implementers; Opus for plan expansion, diagnosis and gate reviews.
- Generic coordinator rules live in `/start-night-run`; `docs/milestone-prompt.md` "Unattended run" links there instead of repeating them; the handoff keeps only task specifics, pre-approvals and the start line.
- `/start-night-run` keeps the host awake with `caffeinate -ims -w <session pid>` (display may sleep) in the background.
- Prepare makes a pre-authorized local commit of the repository changes it made (plan refinements); never a push. The handoff is private (`~/projects/wargrid-private/docs/<task>-prompt.txt`).
- Morning: final message plus a morning summary file (results, rulings with their cost, what waits for the user); open choices are asked as a questionnaire at the next kickoff.

## Approaches

- **A, chosen:** two command files in `.claude/commands/` beside `kickoff.md` and `wrapup.md`; checks done inline (`ps -o args= -p $PPID` shows `--settings` and `--remote-control` and gives the pid for `caffeinate -w`). No new tool.
- B: the same plus `tools/night_preflight.sh`; testable, but a tracked tool used once a night.
- C: one `/night-run prepare|start` command; prepare and start run in different sessions with different settings, so one file mixes two rule sets.

## Shape

`/prepare-night-run`: read the notes, offer candidates, then questionnaire rounds until no open choice is left; refine the plan; Opus readiness review and fixes; permission check (every `ask` rule counts as denied at night; needed allow rules go into a proposed copy of the settings file plus a `cp` line for the user, never an edit of the file itself); write the handoff (task, backups, pre-approvals, start line `claude --remote-control --settings … --permission-mode auto --model sonnet`, then `/start-night-run <handoff>`); local commit.

`/start-night-run <handoff>`: check the parent command line for the night settings and `--remote-control` (warn and stop if missing); check `pgrep -fl 'godot|generalszh'` for another session's processes and report them, never kill them; start `caffeinate`; then run as coordinator under the generic rules and the handoff.

## Left to the builder

Exact wording and order inside the commands; which `milestone-prompt.md` lines move and which stay milestone-specific; the morning summary file location (beside the run's ledger).

Commands are tracked in a public repository: home-relative paths, no private detail.
