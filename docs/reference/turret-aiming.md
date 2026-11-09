# Turret aiming in the simulation: impact note (2026-11-09)

Sources. **ZH src** = ~/projects/CnC_Generals_Zero_Hour @ 0a05454, paths under `GeneralsMD/Code/GameEngine/`. **INI** = retail root `INIZH.big` (pinned hash) decoded into the session scratchpad, cited as `data\ini\object\<file>:line`. Single values only. Wargrid kind -> ZH object: USA from `tools/check_reference.py:24-34`; China/FRC **inferred** from display names.

## 1. Zero Hour facts
- **source** Aim gate: AIM hands over to FIRE only when turn AND pitch are aligned and the target is in range (`Source/GameLogic/AI/TurretAI.cpp:1169-1199`); turn threshold about 2 deg (`:1093-1094`). States IDLE/IDLESCAN/AIM/FIRE/RECENTER/HOLD (`:93-101`).
- **source** Rates are deg/s parsed to rad/frame (`Source/Common/INI/INI.cpp:598-604`); 30 frames/s (`Include/Common/GameCommon.h:72`). Unset default is 0.01 rad/frame, about 17 deg/s (`Include/GameLogic/TurretAI.h:37-38`, `TurretAI.cpp:178-179`). **Correction:** Q8 in `docs/questions/next-m75-art-look.md:56` says "about 60 deg/s" from `TurretAI.cpp:178-181`; that is wrong. 60 is only the commented-out old Crusader value; retail Crusader is 180.
- **source** `FiresWhileTurning` only keeps the turret move sound playing (`TurretAI.cpp:708-727`; header comment `Include/GameLogic/TurretAI.h:239`); it does not skip the aim gate. It is read at `:202, :260, :286, :371, :708` and nowhere else.
- **source** Recenter: after losing the target the turret holds for `RecenterTime` (default 2 s, `TurretAI.cpp:200`; HOLD state `:1439`), then turns back to `NaturalTurretAngle` (default 0 = hull forward, `:180`).

| Wargrid kind | ZH object | TurretTurnRate deg/s | Other |
|---|---|---|---|
| usa_tank | AmericaTankCrusader | 180 (`americavehicle.ini:1476`, old value 60 in comment) | |
| usa_light_vehicle | AmericaVehicleHumvee | 180 (`americavehicle.ini:158`) | RecenterTime 5000 ms (`:159`) |
| usa_defence | AmericaPatriotBattery | 180 (`factionbuilding.ini:28897`) | pitch 180 (`:28898`), idle scan 250 ms, 0-360 deg (`:28904-28907`) |
| china_light_vehicle | ChinaTankBattleMaster | 120 (`chinavehicle.ini:104`) | |
| china_tank | ChinaTankGattling | 180 (`chinavehicle.ini:1870`) | pitch 180, FiresWhileTurning (`:1871-1873`) |
| china_defence | ChinaGattlingCannon | 180 (`factionbuilding.ini:31681`) | pitch, FiresWhileTurning, scan 250 ms (`:31682-31689`) |
| frc_tank | GLATankScorpion | 100 (`glavehicle.ini:194`) | RecenterTime 5000 ms (`:195`) |
| frc_light_vehicle | GLAVehicleTechnicalChassisOne | 240 (`glavehicle.ini:4767`) | idle scan 30-60 deg every 5-10 s (`:4769-4772`) |
| frc_defence | GLATunnelNetwork | 180 (`factionbuilding.ini:15085`) | |

- **source** 9 of Wargrid's current kinds have a turret in ZH (6 vehicles, 3 defences). Typical rate 180 deg/s (72 of 209 `TurretTurnRate` lines in `data\ini\object\`; then 60 x42, 100 x17). At 30 Hz, 180 deg/s = 6 deg/tick: a full 180 deg turn takes 30 ticks (1 s); BattleMaster 1.5 s, Scorpion 1.8 s.
- **source** No turret: infantry (Ranger, Missile Defender, Red Guard, Tank Hunter, Rebel, Tunnel Defender: no `Turret` block), dozers, workers, Chinook, supply truck. Armed ones turn the whole body until within about 2 deg (or the weapon's AimDelta) before firing (`Source/GameLogic/AI/AIStates.cpp:5051-5072`); infantry TurnRate 500 deg/s (`data\ini\locomotor.ini:10, :27`), so at most about 11 ticks.
- **source** Wargrid today: combat never reads `heading` (0 matches in `game/scripts/simulation/combat.gd`). Hull turning happens only while moving (`locomotion.gd:11-22`). So neither turret nor hull facing delays a shot. Units that moved this tick do not fire (`combat.gd:352-358`). **inferred** ZH turreted units do fire on the move; not checked in source here.

## 2. What it would change in Wargrid
- **Firing decision:** units in `Combat.fire` (`combat.gd:352-368`; gate at `:361-363`), defences in `Combat.fire_defences` (`combat.gd:389-420`; gate at `:408`). Add one more condition, "turret aligned", next to `next_fire_tick` and `_in_range`, plus a turn step for every armed unit each tick before `fire`.
- **State:** a `turret` unit vector `[x, y]` like `heading` (`simulation.gd:85`), plus a hold-until tick for recentering, stored in the `combat` dict from `CombatDefinitions.initial_combat` (`combat_definitions.gd:34-40`). Snapshot (`simulation.gd:628`) and `StateHash.digest` (`state_hash.gd:10-13`, whole-state `hash()`) pick it up without new code. Per-kind `turret_cos/turret_sin` in definitions, the same way as `turn_cos/turn_sin` (`definitions/usa.gd:11`). Reuse `Locomotion.turn` (`locomotion.gd:20`). Infantry hull aim would set `heading` while standing.
- **Pins and traces that move (inferred):** `test_team_match.gd:13` FINAL_DIGEST (it spawns `usa_tank`, `:27`); `test_state_hash.gd:6` PINNED only if its world holds an armed unit (not checked); first-shot ticks in `test_combat.gd` (64 cases, 16 tick lines), `test_defences.gd`, `test_ramp.gd`, `test_containers.gd`, `test_tunnels.gd`, `test_teams.gd`, `test_skirmish_match.gd`, `test_horde.gd`, `test_salvage.gd`; CI replay traces (`tools/compare_local_traces.sh`, `tools/desync_diff.py`) and the `tools/run_netplay.sh` scenarios; benchmark rows (fights start later).
- **Cost per tick (inferred, not measured):** one dot product plus one rotation per armed unit that is not aligned; aligned or idle turrets skip. Smaller than locomotion's turn step, which already runs per moving unit. Needs a benchmark row like any sim change.
- **Batch A shells and minimum range (inferred):** shells fly to the target's position at firing time (`docs/questions/next-batch-a.md:8`). A turret delay means a fast unit has moved further before the first shell leaves. Minimum range backs a unit away and then fires (`design-answers-2026-11-08.md:85`); with turrets the turret keeps tracking while the hull backs off. Both already change first-shot timing and re-pin the same traces, so one re-pin covers all of it.
- **Avoidance:** "a unit that is shooting holds its spot" (`design-answers-2026-11-08.md:117`). An aiming unit must count as shooting, or friends push it away while its turret is still turning (inferred).
- **Presentation:** the drawn turret reads `combat.turret` from the snapshot, with no own rate or timers, so Q8's drawing-only state goes away. Idle scan (Technical 5-10 s random) stays presentation-only, so it never uses the sim's seeded random (inferred recommendation).

## 3. Gameplay effect in plain words
- A tank that switches target has to turn its turret first: up to 1 s for the Crusader, 1.8 s for the Scorpion, before the next shot can fire. Reload is 2 s for Crusader and BattleMaster (`data\ini\weapon.ini:342, :313`), so a full turn can cost nearly one shot.
- Fast units circling a tank make it keep re-aiming. Kiting and flanking pay off, and a Scorpion (100 deg/s) is easier to flank than a Technical (240 deg/s).
- Facing starts to matter: tanks arriving with their turret already pointed forward fire first. Today a tank fires the tick it stops, in any direction.
- Infantry get only a small delay (at most about 0.36 s), but it shows: soldiers face whoever they shoot.
- Defences (180 deg/s) react about 1 s later to an attack from behind.

## 4. Placement options
- **Ground batch A (recommended):** shells, minimum range and line of sight already change combat timing and traces there, so one re-pin covers it. Batch A also adds most new turreted units, so each gets its rate once. The art lab and M7.5 draw turrets from sim state afterwards; until batch A, the drawing-only stand-in from Q8.
- **M7.5:** mixes a sim and trace change into an art pass that is presentation-only by design (`docs/art-lab-prompt.txt:1`). Not recommended.
- **Later (with batch B or a combat-feel spike):** a second re-pin, and new units get tuned without turret delay first.
- **Never:** keep "firing ignores heading" (blueprint M6, `docs/blueprint.md:547`). Simplest, but tanks then play like ZH units with an infinite turn rate.

## Questions
Q1. Should a tank's turret have to point at its target before it can fire?
   a) Yes, the turret turns at its rate and fires once aligned — ZH default (TurretAI.cpp:1169-1199)   b) No, turrets are drawing only and firing ignores facing (today)
   Recommendation: a, because turn time is part of how ZH tanks feel against fast units. Why it matters: changes first-shot timing and re-pins traces.
Q2. When should turret aiming land, if yes?
   a) Ground batch A, together with travelling shells and minimum range   b) Its own small task before batch A   c) After batch B
   Recommendation: a, because batch A already moves the same traces and timing tests. Why it matters: each later slot costs another re-pin.
Q3. Should soldiers (no turret) have to turn their whole body to face the target before firing?
   a) Yes, within about 2 degrees, at their turn rate (about 0.36 s at most) — ZH default (AIStates.cpp:5051-5072)   b) No, soldiers fire in any direction
   Recommendation: a, because it is cheap, tiny in effect, and makes soldiers visibly face their target. Why it matters: same re-pin as Q1.
Q4. Should each tank keep its own Zero Hour turret speed?
   a) Yes: Crusader 180, BattleMaster 120, Scorpion 100, Technical 240 deg/s — ZH default (INI rows above)   b) One rate for all turrets
   Recommendation: a, because the Scorpion's slow turret is part of its trade-off. Why it matters: data only, no extra code.
Q5. After losing its target, when does the turret turn back to face forward?
   a) After a short wait (2 s, Humvee and Scorpion 5 s), then turns back — ZH default (TurretAI.cpp:200, :1439)   b) Right away   c) It stays where it last aimed
   Recommendation: a, because it keeps the ZH look and a tank that loses a target briefly is still pointing the right way. Why it matters: one hold-until tick per unit in the hash.
Q6. Should turreted units be able to fire while driving?
   a) Yes, turreted units shoot while moving — ZH behaviour (inferred, not checked in source)   b) No, units fire only when they did not move this tick (today, combat.gd:352-358)
   Recommendation: research first: check ZH source before answering. Why it matters: big gameplay change (attack-move, kiting), and only possible once turrets exist.
