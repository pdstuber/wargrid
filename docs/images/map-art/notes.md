# Wargrid map art: faction shapes and placeholders

Mock-ups of the shapes picked on A/B pages (user, 2026-11-13); decisions with their reasons are in the [design answers](../../reference/design-answers-2026-11-08.md#map-art-faction-shapes-m75-user-2026-11-13). Pictures of HTML pages that redraw the game's exported shapes, not screenshots of the game. All 1280x720, sand ground, default owner colours.

| What | Today | Picked |
|---|---|---|
| The five shared buildings, rows USA, China, FRC (zoom 1) | [buildings-today](buildings-today-z1.webp) | [buildings-picked](buildings-picked-z1.webp) |
| Rifle and rocket infantry, builder, light vehicle, Supply Helicopter (zoom 2) | [units-today](units-today-z2.webp) | [units-picked](units-picked-z2.webp) |
| Supply piles at five fill levels, construction at 10, 50 and 90 %, salvage crates (zoom 1) | [placeholders-today](placeholders-today-z1.webp) | [placeholders-picked](placeholders-picked-z1.webp) |

Everything picked, together:

- [Two bases at the smallest zoom, under the HUD v4 mock-up](base-usa-china-z05-hud.webp): the state the shapes were judged in.
- One base and army per faction at zoom 1: [USA](base-usa-z1.webp), [China](base-china-z1.webp), [FRC](base-frc-z1.webp).

What is real and what is not:
- "Today" is the output of `game/scripts/presentation/shapes.gd` at commit `10b9423`, exported headless and redrawn in the page with the bake's own rules. The redraw matched the game's baked triangles to 0.00001 px on 552 of 555 sampled poses; the other three are one tie in the paint order of two barrels of the same colour. Pixels were not compared with a game window.
- "Picked" is candidate data in the same format, not in the game. Every candidate passes a JavaScript port of the shape audit's paint-order and size rules; none was run in Godot.
- Sizes are the game's in its 1280x720 layout; a larger window scales everything up. The ground is the game's sand with its per-cell shade.
- The base scenes are composed by hand. Tanks, defence buildings, the Laborer, the supply truck and rubble are today's shapes.
- The HUD is the [HUD v4](../hud-v4/notes.md) mock-up layer; its glyphs here are silhouettes baked from the shapes, not the HUD's own drawings.
- In the "today" placeholder picture the pile and construction text uses the mock-up's typeface, not the game's font; the fill amounts are examples.
- The salvage crate's colours were an agent choice made after the cargo colour was picked (grey crate, dark drum, cream mat) and accepted afterwards (user, 2026-11-13).
- In the big-pile row neighbouring footprints touch at the corners; five do not fit side by side at zoom 1.

Not drawn: damage states of the picked buildings, the paused construction case, wrecks, anything moving. Not tested: anything in Godot, the rendered benchmark, Neon colours and the dark ground on the picked set. The pages, the build spec and the candidate data are working files in the private notes repository (`art-spike/`).
