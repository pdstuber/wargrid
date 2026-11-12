# Playtest findings: idle repair by builders, and bot supply economy
## Findings (short, cited)
ZH root: ~/projects/CnC_Generals_Zero_Hour/GeneralsMD/Code/GameEngine/Source (shortened "ZH/" below). Retail INI decoded into ~/projects/wargrid-overnight-work/ini/ (from INIZH.big).

A) Idle repair
- **source** Dozers repair damaged own structures by themselves when idle: after BoredTime of idle with no pending task, the dozer picks the closest own STRUCTURE in BoredRange that is repairable and issues `aiRepair` (ZH/GameLogic/Object/Update/AIUpdate/DozerAIUpdate.cpp:1111-1128, finder at :868-926). It never takes enemy buildings (canRepairObject rejects ENEMIES; neutral allowed), full-health ones, ones under construction, bridges, rebuild holes (ZH/Common/RTS/ActionManager.cpp:383-433).
- **source** If nothing to repair, it hunts enemy/neutral mines instead (DozerAIUpdate.cpp:1134-1141, findMine :932-953). Mine clearing is only allowed while not on a job (:779, :786).
- **source** GLA worker uses the same state machine (WorkerAIUpdate.cpp:196 creates a DozerPrimaryStateMachine, :304 updates it), so it auto-repairs and clears mines the same way.
- **source** Retail values, identical for all three: `RepairHealthPercentPerSecond = 2%`, `BoredTime = 5000` ms (~5 s), `BoredRange = 150` (americavehicle.ini:1739-1741 AmericaVehicleDozer; chinavehicle.ini:2231-2233 ChinaVehicleDozer; glainfantry.ini:3757-3759 GLAInfantryWorker; in the decoded copies under ini/). 2% per second = full repair of an empty building in 50 s per builder.
- **source** AI-controlled dozers scan twice as far: `AIDozerBoredRadiusModifier = 2.0` (aidata.ini:60, used at DozerAIUpdate.cpp:2333). Humans: 150.
- **source** Repair rate actually applied per tick: max health * RepairHealthPercentPerSecond (DozerAIUpdate.cpp:719). Several dozers may repair the same building and stack (comment :725-727).
- **source** Wargrid today: no repair order and no repair code at all (`rg -n -i repair game/scripts` returns nothing). Blueprint lists "repair" only as a scope word (docs/blueprint.md:28). So the friend's observation is correct: builders sit idle next to damaged buildings.
- **inferred** The friend most likely saw idle ZH-style behaviour missing, not a bug in an existing feature.

B) Bot supply economy
- **source** Where the bot builds the supply center: `Skirmish._build` walks `build_order(faction)` and takes the first kind not yet owned; the site is the map's fixed slot `MapData.slot(map, player, kind)` (game/scripts/simulation/skirmish.gd:104-113, game/scripts/simulation/map_data.gd:21-24). It never looks at sources.
- **source** Slots come from tools/zh_map/convert.py: `_find_slot` scans rings of growing distance (2..12 cells) around the start cell in order power_plant, supply_center, barracks, factory, command_center, defence (convert.py:32-39, :268-285, :315-320). supply_center is the 2nd slot, 3x3, so it lands at about 2-3 cells from the start; sources are only used to mark taken cells, plus a check that some source is within 20 cells (SUPPLY_REACH, convert.py:322). The slot choice does not aim at supplies.
- **source** Collector count: USA supply center row has `spawns_on_complete: [usa_collector]` (game/scripts/simulation/definitions/usa.gd:14) and `units_for` has no entry for `usa_supply_center` (factions.gd:12), so `unit_for` returns "" and `_produce` skips it (skirmish.gd:131-139). Only a faction whose start unit collects (FRC) gets LABORERS = 7 (skirmish.gd:15-17, :119-125). So a USA or China bot has exactly 1 collector for the whole game. Matches the playtest.
- **source** Measured (cells, distance from 3x3 supply_center slot centre to nearest source centre; script output in ~/projects/wargrid-overnight-work/supply_distance.txt):
  - dry_wells: seat 1 nearest 25.6 (but that is a 50-box pile; nearest 400-box dock 28.3); seat 2 nearest 19.5 (400 boxes). Seat 1 has no source within 20, none within 25 that is a full dock.
  - broken_crown: 22.4, 18.1, 15.9, 19.8 (all 400 boxes).
  - ashfall: 21.5, 22.4, 25.1, 18.0, 20.4, 21.1, 23.7, 26.5 (all 400 boxes).
  - Every start is 16-27 cells from supplies; none is within 10. So "very far" is real on all three maps, worst on Dry Wells seat 1 and ashfall seat 8. A USA Chinook flies 8 boxes per trip over 20+ cells.
- **source** ZH skirmish AI: the first supply center is in the map's build list (map-authored position, not AI-chosen). Later ones use `AIPlayer::buildBySupplies` -> `findSupplyCenter`: richest warehouse not already covered by own center within 20 cells, not closer to the enemy than 60/40, nearest to base; site is the warehouse position pulled 3 cells back toward base, then wiggled to a legal spot (ZH/GameLogic/AI/AIPlayer.cpp:1849-1960, :2180-2250; SUPPLY_CENTER_CLOSE_DIST = 20 cells, :71). In ZH the depot sits at the supply, within a few cells.
- **source** ZH gatherers: `checkForSupplyCenter` sets desired gatherers = SideInfo value + 1 ("freebie", AIPlayer.cpp:190-215). aidata.ini ResourceGatherersEasy/Normal/Hard are identical per side: America 2 (:68-70), China 2 (:96-98), GLA 5 (:123-125), generals variants 2 or 5. Not difficulty dependent.
- **inferred** ZH's "+1 freebie" is the truck the depot spawns for free, so USA and China bots in ZH end with about 3 collectors per depot, GLA about 6, versus Wargrid USA/China bot 1.
- **inferred** Fix type: both. Slot position is map data (start-cell-relative, 2-3 cells from builder, but supplies 16-27 cells away), so moving the slot needs a convert.py change plus regenerating three JSON maps. The one-collector problem is a bot rule (skirmish.gd `_produce`), independent of maps.
- **inferred** Smallest fixes. (1) Collectors: let `unit_for` return the faction collector for supply centers, capped at a per-faction count (2 for USA/China per aidata), about 3 lines in `_produce`. (2) Placement: in `_build`, when kind == supply_center, pick the legal 3x3 site nearest to the closest source instead of the fixed slot (needs a legality query; not verified that the sim exposes one), or in convert.py pick the supply_center slot as the open site minimizing distance to the nearest source within MAX_RING 12 (map data fix, no bot code change). Neither verified by running.

## Questions
Q1. Should idle builders (dozers, workers) repair damaged own buildings by themselves?
   a) Yes: after 5 s idle, repair the nearest damaged own building within 150 — ZH default (DozerAIUpdate.cpp:1111-1128, retail INI BoredTime 5000, BoredRange 150)   b) No auto repair; only on player order   c) Yes, but only when the player turns an "auto repair" toggle on
   Recommendation: a, because it is the ZH behaviour and the friend noticed it missing. Why it matters: decides whether damaged bases heal without micro.

Q2. Should the player also be able to order a builder to repair a specific building?
   a) Yes: right-click a damaged own building with the builder selected — ZH default (ActionManager.cpp:383-433)   b) No manual order; auto only
   Recommendation: a, because ZH has both and the order is cheap once repair exists. Why it matters: the order is the only way to repair fast under attack.

Q3. How fast should a builder repair?
   a) 2% of max health per second per builder — ZH default (retail INI RepairHealthPercentPerSecond = 2%, identical USA/China/GLA)   b) Faster, 4% per second   c) Slower, 1% per second
   Recommendation: a, because it is the retail value. Why it matters: sets how worth repairing is compared to rebuilding.

Q4. Can several builders repair the same building together?
   a) Yes, rates add up — ZH default (DozerAIUpdate.cpp:725-727)   b) No, one builder per building
   Recommendation: a, because it matches ZH and makes mass builders useful. Why it matters: ties into whether builders are worth multiple copies.

Q5. Should repair cost credits?
   a) Free — ZH default (DozerAIUpdate.cpp:719 applies health only, no cost; inferred, no money call found in that block)   b) Costs a share of the building price proportional to health restored
   Recommendation: a, because it is the ZH behaviour. Why it matters: free repair removes a credit sink in long fights.

Q6. How far should the idle scan reach, for a human player's builders versus bot builders?
   a) Human 150 world units, bots twice that (300) — ZH default (INI BoredRange 150, aidata.ini:60 AIDozerBoredRadiusModifier 2.0)   b) Same range for both
   Recommendation: a for ZH feel, b for fairness; pick a. Why it matters: bots keep their bases repaired better than humans otherwise.

Q7. How many supply collectors should a USA or China skirmish bot run?
   a) 2 per supply center, plus the free one from the depot (about 3) — ZH default (aidata.ini:68-70, 96-98; AIPlayer.cpp:190-215)   b) 2 total   c) Keep 1 (today)
   Recommendation: a, because it is the ZH value and the playtest shows 1 starves the bot. Why it matters: decides how strong bot economy is on every map.

Q8. For a GLA-like faction whose start unit also collects, how many gatherers should the bot run?
   a) 5 plus one free — ZH default (aidata.ini:123-125, GLA 5)   b) Keep 6 (today: 1 builder plus 6, skirmish.gd:15-17, FRC)   c) Same as USA/China
   Recommendation: b, because the FRC number was set by the user on 2026-11-07 and is already about ZH GLA. Why it matters: avoids reopening a decided number; asked only to confirm the FRC case stays separate.

Q9. Should collector counts depend on difficulty?
   a) No, same for Easy/Normal/Hard — ZH default (aidata.ini: Easy = Normal = Hard in every SideInfo)   b) Yes, fewer on Easy
   Recommendation: a, because ZH does not vary it; difficulty comes from other settings. Why it matters: keeps the bot rule one number per faction.

Q10. Where should the bot build its supply center?
   a) Next to the nearest supplies, pulled slightly back toward the base — ZH default for expansions (AIPlayer.cpp:1849-1960)   b) At the fixed slot near the start, as today (16-27 cells from supplies on all three maps)   c) Fixed slot, but chosen at map conversion to be the open spot nearest the supplies
   Recommendation: c, because it fixes the playtest with no bot code and keeps determinism. Why it matters: a far depot makes every trip 2-3 times longer.

Q11. For the first supply center, should the bot treat it like a player does (pick a spot near supplies) or use the map's authored position?
   a) Map-authored build list position — ZH default (map build lists, AIPlayer.cpp:148)   b) Bot chooses near supplies   c) Same as Q10 answer
   Recommendation: c, because one rule is simpler. Why it matters: ZH relies on map authors placing the first depot well; our converted maps do not.

Q12. If the supply center slot moves closer to supplies, may it also be further from the start builder?
   a) Yes, up to about 12 cells (convert.py MAX_RING = 12)   b) No: keep within 5 cells of the start so the depot stays inside the base
   Recommendation: a, because supplies are 16-27 cells out and a 5-cell limit cannot help. Why it matters: bigger distance means a depot outside the base defence.

Q13. Should the bot rebuild or add a second depot near other supplies later (expansion), as ZH does?
   a) Yes, once rich supplies are free and not closer to the enemy (60/40 rule) — ZH default (AIPlayer.cpp:2180-2250)   b) No, one depot only (today)
   Recommendation: b for now, because it is a separate feature; ask later. Why it matters: bots never expand without it, long games stall on 400-box docks.

Q14. Should a friend-visible hint show an idle builder with nothing to repair (for example a status line "idle")?
   a) No, ZH has none   b) Yes, small idle marker
   Recommendation: a, because ZH has none. Why it matters: avoids scope creep in the HUD.
