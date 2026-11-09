# Wargrid HUD v2 — design handoff

Editable `wargrid-hud-v2.svg` and matching `wargrid-hud-v2.png`, both 1920 × 1080. New version; earlier deliverables preserved. This is a static vector concept, not a screenshot or an implemented interface.

## Required content

- World: 25 own units, 15 enemy units. Tank body/shadow width 30 px, utility vehicles approximately 24 px, infantry 12 px; factory body width 190 px. These sizes apply at native 100% display, not a scaled chat preview. UI portraits deliberately enlarge units.
- Twelve selected units: six Medium Tanks, two Rotary Gun Tanks, four infantry. White ground diamonds; smaller diamonds for infantry. Selected factory has a thin white footprint outline.
- Ground base `#575C55`; broad low-contrast terrain planes. Owner-colored roofs use darker colors than units. No map labels, text, or UI badges. Explicit requested exceptions: health bars, veterancy chevrons and an unlabeled teammate ping.
- Health shown only for selected/damaged units, using green/yellow/red. Veterancy shown on some friendly and enemy units. All units have small shadows.
- Commands: Attack Move A, Guard G, Stop S. Sell and Set rally point live with the factory, not in the mixed-army command context. No Sell hotkey invented.
- Factory production queue has exactly nine slots, four occupied. First slot shows 42% progress; remaining capacity stays visible. Click-to-cancel hint included.
- Credits; power used/available; idle builder button; expandable minimap in the requested low-power state. Radar contents are hidden; no enemy positions leak through the disabled minimap.

## Optional proposals shown explicitly

Each panel carries an Optional label. These are proposals, not claims about existing Wargrid behavior.

1. Control groups 1–0 with unit counts. Active group marked with teal border and key, not just color.
2. Idle army count alongside idle builder count.
3. Base-under-attack and unit-ready alert feed; arrow indicates camera-jump action.
4. Global production/upgrade overview. Current example has active production and no upgrades; no new upgrade names invented.
5. Hover tooltip: Medium Tank, cost 800, base build time 10 s, hotkey W (changed from 2 by Claude 2026-11-09: digits are control groups; production uses a letter grid, Q W E R ...). “Base” distinguishes this from actual time during the displayed low-power state. Unit data: existing China definition has cost 800 and 300 ticks; ordering puts Medium Tank second in the factory menu.
6. Three-player allied team strip for 3v3: name, ownership color and connection status. “Ally 1” and “Ally 2” are sample name placeholders, not game character names.

The factory is a pinned secondary context to show factory controls alongside the active twelve-unit army selection. This is an additional layout proposal, not an established selection contract. Pinning should never redirect A/G/S away from the primary army selection. If pinning is rejected, use the same dock for separate army/factory selection states.

## Color roles

| Role | Color |
| --- | --- |
| UI interaction accent | Teal `#29C8B8` |
| World selection | White `#FFFFFF` |
| Owner blue | `#438FE5` |
| Owner red | `#E66963` |
| Owner gold | `#D4B354` |
| Owner green | `#70B76C` |
| Owner orange | `#E98A46` |
| Owner sky blue | `#7CC5EA` |
| Owner purple | `#9D7AD9` |
| Owner pink | `#E78DB5` |
| Blue / red roofs | `#326A9B` / `#9A504D` |

These are proposed exact palette values, not changes to the game's owner-color mapping. Teal is reserved for interface interaction; white is reserved for world selection. Health, ownership and teammate ping colors remain separate semantic channels. Low power uses both text and a warning color. Color-vision accessibility remains untested; distinct hex values alone do not prove perceptual separation.

## Modern UX references

- [AoE IV global build queue](https://www.ageofempires.com/news/age-of-empires-iv-season-one-update-release-notes/): persistent production visibility and navigation to the producer.
- [AoE IV minimap sizes and team grouping](https://www.ageofempires.com/news/ageiv_seasonfour_update_60878/): adjustable map size and clear allied grouping.
- [Beyond All Reason controls](https://www.beyondallreason.info/commands-2-0-grid): direct idle-builder selection and explicit control-group operations.

The mockup's arrangements are design proposals informed by these features, not measured usability claims or exact copies of those games.

## Validation and limits

Rendered and visually checked. Structural checks verify 25 own / 15 enemy units, 12 selections, nine queue slots, unique IDs, no map text, and no embedded raster images. SVG groups are named for editing. No source code in the game repository changed.

Unverified: in-engine scale against actual camera projection, input/focus behavior, tooltips near screen edges, large selection overflow, animation, disabled-radar behavior, performance and color-vision accessibility. Counts, resources, queue progress, names and status are illustrative. The enemy faction and actual map geometry are unspecified.
