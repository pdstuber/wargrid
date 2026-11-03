# Verification against real Zero Hour — 2026-11-03

Status: **LEVEL 0 DONE (SOURCE/CONFIG); LEVEL 1 PROTOCOL PROPOSED, NOT RUN; LEVEL 2 NOT STARTED**. Nothing here measures the running retail game. Never describe level 0 values as measured parity. Scope rule from [AGENTS](../../AGENTS.md): preserve strategic identity and feel; original bugs and slow algorithms are not compatibility requirements. Goal is calibrated constants and feel, not trace parity.

## Levels

| Level | Evidence | State |
|---|---|---|
| 0 | Source plus hash-pinned INI reading | done below |
| 1 | Observe the real game: video frame counts and a World Builder ruler map, scalar results | protocol below, awaiting user session |
| 2 | Instrumented build of EA source logging per logic frame | only if level 1 shows disagreement that matters |
| 3 | Replay/full-match trace comparison | rejected: Wargrid grid, direct-hit combat and pathing differ by design, so it fails by construction |

Fixed facts: logic runs at 30 frames/s (`LOGICFRAMES_PER_SECOND = 30`, `GeneralsMD/Code/GameEngine/Include/Common/GameCommon.h:72`), same as Wargrid's tick, so frame counts in a recording map one-to-one to ticks. `WorldBuilder.exe` is present in the Zero Hour install backup (tar member listing), availability on the Steam Deck install itself unchecked. Source revision and archive hash as in [installation](installation.md) and [M4 combat](m4-combat.md); `Locomotor.ini` below read from root `INIZH.big` (SHA-256 `1a6d41a7…e9a0`, hash re-verified 2026-11-03).

## Level 0 result: speeds and scale

Pathfinding cell is 10 world units (`PATHFIND_CELL_SIZE 10`, `GeneralsMD/Code/GameEngine/Include/GameLogic/AIPathfind.h:439`). Wargrid ranges (rifle 100 → 4 cells, tank 150 → 6 cells) imply **1 Wargrid cell = 25 world units**. That mapping is inferred from the range ratio, not documented anywhere else.

Speeds below are `Locomotor.ini` `Speed` in world units per second, resolved through each object's `Locomotor = SET_NORMAL …` line in the decoded object INIs.

| Object | Locomotor | Speed | Cells/s at 25 units/cell | Wargrid before 2026-11-03 |
|---|---|---:|---:|---:|
| `AmericaInfantryRanger` | `BasicHumanLocomotor` | 20 | 0.8 | 3.0 (M4 infantry, provisional) |
| `AmericaTankCrusader` | `CrusaderLocomotor` | 30 | 1.2 | 3.0 (M4 tank, provisional) |
| `AmericaVehicleDozer` | `AmericaVehicleDozerLocomotor` | 30 | 1.2 | 3.0 (builder) |
| `AmericaVehicleHumvee` | `HumveeLocomotor` | 60 | 2.4 | 3.0 (legacy vehicle) |
| `AmericaVehicleChinook` | `ChinookLocomotor` | 150 | 6.0 | 6.0 (collector) |

Findings:

1. Only the collector matches the 25-unit mapping (6.0 equals 150/25 numerically; M3 text says "provisional", so treat as possibly coincidental). Every ground unit is 2.5 to 3.75 times faster than the mapping implies.
2. Engagement shape differs. Real Ranger crosses rifle range in 100/20 = 5 s, Crusader crosses tank range in 150/30 = 5 s. Wargrid at 3.0 cells/s: 4/3 = 1.3 s and 6/3 = 2 s. Chases, kiting and retreat windows are 2.5 to 4 times shorter than the source data implies.
3. Real Crusader is 1.5 times faster than Ranger. Wargrid has them equal.
4. Tick-based timers (shots, reload, build, cost) do not depend on the scale and are unaffected.

**Adopted by user 2026-11-03:** ground speeds derive from the 25-unit scale: infantry 0.8, tank 1.2, builder 1.2 cells/s. Builder applied in code (`economy_definitions.gd`); infantry/tank go into M4 definitions. Legacy unarmed `vehicle` stays 3.0: it is the M1/M2 prototype and benchmark unit, not a Humvee mapping, and changing it would alter M2 benchmark and replay behavior. Consequence: a 40-cell base-to-base trip takes 33 s for a tank and 50 s for infantry; M4 task7 schedule was not yet measured and must be calibrated against these speeds.

## Level 0, automated (2026-11-03)

`python3 tools/check_reference.py "<Zero Hour backup>.tar.gz"` reads the root `INIZH.big` in memory, refuses any other bytes than the pinned SHA-256 (see [installation](installation.md)), asks Godot for Wargrid's live definitions (`game/scripts/debug/dump_definitions.gd`) and compares 74 values: cost, build ticks (`BuildTime` × 30), milliHP (`MaxHealth` × 1000), armor class, ground speed (`Locomotor Speed` ÷ 25), primary weapon, power, weapon damage/type/range (÷ 25)/delay/clip/reload (milliseconds to logic frames rounded up, as `Weapon.cpp` 407–408), and the armor matrix for small arms and armor piercing (unlisted types 100%, else `DEFAULT`, as `Armor.cpp` 54–64). It exits 1 on any difference that is not a listed deliberate departure. Local only; its unit tests use synthetic BIG/INI fixtures and run in CI without retail data.

Result on the pinned data: **74 rows, 0 differ**; two deliberate departures (legacy `vehicle` speed 3.0 against Humvee 2.4, and unarmed against `HumveeGun`). Printed but not modelled: `SpeedDamaged`, `Acceleration`, `TurnRate` per locomotor (for example Dozer acceleration 30, Ranger turn rate 500, Crusader 180), tank `PrimaryDamageRadius` 5 and `ScatterRadiusVsInfantry` 10. Object names it resolves: Ranger, Crusader, Dozer, Humvee, Chinook, Barracks, Power Plant, Supply Center, War Factory. This is still source/config evidence: it shows Wargrid matches the shipped data, not that the shipped binary behaves like the source; see level 1.

## Goal calibration (user, 2026-11-03)

Goal is a pixel-art clone that **feels very close**, not mathematical parity. Consequences: level 2 and 3 are out unless level 1 shows a feel problem numbers cannot explain. Ratios drive feel (speed vs range, tank vs infantry pace, time-to-kill, build/economy pacing), so level 1 tolerances widen to about ±20% and V6–V9 become side-by-side feel checks (record impressions plus frame counts) rather than pass/fail. Not covered by numbers: acceleration/turning, unit size relative to a cell, sound and UI responsiveness; only side-by-side play shows those.

## Level 1 protocol (proposed)

Setup, once: record game version string, install source (Steam Deck copy), mods none, display resolution, and that no unit upgrades or generals powers are active. Use a World Builder map (flat terrain, no obstacles, units placed at exact coordinates) so distances are known. If World Builder is unavailable, stop and ask; do not estimate distances by eye. Record at 60 fps or better and count frames.

| Id | Scenario | Measure | Compare against | Tolerance |
|---|---|---|---|---|
| V1 | Ranger moves straight over a known distance | seconds, speed in units/s | 20 | ±10% |
| V2 | Crusader, Dozer, Humvee, same | speed | 30, 30, 60 | ±10% |
| V3 | Ranger attacks stationary Ranger-sized target at increasing distance | farthest distance at which it fires | 100 | ±10 units |
| V4 | Crusader vs stationary tank | farthest firing distance; shot interval in frames | 150; 60 logic frames | ±10 units; ±1 frame |
| V5 | 10 Rangers vs one stationary Crusader (no upgrades; one Ranger needs about 115 s, too long to time) | shot rhythm of one Ranger, then time to kill | 3-shot burst at 3-frame spacing, 21-frame reload; 1.25 HP per shot, 384 shots for 480 HP, so about 11.5 s for 10 Rangers | ±1 frame; ±15% time to kill |
| V6 | Crusader vs one Ranger | shots to kill, time to kill | M4 direct hit: 6 HP per shot, 30 shots, first shot to death at least 1740 frames if all hit | report; source has splash and scatter, so large variance is expected, not a failure |
| V7 | Barracks and war factory production | seconds for Ranger (5 s) and Crusader (10 s) | `AmericaInfantry.ini`/`AmericaVehicle.ini` build time | ±0.5 s |
| V8 | Supply collection cycle (Chinook) | first deposit time and amount per trip | M3 economy values | report |
| V9 | Low-power production slowdown | build time at 0.5–0.8 rate | M3 power rule | report |

Output: one results table in a new `docs/reference/zero-hour-level1-results.md` with raw frame counts, video file names (kept outside the repo), version info and a per-row verdict of match, differs, or unclear. Differences feed a decision list; they do not automatically change numbers. Never mark a row verified without recorded frame counts.

## Gate

M5 (core factions) adds many unverified constants. Treat completion or explicit user deferral of level 1 as a gate before M5 kickoff, recorded in README and the blueprint. Level 2 is optional and only considered after level 1. Any Zero Hour source used for level 2 stays external and read-only: no code copied (AGENTS), and GPL terms make that a hard rule.
