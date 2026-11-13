# P2 "You clicked, we heard" Implementation Plan

**Status:** approved by the user 2026-11-13 (subagent-driven run; Restart keeps the running playlist, user 2026-11-13). The run starts only when the user says so.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Run rules: [milestone prompt](../../milestone-prompt.md) (coordinator plus one fresh subagent per task, no per-task reviewers, one Opus review at the gate review task). Resume record: [P2 verification](../../reference/p2-verification.md). Every task subagent also reads "Global Constraints" and "Review Focus" (`rg -n '^## ' <plan>`).

**Goal:** Every unit order gets one spoken acknowledgement at click time, offline and online; the launcher is grouped into sections with the relay URL under a closed Advanced fold; match music is shuffled per match (F4); the after-match form gets a scale legend (F1); F5 is reproduced or reported "not reproduced"; three report-only measurements (browser against native team match, late-game 3v3 canary, recorded playtest match row).

**Architecture:** A small static table `unit_voice.gd` (role per kind, voice line per command type, file paths) sits beside `sound_cues.gd`; `SoundDirector.order_voice` picks the speaker from the last presented view rows and a variant from its own presentation `RandomNumberGenerator`; `SoundPlayer` plays it on a second `Voice`-bus player and skips while one plays. The hook is in `_submit`, where the order leaves the input code: offline after `super._submit` issued it locally and only when that issue was accepted, online at `_lockstep.submit`. Nothing in `game/scripts/simulation/` or `game/scripts/net/` changes. The launcher keeps its controls and node names where possible, regrouped under headed sections in `launcher.tscn`. Riders are debug/benchmark code only.

**Tech Stack:** Godot 4.7.2, typed GDScript, the suite runner `game/tests/run_tests.gd`; Python 3 with numpy/scipy for `tools/audio/synth.py`; Piper `piper-tts==1.8.0` outside the repo; ffmpeg for loudness.

**Spec:** [P2 design](../specs/2026-11-13-p2-you-clicked-we-heard-design.md) (read fully once; every decision there is settled). Sound rules: [sound spike design](../specs/2026-11-08-sound-spike-design.md), [evidence](../../reference/sound-spike.md), [plan](2026-11-08-sound-spike.md).

## Global Constraints

- Worktree `~/projects/wargrid-wt-p2`, branch `p2-you-clicked`, base: the `main` commit that adds the spec and this plan. The main checkout's branch is never switched. Agent shells reset their directory: start every command with `cd ~/projects/wargrid-wt-p2 && `. Logs and scratch: `~/projects/wargrid-p2-work/` (full paths in every log name).
- **Presentation only (sound spike rule):** `git diff main -- game/scripts/simulation game/scripts/net` stays empty for the whole branch. Proof at every GREEN: the existing trace and replay tests pass unchanged (`test_replay.gd`, `test_state_hash.gd`, `test_skirmish_match.gd` pinned outcomes, `test_team_match.gd` `FINAL_DIGEST`, `test_view_rows.gd` `EXPECTED_DIGEST`); at the exit, `sh tools/run_netplay.sh match` keeps its pinned terminal tick and CI `compare_local_traces.sh` matches. No pinned value in those files may change; a change parks the task.
- **No new simulation command,** so no same-tick interaction cases (AGENTS.md asks for them only for new commands). Order voice reads commands; it never issues, alters or delays one.
- **Presentation randomness only:** variant choice and the music shuffle use a `RandomNumberGenerator` owned by presentation code (the director's `_rng`, a new one in `skirmish_main.gd`); never `sim.next_random()`, never the match seed.
- **Headless playback off:** every `play()` call is guarded by `DisplayServer.get_name() != "headless"` (as `sound_player.gd` and `music_player.gd` do).
- **Order voice values (spec "Decided"):** roles `infantry`, `vehicle`, `worker`; lines `infantry` and `vehicle`: `move`, `attack`; `worker`: `move`, `work`; 2 variants each, 12 files `game/audio/voice/units/<role>_<line>_<n>.wav`, `n` in 1..2. Role: a kind with `builds` or `collects` is `worker`; else `class == "infantry"` is `infantry`; else `vehicle`. Command to line: `move`, `enter`, `unload` -> `move`; `attack`, `attack_move` -> `attack`; `gather`, `build`, `resume_build` -> `work`; `stop`, `set_rally`, `produce`, `cancel_build`, `cancel_production`, `defence_attack` silent. Speaker: the first own unit in the order's unit list whose role has that line. One unit voice at a time; an order while one plays is skipped, not queued, not cut. Unit voice and announcer are separate `AudioStreamPlayer`s, both on bus `Voice`.
- **Proposed wording** (the user edits it on the A/B page): `move` "Moving." / "On my way."; `attack` "Engaging." / "Target acquired."; `work` "Getting to work." / "On it.". Same wording for every role; voice and treatment differ per role.
- **Voice assets:** Piper `john`, `norman`, `bryce` (`en_US-<name>-medium`) from `rhasspy/piper-voices` at revision `e7229f7d33a10e145e109b886d661984201ac3c4`; raw renders, models, venv and the A/B page live only under `~/projects/wargrid-sound-work/` (never in the repo); picked lines reach the repo only through `tools/audio/synth.py`. Mono 16-bit 44,100 Hz WAV, -24 LUFS (`VOICE_LUFS`), peak <= -1 dBFS, imported like `game/audio/voice/*.wav` (`force/mono=true`, `compress/mode=2`). Raw committed audio stays <= 20,000,000 bytes.
- **Launcher (spec "Menu"):** sections "Play offline", "Play online", "Settings"; Credits and the legal line at the foot; a "Match" row (your faction, map) above both play sections; Opponent and Start offline only; relay URL under an "Advanced" fold, closed by default. Same controls, regrouped; no redesign.
- **Music (F4):** the five `MusicPlayer.PLAYLIST` tracks shuffled once per match, then looped in that order with `GAP_SECONDS`; the launcher keeps `MENU`.
- **Scale legend (F1):** exact text `1 strongly disagree … 5 strongly agree` (Unicode ellipsis), one line under the 1-5 rows.
- New tests use only the [simulation interface](../../reference/sim-interface.md) plus `definitions/` data (`tools/test_sim_boundary.py`); presentation privates (`_sound`, `_unit_voice`, `_paths`) may be read, as `test_announcer.gd` reads `_sound._voice`. New suites go into `run_tests.gd` `SUITES`; new `.gd` files get their generated `.gd.uid` tracked.
- Typed GDScript, small functions, comments only for a one-line why, no section-header comments. Edit with the Edit tool or asserted replacements only. Scratch Godot scripts `quit()` on every path.
- Every suite, benchmark, lint, netplay and parity call: Bash `timeout: 600000`, output to a file, judged by exit code and summary lines (`CASES … CHECKS … FAILURES …`, `TESTS PASSED`); on failure read only `rg -n 'FAIL|SCRIPT ERROR|ERROR:' <log>`. Edit loop: `WARGRID_TEST_ONLY=<substring> sh tools/run_tests.sh`.
- Gates before each GREEN: `sh tools/run_tests.sh`, `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/check_public.sh`; plus `sh tools/run_python_checks.sh` when `tools/` Python changes and `sh tools/run_shell_checks.sh` when a `*.sh` changes.
- No window, browser, sound, deploy, push or merge outside the stop gates below; ask before each. Subagents never commit or push; the coordinator makes one local commit per GREEN task (pre-authorized by the milestone prompt), message: subject plus at most 2-3 lines.
- Living docs (`docs/guide/`, `STATUS.md`, `packages.md`) name symbols, not line numbers; tracked files stay free of personal detail (`check_public.sh`).

## Review Focus

1. **Fast clicking:** ten orders in one second give one unit line; the next line only after it ends, with no backlog. Test: Task 1 `test_order_voice_skips_while_busy` (OV4).
2. **Orders naming units that are gone or not yours** (a unit died since the last frame, an id from an old selection, an enemy id): silent, no error. Test: Task 1 `test_first_unit_with_a_line_speaks` (OV3, unknown and enemy rows).
3. **A valid click while an older rejection surfaces in the same refresh** (an earlier order failed at step time and its result is shown now): the old rejection beeps and the new order still speaks. Test: Task 2 `test_valid_order_speaks_despite_older_rejection` (OV11).
4. **Restart, then order:** the first order after Restart speaks; Restart keeps the running playlist instead of cutting the track. Tests: Task 2 `test_restart_then_order_speaks` (OV12), Task 4 `test_scene_plays_a_shuffled_playlist` (MU2).
5. **Advanced fold closed:** Create still uses the default relay URL and the busy state still locks the hidden field. Test: Task 3 `test_launcher_sections` (N20).

## Stop gates

- **(a) Batched browser and window session (user present, after Task 8).** In this order, asking before each window or sound: A/B listening page in Firefox (`open -a Firefox`), the user picks voice and treatment per role and edits wording (re-render and re-listen if the wording changed); Task 9 runs while the session continues; test deploy of the Task 9 tree (`sh tools/deploy_web.sh test`, needs approval) and the F5 repro by the user's hand on the test app; browser against native team match in the Firefox web bench (dedicated profile) for both web builds; rendered benchmark rerun last (`sh tools/run_game.sh res://scenes/movement_benchmark.tscn`, nothing overlapping the window).
- **(b) Focus card playtest (user present, after Task 12).** Test deploy of the final tree (approval), the P2 card played offline and online. A rendered rerun is repeated here only if presentation code changed after gate (a) (Task 10 or 12 fixes).
- **(c) Any push, deploy or merge** needs the user's explicit approval, each time.

## Risks and model routing

Riskiest contract first: the order hook's timing and its rejected-order rule (Tasks 1-2). Second: the launcher fitting 1280x720 with three headers and a fold (Task 3; P1 already reduced the box separation to fit). Third: the Piper reinstall on macOS arm64 (VOICES.md: Python 3.14, the short `espeak-ng-data` path workaround) (Task 7).

| Task | What | Model |
|---|---|---|
| 1 | Order voice rule: table and director | Sonnet |
| 2 | Order voice in the game: player, hooks, placeholder WAVs | Sonnet |
| 3 | Launcher sections and Advanced fold | Sonnet |
| 4 | F4 music shuffle, F1 scale legend | Sonnet |
| 5 | Late-game 3v3 canary (report-only) | Sonnet |
| 6 | Browser rider prep: bench lines, two web exports, native run | Sonnet |
| 7 | Voice pipeline and A/B page | Sonnet |
| 8 | P2 focus card and docs | Sonnet |
| — | **Stop gate (a)** | user |
| 9 | Picked voices into the game | Sonnet |
| 10 | Replaced by [the F5 addendum](2026-11-13-p2-f5-paste-and-links.md): reproduced by the user on the test app, cause in Godot's web clipboard, fixed by 10a-10c | Sonnet |
| 11 | Exit checks and ledger row | Sonnet |
| 12 | Gate review and lean pass | **Opus (high)** reviewer |
| — | **Stop gate (b)**, then fixes in Task 13 | user |
| 13 | Playtest fixes and findings | Sonnet |
| — | **Stop gate (c)** | user |
| 14 | Recorded playtest match row (after the exit, own commit) | Sonnet |

---

### Task 1: Order voice rule (risk first)

```text
Task: a pure table and director rule that picks one unit voice line for an order, or none.
Owns: game/scripts/presentation/unit_voice.gd (new), game/scripts/presentation/sound_director.gd, game/tests/test_order_voice.gd (new), game/tests/run_tests.gd, docs/reference/p2-verification.md
Invariant: no simulation or net file changes; existing sound and announcer suites unchanged and green.
Boundary: mixed selections, enemy and unknown ids, every command type, busy.
Red: OV1-OV5 fail on assertions (UnitVoice table empty, order_voice returns "").
Green: WARGRID_TEST_ONLY=test_order_voice; test_sound.gd; test_announcer.gd; full suite.
Stop: Registry.units() holds a kind the role rule places differently from the table below.
```

**Files:** Create `game/scripts/presentation/unit_voice.gd`, `game/tests/test_order_voice.gd` (+ `.gd.uid`); modify `game/scripts/presentation/sound_director.gd`, `game/tests/run_tests.gd` (append the suite as the last `SUITES` entry).

**Interfaces (produces):**
- `unit_voice.gd` (`extends RefCounted`, statics only): `const VARIANTS := 2`; `const LINES := {"infantry": ["move", "attack"], "vehicle": ["move", "attack"], "worker": ["move", "work"]}`; `const ORDER_LINE := {"move": "move", "enter": "move", "unload": "move", "attack": "attack", "attack_move": "attack", "gather": "work", "build": "work", "resume_build": "work"}`; `static func role(kind: String) -> String`; `static func speakers(payload: Dictionary) -> Array[int]` (`unload`: `[target_id]`; `build`, `resume_build`: `[builder_id]`; else `entity_ids`); `static func path(role: String, line: String, variant: int) -> String` = `"res://audio/voice/units/%s_%s_%d.wav"`.
- `SoundDirector.order_voice(payload: Dictionary, busy: bool) -> String`: `""` when `busy`, when the type is not in `ORDER_LINE`, or when no speaker; else the path, variant `_rng.randi_range(1, UnitVoice.VARIANTS)`. Speakers are looked up in `_rows` (the last `update` state's view rows): skip ids with `index_of == -1` or `owner != _local_player`; kind `_rows.kinds[_rows.kind[i]]`. `busy` is checked first, so a skipped order draws no random number.

- [ ] **Step 1:** `docs/reference/p2-verification.md` arrives from `main` with this plan; update its resume record. Baseline: `sh tools/run_tests.sh > ~/projects/wargrid-p2-work/t1-baseline.log 2>&1; echo "exit=$?"`; record CASES / CHECKS in an evidence row.
- [ ] **Step 2: Failing tests** in `test_order_voice.gd` (header as other suites: `@warning_ignore_start("untyped_declaration")`, `extends RefCounted`, `cases()`). Helper `_director(units: Array) -> SoundDirector`: seeded `RandomNumberGenerator` (seed 1), `Director.new(1, rng)`, one `update({"units": ViewRows.from_units(units), "buildings": [], "match": {"status": "ongoing"}})`; unit rows `{"id", "owner", "kind", "position": [x, y], "combat": {"tier": 0}}` as `test_sound.gd` `_unit` builds them. Fixture units: 1 `usa_builder`, 2 `usa_rifle_infantry`, 3 `usa_tank`, 5 `frc_light_vehicle` (all owner 1), 4 `china_tank` (owner 2).
  - `test_order_roles_cover_every_unit` (OV1): `const EXPECTED_ROLES := {"usa_builder": "worker", "usa_collector": "worker", "china_builder": "worker", "china_collector": "worker", "frc_builder": "worker", "usa_rifle_infantry": "infantry", "usa_rocket_infantry": "infantry", "china_rifle_infantry": "infantry", "china_rocket_infantry": "infantry", "frc_rifle_infantry": "infantry", "frc_rocket_infantry": "infantry", "usa_light_vehicle": "vehicle", "usa_tank": "vehicle", "china_light_vehicle": "vehicle", "china_tank": "vehicle", "frc_light_vehicle": "vehicle", "frc_tank": "vehicle"}`. Sorted `Registry.units()` equals sorted `EXPECTED_ROLES.keys()` ("OV1 every unit kind has a role row, got %s") and `UnitVoice.role(kind) == EXPECTED_ROLES[kind]` for each ("OV1 %s speaks as %s, got %s").
  - `test_order_line_per_command` (OV2): `UnitVoice.ORDER_LINE` equals the Global Constraints mapping; `const SILENT := ["stop", "set_rally", "produce", "cancel_build", "cancel_production", "defence_attack"]`; sorted `ORDER_LINE.keys() + SILENT` equals sorted `FocusCards.COMMAND_TYPES` (a new command forces a decision); each silent type with `entity_ids [2]` gives `""` ("OV2 %s stays silent").
  - `test_first_unit_with_a_line_speaks` (OV3), each `order_voice(payload, false)` checked with `begins_with`: `attack [1, 2, 3]` -> `res://audio/voice/units/infantry_attack_`; `gather [2, 1]` -> `worker_work_`; `move [3, 1]` -> `vehicle_move_`; `enter [2]` -> `infantry_move_`; `build {builder_id: 1}` and `resume_build {builder_id: 1}` -> `worker_work_`; `unload {target_id: 5}` -> `vehicle_move_`; empty string for `attack [1]` (worker has no attack line), `move [4]` (enemy), `move [99]` (unknown id), `unload {target_id: 99}` (a building or gone).
  - `test_order_voice_skips_while_busy` (OV4): `order_voice(move [2], true) == ""`; then `order_voice(move [2], false)` is non-empty; a director whose first call was busy draws the same next variant as a fresh director with the same seed (no random number spent, nothing queued).
  - `test_order_variant_is_presentation_random` (OV5): 20 calls `move [2]` give only `infantry_move_1.wav` and `infantry_move_2.wav`, both at least once; a second director with seed 1 gives the same 20.
- [ ] **Step 3: Red.** Create `unit_voice.gd` with the consts empty and the funcs returning `""` / `[]`, and `order_voice` returning `""`, so the suite loads. `WARGRID_TEST_ONLY=test_order_voice sh tools/run_tests.sh > ~/projects/wargrid-p2-work/t1-red.log 2>&1`: assertion failures only, no `SCRIPT ERROR`.
- [ ] **Step 4: Implement** the table and `order_voice` as in Interfaces (`const UnitVoice = preload("res://scripts/presentation/unit_voice.gd")` in the director).
- [ ] **Step 5: Green.** `WARGRID_TEST_ONLY=test_order_voice`, `=test_sound.gd`, `=test_announcer` exit 0; full suite exit 0 (baseline + 5 cases); lint, warnings, check_public exit 0; `git diff main -- game/scripts/simulation game/scripts/net` empty. Evidence row and resume record.

---

### Task 2: Order voice in the game

```text
Task: offline and online orders play the director's line on a second Voice-bus player; locally rejected orders only beep.
Owns: game/scripts/presentation/sound_player.gd, game/scripts/main.gd (_submit only), game/scripts/skirmish_main.gd (_submit), game/scripts/online_main.gd (_submit), game/audio/voice/units/*.wav + .import (placeholders), game/tests/test_order_voice.gd
Invariant: rejected-order error cue, insufficient-funds line and playtest observe_command behave as on main; no trace change.
Boundary: rejection in the same refresh as a valid click; restart; online rejection after submit.
Red: OV6-OV12 fail (no files, no _unit_voice, no hook).
Green: test_order_voice; test_sound.gd; test_announcer; test_online_scene; test_playtest_overlay; full suite.
Stop: an existing announcer, sound, online or playtest case would need its expectation changed.
```

**Files:** Modify `game/scripts/presentation/sound_player.gd`, `game/scripts/main.gd` (`_submit`), `game/scripts/skirmish_main.gd` (`_submit`), `game/scripts/online_main.gd` (`_submit`); create 12 placeholder WAVs `game/audio/voice/units/{infantry,vehicle}_{move,attack}_{1,2}.wav`, `worker_{move,work}_{1,2}.wav` with their `.import` files; test `game/tests/test_order_voice.gd`.

**Interfaces:**
- Consumes: `SoundDirector.order_voice(payload: Dictionary, busy: bool) -> String`, `UnitVoice.path`, `UnitVoice.LINES`, `UnitVoice.VARIANTS` (Task 1).
- Produces: `SoundPlayer` `var _unit_voice := AudioStreamPlayer.new()` (name `UnitVoice`, bus `&"Voice"`, added in `_ready` next to `_voice`); `func order(payload: Dictionary) -> void` (asks `director.order_voice(payload, _unit_voice.playing)`; on a path: `_unit_voice.stream = load(path)`, then `play()` only when not headless). `main.gd` `var _last_issue_ok: bool = false`, set from the `_issue` result in `_submit`. `skirmish_main._submit`: unchanged error/observe lines, then `if _last_issue_ok: _sound.order(payload)`. `online_main._submit`: `_sound.order(payload)` after its `_refresh()`.

- [ ] **Step 1: Placeholders.** Copy `game/audio/sfx/click.wav` to the 12 paths (shortcut until Task 9; Wargrid-made, GPL like the effects). Run `godot --headless --path game --import > ~/projects/wargrid-p2-work/t2-import.log 2>&1`, then set each new `.import`'s `[params]` to match `game/audio/voice/victory.wav.import` (`force/mono=true`, `force/max_rate=false`, `compress/mode=2`) with asserted replacements, import again. Check: `rg -c 'force/mono=true' game/audio/voice/units/*.import` prints 12 lines of `1`.
- [ ] **Step 2: Failing tests** in `test_order_voice.gd`; scene helper as `test_announcer.gd` `_scene` (skirmish scene, process off, two frames); `_unit_line(scene) -> String` = the `_sound._unit_voice.stream` file basename or `""`. Own builder = player 1's `*_builder` from `simulation.view_state().units`; enemy HQ from `snapshot().buildings`.
  - `test_order_lines_exist` (OV6): for each role in `UnitVoice.LINES`, each line, `n` in 1..`VARIANTS`: `ResourceLoader.exists(UnitVoice.path(role, line, n))`; 12 checked in total.
  - `test_offline_order_speaks` (OV7): `_submit` a `move` for the builder to a cell 6 cells away: `_unit_line` begins `worker_move_`; `_sound._unit_voice.bus == &"Voice"` and `_sound._unit_voice != _sound._voice`; `simulation.tick()` unchanged by the order.
  - `test_offline_rejected_order_only_errors` (OV8): `_submit` an `attack` with `entity_ids [builder]`, `target_id` the enemy HQ: fixture check `_error == "Attack requires armed units"`; `_unit_line == ""`; after `_refresh()`, `_sound.last_requests()` cues contain `"error"`.
  - `test_online_order_speaks_on_submit` (OV9): `OnlineTests._online(runner, 1)`, `_run(main, n)` until seat 1 owns a unit in `view_state().units`; `_submit` a `move` for it: `_unit_line` non-empty at once (before any further tick); then append `{"tick": t, "sequence": 0, "error": "No units left"}` to `lockstep._rejections`, `_run(main, 1)`: cues contain `"error"` and `_unit_line` is still set.
  - `test_headless_playback_off` (OV10): after OV7's order, `not _sound._unit_voice.playing`.
  - `test_valid_order_speaks_despite_older_rejection` (OV11): append to `stepped_results` an unseen failed result of player 1 (`{"tick": tick, "player": 1, "sequence": 99, "ok": false, "error": "No units left"}`), then `_submit` a valid `move`: `_unit_line` begins `worker_move_` and cues after `_refresh()` contain `"error"`.
  - `test_restart_then_order_speaks` (OV12): `_restart()`, then a builder `move`: `_unit_line` begins `worker_move_`.
- [ ] **Step 3: Red.** `WARGRID_TEST_ONLY=test_order_voice sh tools/run_tests.sh > ~/projects/wargrid-p2-work/t2-red.log 2>&1`: OV6 passes (Step 1), OV7-OV12 fail on assertions or on the missing `_unit_voice` member reported as a failed check (guard reads with `_sound.get("_unit_voice")`), no parse error.
- [ ] **Step 4: Implement** as in Interfaces.
- [ ] **Step 5: Green.** `WARGRID_TEST_ONLY=test_order_voice`, `=test_sound.gd`, `=test_announcer`, `=test_online_scene`, `=test_playtest_overlay` exit 0; full suite exit 0; lint, warnings, check_public exit 0; simulation/net diff empty. Evidence row.

---

### Task 3: Launcher sections and Advanced fold

```text
Task: regroup the launcher into Match row, Play offline, Play online (relay URL under a closed Advanced fold), Settings, foot.
Owns: game/scenes/launcher.tscn, game/scripts/launcher.gd, game/tests/test_online_scene.gd, game/tests/test_playtest.gd (paths only)
Invariant: same controls and behaviour; online create hello still carries MatchSettings.for_map(_map_id()); _start still passes the own faction.
Boundary: fold closed during Create; busy state with the fold closed; WaitRow and ThisBuild visible together at 1280x720.
Red: N20 fails (no section headers, no Advanced).
Green: test_online_scene; test_playtest; test_pause_menu; full suite.
Stop: the box does not fit 1280x720 with the values below (record the measured box height; a further layout change is a design question).
```

**Files:** Modify `game/scenes/launcher.tscn`, `game/scripts/launcher.gd` (`_ready`, `_add_playtest`, `_add_audio`, `_offline_setup`, `_set_busy`, `_map_id`); tests `game/tests/test_online_scene.gd` (N5, the faction-selector test, N7/N13/N14/N15/N17 paths, new N20), `game/tests/test_playtest.gd` (paths only if any change).

**Target tree under `Center/Box`** (in order; new nodes in bold; `separation` 8 -> 6):
`Title`; **`MatchRow`** (HBox: `Own` "Your faction", `Map`, both `size_flags_horizontal = 3`); **`OfflineHeader`** (Label "Play offline"); **`OfflineRow`** (HBox: `Opponent`, `Offline` with text "Start"); `ThisBuild` (code, after `OfflineRow`); **`OnlineHeader`** (Label "Play online"); `Create`; `JoinRow`; `WaitRow`; **`Advanced`** (Button, `toggle_mode = true`, `flat = true`, text "Advanced ▸" closed / "Advanced ▾" open); `RelayUrl` (`visible = false`); `Status`; **`SettingsHeader`** (Label "Settings"); `Volume` (code, right after `SettingsHeader`); `PlaytestSwitch` (code, before `Credits`); `Credits`; `Legal`. Headers: `theme_override_font_sizes/font_size = 14`. `FactionRow` is removed. Path changes: `FactionRow/Own` -> `MatchRow/Own`, `Map` -> `MatchRow/Map`, `FactionRow/Opponent` -> `OfflineRow/Opponent`, `Offline` -> `OfflineRow/Offline`; find every use with `rg -n 'FactionRow|Box/Map|Box/Offline|"Offline"|"Map"' game/scripts game/tests`.

**Interfaces (produces):** `launcher.gd` `func _set_advanced(open: bool) -> void` (shows `RelayUrl`, sets the button text), connected to `Advanced.toggled`; `_set_busy` path list `["OfflineRow/Offline", "Create", "RelayUrl", "JoinRow/Code", "JoinRow/Join", "MatchRow/Own", "OfflineRow/Opponent", "MatchRow/Map"]`.

- [ ] **Step 1: Failing test** `test_launcher_sections` (N20) in `test_online_scene.gd`, same SubViewport loop as N5 (1280x720 and 1920x1080, scratch `AudioSettings.path`):
  - `OfflineHeader.text == "Play offline"`, `OnlineHeader.text == "Play online"`, `SettingsHeader.text == "Settings"`.
  - Order by `get_index()` in `Center/Box`: `MatchRow` < `OfflineHeader` < `OfflineRow` < `OnlineHeader` < `Create` < `JoinRow` < `Advanced` < `RelayUrl` < `SettingsHeader` < `Volume` < `PlaytestSwitch` < `Credits` < `Legal`; `Opponent` and `Offline` are children of `OfflineRow`; `Own` and `Map` of `MatchRow`.
  - Fold: on load `not Advanced.button_pressed` and `not RelayUrl.visible`; `RelayUrl.text == "wss://relay.pdstuber.dev/ws"`; `_set_busy(true)` makes `RelayUrl.editable == false` while hidden; `Advanced.button_pressed = true` (emits `toggled`) makes `RelayUrl.visible`.
  - With the fold open and `WaitRow`, `ThisBuild` visible: every control in N5's list (with the new paths, plus the three headers and `Advanced`) lies inside the viewport, and no two overlap.
- [ ] **Step 2: Red.** `WARGRID_TEST_ONLY=test_launcher_sections`: assertion failures (missing nodes reported through `get_node_or_null` checks), no `SCRIPT ERROR`.
- [ ] **Step 3: Implement** the tree and `launcher.gd` changes; update N5 (open the fold before measuring, new paths), the faction-selector test (`MatchRow/Own` and `OfflineRow/Opponent` do not overlap, each inside the box, the row clear of `OfflineRow`, `MatchRow/Map`, `Create`, `JoinRow`, `Status`; default United States unchanged), and the other path references.
- [ ] **Step 4: Green.** `WARGRID_TEST_ONLY=test_online_scene`, `=test_playtest.gd`, `=test_pause_menu` exit 0; full suite exit 0; lint, warnings, check_public exit 0. Record the measured `Center/Box` height at 1280x720 in the evidence row.

---

### Task 4: F4 music shuffle and F1 scale legend

```text
Task: match music shuffled once per match; one scale legend line in the after-match form and in the docs.
Owns: game/scripts/presentation/music_player.gd, game/scripts/skirmish_main.gd (_ready only), game/scripts/playtest/session_form.gd, game/tests/test_audio_settings.gd, game/tests/test_playtest_overlay.gd, docs/guide/05-presentation.md (Playtest helper bullet)
Invariant: launcher plays MENU only; PLAYLIST constant unchanged; form answers stored as before.
Boundary: Restart keeps the running playlist; a card with five questions.
Red: MU1, MU2, PO18 fail.
Green: test_audio_settings; test_playtest_overlay; test_sound.gd; full suite.
Stop: none expected.
```

**Interfaces (produces):** `MusicPlayer` `static func shuffled(paths: Array[String], rng: RandomNumberGenerator) -> Array[String]` (returns a new array; Fisher-Yates with `rng.randi_range`); `skirmish_main._ready` plays `MusicPlayer.shuffled(MusicPlayer.PLAYLIST, rng)` with `rng := RandomNumberGenerator.new(); rng.randomize()`; `_restart` does not touch music (user, 2026-11-13: Restart keeps the running playlist). `SessionForm` `const SCALE_LEGEND := "1 strongly disagree … 5 strongly agree"`, a Label named `ScaleLegend` added once in `open_questions` right after the last question.

- [ ] **Step 1: Failing tests.**
  - `test_audio_settings.gd` `test_match_playlist_is_shuffled` (MU1): with seeded RNGs, `shuffled(PLAYLIST, rng)` has size 5 and sorts to sorted `PLAYLIST`; seed 1 twice gives the same order; two seeds (pick two that differ, e.g. 1 and 2; assert they differ) give different orders; `PLAYLIST` afterwards equals its five literal paths in source order.
  - `test_audio_settings.gd` `test_scene_plays_a_shuffled_playlist` (MU2): the skirmish scene's Music child (`get_children()` with script `MusicPlayer`) has `_paths` sorted equal to sorted `PLAYLIST`; after `_restart()` `_paths` and `track_index()` are unchanged; the launcher's Music child has `_paths == [MusicPlayer.MENU]`.
  - `test_playtest_overlay.gd` `test_scale_legend` (PO18): `SessionForm.new()` with a session and card 1, `open_questions`: exactly one Label `ScaleLegend` with `text == SessionForm.SCALE_LEGEND`; its index in the content box is after the last question's `<id>_5` row and before the "Match 1" label.
- [ ] **Step 2: Red.** `WARGRID_TEST_ONLY=test_audio_settings` and `=test_scale_legend`: assertion failures only.
- [ ] **Step 3: Implement**; in `docs/guide/05-presentation.md`, Playtest helper bullet, add one sentence: the focus questions are agreement scores, `1 strongly disagree … 5 strongly agree`, shown under the score rows.
- [ ] **Step 4: Green.** Named suites exit 0; full suite exit 0; lint, warnings, check_public exit 0.

---

### Task 5: Late-game 3v3 canary (report-only)

```text
Task: a synthetic late-game board (six seats, two teams, three factions, built bases, 210 mixed units in contact, bots running), timed headless, reported per zone.
Owns: game/scripts/debug/combat_workload.gd, game/benchmarks/run_late_game.gd (new), game/tests/test_benchmark.gd
Invariant: every existing layout builds the same world (combat benchmark lines and pinned traces unchanged); run_benchmark.sh untouched.
Boundary: a base cell that is blocked; a spawn cell that is taken.
Red: BM22 fails (unknown layout).
Green: test_benchmark; full suite; one run of run_late_game.gd.
Stop: a mechanic check in the runner fails (record the counters, never drop the check).
```

**Interfaces (produces):** layout `"late_game_3v3"` in `CombatWorkload.create` (assert list and dispatch); `static func _late_game_3v3() -> Simulation`; `_building(sim, kind, origin, owner: int = 1)` (default keeps existing callers). Board: `TeamMatch.create()` (Ashfall, `TeamMatch.SEATS`, match started); per seat, completed `<faction>_barracks`, `<faction>_factory`, `<faction>_supply_center`, `<faction>_defence`, plus `<faction>_power_plant` for `usa` and `china`, each at the first origin around the seat's start cell (rings of radius 4 to 14 cells) where `sim.preview_build(seat, <seat's builder id>, kind, origin).ok`; army per seat 35 units: 12 `<faction>_rifle_infantry`, 8 `<faction>_rocket_infantry`, 8 `<faction>_light_vehicle`, 7 `<faction>_tank`, spawned in blocks of 5 rows within 6 cells of the midpoint between the two teams' start-cell centroids (team 1 on its side, team 2 mirrored), skipping cells where `spawn` returns <= 0, then one `attack_move` per seat to the nearest enemy start cell. Assert 210 army units. `run_late_game.gd` (`extends SceneTree`): `WARMUP := 300`, `SAMPLES := 1800`, each tick timed around `TeamMatch.step(sim)`, `Profiler` on for the window; prints `LATE GAME 3v3 tick_ms=<Stats.summary JSON> mean_ms=%.3f shots_window=%d deaths_window=%d bot_commands_window=%d alive_start=%d alive_end=%d`, `Stats.worst_tick_line("late_game", "late_game_3v3", samples, WARMUP)`, the `Profiler.report("late_game")` lines, last `LATE GAME CANARY DONE`. Exit 1 when `first_shot >= 60`, `shots_window == 0`, `deaths_window == 0` or `bot_commands_window == 0` (ok `command_results()` entries of the six seats inside the window). Not added to `run_benchmark.sh` (report-only).

- [ ] **Step 1: Failing test** `test_late_game_layout` (BM22) in `test_benchmark.gd`: `CombatWorkload.create("late_game_3v3")`; `view_state().players` has six seats in teams 1 and 2, factions `usa`, `china`, `frc` twice each; per seat the completed buildings above exist (`snapshot().buildings`, `completed`); at creation 35 non-builder units per seat; after 60 `TeamMatch.step` calls, some `combat_events()` entry of type `shot` occurred.
- [ ] **Step 2: Red** (`WARGRID_TEST_ONLY=test_late_game_layout`), then implement, then green.
- [ ] **Step 3: One run, alone:** `uptime; godot --headless --path game --script res://benchmarks/run_late_game.gd > ~/projects/wargrid-p2-work/t5-canary.log 2>&1; echo "exit=$?"; uptime`. Exit 0, `LATE GAME CANARY DONE`. Paste the `LATE GAME`, `WORST TICK` and the top five `PROFILE` lines into the evidence row (report-only, no budget, no judgement).
- [ ] **Step 4: Gates.** Full suite, lint, warnings, check_public exit 0; `sh tools/run_benchmark.sh` is not needed here (no simulation change; debug-only layout).

---

### Task 6: Browser rider prep

```text
Task: make the web bench report mean and worst tick for the team match; build both web bench exports; run the native row.
Owns: game/benchmarks/bench_runner.gd (_team only), game/scripts/debug/timing_stats.gd (mean), game/tests/test_benchmark.gd, ~/projects/wargrid-p2-work/ (exports, threaded scratch tree)
Invariant: Stats.summary output unchanged; run_benchmark.sh lines unchanged; tracked export_presets.cfg unchanged.
Red: BM21 fails (no Stats.mean).
Green: test_benchmark; full suite; native bench_runner run.
Stop: the threaded export fails for lack of a threaded web template (report, do not install anything unasked).
```

**Interfaces (produces):** `Stats.mean(samples: PackedFloat64Array) -> float` (0.0 for empty); `bench_runner._team()` also emits `TEAM MEAN ms=%.3f` and `Stats.worst_tick_line("bench", "team", samples, 0)` after `TEAM TIMING`.

- [ ] **Step 1:** `test_stats_mean` (BM21): `Stats.mean(PackedFloat64Array([1.0, 2.0, 6.0])) == 3.0`, empty gives 0.0. Red, implement both changes, green; full suite, lint, warnings exit 0.
- [ ] **Step 2: Exports (headless, no window).** Single-threaded: `sh tools/export_build.sh "Web Bench" ~/projects/wargrid-p2-work/web-bench/index.html`. Threaded: `git archive HEAD | tar -x -C ~/projects/wargrid-p2-work/threaded-tree`, in that copy's `game/export_presets.cfg` set the `Web Bench` preset's `variant/thread_support=false` to `true` (one asserted replacement in that preset's options section; the threaded game build in `~/projects/wargrid-perf-work/threaded-deploy/tree/game/export_presets.cfg` is the reference for the setting), then `sh ~/projects/wargrid-p2-work/threaded-tree/tools/export_build.sh "Web Bench" ~/projects/wargrid-p2-work/web-bench-threads/index.html`. Both exit 0; record sizes of `index.wasm` and `index.pck`.
- [ ] **Step 3: Native row, alone:** `uptime; godot --headless --path game --script res://benchmarks/bench_runner.gd > ~/projects/wargrid-p2-work/t6-native.log 2>&1; uptime`. Record `TEAM MATCH`, `TEAM TIMING`, `TEAM MEAN`, `WORST TICK bench team` lines. The Firefox runs wait for stop gate (a).

---

### Task 7: Voice pipeline and A/B page

```text
Task: render the unit lines in three voices, give synth.py its unit-voice entry and treatments, and build the A/B page (outside the repo).
Owns: tools/audio/synth.py, tools/audio/test_synth.py; outside the repo: ~/projects/wargrid-sound-work/sourcing/voice/{render.py,VOICES.md,models/,e/,raw/<voice>/}, ~/projects/wargrid-sound-work/venv-piper/, ~/projects/wargrid-sound-work/p2-ab/
Invariant: synth.py output for sfx and the eight announcer lines byte-identical to before; nothing from ~/projects/wargrid-sound-work enters the repo.
Boundary: a model download of the wrong size; Piper's macOS espeak path bug.
Red: the new Python tests fail (no radio, no voice argument, no UNIT_LINES).
Green: sh tools/run_python_checks.sh.
Stop: a model card at the pinned revision no longer states public domain; Piper cannot be installed (record the error).
```

**Interfaces (produces):** in `synth.py`: `UNIT_LINES = {"infantry": ["move", "attack"], "vehicle": ["move", "attack"], "worker": ["move", "work"]}`, `UNIT_VARIANTS = 2`; `load_line(src_dir: Path, line: str, voice: str = "kristin") -> Arr` (reads `voice/raw/<voice>/<line>.wav`); `radio(x: Arr, rng: Rng) -> Arr` (4th-order Butterworth band-pass 300-3,400 Hz, then `sat(…, 1.5)`, plus white noise of amplitude 0.003 from `rng`); `TREATMENTS: dict[str, Callable[[Arr, Rng], Arr]] = {"clean": …, "radio": radio, "c1n": c1n}`; `UNIT_PICKS: dict[str, tuple[str, str]] = {}` (role to `(voice, treatment)`, filled in Task 9); `unit_line(src: Path, role: str, line: str, n: int) -> Arr` = treatment of `load_line(src, f"unit_{line}_{n}", voice)` with `rng_for(f"unit-{role}-{line}-{n}")`, scaled to `VOICE_LUFS`, `tail_fade(…, 0.03)`; `main` writes `OUT/voice/units/<role>_<line>_<n>.wav` for every role in `UNIT_PICKS`. Raw render names: `unit_move_1`, `unit_move_2`, `unit_attack_1`, `unit_attack_2`, `unit_work_1`, `unit_work_2`, wording from Global Constraints.

- [ ] **Step 1: Failing Python tests** in `test_synth.py`: `test_unit_lines` (`UNIT_LINES` exactly as above, `UNIT_VARIANTS == 2`); `test_load_line_reads_voice_folder` (a `raw/john/x.wav` fixture loads with `voice="john"`, length as `test_load_line_pads_and_resamples`); `test_radio_band_limited` (1 s of seeded white noise: same rng seed gives equal output, finite, same length, spectral energy below 200 Hz under 1 % of the total); `test_treatments_known` (`set(TREATMENTS) == {"clean", "radio", "c1n"}`; every `UNIT_PICKS` value names a treatment in it and a voice in `{"john", "norman", "bryce"}`). Red: `sh tools/run_python_checks.sh > ~/projects/wargrid-p2-work/t7-red.log 2>&1` fails on these.
- [ ] **Step 2: Implement** in `synth.py`; check the invariant: copy `main`'s `tools/audio/{synth,process}.py` to `~/projects/wargrid-p2-work/synth-main/` (`git show main:<path>`), run both versions as `python3 <synth.py> ~/projects/wargrid-sound-work/sourcing <out>` (outs `synth-main-out`, `synth-check`), and `cmp` every `sfx/*.wav` and `voice/*.wav` between them (byte-identical). Green: `sh tools/run_python_checks.sh` exit 0.
- [ ] **Step 3: Piper (approved re-download, user, 2026-11-13).** Venv `~/projects/wargrid-sound-work/venv-piper` with Python 3.14 (`python3.14 -m venv`), `pip install piper-tts==1.8.0`; copy the wheel's `espeak-ng-data` to `~/projects/wargrid-sound-work/sourcing/voice/e/espeak-ng-data` (short-path workaround, VOICES.md). For `john`, `norman`, `bryce`: download `en_US-<name>-medium.onnx`, `.onnx.json` and `MODEL_CARD` from `https://huggingface.co/rhasspy/piper-voices/resolve/e7229f7d33a10e145e109b886d661984201ac3c4/en/en_US/<name>/medium/` into `sourcing/voice/models/`; each `.onnx` must be 63,531,379 bytes; each MODEL_CARD's licence line must still read public domain (quote it into VOICES.md under a dated line).
- [ ] **Step 4: Raw renders.** Extend `render.py` with the six unit texts behind a `--units` flag (same `SynthesisConfig`); render `john norman bryce` into `sourcing/voice/raw/<voice>/unit_*.wav`.
- [ ] **Step 5: A/B page** in `~/projects/wargrid-sound-work/p2-ab/`: a scratch script there (run with `python3 -I`, `sys.path` set to `~/projects/wargrid-wt-p2/tools/audio`) renders every voice x treatment x raw line through `TREATMENTS` and the same level scaling (54 files). `index.html`: one step per role (infantry, vehicle, worker) showing a labelled grid voice x treatment, each cell playing that role's four lines, pick one cell; a last step with the six texts in editable fields; every choice POSTs all answers so far as JSON to `/result`. Served by `python3 -I tools/serve_web_bench.py ~/projects/wargrid-sound-work/p2-ab ~/projects/wargrid-sound-work/p2-ab/results 8061`; not opened yet (stop gate (a)). Check the page loads with `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8061/` = 200, then stop the server.

---

### Task 8: P2 focus card and docs

```text
Task: ship the P2 focus card first in the picker; living docs name what P2 changed.
Owns: game/data/playtest/focus.json, game/tests/test_playtest.gd, docs/guide/05-presentation.md, docs/STATUS.md (F1, F4 rows), docs/packages.md (P2 notes)
Invariant: the three P1 cards unchanged; no "(user, DATE)" tag invented.
Red: PT1 with the new SHIPPED list fails.
Green: test_playtest; test_playtest_overlay; full suite.
Stop: a playtest test other than PT1, PT2, PT6 needs its expectation changed.
```

- [ ] **Step 1:** Prepend to `focus.json` (newest first, the default card):
  ```json
  {"id": "p2-you-clicked", "title": "Every order heard",
   "new": ["Units answer every order with a short voice line.", "The menu has sections; the relay URL sits under Advanced.", "Match music is shuffled each match."],
   "try": [
    {"id": "move", "text": "Move infantry, a vehicle and a worker with a right-click", "trigger": "move"},
    {"id": "attack", "text": "Attack an enemy with a right-click", "trigger": "attack"},
    {"id": "work", "text": "Send workers to collect supplies", "trigger": "gather"},
    {"id": "online", "text": "Give orders in an online match"},
    {"id": "music", "text": "Start a second match and listen to the first track"},
    {"id": "paste", "text": "Online: Create, Copy the code, then paste a relay URL under Advanced"}],
   "questions": [
    {"id": "heard", "text": "Every order I gave felt heard"},
    {"id": "not_chatty", "text": "The voices stayed out of the way when I clicked fast"},
    {"id": "menu", "text": "The menu sections made it easy to find things"},
    {"id": "music", "text": "The match music felt varied between matches"}]},
  ```
  Tests: `SHIPPED := ["p2-you-clicked", "p1-frc-economy", "p1-frc-tunnels-online", "p1-look-and-m6-fixes"]`; PT6 picker count 4 and item 1 now sets `p1-frc-economy`; PT2 default is `SHIPPED[0]`. Red first (PT1 with the new list before the json edit), then green.
- [ ] **Step 2: Docs.** `05-presentation.md`: sound section, one paragraph on unit voices (roles from definitions, line per command type, speaker rule, skip while playing, separate `Voice` player, played in `_submit`; names `unit_voice.gd`, `SoundDirector.order_voice`, `SoundPlayer.order`); music: shuffled per match; launcher: the sections and the Advanced fold. `STATUS.md`: F1 and F4 rows get "fixed on `p2-you-clicked`, not merged". `packages.md` P2 notes: the card id. Check links (`rg -n '\]\(' <changed docs>`, open each relative target) and `sh tools/check_public.sh` exit 0.

---

### Stop gate (a): batched browser and window session

Coordinator, with the user present; ask before each window or sound; record each result in the verification file.

- [ ] A/B page: `python3 -I tools/serve_web_bench.py ~/projects/wargrid-sound-work/p2-ab ~/projects/wargrid-sound-work/p2-ab/results 8061` in the background, `open -a Firefox http://127.0.0.1:8061/`. Read the last `results/web-*.log`: picks per role and wording. If wording changed: re-render (Task 7 Steps 4-5) and let the user listen once more. Then run Task 9.
- [ ] Test deploy of the Task 9 tree (approval asked): `sh tools/deploy_web.sh test`, `/health` 200. F5 repro by the user's hand on the test app (`wargrid-web-test`, test relay): Create, Copy the room code, open Advanced, paste a URL into the relay field. Record exactly what the field shows. Then Task 10.
- [ ] Web bench, Firefox with a dedicated profile (`~/projects/wargrid-p2-work/ff-profile`, `open -na Firefox --args -profile <dir> -no-remote <url>`; never the user's own profile), tab in front, nothing else heavy running (`pgrep -fl 'godot|generalszh'` empty, `uptime` at start and end): `python3 -I tools/serve_web_bench.py ~/projects/wargrid-p2-work/web-bench ~/projects/wargrid-p2-work/web-results`, open `http://127.0.0.1:8060/`, wait for `BENCH POSTED`; then the same for `web-bench-threads` (`cross_origin_isolated=true` expected in the header line). Report per build (native from Task 6, web single-threaded, web threaded): `TEAM TIMING` p95, `TEAM MEAN`, `WORST TICK bench team`, `TEAM MATCH` end tick; no pass/fail (the 3v3 decision stays the user's).
- [ ] Rendered benchmark rerun, last, alone: `sh tools/run_game.sh res://scenes/movement_benchmark.tscn > ~/projects/wargrid-p2-work/gate-a-render.log 2>&1`; header `vsync=off`, `RENDERED BENCHMARK PASSED 4`; `uptime` at start and end.

---

### Task 9: Picked voices into the game (during gate a)

```text
Task: replace the placeholders with the picked lines rendered by synth.py; credit them.
Owns: tools/audio/synth.py (UNIT_PICKS, text only if wording changed), tools/audio/test_synth.py, game/audio/voice/units/*.wav, game/audio/CREDITS.md, game/tests/test_credits.gd
Invariant: .import params unchanged (mono, QOA); sfx and announcer files byte-identical.
Red: CR-U fails (no rows); the UNIT_PICKS completeness test fails.
Green: test_credits; test_order_voice; run_python_checks; full suite.
Stop: a rendered line peaks over -1 dBFS at -24 LUFS (scale_to raises); raw committed audio over 20,000,000 bytes.
```

- [ ] **Step 1: Failing tests.** `test_synth.py` `test_unit_picks_cover_roles`: `set(UNIT_PICKS) == set(UNIT_LINES)`. `test_credits.gd` `test_unit_voice_rows` (CR-U): for each of the 12 file names, `CREDITS.md` has a row starting `` | `voice/units/<file>` | `` whose source URL contains `huggingface.co/rhasspy/piper-voices/blob/e7229f7d33a10e145e109b886d661984201ac3c4/en/en_US/` and the picked voice name.
- [ ] **Step 2:** Set `UNIT_PICKS` from the gate result; `python3 tools/audio/synth.py ~/projects/wargrid-sound-work/sourcing ~/projects/wargrid-p2-work/synth-out`; copy only `voice/units/*.wav` over the placeholders; `cmp` its sfx and announcer outputs against `~/projects/wargrid-p2-work/synth-main-out/` (Task 7, identical). Record each line's `lufs` and `peak` print in the evidence row. `godot --headless --path game --import`; `git diff --stat game/audio/voice/units/*.import` empty.
- [ ] **Step 3: Credits.** Header sentence: unit lines rendered with Piper `en_US-<picked voices>-medium` and treated by the same script (keep the kristin sentence CR4 checks); add bryce's base-model caveat from VOICES.md if bryce is picked. 12 rows in the voice rows' shape: title `-`, source URL the voice's `MODEL_CARD` at the pinned revision, author Wargrid, `GPL-3.0-or-later`, changes "`<treatment>` by `tools/audio/synth.py` (en_US-<voice>-medium)".
- [ ] **Step 4: Green.** `WARGRID_TEST_ONLY=test_credits`, `=test_order_voice` exit 0; `sh tools/run_python_checks.sh` exit 0; full suite, lint, warnings, check_public exit 0. Size: `git ls-files -z game/audio | xargs -0 stat -f %z | awk '{s+=$1} END {print s}'` <= 20000000.

---

### Task 10: F5 outcome

Replaced by [the F5 addendum](2026-11-13-p2-f5-paste-and-links.md): reproduced by the user on the test app, cause in Godot's web clipboard, fixed by 10a-10c.

---

### Task 11: Exit checks and ledger row

```text
Task: run every gate once on the final tree and record it.
Owns: docs/reference/performance.md (one History row), the verification file
Invariant: no budget, ceiling or F changed.
Stop: any check fails; run_benchmark.sh's BUDGET EXCEEDED line names a layout other than the rows already accepted as exceeded.
```

- [ ] Full suite (`TESTS PASSED`, exit 0), `run_lint.sh`, `run_warnings.sh`, `run_python_checks.sh`, `run_shell_checks.sh`, `check_public.sh`; `sh tools/run_netplay.sh match` (pinned terminal tick unchanged); `git diff main -- game/scripts/simulation game/scripts/net` empty; `git diff main --stat`. Each with its tree (`git rev-parse --short HEAD`, "+ uncommitted" if dirty).
- [ ] `pgrep -fl 'godot|generalszh'` (none), `uptime`, `sh tools/run_benchmark.sh > ~/projects/wargrid-p2-work/t11-bench.log 2>&1; echo "exit=$?"`, `uptime`. Expected `BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1`.
- [ ] One History row in `performance.md`, in the shape of the last P1/c1 rows: headless numbers and judgement (no simulation change: equal within noise to the last row); the rendered rerun from gate (a) with its tree (rerun at gate (b) if presentation code changed since); report-only lines: the canary (Task 5), the browser against native team match per build (gate a), each labelled "report-only, no budget". Load over 2.0 at start: tag "host under load", rerun once.
- [ ] Pending for the user: CI on Linux and Windows plus `sh tools/compare_local_traces.sh <run id>` (needs a push, gate c), playtest (gate b).

---

### Task 12: Gate review and lean pass (Opus)

```text
Task: one substantive fresh-context review of the branch and one lean-only pass.
Stop: a critical or important finding that changes a spec decision parks for the user; others are fixed test-first by a Sonnet fix task, then Task 11 reruns.
```

- [ ] **Step 1:** Fresh Opus (high) reviewer, no implementation context. Brief: `git -C ~/projects/wargrid-wt-p2 diff main...HEAD`, the spec, this plan's Global Constraints and Review Focus, the verification file; it names, per new test (OV1-OV12, N20-N26, JL1-JL6, PS1-PS6, MU1-MU2, PO18, BM21-BM22, CR-U, the synth tests), the production change that makes it fail; checks docs claims against the code; no repo-wide search.
- [ ] **Step 2:** `/ponytail-review` on the same diff (over-engineering only); apply cuts that keep every test green and remove no test or check.
- [ ] **Step 3:** Findings and rulings in the verification file; fixes test-first; Task 11 again.

---

### Stop gate (b): focus card playtest

- [ ] Ask for the test deploy of the final tree (gate c approval), `sh tools/deploy_web.sh test`, `/health` 200. The user plays card `p2-you-clicked` offline and online; the session file lands in `~/projects/wargrid-playtests/`. `python3 tools/playtest_session.py <file>` and `sh tools/replay_session.sh <file>` (`REPLAY MATCHED` per offline match) recorded. If Task 10 changed code, the user re-checks the F5 paste here. Rendered rerun if presentation code changed after gate (a).

### Task 13: Playtest fixes and findings

```text
Task: fix problems inside the P2 card's focus (orders heard, voice chatter, menu sections, music, F5); everything else goes on the findings list.
Owns: whatever the fix needs inside the P2 scope; docs/STATUS.md findings list; the verification file
Stop: a fix would change a spec decision or leave the P2 scope.
```

- [ ] Each focus problem: failing test, fix, green, full gates (Task 11 checks for the changed area; rendered rerun with approval if presentation changed). Other findings: one STATUS row each with the card id. P2 exit = card playtested and its focus problems fixed (packages.md).

### Stop gate (c): push, deploy, merge — only with the user's explicit approval, each named.

---

### Task 14: Recorded playtest match row (after the P2 exit, own commit, report-only)

```text
Task: replay the offline match of the P2 playtest session headless as a timed row.
Owns: game/benchmarks/p2_playtest_match.json (new fixture), game/benchmarks/run_recorded_match.gd (new), docs/reference/performance.md (one report-only row)
Invariant: no screenshot, marker text or name in the fixture; run_benchmark.sh untouched.
Stop: the replay digest differs from the recorded end_digest (the fixture is not from this simulation).
```

- [ ] **Step 1: Fixture.** From the session file, the offline match the user names (default: the longest offline match), keep only `build`, `map`, `seed`, `factions`, `seat`, `end_tick`, `end_digest`, `result`, `commands`: `python3 -I -c 'import json,sys; s=json.load(open(sys.argv[1])); m=max((x for x in s["matches"] if x["mode"]=="offline"), key=lambda x: x["end_tick"]); json.dump({k: m[k] for k in ["build","map","seed","factions","seat","end_tick","end_digest","result","commands"]}, open(sys.argv[2],"w"), indent=1)' <session> game/benchmarks/p2_playtest_match.json`. `sh tools/check_public.sh` exit 0.
- [ ] **Step 2: Runner** `run_recorded_match.gd` (`extends SceneTree`): `Skirmish.create(true, "ai", {1: factions[0], 2: factions[1]}, MatchSettings.map_path(map), MatchSettings.starts(map, seed))`; commands from `Wire.decode` per line, issued at their tick as the oracle does (`headless_client.gd` `_replay_oracle`); time issue plus `step()` per tick until `end_tick` or match over; `WARMUP := 300`. Prints `RECORDED MATCH map=%s seed=%d ticks=%d commands=%d digest=matched`, `RECORDED TIMING <Stats.summary JSON>`, `RECORDED MEAN ms=%.3f`, `Stats.worst_tick_line("recorded", "p2_playtest", samples, WARMUP)`. Exit 1 with `RECORDED MATCH DIFFERS` when the end digest differs, or when no command was issued after `WARMUP`.
- [ ] **Step 3:** One run alone (`uptime` before and after), log `~/projects/wargrid-p2-work/t14-recorded.log`; ledger History row "report-only, no budget"; full suite, lint, warnings exit 0; own local commit.
