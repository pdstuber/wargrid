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
- Map pings for teammates without text (against Zero Hour's 3 text beacons per player, `multiplayer.ini:37`); one per player, a new ping replaces the old (OpenRA), lasting 30 s; plain ping only, no icon kinds (2026-11-09 HUD round).

HUD round on a click page (user, 2026-11-09 late evening; [re-check](../questions/hud-modern-recheck.md), [mock-up review](../questions/next-m76-hud.md); recommendations unless noted):
- Minimap attack flash at most once every 10 s per area (about 250 units), so an attack elsewhere still flashes (Zero Hour as written; retail's bug makes it map-wide).
- No health-bar setting: fixed "selected or damaged" (against the recommendation of an "Always" option); the unit under the mouse also shows its bar (Zero Hour, OpenRA).
- Health bars keep the green-yellow-red fill; a thin frame shows own / ally / enemy colour (compromise with look Q13).
- Teammates' attacks also show on your minimap, in a different colour (AoE IV).
- Idle builder button with a count only; no idle-army button (against the recommendation; the comma hotkey for idle army stays).
- Control-group row with unit counts, click selects (SC2, BAR).
- Production overview strip: each factory's current item and progress, click jumps there (AoE IV); no queueing from the strip.
- Keep formation: Zero Hour's opt-in Ctrl+F.
- Layout: the compact direction, one bottom dock with the minimap inside, optional panels as toggles (HUD v3 compact).
- The army panel and a pinned factory panel side by side; the factory never takes army orders.
- Production hotkeys by button position, the same grid in every building (AoE IV / BAR style). Open for M7.6 planning: with the pinned factory beside the army panel, the grid must not use Attack Move `A`, Guard `G` or Stop `S`.
- Large selections show cards per kind with count and total health; click filters, shift-click adds.
- Alert feed kept (click jumps to the event); team strip as a toggle in the compact dock; "Show performance" in the Esc menu or settings, next to F3.

HUD v4 mock-ups, round 1 on a labelled A/B page (user, 2026-11-13; picks as recommended unless noted). The clickable pages, the build spec and the survey are working files in the private notes repository (`hud-v4/`); the final pictures of all three rounds are in [HUD v4](../images/hud-v4/notes.md) ([120 units](../images/hud-v4/full-many.webp), [Core factory](../images/hud-v4/core-factory.webp)). Critique of [v2](../images/hud-v2/wargrid-hud-v2.png) and [v3](../images/hud-v3/wargrid-hud-v3-notes.md) that led here (agent assessment): one accent colour doing six jobs, an outline on every box, shrunk world sprites as unit pictures, and a v3 coverage figure that left out the decided strips.
- **Direction:** the HUD need not look like Zero Hour; parity is mostly about gameplay. It should be modern, take the best of well-regarded modern RTS games, keep Wargrid's own look, add something others lack, be beautiful and clear with good contrasts, and follow UI practice.
- **Look:** the flat look of the [fancy launcher set](#new-launcher-user-2026-11-13): matte slabs, cyan for a selected or armed control only, owner colour for whose a panel is, no gradients or glow. World selection stays white ([blueprint M7.5](../blueprint.md), look answers); cyan is for HUD controls.
- **Dock: slabs that hug their content.** Minimap, selection panel and context panel each are their own slab in a fixed place on the bottom edge; an unused place shows the world. This refines "one bottom dock" above. Measured on the round 1 mock-up at 1280x800 (superseded by the round 3 figures below): 5.6 % of the screen with nothing selected, 20.7 % with a 120-unit selection and a pinned factory; a full-width bar is 23 to 24 % in every state.
- **Status on the top edge** (against the recommendation of a ledge on the dock): credits, power and the production strip sit top left; the group row and the idle-builder button stay on a ledge above the dock.
- **HUD size: scaled with the screen,** as the game does today (a 1280x720 layout stretched to the window, world and HUD together; `game/project.godot`), so a bigger screen of the same shape shows no more map; with P2.1's stretch aspect `expand` a wider or taller one shows more at the same scale. No pixel-size mode. The mock-up's own text floor of 12 px (agent choice) becomes 18 px at 1080p.
- **Glyph plus word.** Resolves the blueprint's "command buttons with icons" against the launcher's "no icons": HUD buttons, cells and rows carry a single-colour silhouette in front of the name. A glyph is added to a worded cell and changes no size.
- **Flat buttons** (no recommendation was given)**;** the cyan outline is the only thing that marks an armed or selected control.
- **Amber means "needs you now" only:** under attack, low power, cannot afford. Money is plain text. No red warnings, because red is an owner colour. This narrows amber for the HUD only: in the launcher it stays the one start button.
- **Two sets on one layout.** Core is the early package: words only and only the panels the game can feed today (selection panel, build and production grid with position keys Q W E R T, queue of nine, credits, power, Attack Move, Stop), with no simulation change. The position keys are an input change that collides with keys bound today (W pans the camera in `game/project.godot`, E produces); to be settled in the P2.3 plan. Full adds glyphs, minimap, group row, idle builder, production strip, alert feed, Guard, Sell and the pinned factory, each with its feature. Core uses the flat dark look from the start, not today's grey. Placement: [packages](../packages.md).
- **Rows per kind, not cards** (user, 2026-11-13, confirmed after round 2): a large selection lists rows of name, count and health in two columns, so names are never cut and the panel has one width with or without glyphs. Replaces "cards per kind" above; click filters and shift-click adds as before.
- **Drawing calls shown on the page, not confirmed by the user (agent assessment):** Core queue slots show the key of the cell that made the item; Sell appears only on a selected building, never on the pinned panel; no rally button, right-click on the ground stays; minimap dots differ by shape as well as hue.
- **Checked against published criteria** (survey with quotes in the private notes; fetched 2026-11-13): Steam Deck asks for text of at least 9 px at 1280x800 and recommends 12 px; the Xbox Accessibility Guidelines ask for 18 px on PC at 1080p; the flat dark tokens pass the WCAG contrast pairs computed on the page (4.5:1 text, 3:1 non-text), today's grey fails two. Not tested in the game.
- **Round 2, all six additions taken** (picks as recommended):
  - *Reason at a blocked cell:* a small card above the dock names the cause with its number ("150 credits short") when a build or production cell cannot be used (Stormgate, Beyond All Reason). Needs a read-only "can I, and why not" query per cell on the simulation interface.
  - *Forecast before a purchase:* the same card shows credits and power after the purchase and warns when a building would cause low power (own idea; not found in the surveyed games). HUD arithmetic on the definitions.
  - *Time until affordable:* "about 7 s at current income" on a cell blocked by credits (own idea; not found). Income arrives in truckloads, so the figure jumps and says "about".
  - *Queued count on the production cell* (Beyond All Reason). The option as drawn also named shift-click to queue five; five queue commands in one tick are a same-tick case for the plan.
  - *Income and spending per minute beside the credits* (Beyond All Reason). Its "wasting" warning is not taken: Wargrid has no storage cap.
  - *Edge arrows* at the screen edge to an off-screen attack (amber) or teammate ping (ally colour), click jumps there (Forged Alliance Forever). Comes with the alert events.
  - Left out of round 2: a box selection that skips workers (Zero-K) and a range ring while placing (Beyond All Reason).
  - *In the Core package (P2.3):* the queued count, the credits shortfall on the card (cost minus credits; other reasons need the simulation query and come later) and the forecast, all HUD arithmetic. Income, time until affordable and the edge arrows come with later packages.
  - Open (agent assessment): the card is small and easy to miss; a forecast on the power figure in the top strip while a building is armed may serve "warn before you commit" better. Not drawn.
- **Round 3, look** (picks as recommended):
  - *Judged on the game's own colours:* sand ground and the owner colours of `game/scripts/presentation/palette.gd`, not v3's muted backdrop. The dark slabs separate more clearly on the light ground.
  - *One type scale:* three text sizes with fixed roles and tabular numbers; the top strip is 32 px high with the credits at 16 px. Both liked as drawn.
  - *Typeface Inter* (SIL Open Font License) over Barlow Semi Condensed. The game needs a font file; this is the one to add with the theme.
  - *Glyphs, third pass:* bright top faces as the dominant mass, one ground line, at most six shapes each. Mock-up drawings, not game art.
  - *Dock height: tight.* The polished dock was 16 px taller, and that was feared to take too much of the screen (user, 2026-11-13). A second flip kept the type scale and took the height back: dock 168 px in the 1280x720 layout, rows 26 px, buttons 32 px, and the queue label moved into the title row so a production panel is only as wide as its nine slots (376 px against 484). Agent call, not picked: build cells grew from 88 to 100 px so a four-digit cost clears the key chip, which costs about one point of coverage while placing.
  - Coverage with all picks, measured on the mock-up at 1280x800: Full 6.6 % with nothing selected, 20.0 % with 120 units and a pinned factory, 21.8 % while placing; Core 1.0 %, 8.1 % and 16.9 %.
  - Agent call: the mock-ups show power as used / available ("11 / 10" is low power); today's status line prints supply / demand.
  - Open for the theme work (agent assessment): the mock-ups use the art sheets' lighter owner blue for the panel edge and progress bars, the game draws owner 1 darker; which one the HUD uses is not decided.


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
- FRC rebuild holes (raised by the user): most FRC buildings leave a hole when destroyed (Zero Hour GLA: 500 HP, heals 0.5 % per second, `HoleMaxHealth` / `HoleHealthRegen%PerSecond` in retail `data\ini\object\factionbuilding.ini:143-144`, 11 `RebuildHoleExposeDie` buildings); after 20 s (`WorkerRespawnDelay`) a worker spawns and rebuilds the building unless the hole is destroyed; a killed worker or rebuild restarts the wait (`RebuildHoleBehavior.cpp:200-335`). Lands in batch A gate A4 (FRC), Zero Hour behaviour. The rebuild is free: money is withdrawn only when `isRebuild` is false (WorkerAIUpdate.cpp:408-416; checked 2026-11-09).

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

Follow-up after the avoidance spike (user, 2026-11-09 evening; open questions from the spike note on `spike-avoidance`, `docs/reference/unit-avoidance-spike.md`):
- A unit within one cell of its destination ignores blockers and squeezes in; overlaps there are spread out afterwards (Zero Hour default, AIUpdate.cpp:1303-1311).
- Each unit keeps its own reserved destination cell (today's rule) together with the squeeze-in rule; if packed moves still cannot finish within the cost cap, OpenRA-style "stop near enough when close and blocked" is the allowed fallback (user asked for its trade-offs first: cheaper, no fight for the last cells, but irregular end positions and a tail that can stop short).
- The +0.5 ms cost cap applies to every 300-unit row, the all-infantry horde row included.
  - That means all six rows (docks included; "five" was a slip, user, 2026-11-10): HEADLESS movement open and dense, docks, COMBAT open and dense (150 v 150), and COMBAT hordes300.
  - A miss on COMBAT open or dense counts as a movement-row miss for the near-enough fallback below (user, 2026-11-09).
- The next spike round builds on approach A (Zero Hour-style yielding) and borrows B's "claim the next cell" only where A's retry cost shows up (a hypothesis to test).
- The about-5-s last resort counts "no progress towards the goal", not consecutive blocked ticks, so circling units are caught.
- A move order is never given up because the unit is stuck; it fails only when no path exists (Zero Hour default, AIStates.cpp:1880-1895).
- Speed matching (a fast unit follows a slower friend) is part of the first version, not a follow-up; it is expected to cut A's per-tick retries as well (inferred, not measured).
- Narrow passages are tested twice: a synthetic benchmark layout with a 2-3 cell gap, and the narrowest real passage found on the three converted maps (the spike's Dry Wells "choke" was a 20-cell lane).
- The next round adds a mixed-owner scenario (tanks driving through an enemy infantry blob) so crushing and its cost are measured.
- Per-unit avoidance state goes into the snapshot and state hash already in the next spike round, so its measured cost is honest.
- Existing tests that fail because behaviour changed (G3, P3, S8, BM6 in round 1) are listed with what changed and a proposed rewrite; the user decides per test before the avoidance milestone. The spike does not change them.
- Screenshots colour units by moving group, so crossings and who yielded are visible.
- The overnight run of spike round 2 may open short-lived game windows for screenshots (no sound, closed by the run); this pre-approval covers that run only.
- Round 2 continues on branch `spike-avoidance` (worktree `../wargrid-wt-avoid`), rebased onto current `main` first.
- If round 2 still misses the cap: record the exceeded rows and what costs most, never loosen. If the miss is on the movement rows, also measure the near-enough fallback as a separate variant next to the main one and report both; if only the horde row misses, report only (near-enough does not reduce bookkeeping cost). The user decides the next step (revised from "report only" after the user asked why not; 2026-11-09).
- Round 2 is measured natively and in the browser (Firefox web bench, as round 1).
- Steam Deck measurement by the user after round 2, only if round 2 passes the cap on the Mac.

After round 2 (no variant met the cap; user, 2026-11-10):
- Round 3 is a cost experiment on R1, no rule changes: trim the cheap path, merge the per-class grid fills, skip the grid for all-infantry, re-measure against r0 in the same interleave. Hard stop after one round: if it does not close the gap, the next step is a design brainstorm for a different structure (for example grids only near vehicles), not another experiment.
- Round 3 verdict (user, 2026-11-10, round 2 open question 2): a row passes only if its median-of-3 delta p95 against r0 is at most +0.500 ms; the spread is reported, there is no noise allowance.
- Round 3 also changes the movement benchmark legs so packed moves can finish (round 2 open question 8; user, 2026-11-10). Risk raised before the answer: spreading destinations makes `run_benchmark.sh` pass while the in-game "select 300, click one spot" jam remains. So the new legs apply identically to r0 and the variant, the old packed one-anchor move stays in the jam harness as a reported jam row, r0 is measured on old and new legs so the budget shift is visible, and only on the spike branch (main's benchmark is unchanged).
- Round 3 measures the browser (Firefox Web Bench, a dedicated profile, never the user's own Firefox) only if the native cap passes; otherwise it is skipped and said so (user, 2026-11-10, round 2 open question 13).

After round 3 (brainstorm; user, 2026-11-10; round 3 missed the cap on one row and packed moves still jam):
- The user asked what Zero Hour, OpenRA and Recoil do when there is no room. Two independent source readings (main session and a subagent; notes outside the repo in `~/projects/wargrid-overnight-work/avoidance/brainstorm/`) agree: all three have a fallback and none relies on hard blocking alone; Zero Hour lays goals out so units rarely have to pass a standing one (`AIGroup.cpp:480-514`, `:990-1012`, `:1696-1700`), while Wargrid hands goal cells out by unit id (`destination_allocation.gd`).
- Next is a spike, not a milestone (user): first Zero Hour's goal layout, then a no-room fallback (goal swap with a standing friend), then a small slice of column moves to get a feeling for them. Draft plan: [avoidance round 4](../superpowers/plans/2026-11-10-avoidance-round4-spike.md); not approved yet, and open to change from the subagent's findings (user).
- (Not built: round 4 was narrowed to `s1` and `s3`, user 2026-11-10.) Added from the subagent's reading, as a measured variant only: crossing movers pass through each other after 1 s, Zero Hour's rule (`AIUpdate.cpp:1355-1362`). It contradicts the "about 5 s" answer above for that case; **not decided**, the user rules after the results.
- Column moves make a group long and thin, so the front arrives well before the tail (Zero Hour has the same trait); the user judges that by seeing it.
- Friend's playtest (competitive RTS experience, reported by the user 2026-11-10, in substance): the pathfinding grid looks as coarse as the building grid, and units "move strangely, probably because there is no 360° movement". Checked: routes use four directions on the same cell grid that buildings block (`grid_navigation.gd:19-24`), one cell is 25 Zero Hour world units; Zero Hour paths on 10-unit cells and smooths the path (`AIPathfind.h:439`, `AIPathfind.cpp:474`). Movement in any direction is an **open design question**, to be asked before the avoidance milestone because the blocking rules depend on it; round 4 only shows an eight-direction probe.
- **Decided (user, 2026-11-10):** units path on a finer grid than buildings and drive at any angle, as Zero Hour does, "unless there is very good reason not to". Wargrid may use its own method, closer to what modern RTS games do, as long as it feels similar. Design not done yet: grid size, path smoothing method, cost on the browser target. The movement brainstorm must also investigate a navmesh and flow fields (user, 2026-11-10), not only a finer grid with smoothing.

## Movement and pathing (user, 2026-11-10)

Questions and research: [movement and pathing brief](../questions/movement-pathing-brief.md). The decisions that started it (finer grid, any angle, own method allowed, navmesh and flow fields investigated) are under "After round 3" above.

- Priority (user, 2026-11-10): for movement and pathing, units not getting stuck and good performance matter more than exact Zero Hour parity. The method choice and any later trade-off are judged on these two first.
- Base method: measured first (finer grid with smoothing, hand-written navmesh, flow fields; pathing timing spike note `docs/reference/pathing-timing-spike.md` on branch `spike-pathing`, commit `70026c5`), then **chosen provisionally (user, 2026-11-10, questionnaire after the art lab; the user was unsure on some items: the movement milestone shows in-game A vs B examples, like the avoidance round 4 feel session and the art lab, before any item is locked)**:
  1. **Rectangle navmesh (B)** as the base method, with the same straightening; the finer grid (A) stays as the reference that B's paths are checked against. The milestone's first task is a moving-units prototype that checks stuck behaviour; if B fails it, fall back to A.
  2. Big group orders: **individual routes first**; shared trunks or flow fields later, only if measured jams or cost need them.
  3. Path budget: **keep 8 route requests per tick** (`simulation.gd:18`) and measure; a Zero Hour style searched-cell cap (`AIPathfind.cpp:1103`) only if measurement shows spikes.
  4. **Three size classes: infantry, vehicle, large**, one mesh per class.
  5. Building placement: **local update** (re-widen and rebuild only the tiles around the building) in the milestone, measured.
  6. Straightening: **body-safe line test** (the unit's full width along the line), because a centre-line test can clip a corner by about half a cell (spike part 7).
  7. **Own navmesh code is acceptable** (rectangle building and incremental updates; the search stays Godot's `AStar2D`).
  8. Determinism: **cross-platform path test early** (fixed scenarios compared across macOS, Linux and Windows CI, like the trace comparison); if paths differ, switch to integer costs in an own search.
  Feel goal (user, 2026-11-10): movement does not have to play exactly like Zero Hour, but like a polished modern RTS. So responsiveness wins over Zero Hour's wave start where they conflict, for example a large order should get every unit moving within a tick or two (today 8 routes per tick means about 1.3 s until the last of 300 units starts).
  Movement lab, the milestone's first task (in the art lab style: `[` `]` question, `Tab` variant, click page), in this order of gameplay impact: (1) route budget per tick (8 vs 32 vs all at once, watching the response to the click and the cost); (2) body-safe vs centre-line straightening (corner hugging, scraping, getting stuck); (3) individual routes vs shared trunk for big orders (broad stream vs column); (4) navmesh vs finer grid path shape. No A/B for the local building update (same paths when correct: proved by a test) or cross-platform determinism (a test).
- Grid size: 2x2 pathing cells per building cell (12.5 Zero Hour units; Zero Hour uses 10, `AIPathfind.h:439`). Ashfall becomes 388x374 cells, so the map cap of 256 per side (`grid_navigation.gd:15`) must rise.
- Turning needs no new decision: units already turn at a per-kind rate, wheeled vehicles only while rolling (`locomotion.gd`), as Zero Hour (retail `locomotor.ini`: `TurnRate`, `MinTurnSpeed`).
- Unit size: **revised (user, 2026-11-10)** to a few size classes, Recoil-style (2 or 3, for example infantry, vehicle, large vehicle; each kind assigned one; one pathing layer per class), after the priority above; soldiers still fit where tanks do not. Superseded: "per unit kind, as Zero Hour" (its width gives 1 to 5 pathing cells across, `AIPathfind.cpp` `getRadiusAndCenter`), chosen earlier the same day. Other games: OpenRA uses whole cells for vehicles and five shared slots for infantry (`mods/ra/rules/world.yaml:15`, `MapGrid.cs:118-124`); Recoil one pathing layer per size class (`QTPFS/PathManager.cpp:397-400`).
- Order: movement and pathing is its own milestone before the unit avoidance milestone; avoidance is then designed on the finished movement model (two trace re-pins accepted).
- The timing spike for the three methods runs right after avoidance round 4, before the art lab: scratch scripts, no simulation change, every row labelled as a GDScript cost to be re-read after the native simulation core spike (a native core could make navmesh or flow fields cheap).
- Feel: units keep Zero Hour's weight (per-kind turn rates, rolling turns for wheels, acceleration and braking); not made snappier.
- Permafrost Engine (`~/projects/permafrost-engine` @ `083a99c`, GPLv3 or later; evaluated read-only 2026-11-10, report `~/projects/wargrid-overnight-work/engines/permafrost-engine.md`): read as a reference only, not used as code, engine or core (C and Python 2.7, x86_64 Linux and Windows only, no WebAssembly, no lockstep, float and threaded movement). **Into the movement or avoidance milestone design (user, 2026-11-10):** moving units never lock grid cells; only stopped units mark cells blocked, with a reference count (`src/navigation/nav_data.h:132-137`); moving units steer around each other with velocity-based avoidance, ClearPath/HRVO (`src/game/clearpath.c:36-41`); waiting units wake when a counter bumps as a cell frees up (`nav_data.h:138-142`). Determinism of the steering maths (square roots, vector maths, no trigonometry) is a design point.
- **Deferred (user, 2026-11-10):** if the native simulation core spike decides on Rust or C++, evaluate Permafrost's chunk flow fields (A* over chunk portals, per-chunk fields cached by chunk, target and layer, a line-of-sight field for straight driving; `src/navigation/a_star.h:128`, `field.c:2186`, `fieldcache.c:61-65`, `field.h:206-214`) against the chosen method; in GDScript one chunk field is estimated at about 55 ms in the browser (inferred).
- Left open on purpose: shared group routes or flow fields for big orders (waits for the round 4 column feel session and the timing spike). Proposed, not decided (technical, measured in the spike): budget path work in searched cells per tick as Zero Hour does (5,000 per frame, `AIPathfind.cpp:1103`) instead of 8 routes per tick; raise the map cap to 512 cells per side.

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

## Simulation core and state digest (user, 2026-11-09 late evening)

Questions from [sim core options](sim-core-options.md) (Q1-Q15) and [state digest research](state-digest-research.md) (Q1-Q8). Own engine is out of scope unless done for fun; C++ in Godot is acceptable; Rust in Godot is the leaning; the browser stays the primary target, a reduced browser mode is only a measured fallback (user).

- Write down the simulation's public interface (commands in, snapshot and events out) as a short note now.
- New tests check the game only through that interface; the 19 existing test files that read internals are not migrated now.
- Replace Godot's `Dictionary.hash()` in the online desync digest with our own hash over every field (one re-pin).
- The hash walks every field automatically with sorted keys (not Zero Hour's hand-written per-class list).
- Hash function: 64-bit FNV-1a with a fold, 16 hex characters on the wire (relay unchanged).
- If the full hash is too slow on a hash tick, spread one hash over the next 30 ticks (desync detected about 1 s later), not Zero Hour's every-100-ticks.
- 0.0 and -0.0 hash the same (as Godot today), so a Python checker can verify the JSON desync dump.
- The new hash ships together with the golden test scenarios: one re-pin.
- A new game version keeps old and new clients apart (the relay already refuses a build mismatch); no protocol bump.
- The CI replay traces switch to the same digest (today a Godot-only SHA-256 over `var_to_bytes`, `test_replay.gd:56`).
- The simulation performance spike starts with a one-day check that a tiny Rust extension (godot-rust) runs in Firefox on the Steam Deck.
- If native code wins: Rust, with C++ only if Rust fails in the browser.
- Pass line: Rust must show at least 5x after the data hand-off cost. **Superseded 2026-11-10** by the ratio rule in "Native simulation core spike" below (the user called the 5 arbitrary on 2026-11-09).
- If native wins, production also sends the cross-origin isolation headers (needed for any extension in the browser; refines the earlier "test app only").
- Whole simulation port or hot loops first: decided after the spike (the data hand-off cost decides).
- During any port the GDScript simulation stays the reference until the golden scenarios match (the rollback).
- Fixed-point (integer) simulation maths, like OpenRA's 1024 units per cell (`OpenRA.Game/WDist.cs:22`): not now; floats with written determinism rules and a CI check, and switch to integers as part of a Rust port if one happens (one re-pin). User asked for the upsides first (determinism by construction, cross-language for free, simpler hashing).
- Browser fallback trigger (if the browser proves too slow): either skirmish simulation p95 over 10 ms in Firefox on the Steam Deck after the spike's fixes, or frame p95 over 16.7 ms at Low.
- In that fallback the browser defaults to Low graphics; High stays available with a warning (graphics are per player).
- In that fallback the host can pick a lower unit cap per match (a simulation switch, identical for all players).
- No reduced update rate for far-away or idle units until measured (it changes fights).
- Per-match switches travel with the host's match settings in the start message; only the code fingerprint (R1.1) gates rooms.
- Golden scenarios get a horde-style case only when a horde mode is planned.

## Native simulation core spike (user, 2026-11-10 evening)

Interview before the overnight run of the handoff (`native-sim-spike-prompt.txt`, private); evidence in [its verification file](native-sim-spike-verification.md).

- Verdict by the ratio rule (language gain K, hand-off H, effective gain E, template tax T against the need Q), not by "5x"; the old quantity is still reported as E.
- Headroom factor 1.5: the projected gain must reach Q x 1.5 (today 1.45 x 1.5 = 2.18).
- The Rust core is engine-independent as a requirement: it builds and passes its tests with no Godot installed.
- Slices: the horde step and the movement of moving units, ported in parallel (movement is rewritten by the next milestone, which does not matter for ratios).
- Added probe: what it costs to hand 400 unit records from Rust to Godot as today's Dictionary-shaped snapshot against packed number arrays.
- Template tax measured on the simulation benchmark and on the rendered web benchmark.
- Emscripten 3.1.74 is the main version (documented by godot-rust); 4.0.20, the engine's own, gets a comparison row.
- Linux x86-64 binaries are built in a container on the Mac; nothing is installed on the Deck beyond one folder.
- The user sets up the Deck (Desktop Mode, mains power, no sleep) before starting; without it the run continues on the Mac and the outcome is at most CONDITIONAL GO.
- If the Deck does not work during the night: "run the stuff on the mac and follow your best judgement" (late evening, after the Deck preflight passed: Desktop Mode, mains, no screen-off, no lock, "when inactive: do nothing").
- Overnight a stop condition takes its written default and the run continues; only push, deploy and loosening a budget or pin are never defaulted.
- Local commits on `spike-native-sim` are pre-authorized; no push, PR or merge.
- Models: Sonnet coordinator; Opus 5.5 and Sonnet 5.5 subagents by difficulty (the plan names one per task).
- If the run is not finished in the morning it keeps going; the user checks in.
- One phone notification, when the report is done or nothing can continue.
- Browser windows on the Mac and on the Deck are allowed during this run (user: "fine to spawn windows, play sounds, run benchmarks, launch browsers").
- Coordinator calls (not the user's, change if wanted): Vivaldi is the Chromium browser on the Mac; no C++ fallback is built at night (a morning decision if Rust fails in a browser); parallel code tasks get their own task worktree and branch, and their commits reach `spike-native-sim` by `git cherry-pick`, because `git merge` asks for approval and a night session denies what asks.


## Turret aiming (user, 2026-11-10; [impact note](turret-aiming.md))

- A tank's turret must point at its target before it fires: it turns at its rate and fires once aligned (Zero Hour default, TurretAI.cpp:1169-1199). Replaces "firing ignores heading" (blueprint M6).
- It lands in ground batch A, together with travelling shells and minimum range, so one re-pin covers all of them. Until then turrets are drawing only (the art lab uses that stand-in).
- Soldiers (no turret) turn their whole body to within about 2 degrees of the target before firing, at their turn rate (Zero Hour default, AIStates.cpp:5051-5072; at most about 0.36 s).
- Each turreted kind keeps its own Zero Hour turret rate (Crusader 180, BattleMaster 120, Scorpion 100, Technical 240 deg/s; table in the impact note). China/FRC kind mappings are inferred from display names: re-check with `tools/zh_ini.py` at batch A planning.
- After losing its target a turret holds for `RecenterTime` (2 s; Humvee and Scorpion 5 s), then turns back to face forward (Zero Hour default, TurretAI.cpp:200, :1439).
- Turreted units fire while driving at whatever is in range once their turret is aligned; units without a turret still stop to fire (Zero Hour: the turret's idle state picks targets on its own timer, TurretAI.cpp:879-900, :1306-1327; `getNextMoodTarget` has no movement check, AIUpdate.cpp:4495; source reading, not every guard traced). Check each unit's `AutoAcquireEnemiesWhenIdle` with `tools/zh_ini.py` at batch A planning.

## Performance next (user, 2026-11-11)

Asked one at a time after the native sim spike; analysis and experiments in [performance next](performance-next.md).

- **Goal row:** a 210-unit 3v3 must run smoothly in Firefox on the Steam Deck. 400 units fighting at once (hordes300) stays a reported stress row, not the goal. Budgets, F and gates in the [ledger](performance.md) are unchanged by this answer.
- **Motive:** no performance problem is felt in play. All playtesters have gaming PCs; no low-end tester exists yet. The work is driven by the ledger, a possible horde mode later, and fixing architectural base issues now so later work is easier.
- **Horde mode size:** 1,000 enemies "for now". Not thought through; a spike comes first so the user can see whether the mode makes sense. The horde spike is approved (benchmark, then a playable throwaway scene).
- **Threads:** a threaded browser build may send the cross-origin isolation headers in production if the experiment shows a clear win (replaces "test app only" for that case). The user still wants threads together with Godot's "Separate" render thread measured (asked 2026-11-09 as perf question Q11, never run).
- **Tick rate:** split rates. Movement and firing stay at 30 per second; unit decisions may run less often, staggered across units. Asked first how modern RTS games do it (StarCraft II 22.4, OpenRA 25, Recoil and Zero Hour 30, Permafrost movement 20 and combat 10; sources in the note).
- **Order:** experiments first (speed-built web template, simulation on a thread, packed-array horde spike), then decide the data layout, before the movement and pathing milestone starts.
- **Budgets:** may be re-derived from a new structure (simulation on its own thread or frame) as an explicit proposal with measurements and a ledger row for the user's approval; nothing is loosened silently.
- **Measuring host:** the Mac mini; the Steam Deck gets a break. Windows and non-headless runs on the Mac mini were approved for 2026-11-11 while the user was away.
- **Working style (user):** other engines' sources (OpenRA, Recoil, Permafrost) are one input, not the only one: "we have looked at the other engines before and not fixed our own engine so far".

## After performance next (user, 2026-11-11 evening)

- Interpolation rework (presentation only, folds in T4b, changes WB18's golden batch by design, needs a rendered A/B): before the movement milestone.
- Packed-array storage for per-unit simulation state: inside the movement milestone, not as its own refactor task; after the golden scenarios plan.
- Test app: final tree, single-threaded (deployed 2026-11-11 as fly release v11 of wargrid-web-test); the threaded build with isolation headers stays in `~/projects/wargrid-perf-work/threaded-deploy/`.
- Next run to start: the golden scenarios plan ([plan](../superpowers/plans/2026-11-09-state-digest-golden-scenarios.md)).
- Worker thread for the simulation: the user wants to pursue it ("unless you tell me it is not worth it"); design in [worker thread design](../superpowers/specs/2026-11-12-worker-thread-design.md), stage 1 (single-threaded `SimPump` boundary) first, the thread itself after a browser measurement.
- Order of the next work (user agreed, 2026-11-11): 1 golden scenarios, 2 interpolation rework, 3 worker thread stage 1 (`SimPump` boundary), 4 the worker thread itself only if a browser measurement shows a main-thread win. Each is started by the user explicitly.

## Main branch audit (user, 2026-11-11 night)

Answers to an outside audit of `main` at `ec78012` (audit and fix list kept outside the repo in `~/projects/wargrid-overnight-work/audit-2026-11-11/`). Fixes applied the same night on branch `verify/2026-11-11`: WB18 made platform-stable, CI check in kickoff and wrap-up, web desync download, lockstep queue bound, `chases` in the snapshot, release actions pinned by SHA.

- **Golden order (changes "After performance next" item 1):** pin as few new golden digests as possible until the movement milestone has landed; the golden scenarios plan moves after movement. The snapshot restore round-trip test comes with the movement milestone's unit schema, not before.
- **Presentation tests:** no byte-exact goldens over drawn geometry; use counts, summed coordinates with a tolerance and colour digests (as WB18 now does).
- **Reference-trace parity:** a gate only for units that change locomotion feel; otherwise a tool used when a unit feels wrong.
- **Design questions:** research only for the next one or two milestone packages.
- **Bot memory:** stays outside the snapshot while each netplay client runs only its own seat's bot; revisit when M9 bot takeover runs bots on every client.
- **Relay Origin check:** skipped for now (friends only); revisit in M9.
- **Fuzz and invariant test:** before the movement milestone. **One targetability predicate:** before ground batch A. **Controller chain flattening:** with the controls task, together with the `SimPump` seam.
- **Performance:** now a `BUDGET EXCEEDED` summary line and a report-only worst-tick line; the forward budget per unbuilt system after measuring the browser against native on the team match (desktop-only 3v3 is decided from that measurement); a report-only late-game canary before the movement design.
- **Roadmap:** a thin playable slice (controls task, minimal real HUD, order acknowledgement sound, regular 1v1 playtests) directly after the movement milestone; fog (M7.9) before ground batch A; the roster stays at four units per faction until three recorded 1v1 matches are reviewed.
- **Unit autonomy (human vs AI behaviour):** decided at the M8 design, leaning toward a per-unit stance; count "units just stood there" and "ran off" remarks in playtests first.
- **Documentation:** `docs/ARCHITECTURE.md`; a `docs/STATUS.md` that replaces the status bullets in the development notes' Start here; symbols instead of line numbers in living documents; a short table at the head of the performance ledger. Logs are not moved.
- **README:** current screenshot and a short fight clip (needs a window: ask first), remove "placeholder shapes for now", CI badge once `main` is green, three lines on what Wargrid does differently. Align `AGENTS.md` with the README's "inspired by" wording; open item: a qualified opinion on deriving the roster's numbers from retail data before wider distribution.
- **Next (user):** overhaul milestone planning into smaller packages that each give players a meaningful increment and can be shipped and playtested on their own, plus tooling that focuses playtests on the current aspects and makes feedback easy, clear and directed. Starts right after the audit batch, with brainstorming.

## Planning overhaul: packages and playtest tooling (user, 2026-11-11 night)

- **Feedback moments:** both mid-match and afterwards: a quick in-match marker plus a short after-match form that shows the markers again.
- **Players:** mostly the user alone; a friend joins only for online parts.
- **Playtest length per package:** 15 to 20 minutes, one or two matches.
- **Cadence:** a new package every 2 to 3 days.
- **Package rule:** mostly every package changes something the player can feel in a match; a pure engine package is allowed now and then, without a playtest.
- **Big changes (movement, avoidance):** ship behind a toggle, old and new side by side in the build, flipped with a key like the art lab, before the new one becomes the default.
- **Where packages go:** every package to the test app (`wargrid-web-test`); a public release bundles a week's packages.
- **Playtest findings:** a problem in what the package was about is fixed before the next package; other findings go on a list that orders later packages.
- **In-match marker:** one key (for example F2) opens a quick note, Good / Bad / Confusing plus an optional line of text, pausing offline; it saves tick, camera spot, selection and a screenshot.
- **Focus:** the launcher shows a card per build (what is new, what to try); in a match a toggleable checklist ticks items off as they are done.
- **After-match form:** in the game, shown after the match: three to five rating questions about the package's focus, and the session's markers listed again to comment on; works in the browser and on desktop.
- **Hand-off:** one file per session, saved on desktop and downloaded in the browser (the desync report's download path); the user drops it in a folder the agent reads.
- **First package:** the playtest helper (marker key, focus card, checklist, after-match form, session file).
- **Open playtest backlog** (M7 FRC checks, art-lab defaults never seen in a match, M6 fixes checked headless only): three 15-minute focus cards, one per area, played with the helper.
- **Focus cards:** the agent drafts each from the package plan; the user approves it with the plan and may edit it before playing.
- **Re-plan depth:** the next five packages in detail (about two weeks), the rest of blueprint §7 re-cut roughly, re-planned as playtests come in.
- **Order (replaces "playable slice directly after the movement milestone" above):** interleave: playtest helper, camera controls, movement part 1 behind a toggle, order controls (control groups, Shift-queue, acknowledgement sound), movement part 2, and so on.
- **Engine-only audit items** (fuzz test, `BUDGET EXCEEDED` line, browser against native measurement): riders, one small item per package next to its player change.
- **Naming:** P1, P2, ... with a player-facing name (for example "P3 Camera that follows you"), tracked in `docs/STATUS.md`; M-numbers stay for history.
- **Helper scope:** on by default in the test app and dev builds; off in public releases unless switched on in the settings, so friends can send session files too.
- **Session file contents:** the match's command log (so the agent replays the match headless and jumps to each marker's tick), the notes, answers, build id, map and seed, and each marker's screenshot as a small JPG (about 640 px wide) inside the one file.
- **Plan home:** `docs/packages.md` (next five packages in detail, the rest rough); blueprint §7 links to it and keeps design scope; `docs/STATUS.md` shows state.
- **Session inbox:** `~/projects/wargrid-playtests/`, outside the public repository; the agent reads new files at kickoff.
- **Earlier order kept:** the interpolation rework becomes its own package ("Smooth motion", P4) before movement (P5); the `SimPump` seam goes with controller flattening in the HUD packages; writing the movement design is P3's rider.
- **Session:** one sitting; one file holds every match of the sitting; a short marker review after each match, the focus questions once when the session ends.
- **First plan covers:** `docs/packages.md`, `docs/STATUS.md` and the blueprint §7 link; P1 with its rider; all three backlog focus cards. Only card 1 blocks P2; findings from cards 2 and 3 go on the list unless they block play. Design: [packages and playtest helper](../superpowers/specs/2026-11-11-packages-and-playtest-helper-design.md).

## Dock-hold experiment (user, 2026-11-12)

Evidence: [dock-hold experiment](dock-hold-experiment.md).

- **Dock model:** adopt neither split nor queue yet; measure option C next (one pile lock per credit for every collector, rest of the stand unlocked), with a per-phase breakdown for the unexplained FRC 7-worker loss and the saturation and payback metrics.
- **Gated multi-collector targets:** change them (steady window, re-measured values) together with the change that adopts a dock model, not before.
- **Code location:** harness tooling and the note on `main`; the split and queue variants stay on the local branch `dock-hold` as evidence.

## Dock option C follow-up (user, 2026-11-12 night)

Answers to the open points of the [dock-hold note](dock-hold-experiment.md#option-c-and-saturation-2026-11-12):

- **Dock model:** none chosen yet; the frc7 shortfall is investigated first, because it decides whether any dock rebuild pays (c1 18 of 22 rows, split 17, hold 16, c2 15).
- **USA 2-Chinook overshoot:** up to +5 % above Zero Hour is acceptable (c1's usa2 far +4.3 % steady is inside).
- **frc7 shortfall** (Wargrid loses 14.4 % against the pile bound, Zero Hour about 7 %): one small evidence-only investigation: phase breakdown at n = 1 and n = 7 on both sides, the gap between a pile release and the next grant, and the far-depot cycle length.
- **Economy metrics:** saturated income per dock site with spend to 90 %, and marginal income with payback, become standing report rows (cap, n90, spend90 per curve, payback only up to n90, a flag when a pile empties); the basket metric waits until a basket is chosen.
- **Branch `dock-hold`:** stays local; nothing is cherry-picked or pushed until a dock decision.
- **c1 and c2 in CI:** run only when named (`WARGRID_DOCK_MODELS`); the default suite runs hold, split and queue.

## frc7 gap follow-up (user, 2026-11-12 night)

Answers after the [frc7 gap measurement](dock-hold-experiment.md#frc7-gap-measurement-2026-11-12) (one extra cell walked per trip with several workers; no dock lock rule touches it):

- **Dock model:** c1 is chosen for a clean rebuild (one pile throughput rule, 184 ticks per 300 credits; usa2 far +4.3 % is inside the +5 % allowance). Order: the dock rebuild comes before the movement fix, so FRC income leaves hold's cap (frc7 close 1590 against Zero Hour's 2850) without waiting for it.
- **Release first:** release 0.11.0 before any of this, so the live site gets the new graphics (top priority).
- **Then:** the c1 rebuild plan (Opus-written), then its run; frc7 close and far rows stay reported, not judged, because the movement fix will lift them about 8 %. The evidence-only spike on the rule behind the extra cell (trace one leaving worker's cells against the standing workers' cells, then the route, arrival-cell and exit-cell code) runs after it or in a second worktree.
- **Start-dependent n = 7 rates** (split sweep 2385 against opening 2625; Zero Hour 30 apart): a caveat in the note for now; revisited after the movement fix.
- **Zero Hour far opening:** three new games approved and run (`open_worker_u3125_x7`, 3 of 3).

## Netplay reference review (user, 2026-11-13)

Evidence: [netplay reference review](netplay-reference-review.md). Placements: Relay guards and Adaptive input delay in the rough rest of [packages](../packages.md), the deploy wait as a rider on Is Wargrid healthy, the rest in [blueprint §7 M9](../blueprint.md#m9--3v3-online), the M7.9 fog section (map hacking) and Later; snapshot rejoin answers [dropped players](../questions/next-m9-drops.md) Q11.

- **Anti-cheat without a server simulation:** the Relay guards package covers what a relay can see (lead bound, hash comparison, later the byte budget). Map hacking cannot be stopped in lockstep, because every client holds the full state; accepted for friends' matches, revisit at fog (M7.9) if matches become public. A server-authoritative simulation stays rejected.
- **Metrics:** both. Relay `/metrics` into fly's hosted Grafana stays the Is Wargrid healthy package (live health); `MATCH END` log fields carry the per-match detail (frame bytes, desync groups). The 2026-11-08 removal of Prometheus does not block that package.
- **Hidden browser tab:** observe it at the next browser playtest (hide the tab 3, 8 and 15 s in Firefox, Chrome and Safari; note the time to stall and to `left`) before designing anything for it.
- **Rejected or deferred (agreed with the review's §10):** a second transport for native clients (UDP or ENet, QUIC, WebTransport, WebRTC) is rejected, revisited only if the M9 burst-loss scenario shows stalls that redundancy would remove; a server-authoritative simulation is rejected, lockstep stays; relay-side tick stamping (OpenRA) and a relay clock that never waits (Recoil) are rejected for now, adaptive delay goes in-band (Warzone 2100); binary encoding instead of JSON is deferred, the fallback if fewer frames per second (M9 relay CPU item) is not enough.
- **Also deferred or skipped:** an external store such as Redis for room state (deferred; clients already hold the same data, so it is not the first availability option); per-subsystem sync hash rings in the running game (deferred until a desync does not reproduce on command-log replay); an Origin check on the WebSocket upgrade (skipped; nothing to steal, native clients send no Origin, the M9 lobby tickets are the gate).

## Simulation reference review (user, 2026-11-13)

Evidence: [simulation reference review](simulation-reference-review.md). Packages: Sim quick wins and Flatter worst ticks in the rough rest of [packages](../packages.md).

- **Movement design inputs** (for the movement milestone design, P3's rider; built in P5): path delivery is deferred and deterministic: a request at tick T gets its route at T+1 at the earliest, served in (request tick, unit id) order under a budget of searched nodes (a started search finishes; no new one starts once the budget is spent); search inputs stay frozen until delivery, and undelivered routes are simulation state in the snapshot. The search over the rectangle navmesh ([Movement and pathing](#movement-and-pathing-user-2026-11-10)) becomes Wargrid's own typed GDScript with an explicit tie-break (f, then g, then node index), replacing item 7's `AStar2D` search, whose tie-breaks are Godot's and unread, if it is fast enough: the P5 plan measures it first (review X3: the pathing spike's 200 pairs against `AStar2D` on the same mesh). Group orders share one search per (goal, size class, tick), dropped at the end of the tick, so who shares depends only on (goal, size class, tick, request order). Mesh updates when buildings land are capped per tick.
- **Avoidance design inputs** (for the avoidance milestone): moving units are soft (they push and are pushed, with pressure damping so crowds settle), parked units block their cell for search and movers, waiting units wake when a cell frees; each unit sums the pushes on itself so the result does not depend on iteration order. The neighbour query comes from one packed per-tick index (review X5: packed rebuild against incremental against today's grid). Hard cell occupancy for movers (OpenRA) matches the avoidance spike rules that jammed packed moves.
- **Split rates scope** (refines the [split rates decision](#performance-next-user-2026-11-11)): slower cadence applies to target rescans, retaliation joins and return-home scans; keeping the current target (lookup, hostility, range, engage or chase) stays per tick, because it decides how fast a unit reacts. The per-unit cost is expected to fall from packed storage, not from cadence.
- **Browser digests (review X7):** the golden scenarios run in the Firefox web bench and their digest lines are compared with native, as part of the golden scenarios work after the movement milestone; a CI job later only if cheap.
- **Rejected (agreed with the review's §8, among them):** fixed-point maths now (the 2026-11-09 decision stands: only with a native port); an ECS or component framework (packed columns per system instead); parallel work inside a tick (the compute-then-apply-in-order shape stays for kernels); a lower global simulation rate; GPU movement; path caches kept across ticks; hard cell occupancy for movers; a bot thread with a state copy; a whole port to Rust or C++ now (the native spike's conditional verdict is unchanged); a `streflop`-style libm (nothing to fix: only `sqrt` is allowed); diff-based range queries everywhere.

## Package review (user, 2026-11-13)

Questionnaire over the packages after two days of additions; result in [packages](../packages.md).

- **c1 dock rebuild:** tracked as package P1.1 "Laborers that pay" before P2, without renumbering P2 to P5; its card is a replay of card 1 (`p1-frc-economy`); F2 (Laborer back pack) rides on it.
- **P2 scope:** widened with menu quick wins (including the F5 paste fix) and F1 (scale legend), because the order sound alone is thin for a session.
- **P5:** P3's rider, the movement design, ends with movement cut into packages of 2 to 3 days each; P5 is the first of them.
- **Canary:** the late-game 3v3 canary and the recorded playtest match row move from P5 to P2's rider, so they feed the movement design (the audit answer wanted the canary before that design).
- **Engine packages:** a night lane: headless, unattended, no focus card, at most one between two day packages. Order: Sim quick wins, Flatter worst ticks, Relay guards, Adaptive input delay.
- **Adaptive input delay:** if a measured gain adopts it, one online session with a friend before it becomes the default; P1's card 2 is played in that session.
- **Card 3:** played soon in a free sitting on 0.11.0 with the helper switched on.
- **Roadmap page:** `docs/packages.md` becomes the one-screen "what comes when" page (now, day lane, night lane, later); scope stays in the blueprint and the reviews.
- **Blueprint:** a small pass later in its own session: take order and status out of §7 (they live in packages and STATUS) and check every done or not-done claim against its evidence; no full renumbering.
- **README roadmap** (branch `spike-visualization`): kept next to packages; its check is re-keyed from blueprint §7 headings to package names and its rows refreshed, merged in its own session after this one.

## Play with a friend (user, 2026-11-13)

Questionnaire after a research pass on simple ways to play 1:1 with a friend (research note private). Placements: the P2.2 row and a line under "Not ordered yet" in [packages](../packages.md).

- **Channel-neutral:** Discord was only an example of where a link gets sent (chat, SMS or a phone call do as well). Nothing is optimised for or integrated with a chat or storefront service: no Discord Activity or bot, no Steam features.
- **Target flow now: link only.** Host: Create, Copy link, send it by any channel; friend: click, pick a faction, Join (built in P2). A second, simpler round of questions the same day replaced the first round's "easy codes now" and "code before room" answers.
- **Hidden tab while sending the link (P2.2):** a lobby still waiting for its second player tolerates minutes of silence instead of the 10 s read deadline; the 10 s rule stays for started matches; the client's 5 s silence rule (`RelayTransport.silent`) gets the same lobby tolerance. Checked before deciding: the lobby phase ends before the relay's `start` message, from which replays, seeds and traces begin, so the wait does not touch replays or determinism; it fits the Relay guards package (hello deadline before `hello`, unstarted-lobby expiry of about 15 min as the upper bound, [netplay reference review](netplay-reference-review.md) S3/S4); the open M9 question of pausing or continuing while a seat is away in a running match ([dropped players](../questions/next-m9-drops.md) Q1) is unaffected. Whether browsers keep a hidden tab's WebSocket open for minutes: unverified, observed at P2's playtest with the hidden-tab check.
- **Rematch (P2.2):** a "Play again" button after a match: the room stays open, both press it, a new match starts with the same opponent and no new link.
- **Word codes:** only if reading a 6-character code to a friend on a call proves painful.
- **Permanent friend link, quick match:** the friend link is re-explored with the M9 lobby, together with other modern, easy ways to match up with friends; quick match comes after M9.

## New launcher (user, 2026-11-13)

Every screen is drawn in two sets with one layout, kept in [launcher mockups](../images/launcher-mockups/): `minimal-*` is P2.1, `fancy-*` is for later packages. Placement: P2.1 in [packages](../packages.md).

- **First round:** light tabs on top (Vs. Bot, With Friend, Settings; mockups deleted) in the dark game look, own package right after P2; superseded the same day by the sidebar decision below.
- **Second round: sidebar** with separate Vs. Bot and Play with Friend pages, drawn by ChatGPT in a primitive grey and a rich dark version (mockups deleted). The sidebar stays; its pages and the rich skin were superseded the same day by the picks below, made on labelled A/B pages.
- **Structure: one Play page.** Sidebar: Play, Join, Settings, Credits, version at the bottom. [Play](../images/launcher-mockups/minimal-play-bot.webp) holds your faction, an opponent slot switched between Bot and [Friend](../images/launcher-mockups/minimal-play-friend.webp), and the map; [Join](../images/launcher-mockups/minimal-join.webp) takes a match code. The Vs. Bot and Play with Friend pages are dropped: a 3v3 with friends and bots fits neither, so that split would have changed again at M9.
- **Two sets, one layout:** the minimal set keeps today's grey; the [fancy set](../images/launcher-mockups/fancy-play-bot.webp) uses the flat look of the [art direction](../art-direction/ART_DIRECTION.md): matte fills, square slabs, owner blue and red on the chosen faction, cyan for selected only, amber for the one start button, no icons, no backdrop. The ChatGPT skin (gradients, painted backdrop, painted map) is dropped.
- **Factions and map: dropdowns** in both sets. The fancy set adds the faction emblem and a map preview panel (thumbnail, start positions, supply sources).
- **Waiting for the friend: its own view** ([minimal](../images/launcher-mockups/minimal-waiting.webp), [fancy](../images/launcher-mockups/fancy-waiting.webp)): invite link with Copy, both player slots, the map, Cancel match. Part of P2.1.
- **Fast bot start:** the launcher opens on Play with Bot selected and the last settings preselected; no quick-match button. Part of P2.1.
- **Bot level and play style:** hidden in the minimal set until they exist (supersedes "shown, only Normal enabled" from the same day); the fancy set shows levels 1 to 5 and the play style.
- **No Back button** (every page is one sidebar click away) and **no mode-card start screen** (a dark start screen with two mode cards, mockup deleted); the launcher opens on a page directly.
- **Starting resources, game speed, Expert:** left out until the features exist; each control comes with its feature.
- **Emblems:** Wargrid's own, not the Zero Hour faction emblems the ChatGPT mockups resembled (EA trademarks). Single-colour, so each works in any owner colour (colour is ownership, art direction §6); abstract badge shapes, no machines: [USA](../images/launcher-mockups/emblem-usa.svg) a split arrowhead, [China](../images/launcher-mockups/emblem-china.svg) two chamfered plates with the lower one wider, [FRC](../images/launcher-mockups/emblem-frc.svg) a broken ring of three unequal pieces. Stars, wings, national symbols and letters are out. No search against existing logos was done (agent note: the arrowhead is the one to check before the fancy set ships).
- **Fancy set notes (agent assessment, for its planning):** the map picture is a thumbnail rendered from the real map data in Wargrid's look, not painted art; the thumbnails in the fancy mockups are sketches.
