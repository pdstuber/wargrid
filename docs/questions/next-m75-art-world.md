# Next: art pass world, fog and effects (M7.5)

Sources as in [next-m75-art-look.md](next-m75-art-look.md). Starting point, not frozen: the 13 interview answers, here mainly muted biomes with bright units (Q6) and small normal hits with big effects only for powerful attacks (Q7). **A/B** after a question: best answered by eye on a side-by-side page in Firefox (as in the sound spike), from mock-ups now or the art lab later, not in text (user, 2026-11-09). Already decided, not asked: fog semantics (map revealed at start, grey fog hides enemies, frozen last-seen buildings: [blueprint M7.9](../blueprint.md), [answers 2026-11-09](answers-2026-11-09.md)). Fog itself lands in M7.9; its look is asked here so the palette fits it.

## Findings (short, cited)
- **source** Converted maps carry only open, cliff (`#`) and water (`~`) cells plus per-cell heights that no game code reads; no biome, texture, roads, trees, rocks or bridges (`game/scripts/simulation/map_data.gd:47-53, 73`; `tools/zh_map/convert.py:456-470`). The source maps had them: Twilight Flame alone has 320 trees, 43 rocks, 18 dirt roads and 4 bridges (`docs/reference/m6-map-and-feel.md:28`).
- **source** `terrain_view.gd` draws one sand diamond, every blocked cell (cliff and water alike) as one flat brown, and a 1 px grid over the whole map (`game/scripts/presentation/terrain_view.gd:5-49`). The sheets show roads and rocks the maps do not have.
- **source** ZH fog darkens: the shroud multiplies terrain brightness, unexplored black, fogged about half (127/255), visible full (INI `data/ini/gamedata.ini:444-447`; ZH src `GeneralsMD/Code/GameEngineDevice/Source/W3DDevice/GameClient/W3DShroud.cpp:295-322`). On dark ground half brightness is near black.
- **source** ZH cannons fire visible shells with travel time (speed 400, INI `data/ini/weapon.ini:296-324`); rifles are instant (`weapon.ini:729-736`). Wargrid applies damage on the firing tick and draws a one-tick line today (`world_view.gd:336-345`); ground batch A makes all rockets and shells travel in the simulation (user decision 2026-11-07, `docs/blueprint.md:597`), so by M7.5 shells really fly.
- **source** ZH infantry bodies lie 3 s and are gone at 8 s; burned or poisoned ones vanish at once (INI `data/ini/object/americainfantry.ini:960-966`).
- **source** ZH vehicle wrecks never block: main tanks stay 14 s then sink, gone at 20 s; light vehicles gone at 8 s (INI `data/ini/object/hulk.ini:537-577, 820-848`; ZH src `GeneralsMD/Code/GameEngine/Source/GameLogic/Object/PartitionManager.cpp:1964-1965`).
- **source** ZH shakes the camera a lot: 145 view-shake effects in `data/ini/fxlist.ini`, graded subtle (40), normal (27), strong (29) and severe (49) (counted in the decoded file). The art bible says no screen shake as a baseline (`ART_DIRECTION.md` §8).

## Questions
Q1. Which ground look does each map get? **A/B**
   a) Desert for all three maps for now (blueprint §2 "desert maps initially")   b) One biome per map, written into the map file (for example Ashfall ash, Dry Wells desert)   c) Read the biome from the source map's textures in the converter
   Recommendation: b, because it is one field per map, the simulation ignores it, and three maps already give three moods. Why it matters: decides if map files gain a presentation field.
   **Answered 2026-11-10 (in-game A/B): B, sand ground; tone D `#A88E5C` (steps C `#998559`, D, E `#B29763` all fine; A, B, F not).** The lab compared dark ground against sand, not the map-by-map options a-c, so how the biome reaches map files stays open; the dark biome's lighter, warmer tone (#7B7566) also won its own A/B (question 17).

Q2. How should cliffs look? **A/B**
   a) Raised blocks at the map's real heights   b) A low raised step with a lit top and dark side, low enough never to hide a unit   c) Flat, darker cells (today)
   Recommendation: b, because it reads as 2.5D without needing cliffs and units sorted together over thousands of cells. Why it matters: a could hide units behind cliffs.
   **Answered 2026-11-09 (A/B page): b, a low raised step with a lit top.**

Q3. Should water look different from cliffs?
   a) Yes, a muted blue-grey flat surface   b) No, same as cliffs (today)
   Recommendation: a, because players need to tell "too high" from "too wet" (later hovercraft or amphibious units care). Why it matters: one colour, already separate in map data.
   **Answered 2026-11-09: a, muted blue-grey water.**

Q4. Should the converter bring back the source maps' decorations for M7.5?
   a) None; keep the ground plain   b) Roads, rocks and tree clusters as decoration only, no effect on movement   c) Also bridges and oil derricks with their game rules
   Recommendation: b, because a plain plane gives no sense of place and roads guide the eye; c is gameplay and belongs in a map milestone. Why it matters: a converter change under `tools/zh_map/` and a decoration layer in the cached terrain.
   **Answered 2026-11-09: b, roads, rocks and tree clusters as decoration only.**

Q5. When is the cell grid shown?
   a) Only while placing a building   b) Always, faint (today); interview Q6 rejected the grid-board option   c) Toggle with a key
   Recommendation: a, because the sheets and ZH show no grid, and placement is the only time cells matter to the player. Why it matters: one less full-map draw.
   **Answered 2026-11-09: a, grid only while placing a building.**

Q6. How should fogged areas look (M7.9)? **A/B**
   a) Darkened to about half brightness — ZH default (gamedata.ini:444-447)   b) A grey veil: colour drained, brightness kept   c) Slightly darker and colour drained
   Recommendation: c, because half brightness on muted ground nearly hides the map you were promised as revealed, while drained colour still says "not seen now". Why it matters: owner colours of frozen enemy buildings must still read.
   **Answered 2026-11-10 (in-game A/B): A, darkened to half brightness (the Zero Hour default).** Re-check once the ground is sand; the lab fog sat on dark and sand ground alike.

Q7. How should a travelling shell or rocket look? **A/B**
   a) A short bright dash flying to the target   b) A small dot with a fading trail   c) No visible shell, only muzzle flash and impact
   Recommendation: a, because a dash shows direction at a glance and costs one triangle pair; rifles stay an instant streak, as in ZH (weapon.ini:729-736). Why it matters: an art lab run before batch A shows today's instant shots only.
   **Answered 2026-11-10 (in-game A/B): B, a short bright dash flies to the target (option a here).**

Q8. What happens when an infantry soldier dies?
   a) The body lies about 3 s, then fades, gone at 8 s — ZH default (americainfantry.ini:960-966)   b) Falls and fades within about 2 s   c) Vanishes at once with a small flash
   Recommendation: b, because China hordes kill many soldiers at once and 8 s bodies pile up drawing cost. Why it matters: drawing cost in the horde layout, which already exceeds the budget.
   **Answered 2026-11-09: b, falls and fades within about 2 s.**

Q9. Which events get the big "signature" effect (larger core and expanding rings)? **A/B**
   a) Only special weapons (Nuke Cannon, Scud and later superweapons)   b) Special weapons and building deaths   c) Also every vehicle death
   Recommendation: b, because losing a building is a big moment and rare; vehicle deaths are routine. Why it matters: interview Q7 keeps big effects rare.
   **Answered 2026-11-10 (in-game A/B): A, no signature effect on building and vehicle deaths (option a: only special weapons).** The lab fight had no special weapon, so how a special-weapon signature looks stays open.

Q10. Should the camera shake? **A/B**
   a) Yes, graded by explosion size, often — ZH default (fxlist.ini, 145 shakes)   b) Only for signature explosions on screen, small   c) Never (art bible)
   Recommendation: b, because a little shake sells the rare big hits while constant shaking in a 3v3 fight tires the eyes. Why it matters: decides how "punchy" (interview Q4) applies to the camera.
   **Answered 2026-11-10 (in-game A/B): A, no shake (option c here). Open: shake for special-weapon explosions was not shown.**

Q11. Should a unit flash briefly when it is hit? **A/B**
   a) Yes, a one-tick light flash on the hull   b) No, the hit effect at the target is enough
   Recommendation: a, because it shows which unit in a crowd is taking damage. Why it matters: one extra state per unit.
   **Answered 2026-11-10 (in-game A/B): A, no hit flash (option b here).**

Q12. Should players get an option to show allies in one colour and enemies in another?
   a) No, always each player's own colour — ZH default (no such mode found in its options or radar code)   b) Yes, as an option, off by default
   Recommendation: b, because in 3v3 with 8 colours "who is on my side" is the first question, and it doubles as a colour-blind aid. Why it matters: a settings entry and a second colour lookup.
   **Answered 2026-11-09: b, an ally/enemy colour option, off by default.**

Q13. What happens to a destroyed vehicle? **A/B**
   a) A neutral wreck stays, then sinks: tanks about 20 s, light vehicles about 8 s; units drive through it — ZH default (hulk.ini:537-577, 820-848)   b) A short wreck, about 3 s   c) No wreck, only an explosion
   Recommendation: b, because wrecks cost drawing time in big fights and a 20 s wreck that does not block looks like an obstacle that is not there. Why it matters: one more drawn object per dead vehicle.
   **Answered 2026-11-10 (in-game A/B): A, the wreck stays: tanks 20 s, light vehicles 8 s (option a, the Zero Hour default).**

## Added by the art lab A/B (questions 8-18, user, 2026-11-10, in-game; click log `ab-results/web-20261110-155052.log` outside the repo)

Numbers continue the lab's order (the lab's own list, not the Q numbers above). Variant A is today's look, B the candidate, unless noted.

8. Ground: flat or slight per-cell variation? **Answered 2026-11-10 (in-game A/B): B, slight per-cell variation.**
9. Body size against the cell: one-cell hulls or Zero Hour length tanks (about 1.2 cells)? **Answered 2026-11-10 (in-game A/B): A, one-cell hulls.** Spacing is one unit per cell until the movement milestone; revisit then.
10. Infantry click box: fits the body, or wider (36 px, Zero Hour selection cylinder)? **Answered 2026-11-10 (in-game A/B): B, wider click box; the visible body stays narrow.**
11. Horde mark: white diamond or flat ground ring? **Answered 2026-11-10 (in-game A/B): B, ground ring** (user dislikes the diamond; Zero Hour draws a ground decal, `TERRAIN_DECAL_HORDE`, `GeneralsGameCode` @ `afc2a103f` `Drawable.h:264-271`).
12. Drawing interpolation between the last two ticks? **Answered 2026-11-10 (in-game A/B): B, drawn between ticks ("way smoother").** Presentation only, no simulation change; moving and turning looked fine, remaining nervousness is missing avoidance.
13. Light vehicle gun: small or bigger? **Answered 2026-11-10 (in-game A/B): A, small gun.**
14. Infantry colour: pale owner colour, or torso in full owner colour with light head and dark legs? **Answered 2026-11-10 (in-game A/B): B, full-colour torso.**
15. Owner contrast: blue-grey side faces, or neutral grey sides plus an owner band? **Answered 2026-11-10 (in-game A/B): A, blue-grey sides (today).**
16. Owner palette: today's colours or brighter, more saturated ones? **Answered 2026-11-10 (in-game A/B): likes both; today's palette is the default, the bright set is an opt-in menu option "Neon mode"** (#2F7BFF #FF2F45 #14D45A #FFE100 #FF7A00 #A040FF #00D8E8 #FF4FB0). The click log says A.
17. Dark ground tone: #575C55 or lighter, warmer #7B7566? **Answered 2026-11-10 (in-game A/B): B, #7B7566** (dark biome only).
18. Sand tone, six steps. **Answered 2026-11-10 (in-game): C `#998559`, D `#A88E5C`, E `#B29763` fine; A, B, F not; default D `#A88E5C`.**

Open after the lab (not answers):
- Colour harmony (coordinator proposals, not decided, not seen in the lab): warm ground with cool units; the yellow owner `#C9A227` is close to sand D (check, or shift to about `#E8D44A`); shadows slightly warm (30 % dark brown) instead of black.
- Horde ring look beyond "not the diamond" (size, colour, owner tint) is for the rest of M7.5.
- Signature effect and shake for special weapons (questions 9, 10 above).
