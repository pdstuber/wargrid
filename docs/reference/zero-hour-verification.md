# Verification against real Zero Hour — 2026-11-03

Status: **LEVEL 0 DONE (SOURCE/CONFIG); LEVEL 0 AUTOMATED (74 values, 0 differ); LEVEL 1 REDUCED TO THREE SPOT CHECKS, NOT RUN; LEVEL 2 NOT STARTED**. Nothing here measures the running retail game. Never describe level 0 values as measured parity. Scope rule from [AGENTS](../../AGENTS.md): preserve strategic identity and feel; original bugs and slow algorithms are not compatibility requirements. Goal is calibrated constants and feel, not trace parity.

## Levels

| Level | Evidence | State |
|---|---|---|
| 0 | Source plus hash-pinned INI reading | done below |
| 1 | Observe the real game: three scripted-map spot checks (speed, range and reload, burst rhythm) | reduced protocol below, awaiting user session |
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

## Level 1 protocol (reduced by user decision, 2026-11-03)

The formula rows of the earlier protocol (build times, low-power slowdown, weapon timing arithmetic, armor percentages, top speeds as configured) are now covered by the automated level 0 check above. Level 1 only has to answer what reading cannot: does the shipped game behave like the released source and data? One short session of three spot checks does that; any one failing reopens the full list (kept in git history).

Setup, once: game version string, install source, no mods, no upgrades or generals powers. A World Builder map with scripts that places units at exact coordinates on flat terrain, orders them and shows a frame counter, so nothing is measured by eye. If World Builder or its scripting is unavailable, stop and ask. Record at 60 fps or better.

| Id | Spot check | Measure | Expected (source/data) | Tolerance |
|---|---|---|---|---|
| S1 | Ranger walks a known straight distance | speed in units/s | 20 | ±10% |
| S2 | Crusader against a stationary target moved closer step by step | farthest firing distance; frames between shots | 150 units; 60 frames | ±10 units; ±1 frame |
| S3 | Ranger firing at a stationary target | burst rhythm | 3 shots 3 frames apart, then 21 frames | ±1 frame |

Optional feel notes in the same session, impressions plus frame counts, no pass/fail: acceleration and turning of Dozer, Ranger and Crusader (not modelled by Wargrid), Crusader against infantry (splash and scatter, omitted by Wargrid), one Chinook supply trip.

Output: a short results table in `docs/reference/zero-hour-level1-results.md` with raw frame counts, version info and a verdict per row (match, differs, unclear). Video files stay outside the repo. Differences feed a decision list and never change numbers automatically. Never mark a row verified without recorded frame counts.

**Level 1 done by harness (user decision, 2026-11-05):** the [parity harness spike](zero-hour-parity-spike.md) measured S1–S3 and the feel notes frame by frame on a native macOS source build instead of this manual session; caveat: a source build, not the shipped binary. S1 and the S2 interval match; S2 distance and S3 differ by definition (range edge-to-edge, +1 frame per burst gap) and go to the spike's decision list. The [parity harness](zero-hour-parity-harness.md) replaces the manual protocol for later checks.

## Gate

M7 (China and GLA core; renumbered from M5 on 2026-11-03) adds many unverified constants. Treat completion or explicit user deferral of the reduced level 1 (S1–S3) as a gate before M7 kickoff, recorded in README and the blueprint. Level 2 is optional and only considered after level 1. Any Zero Hour source used for level 2 stays external and read-only: no code copied (AGENTS), and GPL terms make that a hard rule.
