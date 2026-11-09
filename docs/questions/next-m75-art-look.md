# Next: art pass look, units, buildings and colour (M7.5)

Sources. **ZH src** = ~/projects/CnC_Generals_Zero_Hour @ 0a05454, paths under `GeneralsMD/Code/`. **INI** = retail `INIZH.big` decoded into the session scratchpad, cited as archive entry:line. Art pack = `docs/art-direction/` (8 sheets in `references/`). Starting point, not frozen: the 13 [interview answers](../art-direction/interview/INTERVIEW_ARCHIVE.md) (user, 2026-11-09: revisable where there are problems); a question that revisits one names it. **A/B** after a question: best answered by eye on a side-by-side page in Firefox (as in the sound spike), from mock-ups now or the art lab later, not in text (user, 2026-11-09). Health bar visibility is asked in [next-m76-hud.md](next-m76-hud.md) Q4, lobby colour choice in [next-m9-lobby.md](next-m9-lobby.md) Q6. Scope and process: [next-m75-art-scope.md](next-m75-art-scope.md); terrain, fog and effects: [next-m75-art-world.md](next-m75-art-world.md).

## Findings (short, cited)
- **source** ZH has 8 player colours, one per seat: Gold, Red, Blue, Green, Orange, SkyBlue, Purple, Pink (INI `data/ini/multiplayer.ini:44-90`), and no ally/enemy colour mode (not found in options or radar code; radar dots use player colour, ZH src `GameEngineDevice/Source/W3DDevice/Common/System/W3DRadar.cpp:688`). Wargrid colours only owners 1 and 2; owners 3-8 all draw grey `808080` (`game/scripts/presentation/world_view.gd:36,47-48`). The pack proposes 3 owner colours.
- **source** ZH paints player colour only on marked stripe or panel regions of each texture, the rest keeps its own paint (ZH src `GameEngineDevice/Source/W3DDevice/GameClient/W3DAssetManager.cpp:408-436, 716-740`). The pack colours whole roofs, buildings included.
- **source** ZH draws no persistent selection ring: selecting flashes the model white, and the health bar is the "selected" mark (ZH src `GameEngine/Source/GameClient/Drawable.cpp:1010-1013, 1359-1381`; INI `data/ini/gamedata.ini:370-371`). Its health bar runs green to yellow to red (`Drawable.cpp:3886-3955`). Wargrid: green `8cff87` outline, one yellow bar (`world_view.gd:202, 253-254`).
- **source** ZH turrets turn on their own, about 60 deg/s on tanks (ZH src `GameEngine/Source/GameLogic/AI/TurretAI.cpp:178-181, 240-260`; INI `data/ini/object/chinavehicle.ini:319`).
- **source** ZH buildings rise out of the ground while built and sink when sold (ZH src `GameEngineDevice/Source/W3DDevice/GameClient/Drawable/Draw/W3DModelDraw.cpp:2024-2035`; `GameEngine/Source/Common/System/BuildAssistant.cpp:1527-1540`); damage looks change at 70 % and 35 % health (INI `data/ini/gamedata.ini:127-128`). Wargrid draws a construction "NN%" text label (`world_view.gd:91-94, 454-455`).
- **source** Real sizes are small: infantry 12 px wide, tanks 30 px, other vehicles 24 px at zoom 1; half that at zoom 0.5 (`world_view.gd:123-132`; zooms `main.gd:10`). The sheets draw tanks at 60-300 px.
- **inferred** Where I see problems (critique, to check on A/B pages):
  - Dark ground follows interview Q1 (high contrast) and Q6 ("desaturated/darker"), and the contrast with bright owner tops is the strength of the sheets. The risk is everything that is not an owner top: side faces `263842`/`3D515F` are close to ground `343A3C`, and neutral wrecks, dark health-bar backs and fog (ZH halves brightness) have little room left. Worth one A/B page with fog and wrecks in it, not a verdict from me.
  - Selection cyan `60E5ED` sits between owner blue `44ADF4` and owner green `69CEAA`; sheet 00 uses cyan, sheet 07 white for the same mark.
  - Amber `F7C871` is shared by impacts, resources and, with 8 players, the Gold and Orange owners.
  - Whole bright roofs make the 3x3 factory the loudest object on screen (sheet 00). Interview Q12 set the colour share for units only.
  - Faction details (USA's slim track pods, FRC's offset turret, China's chamfer) are 2-4 px at real tank size; sheet 03 itself says "change the primary outline" if they vanish.
  - The battlefield sheet shows no health bars, fog, HUD or 300 units: a mood board, not proof the look holds in a real match.
## Questions
Q1. How bright should the ground be? **A/B**
   a) Dark, as on the sheets — interview Q6 ("desaturated/darker")   b) Mid-tone: same muted hues, clearly lighter than the darkest side faces   c) Light, like a sunny desert
   Recommendation: a, because the contrast is what you liked, unless an A/B page with fog, wrecks and health bars shows side faces vanishing; then b. Why it matters: sets every other colour.
   **Answered 2026-11-09 (A/B page): b, mid-tone ground (mock-up #575C55).**

Q2. How many owner colours does the palette need?
   a) 8, one per seat: gold, red, blue, green, orange, sky blue, purple, pink — ZH default (multiplayer.ini:44-90), retuned to the softer sheet style   b) 6, enough for 3v3   c) The sheets' 3
   Recommendation: a, because maps already have up to 8 starts and the lobby question recommends ZH's 8. Why it matters: selection, impact and resource colours must stay clear of all of them.
   **Answered 2026-11-09: a, ZH's 8, retuned to the sheet style.**

Q3. What colour marks a selected unit? **A/B**
   a) No mark, a short white flash; the health bar shows selection — ZH default (Drawable.cpp:1010-1013)   b) White   c) Cyan (sheet 00)   d) Green (today)
   Recommendation: b, because no owner colour is white, cyan clashes with sky blue and green owners, and green clashes with the green owner. Why it matters: selection must read on every owner colour.
   **Answered 2026-11-09 (A/B page): b, white.**

Q4. What shape marks a selected unit? **A/B**
   a) A thin diamond on the ground around it (sheet 07)   b) Corner brackets around the unit   c) An outline around the unit's shape
   Recommendation: a, because it sits on the ground, never covers the hull, and matches building selection (the footprint outline). Why it matters: one cheap polygon per selected unit.
   **Answered 2026-11-09 (A/B page): a, thin ground diamond.**

Q5. How much owner colour do buildings get? **A/B**
   a) Neutral roof with an owner-coloured band or panel — closest to ZH (W3DAssetManager.cpp:408-436); interview Q12 rejected this for units   b) The whole roof in the full owner colour (sheets; interview Q12 applied to buildings)   c) The whole roof in a calmer, darker version of the owner colour
   Recommendation: c, because base ownership stays obvious at a glance while units remain the brightest things on screen. Why it matters: buildings cover far more screen than units.
   **Answered 2026-11-09 (A/B page): c, whole roof in a calmer, darker owner colour (today's 40 % lerp toward grey).**

Q6. Should faction differences be visible at normal zoom? **A/B**
   a) Yes: exaggerate the outline differences until USA, China and FRC tanks tell apart at zoom 1   b) Only at close zoom; at normal zoom role and owner colour are enough   c) As drawn on the sheets
   Recommendation: a, because in 3v3 you need to know what you are fighting, and the sheet details are 2-4 px at real size. Why it matters: shapes must be checked at real size in the lab, not on the sheets.
   **Answered 2026-11-09 (A/B page): a, exaggerate faction outline differences.**

Q7. Should infantry be drawn bigger than their real size? **A/B**
   a) True size (12 px wide at zoom 1, 6 px at the zoomed-out view)   b) About 1.5x larger, vehicles at true size   c) Everything somewhat larger than its collision size
   Recommendation: b, because 6 px soldiers are unreadable and hordes still fit; collision and picking stay unchanged. Why it matters: drawn size and click size stop matching slightly.
   **Answered 2026-11-09 (A/B page): a, true size, against the recommendation: 1.5x looked way too big.**

Q8. Should tank turrets turn on their own toward their target?
   a) Yes, at a fixed turn rate — ZH default (TurretAI.cpp:178-181, about 60 deg/s)   b) No, the turret always faces the hull's direction
   Recommendation: a, because a turret tracking its target is the clearest "this tank is fighting that one" cue; it is drawing only, from the target already in the snapshot. Why it matters: small presentation state per unit, cleared on restart.
   **Answered 2026-11-09: a, turrets turn toward their target at a fixed rate (drawing only).** Checked 2026-11-09: in ZH the turret must be aligned in turn and pitch before the aim state hands over to firing (TurretAI.cpp:1169-1199; state machine :93-101), so turn rate is a gameplay rule there. Wargrid's M6 decision is "firing ignores heading (no turrets yet)" (blueprint M6), so the drawing-only answer stands until the user decides whether turret aiming joins the simulation (open question, 2026-11-09).

Q9. How many detail levels, and when do they switch?
   a) One per existing zoom step: far at 0.5, normal at 1, close at 2   b) By measured on-screen size with hysteresis (art bible §9)   c) One drawing at every zoom
   Recommendation: a, because there are exactly three fixed zooms, so the zoom itself is the threshold and nothing can flicker. Why it matters: b needs tuning and tests for no gain.
   **Answered 2026-11-09: a, one detail level per zoom step.**

Q10. Should ground units cast a shadow? **A/B**
   a) A small dark patch under every unit — interview Q10 ("shadows"; sheet 01)   b) No, only aircraft get a shadow on the ground (sheet 00)
   Recommendation: a, because it grounds units on dark terrain and is one polygon each; drop it only if the lab's benchmark says so. Why it matters: drawing cost per unit.
   **Answered 2026-11-09 (A/B page): a, a small dark patch under every unit (High only).**

Q11. What happens to text and symbols drawn on the map (building glyphs, supply counts, "NN%")?
   a) Remove all; buildings read by shape, progress and amounts show in the selection panel   b) Remove glyphs, keep supply counts on the map   c) Keep them
   Recommendation: a, because interview Q9 rejected icon-labelled buildings and overlapping pile labels are a known playtest issue. Why it matters: until the M7.6 HUD lands, counts must be readable somewhere.
   **Answered 2026-11-09: a, remove all map text and glyphs; progress and amounts in the selection panel.**

Q12. How should a supply pile show how much is left?
   a) The stack shrinks as boxes are taken   b) A number (today)   c) Both
   Recommendation: a, with the number in the selection panel, because shape carries the meaning without text. Why it matters: the pile's drawing depends on its box count.
   **Answered 2026-11-09: a, the stack shrinks; the number is in the selection panel.**

Q13. What colour is the health bar? **A/B**
   a) Green to yellow to red by health — ZH default (Drawable.cpp:3886-3955)   b) One colour (yellow today)   c) The owner colour
   Recommendation: a, because it reads at a glance and stays clear of owner colours. Why it matters: drawn for every damaged unit.
   **Answered 2026-11-09 (A/B page): a, green to yellow to red.**

Q14. How does a building look while it is being built?
   a) It rises out of the ground as it builds — ZH default (W3DModelDraw.cpp:2024-2035)   b) Full shape, see-through, filling in   c) Flat footprint plus a progress bar
   Recommendation: a, because with geometry it is one height factor and the progress is visible without text. Why it matters: selling (if added in M7.6) can reverse it.
   **Answered 2026-11-09: a, it rises out of the ground.**

Q15. How does a damaged building look? **A/B**
   a) Darker roof and a missing corner piece at 70 % and again at 35 % health — ZH thresholds (gamedata.ini:127-128)   b) Same, plus a thin geometric smoke column below 35 % — interview Q7 includes "simple smoke"   c) Only the health bar
   Recommendation: b, because a burning base is a strong ZH cue and Q7 allowed simple smoke; the art bible's "no persistent smoke" is GPT's rule, not yours. Keep the column thin so it never hides units. Why it matters: two extra drawings per building kind.
   **Answered 2026-11-09 (A/B page): b, darker roof and missing corner at 70 % and 35 %, plus a thin static smoke column below 35 %.**
