# How Zero Hour ground units avoid each other

Sources: ZH source `~/projects/CnC_Generals_Zero_Hour` @ 0a05454. Paths are relative to `GeneralsMD/Code/GameEngine/`: `AIPathfind.cpp`, `AIGroup.cpp`, `AIStates.cpp`, `AIDock.cpp` = `Source/GameLogic/AI/`; `AIUpdate.cpp`, `PhysicsUpdate.cpp` = `Source/GameLogic/Object/Update/`; `Locomotor.cpp`, `Object.cpp` = `Source/GameLogic/Object/`. Retail values are from root `INIZH.big` and `EnglishZH.big`, read in memory with a copy of `read_big`; the hash was not checked. Logic runs at 30 frames/s (`Include/Common/GameCommon.h:72`), the same as Wargrid's tick rate, so the seconds below carry over directly. One pathfinding cell = 10 world units (`Include/GameLogic/AIPathfind.h:440`).

Already decided, not asked again: units go around each other in transit, trucks included (user, 2026-11-07; blueprint §7 "Unit avoidance milestone"); distinct reserved destinations (M2).

## Findings (short, cited)

**Cells: only goal cells are reserved, not routes**
- **source** Every ground unit marks the cells it stands on (one per infantry, about 2×2 for a tank) and the cells of its goal (`AIPathfind.cpp:9694-9720` size, `:9725-9822` goal, `:9945-10050` position). A cell holds one "standing" unit and one "goal" unit (`AIPathfind.cpp:1326-1440`). Units never usurp a friend's goal cell (`AIPathfind.cpp:4971`).
- **source** The pathfinder does not look at moving units. It only adds a small cost to cells with moving friends within 10 cells of the start (`AIPathfind.cpp:6284-6286`). Standing friends can be pathed through at extra cost, and the path is flagged "blocked by ally" (`AIPathfind.cpp:6306-6316`, `:9068-9070`). Standing enemies are walls, unless they can be crushed (`AIPathfind.cpp:5085-5090`, `:6265-6270`).

**No physical pushing; the AI decides who yields**
- **source** Physics never pushes AI units apart: "AI objects move under their own initiative, not by getting bounced" (`PhysicsUpdate.cpp:1281-1289`). The collision only feeds `processCollision` (`AIUpdate.cpp:1434-1590`). When blocked, the locomotor brakes to the allowed speed and turns in place (`Locomotor.cpp:1053-1058`).
- **source** Blocked units match the speed of the unit ahead. They stop dead if it is coming toward them (`AIUpdate.cpp:1258-1292`), and speed ramps down by ×0.95 and back up by ×1.05 per frame (`AIUpdate.cpp:2222-2240`).
- **source** Right of way: dozers beat everyone, vehicles beat infantry, then the unit in front, then the lower object id (`AIUpdate.cpp:1215-1253`).
- **source** Moving into a standing unit while already facing the route sets "stuck", which triggers an immediate local re-route (`AIUpdate.cpp:1511-1519`, `AIStates.cpp:1821-1826`). Being blocked for more than 2 s also forces a re-route (`AIStates.cpp:1821`). The re-route considers units within 2 cells (`AIPathfind.cpp:10448-10461`). If it fails, the unit stops and waits 1 s (`AIUpdate.cpp:1757-1771`).
- **source** Head-on deadlock (both blocked, both facing each other): the lower-priority unit steps aside (`AIUpdate.cpp:1521-1535`). It runs a search for a spot off the other unit's path and always moves at least one cell (`AIPathfind.cpp:10195-10360`, `:10326`), with a 10 s cap (`AIUpdate.cpp:3256`). A blocked moving unit only waits ("Just wait", `AIUpdate.cpp:1540`).
- **source** Option tried and dropped by EA: "MOVE_AROUND … just causes more problems than it fixes" (`AIUpdate.cpp:1493`).

**Idle units get moved out of the way**
- **source** Each new path asks standing friends on it to step aside (`AIUpdate.cpp:1754`, `AIPathfind.cpp:10112-10187`). This happens only when the path is flagged "blocked by ally", except for dozers and harvesters, which always clear their path (`AIPathfind.cpp:10120-10123`). Friends that are attacking, busy or using an ability are not moved (`AIPathfind.cpp:10166-10178`). Enemies are never moved (`AIPathfind.cpp:10156`). Recursion is capped at depth 2 (`AIPathfind.cpp:10125`).
- **inferred** After stepping aside, a unit stays where it went. The step-aside is a temporary state that returns to the previous one without resetting it (`Include/GameLogic/AIStateMachine.h:185-186`, `AIStates.cpp:2186-2195`). No "return to old spot" was found.
- **source** Two standing units within half a cell of each other both move to the nearest free spot (`AIUpdate.cpp:1566-1583`).

**Infantry vs vehicles, crushing**
- **source** Infantry walk through all infantry, friend or enemy, moving or standing: the compile flag `INFANTRY_MOVES_THROUGH_INFANTRY` is on (`Include/GameLogic/AIPathfind.h:51`; `AIUpdate.cpp:1331-1337`; `AIPathfind.cpp:5055-5060`, `:10159-10161`).
- **source** Infantry do not squeeze past vehicles. A vehicle that bumps into infantry tells the infantry to move away and is not held up for long (`AIUpdate.cpp:1480-1491`). Infantry only push standing vehicles aside when their path is flagged blocked (`AIPathfind.cpp:10162-10165`). The vehicle push has no friend-or-foe check, so your vehicle can shove an enemy hero aside (**source**, looks like a bug).
- **source** Crushing: a moving vehicle kills enemy infantry that has `SquishCollide` when it drives toward them; allies are never crushed (`SquishCollide.cpp:97-131` in `Source/GameLogic/Object/Collide/`, `Object.cpp:1121-1125`). Crushable enemies do not block the route or the vehicle: "just run over them" (`AIUpdate.cpp:1314`, `AIPathfind.cpp:5087`).
- **source, retail** Crusher level 2 on tanks, trucks and dozers, for example the Crusader (`INIZH.big data\ini\object\americavehicle.ini:1437`), China supply truck (`chinavehicle.ini:2016`) and USA dozer (`americavehicle.ini:1701`). Level 3 on the Overlord, which also crushes vehicles (`chinavehicle.ini:280`). Bikes have none (`glavehicle.ini:501` block). Ordinary infantry are level 0 with `SquishCollide` (Ranger, `americainfantry.ini:887`). Heroes are level 2, so tanks cannot crush them (Burton, `americainfantry.ini:307`).
- **source** Computer players chase infantry on purpose to crush them (`AIStates.cpp:1164-1190`, `aidata.ini:61` `AICrushesInfantry = Yes`). Left for the M8 bots, not asked here.

**Groups and formations**
- **source** Group moves of 10 cells or more share one route 6 cells wide, with infantry in 3 (or 5) columns and vehicles in 2 (`AIGroup.cpp:519`, `:528-638`, `:688`, `:1159`; `aidata.ini:49-50` `MinDistanceForGroup = 100`, `DistanceRequiresGroup = 500`). This is forced above 50 cells, or with more than 6 infantry or more than 4 vehicles (`AIGroup.cpp:601-612`). Each unit moves at its own speed.
- **source** Ctrl+F makes a formation (`EnglishZH.big data\english\commandmap.ini:709-712`, `AIGroup.cpp:2600-2630`). Members keep their offsets, move at the slowest member's speed (`AIStates.cpp:2059-2064`, `AIGroup.cpp:402-460`) and slow to 55 % rather than crowd each other (`AIUpdate.cpp:1287-1289`).
- **source** Clicking inside the group's own area gathers it tightly instead (`gamedata.ini:374` factor 0.5, `AIGroup.cpp:1583-1631`).

**Chokepoints, bridges, docks, factories**
- **not found** No chokepoint-specific logic. "Pinched" cells are terrain only (`Include/GameLogic/AIPathfind.h:371`). Bridges are their own pathfinding layer, so units on and under a bridge do not block each other (`AIPathfind.cpp:3971`, `:9992-10001`). No bridge-specific avoidance was found, and Wargrid's four maps have no bridges (`rg -i bridge game/data/maps` = 0).
- **source** Supply trucks on a run sit in the dock state for the whole trip (`Source/GameLogic/Object/Update/AIUpdate/SupplyTruckAIUpdate.cpp:538,548` → `aiDock`). That state turns on "path through units" every frame (`AIStates.cpp:6170`), and that skips all collision handling (`AIUpdate.cpp:1444-1445`). **So ZH trucks drive through other units**, while other units still yield to them.
- **source** At a dock, one truck is served at a time. The others wait at numbered spots and move up as the line advances (`DockUpdate.cpp:112-232`, `:415-428` in `Source/GameLogic/Object/Update/DockUpdate/`). There are 9 spots at a warehouse (`civilianbuilding.ini:405`), 5 at a pile (`:553`), and an unlimited number at boneless docks (`:504`, `:605`).
- **source** New units leaving a factory drive through units for up to 10 s and clear friends off their exit line (`AIUpdate.cpp:1698-1708`, `:3884`; `AIStates.cpp:3274-3276`).

**Timeouts that let units overlap**
- **source** After 1 s blocked, units whose headings differ by 90° or more just pass through each other (`AIUpdate.cpp:1359-1362`).
- **source** A unit within one cell of its final goal ignores blockers (`AIUpdate.cpp:1303-1311`). Overlaps at the goal are cleaned up by the spread rule above.
- **source** Re-routing again within 3 frames while stuck makes the unit wait 1 s and ignore collisions for 2 s (`AIUpdate.cpp:505-518`; attack path `:1793-1803`). A unit asked twice by the same unit to step aside while blocked also ignores collisions for 2 s (`AIUpdate.cpp:3219-3230`).
- **inferred** If both step-aside searches fail, "path through units" stays on (`AIUpdate.cpp:3247-3249`). It is only reset by certain state exits (`AIStates.cpp:2192`, `:3322`, `:4342`, `:6148`), so the unit may ghost for the rest of its move (likely bug).
- **not found** No overall "give up the order" timeout. The move fails only when no path exists (`AIStates.cpp:1880-1895`).

## Questions

Q1. When a unit's route runs into a friendly unit that is standing still, what should happen?
   a) The standing unit steps aside and the mover keeps going — ZH default (`AIPathfind.cpp:6306-6316`, `:10112-10187`)   b) The mover goes around; standing units never move   c) The mover waits until the way clears
   Recommendation: a, because it keeps parked blobs from walling in your own army. Why it matters: this decides whether a crowded base feels fluid or clogged.

Q2. When two moving units meet head-on and neither can pass, what should happen?
   a) The one with lower right of way steps aside a cell or two, then both continue — ZH default (`AIUpdate.cpp:1521-1535`, `AIPathfind.cpp:10326`)   b) Both stop, and each looks for a new route   c) Both slide around each other smoothly without stopping
   Recommendation: a, because it is ZH's main jam breaker and stays deterministic. Why it matters: this is the most common jam in narrow spots.

Q3. When units get in each other's way, who should make way?
   a) Infantry always make way for vehicles, builders get way from everyone, otherwise the unit in front goes first — ZH default (`AIUpdate.cpp:1215-1253`, `:1480-1491`)   b) Whoever was ordered first goes first   c) Everyone is equal; the unit in front goes first
   Recommendation: a, because tanks shoving through soldiers is part of ZH's feel. Why it matters: it decides who waits in every collision.

Q4. If two units still block each other after a moment, may they pass through each other as a last resort?
   a) Yes: crossing or opposite units pass through after about 1 s, and other stuck cases ignore collisions for 2 s — ZH default (`AIUpdate.cpp:1359-1362`, `:505-518`, `:3219-3230`)   b) Yes, but only after about 5 s of being stuck   c) Never; they stay stuck until the player moves one
   Recommendation: b, because ZH's 1 s gives up too fast for "units go around each other", and c breaks the blueprint's bounded-blocked-state rule (§5). Why it matters: this is the safety net against permanent deadlocks in lockstep, but too short brings back the overlap you disliked.

Q5. Should infantry be able to walk through other infantry? (This checks your 2026-11-07 "all units go around" against a ZH finding.)
   a) Yes, infantry pass through all infantry; only vehicles block them — ZH default (`Include/GameLogic/AIPathfind.h:51`, `AIUpdate.cpp:1331-1337`)   b) No, soldiers go around soldiers too   c) Through friendly soldiers only, never enemies
   Recommendation: a, because ZH does it and it avoids horde jams and extra cost in the browser build. Why it matters: it is the biggest cost and deadlock risk in the milestone, and the 2026-11-07 decision assumed ZH infantry avoid each other.

Q6. How long should a blocked unit wait before it looks for another way around?
   a) Re-route at once if the blocker stands still, otherwise after 2 s — ZH default (`AIUpdate.cpp:1511-1519`, `AIStates.cpp:1821`)   b) Always wait about 1 s first   c) Always wait about 3 s first
   Recommendation: a, because it is ZH's timing and Wargrid runs at the same 30 Hz. Why it matters: too short looks twitchy, too long looks dumb.

Q7. Should vehicles run over enemy soldiers they drive into?
   a) Yes: tanks, trucks and dozers kill ordinary enemy soldiers (not heroes) they drive over, so those soldiers never block vehicles — ZH default (`SquishCollide.cpp:97-131`, `AIUpdate.cpp:1314`, retail `americavehicle.ini:1437`, `americainfantry.ini:887`)   b) Only tanks crush   c) No crushing in this milestone; soldiers block like anything else
   Recommendation: a, because blueprint §1 keeps crushing and it removes a whole class of jams. Why it matters: it changes how infantry play near tanks and whether this milestone also adds a kill rule.

Q8. At a busy supply dock, how should trucks deal with each other?
   a) ZH default: trucks on supply runs drive through all units, and others yield to them (`AIStates.cpp:6170`, `AIUpdate.cpp:1444`). This conflicts with your 2026-11-07 decision.   b) Trucks are solid everywhere, but may overlap other trucks right at the dock   c) Trucks are solid everywhere and queue in a line of waiting spots, as ZH's docks do (`DockUpdate.cpp:136-232`)
   Recommendation: b, because docks are the deadlock risk the blueprint names, and overlap there is barely visible. Why it matters: it keeps your "trucks go around" decision without risking stalled income.

Q9. When a group travels far, how should it move?
   a) As a column on one shared route (infantry 3 wide, vehicles 2 wide), each unit at its own speed — ZH default (`AIGroup.cpp:528-638`, `:688`, `:1159`)   b) Each unit takes its own route   c) The group keeps its shape and moves at the slowest unit's speed
   Recommendation: a, because columns collide far less and match ZH's look. Why it matters: it sets how armies look on the march and how often they jam.

Q10. When a new unit rolls out of a factory into a crowd, what should happen?
   a) It drives through units for up to 10 s on its way out, and friends get cleared off its exit line — ZH default (`AIUpdate.cpp:1698-1708`, `:3884`; `AIStates.cpp:3274-3276`)   b) Friends at the door step aside, but the new unit stays solid   c) The factory holds the unit until the door is clear
   Recommendation: b, because it keeps "go around" while making sure production never stalls. Why it matters: the factory door is the busiest spot in every base.

Q11. Should your units be able to block enemy units with their bodies, for example by walling a pass with tanks?
   a) Yes: standing units are walls to enemies, and enemies are never asked to move — ZH default (`AIPathfind.cpp:6265-6270`, `:10156`)   b) No, enemy units pass through each other
   Recommendation: a, because body-blocking is a real tactic and follows from "units go around each other". Why it matters: it makes chokepoints and base entrances tactical.

Q12. Should a unit that is shooting step aside for a friend passing by?
   a) No, it holds its spot and the friend goes around — ZH default (`AIPathfind.cpp:10166-10171`)   b) Yes, it steps aside and keeps shooting
   Recommendation: a, because fights should not shuffle units out of position. Why it matters: it decides whether reinforcements can break your firing line.

Q13. After a unit steps aside, should it walk back to where it stood?
   a) No, it stays where it stepped — ZH default (inferred, `Include/GameLogic/AIStateMachine.h:185-186`)   b) Yes, once the way is clear
   Recommendation: a, because walking back causes new collisions and ZH players expect it. Why it matters: it decides whether parked units creep apart over a match.

Q14. When a fast unit catches up with a slower friend on the same route, what should it do?
   a) Slow to the friend's speed and follow; after about 2 s, try a way past — ZH default (`AIUpdate.cpp:1258-1292`, `AIStates.cpp:1821`)   b) Overtake right away
   Recommendation: a, because it matches ZH and avoids constant overtaking jams on roads. Why it matters: it shapes how mixed armies string out on the march.

Q15. Should there be a "keep formation" command (Ctrl+F in ZH) that keeps a group's shape and moves it at the slowest unit's speed?
   a) Yes, as in ZH — ZH default (`commandmap.ini:709-712`, `AIGroup.cpp:2600-2630`, `AIStates.cpp:2059-2064`)   b) Not in this milestone; consider it with the M7.6 HUD   c) Never
   Recommendation: b, because it adds a command and HUD work beyond avoidance. Why it matters: it keeps the milestone scope from growing.
