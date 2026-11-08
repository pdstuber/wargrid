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

Fetched 2026-11-07, re-verified in Task 3 on 2026-11-08 (below). Source: `$HOME/projects/wargrid-sound-work/sourcing/MANIFEST.md` (outside the repo).

| file | page URL | quoted wording | fetched |
|---|---|---|---|
| M04 Conflict, Alexandr Zhelanov | https://opengameart.org/content/conflict | asset page field "License(s): CC-BY 4.0"; credit: "Conflict" by Alexandr Zhelanov (https://opengameart.org/content/conflict), licensed CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/) | 2026-11-07 |
| M05 Enemy spotted, Alexandr Zhelanov | https://opengameart.org/content/enemy-spotted | asset page field "License(s): CC-BY 3.0"; credit: "Enemy spotted" by Alexandr Zhelanov (https://opengameart.org/content/enemy-spotted), licensed CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/) | 2026-11-07 |
| M06 Mammoth, congusbongus | https://opengameart.org/content/mammoth | asset page field "License(s): OGA-BY 4.0 / CC-BY 4.0" (used under CC-BY 4.0); credit: "Mammoth" by congusbongus (https://opengameart.org/content/mammoth), licensed CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/) | 2026-11-07 |
| M08 Stay the Course, Kevin MacLeod | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1900018 | incompetech FAQ: "Be sure to credit me."; credit format: "Title Kevin MacLeod (incompetech.com) / Licensed under Creative Commons: By Attribution 4.0 / https://creativecommons.org/licenses/by/4.0/" | 2026-11-07 |
| M10 Hitman, Kevin MacLeod | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1300013 | same FAQ wording and credit format as M08 | 2026-11-07 |
| Announcer voice: Piper en_US-kristin-medium | https://huggingface.co/rhasspy/piper-voices (revision `e7229f7d33a10e145e109b886d661984201ac3c4`) | model card: "License: public domain", "Trained from scratch ... All recordings came from LibriVox.org."; LibriVox: "all our recordings are public domain ... This means anyone can use all our recordings however they wish (even to sell them)." No credit required; courtesy line `Voice: Piper en_US-kristin-medium (public-domain LibriVox recordings)`. Caveat: the licence is the trainers' own claim; LibriVox source recordings not audited. | 2026-11-07 |

### Re-verification, 2026-11-08 (Task 3)

No difference from the manifest.

- OpenGameArt pages (curl, page text; WebFetch got 403): conflict "Author: Alexandr Zhelanov ... License(s): CC-BY 4.0 ... Copyright/Attribution Notice: https://www.youtube.com/c/AlexandrZhelanovsMusic"; enemy-spotted "License(s): CC-BY 3.0 ... Copyright/Attribution Notice: Alexandr Zhelanov https://soundcloud.com/alexandr-zhelanov"; mammoth "License(s): OGA-BY 4.0 CC-BY 4.0" (used under CC-BY 4.0).
- incompetech FAQ (WebFetch): credit format "Title Kevin MacLeod (incompetech.com) / Licensed under Creative Commons: By Attribution 4.0 / https://creativecommons.org/licenses/by/4.0/"; "the Creative Commons license that I offer all of my music under".
- The two MacLeod track pages (`?isrc=`) render by script ("Loading track... No Track selected"), so no licence text is on them. Title, isrc and file name come from `https://incompetech.com/music/royalty-free/pieces.json` (Stay the Course USUAN1900018, Hitman USUAN1300013); the licence rests on the FAQ alone.
- Kristin MODEL_CARD at revision `e7229f7d`: "# Model card for kristin (medium)", "License: public domain" (dataset), "All recordings came from LibriVox.org."

### MacLeod per-track licence, fetched 2026-11-08 (Gate A finding, open: user rules)

- `https://incompetech.com/music/royalty-free/pieces.json` (1443 entries, curl): keys are `bpm, collection, description, feel, filename, filmmusicURL, genre, instruments, isrc, itunes, length, sheetmusic, title, uploaded, video`. No licence field. Hitman entry: isrc USUAN1300013, uploaded 2013-02-03; Stay the Course: isrc USUAN1900018, uploaded 2019-07-16.
- The mp3 ID3 tags carry only title and artist (ffprobe); no licence or copyright tag.
- `faq.html` (curl, verbatim): "Be sure to credit me."; credit block "Title Kevin MacLeod (incompetech.com) / Licensed under Creative Commons: By Attribution 4.0 / https://creativecommons.org/licenses/by/4.0/" (three lines on the page), "It is important that you replace the word Title with the Actual Title of the piece that you are using!"; "the Creative Commons license that I offer all of my music under almost always gives you more rights than those contracts"; licence page "Attribution Code": "Licensed under Creative Commons: By Attribution 4.0 License http://creativecommons.org/licenses/by/4.0/". Also: "You MUST make it clear in the credits which parts are yours, and which parts are mine. There is no need to mention if you cut and splice." (our loudness normalisation and re-encode are listed in the `changes` column).
- Per-track pages (`index.html?isrc=`) render by script; no licence text. `incompetech.filmmusic.io/song/5048-stay-the-course/` returned no licence wording to curl.
- Result: no per-track primary source exists on the site; the site-wide FAQ statement ("all of my music") is the only primary wording. Not verified: per-track exceptions (the FAQ says "almost always" about contracts, not the licence).

Options: (a) keep the two MacLeod tracks on the FAQ's site-wide CC BY 4.0 statement, record this limit (recommended: it is the author's own primary statement, the credit text is shipped as he asks, risk is a hypothetical per-track exception nobody documents); (b) email Kevin MacLeod for per-track confirmation (slow, needs the user); (c) swap Hitman and Stay the Course for OpenGameArt tracks with per-asset licence fields (M13/M14 style alternates; weakens the mood match).

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

The gain is the power curve and does not depend on zoom. A first run with the source on the +x axis measured the left channel only and showed a zoom-dependent drop; that was the pan, not the distance. Stop condition not triggered. No `AudioListener2D` is added (Gate B review, 2026-11-08: none exists in the scene tree): without one the listener is the screen centre mapped back through `full_canvas_transform`, which includes the `Camera2D`, so it follows the view; `sound_player.gd` uses `get_screen_center_position()` of the same camera for its range test. The table rows above measured zoom only, the screen-centre fallback under a panned camera is read from the source above and left to Gate B by ear. A viewport must have `audio_listener_enable_2d` on (the Dummy run reported `is_audio_listener_2d() == true` for the root).

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

Task 2, 2026-11-08 (numpy 2.5.4, scipy 1.18.1, scipy-stubs 1.18.1.1, Python 3.12; synth.py `$SOUND_WORK/sourcing` to `$SOUND_WORK/gate-s`). Faithful-port check: all 10 prototype effects and 8 c1n lines byte-identical (`cmp`). Effects measured looped to 3 s.

```text
sfx/rifle_burst lufs -29.6 peak -17.4 dBFS
sfx/carbine lufs -29.6 peak -14.3 dBFS
sfx/cannon lufs -25.8 peak -14.0 dBFS
sfx/explosion lufs -30.8 peak -17.8 dBFS
sfx/vehicle_death lufs -23.8 peak -8.5 dBFS
sfx/building_small lufs -23.8 peak -8.2 dBFS
sfx/building_large lufs -23.8 peak -7.0 dBFS
sfx/infantry_death lufs -32.0 peak -20.1 dBFS
sfx/click lufs -34.3 peak -22.6 dBFS
sfx/error lufs -34.3 peak -24.6 dBFS
voice/base_under_attack lufs -24.0 peak -7.0 dBFS
voice/building_lost lufs -24.0 peak -10.2 dBFS
voice/unit_ready lufs -24.0 peak -8.6 dBFS
voice/construction_complete lufs -24.0 peak -7.2 dBFS
voice/insufficient_funds lufs -24.0 peak -8.1 dBFS
voice/low_power lufs -24.0 peak -8.8 dBFS
voice/victory lufs -24.0 peak -4.3 dBFS
voice/defeat lufs -24.0 peak -9.5 dBFS
music LUFS/true-peak dBFS: stay_the_course -30.0/-18.2, conflict -30.1/-15.7, enemy_spotted -30.1/-16.8, mammoth -30.0/-18.0, hitman -30.0/-15.2
music size bytes: stay_the_course 2458259, conflict 2508577, enemy_spotted 1978908, mammoth 1625202, hitman 2327193
```

## Import and size (Task 3)

See the verification file, Measurements.

## Gate rulings

Filled at the gates.
