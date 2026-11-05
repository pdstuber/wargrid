# Zero Hour parity harness spike — 2026-11-05

Status: spike between milestones. **Adopted (user, 2026-11-05, "go with your recommendations"):** the native macOS route; the harness moves to `tools/zh_parity/` so any milestone can use it ([parity harness](zero-hour-parity-harness.md)); it counts toward [level 1](zero-hour-verification.md#level-1-protocol-reduced-by-user-decision-2026-11-03) with the source-build caveat below; the container, MinGW and Wine routes are dropped. Question (user, 2026-11-05): find a way to modify, compile and run the original game on this Mac so parity values (for example movement speed) come from exact automated measurement instead of World Builder sessions and by-eye timing. Labels: **measured** (harness command below), **docs** (primary source read), **unverified**.

## Routes tried

| Route | Result |
|---|---|
| TheSuperHackers `GeneralsGameCode` (`afc2a103f`) native on macOS | not possible: 32-bit Windows targets only (VC6, VS2022, MinGW-w64 i686); macOS is a README goal (**docs**) |
| Its Docker build (VC6 under WineHQ 11.0) in Apple `container` 1.6.1, amd64 | fails (**measured**): amd64 always runs on Rosetta for Linux (`VirtualApple` CPU, with or without `--rosetta`); `wineboot` hits `assertion failed [x86_avx_state_ptr->xsave_header.xfeatures == kSupportedXFeatureBits] (ThreadContextSignals.cpp:414 rt_sigreturn)`, `syswow64` stays empty (0 files vs 804 in `system32`), so no 32-bit program (VC6 `CL.EXE`, the game) starts |
| Host Wine | Homebrew disabled all Wine casks on 2026-09-01 (fail Gatekeeper, **measured** `brew info`); unsigned Gcenx builds exist, not tried |
| MinGW-w64 14 (Homebrew GCC 16.2) cross-compile on macOS | configure stops: `EABrowserDispatch requires an IDL compiler` (`widl`, shipped with Wine dev tools) (**measured**); not pursued |
| [dvcdsys/GeneralsGameCode-macOS](https://github.com/dvcdsys/GeneralsGameCode-macOS) (native arm64, D3D8→Metal shim, fork of upstream at `44deb0698`, 2026-05-15) | **works** (**measured**): builds with Command Line Tools only (no Xcode, shaders compile at runtime), runs the retail data headless, has an embedded localhost control API (pause, single-step, orders, per-unit state) |

## What was built

Fork checkout `/Users/pdstuber/projects/GeneralsGameCode-macOS`, local branch `wargrid-parity` on base `8fedb1649`: `b3874dc95` (patch) and `eb595cfc9` (fixes after a Codex `gpt-6-astra` review), **never pushed**, 4 files:

- `Dependencies/Utility/osdep_compat/win32_api.h`: `GetCommandLineA` returned `""` on macOS, so every command-line flag was dropped (the first probe ran windowed with loud sound); now built from `_NSGetArgv`.
- `GeneralsMD/.../Common/CommandLine.cpp`: `-noaudio` also in release builds.
- `Core/.../ExternalControl/ExternalControlSystem.cpp`: `spawn` verb (template, pos, angle, optional `owner` for enemy or neutral objects; same `newObject`/`setOrientation`/`setPosition` sequence as `ScriptActions::doCreateObject`); `/units` gains `angle`, `speed` (`PhysicsBehavior::getVelocityMagnitude`, units per frame), `lastShotFrame`.
- `GeneralsMD/.../Object/Weapon.cpp`: headless counts weapon-fire FX as handled; drawing them segfaulted on the first shot (`W3DModelDraw::handleWeaponFireFX`, null dereference). Only presentation is skipped; the fire OCL and damage still run. A second guard in `FXList.cpp` was tested unnecessary (unit deaths with their FX ran fine without it) and dropped.

Harness (Wargrid, no EA code or data): `tools/zh_parity/parity.py` (launch `-headless -noaudio`, wait in-game, pause, find a flat clear strip via `/map`, spawn, order, step one frame per sample, TSV trace per scenario; reach scenarios bisect over several games) and `tools/zh_parity/analyze.py` (metrics, Wargrid comparison, `--self-test`, run in CI). Data: extracted copy `~/CnC/run/` ([installation](installation.md)); traces in `~/CnC/parity/traces/` (outside git).

## Method

Each scenario starts a fresh headless skirmish on `Killing Fields`, spawns USA templates for the API player (`AmericaInfantryRanger`, `AmericaTankCrusader`, `AmericaVehicleDozer`) and targets for the enemy human slot (no AI runs) or the neutral/civilian players, issues one order (or none for reach tests), then single-steps and samples every logic frame (30 per second). The harness asserts each sample is exactly one frame after the previous and that the frame did not advance while sampling. Speed is cruise speed (median of moving frames); acceleration and braking are medians of per-frame speed changes; a shot counts from the row where its `lastShotFrame` first shows; death is the first frame at 0 health (dead infantry stay on the map about 240 frames). Two independent runs of `move_crusader` produced byte-identical traces (**measured**). `tools/check_reference.py` on the extracted `INIZH.big` passes (hash pinned, 74 rows, 0 differ), so the run data is the pinned data. Wall clock: the three 300–600-frame weapon scenarios took 4 minutes, a 3600-frame supply run about 10.

## Results (all measured, source build)

| Scenario | Measured | INI / Wargrid | Verdict |
|---|---|---|---|
| S1 Ranger cruise speed | 20.00 u/s | 20 (0.8 cells/s) | match |
| Crusader cruise speed | 30.04 u/s | 30 (1.2 cells/s) | match |
| Dozer cruise speed | 30.04 u/s | 30 (1.2 cells/s) | match |
| Ranger accel / braking | 100 / 100 u/s², top speed after 4 frames | Acceleration 100; Wargrid instant | match INI |
| Crusader start | first moving frame travels 1.95 u (58.6 u/s), then cruises | Acceleration 1000; Wargrid instant | engine quirk: one-frame lurch |
| Dozer accel / braking | 30 / 50 u/s², 28 frames to top speed | Acceleration 30; Wargrid instant | match INI |
| Order to first movement | 3 frames (all three units) | Wargrid: next tick | differs, small |
| Turn rate Ranger / Crusader / Dozer | 500 / 180 / 90 °/s | TurnRate 500 / 180 / 90; Wargrid instant | match INI |
| 180° turn, order to first movement | Ranger 11, Crusader 24, Dozer 3 frames (Dozer turns while driving) | Wargrid instant | feel difference |
| S2 Crusader shot interval | 60 frames (9 intervals, all 60) | 60 | match |
| S2 Crusader farthest firing distance | stationary maximum 183 centre-to-centre vs Dozer (bisected, 184 needs a move); fires on the move at 181.5 | AttackRange 150; Wargrid 6 cells = 150 centre-to-centre | **differs**: ≈150 + both 15-unit half-lengths |
| Ranger farthest firing distance | stationary maximum 122 (123 needs a move); approach-and-stop distance 115.45 | AttackRange 100; Wargrid 4 cells = 100 | **differs**: = 100 + own radius 7 + Dozer half-length 15 |
| S3 Ranger burst | 4, 4, 22 frames (17 bursts, every one) | DelayBetweenShots 3, clip 3, reload 21; Wargrid 3/3/21 | within the ±1 tolerance but **systematic +1 frame per gap**: cycle 30 frames, not 27 |
| Ranger duel time-to-kill | 339 frames, 36 shots (winner fired 1 frame earlier) | Wargrid 303 (36 hits at 3/3/21) | **differs** +12% (the +1 cadence) |
| Crusader duel time-to-kill | 428 frames, 8 shots; both reached 0 health at frame 435 (removed at 450 and 452) | Wargrid 420 | +8 frames shell flight at 140 units |
| Crusader vs Ranger in a 5-Ranger cluster (15 apart) | 30 shots, 30 direct hits of 6 HP, 1750 frames; **9 splash hits of 6 HP (54 HP) on neighbours** | Wargrid 30 direct 6 HP hits, 1740 ticks, no splash | splash differs; no scatter miss seen |
| Chinook supply trip | see [Unverified](#unverified) | 8 × 75 = 600 per trip; 6 cells/s flight (provisional) | 4 deposits, each exactly 600 (= 8 × 75); peak flight 150.2 u/s (= 6 cells/s); cycle 773 frames vs Wargrid's ≈535 (8 × 36 load + 87 unload + 2 × 80 flight) |

## Assessment (Claude, not a user decision)

- The harness answers "what does the game logic do" exactly and unattended, with no World Builder, video or screen.
- It measures a **source build** (upstream fork plus four small patches, 64-bit arm64, not VC6), not the shipped `Game.dat`. That is level 2 in the [verification doc](zero-hour-verification.md#levels), not level 1. Evidence that it still reflects retail: logic files the fork touches are 64-bit casts, `PLAYER_EXTERNAL` parity and an opt-in guard mode; nothing in locomotor, weapon or damage code; upstream keeps `RETAIL_COMPATIBLE_*` on by default; cruise speeds, turn rates, Ranger and Dozer acceleration and the Crusader interval match the INI within 0.15% (not the Crusader start lurch or the Ranger cadence). Whether 64-bit arm64 floating point shifts any of these numbers against retail is **unverified**.
- Differences the source-reading level 0 missed: range counts both units' geometry radii (stationary maxima 122 and 183, both 22% beyond Wargrid's centre-to-centre 100 and 150), the Ranger burst runs one frame slower per gap (time-to-kill +12%), tank shells splash neighbouring infantry, and movement starts 3 frames after an order with turn-in-place first.

### Decision list (proposal, for the next combat-feel work)

1. Range: switch to edge-to-edge distance, or keep centre-to-centre cells and accept shorter engagements.
2. Ranger cadence: 3/3/21 (INI arithmetic) or 4/4/22 (measured source-build behaviour).
3. Tank splash against infantry (radius and damage), currently omitted.
4. Start delay, acceleration and turn-in-place, currently instant.
5. Collector cycle: measured 773 frames per trip (≈26 s; 600 per trip, 6 cells/s confirmed) against Wargrid's ≈535 ticks; the extra ≈240 frames sit in the dock and centre stops. Keep the faster provisional timing or lengthen load/unload.

Numbers stay unchanged until each item is decided.

### Chinook trip method (2026-11-05)

The API player's faction is random and a raw `AmericaSupplyCenter` spawn never runs `onBuildComplete`; instant placement (`build_structure` without a dozer) leaves it under construction, so no Chinook and `train_unit` is refused. A spawned `AmericaVehicleDozer` (ordered 10 frames after spawn; in its spawn frame `buildObjectNow` fails) builds an `AmericaPowerPlant`, then the supply centre once `/buildable` shows it `ok`; the centre's Chinook appears 1257 frames in. Headless, `-noaudio`, fork `eb595cfc9`; trace `supply_chinook.tsv` (12,057 rows).

## Unverified

- Shipped binary behaviour (see assessment); a retail cross-check would still need Windows or Wine.
- Chinook load and unload times are not separated: the trace gives time in the dock zone (≈438 frames per trip, including descent) and in the centre zone (≈175 frames, deposit about 122 frames after entering), not the per-box load time.
- Whether the Crusader lurch and the +1 cadence also occur in a VC6 build.
- Scatter against infantry in other geometries, damaged speed (`SpeedDamaged`); not run.
- The fork's other changes outside game logic (audio/video shims) were not reviewed for timing effects; logic stepping is explicit, so wall-clock timing does not enter the traces.
