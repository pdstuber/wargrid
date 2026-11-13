# P2 "You clicked, we heard": design

Status: questionnaire done with the user 2026-11-13; this document awaits the user's approval. Answers tagged "(user, 2026-11-13)" are the user's; everything else is the agent's call and says so. Scope source: [packages](../../packages.md) Day lane P2 row and "P2 additions"; findings F1, F4, F5 in [`docs/STATUS.md`](../../STATUS.md#findings-list).

## Why

P2's focus card asks: does every order feel heard? Today a unit order is silent; only buttons play the `click` cue (`sound_player.gd` `_watch`). The package also carries small menu and playtest-form fixes the user reported, and three measurements that feed P3's movement design and the order-controls package's forward budget table.

## Goals

1. Every unit order gets one spoken acknowledgement at click time, offline and online.
2. F4: in-game music shuffled per match.
3. Menu quick wins: launcher grouped into sections, relay URL under an "Advanced" fold, F5 paste bug reproduced and fixed (or reported "not reproduced").
4. F1: a scale legend in the after-match form and the focus card docs.
5. Riders: browser against native team-match measurement; a late-game 3v3 canary (report-only); a recorded playtest match as a benchmark row.
6. Exit: a new P2 focus card is playtested, problems in its focus are fixed, other findings go on the findings list.

## Non-goals

- No selection voice (Zero Hour `VoiceSelect`); it can come with control groups in the order-controls package (user, 2026-11-13).
- No per-unit or per-faction voice sets (user, 2026-11-13: per role).
- No launcher redesign: same controls, regrouped (user, 2026-11-12).
- No simulation, trace or replay change. Sound is presentation only (sound spike rule).
- No speech engine or model in the repository.

## Anti-goals

- A voice that lags the click online (that is what "on acceptance" would have cost).
- Chatter: overlapping unit voices under fast clicking.
- Offline, a voice for an order the game already knows is invalid.

## Reference behaviour

All three reference engines play the order voice in input code, at the moment the click becomes an order and is sent, not on simulation acceptance:

- Zero Hour, `GeneralsGameCode` @ `afc2a103f`, `Core/GameEngine/Source/GameClient/MessageStream/CommandXlat.cpp:1048-1054`: after the move/attack message is appended to the outgoing stream ("only make sounds if we really did the command messages"); `pickAndPlayUnitVoiceResponse` (`:435`) loops the selection and lets special lines (crush) upgrade the plain move line (`:453-457`).
- OpenRA @ `b4d95a5671`, `OpenRA.Mods.Common/Widgets/WorldInteractionControllerWidget.cs:191-193`: orders built from the click, `PlayVoiceForOrders()`, then issued; the first unit with a line for the order speaks (`OpenRA.Game/VoiceExts.cs:52-68`).
- Recoil @ `a0240a9b5c`, `rts/Game/SelectedUnitsHandler.cpp:272-278`: `SendCommand(c)`, then a random `ok` sample of the first selected unit on its own unit-reply channel.

## Approaches (order voice hook)

- **A. In `_submit`, where the order leaves the input code (chosen, user, 2026-11-13).** Same as all three reference engines. Offline (`skirmish_main.gd` `_submit`, after `super._submit` issues locally) and online (`online_main.gd` `_submit`, at `_lockstep.submit`).
- B. Inside `_show_hint` (the ring hint drawing). Less wiring; rejected: ties sound to drawing code that covers only some command types, and no reference engine does it.
- C. On simulation command results. Rejected (user, 2026-11-13): online it lags by the input delay (4 ticks) plus the round trip.

## Decided

### Order voice

- **Lines per role, shared by all factions (user, 2026-11-13):** three roles. Infantry and vehicles: a "move" line and an "attack" line. Workers: a "move" line and a "work" line. Two variants each, 12 lines in all. Wording is a default the user edits on the A/B page (proposed: "Moving." / "On my way." / "Engaging." / "Target acquired." / "Getting to work." / "On it.").
- **Role from definitions (agent's call):** a kind with `builds` or `collects` is a worker (Bulldozers, Laborer, Supply Truck, Supply Helicopter); `class: "infantry"` is infantry; everything else is a vehicle.
- **Timing: on click (user, 2026-11-13).** Offline, a locally rejected order plays only the error cue, never the voice (user, 2026-11-13). Online, the voice plays on submit; a later rejection adds the error cue as today.
- **Which orders speak (user, 2026-11-13): unit orders only.** Agent's mapping: `move`, `enter`, `unload` give "move"; `attack`, `attack_move` give "attack"; `gather`, `build`, `resume_build` give "work". `stop`, `set_rally`, `produce`, `cancel_*`, `defence_attack` stay silent apart from any button click.
- **Speaker in a mixed selection (user, 2026-11-13):** the first selected unit whose role has a line for this order (OpenRA style). A worker in a mixed army never blocks an attack line.
- **Fast clicks (user, 2026-11-13):** one unit voice at a time; an order given while a unit line plays stays silent (skip, not cut).
- **Announcer overlap (user, 2026-11-13):** unit voices and the announcer play on separate players, both on the `Voice` bus under the Voice slider; they may overlap.
- **Variant choice (agent's call):** presentation randomness (not the match seed), so replays and traces cannot change.

### Voice assets

- **Voices:** Piper male voices john, norman and bryce, re-downloaded from `rhasspy/piper-voices` at the pinned revision `e7229f7d33a10e145e109b886d661984201ac3c4` (user approved the re-download, 2026-11-13). Licence notes in `~/projects/wargrid-sound-work/sourcing/voice/VOICES.md` (john, norman: public domain; bryce: public domain with a base-model caveat).
- **Pick on an A/B page in Firefox (user, 2026-11-13):** each role's lines in 2-3 voices and 2-3 radio treatments (light radio filter, the announcer's `c1n` vocoder, clean), labelled, opened with `open -a Firefox`. The user picks voice and treatment per role.
- **Pipeline as for the announcer (user, 2026-11-13):** raw renders and the A/B page stay in `~/projects/wargrid-sound-work/` (outside the repo, the existing `render.py` extended); picked lines go through a new unit-voice entry in `tools/audio/synth.py` into `game/audio/voice/units/`, with rows in `game/audio/CREDITS.md`. No engine, model or raw render in the repo.

### Menu (launcher)

- **Three headed sections (user, 2026-11-13):** Play offline, Play online, Settings; Credits and legal at the foot. Relay URL under a closed "Advanced" fold in Play online.
- **Shared match row (agent's call):** your faction and the map also feed online play (`launcher.gd` `_process` puts `MatchSettings.for_map(_map_id())` into the create hello; `_start` passes the own faction to the online game), so they sit in a short "Match" row above both play sections. Opponent and Start are offline only.
- **Layout test:** a headless test asserts sections exist, the fold starts closed and controls do not overlap (AGENTS.md: HUD changes get a headless layout test).
- **F5 (user report, 2026-11-12):** reproduce first, by the user's hand on the test app (`wargrid-web-test`, https, test relay) during the batched browser session: Copy the room code, then paste a URL into the relay field (user, 2026-11-13); a scripted repro could miss a gesture- or origin-dependent bug. Agent's hypothesis, unverified: Godot web keeps its own clipboard buffer after `DisplayServer.clipboard_set`, so a later paste returns the room code instead of the system clipboard. Not reproduced means "not reproduced" in status and notes, and no speculative fix.

### Music (F4)

- **Plain shuffle (user, 2026-11-13):** the five `PLAYLIST` tracks shuffled once per match with presentation randomness, then looped in that order; the menu keeps its one track.

### Scale legend (F1)

- **One line under the 1-5 rows (user, 2026-11-13):** "1 strongly disagree … 5 strongly agree" in the after-match form (`game/scripts/playtest/session_form.gd`) and the same line in the focus card docs.

### Riders

- **Browser against native team match:** the bot 3v3 team match (`game/scripts/debug/team_match.gd`) natively and in the Firefox web bench (`tools/serve_web_bench.py`, dedicated profile, never the user's own Firefox), on the Mac mini. Both web builds (user, 2026-11-13): the production single-threaded build and the threaded build in `~/projects/wargrid-perf-work/threaded-deploy/`. Feeds the desktop-only 3v3 decision and the order-controls package's forward budget table. Agent's call: the rider reports mean, p95 and worst tick per build without a pass/fail threshold; the 3v3 decision stays the user's. Opens a browser: ask first, batched with the A/B page and the F5 repro.
- **Late-game 3v3 canary, report-only (user, 2026-11-13: synthetic):** a new combat workload layout that builds a late-game board directly: six seats in two teams across all three factions, built bases, about 210 mixed units (the goal row) in contact. Agent's call: bots run, because their decisions are part of late-game cost. Report-only: per-zone mean, p95, worst tick; no budget, no gate.
- **Recorded playtest match row (user, 2026-11-13: P2's own playtest):** the command log from P2's focus card session, replayed headless as a timed benchmark row. Report-only, no budget; P2 closes at the playtest and the row follows as its own commit, not blocking the exit (user, 2026-11-13). The command log (commands, map, seed, build id; no screenshots or names) is committed as a fixture under `game/benchmarks/` so CI and anyone can rerun it (user, 2026-11-13). Agent's call: the offline match of the session, which the command recorder already captures.

### Focus card

A new card in `game/data/playtest/focus.json` for P2: give orders offline and online with each role; does every order feel heard; menu sections and Advanced fold; music differs between matches; paste a relay URL after Copy (F5). The wording is the builder's.

## Constraints

- Typed GDScript; sound stays out of the simulation; tests through the [simulation interface](../../reference/sim-interface.md).
- Read the sound spike [design](2026-11-08-sound-spike-design.md), [evidence](../../reference/sound-spike.md) and [plan](../plans/2026-11-08-sound-spike.md) before touching sound code.
- Gates: `sh tools/run_tests.sh`, `run_lint.sh`, `run_warnings.sh`, `run_python_checks.sh` (synth change), `run_shell_checks.sh` if a script changes, `check_public.sh`; `sh tools/run_benchmark.sh` plus a ledger row at the exit gate, and a rendered benchmark rerun because presentation changed (window: ask first, batch).
- Headless playback stays off (`DisplayServer.get_name() != "headless"`, as `sound_player.gd` and `music_player.gd` do), so tests do not leak audio resources.

## Left to the builder

- Task order (proposed: voice hook and tests with placeholder WAVs, then assets after the A/B pick; menu, F4, F1; riders; focus card; playtest; recorded row).
- Exact line wording after the A/B page; radio treatment parameters.
- The canary's map, unit mix and run length; the scene layout code; test names.
- How `SoundDirector` exposes the role and line mapping (keep it a small table, like `sound_cues.gd`).
