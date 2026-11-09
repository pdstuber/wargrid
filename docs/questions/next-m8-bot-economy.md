# Next: bot economy choices (M8): where to put supply centers, how many collectors

Sources. **ZH src** = ~/projects/CnC_Generals_Zero_Hour @ 0a05454, paths under `GeneralsMD/Code/GameEngine/Source/`. **INI** = retail root `INIZH.big` decoded into the session scratchpad, cited as archive entry:line. Scale: 150 ZH units is about 6 Wargrid cells (design-answers 2026-11-08 repair), so about 25 units per cell (inferred). Already decided, not asked: M8 replaces the converter's supply-center slot with the bot choosing the site itself as ZH `buildBySupplies`/`findSupplyCenter`; collector counts USA 2, China 3, FRC 5 are a stopgap, stronger levels should make increasingly optimal economic choices (blueprint §7 M8; design-answers 2026-11-08). Not repeated: expansion to a second depot (`playtest-repair-bots.md` Q13, no recorded answer).

## Findings (short, cited)
- **source** Pile choice: the closest supply source to the bot's base that holds at least `minimumCash`; if none, halve the minimum and retry while above 100 (ZH src GameLogic/AI/AIPlayer.cpp:2180-2253). The USA build script asks for 10,000 (wargrid `docs/reference/m7-verification-archive-research.md:141`). A box is worth 75 (`data\ini\gamedata.ini:248`).
- **inferred** A Wargrid small pile (50 boxes, small piles design) is worth 3,750, so ZH's rule ignores it until no pile with 10,000 or 5,000 is left.
- **source** A pile is skipped if the bot already has a supply center within 20 pathfind cells (200 units, about 8 Wargrid cells) of it (AIPlayer.cpp:71, 2208-2223), or if it is too close to the enemy: skipped when 0.4 x (distance to own base)² > 0.6 x (distance to enemy base centre)², i.e. own distance more than about 1.22 x the enemy's (AIPlayer.cpp:2229-2236). The enemy base centre is the box around all enemy structures (AIPlayer.cpp:2187-2192); **inferred** ZH reads it without fog.
- **source** Placement: start 3 pathfind cells (30 units, about 1.2 Wargrid cells) from the pile's centre towards the own base, then try spots in a growing square up to 200 units (about 8 Wargrid cells) out (AIPlayer.cpp:1864-1882, 1905-1925). Not closer than 20 units to a pile (`SupplyBuildBorder`, gamedata.ini:252).
- **source** Defensive buildings ordered "by supplies" go next to the current pile, offset towards the enemy (AIPlayer.cpp:1853-1882).
- **source** Safety check: a site counts as unsafe if any enemy except harvesters, dozers and undetected stealth units is within 300 units (about 12 cells) (`SupplyCenterSafeRadius`, `data\ini\default\aidata.ini:57`; AIPlayer.cpp:997-1040). **inferred** no fog check in that scan.
- **source** Supply guard: when collectors, dozers or the supply center were hit recently, a script can send a team to guard the pile, placed between it and the enemy (AIPlayer.cpp:891-984).
- **source** ZH skirmish gatherers per side are 2 for America at every level (`data\ini\default\aidata.ini` SideInfo America `ResourceGatherers*`), so ZH has no "optimal count" logic to copy.

## Questions
Q1. Which supply pile should the bot build its supply center at?
   a) The closest pile to its base with at least 10,000 left, lowering the bar if none is left — ZH default (AIPlayer.cpp:2180-2253)   b) The richest pile within a set distance   c) The nearest full dock (today's converter stopgap)
   Recommendation: a, because it is the decided starting point and handles running-dry piles. Why it matters: the first depot site sets the whole economy's speed.

Q2. Should the bot skip a pile that lies closer to the enemy than to itself?
   a) Yes, skip it when its own distance is more than about 1.22 x the enemy's — ZH default (AIPlayer.cpp:2229-2236)   b) Skip anything closer to the enemy than to itself (1.0 x)   c) No check; defend it instead
   Recommendation: a, but measured to the enemy buildings the team has seen, because ZH reads hidden enemy positions and Wargrid bots may not. Why it matters: decides how greedy bots expand.

Q3. How far apart must two of the bot's supply centers be?
   a) No second supply center within about 8 cells of a pile it already serves — ZH default (AIPlayer.cpp:71, 2208-2223)   b) Never two on the same pile cluster   c) No limit
   Recommendation: a, because it is ZH and stops stacking depots on one pile. Why it matters: only matters once the bot builds a second depot.

Q4. Where exactly next to the pile should the supply center go?
   a) About 1 cell from the pile towards the own base, then the nearest legal spot in a growing square — ZH default (AIPlayer.cpp:1864-1882, 1905-1925)   b) The legal spot closest to the pile's dock in any direction   c) Towards the own base but always leaving a free lane for collectors
   Recommendation: c, because Wargrid has dock arrival points and the avoidance milestone makes blocked lanes costly; start from a's search. Why it matters: a badly placed depot slows every collector trip.

Q5. Should the bot use small piles?
   a) Only after no bigger pile is left (they fall under the 10,000 bar) — ZH default (AIPlayer.cpp:2202-2203, 2249; inferred for 50-box piles)   b) Never   c) Yes, when one is closer than any big pile
   Recommendation: a, because it falls out of Q1's rule with no extra code. Why it matters: Dry Wells has 12 small piles.

Q6. Before building at a pile, should the bot check that no enemy is near?
   a) Yes, no enemy (except collectors and builders) within about 12 cells — ZH default (aidata.ini:57, AIPlayer.cpp:997-1040)   b) No check   c) Check, and send an escort if unsafe
   Recommendation: a, counting only enemies its team can see (ZH's scan ignores fog). Why it matters: stops bots dropping depots into enemy armies.

Q7. Should the bot defend its supply pile when its collectors are attacked?
   a) Yes, send a guard team between the pile and the enemy — ZH script option (AIPlayer.cpp:891-984)   b) Only rebuild lost collectors   c) Only at higher levels
   Recommendation: c, because defending the economy is a competence the levels can remove. Why it matters: raids on collectors are a common human tactic.

Q8. Should the bot put a defence at its supply pile, facing the enemy?
   a) Yes, defences built "by supplies" go next to the pile, offset towards the enemy — ZH default (AIPlayer.cpp:1853-1882)   b) Only at the main base   c) Depends on the play style (defensive builds them)
   Recommendation: c, because the defensive style needs visible differences. Why it matters: affects how hard bot economies are to raid.

Q9. How should the M8 bot decide how many collectors to run per supply center?
   a) Fixed per faction (today: USA 2, China 3, FRC 5); ZH uses a fixed 2 for America at every level (aidata.ini SideInfo)   b) Worked out from pile distance and collector speed until the dock is busy all the time   c) Fixed at low levels, worked out at high levels
   Recommendation: c, because "stronger levels make increasingly optimal economic choices" is already decided. Why it matters: the economy is the largest strength lever.
