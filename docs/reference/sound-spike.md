# Sound spike evidence

Design: [sound spike design](../superpowers/specs/2026-11-08-sound-spike-design.md) (approved 2026-11-08). Plan: [sound spike plan](../superpowers/plans/2026-11-08-sound-spike.md). Resume record: [sound-spike-verification](sound-spike-verification.md). Labels: confirmed (user said or heard it), source-read (read in a primary source, not re-verified), provisional (to be tuned).

## Zero Hour findings

Provenance: copied on 2026-11-08 from the superseded draft `docs/superpowers/specs/2026-11-07-m6.5-sound-design.md` (heading "Zero Hour evidence"). Label: EA source `0a05454d85`, retail `INIZH.big`, read in memory, not re-verified.

- Fire sound once per shot (`FiringTracker.cpp:162`), the most frequent sound. Impact and death sounds come from FXLists.
- Variety: 3-12 variants per event, random, with pitch shift (e.g. `CrusaderTankWeapon`: 3 variants, pitch +-5 %, volume shift -10, Limit 2).
- Channels: 25 world and 4 UI (`AudioSettings.ini`). Per-event `Limit` (default 4). World sounds beyond MaxRange (default 800) are dropped.
- Default volumes: music 55 %, sound 80 %, speech 70 %.
- Unit-ready and construction-complete are unit voices, not EVA lines.
- EVA plays one line at a time from a priority queue, and each line expires after 5 s. Cooldowns: BaseUnderAttack 30 s, BuildingLost 30 s, UnitLost 15 s, LowPower 120 s, InsufficientFunds 0.
- Skirmish music plays the faction tracks in order with 60 s silence between tracks (taken from the script names; the script logic was not decoded).
- EA bugs not to copy: the radar under-attack distance check is missing parentheses; units under attack play the structure alert.
- No ducking: `MilesAudioManager.cpp` `getEffectiveVolume` is event volume x category volume x distance; speech changes only by map script (spec section 3).

Mix calculation of the draft (2026-11-07, file loudness x INI Volume x category volume, Miles gain assumed linear, nothing heard in game): at point-blank, effects sit 0 to +6 dB against the music average (TankDie +6.2, CrusaderTankWeapon +4.2, RangerWeapon +0.4, explosion -0.8, GUIClick -4.3), unit voices +1 to +3.5, the EVA announcer about +6. The "subtle, in the background" impression comes from distance falloff (`volume *= MinRange/dist`, -6 dB per doubling, MinRange 175, culled at MaxRange 800) and sparse hits, which lowers typical on-screen hits by about 6 to 12 dB.

## Licence sources

Fetched 2026-11-07, re-verified in Task 3 (not yet). Source: `$HOME/projects/wargrid-sound-work/sourcing/MANIFEST.md` (outside the repo).

| file | page URL | quoted wording | fetched |
|---|---|---|---|
| M04 Conflict, Alexandr Zhelanov | https://opengameart.org/content/conflict | asset page field "License(s): CC-BY 4.0"; credit: "Conflict" by Alexandr Zhelanov (https://opengameart.org/content/conflict), licensed CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/) | 2026-11-07 |
| M05 Enemy spotted, Alexandr Zhelanov | https://opengameart.org/content/enemy-spotted | asset page field "License(s): CC-BY 3.0"; credit: "Enemy spotted" by Alexandr Zhelanov (https://opengameart.org/content/enemy-spotted), licensed CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/) | 2026-11-07 |
| M06 Mammoth, congusbongus | https://opengameart.org/content/mammoth | asset page field "License(s): OGA-BY 4.0 / CC-BY 4.0" (used under CC-BY 4.0); credit: "Mammoth" by congusbongus (https://opengameart.org/content/mammoth), licensed CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/) | 2026-11-07 |
| M08 Stay the Course, Kevin MacLeod | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1900018 | incompetech FAQ: "Be sure to credit me."; credit format: "Title Kevin MacLeod (incompetech.com) / Licensed under Creative Commons: By Attribution 4.0 / https://creativecommons.org/licenses/by/4.0/" | 2026-11-07 |
| M10 Hitman, Kevin MacLeod | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1300013 | same FAQ wording and credit format as M08 | 2026-11-07 |
| Announcer voice: Piper en_US-kristin-medium | https://huggingface.co/rhasspy/piper-voices (revision `e7229f7d33a10e145e109b886d661984201ac3c4`) | model card: "License: public domain", "Trained from scratch ... All recordings came from LibriVox.org."; LibriVox: "all our recordings are public domain ... This means anyone can use all our recordings however they wish (even to sell them)." No credit required; courtesy line `Voice: Piper en_US-kristin-medium (public-domain LibriVox recordings)`. Caveat: the licence is the trainers' own claim; LibriVox source recordings not audited. | 2026-11-07 |

The five music files are the manifest rows M04, M05, M06, M08 and M10 (the "five picks" of `SOUND_WORK/music/`). Only the Piper voice output is shipped, never the engine.

## Mix calculation

- Levels (spec section 3, user 2026-11-08: "zero hour proportions sounds good to me"): announcer +6 dB against the music; effects at point-blank rifle and carbine +0.4, cannon +4.2, explosion -0.8, vehicle death +6.2 (retail calculation above); infantry death -2 and buildings +6.2 are guesses heard and approved in the demo, not Zero Hour data; click and error -4.3, no falloff.
- `OFFSET` in `$SOUND_WORK/synth/ingame_spike.py`: rifle-burst 0.4, carbine 0.4, cannon 4.2, explosion -0.8, vehicle-death 6.2, building-small 6.2, building-large 6.2, infantry-death -2.0, click -4.3, error -4.3 (dB, relative to the music LUFS); `MIN_RANGE = 175` world units.
- Approved file: `$SOUND_WORK/synth/out/ingame/ingame-zh.wav`.

## Listening rounds

- 2026-11-07: effects `f` (futuristic) flavour picked per cue by the user; Modern preset dropped 2026-11-08. Ambient `a` flavour unused. Rejected by the user: screams, squash/thud, vocal samples.
- 2026-11-08: announcer variants (a) Piper with ring mod / bitcrush / comb, (b) channel vocoder, (d) tones only, (e) tone + voice; (c) espeak-ng not tried (not installed). User: first b1, then "now i like c1 typical more"; c1n (c1 with a level fix) "now all sound great at 0db". Picked: c1n.
- 2026-11-08: vehicle death pitch variation +-5 % heard and accepted (one clip instead of three variants).
- 2026-11-08: positional audio: Godot `AudioStreamPlayer2D` ("A"); user: "use A and determine via the playtest if it sounds strange".

## Departures

From Zero Hour, by design (provisional until the playtest):

- Unit ready and construction complete are announcer lines (Zero Hour: unit voices).
- No unit-lost line.
- Insufficient credits plays its line, not the error click (as Zero Hour: `ControlBarCommandProcessing.cpp:253` and `PlaceEventTranslator.cpp:199` play only `EVA_InsufficientFunds` plus a silent text message).
- EVA priorities from retail `Eva.ini`: BuildingLost 8, BaseUnderAttack 7, InsufficientFunds 3, LowPower 2, UnitLost 1, all expiring after 5000 ms.
- Unit ready only from a production queue, as Zero Hour's `VoiceCreated` in `ProductionUpdate.cpp:834`.
- UI-only errors set by `base_main` are silent.

## Godot attenuation

Task 1, 2026-11-08. Source: `https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/scene/2d/audio_stream_player_2d.cpp` (fetched 2026-11-08), lines 154-171:

```text
AudioListener2D *listener = vp->get_audio_listener_2d();
if (listener) {
    listener_in_global = listener->get_global_position();
    relative_to_listener = (global_pos - listener_in_global).rotated(-listener->get_global_rotation());
    relative_to_listener *= full_canvas_transform.get_scale();
} else {
    listener_in_global = full_canvas_transform.affine_inverse().xform(screen_size * 0.5);
    relative_to_listener = full_canvas_transform.xform(global_pos) - screen_size * 0.5;
}
float dist = global_pos.distance_to(listener_in_global);
if (dist > max_distance) { continue; }
float multiplier = Math::pow(1.0f - dist / max_distance, attenuation);
```

`dist` is in global (world) px, so camera zoom does not enter it, with or without an `AudioListener2D`; without one the listener is the screen centre mapped back to global. Zoom only enters `relative_to_listener`, which feeds the pan (`pan = relative_to_listener.x / screen_size.x`).

Measured (Godot 4.7.2 headless, Dummy driver, which does mix into `AudioEffectCapture`): 1 kHz loop, `max_distance` 1145, `attenuation` 1.0, source on the +y axis (pan 0), RMS of 0.25 s, dB relative to d = 0:

| d (plane px) | 0 | 250 | 500 | 716 | 1000 | 1145 | 1200 |
|---|---|---|---|---|---|---|---|
| formula `20 log10(1 - d/1145)` | 0 | -2.14 | -4.98 | -8.53 | -17.95 | silent | silent |
| measured, zoom 0.5, 1, 2, no listener | 0 | -2.14 | -4.99 | -8.53 | -17.95 | silent (zoom 2: -34 dB ramp residue) | silent |
| measured, zoom 0.5, 1, 2, `AudioListener2D` current | 0 | -1.9 to -2.1 | -4.8 to -5.0 | -8.3 to -8.5 | -16.9 to -17.95 | silent (zoom 2: residue) | silent |

The gain is the power curve and does not depend on zoom. A first run with the source on the +x axis measured the left channel only and showed a zoom-dependent drop; that was the pan, not the distance. Stop condition not triggered. Task 4 still adds an `AudioListener2D` on the camera so the listener follows the view rather than the screen centre by accident; Gate B checks it by ear. A viewport must have `audio_listener_enable_2d` on (the Dummy run reported `is_audio_listener_2d() == true` for the root).

Values. Zero Hour gain `min(1, 7 / cells)`, 0 past 32 cells, against Godot `(1 - cells / 32) ^ a`, dB:

| cells | 3.5 | 7 | 10 | 14 | 20 | 28 | 32 |
|---|---|---|---|---|---|---|---|
| Zero Hour | 0 | 0 | -3.1 | -6.0 | -9.1 | -12.0 | silent |
| a = 0.5 | -0.5 | -1.1 | -1.6 | -2.5 | -4.3 | -9.0 | silent |
| a = 1 | -1.0 | -2.1 | -3.3 | -5.0 | -8.5 | -18.1 | silent |
| a = 1.5 | -1.5 | -3.2 | -4.9 | -7.5 | -12.8 | -27.1 | silent |
| a = 2 | -2.0 | -4.3 | -6.5 | -10.0 | -17.0 | -36.1 | silent |

Worst-case error from 7 to 28 cells (0.1-cell steps): a = 0.5 4.9 dB (at 21.3 cells), a = 1 6.0 dB (28), a = 1.5 15.1 dB, a = 2 24.1 dB. Pick `ATTENUATION = 0.5`, `MAX_DISTANCE_PX = 1145.0` (32 cells x 35.78 px). Isometric limit: one cell is 45.25 px screen-horizontal and 22.63 px screen-vertical, so the audible edge lies at 25 to 51 cells by direction; the playtest judges it (fallback B, spec Approaches).

## Assets and levels

Filled in Tasks 2-3.

## Gate rulings

Filled at the gates.
