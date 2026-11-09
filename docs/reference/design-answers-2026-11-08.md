# Design answers, 2026-11-08 (user wizard)

The user answered these one by one on 2026-11-08 after research agents looked up the Zero Hour behaviour for each (sources: ZH source @ 0a05454 and the retail `INIZH.big`, cited per line; the research files stayed outside the repo in `~/projects/wargrid-overnight-work/questions/`). They are user decisions and inputs for the named milestones' planning, not designs: each milestone still gets its own design and plan. "Zero Hour default" means the user picked Zero Hour's behaviour.


## Overnight run

- Night pings: none; questions collected for the morning summary.
- Coordinator: Sonnet; plans and reviews on Opus subagents.
- Morning summary: final message plus ~/projects/wargrid-overnight-work/morning-summary.md, every commit listed.
- Spare time after both work items: more research on the next open design points, adding questions; no decisions.
- Converted maps design: open points approved as proposed (map dropdown, Credits button and panel, joiner refusal wording, --map for headless_client).
- Unattended rules: exceeded budgets on the new maps recorded and continue; bots that never attack or collect: smallest fix inside existing bot code, else finding.

## Fog of war (M7.9)

All Zero Hour defaults.

- ~~Map starts black (shroud) until explored (PartitionManager.cpp:1243).~~ Superseded (user, 2026-11-09): follow retail Zero Hour multiplayer, where the map is revealed at the start (`data\ini\multiplayer.ini:38 UseShroud = No` in root `INIZH.big`; `GameLogic.cpp:1752-1753` calls `revealMapForPlayer` when shroud is off in multiplayer). Enemy units and bases still hidden by fog until seen: from the research note `questions/next-m79-fog.md` (`PartitionManager.cpp:2972-2981`), not re-checked.
- Explored areas nobody looks at turn grey (fogged) and hide enemy units (PartitionManager.cpp:1382-1391, 1672-1675).
- Enemy buildings already seen stay shown in their last seen state while fogged; mines stay hidden (PartitionManager.cpp:1672-1677).
- A building under construction reveals nothing (Object.cpp:4842).
- Teammates share vision (ZH: PartitionManager.cpp:3965 "Look/Unlook are the ones sending Ally info").

Follow-up answers (user, 2026-11-09; questions and sources in the overnight `questions/next-m79-fog.md`, not re-checked unless noted):
- An area turns grey 5 s after the last viewer leaves (`data\ini\gamedata.ini:442 UnlookPersistDuration = 5000`).
- Vision is a plain circle; hills and cliffs do not block it (PartitionManager.cpp:3969-3990).
- Direct-fire units need a clear line over terrain and obstacles to auto-target; artillery does not (`data\ini\default\aidata.ini:31 AttackUsesLineOfSight = Yes`, AIUpdate.cpp:4612-4616, PartitionManager.cpp:4496-4566). This changes M6's "elevation affects passability only"; it lands in ground batch A with artillery.
- Explicit attack orders work on remembered buildings in the fog and on ground; only automatic targeting needs vision (WeaponSet.cpp:531-542, AIUpdate.cpp:4634-4641).
- A supply pile in the fog shows its last-seen amount (frozen picture as for fogged immobile objects, PartitionManager.cpp:1665-1684; inferred for piles).
- Firing does not reveal a fogged shooter (no such rule found; only superweapons reveal to all, Object.cpp:5005-5014).

## HUD (M7.6)

Zero Hour defaults.

- Production queue holds 9 entries per building (ProductionUpdate.cpp:109).
- Minimap flashes where an off-screen unit is attacked (Radar.cpp:1171-1185), in addition to the existing announcer line.

Follow-up answers (user, 2026-11-09; [next-m76-hud.md](../questions/next-m76-hud.md)):
- Every building can be sold (`data\ini\commandset.ini:770`), for 50 % of its cost (`gamedata.ini:390`).
- Selling takes 3 s while the building un-builds and can still be destroyed (BuildAssistant.cpp:177, 1499-1603); a "being sold" state blocks production and repair.
- Health bars show for selected or damaged objects (Wargrid today, not Zero Hour's selected or hovered).
- Veterancy chevrons show above every unit with a level, enemies included (Drawable.cpp:2807, 3797-3815; enemies inferred); bots may treat enemy veterancy as public information.
- No selection limit (`data\ini\ingameui.ini:7`).
- A Guard order: attack inside 1.8 x vision, chase to 2.2 x vision for up to 10 s, then return (`data\ini\default\aidata.ini:18-20`).
- Map pings for teammates without text (against Zero Hour's 3 text beacons per player, `multiplayer.ini:37`); how many at once is not decided.

## Unit avoidance: scope

- Re-pin every trace and pinned test once, at the end; no switch to turn avoidance off.
- Extra simulation cost on the 300-unit benchmark: about 0.5 ms per tick at most (half of today's headroom under the 1.82 ms budget).
- Experiments: the benchmark layouts (dense walls with gaps, docks) first, then Dry Wells.
- First version covers moving units only; arrival spreading keeps today's reserved destination cells.

## Avoidance spike (night of 2026-11-08)

- Two approaches prototyped side by side (e.g. cell-based queue/nudge and the closest to Zero Hour's way).
- A few screenshots per approach (chokepoint, dock), linked from the morning summary.
- Cost also measured in the browser build (web bench export, tools/serve_web_bench.py).

## Bots (M8.1)

- Three selectable play styles besides "random": aggressive, economic, defensive.

## Veterancy (ground batch A)

All Zero Hour defaults, checked in the retail `gamedata.ini` and `default\object.ini`.

- Four levels: Regular, Veteran, Elite, Heroic (GameCommon.h:206-218).
- XP only from kills, per unit type (ExperienceValue / ExperienceRequired in the object INI; Object.cpp:2940-2965).
- Bonuses: damage 110/120/130 %, rate of fire 120/140/160 %, max health 120/130/150 % (gamedata.ini:333-338, 352-354); current health keeps its ratio.
- Elite and Heroic self-heal 10 HP per 1000 ms, starting 5000 ms after the last hit (default\object.ini:101-106).

## Ground batch A systems (user, 2026-11-09)

Questions and sources: [next-batch-a.md](../questions/next-batch-a.md).

- Researched upgrades stay when the building that researched them is destroyed (Zero Hour default).
- Add-ons die with their vehicle (Zero Hour default).
- Prerequisites are checked only at queueing: queued units finish after the prerequisite is lost, new orders are refused until it is rebuilt (Zero Hour default).
- A shell flies to where its target stood when it was fired; a fast unit can dodge (Zero Hour default).
- Tank shells hit structures and walls on the way (Zero Hour default).
- Tank shells scatter against infantry by Zero Hour's per-weapon radius (Crusader 10 units), using the simulation's seeded random (Zero Hour default).
- A unit ordered to attack inside its minimum range backs away until the target is past it, then fires (Zero Hour default).
- Poison and radiation fields hurt everything on the ground, own and allied units included, not aircraft (Zero Hour default).
- A small poison field lives a fixed 10 s; a new field cleans its spot first, so fields never stack (Zero Hour default; replaces the blueprint's "duration after the last hit").
- Hazard damage follows Zero Hour's armour table: tanks 25 % poison and 50 % radiation, trucks 50 % poison, buildings 1 % poison and 0 % radiation, Hazmat troops immune (Zero Hour default).
- The FRC Palace's garrison cannot be cleared by flame or toxin clear-building weapons (Zero Hour default).
- USA buildings self-heal 0.3 % of max health per second after 3 s without damage, not while under construction or being sold; other factions' buildings do not (Zero Hour default; capability data, not a faction branch).
- FRC rebuild holes (raised by the user): most FRC buildings leave a hole when destroyed (Zero Hour GLA: 500 HP, heals 0.5 % per second, `HoleMaxHealth` / `HoleHealthRegen%PerSecond` in retail `data\ini\object\factionbuilding.ini:143-144`, 11 `RebuildHoleExposeDie` buildings); after 20 s (`WorkerRespawnDelay`) a worker spawns and rebuilds the building unless the hole is destroyed; a killed worker or rebuild restarts the wait (`RebuildHoleBehavior.cpp:200-335`). Lands in batch A gate A4 (FRC), Zero Hour behaviour. Not verified: whether the rebuild costs money (`ai->construct(..., TRUE)`, :259).

## Minimap (M7.6)

- Free with the Command Center for all three factions for now (Zero Hour differs per faction: USA free, China $500 upgrade, GLA $500 radar van; revisit when those items exist).
- Goes blank at low power until power returns, with an "offline" voice line (ZH Player.cpp:3260-3272).
- Goes blank when the last radar provider is lost or captured; a second provider keeps it (ZH RadarUpgrade.cpp:72-120, Player.cpp:3160-3200).

## Bots (M8)

- Start from Zero Hour's behaviour (enemy choice AISkirmishPlayer.cpp:485-563, target scores AI.cpp:683-720, wave timing), then develop Wargrid's own, better rules: bot intelligence should be unique and really good at this game; moving far from Zero Hour parity is fine for bots. Sources the user collected: docs/reference/fair-bots-research.md.
- A losing bot never gives up; it rebuilds lost base buildings (ZH RebuildDelayTimeSeconds = 30).

## Unit avoidance: behaviour

Zero Hour defaults unless noted. Paths are under `GeneralsMD/Code/GameEngine/` (AIPathfind/AIUpdate/AIStates/AIGroup in `Source/GameLogic/AI/` or `Source/GameLogic/Object/Update/`).

- A standing friend on the route steps aside; busy units (shooting, building, using an ability) do not (AIPathfind.cpp:6306-6316, 10112-10187, 10166-10178).
- Head-on deadlock: the unit with lower right of way sidesteps a cell or two, then both continue (AIUpdate.cpp:1521-1535, AIPathfind.cpp:10195-10360).
- Right of way: dozers/builders over everyone, vehicles over infantry, then the unit in front, then a fixed tie-break (AIUpdate.cpp:1215-1253).
- Infantry pass through all infantry; only vehicles block them (AIPathfind.h:51, AIUpdate.cpp:1332-1338). Refines the 2026-11-07 "units go around each other": vehicles stay solid.
- Last resort: two vehicles still blocking each other pass through after about 5 s (ZH: crossing/opposite units after 1 s, AIUpdate.cpp:1355-1362; user chose 5 s so units mostly go around).
- Supply trucks on a supply run drive through all units, others yield to them, as Zero Hour (AIStates.cpp:6170, AIUpdate.cpp:1445). Supersedes "trucks included" of 2026-11-07.
- Tanks, trucks and dozers crush ordinary enemy infantry they drive over (not heroes, never allies), so those soldiers never block vehicles (SquishCollide.cpp:97-131; crusher levels in retail INI).
- Re-route: at once if the blocker stands still, otherwise after 2 s blocked (AIUpdate.cpp:1511-1519, AIStates.cpp:1821).
- Standing units are walls to enemies; enemies are never asked to step aside (AIPathfind.cpp:6265-6270, 10156).
- A unit that is shooting holds its spot; the friend goes around (AIPathfind.cpp:10166-10171).
- Factory exit: friends at the door step aside, but the new unit stays solid (ZH instead lets it drive through for up to 10 s, AIUpdate.cpp:1698-1708).
- Long group moves travel as a column on one shared route, infantry 3 wide and vehicles 2 wide, each unit at its own speed (AIGroup.cpp:528-638).
- A unit that stepped aside stays there; it does not walk back (inferred from AIStateMachine.h:185-186).
- A fast unit behind a slower friend slows and follows, then tries a way past after about 2 s (AIUpdate.cpp:1258-1292, AIStates.cpp:1821).
- "Keep formation" command (ZH Ctrl+F): later, with the M7.6 HUD, not in the avoidance milestone.
- Aircraft do not take part in avoidance; ground units only.

## Friend's playtest (reported by the user, 2026-11-08)

Reported points, verbatim in substance: units in a building's footprint should move away when it is placed (as the friend remembers Zero Hour); queue buildings with Shift, and which Zero Hour keys to support; a USA bot on Dry Wells built only one Chinook and put its supply depot far from the boxes; defences such as the missile tower can be built anywhere (the friend thinks Zero Hour restricts this, maybe per faction); no way out after "Create match"; do dozers and workers auto-repair structures; the match code should be copy/pastable; can the camera move without arrow keys.

- Launcher, tonight in the converted-maps task (user, 2026-11-08): a Cancel button while waiting for player 2 closes the connection and returns to the launcher; a Copy button next to the shown match code puts it on the clipboard (browser clipboard unverified until tested).
- Bot economy, tonight in the converted-maps task (user, 2026-11-08): collectors per supply center, counting the depot's free one, same at every difficulty: USA 2, China 3, FRC 5 (down from 7), as human players do (Zero Hour's skirmish AI uses 2 + 1 for America and China, aidata.ini ResourceGatherers, AIPlayer.cpp:190-215); per-collector inflow already differs by data (USA helicopter 8 boxes but slow unload, China truck 4 boxes at speed 1.6, FRC laborer 1 box at speed 1.0). Revisit in M8: stronger levels should make increasingly optimal economic decisions. Pins moved by this change may be re-pinned overnight, with old and new values recorded, in their own commit. The depot target ignores small piles and aims at the nearest full dock. The bot's supply-center slot is chosen by the map converter as the open spot nearest the supplies, up to 12 cells from the start (today 16-27 cells from supplies on all three maps). The proper fix comes with M8: the bot chooses its depot site near supplies itself (Zero Hour buildBySupplies/findSupplyCenter); recorded in the blueprint's M8 entry so it is not forgotten.
- Building placement (user, 2026-11-08; Zero Hour behaviour checked in BuildAssistant.cpp:908-1067, which has no distance or ownership check): your own units standing on a placed building's footprint move to the nearest free cell (Zero Hour: friendly units "politely move out of the way", BuildAssistant.cpp:942-943, but it also moves teammates' units and picks a random spot); teammates' units are not moved; an enemy unit on the footprint refuses placement and is highlighted (BuildAssistant.cpp:758-767). No build radius and no defence- or faction-specific placement rule, as Zero Hour: a builder that reaches and sees a spot in the enemy base can build a tower there. Once fog exists (M7.9), placement needs currently visible ground (BuildAssistant.cpp:922-940). A refused placement shows the red ghost, a text reason and the blocking object highlighted (InGameUI.cpp:1478-1500, 4020-4060). Milestone: the move-away belongs with unit avoidance (it reuses step-aside); the visibility rule with M7.9; the blocker highlight with M7.6.

## Controls (friend's playtest; user, 2026-11-08)

Zero Hour's key map is in the retail `EnglishZH.big` `data\english\commandmap.ini` (the `INIZH.big` copy is an empty header). Findings: Shift never queues in Zero Hour (it adds to the selection); waypoints are queued by holding Alt and right-clicking; dozers cannot queue buildings (a new order replaces the old one and the half-built site stays, DozerAIUpdate.cpp:1982-1996).

- Mouse stays StarCraft style (left selects, right orders), with no option to switch to Zero Hour's default left-click orders. A short right-click orders, a right-drag pans the camera, as Zero Hour's "Alternate Mouse Setup" (LookAtXlat.cpp:221-233 starts the scroll regardless of the mouse mode).
- Edge scrolling, also in a window and the browser (Zero Hour: 3 px band, fullscreen only, LookAtXlat.cpp:69, 301).
- Space jumps to the last alert (CommandXlat.cpp:2867-2884); H centres on the Command Center (CommandXlat.cpp:2861).
- Builders queue several buildings with Shift+place; plain placement still replaces (a Wargrid addition: Zero Hour has no building queue).
- Units queue move points with Shift + right-click (Zero Hour: hold Alt).
- Number keys become control groups as in Zero Hour (Ctrl+0-9 make, 0-9 select, Shift adds, Alt centres). With the HUD, building and production are mainly done with the mouse, plus Zero Hour's per-button letter hotkeys, shown on the buttons (the letters come from the localized `generals.csf` `&` markers, not decoded yet).
- No Q (select all) or E (select same type) hotkeys; double-click keeps selecting a type.
- Ctrl + right-click forces an attack, as Zero Hour (retail commandmap BEGIN_FORCEATTACK = Ctrl).
- Period (.) jumps to and selects the next idle builder, as Age of Empires II DE ("Pressing the '.' Key will move you to and select an idle Villager", ageofempires.com Match Goals & Hotkeys, read 2026-11-08; StarCraft II uses F1, Blizzard game guide); comma (,) does the same for idle army units (community guides; not on the official page).
- Camera spots on F1-F8 (Zero Hour SAVE_VIEW/VIEW_VIEW): later. No middle-click zoom reset; the wheel keeps Wargrid's fixed zoom levels.

## Repair (friend's playtest; user, 2026-11-08)

Wargrid has no repair today (`rg -i repair game/scripts`: nothing). All Zero Hour behaviour, retail values identical for the USA dozer, China dozer and GLA worker:

- Idle builders repair damaged own buildings by themselves: after 5 s idle, the nearest damaged own building within 150 Zero Hour units, about 6 Wargrid cells (DozerAIUpdate.cpp:1111-1128; BoredTime 5000, BoredRange 150). Not enemy buildings, full-health ones or ones under construction (ActionManager.cpp:383-433).
- A builder can also be ordered to repair: right-click a damaged own building.
- Rate 2 % of max health per second per builder, free, several builders add up (RepairHealthPercentPerSecond 2 %; DozerAIUpdate.cpp:719, 725-727).
- Bot builders use the same scan range as humans (Zero Hour doubles it for bots, aidata.ini AIDozerBoredRadiusModifier 2.0; not copied, fair bots).
- Pins moved by the depot-slot change (Ashfall team match digest, core series, peak units) may also be re-pinned overnight, recorded with old and new values, in their own commit (user, 2026-11-08).
