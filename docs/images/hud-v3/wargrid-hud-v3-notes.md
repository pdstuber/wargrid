# Wargrid HUD v3

- wargrid-hud-v3-deck: 1280×800; HUD 346,952 px² = 33.88%
- wargrid-hud-v3-compact: 1920×1080; HUD 379,200 px² = 18.29%
- wargrid-hud-v3-bigselect: 1920×1080; HUD 499,392 px² = 24.08%
- wargrid-hud-v3-placement: 1920×1080; HUD 570,832 px² = 27.53%

Coverage is the union of opaque HUD panel rectangles, including collapsed controls hosted inside docks. World selection, placement previews, pings and local grid are excluded. Placement contains two clipped camera views at native object scale, not two scaled-down screenshots.

Deck uses a narrower camera viewport, not scaled world objects. All SVG text is at least 13 px. Q/W are factory production; E/R are available when more context actions exist. Builder palette uses Q/W/E/R. Digits remain control groups.

Large selection contains 120 own selected units plus the 15 enemies. Six kinds are represented: Medium Tank 36, Rotary Gun Tank 24, Militia 24, Anti-Tank Trooper 12, Supply Truck 12, Bulldozer 12. Both infantry kinds share the simplified world silhouette. Kind cards show count and aggregate health. Proposed drill-down uses pages of 12; this frame shows the grouped overview.

Compact/deck collapse optional UX into labeled toggles; hover surfaces are closed in the measured frames. Placement is a modal context, so the nine-slot production queue and army selection panel are replaced by builder placement controls. Shared scene data is retained behind the two viewport clips.

Static vector concepts only. Font size and panel area checked; actual Steam Deck readability, interactions, Godot import and accessibility untested.
