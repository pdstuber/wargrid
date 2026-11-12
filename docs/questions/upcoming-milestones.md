# Open game-design points after unit avoidance (ground batch A, M7.5, M7.6, M7.9, batch B, M8, M8.1)
## Findings (short, cited)
- Source, blueprint §7: M7.5, M7.6, M7.9, M8, M8.1 scopes are "proposed, not approved"; batch A gates are "proposed (not approved)"; batch B and M7.6 "scope not designed". Already user-decided, not asked: rank-gated units by building prerequisites only, all shells travel, upgrade split, A/B pages in Firefox for art, five levels, fair bots, play styles with "random", fog before bots, lobby look.
- Source, ZH shroud: every player starts fully shrouded ("passive shroud" 1,0) - GeneralsMD/Code/GameEngine/Source/GameLogic/Object/PartitionManager.cpp:1243. Shroud is modelled for all players so it can be checksummed in net games (same file, ~1236-1239).
- Source, ZH: an enemy unit is shown only while its cells are clear; an enemy IMMOBILE building stays visible fogged once ever seen; mines never (PartitionManager.cpp:1672-1677).
- Source, ZH: `ShroudOn` default TRUE (GlobalData.cpp:555 area, parse at :500); `FogOfWarOn` default FALSE (GlobalData.cpp:556, parse :501). Fog-of-war toggle is a debug key (CommandXlat.cpp:4180). So retail ZH skirmish effectively has shroud (black until explored) but NO re-darkening fog by default - inferred from these defaults; not verified with retail INI.
- Source, ZH: vision for shroud clearing defaults to the unit's vision range when unset (Object.cpp:295-297); buildings under construction reveal nothing (Object.cpp:4842).
- Source, ZH build queue has 9 physical buttons (GameClient/ControlBar.h:414). Rally point is shown in-world (ControlBarCommand.cpp:494-502). Radar has an attack-glow flag (ControlBar.cpp:960, GlobalData-like member).
- Source, ZH AI: difficulty (easy/normal/hard) only picks a per-side count of desired supply gatherers in the shown code (AIPlayer.cpp:198-211); more difficulty knobs not looked up beyond that.
- Not found: a cheap single ZH rule for squad/play-style names (aggressive/economic/defensive/raider) - ZH has none; that is a Wargrid addition.

## Questions
Q1. Should the whole map start black (shroud), as in Zero Hour?
   a) Yes, black until first explored - ZH default (PartitionManager.cpp:1243, GlobalData.cpp:555)   b) No, map visible, only enemy units hidden outside vision   c) Option per match
   Recommendation: a, because it is the ZH feel and scouting matters. Why it matters: decides explored-state storage and minimap look.

Q2. Once you have seen an area and left it, should it go dark again (fog), hiding enemy movement?
   a) Yes, explored but not visible = fog, enemy units hidden   b) No, explored stays fully visible forever - ZH retail default (FogOfWarOn FALSE, GlobalData.cpp:556; inferred)   c) Fog only dims terrain, enemy units still hidden
   Recommendation: a, because blueprint §M7.9 and fair bots already promise "fog (explored, not visible now)" and bots need a limited picture. Why it matters: ZH default conflicts with the blueprint text; one must change.

Q3. After you have seen an enemy building and lose sight of it, what do you see?
   a) A remembered ghost of the building, shown fogged - ZH default (PartitionManager.cpp:1672-1677)   b) Nothing until seen again   c) Ghost, but it vanishes after some time
   Recommendation: a, because bots/humans need a base map. Why it matters: ghost objects are extra snapshot state.

Q4. Do teammates share vision?
   a) Yes, fully shared inside a team (blueprint starting point; ZH allies share via the ally logic, PartitionManager.cpp:2975 comment, not read in full)   b) Shared only for buildings   c) Not shared
   Recommendation: a, because 3v3 needs it and bot coordination is planned on team-shared vision. Why it matters: affects every vision test.

Q5. Should a building under construction reveal terrain?
   a) No - ZH default (Object.cpp:4842)   b) Yes from placement   c) Yes once half built
   Recommendation: a, because it is the ZH rule. Why it matters: stops cheap scouting with a dropped foundation.

Q6. How should bots play at the weakest level?
   a) Slow and clumsy: fewer commands, no scouting, weak fights   b) Same play but small economy handicap - ZH style (difficulty changes gatherer count, AIPlayer.cpp:203-211)   c) Plays well but pauses often
   Recommendation: a, because no fake weakness and no rule changes were decided (blueprint M8.1). Why it matters: b contradicts that decision; pick it only for ZH feel.

Q7. How many play styles ship, and is "random" a default?
   a) Five (aggressive, economic, defensive, raider, adaptive), random default   b) Three (aggressive, economic, defensive)   c) None until M9 lobby needs it
   Recommendation: b, because fewer styles are testable and still readable. Why it matters: each style needs a strength-band test. ZH default: none (ZH has no styles).

Q8. How strictly should a bot be limited in orders per minute?
   a) Hard cap, human-plausible (say ~60-120 per minute at top level), lower on weaker levels   b) Soft: allowed bursts in fights   c) No cap, only reaction delay
   Recommendation: a, because it keeps one number to tune. Why it matters: sets what "fair" feels like. ZH default: no cap (not looked up).

Q9. Should bots ever surrender or leave when losing?
   a) Never, play to the end   b) Offer surrender when hopeless and the human can refuse   c) Resign automatically
   Recommendation: a, because simplest and matches ZH (not looked up). Why it matters: affects the end of every solo match.

Q10. Where should the bot attack first by default?
   a) Nearest enemy base   b) Weakest or least defended visible target   c) Depends on play style
   Recommendation: c, because styles need a visible difference. Why it matters: shapes how every game opens. ZH default: not looked up.

Q11. HUD: how many build-queue slots per factory?
   a) Nine, as in ZH (ControlBar.h:414)   b) Five   c) Unlimited queue, scroll
   Recommendation: a, because it matches the HUD layout copied from ZH. Why it matters: sets queue limit and bar width.

Q12. HUD: radar when the radar building is destroyed or not built?
   a) Minimap hidden - ZH default for radar-gated play (not verified in ControlBar code)   b) Minimap always on   c) Always on but only shows explored area
   Recommendation: b, because the minimap lands in M7.6 without a radar building in scope. Why it matters: adds a building and tech gate otherwise. ZH default: not looked up.

Q13. HUD: should a unit under attack flash on the minimap?
   a) Yes, attack glow on the minimap - ZH has this (ControlBar.cpp:960 area)   b) No   c) Sound only
   Recommendation: a, because players miss off-screen raids otherwise. Why it matters: needs a presentation event from the simulation.

Q14. Art: should the chosen look be the geometric style, sprites, or a mix per unit class?
   a) Sprites everywhere   b) Geometric shapes everywhere   c) Mix: buildings sprites, units geometric
   Recommendation: wait for the A/B page (already decided); ask only for an early lean. Why it matters: blueprint §2 changes if b or c win.

Q15. Batch A: do veterancy chevrons and level-up bonuses follow ZH three levels?
   a) Yes, three levels with ZH-like bonuses (values to be read at planning)   b) Two levels   c) Cosmetic only
   Recommendation: a, because the blueprint calls veterancy a system. Why it matters: affects every combat trace re-pin. ZH default: not looked up.
