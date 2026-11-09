# Next: bot attacks that reach the enemy (M8), and the Fm1 red test

Sources. **ZH src** = ~/projects/CnC_Generals_Zero_Hour @ 0a05454, paths under `GeneralsMD/Code/GameEngine/Source/`. **INI** = retail root `INIZH.big` decoded into the session scratchpad. **Maps** = `~/projects/CnC_Modding_Support` @ 3aad8e4, read with `tools/zh_map/convert.py load()` into the scratchpad. **Research doc** = wargrid `docs/reference/m7-verification-archive-research.md` (decoded `SkirmishScripts.scb`). Already decided, not asked: start from ZH's enemy choice, target scores and wave timing, then Wargrid's own better rules; a losing bot never gives up (design-answers 2026-11-08). Still open in earlier files and not repeated here: `zh-defaults-followup.md` Q12 (fight targeting per level) and Q13 (decision rate); `upcoming-milestones.md` Q8 (order cap).

## Findings (short, cited)
- **source, Wargrid** On Ashfall the waves launch but armies end 30 to 63 cells short of the enemy base (start distance 154 to 168) and shrink; in four of six sweep rows a seat never damaged an enemy building. Whether they die midway or stall was not checked (wargrid `docs/reference/more-maps.md:89`, `converted-maps-verification.md:266, 274`).
- **source** ZH waves follow map-authored approach routes: the team's centre picks the closest waypoint on the path labelled `<label><enemy start + 1>` and follows it, as a team or individually (ZH src GameLogic/ScriptEngine/ScriptActions.cpp:1680-1722). Labels are Center, Flank and BackDoor; later waves split across all three; at the end the team hunts (research doc lines 113, 118).
- **source** All three converted maps carry these routes: Twilight Flame (Ashfall) `Center1..8`, `Flank1..8`, `BackDoor1..8`, 2-3 waypoints each; Tournament Desert (Dry Wells) `Center1-2`, `Flank1-2`, `BackDoor1-2`, 3-5 each; Fallen Empire (Broken Crown) `Center1-4`, `Flank1-4`, `Backdoor1-4`, 2 each. Wargrid's converter reads only `Player_N_Start` waypoints (wargrid `tools/zh_map/convert.py:261-265`) and drops the routes.
- **source** "Follow as a team": a group counts as at a waypoint when within `SkirmishGroupFudgeDistance` 5.0 x unit count (`data\ini\default\aidata.ini:41-44`). **inferred** the group waits for stragglers at each waypoint.
- **source** No retreat scripts for waves; transports are left at < 25 % health; waves already in the own base switch to "Base Invaded Hunt" when invaded (research doc lines 119-120, 154).
- **not found** A time limit in ZH skirmish or multiplayer: game options are map, starting cash and superweapon limit only (ZH Include/GameNetwork/GameInfo.h:200-203, 254-255).
- **source, Wargrid** `Fm1` (FRC bot match) no longer ends inside its 45,000-tick cap since the collector counts changed (FRC 5 per center instead of 7); per the reviewer, FRC wins at tick 73,560 after the map runs dry near 30,000 (`more-maps.md:99`).

## Questions
Q1. Before changing the bot's attack logic, should M8 first measure why Ashfall waves stop short (die in battle or stall on the path)?
   a) Yes, log wave positions, losses and contacts per wave first, then choose the fix   b) No, go straight to the new wave logic
   Recommendation: a, because the two causes need different fixes and the measurement is a scratch script. Why it matters: avoids tuning the wrong thing.

Q2. Which way should a bot wave travel to the enemy base?
   a) Along the map's authored routes (Center, Flank, BackDoor per enemy start), carried over by the map converter — ZH default (ScriptActions.cpp:1680-1722; routes present in all three maps)   b) Straight pathfinding to the enemy base (today)   c) Routes the bot works out itself from the map (blueprint's parked chokepoint analysis)
   Recommendation: a, because the routes already exist in the GPL map files, match ZH feel and cost nothing at runtime; c can come later for maps without routes. Why it matters: needs a converter change and a map-data field.

Q3. If authored routes are used, which route does a wave take?
   a) Fixed per wave, later waves split over all three routes — ZH default (research doc line 118)   b) Picked from the simulation's seeded random per wave   c) The route where the team has seen the fewest enemy defences
   Recommendation: c for the top levels and a for the lower ones, because it uses only team-visible information and gives the levels a real difference. Why it matters: decides if attacks are predictable.

Q4. How should a wave move along its route?
   a) As one group that waits for stragglers at each waypoint — ZH default (aidata.ini:41-44; waiting inferred)   b) Each unit at its own speed (today)   c) At the speed of the slowest unit
   Recommendation: a, because arriving together is what makes a wave a wave. Why it matters: fast units arriving alone die first, which may be part of the Ashfall problem.

Q5. What does a wave do at the end of its route?
   a) Hunt: attack whatever scores highest nearby (priority minus distance) — ZH default (research doc line 113; AI.cpp:683-720)   b) Go for the enemy's production buildings first   c) Go for the target picked at launch
   Recommendation: a, because the scoring rule is already decided as the starting point. Why it matters: sets what the bot hits first.

Q6. Should a badly beaten wave retreat?
   a) Never; it fights to the end — ZH default (research doc lines 120, 154)   b) Retreat home when it lost most of its strength, with hysteresis so it does not flip back and forth   c) Retreat only at the top levels
   Recommendation: c, because the blueprint proposes "retreat with hysteresis" as a competence and the levels are cut by removing competence. Why it matters: keeps veterans alive (veterancy is decided).

Q7. If the bot's base is attacked while a wave is away, what does the wave do?
   a) Keep going; only units at home react — ZH default (research doc line 119; inferred for waves outside)   b) Turn back if the attackers are stronger than the home defence (as the team sees it)   c) Always turn back
   Recommendation: b, because it uses team-visible information and avoids losing the base to a counter-raid. Why it matters: decides how bots handle base trades.

Q8. What should M8's test for "bots attack on every map" check?
   a) In every bot-vs-bot sweep row, both seats damage an enemy building before a set tick   b) The bot beats a passive player on every map in both slots   c) Both a and b
   Recommendation: c, because the converted-maps run showed waves can launch without ever landing a hit. Why it matters: it is the M8 exit evidence for Ashfall.

Q9. What should happen to the red `Fm1` test (FRC bot match no longer ends inside 45,000 ticks)?
   a) Pin the current result (no winner at the cap) and its digest until M8 retunes the bots   b) Raise its cap to about 80,000 ticks so the FRC win at 73,560 is pinned (longer suite)   c) Change the pairing so it ends inside the cap   d) Leave it red until M8
   Recommendation: a, because the cause is economic, not a bug, M8 will change the bots anyway, and the suite stays fast. Why it matters: the suite cannot show a green marker while it is red. ZH has no time limit (GameInfo.h:200-203), so ZH gives no default here.

Q10. Should Wargrid matches ever end on a timer?
   a) No time limit; the match runs until one team is defeated — ZH default (no limit found, GameInfo.h:200-203)   b) A lobby option for a time limit   c) A draw when no team has income or units that can attack for a long time
   Recommendation: a, because ZH has none and bots never give up (decided); revisit if 3v3 games stall. Why it matters: the 45,000-tick test caps are test limits only, not game rules.
