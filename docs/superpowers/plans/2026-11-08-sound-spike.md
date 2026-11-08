# Sound Spike Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task (coordinator plus one fresh subagent per task, per [milestone prompt](../../milestone-prompt.md) "Unattended run"). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wargrid gets futuristic battle and UI effects for every weapon of USA, China and FRC, deaths and destroyed buildings, a vocoder announcer for the local player, launcher and match music, and three volume sliders. Presentation only.

**Architecture:**
- The simulation gains two read-only accessors. The scenes hand each step's transient events to a pure `SoundDirector`, which also diffs consecutive presentation snapshots once per frame. It returns play requests, and a thin `SoundPlayer` node plays them through bounded voice pools. An `Announcer` queue turns director triggers into one voice line at a time.
- Effects and voice lines come from a seeded repo script (`tools/audio/synth.py`) and are committed as WAV. Music is loudness-normalised and encoded by `tools/audio/process.py`.

**Tech Stack:** Godot 4.7.2-stable typed GDScript; mono 16-bit 44,100 Hz WAV imported as QOA; Ogg Vorbis via `oggenc` (`vorbis-tools` 1.4.3); ffmpeg (`ebur128`, `loudnorm`); Python 3.12 (stdlib, plus numpy and scipy for `synth.py` only).

**Spec:** [Sound spike design](../specs/2026-11-08-sound-spike-design.md), approved 2026-11-08. Run rules: [milestone prompt](../../milestone-prompt.md). Handoff `docs/sound-spike-prompt.txt`, resume record `docs/reference/sound-spike-verification.md`, evidence `docs/reference/sound-spike.md`, ledger [performance](../../reference/performance.md). Branch `spike-sound` (worktree `../wargrid-wt`), base `main` `893332f`.

**DEFINED PATH `SOUND_WORK`** = `$HOME/projects/wargrid-sound-work` (outside the repo, durable, never committed):
- `synth/synth_scipy.py`, `synth_abstract.py`, `voice_spike.py`, `voice_spike_clear.py`, `voice_spike_c1n.py`, `voice_spike_lufs.py`, `ingame_spike.py`;
- `synth/out/abstract/*-f.wav` (the heard effects) and `synth/out/voice-spike-c1n/<line>-c1n.wav` (the heard lines);
- `sourcing/MANIFEST.md`, `REJECTED.md`, `music/` (the five picks), `voice/VOICES.md`, `voice/raw/kristin/*.wav` (22,050 Hz mono raw renders; no Piper run needed).

## Model routing

- **Sonnet (medium): every task.** When a step still leaves a real choice, return `BLOCKED`; never guess.
- **Opus (high):** the gate reviews (A, B, exit) and any re-expansion that Task 1's facts force.

## Working rules for the executor

- Start from the resume record; read only the active task plus the sections it names (`rg -n '^#' <plan>`, then ranges).
- Every suite, benchmark, netplay, lint and parity call passes `timeout: 600000`. Output goes to a file; read only `CASES n CHECKS n FAILURES n` and `TESTS PASSED`, on failure only the failing lines.
- **Trace check** ("traces identical" below), into a fresh `$d`:
  1. `WARGRID_REPLAY_TRACE=$d/replay.tsv WARGRID_ECONOMY_REPLAY_TRACE=$d/economy.tsv WARGRID_COMBAT_REPLAY_TRACE=$d/combat.tsv WARGRID_TEAM_REPLAY_TRACE=$d/team.tsv sh tools/run_tests.sh > $d/suite.log 2>&1`
  2. `NETPLAY_OUT=$d/net sh tools/run_netplay.sh match > $d/net.log 2>&1`
  3. Against `$d0 = $SOUND_WORK/traces/base` (Task 1): `python3 tools/compare_replays.py $d0/X.tsv $d/X.tsv` for `replay`, `economy`, `combat`; `--interval 200 --rows 100` for `team`; `--interval 30 --rows 0 $d0/net/s1.tsv $d/net/s1.tsv`. Each prints `REPLAYS MATCHED`; the netplay terminal tick is equal.
- Before reporting a task done: `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, and `sh tools/run_python_checks.sh` when Python changed.
- Workflow lint: `go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.12` (CI pins 1.7.12).
- Local commit after each green checkpoint is pre-authorized; subagents never commit. Visible windows, browser runs, installs, push and merge need approval.
- Comments: only the why, one line. No EA names in code, data, UI or files.
- **No new simulation command,** so no same-tick interaction cases. The only simulation change is two accessors (Task 1), proven by the trace check.

## Code anchors (pinned on `893332f`; the design commit `6fbb421` touches no code)

- **Events** (cleared in place at `simulation.gd:497-498` inside `step()` :494, which returns early when `match_over()`; deep-copied into `snapshot()` :640):
  - shot `{type, tick, attacker_id, target_id, damage, splash}` (`combat.gd:491` `_hit`); attackers are units or defence buildings (`fire_defences` :389); `splash == true` marks secondary hits;
  - death `{type, tick, object_id}` (`combat.gd:383` volley, :420 defences, `containers.gd:187` passengers); the object is already removed;
  - command result `{tick, player, sequence, ok, error}` (`simulation.gd:360`, every type except `move`); funds error `"Insufficient credits"` (`simulation.gd:260`, `construction.gd:76`).
- **Weapons:** `Combat.weapon_of` (`combat.gd:469`) uses `Registry.kind(kind).weapon_tiers[combat.tier]` when present, else `CombatDefinitions.profile(kind).weapon`. `Shared.WEAPONS` and `Shared.ARMOR` (`definitions/shared.gd`) are the only weapon and armor tables; 15 weapons on `893332f`.
- **Snapshot:** entity `id, owner, kind, position, combat{tier}`; building `id, owner, kind, origin, completed, queue[{id, kind, work}]`, plus `rebuild` on FRC rubble holes and `hole_id` on a rebuild site (`rebuild_holes.gd:53`, `place_rebuild`); hole kinds have a `hole` key in `Registry.kind`; player `id, team, power_supply, power_demand`; `match` `{players, status: setup|ongoing|won|draw, winner (a team), ended_tick}`; `tick`.
- **Production:** `production.gd:96-107` pops the queue head when its unit spawns; `spawns_on_complete` units come from `simulation.gd:815-816`, not from a queue; hole workers from `rebuild_holes.gd` `_spawn_worker`.
- **Scenes:**
  - `main.gd` `_ready` :35 builds `PauseMenu` into `$HUD`, sets `simulation`, then `_refresh()` :47, so a subclass's `_refresh_hud` runs before its own `_ready` continues; `_physics_process` :90 skips while the offline Esc menu pauses; `_submit` :251 sets `_error` from `issue_command`.
  - `skirmish_main.gd`: `_step_simulation` :20, `_restart` :35 (ends with `_refresh()`), `_refresh_hud` :150.
  - `online_main.gd`: `_step_simulation` :47 loops `CATCH_UP_STEPS` (2) over `_lockstep.advance` (:51-55), turns new `rejections()` into `_error` (:56-59); `_submit` :62 does not call super; `_restart` is a no-op.
  - Scene roots are `Node`; `WorldView` (`Node2D`) and `Camera2D` are siblings. Plane px = `Iso.world_to_plane(cells)` = `(32 (x − y), 16 (x + y))` (`presentation/isometric.gd`).
  - `launcher.gd` `_ready` :19 returns early for `HEADLESS_FLAGS`; `launcher.tscn` `Center/Box` holds `Title, Offline, FactionRow, RelayUrl, Create, JoinRow, Status, Legal`. `pause_menu.gd` `_init` builds its buttons in code into `_main_box`.
- **Tests:** suites `extends RefCounted`, `cases() -> Array[Callable]`, `test_x(runner) -> bool`, `runner.check(cond, "<ID> msg")`, registered in `SUITES` (`tests/run_tests.gd:5`). Layout tests N5 `test_online_scene.gd` `test_launcher_layout` :174, E8 `test_pause_menu.gd` `test_menu_layout` :169. Online harness `_online`, `_peer_packets`, `_run` (`test_online_scene.gd:35-53`). `test_one_snapshot_per_refresh` in `test_base_scene.gd` and `test_skirmish_scene.gd`.
- **CI / release:** `ci.yml` job `tools` (:272-297) runs `pip install -r tools/requirements-dev.txt` (`ruff==0.17.3`, `mypy==2.4.1`, `gdtoolkit==4.5.0`), `sh tools/run_python_checks.sh`, then the tool tests with `python3`. `tools/pyproject.toml` mypy `mypy_path = ".:zh_map:zh_parity"`. `release.yml:59` `extras=(LICENSE game/data/maps/NOTICE.md build/release/GODOT_LICENSES.txt)` go into the zips and `web/site/`.
- **Rendered benchmark:** `scripts/debug/movement_benchmark.gd`, layouts `open, dense, ashfall, horde`; `horde` has combat.

## Global Constraints

- **Presentation only:** no simulation, state-hash, replay or netplay trace change. Presentation never calls `sim.next_random()`; the director takes an injected `RandomNumberGenerator`, seeded in tests.
- **Ticks (30 Hz), counted in sim ticks, never wall clock:** a line expires 150 ticks (5 s) after its request; cooldowns `base_under_attack` 900 (30 s), `building_lost` 900 (30 s), `low_power` 3600 (120 s), others none; rifle burst gap `delay_ticks + 1` from the weapon definition. The music gap is 25 s wall clock.
- **Units:** 1 Wargrid cell = 25 Zero Hour world units (inferred, [Zero Hour verification](../../reference/zero-hour-verification.md)). Falloff target: full volume to 175 world units = 7 cells, −6 dB per doubling, silence past 800 world units = 32 cells. One cell step along a world axis is `|(32, 16)|` = 35.78 plane px, so 7 cells = 250 px and 32 cells = 1145 px. Every brief and test states which of ticks, seconds, cells, world units or plane px it uses.
- **Voices:** 25 `AudioStreamPlayer2D` (world) and 2 `AudioStreamPlayer` (UI) on bus `Effects`; 1 `AudioStreamPlayer` on `Voice`; 1 on `Music`. Per-cue limits from spec §2; over a limit or with no free voice, the new request is dropped.
- **Mix (levels baked into the files):** buses at 0 dB, sliders default 1.0 (100 %). Music −30 LUFS; voice lines −24 LUFS; each effect at −30 + offset LUFS measured on the clip looped to at least 3 s, offsets (dB) `rifle_burst` +0.4, `carbine` +0.4, `cannon` +4.2, `explosion` −0.8, `vehicle_death` +6.2, `building_small` +6.2, `building_large` +6.2, `infantry_death` −2.0, `click` −4.3, `error` −4.3. Peaks ≤ −1 dBFS. Each cue has `gain_db` for playtest tuning (0, except `launch` −6 from spec §2). Too quiet overall: raise everything together, never one category. Addendum (Gate B, user): the Effects bus is trimmed -6 dB (`AudioSettings.EFFECTS_TRIM_DB`), so "buses at 0 dB" holds for Music and Voice only.
- **Assets:** `game/audio/sfx/<10 ids>.wav` and `game/audio/voice/<8 line ids>.wav`, mono 16-bit 44,100 Hz, imported as QOA with Mono on and Max Rate set by measurement; `game/audio/music/<5 ids>.ogg`, stereo, `oggenc -b 96`. No `.qoa`, `.opus` or `.mp3` in the repo. Raw committed audio ≤ 20,000,000 bytes.
- **Licences:** Wargrid-made audio is GPL-3.0-or-later; music is CC BY 3.0 / 4.0, each licence page re-fetched and quoted at import; only CC0 and CC-BY. Never write a licence, author or URL not read on a fetched primary page.
- **Python:** numpy and scipy only in `tools/audio/synth.py` and its test; other tools stdlib. Tools write only into the `OUT_DIR` given and exit 2 for a `SRC_DIR` inside the repo.
- **Owners:** announcer lines for the local player only; positional effects for every owner (no shroud until M7.9); victory and defeat against the local player's team.
- **Out of scope:** spec non-goals (presets, unit replies, engine/money/supply/flamethrower sounds, faction music, shroud culling, an options menu beyond the sliders).

## Review Focus

1. **Frames where the sim does not advance** (offline Esc pause, `step()` returning early after the match ends without clearing its events, online waiting): no cue or line repeats. Task 1 `test_stalled_tick_is_collected_once`, Task 4 `test_stalled_tick_is_silent`.
2. **Restart after a match:** the new start makes no unit-ready, placement or construction sound, queued lines are dropped, the first shot of the new match is heard. Task 4 `test_first_shot_after_restart_is_heard`, Task 5 `test_restart_starts_silent`.
3. **Settings file missing, corrupt or out of range, and the suite on a developer machine:** defaults and clamping, no error, the suite never writes the real `user://settings.cfg`. Task 6 `test_settings_missing_and_corrupt`, `test_tests_use_scratch_settings`.
4. **Bursts:** 20 infantry and 6 tanks dying on one tick, a Pickup dying with 5 passengers, a fight 40 cells away while one plays on screen: no error, limits hold, the distant fight takes no voice. Task 4 `test_mass_death_batch`, `test_container_burst`, `test_far_shot_takes_no_voice`.
5. **Local seat 2 with a team mate, and the online start** (setup, then `setup_seat` adds a builder and a completed HQ): lines only for seat 2's own objects, victory follows the team, nothing plays at the online start. Task 4 `test_setup_phase_is_silent`, Task 5 `test_announcer_follows_local_seat`, `test_online_start_says_nothing`.

## Stop gates and checkpoints

- **Gate S (user), end of Task 2:** final effects, lines and processed music confirmed by ear in a Firefox listening page.
- **Gate A, end of Task 3:** the user picks Max Rate per folder; Opus review of Tasks 1–3.
- **Gate B, end of Task 6:** windowed run with approval (falloff, zoom, QOA vs raw voice, mix); Opus review of Tasks 4–6.
- **Exit, Task 7.** Checkpoint restarts after Tasks 1 and 4.

---

### Task 0: Docs, records, handoff

```text
Task: record the spike, its evidence and the audio licence decision, write the handoff, delete the superseded drafts.
Owns: docs/blueprint.md (§7 entry, §12 bullet), README.md, AGENTS.md, docs/session-notes.md, new docs/sound-spike-prompt.txt, docs/reference/sound-spike-verification.md, docs/reference/sound-spike.md; deletes the two untracked drafts.
Invariant: nothing under game/, tools/ or .github/ changes; root prompt.txt untouched.
Boundary: evidence in the old draft design survives its deletion.
Red: n/a (docs).
Green: rg link check below finds every new path; git status shows only the owned paths.
Stop: a status label needs wording the spec does not give.
```

- [ ] **Step 1: Evidence note** `docs/reference/sound-spike.md`, sections:
  - "Zero Hour findings": copy, before Step 6 deletes it, the evidence block of `docs/superpowers/specs/2026-11-07-m6.5-sound-design.md` (heading "Zero Hour evidence", lines 36–48) and its mix calculation (line 33), labelled "EA source `0a05454d85`, retail `INIZH.big`, read in memory, not re-verified"; plus spec §3's `getEffectiveVolume` note (no ducking).
  - "Licence sources": table `file | page URL | quoted wording | fetched` from `$SOUND_WORK/sourcing/MANIFEST.md` rows M04, M05, M06, M08, M10 and `sourcing/voice/VOICES.md` (kristin, revision `e7229f7d33a10e145e109b886d661984201ac3c4`), marked "fetched 2026-11-07, re-verified in Task 3".
  - "Mix calculation": spec §3 levels, `$SOUND_WORK/synth/ingame_spike.py` `OFFSET`, approved file `synth/out/ingame/ingame-zh.wav`.
  - "Listening rounds": spec §Approaches (announcer variants, c1n verdicts, the ±5 % vehicle pitch), dated.
  - "Departures": unit ready and construction complete as lines; no unit-lost line; insufficient credits plays its line, not the error click (as Zero Hour: `ControlBarCommandProcessing.cpp:253` and `PlaceEventTranslator.cpp:199` play only `EVA_InsufficientFunds` plus a silent text message); EVA priorities from retail `Eva.ini` (BuildingLost 8, BaseUnderAttack 7, InsufficientFunds 3, LowPower 2, UnitLost 1, all expiring after 5000 ms); unit ready only from a production queue, as Zero Hour's `VoiceCreated` in `ProductionUpdate.cpp:834`; UI-only errors set by `base_main` are silent.
  - Empty sections filled later: "Godot attenuation" (Task 1), "Assets and levels" (Tasks 2–3), "Gate rulings".
- [ ] **Step 2: Verification file** `docs/reference/sound-spike-verification.md`: the milestone-prompt resume record block (branch `spike-sound`, base `893332f`, next action "Task 1"), then append-only sections "Baseline and trace checks", "Measurements", "Gate rulings".
- [ ] **Step 3: Handoff** `docs/sound-spike-prompt.txt`, modelled on `docs/performance-spike-prompt.txt`: "reading this file does not authorize starting"; NEXT EXACT ACTION (dispatch Task 1 from the resume record); process (milestone prompt "Unattended run", Sonnet medium per task, Opus high for gate reviews); state at handoff (branch, worktree `../wargrid-wt`, base, `SOUND_WORK`); read first (AGENTS, spec, this plan's header to Stop gates); the stop conditions at the end of this plan.
- [ ] **Step 4: Blueprint:** a §7 section "Sound spike (user, 2026-11-08; after M7, before Ground batch A)" inserted before "### Ground batch A", 4–6 lines: scope (spec Goals), links to spec, plan, handoff, "exit: user playtest offline and online". §12 bullet: "**Decided by user 2026-11-07:** Wargrid-made audio (generated effects, rendered announcer lines) is GPL-3.0-or-later; third-party audio keeps its CC0/CC-BY terms, listed in `game/audio/CREDITS.md`."
- [ ] **Step 5: Status lines:** AGENTS.md intent paragraph gains "the sound spike has an approved design and an execution plan (2026-11-08), not started"; a read-before bullet names spec, evidence note, plan, handoff and resume record. README status gets the same sentence. `docs/session-notes.md`: "Choose a licence for original art and audio" becomes "… original art", plus a dated line for the spike.
- [ ] **Step 6:** Delete `docs/superpowers/specs/2026-11-07-m6.5-sound-design.md` and `docs/superpowers/plans/2026-11-07-m7.2-sound.md` (untracked).
- [ ] **Step 7:** `rg -n 'sound-spike' AGENTS.md README.md docs/blueprint.md docs` lists every new file; `rg -n 'm6.5-sound|m7.2-sound' AGENTS.md README.md docs/blueprint.md docs` finds nothing but the evidence note's provenance line. Commit `Plan the sound spike`.

### Task 1: Risk facts, event accessors, per-step collection

```text
Task: measure Godot's 2D attenuation, prove per-step event collection during online catch-up, prove traces equal with the accessors.
Owns: simulation.gd (two accessors), new presentation/sound_director.gd and sound_player.gd (collection only), skirmish_main.gd, online_main.gd, new tests/test_sound.gd (registered), evidence note, verification file.
Invariant: traces identical; test_one_snapshot_per_refresh green in both suites; no snapshot taken per step.
Boundary: a two-step catch-up frame; a stalled tick after match end.
Red: SD1 "collected ticks [t] lack t+1 in a two-step frame".
Green: test_sound.gd, full suite, trace check.
Stop: traces move; Godot's 2D gain is not a distance power curve; zoom still changes the distance with an AudioListener2D.
```

**Interfaces (Produces):**
- `Simulation.combat_events() -> Array[Dictionary]` and `Simulation.command_results() -> Array[Dictionary]` return the live arrays; one comment line "Read-only view; cleared in place by the next step."
- `sound_director.gd` (`RefCounted`, `class_name SoundDirector`): `_init(local_player: int, rng: RandomNumberGenerator = null)` (null becomes a `randomize()`d one); `collect_step(tick: int, events: Array[Dictionary], results: Array[Dictionary]) -> void` ignores `tick <= _last_collected`, else stores `events.duplicate(true)` and `results.duplicate(true)` with the tick; `collected_ticks() -> Array[int]` (pending, oldest first); `update(state: Dictionary) -> Array[Dictionary]` drains the pending steps and returns `[]` (Task 4 adds the rules); `reset() -> void` clears pending steps, previous state and `_last_collected = -1`.
- `sound_player.gd` (`Node2D`, `class_name SoundPlayer`, `name = "Sound"`): `_init(local_player: int)` creates `director`; `collect_step(...)` forwards; `update(state: Dictionary) -> void` calls `director.update(state)`.
- `skirmish_main.gd`: `var _sound: SoundPlayer = null`; `func _ensure_sound() -> void` (creates and `add_child`s it once; called first in `_refresh_hud` and `_collect_sound`, because `main._ready` refreshes before `skirmish_main._ready` continues); `func _collect_sound() -> void` = `_ensure_sound()` then `_sound.collect_step(simulation.tick(), simulation.combat_events(), simulation.command_results())`, called after `simulation.step()` in `_step_simulation`; `_refresh_hud` calls `_sound.update(state)`; `_restart` calls `_sound.director.reset()` right after `simulation = _create_simulation()`.
- `online_main.gd`: `_collect_sound()` inside the catch-up loop after each successful `advance`, never once per frame.

- [ ] **Step 1: Baseline.** Trace check into `$d0 = $SOUND_WORK/traces/base` on the Task 0 commit, then `sh tools/run_benchmark.sh > $d0/bench.log 2>&1` alone with `uptime` at start and end. Record suite totals, the netplay terminal tick and the benchmark summary lines in "Baseline and trace checks".
- [ ] **Step 2: Godot attenuation, source.** Fetch `https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/scene/2d/audio_stream_player_2d.cpp`; quote in "Godot attenuation" the lines that compute the listener position (with and without `AudioListener2D`), the distance, the `max_distance` cut and the gain multiplier, with the URL and date. Hypothesis to confirm, not assume: gain = `pow(1 − d / max_distance, attenuation)` with `d` in global canvas px.
- [ ] **Step 3: Godot attenuation, measured.** Scratch script in the session scratchpad (`quit()` on every path), `godot --headless --path game --script <abs path>`: a looping 1 kHz sine `AudioStreamWAV`, one `AudioStreamPlayer2D` with `max_distance` 1145 px and `attenuation` 1.0 on a bus carrying `AudioEffectCapture`, a `Camera2D` at the origin; for plane distances 0, 250, 500, 716, 1000, 1145, 1200 px and camera zoom 0.5, 1, 2, the RMS of 0.2 s of captured frames in dB. Record the table next to the formula's prediction.
  - Zoom changes the measured gain: add an `AudioListener2D` child of the camera, `make_current()`, re-measure; still changed is a stop. If the listener fixes it, Task 4's `SoundPlayer` owns that listener.
  - The dummy driver captures no frames: record that, keep the source quote as the fact, and move the measurement into the Gate B windowed run (Task 6 Step 6).
- [ ] **Step 4: Pick the values.** Table in "Godot attenuation": Zero Hour gain `min(1, 7 / cells)` (0 past 32 cells) against Godot `(1 − cells / 32) ^ a` in dB at 3.5, 7, 10, 14, 20, 28, 32 cells, for a = 0.5, 1, 1.5, 2. Pick the `a` with the smallest worst-case error from 7 to 28 cells; `MAX_DISTANCE_PX = 1145.0` (32 cells × 35.78 px). Task 4 writes both as `SoundPlayer.ATTENUATION` and `SoundPlayer.MAX_DISTANCE_PX`. Record the isometric limit: one cell is 45.25 px screen-horizontal and 22.63 px screen-vertical, so the audible edge lies at 25–51 cells by direction; the playtest judges it (fallback B, spec §Approaches).
- [ ] **Step 5: Tests** (`SD…`, `test_sound.gd`, registered in `SUITES`):
  - `test_catch_up_collects_every_step` (SD1): `_online(runner, 1)`; run frames without peer packets until `_credit` reaches 2 or more, then `_peer_packets` for the next 3 ticks and one `_run(main, 1)`; that frame advances two ticks `t, t + 1` and `main._sound.director.collected_ticks()` ends with `[t, t + 1]`. Fails if `online_main` collects after the loop.
  - `test_collect_step_copies` (SD2): `collect_step(5, events, [])`, then `events.clear()` and `events[0]` mutated before clear: the stored step still holds the original shot. Fails if references are stored.
  - `test_stalled_tick_is_collected_once` (SD3): `collect_step(20, …)` twice gives `collected_ticks() == [20]`.
  - `test_event_accessors_are_live` (SD4): on a combat fixture, after a step with a shot, `sim.combat_events() == sim.snapshot().combat_events`; after the next step without fire it is empty.
- [ ] **Step 6:** Write stubs first (accessors and director methods returning empty values) so the suite parses, then run. Expected: SD1–SD4 FAIL on their assertion messages.
- [ ] **Step 7:** Implement the Interfaces above.
- [ ] **Step 8:** Green: `test_sound.gd`, full suite (totals = baseline + new cases), lint, warnings, trace check identical. Record. Commit `Collect simulation events per step for sound`. Checkpoint restart.

### Task 2: Generator, voice lines, music tool (ends at Gate S)

```text
Task: port the heard futuristic effects and the c1n vocoder into tools/audio/synth.py, write the music tool, render everything at the spec's levels, and have the user confirm by ear.
Owns: new tools/audio/synth.py, test_synth.py, process.py, test_process.py; tools/requirements-dev.txt, tools/pyproject.toml, .github/workflows/ci.yml (tools job lines); evidence note; $SOUND_WORK/gate-s/.
Invariant: prototypes are read, and run only from SOUND_WORK for the drift check; tools write only into OUT_DIR.
Boundary: a clip whose scaled peak exceeds −1 dBFS; a loudnorm pass that falls back to dynamic mode.
Red: test_synth "ModuleNotFoundError: synth".
Green: test_synth.py, test_process.py, run_python_checks.sh, the faithful-port cmp.
Stop: no cp312 wheel for manylinux x86_64 or macOS arm64; a port differs from its prototype; a peak over −1 dBFS; a dynamic loudnorm; Gate S.
```

**Interfaces (Produces):** the file names `game/audio/sfx/{rifle_burst,carbine,cannon,explosion,vehicle_death,building_small,building_large,infantry_death,click,error}.wav`, `voice/{base_under_attack,building_lost,unit_ready,construction_complete,insufficient_funds,low_power,victory,defeat}.wav`, `music/{stay_the_course,conflict,enemy_spotted,mammoth,hitman}.ogg`.

- [ ] **Step 1: Pins.** `oggenc --version` prints `vorbis-tools 1.4.3`. Fetch `https://pypi.org/pypi/numpy/json`, `…/scipy/json`, `…/scipy-stubs/json`; pick the newest numpy and scipy with `cp312` wheels for `manylinux` x86_64 and `macosx` arm64, and the newest `scipy-stubs` accepting that scipy; record. Append the three `==` pins to `tools/requirements-dev.txt`; `mypy_path = ".:zh_map:zh_parity:audio"`. With approval: `uv tool install --reinstall mypy==2.4.1 --with numpy==<v> --with scipy==<v> --with scipy-stubs==<v>`.
- [ ] **Step 2: `tools/audio/test_synth.py`** (unittest, no ffmpeg; run `uv run --python 3.12 --with-requirements tools/requirements-dev.txt python tools/audio/test_synth.py`):
  - `test_effect_ids_and_seeds`: `synth.EFFECTS` keys are the 10 ids; each seed is `name.replace("_", "-") + "-f"`.
  - `test_effects_sane`: for each id, `synth.prototype_effect(id)` is 1-D float64, finite, peak 0.7 (±1e-9), duration (s) within ±10 % of `rifle_burst` 0.7, `carbine` 0.6, `cannon` 1.5, `explosion` 1.6, `vehicle_death` 1.3, `building_small` 2.2, `building_large` 3.6, `infantry_death` 0.3, `click` 0.05, `error` 0.3.
  - `test_same_seed_same_samples`: two renders `np.array_equal`.
  - `test_effect_targets`: `synth.effect_target(id) == -30.0 + offset` for the Global Constraints offsets.
  - `test_scale_to`: with `measure=lambda x: -20.0`, `scale_to(x, -29.6, measure, "t")` equals `x * 10 ** (-9.6 / 20)`; a target that lifts the peak above `10 ** (-1 / 20)` raises `ValueError` naming `"t"`.
  - `test_load_line_pads_and_resamples`: a 0.1 s 22,050 Hz int16 WAV in a temp `voice/raw/kristin/x.wav` loads to `4410 + 882 + 6615` samples (0.1 s + 0.02 s + 0.15 s at 44,100 Hz).
  - `test_c1n_deterministic`: `c1n` of 0.5 s seeded noise keeps the length, is finite, and repeats exactly for the same seed.
  - `test_refuses_src_in_repo`: `synth.main([<repo>/tools, <tmp>])` returns 2 and writes nothing.
  - `test_wav_format`: `write_wav` reads back via `wave` as 1 channel, 16-bit, 44,100 Hz.
- [ ] **Step 3:** Run. Expected: FAIL `ModuleNotFoundError: synth`.
- [ ] **Step 4: Port `synth.py`** (typed, ruff- and mypy-clean, GPL header line). Port with unchanged numerics and operation order (byte equality depends on it):
  - from `synth_scipy.py`: `SR = 44100`, `t`, `rng_for`, `filt`, `decay`, `sine_sweep`, `reverb`, `mix`, `sat`, `tail_fade`, `fade_bands`;
  - from `synth_abstract.py`: `saw_sweep`, `fm_sweep`, `bitcrush`, `wet`, `f_pew`, `_stack` and the ten `f_*` builders (`f_rifle_burst, f_carbine, f_cannon, f_explosion, f_vehicle, f_building_small, f_building_large, f_infantry, f_click, f_error`); nothing else (no `a_*`, `bell`, page code);
  - from `voice_spike.py`: `load` (as `load_line`), `band_edges`, `env`, `saw`, `carrier`; `LINES` (8 ids, spec §4 order).
  - `EFFECTS: dict[str, tuple[str, Callable[[np.random.Generator], npt.NDArray[np.float64]]]]`; `OFFSET_DB`; `MUSIC_LUFS = -30.0`; `VOICE_LUFS = -24.0`; `PEAK_LIMIT = 10 ** (-1 / 20)`.
  - `prototype_effect(name: str) -> NDArray` = builder output / max |x| × 0.7 (as the prototype `main`); `effect_target(name: str) -> float`; `lufs(x) -> float` (ffmpeg `ebur128` on a float32 temp WAV, last `I:` value, as `voice_spike_lufs.lufs`); `looped(x) -> NDArray` (`np.tile` to at least 3 s); `scale_to(x, target: float, measure: Callable[[NDArray], float], name: str) -> NDArray`; `write_wav(path: Path, x) -> None` (`(x * 32767).astype(np.int16)`, mono, 44,100 Hz).
  - `c1n(x, rng) -> NDArray`, fixed by the spec:

    ```python
    def c1n(x, rng, bands=32, env_hz=80, sib=0.35):
        tone, hiss = carrier(len(x), rng, (110,), 0.0, 1.0)
        out = np.zeros_like(x)
        edges = band_edges(bands)  # geomspace(120, 7500, bands + 1)
        for lo, hi in zip(edges[:-1], edges[1:]):
            sos = butter(4, [lo, hi], "band", fs=SR, output="sos")
            c = sosfilt(sos, hiss if lo >= 2800 else tone)
            out += c / (np.sqrt(np.mean(c ** 2)) + 1e-9) * env(sosfilt(sos, x), env_hz)
        return out + sib * filt(x, "high", 2500)
    ```
  - `main(argv: list[str]) -> int`: `synth.py [--prototype] SRC_DIR OUT_DIR`. Exit 2 when `SRC_DIR` is inside the repo (`process.inside_repo`). Effects: `OUT_DIR/sfx/<id>.wav` = `prototype_effect(id)` when `--prototype`, else `scale_to(prototype_effect(id), effect_target(id), lambda y: lufs(looped(y)), id)`. Lines (both modes): `OUT_DIR/voice/<line>.wav` = `tail_fade(scale_to(c1n(load_line(SRC_DIR, line), rng_for(f"voice-{line}")), VOICE_LUFS, lufs, line), 0.03)`.
- [ ] **Step 5: Faithful-port check** (one-off, recorded, not CI): `uv run … python tools/audio/synth.py --prototype $SOUND_WORK/sourcing $SOUND_WORK/gate-s/proto`; `cmp` each `sfx/<id>.wav` against `$SOUND_WORK/synth/out/abstract/<seed>.wav` and each `voice/<line>.wav` against `synth/out/voice-spike-c1n/<line>-c1n.wav`. Expected: identical. On a difference, run the prototype itself in the same environment into the scratchpad (`python $SOUND_WORK/synth/synth_abstract.py <scratch>` or `voice_spike_c1n.py`): equal to the port means library drift (record both hashes, stop); different means a port bug (fix the port, never tune parameters).
- [ ] **Step 6: Final render:** `synth.py $SOUND_WORK/sourcing $SOUND_WORK/gate-s`. Record per file the looped LUFS and peak dBFS in "Assets and levels".
- [ ] **Step 7: `tools/audio/process.py`** (stdlib): `TRACKS: dict[str, str]` = `stay_the_course` → `music/incompetech/Stay the Course.mp3`, `conflict` → `music/oga-conflict/conflict.ogg`, `enemy_spotted` → `music/oga-enemy-spotted/Enemy spotted.ogg`, `mammoth` → `music/oga-mammoth/mammoth_0.ogg`, `hitman` → `music/incompetech/Hitman.mp3` (relative to `SRC_DIR`). `process.py SRC_DIR OUT_DIR` writes `OUT_DIR/music/<id>.ogg`: first pass `loudnorm=I=-30:TP=-1:LRA=20:print_format=json`, second pass with the measured values and `linear=true`, to a temporary stereo 16-bit 44,100 Hz WAV, then `oggenc -b 96 -o`. Exit 2 for `SRC_DIR` in the repo, 1 on a missing source, a failed tool, or a second pass reporting `"normalization_type" : "dynamic"` (named track). Functions `inside_repo(path: Path) -> bool`, `second_pass(first_pass_stderr: str) -> str` (from the last JSON object).
  - `test_process.py` (stdlib): `test_refuses_source_in_repo`, `test_second_pass_uses_measured_values` (a captured stderr sample gives `measured_I=…:measured_TP=…:measured_LRA=…:measured_thresh=…:offset=…:linear=true`), `test_tracks_are_the_five_picks`.
  - Run `python3 tools/audio/process.py $SOUND_WORK/sourcing $SOUND_WORK/gate-s`; record each track's integrated LUFS (−30 ± 0.5) and size.
- [ ] **Step 8:** `ci.yml` tools job, "Tool tests": add `python3 tools/audio/test_synth.py` and `python3 tools/audio/test_process.py`. Green: both tests, `sh tools/run_python_checks.sh`, actionlint.
- [ ] **Step 9: Gate S.** Write `$SOUND_WORK/gate-s/listen.html`: the 10 effects, the 8 lines and the 5 tracks, each with its LUFS and peak. With the user's go: `open -a Firefox $SOUND_WORK/gate-s/listen.html`. A requested change goes back to Step 4 or 6, recorded verbatim. Commit `Add the effect, voice and music tools`; write the resume record; stop.

### Task 3: Import (ends at Gate A)

```text
Task: commit the confirmed audio with credits, import settings and a guard test; measure size and QOA cost.
Owns: game/audio/** (with .import files), game/audio/CREDITS.md, new tools/test_audio_assets.py, ci.yml (one line), README licence section, evidence note.
Invariant: the committed files are byte-identical to the Gate S files; ≤ 20,000,000 bytes; only the allowed licences.
Boundary: a malformed WAV header; a credit row naming a missing file.
Red: test_every_file_credited "CREDITS.md missing".
Green: test_audio_assets.py, run_python_checks.sh, full suite (totals unchanged, import without ERROR:).
Stop: the budget is exceeded; a licence page differs from MANIFEST.md.
```

- [ ] **Step 1: `tools/test_audio_assets.py`** (stdlib unittest, typed):
  - `test_layout`: `sfx/` holds exactly the 10 ids, `voice/` the 8 line ids, `music/` the 5 track ids; nothing else under `game/audio/` but `.import` files and `CREDITS.md`; no `.qoa`, `.opus`, `.mp3`.
  - `test_every_file_credited`: each `music/*.ogg` and `voice/*.wav` has exactly one `CREDITS.md` table row (first column = path relative to `game/audio/`); each row names an existing file; `sfx/` has none.
  - `test_licences`: music rows `CC-BY-3.0` or `CC-BY-4.0` with an author and an `https://` source; voice rows `GPL-3.0-or-later` naming `en_US-kristin-medium`.
  - `test_size_budget`: raw audio bytes ≤ 20,000,000.
  - `test_wav_mono_16bit`: each WAV's RIFF `fmt ` chunk (parsed with `struct`) has format 1, 1 channel, 16 bits, 44,100 Hz; a malformed header fails naming the file.
  - `test_wargrid_audio_note`: `CREDITS.md` contains "Wargrid-made audio is GPL-3.0-or-later" and `tools/audio/synth.py`.
- [ ] **Step 2:** Run. Expected: FAIL "CREDITS.md missing".
- [ ] **Step 3: Re-verify licences.** Fetch the three OpenGameArt pages (`conflict`, `enemy-spotted`, `mammoth`), `https://incompetech.com/music/royalty-free/faq.html`, both MacLeod track pages (MANIFEST URLs) and the kristin `MODEL_CARD` at revision `e7229f7d33a10e145e109b886d661984201ac3c4`; quote each, dated, in "Licence sources". A difference from `MANIFEST.md` is a stop.
- [ ] **Step 4: Files.** Record `git rev-parse HEAD` as `$base`. Copy `$SOUND_WORK/gate-s/{sfx,voice,music}` into `game/audio/`. `CREDITS.md`: header "Wargrid-made audio is GPL-3.0-or-later, see `LICENSE`. The effects in `sfx/` are generated by `tools/audio/synth.py`; the announcer lines are rendered with Piper `en_US-kristin-medium` (public-domain LibriVox recordings) and vocoded by the same script. Third-party files keep the licence named in their row."; table `file | source URL | author | licence | changes` (music: MANIFEST credit line, changes "loudness-normalised to −30 LUFS and re-encoded to Ogg Vorbis 96 kbps by `tools/audio/process.py`"; voice: model card URL, author "Wargrid", `GPL-3.0-or-later`, changes "vocoded by `tools/audio/synth.py`").
- [ ] **Step 5: Import.** `godot --headless --path game --import`. In each `sfx/*.wav.import` and `voice/*.wav.import` keep the compress mode at its default (QOA) and set Mono true, using the key names the generated files show; re-import.
- [ ] **Step 6: Size and Max Rate.** Base export: `git worktree add $SOUND_WORK/wt-base $base`, import there, `sh tools/export_build.sh Web $SOUND_WORK/web-0/index.html`, remove the worktree. Current tree with Max Rate off → `web-1`; with Max Rate 22,050 Hz on `sfx/` and `voice/` → `web-2`; restore off. Record the three `index.pck` sizes and the `.godot/imported/*.sample` sums per folder. (The raw Kristin renders are 22,050 Hz, so the voice loses nothing below 11 kHz at that rate; the listening A/B is in Gate B.)
- [ ] **Step 7:** `ci.yml` tools job: add `python3 tools/test_audio_assets.py`. README: "Licence for other original art and audio: undecided." becomes "Wargrid-made audio (generated effects, vocoded announcer lines): GPL-3.0-or-later. Music: CC BY 3.0 / 4.0, credited in [game/audio/CREDITS.md](game/audio/CREDITS.md). Licence for other original art: undecided."
- [ ] **Step 8:** Green per the contract. Commit `Add the sound spike audio and credits`.
- [ ] **Step 9: Gate A.** The user picks Max Rate per folder (default off). Fresh Opus review of Tasks 1–3 (accessors and trace evidence, collection wiring, tools against the prototypes, credits against the quotes, import settings), briefed per the milestone prompt. Fix findings test-first, record rulings, write the resume record, stop.

### Task 4: Cue table, director rules, player pools, buses, UI click

```text
Task: every weapon, death and own UI action is heard once per spec rule, through bounded pools.
Owns: new game/default_bus_layout.tres, new presentation/sound_cues.gd, sound_director.gd, sound_player.gd, skirmish_main.gd, online_main.gd, test_sound.gd.
Invariant: traces identical; one snapshot per refresh; no test pins a gain number.
Boundary: rubble holes and rebuild sites; contained units; objects unseen in any snapshot.
Red: SD5 "rifle has a shot cue, got ''".
Green: test_sound.gd, full suite, lint, warnings, trace check.
Stop: traces move; a weapon or armor the mapping below does not cover.
```

**Interfaces:**
- Consumes: Task 1's director, player and wiring; Task 1's `ATTENUATION` and `MAX_DISTANCE_PX`.
- `sound_cues.gd` (`RefCounted`, consts and static functions):
  - `const CUES := {cue: {"sound": String, "limit": int, "pitch": float, "jitter": float, "gain_db": float, "ui": bool}}`:

    | cue | sound | limit | pitch | jitter | ui |
    |---|---|---|---|---|---|
    | `rifle_burst` | `rifle_burst` | 4 | 1.0 | 0 | |
    | `carbine` | `carbine` | 4 | 1.0 | 0 | |
    | `cannon` | `cannon` | 2 | 1.0 | 0 | |
    | `launch` | `explosion` | 4 | 1.5 | 0 | (`gain_db` −6) |
    | `impact` | `explosion` | 4 | 1.0 | 0 | |
    | `infantry_death` | `infantry_death` | 3 | 1.0 | 0 | |
    | `vehicle_death` | `vehicle_death` | 4 | 1.0 | 0.05 | |
    | `building` | `building_small` (request may name `building_large`) | 2 | 1.0 | 0 | |
    | `placement` | `click` | 2 | 0.8 | 0 | yes |
    | `click` | `click` | 2 | 1.0 | 0 | yes |
    | `error` | `error` | 2 | 1.0 | 0 | yes |

    `gain_db` is 0 except `launch`.
  - `const SHOT_BY_WEAPON := {"rifle": "rifle_burst", "militia_gun": "carbine", "cannon": "cannon", "pickup_cannon": "cannon"}`; `const SHOT_BY_DAMAGE := {"small_arms": "carbine", "rapid_fire": "carbine", "gattling": "carbine", "armor_piercing": "cannon", "infantry_missile": "launch", "explosion": "launch"}`. No catch-all; a new weapon needs a row (spec §2).
  - `static func weapon_id(kind: String, tier: int) -> String` (as `Combat.weapon_of`, returning the id); `static func shot_cue(weapon: String) -> String` (weapon row, then damage-type row, else `""`); `static func death_cue(kind: String, is_building: bool) -> String` (`building` for buildings, `infantry_death` for armor `human`, else `vehicle_death`); `static func building_sound(kind: String) -> String` (`building_small` for hole kinds, `building_large` when `footprint.x * footprint.y >= 9`, else `building_small`); `static func path(sound: String) -> String` = `"res://audio/sfx/%s.wav"`.
- `SoundDirector.update(state: Dictionary) -> Array[Dictionary]` returns requests `{"cue": String, "sound": String, "pitch": float, "position": Variant}` (`Vector2` in cells for world cues, `null` for UI); `rejected(error: String) -> void`.
- `SoundPlayer`: `const WORLD_VOICES := 25`, `const UI_VOICES := 2`; `_ready` builds the pools (`Effects` bus; world players with `max_distance = MAX_DISTANCE_PX`, `attenuation = ATTENUATION`) and connects `pressed` of every `BaseButton` in `get_parent().find_children("*", "BaseButton", true, false)` (finds the pause menu's code-built buttons) plus later ones via `get_tree().node_added` filtered by `get_parent().is_ancestor_of(node)`, each giving `click`; `rejected(error)` forwards; `play(requests: Array[Dictionary]) -> void` (stream cache by path; `pitch_scale = pitch`; `volume_db = CUES[cue].gain_db`; `position = Iso.world_to_plane(position)`); `static func plan(requests: Array[Dictionary], playing: Array[String], listener: Vector2, max_distance: float) -> Array[int]` — per request in order, a slot or −1: −1 when a world request's plane distance to `listener` exceeds `max_distance`, −1 when the cue's playing plus already-planned count reaches its limit, else the first free slot (`""` in `playing`), else −1; each assignment updates the local copy. `play` calls it once per pool with the camera's `get_screen_center_position()` (or `Vector2.ZERO` without a camera). `last_requests() -> Array[Dictionary]`.
- Wiring: `skirmish_main._submit` = super, then `_sound.rejected(_error)` when `_error` is not empty; `online_main` calls `_sound.rejected(entry.error)` for every new entry of `_lockstep.rejections()`.

**Director rules** (per `update`, events in collection order):
- **Records:** `current` = `{id: {kind, owner, position (cells), tier, building: bool, completed, hole: has "rebuild", site: has "hole_id"}}`, a building's position = `origin + footprint / 2`. `lookup(id) = current.get(id, previous.get(id, {}))`; an empty lookup skips the event. The first `update` after `_init` or `reset()` only stores and drops pending steps.
- **Shots** with `splash == false` (splash hits are silent): weapon = `weapon_id(attacker.kind, attacker.tier)`; cue at the attacker. For `rifle_burst`, play only when `last_shot[attacker]` is missing or `tick − last_shot[attacker] > weapon.delay_ticks + 1`; every shot sets `last_shot[attacker] = tick`; ids absent from `current` are dropped from `last_shot`. A weapon with non-empty `affects` adds `impact` at the target.
- **Deaths:** `death_cue(kind, building)`; `building` requests carry `building_sound(kind)`; `vehicle_death` pitch = `1 + rng.randf_range(-0.05, 0.05)`.
- **Own failures:** command results with `player == local_player` and `not ok`, and `rejected()`: `"Insufficient credits"` gives no click (Task 5 line), anything else `error`.
- **Placement:** an own building id in `current` but not `previous`, not a hole or site, when both `previous` and `current` have `match.status == "ongoing"`.

- [ ] **Step 1:** Bus layout `game/default_bus_layout.tres` (`AudioBusLayout`): buses 1–3 `Music`, `Effects`, `Voice`, each `volume_db = 0.0`, `send = &"Master"`.
- [ ] **Step 2: Tests** (`SD…`; director tests seed `rng.seed = 1`; each names the change that would make it fail):
  - `test_every_weapon_and_kind_has_a_cue` (SD5): every key of `Shared.WEAPONS` has `shot_cue != ""`; every tier of every `weapon_tiers` too; every kind in `Registry.units() + Registry.buildings()` and every hole kind has a non-empty `death_cue`, infantry-class kinds exactly `infantry_death`; every `CUES` sound and every `building_sound` result exists at `path()`.
  - `test_cue_by_weapon_then_damage_type` (SD6): `rifle`→`rifle_burst`; `militia_gun`, `scout_gun`, `rotary_gun`, `rotary_tower_gun`, `pickup_gun`, `tunnel_gun`→`carbine`; `cannon`, `pickup_cannon`, `light_tank_gun`, `light_tank_gun_plus`→`cannon`; `rocket`, `battery`, `pickup_rocket`→`launch`; `no_such`→`""`. Fails if `pickup_cannon` falls through to `gattling`.
  - `test_tier_picks_weapon` (SD7): an `frc_light_vehicle` shot at tier 0, 1, 2 gives `carbine`, `cannon`, `launch`.
  - `test_rifle_burst_plays_once_per_burst` (SD8, spec "once per burst"): A fires at ticks 100, 104, 108, 130, 134, 138; B at 104, 108: exactly three `rifle_burst`, A at 100, B at 104, A at 130.
  - `test_splash_weapons_add_impact` (SD9): a `cannon` shot gives `cannon` at the attacker and `impact` at the target; a `rifle` shot no `impact`; a `splash: true` shot nothing.
  - `test_death_cues` (SD10): `usa_rifle_infantry`→`infantry_death`; `usa_tank`→`vehicle_death` with pitch in [0.95, 1.05]; `usa_collector` (helicopter)→`vehicle_death`; `usa_barracks` (2×2)→`building`/`building_small`; `usa_factory` (3×3)→`building_large`; `frc_hole_3`→`building_small`; `usa_defence`→`building_small`; an unfinished `usa_factory` site→`building_large`.
  - `test_death_uses_previous_snapshot` (SD11): building 7 in update 1, absent in update 2, death collected between: a `building` request at origin + footprint / 2.
  - `test_unknown_dead_object_is_skipped` (SD12): a death for an id in neither snapshot gives nothing and no error.
  - `test_limits_and_cap` (SD13): `plan` with 4 `carbine` playing drops a fifth; with 2 `cannon` playing drops a third; with all 25 world slots busy under their limits drops a new `impact`; with both UI slots busy drops a `click`.
  - `test_far_shot_takes_no_voice` (SD14): a world request `MAX_DISTANCE_PX + 1` plane px from the listener gets −1; one at `MAX_DISTANCE_PX` a slot.
  - `test_mass_death_batch` (SD15): 20 infantry and 6 tanks dying on one tick admit exactly 3 `infantry_death` and 4 `vehicle_death`.
  - `test_container_burst` (SD16): a Pickup with 5 passengers dying on one tick admits 1 `vehicle_death` and 3 `infantry_death`.
  - `test_placement_and_errors` (SD17): a new own foundation gives `placement`; an enemy's nothing; an own failed result `"No units left"` gives `error`; player 2's nothing; `rejected("No units left")` gives `error`; `"Insufficient credits"` gives no `error`.
  - `test_hole_and_site_are_not_placements` (SD18): a new own hole and a new rebuild site give nothing.
  - `test_setup_phase_is_silent` (SD19): previous `setup` with no objects, current `ongoing` with a builder and a completed HQ: no `placement`; a later new foundation gives it.
  - `test_stalled_tick_is_silent` (SD20): the same `collect_step(20, …)` twice then `update` gives one request per event; a second `update` none.
  - `test_first_shot_after_restart_is_heard` (SD21): `collect_step(300, shot)`, `update`, `reset()`, a storing `update` of the new state, `collect_step(1, shot)`, `update`: a `cannon`.
  - `test_scenes_boot_with_sound` (SD22): `skirmish.tscn` and the online harness have a `Sound` child after two frames; `main.tscn` and `base.tscn` none; no `ERROR:` in the log.
  - `test_bus_layout` (SD23): `Music`, `Effects`, `Voice` exist at 0 dB and send to `Master`.
- [ ] **Step 3:** Run. Expected: FAIL on the assertions.
- [ ] **Step 4:** Implement the Interfaces and rules.
- [ ] **Step 5:** Green per the contract; record the trace check. Commit `Play battle and UI sounds from per-step events`. Checkpoint restart.

### Task 5: Announcer

```text
Task: local-player lines, one at a time, from a priority queue with tick cooldowns and a 150-tick expiry.
Owns: new presentation/announcer.gd, sound_director.gd, sound_player.gd (Voice player), new tests/test_announcer.gd (registered).
Invariant: no line for another player's objects; each spec cooldown and the expiry hold in ticks.
Boundary: spawns_on_complete units, hole workers, rubble, construction sites, draw and abandoned matches.
Red: AN1 "second base attack within 900 ticks started".
Green: test_announcer.gd, test_sound.gd, full suite, lint, warnings.
Stop: a trigger needs a sim field the snapshot lacks.
```

**Interfaces:**
- `announcer.gd` (`RefCounted`, `class_name Announcer`): `const EXPIRY_TICKS := 150`; `const COOLDOWN_TICKS := {"base_under_attack": 900, "building_lost": 900, "low_power": 3600}`; `const PRIORITY := {"victory": 9, "defeat": 9, "building_lost": 8, "base_under_attack": 7, "insufficient_funds": 3, "low_power": 2, "construction_complete": 1, "unit_ready": 1}` (Zero Hour retail `Eva.ini` priorities, higher wins as in `Eva.cpp:511`; construction complete and unit ready are unit voices there, so lowest; victory and defeat are not EVA, so top); `request(line: String, tick: int) -> void` (dropped when the line is already waiting or `tick − last_started[line] < cooldown`); `next(tick: int, busy: bool) -> String` (drops entries with `tick − requested > EXPIRY_TICKS`, returns `""` while `busy`, else the highest priority, ties earliest request, and records `last_started`); `clear() -> void`; `static func path(line: String) -> String` = `"res://audio/voice/%s.wav"`.
- `SoundDirector`: `var announcer := Announcer.new()`; `reset()` calls `announcer.clear()`; the local team comes from the `state.players` row of `local_player`.
- `SoundPlayer.update(state)` ends with `var line := director.announcer.next(state.tick, _voice.playing)` and plays it on the `Voice` player.

**Triggers** (local player only; event triggers use the event tick, diff triggers `state.tick` and need both statuses `ongoing`):
- `base_under_attack`: any shot (splash included) whose target lookup is an own building that is not a hole; construction sites count.
- `building_lost`: a death of an own building that is not a hole.
- `unit_ready`: an own building's previous queue head id is gone from its current queue and a new own unit of that entry's kind exists in `current`. Spawns on completion, hole workers and cancelled entries do not qualify.
- `construction_complete`: an own building id in both snapshots goes `completed` false → true (rebuilt FRC buildings included).
- `insufficient_funds`: an own failed result or `rejected()` with `"Insufficient credits"`.
- `low_power`: own `power_demand > power_supply` now and not in `previous`.
- `victory` / `defeat`: `previous.match.status == "ongoing"` and current `"won"`; `winner == local team` gives `victory`, else `defeat`. `draw` and a match left open by a lockstep end say nothing.

- [ ] **Step 1: Tests** (`AN…`, spec-worded):
  - `test_second_base_attack_within_30s_is_silent` (AN1): requests at ticks 100 and 999 give one start; at 1000 (voice free) a second.
  - `test_building_lost_cooldown_30s` (AN2), `test_low_power_cooldown_120s` (AN3: 3599 dropped, 3600 starts), `test_insufficient_funds_has_no_cooldown` (AN4).
  - `test_line_expires_after_5s` (AN5): requested at 0, busy until 151: `next(151, false) == ""`; a fresh request at 0 with `next(150, false)` starts it.
  - `test_one_line_at_a_time_by_priority` (AN6): `low_power`, `insufficient_funds`, `base_under_attack`, `building_lost` requested on one tick start in the order `building_lost`, `base_under_attack`, `insufficient_funds`, `low_power` (Zero Hour `Eva.ini`), one per free voice; nothing starts while busy. `test_waiting_line_not_queued_twice` (AN7).
  - `test_triggers_from_snapshots` (AN8): `construction_complete`, `unit_ready`, `low_power`, `victory`, `defeat`, and `building_lost` for building 7 of SD11's fixture.
  - `test_unit_ready_not_fired_by_spawns` (AN9): a supply center completing with its `spawns_on_complete` collector gives `construction_complete` only; a Tunnel Hub's two rocket infantry give no `unit_ready`; a hole worker spawn none; a cancelled queue entry none; a finished queue head one.
  - `test_rubble_is_not_base` (AN10): a shot at an own hole and the death of an own hole say nothing; a shot at an own construction site gives `base_under_attack`.
  - `test_unit_attack_is_not_base_attack` (AN11).
  - `test_frc_never_low_power` (AN12): an FRC player with every building kind says no `low_power`.
  - `test_announcer_follows_local_seat` (AN13): local player 2, ally 3: 3's building lost says nothing; 2's gives `building_lost`; `won` with winner = team of 2 gives `victory`.
  - `test_match_end_lines` (AN14): `draw` says nothing; an online match ending `ended_left` (sim status stays `ongoing`) says nothing.
  - `test_online_start_says_nothing` (AN15): the setup → ongoing step with a new builder and a completed HQ gives no `unit_ready` or `construction_complete`.
  - `test_restart_starts_silent` (AN16): a queued line, `reset()`, a fresh state: nothing; `Skirmish` `_restart()` plus two refreshes: no `unit_ready` or `placement` in `last_requests()`.
- [ ] **Step 2:** Run. Expected: FAIL on the assertions.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Green per the contract. Commit `Add the announcer`.

### Task 6: Music and volume settings (ends at Gate B)

```text
Task: menu music, match playlist with gaps, three persisted sliders in the launcher and the Esc menu.
Owns: new presentation/music_player.gd, audio_settings.gd, volume_sliders.gd, launcher.gd, pause_menu.gd, skirmish_main.gd, sound_player.gd, new tests/test_audio_settings.gd (registered), test_online_scene.gd (N5), test_pause_menu.gd (E8).
Invariant: N5 and E8 stay green with only their control lists extended; constructing a slider never writes the file.
Boundary: missing, corrupt and out-of-range settings; a test run on a developer machine.
Red: AS1 "music default 1.0, got 0".
Green: test_audio_settings.gd, N5, E8, full suite, lint, warnings.
Stop: the launcher does not fit 1280×720.
```

**Interfaces:**
- `audio_settings.gd` (`RefCounted`, static): `const DEFAULTS := {"music": 1.0, "effects": 1.0, "voice": 1.0}`; `const BUSES := {"music": "Music", "effects": "Effects", "voice": "Voice"}`; `const SECTION := "audio"`; `static var path := "user://settings.cfg"`; `load_volumes() -> Dictionary` (a non-`OK` load or a non-number gives the default; values clamped 0–1); `save_volumes(volumes: Dictionary) -> void` (loads, sets, saves, so other keys and sections survive); `apply(volumes: Dictionary) -> void` (`set_bus_mute(i, v == 0.0)`, else `set_bus_volume_db(i, linear_to_db(v))`).
- `volume_sliders.gd` (`GridContainer`, 2 columns, name `Volume`): `MusicLabel`/`Music`, `EffectsLabel`/`Effects`, `VoiceLabel`/`Voice` (`HSlider` 0–1, step 0.05, minimum width 200 px); values from `load_volumes()`, signals connected afterwards; a change applies and saves.
- `music_player.gd` (`AudioStreamPlayer`, bus `Music`, name `Music`): `const GAP_SECONDS := 25.0`; `const MENU := "res://audio/music/stay_the_course.ogg"`; `const PLAYLIST: Array[String]` = conflict, enemy_spotted, mammoth, stay_the_course, hitman (spec §5 order); `play_list(paths: Array[String], gap: float) -> void`; `advance(delta: float) -> void` (from `_process`); `track_index() -> int`; `waiting() -> bool`. After `finished` it waits `gap` seconds, then plays the next path, wrapping.
- Wiring: `launcher._ready`, after the headless-flag loop, adds `SoundPlayer.new(0)` (UI click and `apply`), a `MusicPlayer` on `[MENU]` with gap 0, and `VolumeSliders.new()` moved before `Status`; `pause_menu._init` adds `VolumeSliders.new()` to `_main_box` after the buttons; `skirmish_main._ready` adds a `MusicPlayer` on `PLAYLIST` with `GAP_SECONDS`; `SoundPlayer._ready` calls `AudioSettings.apply(AudioSettings.load_volumes())`.
- Test helper (in each suite that builds these scenes): sets `AudioSettings.path = "user://test-settings.cfg"`, restores and deletes it per case.

- [ ] **Step 1: Tests** (`AS…`):
  - `test_settings_missing_and_corrupt` (AS1): no file gives 1.0 × 3; `music = "loud"` gives 1.0, `voice = 3.0` gives 1.0, `effects = -1.0` gives 0.0.
  - `test_settings_round_trip` (AS2): saved volumes load back; an unrelated key in `audio` and another section survive.
  - `test_slider_sets_bus_and_saves` (AS3): `Music` at 0.5 sets the bus to `linear_to_db(0.5)` ± 0.01 dB and saves; 0 mutes it.
  - `test_tests_use_scratch_settings` (AS4): the real file's `get_modified_time` (0 if absent) is unchanged after building the launcher and a `PauseMenu` without the helper and moving a slider with it.
  - `test_playlist_order_and_gap` (AS5): after `finished`, `waiting()`; `advance(24.9)` still waits; `advance(0.2)` gives index 1; after the fifth track it wraps to 0.
  - `test_menu_track_repeats` (AS6): `play_list([MENU], 0.0)`, `finished`, `advance(0.0)`: index 0, not waiting.
  - N5 gains `"Volume"` and its 6 children: inside the viewport and the box, no overlap with any other `Center/Box` control, at 1280×720 and 1920×1080.
  - E8 gains the 3 sliders and 3 labels: inside the viewport, clear of HUD text and of every button.
- [ ] **Step 2:** Run. Expected: FAIL on the assertions.
- [ ] **Step 3:** Implement.
- **Addendum (user, 2026-11-08): mute toggle.** A `Mute` button (launcher and Esc menu, beside the sliders) and key `M` in the match toggle `AudioServer.set_bus_mute(0, ...)` on Master. Session-only, not saved, independent of the slider values (a slider at 0 already mutes its bus). Before implementing: `rg -n '"M"|KEY_M|physical_keycode' game/project.godot game/scripts` for a key clash, and pick another key if `M` is taken. Tests: toggle twice restores Master; slider values and the settings file untouched; the button fits the N5/E8 layout checks. Not in the spec; record it in the design's Goals line.
- [ ] **Step 4:** Green per the contract. Commit `Add music and volume sliders`.
- [ ] **Step 5: Gate B windowed run** (approval; one batch, sound on). In an offline skirmish: a fight at the screen centre, at the edge and 20–40 cells away (falloff and the isometric limit); zoom 0.5 and 2 (loudness unchanged; Task 1 Step 3 if it was deferred); a full mix against spec §3. A scratch scene in the session scratchpad (`quit()` on every path) plays each line imported (QOA) and raw (`AudioStreamWAV.load_from_file` on the source WAV), A/B, then at the Max Rate picked at Gate A. Changes go only into `CUES` `gain_db`, `ATTENUATION` and `MAX_DISTANCE_PX` (within the Zero Hour target), `GAP_SECONDS`, and the voice compress mode (PCM if QOA artefacts are heard; size re-measured). Record every verdict verbatim.
- [ ] **Step 6: Gate B review.** Suite, trace check (identical), `sh tools/run_benchmark.sh` alone. Fresh Opus review of Tasks 4–6, briefed per the milestone prompt (diff since Gate A, contracts, per new test the production change that would make it fail). Fix critical and important findings test-first, record rulings, write the resume record, stop.

### Task 7: Release, measurements, exit gate

```text
Task: ship the credits, prove nothing moved, measure the cost, and play.
Owns: .github/workflows/release.yml, scripts/debug/movement_benchmark.gd (--sound), docs/reference/performance.md, the verification file, README/AGENTS/blueprint status.
Invariant: traces identical against $d0; budgets reported, never loosened.
Boundary: the web build before and after the first click.
Red: the --sound run "RENDERED SOUND cues=0" fails.
Green: trace check, run_benchmark.sh row, rendered row, CI on Linux and Windows.
Stop: a trace moves; a budget exceeded beyond rows the user already accepted; a playtest problem.
```

- [ ] **Step 1:** `release.yml` `extras` gains `game/audio/CREDITS.md` (so the zips and `web/site/` carry it). actionlint (no output, exit 0); `python3 tools/test_package_release.py` OK.
- [ ] **Step 2: Traces.** Trace check against `$d0`: all `REPLAYS MATCHED`, equal netplay terminal tick; suite totals = baseline + new cases, recorded.
- [ ] **Step 3: Benchmarks.** `sh tools/run_benchmark.sh` alone on a quiet host, `uptime` at start and end. `movement_benchmark.gd -- --sound`: on the `horde` layout a `SoundPlayer` with real rules gets `collect_step` after each step and `update` per frame; prints `RENDERED SOUND cues=<n> update_p95_ms=<x>` and fails when `cues == 0` in the sample window. Ask first (window, sound on), batched with Step 4: `sh tools/run_game.sh res://scenes/movement_benchmark.tscn -- --sound`. Ledger row: sim rows, rendered p95 with sound against the last rendered row, the director's `update_p95_ms`, and the `.pck` growth from Task 3; anything unmeasured marked unverified.
- [ ] **Step 4: Web check** (approval, batched with Step 3). `sh tools/export_build.sh Web web/site/index.html`, served as in README "Browser build". In Firefox: no audio before the first click, then menu music; sliders act live; shots pan; every effect and line is heard next to the music; no console audio errors. Record each item as seen or not seen.
- [ ] **Step 5: User playtest** offline and online: levels, falloff, gap, cue choice, line priority and wording. Findings verbatim; fixes test-first, each with a narrow fresh review.
- [ ] **Step 6:** `/ponytail-review` on the branch diff; apply and re-verify. CI on Linux and Windows (push with approval) and `sh tools/compare_local_traces.sh <run id>`. Status lines: "sound spike implemented on `spike-sound`, user playtest done". Report implemented, verified and pending. Commit with approval.

## Spike-specific stop conditions (copied into `docs/sound-spike-prompt.txt`)

- any trace moves, or any simulation change beyond the two accessors;
- Godot's 2D gain is not a distance power curve, or zoom changes it even with an `AudioListener2D`;
- a weapon, damage type or armor without a cue that the mapping does not cover;
- a port that differs from its prototype render; a clip over −1 dBFS at its target; a dynamic loudnorm pass;
- a licence page that is missing, outside the allowed set, or different from `MANIFEST.md`;
- raw audio over 20,000,000 bytes; a format or encoder change; `.qoa`, `.opus` or `.mp3` in the repo;
- a window, browser run, install, push or merge without approval;
- Gate S, Gate A, Gate B, exit.
