# Next: HUD details (M7.6)

Sources. **ZH src** = ~/projects/CnC_Generals_Zero_Hour @ 0a05454, paths under `GeneralsMD/Code/GameEngine/Source/` (headers under `Include/`). **INI** = retail root `INIZH.big` decoded into the session scratchpad, cited as archive entry:line. Already decided, not asked: queue of 9, minimap flash on attack, minimap free with the Command Center and blank at low power or without a radar provider, letter hotkeys on buttons, camera spots F1-F8 with the HUD, "keep formation" considered here, blocker highlight on refused placement (design-answers 2026-11-08). Wargrid today has no sell (`rg -i sell game/scripts/simulation`: nothing) and draws a health bar when a unit is selected or damaged (`game/scripts/presentation/world_view.gd:251-254`).

## Findings (short, cited)
- **source** Every ZH factory and base building has a Sell button (`data\ini\commandset.ini:770` War Factory slot 14 `Command_Sell`). Selling returns 50 % of the cost (`data\ini\gamedata.ini:390`) and takes 3 s while the building "un-builds" (ZH src Common/System/BuildAssistant.cpp:177, 1499-1603).
- **source** Health bars are drawn only for selected objects and the one under the mouse (GameClient/Drawable.cpp:3855-3859; `ShowObjectHealth = Yes`, gamedata.ini:25).
- **source** Veterancy chevrons are drawn above every unit that has a level, with no selection check (Drawable.cpp:2807, 3797-3815). **inferred** enemies' chevrons show too (no relationship check in that function).
- **source** No selection limit in retail: `MaxSelectionSize = 0 ; <1 to disable` (`data\ini\ingameui.ini:7`; InGameUI.cpp:144-150).
- **source** Combat units carry Attack Move, Guard and Stop buttons (commandset.ini:489-491, Crusader). Guard (human-controlled) attacks inside 1.8 x vision and chases to 2.2 x vision for up to 10 s (`data\ini\default\aidata.ini:18-20`). Wargrid has `attack_move` and an idle guard intent already (`simulation.gd:181, 401`), no explicit Guard order.
- **source** Each player may place up to 3 map beacons (pings with text) visible to allies (`data\ini\multiplayer.ini:37`; beacon messages handled in GameLogic/System/GameLogicDispatch.cpp before :1783 "end beacon text").

## Questions
**Answered 2026-11-09:** Q1-Q3 a (sell every building, 50 %, 3 s), Q4 b (selected or damaged, today), Q5 a, Q6 a, Q7 a, Q8 b (pings without text); recorded in the [design answers](../reference/design-answers-2026-11-08.md#hud-m76).

Q1. Should players be able to sell their own buildings?
   a) Yes, every building has a Sell button — ZH default (commandset.ini:770)   b) No selling   c) Only non-production buildings
   Recommendation: a, because selling is a standard ZH escape valve and the HUD is the place for the button. Why it matters: a new command with same-tick cases against attack, capture and production.

Q2. How much money does selling return?
   a) 50 % of the building's cost — ZH default (gamedata.ini:390)   b) 50 % scaled by remaining health   c) 25 %
   Recommendation: a, because it is ZH. Why it matters: decides if selling a damaged building is worth it.

Q3. How long does selling take?
   a) 3 s, during which the building can still be destroyed — ZH default (BuildAssistant.cpp:177)   b) Instant   c) 5 s
   Recommendation: a, because it is ZH and gives attackers a window. Why it matters: needs a "being sold" state that blocks production and repair.

Q4. When should health bars show?
   a) Only for selected units and the one under the mouse — ZH default (Drawable.cpp:3855-3859)   b) Selected or damaged (Wargrid today)   c) Always for everything
   Recommendation: b, because damaged-unit bars help read fights without a mouse-over, and the screen stays calm at full health. Why it matters: the M7.5 art pass draws whichever is chosen.

Q5. Should veterancy chevrons show above every unit, enemies included?
   a) Yes, always, for every side — ZH default (Drawable.cpp:2807, 3797-3815; enemies inferred)   b) Only your own and allied units   c) Only when selected
   Recommendation: a, because seeing enemy veterans is useful information and matches ZH. Why it matters: the bot observation must then include enemy veterancy as public, visible information.

Q6. Is there a limit to how many units one box selection can take?
   a) No limit — ZH retail default (ingameui.ini:7)   b) 40 units   c) 100 units
   Recommendation: a, because ZH has none and 3v3 armies are large. Why it matters: the selection panel must lay out any count.

Q7. Should units get a Guard order (hold an area, attack what comes close, chase a bit, return)?
   a) Yes: attacks inside 1.8 x vision, chases to 2.2 x vision for up to 10 s, then returns — ZH default (aidata.ini:18-20, commandset.ini:490)   b) No, the idle behaviour is enough   c) Yes, but no chase
   Recommendation: a, because it is a standard ZH button next to Attack Move and Stop. Why it matters: a new command with same-tick cases.

Q8. Should players be able to drop map beacons (a ping with a short text) for teammates?
   a) Yes, up to 3 per player — ZH default (multiplayer.ini:37)   b) Pings without text   c) No beacons
   Recommendation: a, because 3v3 with friends needs a way to point at the map. Why it matters: beacons are commands in the lockstep stream (ZH sends them as game messages).
