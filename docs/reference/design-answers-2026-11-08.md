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
- **Two sets on one layout.** Core is the early package: words only and only the panels the game can feed today (selection panel, build and production grid with position keys Q W E R T, queue of nine, credits, power, Attack Move, Stop), with no simulation change. The position keys are an input change: E produces today, and W is a camera key in the sandbox scenes only; settled in the questionnaire below. Full adds glyphs, minimap, group row, idle builder, production strip, alert feed, Guard, Sell and the pinned factory, each with its feature. Core uses the flat dark look from the start, not today's grey. Placement: [packages](../packages.md).
- **Rows per kind, not cards** (user, 2026-11-13, confirmed after round 2): a large selection lists rows of name, count and health in two columns, so names are never cut and the panel has one width with or without glyphs. Replaces "cards per kind" above; click filters and shift-click adds as before.
- **Drawing calls, confirmed in the questionnaire below:** Core queue slots show the key of the cell that made the item; Sell appears only on a selected building, never on the pinned panel; no rally button, right-click on the ground stays, with a "Right-click ground: rally point" line in the factory panel. Still an agent call: minimap dots differ by shape as well as hue.
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
  - The card is small and was missed once on the page; the questionnaire below adds the forecast to the top strip.
- **Round 3, look** (picks as recommended):
  - *Judged on the game's own colours:* sand ground and the owner colours of `game/scripts/presentation/palette.gd`, not v3's muted backdrop. The dark slabs separate more clearly on the light ground.
  - *One type scale:* three text sizes with fixed roles and tabular numbers; the top strip is 32 px high with the credits at 16 px. Both liked as drawn.
  - *Typeface Inter* (SIL Open Font License) over Barlow Semi Condensed. The game needs a font file; this is the one to add with the theme.
  - *Glyphs, third pass:* bright top faces as the dominant mass, one ground line, at most six shapes each. Mock-up drawings, not game art.
  - *Dock height: tight.* The polished dock was 16 px taller, and that was feared to take too much of the screen (user, 2026-11-13). A second flip kept the type scale and took the height back: dock 168 px in the 1280x720 layout, rows 26 px, buttons 32 px, and the queue label moved into the title row so a production panel is only as wide as its nine slots (376 px against 484). Build cells grew from 88 to 100 px so a four-digit cost clears the key chip, which costs about one point of coverage while placing (agent call, confirmed in the questionnaire below against 96 px cells with a smaller glyph).
  - Coverage with all picks, measured on the mock-up at 1280x800: Full 6.6 % with nothing selected, 20.0 % with 120 units and a pinned factory, 21.8 % while placing; Core 1.0 %, 8.1 % and 16.9 %.
  - Agent call: the mock-ups show power as used / available ("11 / 10" is low power); today's status line prints supply / demand.
  - The mock-ups use the art sheets' lighter owner blue for the panel edge and progress bars; the questionnaire below decides for the game's own colours.
- **Questionnaire after round 3** (user, 2026-11-13; all as recommended; the new decisions are not in the pictures, the confirmations in the last line but one are):
  - *Keys:* W, A, S, D are no camera keys; W and E are grid keys (A and S are already Attack Move and Stop). In a match the camera already pans with the arrow keys only (`game/scripts/skirmish_main.gd`); W, A, S, D pan only in the sandbox scenes (`game/scripts/main.gd`) and are dropped there too, so the keys mean the same everywhere. Edge scrolling and right-drag come with P3. The question as asked said W pans the camera today; that was wrong for matches (agent error), which makes the answer cost nothing there.
  - *Refused orders:* the reason shows on one amber line just above the dock for about 3 s, in Core and Full. It replaces the status line's error text.
  - *Key hints:* the status line's key hints go; every button shows its own key, the mouse rules move to a short Controls list in the Esc menu, and Unload gets a button with its U key when a transport is selected.
  - *A selected enemy unit* shows in the selection panel like an own unit, name and health, with its owner's colour on the panel edge and no command buttons.
  - *Owner colour on the HUD* (panel edge, progress bars): the colour the game draws that owner's units in, the Neon set included when it is on, lightened only where it misses 3:1 against the dock. Agent arithmetic, not measured in the game: owner 1's blue is about 3.3:1, owner 2's red about 3.2:1, the purple about 2.8:1.
  - *Forecast in the top strip too:* while a building is armed for placement, the credits and power figures themselves show the values after the purchase, with the low-power warning; the card stays for hovering.
  - Confirmed as drawn: Sell only on a selected building; no rally button, with the rally line in the factory panel; key letters in Core queue slots (against a list of names, and against bringing glyphs into Core); build cells 100 px wide.
  - Next for the HUD: a headless check whether the game's shape parts can be drawn into a UI control, because it decides what glyphs cost; evidence only. The P2.3 design follows it. Run on 2026-11-13, headless and then in one window: baked shape parts draw in a `Control` in the right order and colours, and two-tone silhouettes read at 28 px ([map art](#map-art-faction-shapes-m75-user-2026-11-13), questionnaire after round 3).
- **Edge scrolling against the dock** (user, 2026-11-13, P2.3 planning): P3's edge scrolling works in a band at every screen edge, also where a dock slab touches it, as in Zero Hour (a 3 px band at all four edges with no HUD exception, `GeneralsGameCode` @ `afc2a103f` `LookAtXlat.cpp:80,358`).


## Unit avoidance: scope

- Re-pin every trace and pinned test once, at the end; no switch to turn avoidance off.
- Extra simulation cost on the 300-unit benchmark: about 0.5 ms per tick at most (half of today's headroom under the 1.82 ms budget).
- Experiments: the benchmark layouts (dense walls with gaps, docks) first, then Dry Wells.
- First version covers moving units only; arrival spreading keeps today's reserved destination cells.
- Revised (user, 2026-11-13): the order "movement and pathing is its own milestone before the unit avoidance milestone; avoidance is then designed on the finished movement model" becomes a core avoidance package right after core movement and advanced avoidance later, both on the new movement base, behind a toggle key ([second pass](#package-review-second-pass-user-2026-11-13-night)).

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
  - Revised (user, 2026-11-13): movement and avoidance ship as core slices soon and advanced slices later, both on the new movement base ([second pass](#package-review-second-pass-user-2026-11-13-night)).
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

## Worker-thread experiment preparation (user, 2026-11-14)

- First deliverable: a scratch experiment with measurements, not a production `SimPump` implementation. Architecture reference: [worker thread design](../superpowers/specs/2026-11-12-worker-thread-design.md).
- Base: One controller after integration, not its unmerged branch.
- Overnight scope: headless checks. Rendered browser measurements remain an attended follow-up; headless results alone do not establish the design's browser performance go/no-go.
- These choices define preparation scope; implementation still requires an explicit start.
- Second round (user, 2026-11-14): Flatter worst ticks first; the spike goes at the end of the night lane. A Safari and Chromium check of a threaded export comes first, attended. Thin scope: a scratch worker driver in the real match scene, a headless digest check, threaded exports built overnight, plus one fault probe (a script error in the worker fails loudly, no hang); the full reader audit and other fault probes only after a go. Lever A1 (step and hand-off in separate frames, no threads) is a third arm in the browser A/B. Go rule: a gain above twice the A/A spread on skirmish3v3 and the team match against the better of current `main` and A1, no worse frame tails; hordes300 reported as stress, outside the rule.

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

## Package review, second pass (user, 2026-11-13 night)

Questionnaire over the packages after the HUD v4 and map art additions; result in [packages](../packages.md) and [STATUS](../STATUS.md#packages).

- **P2.3 HUD core splits into two day packages** (user, 2026-11-13): P2.3a "See your selection" (flat dark theme and Inter, top strip, selection panel, refusal line, owner colour, stretch aspect `expand` and edge anchoring: everything P2.5 needs) and P2.3b "Build from the dock" (build and production grid with position keys, queue, forecast and shortfall card, Unload, key on every button, Controls list in the Esc menu). P2.5 needs P2.3a only; P3's edge scrolling is built against P2.3a's dock.
- **Controller flattening (FIX-6) becomes its own night package, "One controller", before P2.3a** (user, 2026-11-13): night 2 after Tighter gates; the later night packages move down one. The `SimPump` seam stays in Later 3, which changes "the `SimPump` seam goes with controller flattening" from the [planning overhaul](#planning-overhaul-packages-and-playtest-tooling-user-2026-11-11-night).
- **The movement design moves from P3's rider to P2.1's** (user, 2026-11-13), written during the launcher days so P5 can be planned when its turn comes; P3 has no rider. Day lane order unchanged.
- **Gates of P2.3a and P2.3b:** a rendered benchmark row with the HUD in the scene and a 120-unit selection (user, 2026-11-13).
- **P2.1 keeps the Fullscreen setting; stretch aspect `expand`, HUD anchoring and the non-16:9 layout test move to P2.3a** (user, 2026-11-13), because anchoring today's status line would be thrown away. `expand` shows more map on a wide screen, which is a vision edge online and a draw cost the 1280x720 benchmark misses, so P2.3a also gets a rendered row at a wide window size.
- **Hello deadline and unstarted-lobby expiry move from Relay guards into P2.2 Quick rematch** (user, 2026-11-13): P2.2 lets a lobby wait minutes, so the cap on that wait ships with it. Relay guards keeps the lead bound, the relay hash comparison, the per-IP limits, the `MATCH END` byte fields and the `WebSocketPeer` rider.
- **The web hotkey check moves to order controls as its first step** (user, 2026-11-13): which decided keys a browser takes before the game ([F10](../STATUS.md#findings-list)); P3 checks Space itself. The only check left before the P2.3 designs is whether tabular numbers render in the web build; the glyph silhouettes were checked in a window inside the [map art spike](#map-art-faction-shapes-m75-user-2026-11-13).
- **HUD glyphs come after P2.6** (user, 2026-11-13): in the windowed check Vehicle Factory and Headquarters were the same rhombus until the faction bodies exist.
- **Order controls gains** the comma key for the next idle army unit, the control-group row and the idle-builder button (user, 2026-11-13), so each HUD Full item lands with its control.
- **Later 3 is renamed** (user, 2026-11-13): it holds the minimap rectangle, the base-under-attack alert and the `SimPump` seam, no longer a "minimal real HUD" and no longer FIX-6.
- **Findings list destinations** (user, 2026-11-13): budget rows exceeded go to Sim quick wins and Flatter worst ticks; F10 to order controls' hotkey check; air collector full load, F8, F9 and the repeat friend match are parked.
- The names "See your selection", "Build from the dock", "One controller" and "Minimap and attack alerts" are proposed (agent, 2026-11-13) per the [wording rule](../roadmap-wording.md).

Movement and avoidance, same questionnaire (user, 2026-11-13):
- **Core slices soon, advanced slices later, both on the new movement base.** Avoidance is not built on today's grid, because the new base changes the cell model: moving units lock no cells. This revises the order "movement and pathing is its own milestone before the unit avoidance milestone" ([movement and pathing](#movement-and-pathing-user-2026-11-10)).
- **Core movement** (day package P5, replacing "Smarter paths (toggle)"): the provisional base method in minimal form (rectangle navmesh B, the finer grid A as reference and as fallback if B fails the stuck check), individual routes, body-safe straightening, moving units never lock cells (only stopped units, reference-counted, the Permafrost rule above), behind a toggle key. First step: the seeded fuzz and invariant test, moved from P4's rider. The movement lab is reduced to what core needs: navmesh against finer-grid path shape, body-safe against centre-line straightening. The cross-platform path determinism test comes early (item 8 of the 2026-11-10 list).
- **Core avoidance** (day package P6, after core movement): moving units yield and steer around each other, starting from the avoidance spike's Zero Hour style yielding (approach A, branch `spike-avoidance`, `docs/reference/unit-avoidance-spike.md` there), behind a toggle key; cost cap as in [unit avoidance: scope](#unit-avoidance-scope) (about 0.5 ms per tick on the 300-unit benchmark).
- **Advanced slices, later packages:** three size classes, local navmesh updates on building placement, the route budget per tick (8 against 32 against all, or a searched-cell cap), shared trunks or flow fields for big orders, formations and keep formation; arrival spreading, crusher rules, the open questions of avoidance round 2, soft movers. Each toggle becomes the default with one trace re-pin, so the "two trace re-pins accepted" count stands (one for movement, one for avoidance).
- **Day lane order:** P2.3b, core movement, P2.4, core avoidance, P2.5, P2.6, then P3 camera and P4 smooth motion. P4 stays its own package after P3.
- **The movement design** (P2.1's rider) designs the core movement and core avoidance packages and cuts the advanced ones into packages.
- **Golden scenarios** stay after movement: after the advanced movement packages make its toggle the default.
- The names "Units that find their way", "Units that make room", "Smoother big moves" and "Crowds that sort themselves" are proposed (agent, 2026-11-13).

Answers to the contradictions found while placing these (user, 2026-11-13):
- **P6 starts from soft movers** (user, 2026-11-13): moving units push and are pushed, with pressure damping, and parked units block their cell, as in the [simulation review answers](#simulation-reference-review-user-2026-11-13). Approach A (yielding) stays a reference only. Pressure tuning, crusher rules and the round 2 questions stay in advanced avoidance. Replaces "starting from approach A" above.
- **The path budget goes into P5** (user, 2026-11-13): deferred path delivery under a searched-node budget, as the simulation review answers placed it, because a big order must get every unit moving within a tick or two. The 2026-11-10 lab's "8 against 32 against all" comparison moves into P5's lab as the budget size check (response to the click against cost). Shared group searches and trunks or flow fields stay advanced. Replaces the route budget in the advanced list above.
- **P6 keeps the 0.5 ms per tick cap** (user, 2026-11-13): its design measures the soft-mover cost first; going over the cap is a stop for the user to decide, never loosened. No avoidance spike variant met the cap (rounds 1 to 4).
- **One controller is planned as small resumable tasks with a resume record and may span one or two nights** (user, 2026-11-13). The audit's manual offline and online match in a window becomes a short attended check before P2.3a starts, not part of P2.3a's playtest.

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

## Map art: faction shapes (M7.5; user, 2026-11-13)

A design spike on branch `spike-art`: no game code changed. Candidates were shown on labelled A/B pages that draw the game's own shapes: a headless script exported every shape of `game/scripts/presentation/shapes.gd` with the palette and projection, and the page redraws them with the same bake rules, so a candidate is the same data edited. Judged at the three zoom steps, smallest first, on the game's ground and owner colours, each role beside the other factions' version, in a small base under the [HUD v4](../images/hud-v4/notes.md) mock-up layer, and as a single-colour silhouette at HUD glyph size. The pages, the build spec, the exported shapes and the candidate data are working files in the private notes repository (`art-spike/`). Pictures: [map art](../images/map-art/notes.md).

Starting point (inventory of the code at `10b9423`): 37 definitions, of which 24 share 9 shapes across factions, colour being the only difference: Headquarters, Supply Depot, Vehicle Factory and Barracks in all three factions (FRC calls its own Supply Cache and Vehicle Yard), Power Plant in USA and China (FRC has none), rifle and rocket infantry in all three, the bulldozer in USA and China, the light vehicle in USA and FRC. Factory and Headquarters share one slab; the factory adds a door, the Headquarters one roof box.

**Round 1, the five shared buildings** (user, 2026-11-13; all six picks as recommended, no comments; the recorded view at each pick was the base view at zoom 0.5 with the Neon set on the dark ground):
- **Own body per faction ("bold") for Barracks, Vehicle Factory, Headquarters, Supply Depot and Power Plant,** against "restrained" (today's body with faction parts on and beside it) and against today's shared shape. The role cue is the same in every faction (barracks low with repeated rooms, power plant two drums, depot an open pad under lifting gear, factory one hall with a wide dark door, headquarters the tallest with a tower or mast); the faction changes the construction: USA symmetric with centred modules, China a thick plinth and mass that steps inwards, FRC unequal boxes pushed together off-centre. These three constructions were proposals in the [art direction](../art-direction/ART_DIRECTION.md); for buildings they are now picked.
- **No wedge primitive.** China's buildings were also drawn with true sloped faces; stepped boxes were picked, so "boxes and cylinders" stands. Agent note: the slopes clearly helped only the factory; vehicle hulls are the stronger case and may be asked again.

Agent assessment from the round, not user decisions:
- At zoom 0.5 the restrained factories and barracks of the three factions could not be told apart; their faction parts were 2 to 4 px.
- Cost is shape data plus splitting five roles by faction in `Shapes.role()` and its pinned test. The picked bodies no longer use the shared four-part slab, so each needs its own rule for the decided damage look (missing corner, darker roof); the drawing agents described one per shape, none was drawn.
- All candidates pass a JavaScript port of the shape audit's paint-order and footprint rules (`game/tests/test_shape_audit.gd`) at heading 0, undamaged. Not run in Godot.
- At zoom 0.5 the game draws a cylinder with four sides (`game/scripts/presentation/shape_bake.gd`), so the power plant's drums are square posts at the smallest zoom.
- Baked from the shape parts as one flat colour, most buildings are the same lozenge at 22 and 28 px; two tones help somewhat. A headless probe drew baked shape parts into a `Control` through the same call the world uses without errors; pixels are unproven without a window (windowed run: questionnaire after round 3 below). Both feed the HUD's choice between baked and hand-drawn glyphs.

**Round 2, the four shared unit shapes** (user, 2026-11-13; no comments; the recorded views were the base view on the dark ground with the default set, three of four at zoom 1; asked afterwards, the dark ground was only being looked at, so rounds keep opening on sand):
- **Rifle and rocket infantry get faction versions, the "restrained" ones:** today's body and height, the faction in headgear, pack or weapon. Picked against the agent recommendation to keep one shared soldier.
- **Bulldozer: own body for USA and China ("bold").** USA narrow with a tall rear cab, China low with a wide blade. FRC builds with the Laborer, which keeps its shape.
- **Scout Car and Armed Pickup become two vehicles ("bold"):** a low closed car, and a pickup with an off-centre cab, an open bed and a gun on a post. The picked car is lower than a tank; today's shared shape is taller than one.

Agent assessment from round 2:
- At zoom 0.5 a soldier is about 8 px tall at the decided true size. Three drawing agents and the coordinator each found that the faction cannot be read on infantry there in either option; it shows from zoom 1 and in the HUD glyphs. So the requirement to tell faction apart at the smallest zoom is met for buildings and vehicles and not for infantry.
- The picked bulldozers and the Scout Car change heights that `game/tests/test_shapes.gd` pins, and four more roles split by faction.
- The shape audit limits infantry: one thin weapon per soldier, the launcher touching the torso and under 0.4 cells long, and an owner-colour share of the drawn area (`game/tests/test_shape_audit.gd`).
- Candidates were checked for paint order at eight headings; the game's audit samples two of its 64 heading steps for paint order. Today's shared rifle infantry has one wrong sample at a heading the game does not test.
- The four tanks were not redrawn; their hulls differ by 0.05 to 0.15 cells, 1 to 3 px at zoom 0.5, and the two China tanks share one hull.

**Round 3, the placeholders** (user, 2026-11-13; all five picks as recommended, no comments; judged on sand with the default set). Covers findings F6 and F7 of the [status list](../STATUS.md#findings-list) as far as the look goes:
- **Supply piles show their fill as rows of pallets that empty from one end,** so the share of cargo against bare pad is the fill level; picked against one stack that loses height. Both pile sizes, no text. This gives the 2026-11-09 answer "the stack shrinks; the number is in the selection panel" ([look questions](../questions/next-m75-art-look.md) Q12) its form: the cargo still shrinks with the box count, as rows, not as one stack (confirmed when asked, user, 2026-11-13). Today the pile draws the same four crates from 40 to 400 boxes. Agent note: one pallet per 20 boxes would give the big source 20 steps from one shape.
- **Cargo colour pale steel `#DDE4E6`** in place of amber `#F7C871`, which is also the HUD's "needs you now" colour. Computed against sand: amber 2.01, pale steel 2.44 (pure white would reach 3.14, so no cargo colour passes 3:1 there); amber sits at a colour distance (CIE76) of 21 from the gold owner, pale steel at about 42 from the nearest owner colour of either set. Cargo is the neutral owner's colour in `game/scripts/presentation/palette.gd`, so the change reaches everything neutral-owned.
- **Salvage crate: a small crate beside a drum on an oblong ground mat,** in place of the 4 px square. Agent assessment: the mat makes it findable beside a crowd at zoom 0.5; on a dark plate the same crate looked like a small supply pile.
- **Construction: the building rises inside four thin corner posts at its final height,** so progress reads as how full the frame is and posts alone mean just started or paused. Picked against today's rise without the text, where half built reads as a finished, lower building (the game scales the shape's height, `game/scripts/presentation/world_batch.gd`). The building still rises as answered on 2026-11-09 (Q14), now inside the posts.
- **Supply Helicopter: a tandem-rotor transport,** a long owner-coloured hull with a rotor cross at each end and a cargo pod, picked against a single rotor with a slung load. Both rotors stay fixed parts: a fixed part keeps its own orientation while its pivot turns with the hull (`game/scripts/presentation/shape_bake.gd`), so each rotor follows its end of the body.

Agent assessment from round 3:
- The pile and construction text carries numbers the player uses (boxes left, collectors docked and waiting, build percent). With the text gone they belong in the selection panel, as answered on 2026-11-09 (Q11, Q12); that is HUD work, so the two should land together or the gap be accepted.
- Cost: shape data, a few lines of drawing code for the pile's fill steps, the crate and the site posts (the posts are not part of the building's shape), one palette value. Removing the labels removes the game's only text on the map.
- Open after the picks: the crate's top took the cargo colour and would sit pale on its mat; the pictures show an agent choice made afterwards (grey crate, dark drum, cream mat), accepted in the questionnaire below. The helicopter's cargo pod is in the skin colour, the only pale neutral a unit shape has, because colour slots resolve per owner. The paused construction case was not drawn.
- Today's helicopter rotor is a fixed part 0.1 cells off the anchor with no pivot, while the hull, also 0.1 off, turns about the anchor, so hull and rotor drift apart as it turns; possibly part of F7's "moves oddly". Read from the shape data, not checked in the game. Motion stays with the aircraft work.

**Questionnaire after round 3** (user, 2026-11-13; all as recommended except the last but one):
- The numbers the map text carried go into the HUD core package: its selection panel shows boxes left and collectors docked and waiting for a selected pile, and build percent for a selected construction site. P2.5 then removes the text with no gap.
- P2.4 "Three armies" goes before the HUD core package if it is ready first.
- The game's shape audit checks paint order at eight headings from P2.4 on, and today's rifle infantry gets its one-sample fault fixed there.
- Every ground batch package brings its new units' shapes in the picked faction look; no later art pass over them.
- The salvage crate's colours stay as drawn: grey crate, dark drum, cream mat. Known weak spot (agent): the crate's top is the grey of rubble; mat and size tell them apart.
- The windowed check of shape parts in a UI control is run at once (the recommendation was the next session). Result (agent run), one window, Godot 4.7.2 with the compatibility renderer, today's shapes at 22, 28 and 64 px on one dark slab colour: the shapes draw in a `Control` through the same call the world uses, in the right order, hard-edged and without seams; the control must clip its contents; sizes are layout pixels, because the game stretches its 1280x720 layout. As one flat colour, infantry and, barely, the helicopter read at 22 px, the tank loses its barrel at 22 px, and Vehicle Factory and Headquarters are the same rhombus at every size. In two tones (top faces light, other faces muted) all five tested shapes are recognisable at 28 px; at 22 px the two buildings differ by a roof block of 2 to 3 px. Agent assessment: baked two-tone glyphs are workable for units and need the picked faction bodies to tell buildings apart; a glyph control is about 40 lines on public calls, no game change. Not proven: other renderers and GPUs, the web build, the game's stretched and HiDPI scales (the run turned the stretch off), clipping inside scrolled containers, the cost of many glyphs.
- Second half of the spike, in this order: damage looks for the 14 new building bodies (P2.6's first step), tanks with the wedge asked again for hulls, detail per zoom step, the weak spots of rounds 1 to 3; then ground, owner colours, cliffs and decoration.

**Round 4, prettier shapes** (user, 2026-11-14; all six picks as recommended, no comments; judged on sand with the default set, Row view):
- **Damaged buildings lose their corners on the camera side:** at 70 % one corner facing the camera goes and the remaining roof turns dark, at 35 % a second, different corner goes and one thin smoke column rises, clear of doors and the Headquarters tower. Drawn for all 14 picked bodies; picked against corners taken off the rear and the skyline, and against today's shared-slab rule. This is P2.6's first step.
- **Tanks tell their faction by hull outline, boxes only:** USA long and slim, China broad (both China tanks share the hull and differ by turret: one long barrel against a short twin-barrel block), FRC short with a set-back, lopsided turret. Picked against the same tanks with sloped hull plates, so "boxes and cylinders" stands for hulls too.
- **Zoom 0.5 draws the same parts as zoom 1;** **zoom 2 adds up to four finishing parts per shape** (window bands, vents, track bands, hatches) that leave the outline unchanged. This narrows the 2026-11-09 answer "one detail level per zoom step" to an added level at zoom 2; at zoom 0.5 cylinders still lose sides as today.
- **Weak spots fixed:** China's power plant drums now clearly top its barracks, which is the lowest building again; FRC's barracks reads as three unequal rooms in a row; the USA soldier's pale head shows under the helmet; the Scout Car's and Armed Pickup's guns are at least 2 px at zoom 1.

**Questionnaire after round 4** (user, 2026-11-14; all as recommended):
- FRC's tank goes back to today's hull length (0.7 cells) and the Armed Pickup is shortened to about 0.65, so the tank stays the bigger vehicle; the round 4 drawing had the tank at 0.56 and the pickup at 0.86.
- The zoom-dependent drawing code (`_build_parts` reading the detail level, which today it ignores) rides with P2.4, with its units' zoom 2 versions; P2.6 brings the buildings' zoom 2 versions.
- Round 5 (ground, owner colours, cliffs, decoration) follows in the same session.

Agent assessment from round 4:
- Cutting a corner out of one box means splitting it, so a damaged body can have more primitives than the healthy one; the healthy shape is unchanged.
- At zoom 0.5 every building and tank part is already at least 2 px wide; only weapons on small units are thinner, and dropping them removes the unit's role cue. So a reduced zoom 0.5 level gains nothing; the thicker weapons go into the shape at every zoom instead.
- At zoom 0.5 a sloped hull plate is a slightly darker face, too little for a new primitive.
- The faction tanks change hull sizes that `game/tests/test_shapes.gd` pins; the USA soldier fix widens the torso slightly to keep the owner-colour share above the audit's 30 %. Neither is checked in Godot.
- The zoom 0.5 and zoom 2 tank versions on the page were built on today's hulls; P2.4 redraws them on the picked hulls.

**Round 5, the world** (user, 2026-11-14; all six picks as recommended, no comments; judged in the base view at zoom 0.5, mostly on sand):
- **Darker unit and building sides** (`SIDE` `#1c2e39`, `SIDE_DARK` `#0e1b23` in `game/scripts/presentation/palette.gd`), so the dark side band reaches 3:1 on both grounds (`SIDE` 4.46 on sand and 3.05 on the dark ground, against 2.63 and 1.80 today); picked against today's sides with a tighter, darker contact shadow.
- **Lifted default owner colours:** `44adf4 d54f3b 4fc389 ecdc3c e08522 9249ac 008d8d ffa5d4` in place of today's set. Every owner pair stays at least 22 apart (CIELAB distance) in normal vision and under simulated deuteranopia and protanopia (today's blue and purple: 5.2), and gold moves away from sand. No owner top reaches 3:1 against sand, which would need an almost black or almost white colour; the side band carries the outline. Picked against richer, darker owners.
- **Neon stays opt-in;** the default set stays the default.
- **Firmer cliffs:** top lightened 0.22 and sides darkened 0.55 (today 0.15 and 0.4), height unchanged, so the side reaches 3.23 against sand (today 2.3); picked against today's cliffs with a thin lit rim on the top edge.
- **Decoration lies flat on the ground:** roads as lighter strips, rock plates and tree discs with flat shadows, water as a muted blue-grey surface; nothing has height, so nothing can hide a unit. Picked against low raised rocks and tree clusters. None of it exists in the code.
- **Fog at 0.65 brightness** rather than half, so frozen buildings and the side band keep more contrast and the fog edge stays visible.

**Questionnaire after round 5** (user, 2026-11-14; all as recommended):
- Fog brightness 0.65 replaces half brightness (Zero Hour's default, answered 2026-11-10 with "re-check once the ground is sand") as the fog package's starting value; the fog package confirms it in the game, since the page only multiplied brightness.
- The palette changes (side band, owner colours, cliffs) ride with P2.4.
- Flat decoration lands with the next map ports, whose converter learns roads, rocks, trees and water.
- The Neon set fails the colour-vision check (blue against purple 1.5 under deuteranopia) and its teal `#00d8e8` sits close to the HUD's cyan: recorded on the findings list.

Agent assessment from round 5:
- With the darker sides, building sides look nearly black at zoom 1 on the dark ground and doors on side faces lose contrast.
- A unit standing right in front of a cliff face loses its side band against the dark face (contrast 1.1 to 1.5) with either cliff option; its owner-coloured top carries it there.
- Under either fog value some frozen owner pairs fall under the colour-vision distance of 20.
- Raised decoration would have to be drawn in the terrain layer and sorted with the cliff cells to stay under units; the picked flat decoration needs neither. Raised cliff cells are blocked today, so no unit stands on top of a cliff.
- The game's per-cell ground shade is at most 4 % either way.

Contrast, computed (WCAG relative luminance): no owner colour of the default set reaches 3:1 against the sand ground `#A88E5C` (blue 1.68, red 1.72, green 1.27, gold 1.30, orange 1.02, purple 1.94, teal 1.05, pink 1.19), and the Neon set does not either (best: yellow 2.40). A shape separates from the sand through its dark side faces (`#263842` 3.87, `#3D515F` 2.63). On the dark biome `#7B7566` the side faces drop to 2.65 and 1.80, and only Neon yellow passes (3.50). **Owner colour against ground goes to an A/B in a later round (done: round 5, 2026-11-14) of this spike** (user, 2026-11-13), part of its second half.

**P2.4 prep questionnaire** (user, 2026-11-14; all eight as recommended, after the research below; P2.4's design and plan are written when the package starts):
- Straight swap: the picked unit shapes replace today's; no look toggle.
- The palette changes (side band, owner colours, cliffs) go in their own commit inside P2.4, so the golden output re-pins once for colours and once for shapes; whatever fixes the Neon finding F12 (not yet picked) rides in that commit.
- P2.4 starts with the eight-heading paint-order audit, run on today's shapes, with zero wrong samples allowed at every heading.
- P2.4 draws the missing zoom 2 versions: the three rocket infantry, both bulldozers, the Armed Pickup and the four tanks on their picked hulls (the page's zoom 2 tanks sit on today's hulls).
- Tanks are nudged to exactly 3 units tall, keeping the Zero Hour height-to-length rule (picked: USA 3.1, 3.2 at zoom 2; FRC 2.9). Light vehicles and bulldozers keep their drawn heights and are re-pinned (Scout Car 2.7, Armed Pickup 3.95, USA bulldozer 4.95, China bulldozer 4.2; today 4.5).
- The identity audit's rule becomes "zoom 0.5 and zoom 1 draw the same parts; zoom 2 keeps every part and primitive and adds at most four", so zoom 2 versions are drawn as supersets.
- The firmer cliff factors (top lightened 0.22, sides darkened 0.55) apply to the dark biome too, which has hand-set cliff colours today.
- Branch `spike-art` was rebased onto `main` first (clean).

Research for the questionnaire (agent, 2026-11-14; page-side counts from the spike's own triangle counter, which matches the game's exported counts at heading 0; nothing run in Godot):
- **Triangles per tick (estimate),** mean over the 64 headings, today against picked: team match army (210 units and 6 builders) 5487 to 7250 at zoom 0.5 (+32 %), 6974 to 8964 at zoom 1 (+29 %), 8370 to 11837 at zoom 2 (+41 %). The rendered benchmark's open, dense and Ashfall layouts are 300 Scout Cars, the unit that grows most: 7050 to 10575 (+50 %; +75 % at zoom 2). Horde layout +22 %. Zoom 2 counts use the zoom 1 parts where no zoom 2 version exists yet, and the page's zoom 2 tanks sit on today's hulls, so they are provisional. At a rough two-point slope from the art lab's headless Low and High rows (about 0.075 ms per 1000 triangles per tick; shadows and a higher detail level are mixed in; [performance ledger](performance.md#art-lab-exit-rerun-2026-11-10-tree-96f89e8)) that is about +0.26 ms rendered tick-frame p95 on those layouts at zoom 0.5, from 64-70 % to about 73-79 % of the budget against the single-run P2 gate rows (worst: open; runs on one tree spread by about 0.5 ms), and about +0.18 ms on the horde layout, which has no P2 gate row and last measured about 6 ms (art lab, 2026-11-10). Agent judgement, not measured: the cost is the CPU append in `WorldBatch.build`, and counts this small barely load the GPU. The gate overstates a real match, whose mix grows by about a third.
- **Tests the picks touch:** in `game/tests/test_shapes.gd` the role map SH7, turret parts SH9 and SH9b (USA tank turret is the third part, FRC pivot moves), heights SH12, hulls SH13 (USA 0.9 x 0.4, China 0.76 x 0.68, FRC 0.7 x 0.46), tank parts SH14 (USA and FRC tracks and deck), side colours SH15, infantry SH16 (the USA helmet is a fourth cylinder, the USA torso 0.17 wide and its head 1.15 tall, against 0.16 and 1.3), the bulldozer and head-fan checks SH17 and SH18 (they name shared roles; under the USA helmet SH18 finds no head top), cliff factors W1; in `test_shape_audit.gd` the shared role lists and SA7's infantry and laborer pair, identity SA3, paint order SA4 (two headings), owner-colour share SA5 (China rifle at zoom 2 about 23 % on the page's raster against SA5's 30 % floor, USA rocket at zoom 0.5 and USA tank at zoom 2 at the floor), the weapon rule SA6 (China's rocket launcher sits 0.13 cells off the torso and is 0.4 long, limits 0.08 and under 0.4); in `test_world_batch.gd` the golden output. At eight headings today's three rifle infantry have one wrong sample at heading 6, the picked FRC rifle two.
- **Code:** `Shapes.role()` already gives each tank its own role; rifle and rocket infantry, bulldozer and light vehicle split by faction. `_build_parts` reads the detail level only for the fallback shape; its cache is already keyed by detail. `WorldBatch.INFANTRY_ROLES` gives infantry their wide click box, so faction infantry roles must join it (a view test covers only the USA rifle). Palette: `OWNER_BASE`, `SIDE`, `SIDE_DARK` and the cliff factors in `ground_set`; the art lab's sand steps reuse `ground_set`.

Where the game differs from decided answers (inventory, 2026-11-13; none changed by this spike): selection is drawn green (`game/scripts/presentation/world_view.gd`), decided white; supply sources show two lines of text and construction a percentage, decided no text on the map; vehicle wrecks exist only in the art lab, and a death shows a dark ground patch that fades in two seconds, not a body that fades; a zoom step changes only the number of cylinder sides, decided one detail level per zoom step; big supply sources look the same from 40 to 400 boxes; salvage crates are a 4 px square.

Not tested: anything in the game, motion, effects, fog, a fight, the rendered benchmark, colour-vision deficiencies beyond a computed table on the page.
