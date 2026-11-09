# Next: fog of war details (M7.9)

Sources. **ZH src** = ~/projects/CnC_Generals_Zero_Hour @ 0a05454, paths under `GeneralsMD/Code/GameEngine/Source/`. **INI** = retail root `INIZH.big` (no override in `PatchINI.big`/`PatchZH.big`/`PatchData.big`, checked), decoded into the session scratchpad, cited as archive entry:line. Already decided and not asked again: black start, grey fog hides enemy units, last-seen enemy buildings, foundations reveal nothing, shared team vision (design-answers 2026-11-08); elevation affects passability only (M6, session notes 2026-11-05); bots see only what their team sees (blueprint §14).

## Findings (short, cited)
- **source, conflicts with the 2026-11-08 answer.** Retail skirmish and multiplayer do NOT start black. `data\ini\multiplayer.ini:38` sets `UseShroud = No`; at map load, for every occupied slot of the skirmish or network game, `if (!isShroudInMultiplayer()) revealMapForPlayer(...)` (ZH src GameLogic/System/GameLogic.cpp:1731-1754; skirmish uses `TheSkirmishGameInfo`, :1202). `revealMapForPlayer` adds and removes a looker on every cell, so every cell becomes "fogged", i.e. explored grey (GameLogic/Object/PartitionManager.cpp:2972-2981, status values :1384-1391). The code default (`m_isShroudInMultiplayer = TRUE`, Common/MultiplayerSettings.cpp:79) is what the earlier answer read; the shipped INI turns it off.
- **source** Even with the map revealed, enemy buildings and units stay hidden until actually seen: a fogged enemy object is shown only if it is immobile AND `m_everSeenByPlayer` is set (PartitionManager.cpp:1670-1676). Neutral immobile objects (supply piles, civilian buildings) show fogged at once; neutral moving things are hidden (:1665-1669).
- **source** A fogged object is drawn as a frozen snapshot of its last seen state (ghost object `snapShot`, PartitionManager.cpp:1677-1684).
- **source** Fog grows back 5 s after the last viewer leaves: `UnlookPersistDuration = 5000` (`data\ini\gamedata.ini:442`).
- **source** Vision is a plain filled circle of cells; terrain and cliffs do not block it (`doShroudReveal` draws a `DiscreteCircle`, PartitionManager.cpp:3969-3990).
- **source** Line of sight matters for auto-targeting only: with `AttackUsesLineOfSight = Yes` (`data\ini\default\aidata.ini:31`), units with `KindOf ATTACK_NEEDS_LINE_OF_SIGHT` add a terrain-and-obstacle LOS filter when picking targets (ZH src Object/Update/AIUpdate.cpp:4612-4616; AI/AI.cpp:654-655; PartitionManager.cpp:4496-4566, 5340-5347). That kind is on direct-fire units (Ranger, Crusader, Paladin, Battlemaster, Gattling Tank, Rebel, RPG trooper, Scorpion...), not on artillery (Inferno, Tomahawk) (`data\ini\object\*.ini` KindOf lines). **inferred** attack paths also look for a spot with a clear view (AI/AIPathfind.cpp:9384-9395).
- **source** "Fog no longer prevents attacking at all"; it only prevents automatic target picking (Object/WeaponSet.cpp:531-542). Human players' units auto-target only unfogged enemies (`AI::UNFOGGED`, AIUpdate.cpp:4634-4641); computer players' units skip that filter, so ZH bots' units auto-target in fog. Wargrid's fair-bot rule already forbids that difference; not asked.
- **not found** Any rule that reveals a shooter when it fires. The only "reveal to all" field, `ShroudRevealToAllRange`, is on superweapon buildings (Object/Object.cpp:5005-5014; `data\ini\object\*general.ini`, value 60).

## Questions
Q1. At match start, should the map look black or show the terrain greyed out?
   a) Terrain shown grey from the start; enemy bases still hidden until scouted — ZH retail default (multiplayer.ini:38, GameLogic.cpp:1750-1754, PartitionManager.cpp:2972-2981)   b) Black until explored (your 2026-11-08 answer, which read the code default)   c) A lobby option, grey by default
   Recommendation: a, because it is what Zero Hour players actually saw in skirmish and online, and the earlier answer rested on a default the retail data overrides. Why it matters: it changes scouting, the minimap's first look and the stored "explored" state.

Q2. If the map does start black (Q1 b), should neutral supply piles be visible from the start?
   a) No, piles appear only once explored (follows from b)   b) Yes, piles always shown so players can plan the economy   c) Only the piles near your own start
   Recommendation: a, because it keeps one rule; skip this question if Q1 is a. Why it matters: bots and players need to find supplies; hidden piles force early scouting.

Q3. How long does an area stay clear after your last unit leaves it?
   a) 5 seconds, then it turns grey — ZH default (gamedata.ini:442)   b) It turns grey at once   c) 2 seconds
   Recommendation: a, because it is the tuned value and hides flicker at vision edges. Why it matters: decides how long a scout's last look stays live.

Q4. Do hills and cliffs block what a unit can see?
   a) No, vision is a simple circle — ZH default (PartitionManager.cpp:3969-3990)   b) Yes, higher ground hides what is behind it   c) Only cliffs block vision
   Recommendation: a, because it matches ZH and M6's "elevation affects passability only", and is cheap. Why it matters: b means a per-cell line-of-sight test inside the vision update, a real per-tick cost.

Q5. Should direct-fire units (soldiers, tanks) refuse to auto-target over a hill, while artillery can?
   a) Yes: direct-fire units need a clear line over terrain and obstacles to pick a target; artillery does not — ZH default (aidata.ini:31, AIUpdate.cpp:4612-4616, PartitionManager.cpp:4496-4566)   b) No, keep M6's rule: elevation never affects shooting   c) Yes, but only for soldiers
   Recommendation: b for now, because M6 decided elevation affects passability only and this is not a fog rule; revisit with ground batch A artillery if hills feel flat. Why it matters: a is the reason high ground matters in ZH, but it adds a line test per target search.

Q6. May a player order an attack on an enemy building that is only remembered in the fog?
   a) Yes, explicit attack orders work on remembered buildings and on ground; only automatic targeting needs vision — ZH default (WeaponSet.cpp:531-542, AIUpdate.cpp:4634-4641)   b) No, only on what you see right now   c) Only artillery may attack remembered buildings
   Recommendation: a, because artillery against a scouted base is a core ZH tactic and the rule is simple. Why it matters: decides if ghosts are clickable targets and how orders validate.

Q7. When a supply pile is in the fog, what amount does it show?
   a) The amount when last seen (frozen picture) — ZH default for fogged immobile objects (PartitionManager.cpp:1665-1684; inferred for piles)   b) The live amount, piles are public   c) No amount shown in the fog
   Recommendation: a, because the same "last seen" rule as enemy buildings is easiest to explain. Why it matters: bots must plan on last-seen pile sizes, not live ones (fair-bot rule).

Q8. Should firing reveal a hidden shooter to the side it hits?
   a) No: a unit in the fog stays hidden while it fires — ZH (no such rule found; only superweapons reveal to all, Object.cpp:5005-5014)   b) Yes, briefly reveal the shooter's cell to the target's team   c) Reveal only artillery shooters
   Recommendation: a, because ZH has no such rule and it keeps vision one system. Why it matters: with a, long-range artillery is invisible unless scouted.
