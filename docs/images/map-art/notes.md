# Wargrid map art: faction shapes, placeholders, damage, tanks and the world

Mock-ups of the looks picked on A/B pages (user, 2026-11-13 and 2026-11-14); decisions with their reasons are in the [design answers](../../reference/design-answers-2026-11-08.md#map-art-faction-shapes-m75-user-2026-11-13). Pictures of HTML pages that redraw the game's exported shapes, not screenshots of the game. All 1280x720, sand ground unless named; the round 5 picked pictures use the picked owner colours, the others today's default set.

| What | Today | Picked |
|---|---|---|
| The five shared buildings, rows USA, China, FRC (zoom 1) | [buildings-today](buildings-today-z1.webp) | [buildings-picked](buildings-picked-z1.webp) |
| Rifle and rocket infantry, builder, light vehicle, Supply Helicopter (zoom 2) | [units-today](units-today-z2.webp) | [units-picked](units-picked-z2.webp) |
| Supply piles at five fill levels, construction at 10, 50 and 90 %, salvage crates (zoom 1) | [placeholders-today](placeholders-today-z1.webp) | [placeholders-picked](placeholders-picked-z1.webp) |

Rounds 4 and 5 (user, 2026-11-14):

| What | Today | Picked |
|---|---|---|
| Damage at 100, 70 and 35 % for every building body, all three factions (zoom 0.5) | [damage-today](damage-today-z05.webp) | [damage-picked](damage-picked-z05.webp) |
| Tanks, light vehicles and the Armed Pickup at eight headings (zoom 2) | [tanks-today](tanks-today-z2.webp) | [tanks-picked](tanks-picked-z2.webp) |
| Zoom 2 finish: Barracks, Factory, HQ, a tank, a light vehicle, riflemen (zoom 2) | [zoom2-today](zoom2-today-z2.webp) | [zoom2-picked](zoom2-picked-z2.webp) |
| Building fixes: China and FRC bodies (zoom 1) | [fix-buildings-today](fix-buildings-today-z1.webp) | [fix-buildings-picked](fix-buildings-picked-z1.webp) |
| Unit fixes: infantry, tanks, light vehicles and the Laborer at eight headings (zoom 2) | [fix-units-today](fix-units-today-z2.webp) | [fix-units-picked](fix-units-picked-z2.webp) |
| The whole scene, sand, no HUD (zoom 0.5): owner colours, side band, cliff, ground decoration | [world-today](world-today-z05.webp) | [world-picked](world-picked-z05.webp) |

Also from round 5:

- [The picked world on the dark ground](world-picked-dark-z05.webp) (zoom 0.5).
- [The lighter fog](world-fog-z1.webp), the picked one (zoom 1).
- [The picked cliff and decoration patch](world-cliff-decor-z1.webp) (zoom 1).

Everything picked in rounds 1 to 3, together:

- [Two bases at the smallest zoom, under the HUD v4 mock-up](base-usa-china-z05-hud.webp): the state the shapes were judged in.
- One base and army per faction at zoom 1: [USA](base-usa-z1.webp), [China](base-china-z1.webp), [FRC](base-frc-z1.webp).

What is real and what is not:
- "Today" is the output of `game/scripts/presentation/shapes.gd` at commit `10b9423`, exported headless and redrawn in the page with the bake's own rules. The redraw matched the game's baked triangles to 0.00001 px on 552 of 555 sampled poses; the other three are one tie in the paint order of two barrels of the same colour. Pixels were not compared with a game window.
- "Picked" is candidate data in the same format, not in the game. Every candidate passes a JavaScript port of the shape audit's paint-order and size rules; none was run in Godot.
- Sizes are the game's in its 1280x720 layout; a larger window scales everything up. The ground is the game's sand with its per-cell shade.
- Round 4 and 5 candidates are page data, not run in Godot, like the rest of "picked".
- The round 4 "today" pictures draw today's shapes with today's damage rule. In the zoom 2 finish picture the tank's zoom 2 version sits on today's hull, not the picked one.
- The tank picture is round 4's pick. It does not carry the later FRC correction (tank 0.7 cells, Armed Pickup 0.65); round 5's row view does not show the three tanks side by side, so the correction is visible only in the world pictures. The unit fixes are shown at zoom 2, because they hardly show at zoom 1.
- The world pictures are round 5's page with rounds 1 to 4 baked in. "Today" is every round 5 option at 0: today's owner colours, side band, cliff, no decoration, no fog. Picked colours are the "lift" owners and the "deeper" side band.
- The fog is a brightness multiply over half the stage, and part of the own army stands inside it, which the game would not show.
- Decoration (the road, scrub, rocks, water) is not in the game.
- The base scenes are composed by hand. Tanks, defence buildings, the Laborer, the supply truck and rubble are today's shapes.
- The HUD is the [HUD v4](../hud-v4/notes.md) mock-up layer; its glyphs here are silhouettes baked from the shapes, not the HUD's own drawings.
- In the "today" placeholder picture the pile and construction text uses the mock-up's typeface, not the game's font; the fill amounts are examples.
- The salvage crate's colours were an agent choice made after the cargo colour was picked (grey crate, dark drum, cream mat) and accepted afterwards (user, 2026-11-13).
- In the big-pile row neighbouring footprints touch at the corners; five do not fit side by side at zoom 1.

Not drawn: the paused construction case, wrecks, anything moving. Not tested: anything in Godot, the rendered benchmark. The dark ground was looked at only with the round 5 world. The pages, the build spec and the candidate data are working files in the private notes repository (`art-spike/`).
