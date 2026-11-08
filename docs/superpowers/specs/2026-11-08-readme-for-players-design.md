# README for players (design, approved by the user 2026-11-08)

Small docs-only task, not a milestone.

## Intent

The repository is public. Visitors want to know what Wargrid is and how to play it; today about two thirds of `README.md` is milestone status, CI runs and hosting notes for the agent workflow. Nothing is hidden: the workflow content moves, it is not deleted. The development and milestone flow must keep working unchanged (user, 2026-11-08).

## Goals and non-goals

- Goal: a player-first README with a short tech section for technical readers.
- Goal: every agent entry point (AGENTS.md, kickoff, wrap-up, session notes) finds status, setup and commands in the new file.
- Non-goal (user): controls, factions or a how-to-play guide; players know Command & Conquer.
- Non-goal: rewriting or pruning the moved text, or historical prose that mentions the README.
- Anti-goal: a session that runs `/kickoff` after this change and cannot find status, commands or the next action.

## Approaches

1. **README for players plus one `docs/development.md` with everything moved** (picked): one new home, headings kept, so anchors move with them.
2. README with a "for developers" second half: defeats the intent.
3. Several new files (relay, release, CI): more links to keep in sync for no reader gain.

## Design

- **`README.md`**: logo, two-sentence pitch, the existing screenshot; **Play**: browser link, desktop zips with the unsigned-build steps (moved up from Release), online in one line (Create gives a code, a friend joins with it, both on the same version); **Status**: three lines; **How it's built**: the current "How it works" paragraph plus a five-line folder map (`game/`, `relay/`, `protocol/`, `tools/`, `web/`); one line on AI-agent development linking to `docs/development.md`; **License** unchanged.
- **`docs/development.md`**: every other current README section, moved verbatim with its heading (Start here, Milestone history, Working tree and controls, Setup and commands, Relay, Hosting, Browser build, Release, Local references); only relative links are fixed for the new path.
- **Root `prompt.txt`** (the finished M7 handoff) moves to `docs/m7-prompt.txt`, like the M3-M6 handoffs; `docs/milestone-prompt.md`'s generic root `prompt.txt` for future runs stays.
- **Pointers updated**: `AGENTS.md` lines that name README as the home of status, setup, commands and acceptance evidence, and its M7 handoff line; `docs/kickoff.md` steps 1 and 4; `docs/wrapup.md` step 4; `docs/session-notes.md` header; the blueprint's live ownership lines (status line and the documentation-ownership line near the end; §7.1 M0 history stays); the `README.md#relay` links in `docs/reference/relay-stack-spike.md` and the M5 plan; `docs/reference/release-verification.md` "README > Release".
- **Unchanged**: `.claude/commands/kickoff.md` and `wrapup.md` (they only call the docs files); `tools/package_release.py` (its own `README.txt`).

## Verification

1. Scoped `rg` for `README` over the repo's docs and `AGENTS.md`: every hit is a swapped pointer, historical prose, an external README or the zip `README.txt`.
2. Link and anchor check over the changed files.
3. A fresh subagent with no context does a dry `/kickoff` read and must find current status, commands and the next action without the README.

## Calls made by Claude (user may override)

- The old 48 × 32 screenshot stays until a rendered Dry Wells shot is approved.
- Moved text stays as written apart from link fixes.
