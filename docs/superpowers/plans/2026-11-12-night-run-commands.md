# Night run commands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/prepare-night-run` and `/start-night-run` project commands that turn the hand-made overnight setups into a routine.

**Architecture:** House pattern of `/kickoff` and `/wrapup`: each command file is one line pointing to a section of a new `docs/night-run.md`, which holds both routines. The generic coordinator rules move from `docs/milestone-prompt.md` "Unattended run" into `docs/night-run.md`; the old heading stays (plans link to it) with a pointer.

**Tech Stack:** Markdown, Claude Code project commands (`.claude/commands/*.md` with `description` front matter).

**Spec:** `docs/superpowers/specs/2026-11-12-night-run-commands-design.md`

## Global Constraints

- Public repository: home-relative paths (`~/projects/…`), no private detail, no hostnames; `sh tools/check_public.sh` exits 0.
- Night settings file: `~/projects/wargrid-overnight-work/night-settings.json`; sessions never edit it, they write a proposed copy and a `cp` line.
- Start line: `claude --remote-control --settings ~/projects/wargrid-overnight-work/night-settings.json --permission-mode auto --model sonnet`, then `/start-night-run <handoff path>`.
- Handoffs: `~/projects/wargrid-private/docs/<task>-prompt.txt`, never in this repository.
- Every `ask` rule counts as denied at night (project: `git merge`, `gh pr`, `fly`, `run_game.sh`, `deploy_web.sh`; user: `git push`).
- No new scripts or tools (approach A).

## Review Focus

- `/start-night-run` in a session without `--settings …night-settings.json` or without `--remote-control`: warns, names the missing flag, stops before any coordinator work.
- `/start-night-run` with no argument or a missing handoff path: says so and stops.
- Another session's `godot`/`generalszh` processes running: listed, never killed; the run continues (results are tick-based) unless the handoff includes benchmarks, then it stops.
- A question unanswered overnight: reversible choice becomes a logged ruling, irreversible one parks the task and the run takes the next backup.
- Plans linking to `milestone-prompt.md` "Unattended run" still land on text that tells them where the rules went.

---

### Task 1: Night run doc and commands

**Files:**
- Create: `docs/night-run.md`
- Create: `.claude/commands/prepare-night-run.md`
- Create: `.claude/commands/start-night-run.md`
- Modify: `docs/milestone-prompt.md:28-44` (section "Unattended run")
- Modify: `AGENTS.md` (the `/kickoff` and `/wrapup` line under "Read before changing")

**Interfaces:**
- Produces: `docs/night-run.md` headings `## Prepare`, `## Start`, `## Coordinator rules`, `## Morning`; anchors `#prepare`, `#start`, `#coordinator-rules`, `#morning`.

- [ ] **Step 1: Write `docs/night-run.md`**

Payoff-first intro (two lines: what the commands are for). Then:

- `## Prepare`: (1) read session notes Next action, Deferred list and `docs/packages.md`; offer two or three ranked candidates that suit unattended work, user picks; (2) pick one or two small independent backup tasks; (3) questionnaire rounds, up to four short questions each with a recommendation, `PushNotification` before each round, until no open choice is left; (4) refine the plan for a Sonnet coordinator; (5) fresh Opus readiness review of the plan (vague steps, missing paths, `ask`-rule commands), apply fixes; (6) permission check against the night settings file, proposed copy plus `! cp` line when rules are missing; (7) write the handoff (task, backups, pre-approvals, run-specific rules, start line from Global Constraints); (8) pre-authorized local commit of the repository changes prepare made (user, 2026-11-12), never push; (9) final message: the start line to paste.
- `## Start`: (1) argument is the handoff path; missing or unreadable: say so, stop; (2) `ps -o args= -p $PPID` must contain `--remote-control` and `night-settings.json`; otherwise name the missing flag, give the start line, stop (hybrid start only when the handoff says "hybrid"); (3) `pgrep -fl 'godot|generalszh'`: list other processes, never kill; stop only if the handoff runs benchmarks; (4) `caffeinate -ims -w $PPID` with `run_in_background` (system awake, display may sleep; extra assertions from other tools are harmless), then report `pmset -g assertions` lines naming display sleep so the user sees what else keeps the screen on; (5) post the Task / What / Status table, then run as coordinator under Coordinator rules and the handoff.
- `## Coordinator rules`: the bullets now in `milestone-prompt.md:32-44` (Coordinator, one subagent per task, After GREEN, Diagnose before asking, No leftovers, Long commands, Opus work stays on Opus, compaction), plus: questions may go unanswered overnight, so ask and keep working (reversible: recommended option as `Ruling: <what> — <why> — <cost if wrong>` in the ledger; irreversible: park the task, take the next backup; a later answer overrides) (user, 2026-11-12); after the main task ends or parks, take backups in order.
- `## Morning`: final message plus a morning summary file beside the run's ledger (results, every ruling with its cost, what waits for the user); `/kickoff` asks open choices as a questionnaire.

- [ ] **Step 2: Write the two command files**

Same shape as `.claude/commands/kickoff.md`:

```markdown
---
description: Prepare an unattended night run: pick the work, settle questions, write the handoff
---

Follow docs/night-run.md, section Prepare, exactly.
```

`start-night-run.md`: description `Start an unattended night run from a handoff: machine checks, then coordinate`; body `Follow docs/night-run.md, section Start, exactly. Handoff: $ARGUMENTS`.

- [ ] **Step 3: Replace `milestone-prompt.md` "Unattended run" body**

Keep the heading. Body: one line "Generic coordinator rules for unattended runs: [night run](night-run.md#coordinator-rules); start with `/start-night-run`." Keep only the milestone-specific bullets: Stop gate, No per-task reviewer subagents, plain `git push` only. Delete the moved bullets (no duplicate).

- [ ] **Step 4: Point `AGENTS.md` at it**

In the `/kickoff` and `/wrapup` line, add `/prepare-night-run` and `/start-night-run` → [night run](docs/night-run.md).

- [ ] **Step 5: Verify**

Run: `sh tools/check_public.sh > <scratch>/pub.log 2>&1; echo "exit=$?"` → `exit=0`.
Run: `rg -n 'night-run.md' AGENTS.md docs/milestone-prompt.md .claude/commands` → each file links to an existing heading.
Run in this session (started without night settings): the Start step 2 check `ps -o args= -p $PPID | rg -c night-settings.json` → `0`, so the command would stop with the missing-flag message.
Grep that no moved rule exists twice: `rg -n 'Diagnose before asking' docs` → only `docs/night-run.md` (and the 2026-11-07 retrospective).

- [ ] **Step 6: Review and commit**

`/ponytail-review` on the diff; apply cuts. Fresh Opus review (doc states code facts). Commit after the user's approval:

```bash
git add docs/night-run.md .claude/commands/prepare-night-run.md .claude/commands/start-night-run.md docs/milestone-prompt.md AGENTS.md docs/superpowers/specs/2026-11-12-night-run-commands-design.md docs/superpowers/plans/2026-11-12-night-run-commands.md
git commit -m "Add night-run prepare and start commands" -m "Turns the hand-made overnight setups into two routines; coordinator rules now live once."
```
