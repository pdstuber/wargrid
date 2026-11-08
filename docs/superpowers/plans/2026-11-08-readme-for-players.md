# README for Players Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a player-first `README.md`; every other current README section moves verbatim to `docs/development.md`, and every agent entry point points there.

**Architecture:** documentation only. One new file, one moved file, pointer swaps. No game code, tests or tools change.

**Tech Stack:** Markdown; `rg`; a throwaway Python link checker in the scratchpad.

**Spec:** [README for players design](../specs/2026-11-08-readme-for-players-design.md)

## Global Constraints

- Moved text stays as written apart from relative-link fixes for the new path (design, "Calls made by Claude").
- Moved sections keep their exact headings, so anchors such as `#relay`, `#release`, `#setup-and-commands` keep working at the new path.
- No controls, factions or how-to-play guide in the README (user, 2026-11-08).
- Historical prose that mentions the README stays (AGENTS.md: never rewrite history); only live rules, pointers and links change.
- Edit with the Edit tool; no unasserted `sed` replacements (AGENTS.md).

## Review Focus

1. A relative link copied from the root into `docs/` silently points one level too deep (`docs/reference/x.md` must become `reference/x.md`, `AGENTS.md` must become `../AGENTS.md`). Task 3 step 2 checks every link.
2. An in-page anchor in the moved text whose section stayed in the README (`#license`) must become `../README.md#license`. Task 3 step 2.
3. A new session's `/kickoff` reads the README, finds no status and stops or guesses. Task 3 step 3.
4. `AGENTS.md` still says acceptance evidence or commands live in the README. Task 3 step 1.
5. The README's online line promises something the launcher does not do. Task 1 step 3 takes its wording from `game/scripts/launcher.gd`.

---

### Task 1: Split README into README and docs/development.md

**Files:**
- Create: `docs/development.md`
- Modify: `README.md` (whole file)

- [ ] **Step 1: Create `docs/development.md`** with a one-line intro ("Development status, setup, commands and operations for Wargrid's agent-driven workflow; players start at the [README](../README.md).") followed by these current README sections, in this order, verbatim with their headings: `## Start here` (with the paragraph after its list), `## Milestone history`, `## Working tree and controls`, `## Setup and commands`, `## Relay` (with `### Hosting`), `## Browser build`, `## Release`, `## Local references`. Also move README lines 15-19 (How it works, Status, Developed with AI) to the top as `## Overview`, verbatim.
- [ ] **Step 2: Fix relative links in `docs/development.md`** for its new location: `docs/X` to `X`, root files (`AGENTS.md`, `LICENSE`, `Wargrid_Kickoff_Blueprint.md`, `.github/...`, `game/...`) get `../`, `#license` becomes `../README.md#license`. Anchors of moved sections stay in-page. Absolute URLs unchanged.
- [ ] **Step 3: Rewrite `README.md`** to: title; the logo `<p>` block; the pitch (current line 5, kept); the screenshot and caption (kept); `## Play`: browser link with the current browser note, desktop zips on Releases with the unsigned-build steps copied from the Release section (macOS Open Anyway or `xattr -dr com.apple.quarantine Wargrid.app`; Windows SmartScreen More info, Run anyway), one line on online play worded from `launcher.gd` (Create gives a match code, the friend enters it under Join; both need the same version), from source: Godot 4.7.2 with a link to `docs/development.md#setup-and-commands`; `## Status`: at most three lines (early development; three factions, teams, bot skirmish, online 1v1, maps; latest release from `game/project.godot` history, currently 0.8.0); `## How it's built`: the current "How it works" paragraph plus a folder map of `game/`, `relay/`, `protocol/`, `tools/`, `web/`, one line each; one line "Developed with AI coding agents (Claude Code); plans, decisions and evidence: [development notes](docs/development.md)."; `## License`: unchanged.
- [ ] **Step 4: Check**: `rg -n "^#" README.md docs/development.md` shows the README with Play, Status, How it's built, License, and every moved heading exactly once in `docs/development.md`. `git diff --stat` shows only these two files.

### Task 2: Move prompt.txt and swap pointers

**Files:**
- Move: `prompt.txt` to `docs/m7-prompt.txt` (`git mv`)
- Modify: `AGENTS.md:7,12,21,30,52`; `docs/kickoff.md:5,8`; `docs/wrapup.md:8`; `docs/session-notes.md:3`; `Wargrid_Kickoff_Blueprint.md:6,841`; `docs/reference/relay-stack-spike.md` and `docs/superpowers/plans/2026-11-04-m5-online-spike.md` (`README.md#relay` links); `docs/reference/release-verification.md:16`; `docs/development.md` (the Start here line naming root `prompt.txt`)

- [ ] **Step 1: `git mv prompt.txt docs/m7-prompt.txt`.**
- [ ] **Step 2: AGENTS.md**: line 7 "Current setup and milestone status live in [README](README.md)" and "Remaining acceptance evidence lives in README" name `[development notes](docs/development.md)` instead; line 12 "Start with [README](README.md) for actual project state and commands" becomes `docs/development.md`; line 30 "Keep setup/current status in README" becomes `docs/development.md`; line 52 "Planned commands in README" becomes `docs/development.md`; line 21 "`prompt.txt` is the handoff" becomes "historical handoff `docs/m7-prompt.txt`".
- [ ] **Step 3: kickoff and wrap-up**: `docs/kickoff.md` step 1 reads `docs/development.md` where it reads `README.md`; step 4 "authoritative setup in README" becomes `docs/development.md`. `docs/wrapup.md` step 4 lists `docs/development.md` instead of `README.md`.
- [ ] **Step 4: session notes header** (`docs/session-notes.md:3`): "Setup lives in [README](../README.md)" becomes `[development notes](development.md)`.
- [ ] **Step 5: blueprint**: line 6 "[README](README.md) owns current verification status" and line 841 "[README.md](README.md) records current implementation status and verified commands" point to `docs/development.md`. §7.1 lines 729-745 stay (M0 history).
- [ ] **Step 6: anchors and release**: `README.md#relay` links become `development.md#relay` with the right relative prefix from each file; `release-verification.md:16` "README > Release" becomes "[development notes > Release](../development.md#release)".
- [ ] **Step 7: `docs/development.md` Start here line** naming root `prompt.txt` as the M7 handoff now names `[M7](m7-prompt.txt)` among the historical prompts. This is a link fix forced by the move, not a rewrite.

### Task 3: Verify

- [ ] **Step 1: rg sweep**: `rg -n "README" AGENTS.md Wargrid_Kickoff_Blueprint.md docs .claude/commands -g '!docs/reference/fair-bots-research.md'`. Every hit must be one of: a swapped pointer, historical prose in an old plan, spec, retrospective or verification note, an external project's README, or the zip `README.txt`. List any other hit as a failure.
- [ ] **Step 2: link check**: a scratch Python script in the scratchpad (not committed), run with `python3 -I`, over every file changed in Tasks 1-2: for each Markdown link `[..](target)` with no URL scheme, resolve the path relative to the file and assert it exists; for `#anchor` parts on `.md` targets, assert a heading with that GitHub slug exists (lowercase, spaces to `-`, drop punctuation except `-` and `_`). Expected output: `LINKS OK <n>` and exit 0.
- [ ] **Step 3: cold kickoff read**: a fresh subagent with no conversation context reads `AGENTS.md`, then follows `docs/kickoff.md` step 1 without opening `README.md`, and reports (a) the current status of the converted maps task, (b) the command for the test suite, (c) the next action from the session notes. Pass: all three are answered with file citations and none came from `README.md`.
- [ ] **Step 4: report** the three results, then `/ponytail-review` on the diff. Commit only with the user's approval (suggested message: "Make the README player-first; move dev notes to docs/development.md").
