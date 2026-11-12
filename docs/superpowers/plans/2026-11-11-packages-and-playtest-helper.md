# Packages and Playtest Helper Implementation Plan

**Status: approved by the user 2026-11-11 (night), with the three focus cards as drafted; subagent run (milestone prompt), started by the user explicitly; run done 2026-11-12: exit gate met, card 1 playtested, merged to `main` (`c2013d1`).** User changes at approval: keys ` (checklist) and N (note) instead of F1/F2 (no fn key on a Mac, F1 opens browser help); the helper switch is on the launcher and in the Esc menu.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Run rules: [milestone prompt](../../milestone-prompt.md) (coordinator plus one fresh subagent per task, no per-task reviewers, one Opus review at the stop gate).

**Goal:** P1 "Tell us what you see": an in-game playtest helper (focus card, ` checklist, N marker with screenshot, after-match form, one session file per sitting that replays headless), its benchmark rider, the three backlog focus cards, and the package documents (`docs/packages.md`, `docs/STATUS.md`, blueprint §7 link).

**Architecture:** Everything new lives under `game/scripts/playtest/` and attaches to the controller chain through small hooks: a `CommandRecorder` wraps the simulation for the offline controller and the bot (it forwards `issue_command` and keeps accepted commands), one `PlaytestOverlay` Control in `$HUD` reads the controller through two Callables (`playtest_context`, `playtest_match`), and a `PlaytestSession` (static `current`, mirrored to `user://playtests/current.json`) collects markers, matches and answers across scene changes. The existing `--replay-log` oracle learns the offline match settings (`--factions`) and prints state at marker ticks, so `tools/replay_session.sh` replays any session match and checks its recorded end digest.

**Tech Stack:** Godot 4.7.2, typed GDScript, `Image.save_jpg_to_buffer`, `Marshalls`, `JavaScriptBridge.download_buffer`; Python 3 stdlib for `tools/playtest_session.py`; POSIX sh.

**Spec:** [packages and playtest helper design](../specs/2026-11-11-packages-and-playtest-helper-design.md) (read fully once). User answers: [design answers](../../reference/design-answers-2026-11-08.md), sections "Main branch audit" and "Planning overhaul".

**Model routing:** Tasks Sonnet (mid tier); stop-gate review Opus (high), fresh context. Verification file and resume record: `docs/reference/p1-playtest-helper-verification.md` (created in Task 1). Scratch output: `~/projects/wargrid-p1-work/`.

## Global Constraints

- Branch `p1-playtest-helper` from `main` (the commit that adds this plan) in worktree `~/projects/wargrid-wt-p1`, created by the coordinator before Task 1; the main checkout's branch is never switched.
- Presentation only: `git diff main -- game/scripts/simulation` stays empty. In `game/scripts/net/` only two changes are allowed: `Lockstep.log_lines` (moved from `headless_client.gd`) and the new oracle arguments; without the new arguments the oracle's behaviour and output lines are unchanged. Replay, hash and trace tests and every `sh tools/run_netplay.sh` result line stay as on `main`.
- The helper reads only `view_state()`, `snapshot()`, `tick()`, `match_over()` and the command stream; it never writes simulation state. `CommandRecorder.issue_command` passes the command through unchanged.
- New tests use only the [simulation interface](../../reference/sim-interface.md) plus static data from `definitions/`; `tools/test_sim_boundary.py` (inside `sh tools/run_python_checks.sh`) passes. Reading headless-client or controller privates (`client._sim`, `main._submit`) is allowed, as `test_skirmish.gd` SK22 does.
- No game window in any task before Task 9. Tests inject `image_source` (a Callable returning an `Image`) and `download` (`func(buffer: PackedByteArray, file_name: String, mime: String)`, as `test_online_scene.gd` N2w does) and set `web` themselves.
- Tests never touch the player's real files: every playtest test sets `AudioSettings.path` to a scratch path (as `test_audio_settings.gd` does) and `PlaytestSession.dir` to `user://test-playtests-<pid>`, and removes both at the end.
- Keys (physical keycodes, so layout-independent): ` (`KEY_QUOTELEFT`) toggles the checklist, N (`KEY_N`) opens the marker note; both unused by the game today. Marker kinds: `good`, `bad`, `confusing`. Screenshot: viewport image scaled to at most 640 px wide (aspect kept), JPG quality 0.6, retried at 0.3 if over `MAX_JPG_BYTES` = 98304, else dropped (`jpg: ""`); stored base64.
- Session file `format` 1: `format`, `build`, `focus`, `started`, `checklist`, `answers`, `matches[]` with `mode`, `map`, `seed`, `factions`, `seat`, `end_tick`, `end_digest`, `build`, `result`, `markers[]` (`tick`, `kind`, `text`, `camera`, `selected`, `comment`, `jpg`) and `commands` (lockstep log lines). The top-level `build` is the build of the sitting's first match; each match's own `build` (`PlaytestSettings.build_id()` at match end) is the one to replay against (user, 2026-11-12, gate review I6).
- Build id: `<config/version>+<commit>` (`0.11.0-dev+c7178a9`), `+unknown` without a commit file.
- Helper on by default when `config/version` ends in `-dev`; a stored `playtest/enabled` bool in `user://settings.cfg` overrides it both ways.
- Session files and screenshots never enter the repository: `user://playtests/`, the browser download, `~/projects/wargrid-playtests/` (user inbox) and `~/projects/wargrid-p1-work/` (fixtures). `game/build_commit.txt` is gitignored.
- UI uses `UiStyle.hud_theme()` and the pause menu's patterns (built in code, `Button` + `VBoxContainer`); no new scene files.
- Typed GDScript; `sh tools/run_lint.sh`, `sh tools/run_warnings.sh` and `sh tools/run_tests.sh` pass before each GREEN; Python tasks also `sh tools/run_python_checks.sh`. Every suite, benchmark, netplay and lint call uses `timeout: 600000`, output to a file, summary lines only. New scripts get tracked `.gd.uid` files from the import: list them with the changed paths. New suites go into `run_tests.gd` `SUITES`.
- Living documents written here (`packages.md`, `STATUS.md`) name symbols, not line numbers (audit answer).

## Review Focus

1. **Typing a note never plays the game.** With the N note open, letters (A, S, E, U, M, 1-9) go into the text field and Esc closes the note instead of opening the pause menu. Test in Task 4 (`test_note_typing_is_not_a_hotkey`).
2. **A closed tab or a crash keeps the sitting.** Each finished match is mirrored to `current.json`; the next start resumes the same session instead of starting empty. Test in Task 3 (`test_session_resumes_after_restart`).
3. **The screenshot shows the game, not the note,** and a failed capture (null or empty image, as headless and possibly WebGL give) still saves the marker with `jpg: ""`. Tests in Task 3 (`test_capture_bounds`) and Task 4 (`test_capture_before_dialog`).
4. **Two matches in one sitting stay apart:** markers and commands of a restarted or second match land in match 2, ticks start at 0 again, and each match replays to its own end digest. Tests in Task 1 (`test_restart_starts_new_record`), Task 5 (`test_two_match_session_file`) and Task 6 (replay of that file).
5. **Leaving behaves as before when the helper is off,** and online leaving shows the form without pausing and closes the transport once. Test in Task 5 (`test_leave_flow`).

---

### Task 1: Offline command recording and the replay oracle (risk first)

```text
Task: every command that reaches an offline simulation is recorded in lockstep line format, and the oracle replays it to the same digest.
Owns: game/scripts/playtest/command_recorder.gd, game/scripts/main.gd (_issue seam, menu_open in _physics_process), game/scripts/skirmish_main.gd, game/scripts/online_main.gd, game/scripts/net/lockstep.gd (log_lines), game/scripts/net/headless_client.gd, game/tests/test_playtest_replay.gd, game/tests/test_online_scene.gd, game/tests/run_tests.gd, docs/reference/p1-playtest-helper-verification.md
Invariant: no simulation file changes; SK22 and all netplay scenarios unchanged; oracle output unchanged without the new args.
Boundary: rejected command; bot memory through the wrapper; restart; a dropped command line changes the digest.
Red: test_offline_scene_replays_to_same_digest fails (playtest_match missing).
Green: test_playtest_replay.gd, test_skirmish.gd, test_online_scene.gd, full suite, sh tools/run_netplay.sh (default scenarios).
Stop: the replay digest differs and the cause is inside game/scripts/simulation (a fix there would change the simulation).
```

**Interfaces (produces):**
- `CommandRecorder` (RefCounted): `func _init(sim: Simulation) -> void`; `func issue_command(command: Dictionary) -> Dictionary` (forwards, appends `command.duplicate(true)` when `ok`); `func snapshot() -> Dictionary`; `func tick() -> int`; `func map_data() -> Dictionary`; `func simulation() -> Simulation` (so `Skirmish._bot` keeps its memory on the real simulation, as `SeatSim` does); `func commands() -> Array[Dictionary]`.
- `Lockstep`: `static func log_lines(rows: Array[Dictionary]) -> PackedStringArray`, moved verbatim from `HeadlessClient._command_lines` (comment `# formerly in headless_client.gd`); `_write_logs` calls it.
- `main.gd`: `func _issue(command: Dictionary) -> Dictionary` returns `simulation.issue_command(command)`; `_submit` calls it. `_physics_process` pauses on `menu_open() and _pauses_sim()` instead of `_pause.visible and _pauses_sim()`.
- `skirmish_main.gd`: `var recorder: CommandRecorder`, created in `_create_simulation()` around the new simulation (so `_ready` and `_restart` both get a fresh one); `_step_simulation` calls `Skirmish.issue_opponent(recorder)`; `_issue` override sends through `recorder`.
  - `func playtest_context() -> Dictionary`: `{tick: int, camera: [x, y]` (cells, `Iso.plane_to_world(_camera.position)`), `selected: Array[int]` (`_view_selection()`), `over: bool` (`simulation.match_over()`), `menu: bool` (`_pause.visible`)`}`.
  - `func playtest_match() -> Dictionary`: `{mode: "offline", map: map_path.get_file().get_basename(), seed: match_seed, factions: [factions[1], factions[2]], seat: local_player, end_tick: simulation.tick(), end_digest: StateHash.digest(simulation.snapshot()), result: _result_text(simulation.snapshot().match)` (empty when left early)`, commands: Lockstep.log_lines(recorder.commands())}`.
- `online_main.gd` overrides both: context `over` is `_finished`; record `mode: "online"`, `factions` from `simulation.view_state().players` (`faction`, seat order), `commands: Lockstep.log_lines(_lockstep.command_log())`.
- Oracle (`headless_client.gd`), all optional:
  - `--factions A,B`: `_oracle_sim()` builds `Skirmish.create(true, "ai", {1: A, 2: B}, MatchSettings.map_path(id), starts)`; `_faction_error()` also rejects an unknown entry.
  - `--state-ticks T1,T2,...`: when `sim.tick()` equals a listed tick (before that tick's commands are issued), append and print `ORACLE STATE <tick> <digest> <summary>` to `var state_rows: PackedStringArray`; `static func state_summary(snapshot: Dictionary) -> String` gives compact JSON `{"match": status, "players": [{"id", "credits"}], "units": {owner: count}, "buildings": {owner: count}}`.
  - `--snapshot-dir DIR`: also writes `DIR/tick-<T>.json` (the full snapshot) at each state tick.
  - Always, when the loop ends: print `ORACLE FINAL <tick> <digest>` before `_exit()`. `ORACLE FINAL` is printed on every oracle run, with or without the new args; no consumer parses oracle stdout (`run_netplay.sh` reads `--hash-log`). A listed state tick equal to the end tick also gets its row, after the loop.

- [ ] **Step 1:** In the worktree, create the verification file with the milestone prompt's resume record block, then dated rows.
- [ ] **Step 2: Write the failing tests** in a new suite `game/tests/test_playtest_replay.gd` (register in `SUITES`; restore `SkirmishMain` statics after each case; oracle via a subclass with `_exit` overridden, as `test_skirmish.gd` `OracleClient` does):
  - `test_recorder_logs_accepted_commands`: on `Skirmish.create(true, "ai", {1: "usa", 2: "china"})`, a valid `stop` for player 1's builder at tick 0, sequence 0 is `ok` and `commands().size() == 1`; the same sequence again is rejected and the size stays 1; `is_same(recorder.simulation(), sim)`.
  - `test_bot_through_recorder_keeps_memory`: `Skirmish.issue_opponents(recorder, [2])` at tick 0 leaves `sim.has_meta(Skirmish.BOT_META)` true, and every recorded command has `player == 2`.
  - `test_log_lines_format`: rows at ticks 3, 3, 5 give 2 lines; `Wire.decode(lines[0])` is ok with `seat == 0`, `tick == 3` and both commands in order.
  - `test_offline_scene_replays_to_same_digest`: statics `factions = {1: "frc", 2: "china"}`, `map_path = MatchSettings.map_path("dry_wells")`, `match_seed = 7`, `starts = MatchSettings.starts("dry_wells", 7)`; instantiate `res://scenes/skirmish.tscn` with process and physics off; call `_physics_process(1.0 / 30.0)` 600 times, and at step 30 select player 1's builder and `_submit` a `move` to a cell at least 10 cells away. Then `record.mode == "offline"`, `record.map == "dry_wells"`, `record.seed == 7`, `record.factions == ["frc", "china"]`, `record.seat == 1`, `record.end_tick == 600`, `record.end_digest == StateHash.digest(main.simulation.snapshot())`, and the lines hold commands of both players. Replaying the lines with `{"map": "dry_wells", "seed": "7", "factions": "frc,china", "replay-log": <file>, "oracle-ticks": "600"}` gives `client._sim.tick() == 600` and the same digest; replaying without the player's move line gives a different digest.
  - `test_restart_starts_new_record`: after 30 steps and `_restart()`, `playtest_match().commands.is_empty()` and `end_tick == 0`.
  - `test_oracle_factions_arg`: `--factions frc,china` with an empty log and `oracle-ticks` 1 gives `match.status == "ongoing"` and player factions `frc`, `china`; without it the status is not `ongoing`; `factions` `frc,nope` gives a non-empty `_faction_error()`.
  - `test_oracle_state_rows`: `state-ticks` `0,30`, `oracle-ticks` 31, `snapshot-dir` a scratch dir: `state_rows.size() == 2`, rows start `ORACLE STATE 0 ` and `ORACLE STATE 30 `, and `tick-30.json` parses with `tick == 30`.
  - In `test_online_scene.gd`, `test_online_playtest_record`: with `_online(runner, 1)` and `_peer_packets` through tick 10 and `_run(main, 10)`, `playtest_match().mode == "online"` and `commands == Lockstep.log_lines(lockstep.command_log())` with at least one line; `playtest_context().over == false`.
- [ ] **Step 3:** Run `WARGRID_TEST_ONLY=test_playtest_replay sh tools/run_tests.sh > ~/projects/wargrid-p1-work/t1-red.log 2>&1`. Expected: FAIL on assertions, not a parse error (create `command_recorder.gd` as a bare `extends RefCounted` first so the suite loads).
- [ ] **Step 4:** Implement the interfaces above.
- [ ] **Step 5:** Run the cases, then the full suite, lint and warnings. Expected: PASS, completion marker. Run `sh tools/run_netplay.sh > ~/projects/wargrid-p1-work/t1-netplay.log 2>&1` and compare its result lines with a run on `main` (record both in the verification file). Expected: identical.
- [ ] **Step 6:** GREEN; coordinator commits "Record offline commands for session replays".

### Task 2: Helper switch, build id and focus cards on the launcher

```text
Task: the helper knows whether it is on and which build it is; three validated focus cards ship and show on the launcher.
Owns: game/scripts/playtest/playtest_settings.gd, focus_cards.gd, focus_card_view.gd, game/data/playtest/focus.json, game/scripts/launcher.gd, tools/export_build.sh, tools/run_game.sh, game/export_presets.cfg (include_filter of every preset), .gitignore, game/tests/test_playtest.gd, game/tests/test_online_scene.gd (N5), run_tests.gd
Invariant: launcher behaviour unchanged when the helper is off; audio and graphics settings untouched by saving the switch.
Boundary: duplicate ids; 2 and 6 questions; unknown trigger and unknown kind; corrupt stored switch; release version; missing commit file.
Red: test_shipped_focus_file_valid fails (file missing).
Green: test_playtest.gd, test_online_scene.gd, full suite.
Stop: none.
```

Read the [release workflow plan](2026-11-06-release-workflow.md) before touching `export_build.sh` (AGENTS: release tools).

**Interfaces (produces):**
- `PlaytestSettings` (static): `const COMMIT_PATH := "res://build_commit.txt"`; `static func enabled(version: String = <config/version>) -> bool` (stored bool under section `playtest`, key `enabled`, in `AudioSettings.path`, else `version.ends_with("-dev")`); `static func save_enabled(on: bool) -> void`; `static func build_id(version: String = <config/version>, commit_path: String = COMMIT_PATH) -> String`.
- `tools/export_build.sh` and `tools/run_game.sh` write `game/build_commit.txt` with `git -C "$repo_root" rev-parse --short HEAD`, plus `-dirty` when `git status --porcelain` is non-empty, before running Godot; a failing `git` writes nothing. Every preset's `include_filter` gains `build_commit.txt`; `.gitignore` gains `game/build_commit.txt`.
- `FocusCards` (static): `const PATH := "res://data/playtest/focus.json"`; `const COMMAND_TYPES: Array[String]` = the sim interface's command types without `choose_faction`; `static var chosen: String = ""` (launcher pick; empty means the first card); `static func load_cards(path: String = PATH) -> Array[Dictionary]` (file order, newest first; `[]` plus `push_error` when `errors` is non-empty); `static func errors(cards: Variant) -> PackedStringArray`; `static func trigger_error(trigger: String) -> String`; `static func matches_command(trigger: String, payload: Dictionary) -> bool`; `static func card(id: String, cards: Array[Dictionary]) -> Dictionary` (first card when `id` is unknown or empty).
- Triggers (fixed list): a command type from `COMMAND_TYPES`; `build:<kind>` (matches `building_kind`); `produce:<kind>` (matches `unit_kind`); `esc_menu`; `key:<name>` where `OS.find_keycode_from_string(name) != KEY_NONE`. A kind must exist in `Registry.kind()`.
- `FocusCardView` (PanelContainer, named `FocusPanel`): `func _init(cards: Array[Dictionary], open_count: Callable = func() -> int: return -1) -> void`; built like `CreditsPanel` (full rect, 32 px margins, hidden by default); shows the chosen card's title, "New in this build" lines, "Try" items, an `OptionButton` named `Picker` when there is more than one card (sets `FocusCards.chosen` and redraws), an `OpenSession` label "Session open: N matches" when `open_count.call() >= 0` (Task 3 passes `PlaytestSession.open_count`), and a `Close` button.
- `launcher.gd`: always add a `CheckButton` named `PlaytestSwitch` ("Playtest helper") to `Center/Box`, pressed per `PlaytestSettings.enabled()`; toggling calls `save_enabled` and shows or hides `ThisBuild` (user: the switch is on the launcher too, so a release player can turn it on before the first match). When `PlaytestSettings.enabled()`, add a `Button` named `ThisBuild` ("This build: <card title>") to `Center/Box` right after `Offline`, and the `FocusPanel`; the button opens the panel, which hides `$Center` as `_show_credits` does.

**Focus file** `game/data/playtest/focus.json` (drafts; the user approves or edits them with this plan; card 1 is P1's blocking focus):

```json
[
 {"id": "p1-frc-economy", "title": "FRC economy",
  "new": ["Playtest helper: ` shows this checklist, N drops a note with a screenshot.", "FRC Laborers collect supplies; small piles are separate sources."],
  "try": [
   {"id": "frc_offline", "text": "Start an offline match as FRC on any map"},
   {"id": "collect", "text": "Select Laborers and right-click a supply pile", "trigger": "gather"},
   {"id": "cache", "text": "Place a Supply Cache next to a pile", "trigger": "build:frc_supply_center"},
   {"id": "workers", "text": "Produce more Laborers at the Supply Cache", "trigger": "produce:frc_builder"},
   {"id": "income", "text": "Watch your credits for two minutes"}],
  "questions": [
   {"id": "collect_clear", "text": "Right-click collecting did what I expected"},
   {"id": "placement", "text": "Placing the Supply Cache near piles was easy"},
   {"id": "income_feel", "text": "FRC income felt right for the faction"},
   {"id": "helper", "text": "The checklist and N notes stayed out of the way"}]},
 {"id": "p1-frc-tunnels-online", "title": "FRC tunnels, pickups and online",
  "new": ["Tunnel Hubs and Armed Pickups carry infantry.", "Esc opens the pause menu."],
  "try": [
   {"id": "tunnel", "text": "Build a Tunnel Hub", "trigger": "build:frc_defence"},
   {"id": "enter", "text": "Right-click a Tunnel Hub or pickup with infantry selected", "trigger": "enter"},
   {"id": "unload", "text": "Unload with U", "trigger": "unload"},
   {"id": "esc", "text": "Open the Esc menu and resume", "trigger": "esc_menu"},
   {"id": "online", "text": "Play FRC online against China or USA"}],
  "questions": [
   {"id": "riders", "text": "Tunnels and pickup riders behaved as I expected"},
   {"id": "esc_menu", "text": "The Esc menu was clear"},
   {"id": "online_feel", "text": "The online match felt responsive"}]},
 {"id": "p1-look-and-m6-fixes", "title": "The new look in a real match",
  "new": ["The art lab look is the default now.", "M6 fixes: health bars, result text and enemy order marks."],
  "try": [
   {"id": "zoom_fight", "text": "Zoom in on a fight with the mouse wheel"},
   {"id": "attack_building", "text": "Attack an enemy building and watch its health bar", "trigger": "attack"},
   {"id": "attack_move", "text": "Attack-move with A and a left-click", "trigger": "attack_move"},
   {"id": "enemy_marks", "text": "Check whether enemy move orders show on your screen"},
   {"id": "result", "text": "Finish a match and read the result text"}],
  "questions": [
   {"id": "readable", "text": "Units and buildings were easy to tell apart"},
   {"id": "health_bar", "text": "Health bars stayed readable during attacks"},
   {"id": "look", "text": "The new look fits Wargrid"}]}
]
```

- [ ] **Step 1: Write the failing tests** in a new suite `game/tests/test_playtest.gd`:
  - `test_shipped_focus_file_valid`: `errors(JSON of PATH)` is empty; `load_cards()` gives ids `p1-frc-economy`, `p1-frc-tunnels-online`, `p1-look-and-m6-fixes` in that order.
  - `test_focus_validation`: each gives a non-empty `errors`: two cards with one id; two `try` items with one id; 2 questions; 6 questions; trigger `fly`; trigger `build:no_such_kind`; `key:NotAKey`; a missing `title`. Each valid trigger form (`gather`, `build:frc_supply_center`, `produce:frc_builder`, `esc_menu`, `key:F3`) gives `trigger_error == ""`.
  - `test_trigger_matching`: `matches_command("build:frc_supply_center", {type: "build", building_kind: "frc_supply_center"})` true, with `usa_barracks` false; `"gather"` matches `{type: "gather"}`; `"esc_menu"` matches no command.
  - `test_switch_defaults_and_override`: with the scratch settings path: unset gives `enabled("0.11.0-dev")` true and `enabled("0.11.0")` false; `save_enabled(false)` makes the dev build false; `save_enabled(true)` makes the release true; a stored string value counts as unset; saving keeps the stored audio volumes.
  - `test_build_id`: a scratch commit file with `abc1234\n` gives `build_id("0.11.0-dev", path) == "0.11.0-dev+abc1234"`; a missing file gives `"0.11.0-dev+unknown"`.
  - `test_launcher_focus_card`: at 1280x720 and 1920x1080, with the helper on: `Center/Box/ThisBuild` is visible, inside the viewport and clear of every other `Center/Box` control; pressing it shows `FocusPanel` and hides `Center`; `Close` reverses it; the panel and all its labels lie inside the viewport; the `Picker` has 3 items and choosing item 2 sets `FocusCards.chosen == "p1-frc-tunnels-online"`. With the switch saved off, `ThisBuild` is absent or hidden; pressing `PlaytestSwitch` then shows it and `PlaytestSettings.enabled("0.11.0")` becomes true; `PlaytestSwitch` is inside the viewport and clear of every other `Center/Box` control at both sizes.
  - N5 (`test_launcher_layout`): set the scratch settings path and add `ThisBuild` to its path list.
- [ ] **Step 2:** Run `WARGRID_TEST_ONLY=test_playtest sh tools/run_tests.sh`. Expected: FAIL.
- [ ] **Step 3:** Implement. Check `sh tools/export_build.sh Web ~/projects/wargrid-p1-work/web/index.html` removes `game/build_commit.txt` after packing it (`run_game.sh` leaves it, rewritten on each launch) and that `git status --short` does not list it.
- [ ] **Step 4:** Full suite, lint, warnings. Expected: PASS.
- [ ] **Step 5:** GREEN; coordinator commits "Ship the P1 focus cards and the helper switch".

### Task 3: Marker capture and the session file

```text
Task: a marker becomes a bounded JPG plus its fields; a session holds every match of a sitting and saves on desktop or downloads in the browser.
Owns: game/scripts/playtest/marker_capture.gd, playtest_session.gd, focus_card_view.gd (open_count wiring), game/tests/test_playtest.gd
Invariant: nothing outside PlaytestSession.dir is written.
Boundary: null image, 1x1 image, 1920x1080 image, noise image; unanswered questions; game restart mid-session; corrupt current.json.
Red: test_capture_bounds fails (class missing).
Green: test_playtest.gd, full suite.
Stop: none.
```

**Interfaces (produces):**
- `MarkerCapture` (static): `const KINDS: Array[String] = ["good", "bad", "confusing"]`, `MAX_WIDTH := 640`, `QUALITY := 0.6`, `FALLBACK_QUALITY := 0.3`, `MAX_JPG_BYTES := 98304`; `static func jpg_base64(image: Image) -> String` (`""` for null or empty images and when both encodings exceed the bound; never mutates the caller's image); `static func marker(kind: String, text: String, context: Dictionary, jpg: String) -> Dictionary` gives `{tick, kind, text, camera, selected, comment: "", jpg}`.
- `PlaytestSession` (RefCounted): `const FORMAT := 1`; `static var dir: String = "user://playtests"`; `static var current: PlaytestSession = null`; `var data: Dictionary`;
  - `static func resume_or_open(focus_id: String, build: String) -> PlaytestSession`: returns `current`, else loads `dir/current.json` when it parses with `format == 1`, else a new session (`started` = `Time.get_datetime_string_from_system(true)`); sets `current`.
  - `static func open_count() -> int`: matches in `current` or in `current.json`, -1 when none.
  - `func add_marker(marker: Dictionary) -> void`; `func pending_markers() -> Array[Dictionary]`.
  - `func finish_match(record: Dictionary) -> int`: appends `record` plus the pending markers as `markers`, clears them, writes `current.json`, returns the match index. Each record carries `build` (`PlaytestSettings.build_id()` at match end), so a sitting resumed on a newer build keeps the right build per match (user, 2026-11-12, gate review I6).
  - `func set_comment(match_index: int, marker_index: int, text: String) -> void`; `func set_answer(question_id: String, score: int, text: String) -> void` (score 1-5, 0 unanswered); `func set_checked(item_id: String, on: bool) -> void`.
  - `func write(web: bool, download: Callable) -> String`: JSON of `data`; web: `download.call(bytes, file_name, "application/json")`, returns the file name; desktop: writes `dir/<file_name>`, returns the globalized path (`""` on a write error, and `current.json` is kept). On success removes `current.json` and clears `current`.
  - `func discard() -> void`: removes `current.json`, clears `current`.
  - `static func file_name(started: String) -> String`: `session-<started with ":" replaced by "-">.json`.

- [ ] **Step 1: Write the failing tests** in `test_playtest.gd`:
  - `test_capture_bounds`: null and `Image.create_empty(0, 0, ...)` give `""`; a 1920x1080 flat image gives a JPG that decodes (`Image.load_jpg_from_buffer` of `Marshalls.base64_to_raw`) to 640x360; a 1x1 image stays 1x1; a 1920x1080 seeded-noise image gives either `""` or decoded bytes `<= MAX_JPG_BYTES`; the source image keeps its size.
  - `test_marker_fields`: `marker("bad", "stuck", {tick: 90, camera: [3.5, 4.0], selected: [7], over: false, menu: false}, "QUJD")` has exactly the seven keys with those values and `comment == ""`.
  - `test_session_schema`: a session with two finished matches (one marker each), one answer and one checked item serialises to JSON whose keys are exactly the Global Constraints list, with `format == 1`, `build` and `focus` as given, `matches[1].markers[0].tick` as added, and `answers.<id> == {score, text}`.
  - `test_session_web_download`: with `web = true` and an injected download: one call with `mime == "application/json"`, the file name from `file_name`, a buffer that parses back to `data`; no `session-*.json` under `dir`; `current == null`.
  - `test_session_desktop_write`: `web = false` writes `dir/session-....json`, the returned path ends with it, and `current.json` is gone.
  - `test_session_resumes_after_restart`: after `finish_match`, set `current = null` (a new game start) and `resume_or_open` returns a session with 1 match and the same `started`; `open_count() == 1`; a corrupt `current.json` gives a new empty session.
- [ ] **Step 2:** Run `WARGRID_TEST_ONLY=test_playtest sh tools/run_tests.sh`. Expected: FAIL.
- [ ] **Step 3:** Implement; pass `PlaytestSession.open_count` to `FocusCardView`.
- [ ] **Step 4:** Full suite, lint, warnings. Expected: PASS.
- [ ] **Step 5:** GREEN; coordinator commits "Capture markers and keep playtest sessions".

### Task 4: In-match overlay: checklist and marker note

```text
Task: in a match, ` toggles the card's checklist (manual ticks plus triggers) and N opens a note that captures tick, camera, selection and screenshot; offline the match pauses while it is open.
Owns: game/scripts/playtest/playtest_overlay.gd, game/scripts/skirmish_main.gd, online_main.gd, game/scripts/presentation/pause_menu.gd (opened signal, Playtest toggle), game/tests/test_playtest_overlay.gd, test_pause_menu.gd (E8), run_tests.gd
Invariant: with the helper off, input, pausing and HUD are as on main; online never pauses.
Boundary: N while the pause menu is open or after the match ended; Esc with the note open; typing hotkey letters into the note; switching the helper on mid-match; trigger items already ticked.
Red: test_marker_pauses_offline fails (overlay missing).
Green: test_playtest_overlay.gd, test_pause_menu.gd, full suite.
Stop: none.
```

**Interfaces:**
- Consumes: `playtest_context()` (Task 1), `FocusCards`, `PlaytestSettings` (Task 2), `MarkerCapture`, `PlaytestSession` (Task 3).
- Produces `PlaytestOverlay` (Control, full rect, `mouse_filter` ignore, named `Playtest`):
  - `const CHECKLIST_KEY := KEY_QUOTELEFT`, `const MARKER_KEY := KEY_N`.
  - `var image_source: Callable` (default: `get_viewport().get_texture().get_image()`), `var web: bool = OS.has_feature("web")`, `var download: Callable = JavaScriptBridge.download_buffer`.
  - `func setup(card: Dictionary, context: Callable, match_record: Callable) -> void`; `func set_active(on: bool) -> void` (on: `PlaytestSession.resume_or_open(card.id, PlaytestSettings.build_id())`); `func is_active() -> bool`; `func holds_match() -> bool` (note or form visible).
  - `func observe_command(payload: Dictionary) -> void`; `func observe_menu() -> void`; `func checked(item_id: String) -> bool`.
  - `func open_marker() -> void`: ignored when inactive, `context.over`, `context.menu` or the form is visible; captures context and `MarkerCapture.jpg_base64(image_source.call())` **before** the note becomes visible; `func save_marker(kind: String, text: String) -> void`; `func cancel_marker() -> void`.
  - Children: `Checklist` (PanelContainer, bottom-right, 16 px margin, width 320, one `CheckBox` per `try` item named by item id, visible at match start when active) and `MarkerDialog` (PanelContainer, bottom-centre, width 360: buttons `Good`, `Bad`, `Confusing`, a `LineEdit` named `Text`, `Save`, `Cancel`).
  - `_input`: `, N and Esc (only while the note is open) are handled and marked as handled; other keys are observed for `key:<name>` triggers only while no note or form is open. Clicking a `CheckBox` toggles it and `set_checked`; a matching trigger ticks it once.
- Hooks: `skirmish_main._ready` adds the overlay to `$HUD` with the card `FocusCards.card(session focus or FocusCards.chosen, FocusCards.load_cards())`, `playtest_context` and `playtest_match`, active per `PlaytestSettings.enabled()`; `menu_open()` returns `super() or playtest.holds_match()`; `skirmish_main._submit` calls `observe_command(payload)` when `_error` is empty; `online_main._submit` calls it after `_lockstep.submit`. `PauseMenu` gains `signal opened` (emitted in `open()`, connected to `observe_menu`), and a `Playtest` button "Playtest helper: On/Off" with `signal playtest_changed(on: bool)` that saves through `PlaytestSettings.save_enabled` and calls `set_active`.

- [ ] **Step 1: Write the failing tests** in a new suite `game/tests/test_playtest_overlay.gd` (scratch settings and session dir; scene setup as `test_pause_menu.gd` `_scene` and `_online`; inject `image_source` returning a 1280x720 image and recording `MarkerDialog.visible` at call time):
  - `test_marker_pauses_offline`: offline, N opens the note; 5 `_physics_process` calls leave `simulation.tick()` unchanged; `save_marker("good", "nice")` closes it, the next call advances the tick, and `PlaytestSession.current.pending_markers()[0]` has `kind == "good"`, `text == "nice"`, the tick when N was pressed, the selected ids and a non-empty `jpg`.
  - `test_marker_does_not_pause_online`: online with the note open, `_physics_process` still polls the transport (poll count rises) and `menu_open()` is true.
  - `test_capture_before_dialog`: the injected source saw `MarkerDialog.visible == false`; a source returning `null` still saves the marker with `jpg == ""`.
  - `test_note_typing_is_not_a_hotkey`: with a unit selected and the note's `Text` focused, pushing `KEY_A`, `KEY_S` and `KEY_1` through `runner.root.push_input` leaves `_attack_move_mode` false, issues no command (`playtest_match().commands` unchanged) and puts the letters in `Text`; Esc closes the note and leaves the pause menu closed.
  - `test_marker_ignored_when_menu_or_over`: N with the pause menu open, and after the match is over, opens nothing.
  - `test_checklist_triggers`: card 1; `_submit` of an accepted `gather` ticks `collect`; a rejected one (offline `_error` set) does not; `build:frc_supply_center` ticks `cache`; opening the Esc menu ticks an `esc_menu` item of card 2; ` hides and shows `Checklist`; a manual click toggles `income` and `set_checked`.
  - `test_helper_off_changes_nothing`: with the switch off, ` and N do nothing, `menu_open()` equals `_pause.visible`, and no session exists; the pause menu's `Playtest` toggle turns it on and the checklist appears.
  - `test_overlay_layout`: at 1280x720 and 1920x1080, `Checklist` and `MarkerDialog` (opened) lie inside the viewport and intersect none of `HUD/Status`, `HUD/Economy`, `HUD/Result`, `HUD/Restart` or each other (minimum-size rects, as E8 does).
  - E8 (`test_menu_layout`): the `Playtest` button is visible and clear of every other control.
- [ ] **Step 2:** Run `WARGRID_TEST_ONLY=test_playtest_overlay sh tools/run_tests.sh`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Full suite, lint, warnings. Expected: PASS.
- [ ] **Step 5:** GREEN; coordinator commits "Add the in-match checklist and marker note".

### Task 5: After-match form and leaving

```text
Task: when a match ends or the player leaves, the form reviews that match's markers; ending the session asks the focus questions and saves or discards the file.
Owns: game/scripts/playtest/session_form.gd, playtest_overlay.gd, skirmish_main.gd (_leave, _restart), game/tests/test_playtest_overlay.gd
Invariant: helper off -> leaving and Restart behave exactly as on main.
Boundary: leave before any marker; leave after the match already ended (no second review); restart then a second match; online leave; Esc while the form is open; write error on desktop.
Red: test_leave_flow fails (form missing).
Green: test_playtest_overlay.gd, test_pause_menu.gd, test_online_scene.gd, full suite.
Stop: none.
```

**Interfaces:**
- `SessionForm` (PanelContainer, named `SessionForm`, right side: 16 px margins, width 420, full height, content in a `ScrollContainer`):
  - `signal next_match`, `signal save_requested`, `signal discard_requested`, `signal closed`.
  - `func open_review(session: PlaytestSession, match_index: int) -> void`: that match's markers (kind, tick, text) each with a `LineEdit` named `Comment_<match>_<marker>` wired to `set_comment`; buttons `NextMatch` and `EndSession`.
  - `func open_questions(session: PlaytestSession, card: Dictionary) -> void`: per question a label, five toggle buttons `<qid>_1` ... `<qid>_5` in one `ButtonGroup` and a `LineEdit` `Answer_<qid>`, wired to `set_answer`; then every match's markers again with their comment fields (the design's "session's markers listed again"); buttons `SaveSession` and `DiscardSession`.
  - `func show_saved(where: String, web: bool) -> void`: "Saved to <path>" or "Downloaded <name>", `ShowInFolder` (desktop only, `OS.shell_show_in_file_manager`), `Close`; on `where == ""` "Could not save" plus `SaveSession` again.
- `PlaytestOverlay` gains `signal finished` and `func end_match() -> void` (idempotent per match: `finish_match(match_record.call())`, hides the checklist, opens the review), `func begin_match() -> void` (after a restart: new pending match, checklist back), `func reviewing() -> bool`. It polls `context.over` in `_process` and calls `end_match` once. `next_match`, `discard_requested` and `closed` emit `finished`; `save_requested` calls `write(web, download)` then `show_saved`. Esc is handled (ignored) while the form is visible.
- `skirmish_main._leave()`: when the overlay is active and this match is not reviewed, close the pause menu, `end_match()`, `await playtest.finished`, then `super()`. `_restart()` calls `playtest.begin_match()`. `online_main._leave` is unchanged (it calls `super()` after closing the transport).

- [ ] **Step 1: Write the failing tests** in `test_playtest_overlay.gd` (`main.change_scene` replaced by a recording Callable):
  - `test_leave_flow`: offline, helper on: `leave_requested` shows `SessionForm`, no scene change yet; `NextMatch` changes scene once to `LAUNCHER_SCENE`. Helper off: `leave_requested` changes scene at once and no form exists. Online, helper on: confirming leave closes the transport once (`close_calls == 1`), shows the form, and `NextMatch` changes scene once.
  - `test_match_end_opens_review_once`: remove every player 2 object with `remove_object` (sim interface, as `test_skirmish_scene.gd` does) and step once, so `match_over()`; one `_process` shows the review; a second `_process` and a later leave add no second match.
  - `test_two_match_session_file` (no `remove_object`, so both matches stay replayable): match 1 runs 60 steps with an accepted player `move` and one marker, then `end_match()` is called directly (as a leave would), `NextMatch`, `_restart()`; match 2 runs 90 steps with a `move` and two markers; leave, `EndSession`, rate every question 4 with text on the first, `SaveSession` on desktop. The written file has 2 matches with 1 and 2 markers, `end_tick` 60 and 90, every match 2 marker tick at most 90, `answers` holds each question with score 4, and each `end_digest` equals the digest taken at that match's end. When the environment variable `WARGRID_SESSION_OUT` is set, also copy the file there (fixture for Task 6).
  - `test_web_save_downloads`: same flow with `web = true` and an injected download: one download, `ShowInFolder` absent, `Close` emits `finished`.
  - `test_desktop_write_error_keeps_session`: `PlaytestSession.dir` set to an unwritable path: "Could not save" shows, `SaveSession` is offered again, and `current` still holds the session.
  - `test_form_layout`: at 1280x720 and 1920x1080 with a 3-match, 12-marker session, the form and its visible buttons lie inside the viewport and intersect none of `HUD/Status`, `HUD/Economy`, `HUD/Result`, `HUD/Restart`; no two visible buttons overlap.
- [ ] **Step 2:** Run `WARGRID_TEST_ONLY=test_playtest_overlay sh tools/run_tests.sh`. Expected: FAIL on the new cases.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Full suite, lint, warnings. Expected: PASS.
- [ ] **Step 5:** GREEN; coordinator commits "Add the after-match form and session saving".

### Task 6: Agent tooling for session files

```text
Task: the agent prints a session's answers and markers, extracts its JPGs and replays each match headless to its markers and end digest.
Owns: tools/playtest_session.py, tools/test_playtest_session.py, tools/replay_session.sh, docs/kickoff.md (inbox line)
Invariant: tools never write inside the repository; existing Python checks unchanged.
Boundary: format other than 1; marker without jpg; online match (no --factions); tampered command log.
Red: test_summary_lines fails (module missing).
Green: sh tools/run_python_checks.sh; replay of the Task 5 fixture.
Stop: the untampered fixture replays to a different digest.
```

**Interfaces (produces):**
- `tools/playtest_session.py FILE`: prints `SESSION build=<b> focus=<f> started=<s> matches=<n>`, one `CHECK <id> yes|no` per item, one `ANSWER <qid> <score> <text>` per answer, per match `MATCH <k> <mode> <map> seed=<s> seat=<n> end_tick=<t> build=<b> result=<r>` and per marker `MARKER <k>.<i> tick=<t> <kind> text=<json string> comment=<json string> camera=<x>,<y> selected=<ids> jpg=<path or ->`; writes each JPG as `<stem>-m<k>-<i>.jpg` next to FILE. `--replay-args` instead writes `<stem>-m<k>.cmd` (one command line per line) and prints one tab-separated row per match: `k`, `cmd path`, `mode`, `map`, `seed`, `factions` (comma-joined, `-` online), `end_tick`, `end_digest`, `marker ticks` (comma-joined, `-` when none), `build` (the match's own, user 2026-11-12, gate review I6). Exit 2 with `unsupported session format` when `format != 1`. Functions: `load_session(path: Path) -> dict`, `summary_lines(session: dict, jpgs: list[Path | None]) -> list[str]`, `write_jpgs(session: dict, path: Path) -> list[Path | None]`, `replay_rows(session: dict, path: Path) -> list[str]`.
- `sh tools/replay_session.sh FILE [--tick N]`: for each row, runs `${WARGRID_CLIENT:-godot --headless --path game} -- --netclient --replay-log <cmd> --map <map> --seed <seed> [--factions <f>] --oracle-ticks <end_tick> --state-ticks <marker ticks or N>` (`--tick N` adds `--snapshot-dir <stem>-m<k>-snapshots` next to FILE), prints its `ORACLE STATE` lines, then `REPLAY MATCHED <k>` when its `ORACLE FINAL` digest equals `end_digest`, else `REPLAY DIFFERS <k> recorded=<d> replayed=<d>`; exits 1 if any match differs or the oracle fails.
- `docs/kickoff.md` step 1: also list new files in `~/projects/wargrid-playtests/` and run `python3 tools/playtest_session.py` on each (a playtest session is input for today's question).

- [ ] **Step 1: Write the failing tests** in `tools/test_playtest_session.py` (unittest, temp dirs; fixture session built in the test with a real 1x1 JPG as base64):
  - `test_summary_lines`: the lines for a 2-match fixture equal the expected list exactly (one marker without `jpg` prints `jpg=-`).
  - `test_write_jpgs`: files `<stem>-m1-1.jpg` exist and start with bytes `FF D8`; the marker without a JPG yields `None`.
  - `test_replay_rows`: offline row has factions `frc,china`, online row `-`; `.cmd` files hold the command lines in order.
  - `test_rejects_other_format`: `format: 2` exits 2 with `unsupported session format`.
- [ ] **Step 2:** Run `sh tools/run_python_checks.sh > ~/projects/wargrid-p1-work/t6-red.log 2>&1`. Expected: FAIL.
- [ ] **Step 3:** Implement both tools and the kickoff line.
- [ ] **Step 4:** Run `sh tools/run_python_checks.sh`. Expected: PASS. Then `WARGRID_SESSION_OUT=$HOME/projects/wargrid-p1-work/fixture-session.json WARGRID_TEST_ONLY=test_two_match_session_file sh tools/run_tests.sh`, then `sh tools/replay_session.sh ~/projects/wargrid-p1-work/fixture-session.json`. Expected: `REPLAY MATCHED 1`, `REPLAY MATCHED 2`, exit 0. Copy the fixture, delete one player command line from match 2 with a small Python edit, rerun. Expected: `REPLAY DIFFERS 2`, exit 1. Record both in the verification file.
- [ ] **Step 5:** GREEN; coordinator commits "Add tools to read and replay playtest sessions".

### Task 7: Rider: BUDGET EXCEEDED summary and worst-tick lines

```text
Task: run_benchmark.sh ends with one line naming rows over budget whose regression ceilings held, and every row prints its worst tick (report-only).
Owns: game/scripts/debug/timing_stats.gd, game/benchmarks/run_movement.gd, run_combat.gd, run_lockstep.gd, tools/run_benchmark.sh, game/tests/test_benchmark.gd
Invariant: budgets, ceilings, pass counts and exit codes unchanged; no worst-tick value ever fails a run.
Boundary: empty samples; ties; no row over budget prints no summary line.
Red: test_worst_tick fails (function missing).
Green: test_benchmark.gd, full suite, sh tools/run_benchmark.sh (alone, quiet host).
Stop: none (exceeded rows are reported, never re-pinned).
```

**Interfaces (produces):** `Stats.worst(samples: PackedFloat64Array) -> Dictionary` gives `{"ms": float, "index": int}` (first index on ties; `{"ms": 0.0, "index": -1}` when empty). `Stats.over_budget_line(layout: String, summary: Dictionary) -> String`: `""` when `within(summary, BUDGET_P95_MS, BUDGET_P99_MS)`, else `"OVER BUDGET %s p95=%.3f p99=%.3f budget=%.2f/%.2f"`. Each row prints `WORST TICK <bench> <row> ms=%.3f tick=%d` (bench `movement`, `combat` or `lockstep`; row the layout, `overhead` for lockstep; tick = warmup + index) right after its existing summary line. `run_combat._stress_ok` prints the over-budget line when non-empty. `run_benchmark.sh` requires 2, 10 and 1 `WORST TICK` lines in the three logs and, at the end, when any `OVER BUDGET` line exists, prints `BUDGET EXCEEDED <layouts, space-separated> (regression ceilings held)`.

- [ ] **Step 1:** Write `test_worst_tick` (`[1.0, 3.0, 3.0, 2.0]` gives `{ms: 3.0, index: 1}`; empty gives index -1) and `test_over_budget_line` (`{p95: 1.82, p99: 3.64}` gives `""`; `{p95: 2.0, p99: 3.0}` gives `"OVER BUDGET open p95=2.000 p99=3.000 budget=1.82/3.64"`) in `test_benchmark.gd`; add them to `cases()`. Run; expected FAIL.
- [ ] **Step 2:** Implement.
- [ ] **Step 3:** Full suite, lint, warnings. Then `sh tools/run_benchmark.sh > ~/projects/wargrid-p1-work/t7-bench.log 2>&1` alone, `uptime` before and after. Expected: 13 `WORST TICK` lines, a `BUDGET EXCEEDED ... (regression ceilings held)` line naming the stress rows that measured over budget, exit as before. Record the lines in the verification file.
- [ ] **Step 4:** GREEN; coordinator commits "Report exceeded budgets and worst ticks".

### Task 8: Package documents

```text
Task: packages.md plans P1-P5 and the rough rest; STATUS.md holds state and replaces the status bullets in development.md's Start here; blueprint §7 links both.
Owns: docs/packages.md, docs/STATUS.md, docs/development.md (Overview status sentence, Start here), docs/blueprint.md (§7 head), AGENTS.md (status pointer line only), docs/wrapup.md (step 4 list)
Invariant: no rule or numeric value duplicated; confirmed, proposed and deferred labels kept; every finished milestone's design, plan and evidence links still reachable from Start here (AGENTS.md says so).
Boundary: links into reference notes and anchors; no line numbers in the new documents.
Red: n/a (docs).
Green: link and path check (scripted below), rg for stale status wording.
Stop: a status in Start here contradicts its verification file (ask which is right).
```

- [ ] **Step 1: `docs/packages.md`:** package rules (link the design, do not restate its list), then P1 to P5 with player-facing name, player change, focus card (P1: link `game/data/playtest/focus.json` and name card 1 as blocking), rider, and exit (P1: card 1 playtested with the helper, findings in `STATUS.md`); then the design's rough rest as a list; then "How a package runs": plan with drafted focus card, user approval, test-app deploy (approval), one 15-20 minute session, focus problems fixed before the next package, other findings to the list.
- [ ] **Step 2: `docs/STATUS.md`:** a table `Package | Name | State | Plan | Evidence` (P1 "in progress" with this plan and the verification file; P2-P5 "planned"); a "Findings list" section that orders later packages (start with the open M7/M6 items the cards cover, each pointing at its card); a "Finished work" table, one row per M0-M7, converted maps, sound spike, art lab, native sim spike, performance next and the small tasks, each with one state phrase and its verification or evidence link. Condense; do not copy the paragraphs.
- [ ] **Step 3: `docs/development.md`:** the Overview's status sentence points to `STATUS.md`; Start here keeps navigation only (kickoff, session notes, blueprint, `packages.md`, `STATUS.md`, design questions, AGENTS, installation, ledger, ZH verification, relay scaling) plus one compact bullet listing each finished milestone's design, plan and evidence links without status text. Every status sentence moves to `STATUS.md`.
- [ ] **Step 4:** Blueprint §7: one paragraph under the heading: work after M7 ships as packages P1, P2, ... planned in `packages.md`, state in `STATUS.md`; this section keeps design scope; the order in "Order after M7" is superseded by `packages.md` from P1 on (user, 2026-11-11 night). `AGENTS.md` line "Current setup and milestone status live in the development notes": setup stays there, package and milestone state in `docs/STATUS.md`. `docs/wrapup.md` step 4: add `docs/STATUS.md` and `docs/packages.md` to the list.
- [ ] **Step 5:** Check every relative link in the changed files resolves (a short Python one-off over `](...)` targets, run from the scratch dir, output to a log) and `rg -n 'Status|status' docs/development.md` shows no milestone state left in Start here.
- [ ] **Step 6:** GREEN; coordinator commits "Plan work as packages and track their state".

### Task 9: Exit gate (stop)

```text
Task: final evidence on the final tree, one rendered batch, reviews.
Owns: docs/reference/p1-playtest-helper-verification.md, docs/reference/performance.md (row), docs/STATUS.md (P1 state), the session notes (private, `~/projects/wargrid-private/docs/session-notes.md`)
Invariant: no budget, ceiling or label changed.
Boundary: an unverified browser capture stays "unverified", not assumed.
Red: n/a.
Green: full suite, lint, warnings, Python checks, run_benchmark.sh, netplay, rendered batch.
Stop: always (deploy, push, merge and the playtest are the user's).
```

- [ ] **Step 1:** On the final tree: full suite, lint, warnings, `sh tools/run_python_checks.sh`, `sh tools/run_netplay.sh` (result lines equal to `main`'s), `git diff main -- game/scripts/simulation` empty. Then `sh tools/run_benchmark.sh` alone on a quiet host with `uptime` at start and end; write a ledger row (tree, load, the `BUDGET EXCEEDED` line).
- [ ] **Step 2: One batched rendered ask** (the user approves the window first): (a) the rendered benchmark rerun `sh tools/run_game.sh res://scenes/movement_benchmark.tscn > ~/projects/wargrid-p1-work/t9-render.log 2>&1` (presentation changed); (b) a scratch script `~/projects/wargrid-p1-work/capture_check.gd` that opens the real skirmish scene, waits 120 frames, calls `open_marker()` and `save_marker("good", "check")`, ends the session, decodes the saved JPG and prints `CAPTURE OK width=<w> bytes=<n>` (expected width 640, bytes at most 98304), and calls `quit()` on every path. Record both rows. Browser capture stays "unverified until the test-app playtest".
- [ ] **Step 3:** Opus gate review (fresh context, milestone prompt brief: changed contracts, the hooks in the controller chain, the oracle args, Review Focus above; it names per new test the production change that would make it fail), then `/ponytail-review` on `main..p1-playtest-helper`. Fix findings test-first.
- [ ] **Step 4:** Update the resume record, `STATUS.md` (P1 "implemented, playtest pending"), session notes. **STOP.** The final message reports implemented, verified and pending separately: the user's approval for `sh tools/deploy_web.sh test`, push and CI plus `compare_local_traces.sh`, the playtest of card 1 (blocking; cards 2 and 3 feed the findings list), and moving the session file to `~/projects/wargrid-playtests/`.
