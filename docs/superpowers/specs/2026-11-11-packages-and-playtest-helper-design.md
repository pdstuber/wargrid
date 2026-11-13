# Packages and the playtest helper: design

Status: approved by the user 2026-11-11 (night); questionnaire complete. User answers are recorded in [design answers](../../reference/design-answers-2026-11-08.md#planning-overhaul-packages-and-playtest-tooling-user-2026-11-11-night); this document marks everything else as the agent's call. Updated by the package review (user, 2026-11-13): P1.1 added, P2 and P5 rescoped, canary moved to P2, a night lane for engine packages; the current order lives in [packages](../../packages.md), not in the table below.

## Intent

Milestones deliver too much to playtest at once (user). The M7 exit playtest is still open as a long checklist, the art-lab defaults have not been seen in a real match, and the M6 fixes were checked headless only. Shipping is not the bottleneck (five releases in four days); checking is. The user wants:

1. **Packages:** small units of work, each giving Wargrid players something they can feel, shipped often and playtested in one short session.
2. **A playtest helper:** the build tells the player what to look at, and turns reactions into feedback the agent can act on without guessing.

Success: a new package to play every two to three days, each playtest done in 15 to 20 minutes, and every finding traceable to a moment in a replayable match.

## Goals

- Re-cut the roadmap into packages: the next five in detail, the rest of blueprint §7 roughly.
- Build the playtest helper as the first package (P1).
- Clear the open playtest backlog in three short focus sessions with the helper (all three cards ship with P1). Only card 1 is P1's blocking focus (user): findings from cards 2 and 3 go on the findings list unless they block play.
- Write `docs/packages.md` and `docs/STATUS.md` and link them from blueprint §7.

## Non-goals

- Online collection of feedback, analytics, accounts, telemetry.
- Video recording, voice notes.
- Automatic detection of every checklist item (only a small fixed list of triggers, see below).
- Re-designing milestones beyond P5 in detail.

## Anti-goals (a failure even if it works)

- Any change to simulation behaviour or a moved simulation trace from the helper.
- A helper that makes a session longer than 20 minutes or interrupts play online.
- Screenshots or notes landing in the public repository.

## Constraints

- `AGENTS.md`: typed GDScript, presentation separate from the simulation, headless tests, HUD changes get a headless layout test, lint and warnings pass, no game window without asking.
- Determinism rules: the helper only reads `view_state()`, `snapshot()` and the command stream; it never writes simulation state.
- The controller chain (`main.gd` → `base_main.gd` → `skirmish_main.gd` → `online_main.gd`) stays until FIX-6; the helper attaches with small hooks, not by growing the chain.

## Package rules (user)

- Mostly every package changes something the player can feel in a match; a pure engine package is allowed now and then, without a playtest.
- Big changes (movement, avoidance) ship behind a toggle key, old and new side by side, before the new one becomes the default.
- Every package goes to the test app (`wargrid-web-test`); a public release bundles a week's packages.
- A problem in a package's focus is fixed before the next package; other findings go on a list that orders later packages.
- Each package may carry one small engine item ("rider") next to its player change.
- Named P1, P2, ... with a player-facing name; tracked in `docs/STATUS.md`; the plan lives in `docs/packages.md`; blueprint §7 links to it and keeps design scope.
- The agent drafts each package's focus card from its plan; the user approves it with the plan.

## The next five packages

Order is the user's (interleave controls and movement; interpolation rework before movement); contents within each are the agent's proposal.

| # | Player-facing name | Player change | Focus card (what to try) | Rider |
|---|---|---|---|---|
| P1 | Tell us what you see | The playtest helper (below) | Three backlog cards, one per sitting: (1) FRC economy: right-click collect, pile placement, income feel; (2) FRC tunnels and pickup riders, the Esc menu, online FRC against China or USA; (3) art-lab defaults in a real match, M6 fixes on screen (target box against health bar) | `BUDGET EXCEEDED <rows> (regression ceilings held)` summary line in `run_benchmark.sh`, and a report-only worst-tick line per row |
| P2 | You clicked, we heard | Order acknowledgement sound per accepted order (cue exists in `sound_cues.gd`) | Give orders offline and online; does every order feel heard? | Browser against native team-match measurement (decides desktop-only 3v3) |
| P3 | Camera that follows you | Edge scrolling in window and browser, right-drag pan with short right-click still ordering, Space to last alert, H to Command Center; camera actions off WASD | Pan around a full match without the arrow keys | Write the movement milestone design (scope for P5) |
| P4 | Smooth motion | The interpolation rework (presentation only, folds in T4b), behind a toggle key; changes WB18's shapes by design | Watch a fight with the toggle off and on | Seeded fuzz and invariant test (must land before movement) |
| P5 | Smarter paths (toggle) | Movement milestone part 1 behind a toggle key, scoped by P3's design | Same orders with toggle off and on; note stuck or odd routes | Late-game 3v3 canary workload (report-only) |

**Rough rest (re-planned as playtests come in):** order controls ("Orders that feel yours": control groups in the Zero Hour layout, Shift-queued move points, Shift-placed building queue, Ctrl force-attack, idle-builder key; rider: forward budget table after P2's measurement); movement part 2 (toggle becomes default); minimal real HUD (credits and power numbers, production buttons with hotkeys, minimap rectangle, base-under-attack alert); controller flattening (FIX-6) together with the `SimPump` seam, in the HUD packages; unit avoidance behind a toggle; fog of war (before ground batch A); ground batch A cut into packages of two or three units each, roster held at four per faction until three recorded 1v1 matches are reviewed; art pass; ground batch B; bots; 3v3 online.

## P1: the playtest helper

All presentation code under `game/scripts/playtest/`, one overlay node the match screens add; the launcher shows the focus card.

### Focus card and checklist

- Data: `game/data/playtest/focus.json`, one entry per focus card (a build may carry several; the launcher lets the player pick one, newest first): `id`, `title`, `new` (lines), `try` (items with `id`, `text`, optional `trigger`), `questions` (three to five, each `id`, `text`, scale 1 to 5 with optional text).
- Launcher: a card "This build" with what is new and what to try.
- In a match: a checklist panel toggled by a key (user: the ` key). Items tick when done.
- Ticking (agent's call): manual by click by default; an item may name a trigger from a small fixed list the overlay can observe without touching the simulation: a command type sent by the local player (`gather`, `build:<kind>`, `attack_move`, ...), the Esc menu opened, a toggle key pressed. Anything else stays manual.

### Mid-match marker

- One key (user: the N key) opens a quick note: Good, Bad, Confusing, plus an optional one-line text. Offline the match pauses while the note is open; online it does not pause.
- Saved per marker: tick, kind, text, camera centre, selected ids, and a screenshot: the viewport image downscaled to about 640 px wide, JPG, base64 inside the session.

### After-match form

- Shown when the match ends or when the player leaves through the Esc menu.
- The focus card's questions, then the session's markers listed again, each with a comment field.
- A "Save session" button writes the session file; skipping is allowed.

### Session file

- A session is one sitting (user): it may hold several matches (a restart or a second match). After each match a short marker review; the focus questions once, when the player ends the session.
- One JSON file per session: `format` (1), build id, focus id, start time, checklist state, answers, and `matches`: each with map, seed, factions, seat, its markers (with JPGs) and its command log.
- Build id (agent's call): the version string plus the commit hash, because `0.11.0-dev` stays the same across several packages.
- Command log: online, `Lockstep.command_log()`; offline, every command that reaches the simulation, recorded where the controller and the bot send them, in the lockstep log's line format so the existing replay path reads both.
- Desktop: written to `user://playtests/session-<time>.json`; the form shows the path and offers "Show in folder". Browser: downloaded through the same path as the desync report (`JavaScriptBridge.download_buffer`).
- The user moves files to `~/projects/wargrid-playtests/` (outside the repository); the agent reads new files at kickoff.
- Agent tooling: `tools/playtest_session.py FILE` prints the focus answers and markers and writes each JPG next to the file; `sh tools/replay_session.sh FILE [--tick N]` replays the command log headless through the existing `--replay-log` path and prints state at each marker tick.

### Scope of the helper

- On by default in the test app and dev builds; off in public releases unless switched on in the settings (user). Mechanism (agent's call): on when the version ends in `-dev` (test-app builds come from `tools/deploy_web.sh test`, releases from CI with a release version), plus a switch on the launcher and in the Esc menu that overrides it (user).

### Tests

- Focus file validation (ids unique, three to five questions, known triggers).
- Marker capture with an injected image source (no window): fields, JPG size bound, base64 round trip.
- Session file schema and the browser branch (injected download Callable, as the desync test does).
- Offline command recording: a recorded session replayed headless reaches the same final state digest as the original match.
- Headless layout tests for the card, checklist, marker dialog and after-match form.
- The simulation suite, traces and netplay pins unchanged.

## Approaches considered

- **A. In-game overlay node (chosen by the user).** Presentation-only, same on desktop and browser, reuses the desync download path; attaches to the controller chain with small hooks until FIX-6.
- **B. Browser-side HTML overlay via `JavaScriptBridge`.** Richer forms, but browser only; desktop would need a second version. Rejected: contradicts "works in browser and desktop".
- **C. Companion Firefox page, game writes marker files only.** Fastest, but the after-match form leaves the game. Rejected: against the user's answer.

## Left to the builder

- Exact layout and styling (use `UiStyle.hud_theme()` and the pause menu's patterns).
- JPG quality and the exact downscale, within about 640 px wide and a per-marker size bound.
- File naming beyond the pattern above.
- How offline command recording hooks in, as long as no simulation trace moves and the replay digest test passes. The existing `--replay-log` oracle builds a human second seat in setup phase; offline skirmish uses an AI seat, preset factions and `start_match`, so the oracle needs extending to read the session's match settings.
