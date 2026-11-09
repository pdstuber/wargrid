# Building placement in Zero Hour vs Wargrid (friend's playtest)

All ZH paths are under ~/projects/CnC_Generals_Zero_Hour/GeneralsMD/Code/ @ 0a05454. Wargrid paths under ~/projects/wargrid.

## Findings (short, cited)

Placement flow (source)
- Ghost/click check: `isLocationLegalToBuild` with TERRAIN_RESTRICTIONS | CLEAR_PATH | NO_OBJECT_OVERLAP | SHROUD_REVEALED | IGNORE_STEALTHED (GameEngine/Source/GameClient/InGameUI.cpp:1478-1486; MessageStream/PlaceEventTranslator.cpp:120-126, 225-235).
- On the command, `buildObjectNow` runs: clear props/trees (`clearRemovableForConstruction`), then `moveObjectsForConstruction`, then the dozer/worker `construct`, which re-validates with the same four flags and withdraws money (Common/System/BuildAssistant.cpp:358-377; GameLogic/Object/Update/AIUpdate/DozerAIUpdate.cpp:1676-1684, WorkerAIUpdate.cpp:381-388). Money is paid and the foundation exists at placement time, not on dozer arrival. (m7-placement-rules.md rule 11 says the re-check uses "only SHROUD_REVEALED" - the source shows all four flags; doc looks wrong, inferred from the cited lines.)

1. Own units in the footprint (source)
- Friendly units are NOT a blocker: header comment "Friendly objects should politely move out of the way when you build something where they're standing" (BuildAssistant.cpp:940-945).
- Who moves: every non-mine, non-inert, non-removable object in the footprint whose owner is NEUTRAL or ALLIES (teammates included, not only own) and that has an AI. Each gets one `aiMoveToPositionEvenIfSleeping` order to a random point: random direction, distance random 0.5-1.5 x (box half-diagonal x 1.4) from the building centre (BuildAssistant.cpp:1416-1480). No clear-area step, no pathing check, no return to old orders.
- Exceptions that block placement (source, BuildAssistant.cpp:690-760): allied unit that is using an ability or `isBusy()` (patch 1.01 anti-exploit, e.g. Black Lotus hacking); a disabled object (cannot move); any KINDOF_IMMOBILE object of any owner (all structures).
- Enemy units: any enemy object in the footprint gives LBC_OBJECTS_IN_THE_WAY (BuildAssistant.cpp:758-767). Human placement also fails in `buildObjectNow` if any enemy/unmovable remains; AI players ignore that and build anyway (BuildAssistant.cpp:360-367).
- Stealthed enemy not detected: ignored by the ghost check (IGNORE_STEALTHED), but `moveObjectsForConstruction` still counts it as enemy-unmovable, so the order is dropped silently (inferred from :1448-1478 + :360-367; not run).
- Mines, inert things and removable props (shrubbery, KINDOF_CLEARED_BY_BUILD = civilian props, dead objects) never block; props are destroyed (BuildAssistant.cpp:716-726, 1355-1383, 1389-1408; civilianprop.ini carries CLEARED_BY_BUILD).

2. Restrictions (source unless noted)
- No "build near own buildings" radius exists. `isLocationLegalToBuild` has no ownership/proximity test, ThingTemplate INI has no field for it (field list ThingTemplate.cpp:124-157; INI scan of all of INIZH.big finds no build-radius key). Not found anywhere in the engine.
- No per-faction rule and no defence-specific rule: missile tower/Patriot/gattling/stinger site/tunnel have no placement KINDOF. The only per-object rules are KINDOF_CANNOT_BUILD_NEAR_SUPPLIES (supply centers of all three factions, gap `SupplyBuildBorder = 20` units, BuildAssistant.cpp:968-996; GameData.ini:252; factionbuilding.ini:18740,21247 + GLA stash) and a factory exit lane / tunnel extra bib (m7-placement-rules.md rows 4-5).
- Map edge: `MinDistFromEdgeOfMapForBuild = 30` (GameData.ini:251; BuildAssistant.cpp:536-541). Terrain: flat enough (`AllowedHeightVariationForBuilding = 10`, GameData.ini:256), no water/cliff, not on a bridge (BuildAssistant.cpp:1017-1062).
- Shroud: the centre cell must be CELLSHROUD_CLEAR for the player, the FIRST check (so error codes cannot leak hidden info) (BuildAssistant.cpp:922-940). CLEAR = a player is actively looking now; "explored but nobody looking" is CELLSHROUD_FOGGED and fails (PartitionManager.cpp:1388-1391). So in ZH you cannot place into grey fog, only into currently visible ground. Only the centre cell is tested, not the footprint.
- Builder must be able to path there (CLEAR_PATH, `isQuickPathAvailable`), skipped for immobile builders (BuildAssistant.cpp:997-1014). Distance from the dozer is unlimited; it walks.
- Feedback: per-reason message (GUI:CantBuildObjectsInTheWay, ...Shroud, ...TooCloseToSupplies, ...NoClearPath, ...NotFlatEnough; InGameUI.cpp:4020-4060), red ghost tint, and `addFactionBib` draws a red bib on the blocking object (InGameUI.cpp:1478-1500; BuildAssistant.cpp:735).

3. Wargrid today (source)
- `Construction.footprint_error` (game/scripts/simulation/construction.gd:28-38): rejects non-walkable cells (buildings, piles, water), and ANY ground unit's cell or destination cell on the footprint, any owner, no push-away: "Footprint covers ground unit or destination" (`Simulation._unavailable_cells`, game/scripts/simulation/simulation.gd:317-330; air and container-riders ignored). Then edge margin 1 cell, then supply gap 1 cell on depots.
- No build radius, no fog (no simulation fog yet; M7.9 planned, ZH model decided: docs/reference/design-answers-2026-11-08.md fog section), no faction or defence rule, no exit lane, no tunnel margin.
- `preview` also needs a reachable perimeter cell for the builder ("No reachable builder approach", construction.gd:80-93); money is taken at `place` (construction.gd:99-111) like ZH.
- Known pain: the FRC bot was blocked every decision by its own idle infantry (docs/reference/m7-verification-archive-gate3.md:37); the friend hit the same thing as a human. Existing note: rule 3 "Keep stricter unit rule unless the user wants ZH push-away (needs a sim command to move friendlies)" - noted, never decided as a question (docs/reference/m7-placement-rules.md:25, 47).
- Friend's claims (docs/reference/design-answers-2026-11-08.md:92): units should move away - TRUE in ZH. "Defences cannot be built anywhere" - not found in ZH; the only global limit is visibility, which Wargrid lacks until M7.9.

## Questions

Q1. A building is placed on ground where your own units stand: what happens?
   a) Units walk away and the building is placed — ZH default (BuildAssistant.cpp:940-945, 1416-1480)   b) Placement is refused with a message (Wargrid today, construction.gd:33)   c) Placement is refused but idle units auto-clear and the player can retry
   Recommendation: a, because it is what the friend expects and what removes the bot-blocked-by-own-units bug. Why it matters: needs a new "move away" simulation command and a trace re-pin.

Q2. Which units get pushed off the footprint?
   a) Own and teammates' units — ZH default (BuildAssistant.cpp:1448-1451, ALLIES or NEUTRAL)   b) Only your own units   c) Only idle units, units with orders stay and block
   Recommendation: b, because a teammate's order being overwritten by you is hostile and 3v3 is the long-term target. Why it matters: ZH overwrites teammates' orders.

Q3. Where do pushed units go?
   a) One random spot 0.5 to 1.5 building-radii from the centre, no pathing check — ZH default (BuildAssistant.cpp:1455-1472)   b) The nearest free cell outside the footprint   c) The nearest free cell, and then they return to their old position
   Recommendation: b, because ZH's random spot can land inside another building and needs the deterministic tie-breaks we use elsewhere anyway. Why it matters: the sim must stay deterministic and no unit may be sent into a wall.

Q4. Units that are busy or disabled (hacking, using an ability, frozen) stand in the footprint: what happens?
   a) They block placement; only non-busy units are pushed — ZH default (BuildAssistant.cpp:696-703, 753-761)   b) They are pushed anyway   c) Nothing special: no such units yet
   Recommendation: c now, a when abilities arrive, because Wargrid has no hack or ability units today. Why it matters: stops a player cancelling a channel by placing a building.

Q5. An enemy unit stands in the footprint: what happens?
   a) Placement is refused, the enemy unit is highlighted — ZH default (BuildAssistant.cpp:758-767)   b) Placement is allowed and the enemy unit is pushed too   c) Placement is allowed and the enemy unit is crushed
   Recommendation: a, because b and c let you grief an enemy standing at a choke point. Why it matters: it decides if units can be used to body-block enemy building.

Q6. Can you build only near your own buildings (a build radius)?
   a) No limit, anywhere your builder can walk and see — ZH default (no such check in BuildAssistant.cpp:908-1068; none in the INI)   b) Within N cells of any own building   c) Within N cells of the builder's own base centre only
   Recommendation: a, because that is ZH and it keeps forward bases and tunnel plays possible. Why it matters: this is the friend's "restrictions" question; it is the core feel of expanding.

Q7. Should defences (Patriot, missile tower, gattling, stinger site, tunnel) have their own placement limit?
   a) No, same rules as all buildings — ZH default (no defence KINDOF or INI field, see Findings 2)   b) Defences only within N cells of an own building   c) Defences only inside the area of an own power or command building
   Recommendation: a, because ZH has no such rule and the friend's memory was probably of the fog limit or of base-adjacent AI placement. Why it matters: forward defences and tower rushes are part of ZH play.

Q8. Does any faction get its own placement rule?
   a) No, one rule set for USA, China and FRC (GLA) — ZH default (nothing faction-specific in BuildAssistant.cpp)   b) FRC tunnel hub gets an extra one-cell margin around it   c) FRC buildings must be near a tunnel hub
   Recommendation: a for now, because capability differences are data (AGENTS.md) and the extra bib on tunnels is a minor row key. Why it matters: decides whether placement needs per-faction data rows.

Q9. Once fog exists (M7.9): where may a building be placed?
   a) Only on ground you can see right now — ZH default (BuildAssistant.cpp:925-939; PartitionManager.cpp:1388-1391)   b) Anywhere already explored, including grey fog   c) Anywhere, shroud and fog ignored
   Recommendation: a, because that is ZH and it is the cheapest fair rule for the bots too. Why it matters: it defines how far from your base you can expand blind, and it is a first check in the sim.

Q10. Is the shroud test done on the building's centre only or on all footprint cells?
   a) Centre cell only — ZH default (BuildAssistant.cpp:927-936)   b) All footprint cells must be visible
   Recommendation: b, because Wargrid footprints are small cells and a centre-only test can place a big building half in the shroud. Why it matters: small, but it is a determinism and exploit detail for the M7.9 design.

Q11. How is a refused placement explained to the player?
   a) Red ghost, a text reason, and the blocking object highlighted — ZH default (InGameUI.cpp:1478-1500, 4020-4060; BuildAssistant.cpp:735)   b) Red ghost and text reason only (Wargrid today)   c) Red ghost only
   Recommendation: a, because the friend asked why placement fails. Why it matters: cheap HUD work that cuts most "why can't I build" confusion.

Q12. Factory exit lane: must a factory keep one free cell in front of its exit?
   a) Yes, 1 cell clear in front of Command Center, Barracks, War Factory, Airfield, Arms Dealer — ZH default (factionbuilding.ini exit width 25; BuildAssistant.cpp:775-900)   b) No, units spawn on any free cell (Wargrid today)
   Recommendation: b, because Wargrid finds exit cells dynamically; the lane only prevents walled-in factories. Why it matters: affects walling/blocking tactics. (Listed as open in m7-placement-rules.md; not yet asked.)

Q13. The builder cannot find a path to the site (walled in, island): what happens?
   a) Placement refused ("no clear path") — ZH default (BuildAssistant.cpp:997-1014)   b) Placement allowed, builder waits   c) Placement allowed and the foundation is dropped when the builder gives up
   Recommendation: a, because it matches Wargrid's "No reachable builder approach" today. Why it matters: confirms a rule that already exists, no work.
