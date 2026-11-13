# Wargrid HUD v4

Mock-ups of the in-match HUD as picked on A/B pages (user, 2026-11-13); decisions with their reasons are in the [design answers](../../reference/design-answers-2026-11-08.md#hud-m76). Static pictures of clickable HTML pages, not screenshots of the game. All at 1280x800; the game scales the same layout to larger screens.

| State | Full | Core (package P2.3) |
|---|---|---|
| Nothing selected | [full-none](full-none.webp) | [core-none](core-none.webp) |
| One unit | [full-one](full-one.webp) | [core-one](core-one.webp) |
| 120 units, pinned factory | [full-many](full-many.webp) | [core-many](core-many.webp) |
| Factory with a queue, credits short | [full-factory](full-factory.webp) | [core-factory](core-factory.webp) |
| Builder placing a building | [full-place](full-place.webp) | [core-place](core-place.webp) |

Core and Full are defined in the design answers ("Two sets on one layout" and "In the Core package"): Core is words only, with the queued count, the credits shortfall and the forecast on the card; everything else in the Full pictures comes with later packages.

HUD coverage of the screen, measured on the pages (sum of the opaque slabs; the hover card is not counted):

| | Nothing | One unit | 120 units | Factory | Placement |
|---|---|---|---|---|---|
| Full | 6.6 % | 12.6 % | 20.0 % | 19.0 % | 21.8 % |
| Core | 1.0 % | 7.7 % | 8.1 % | 14.1 % | 16.9 % |

For comparison, [v3](../hud-v3/wargrid-hud-v3-notes.md) measured 33.9 % at this size without the group row, production strip and alert feed.

What is real and what is not:
- Unit and building names, costs, build times and power come from `game/scripts/simulation/definitions/`. Credits, income, health, group sizes and queue contents are illustrative.
- The world behind the HUD is the v3 concept scene recoloured to the game's palette (`game/scripts/presentation/palette.gd`, sand ground). It is not a game screenshot and not the art bible's look.
- The minimap is a sketch, not map data.
- Power reads used / available ("11 / 10" is low power); today's status line prints supply / demand.
- The glyphs are mock-up drawings (third pass), not game art; the Militia is the weakest at small size.
- The typeface is Inter (SIL Open Font License); the game has no font file yet.
- The card above the dock belongs to the cell under the drawn pointer.

Not tested: anything in Godot, a real Steam Deck, colour-vision deficiencies. The pages, the build spec, the survey of other games and the recorded picks are working files in the private notes repository (`hud-v4/`).
