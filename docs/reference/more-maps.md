# More converted maps (2026-11-07, rebased onto M7 2026-11-08)

Small task, not a milestone. Two more maps converted with `tools/zh_map/convert.py` (`convert.py <map> <out.json> <name>`), same rules as Ashfall (AGENTS.md map-data rule; notice in `game/data/maps/NOTICE.md`). Sources are 4 × 5 cells and starts carry M7's six slots (`power_plant`, `supply_center`, `barracks`, `factory`, `command_center`, `defence`).

| Wargrid name | Source (CnC_Modding_Support `3aad8e4`, `Zero Hour/Maps/official/`) | Cells | Seats | Sources |
|---|---|---|---|---|
| Dry Wells | `Tournament Desert/Tournament Desert.map` | 81 × 108 | 2 | 4 docks of 400 (12 small piles not converted, see below) |
| Broken Crown | `Fallen Empire/Fallen Empire.map` | 112 × 100 | 4 | 8 docks of 400 |

## Converter changes

- **Water height.** Fallen Empire has one water polygon (height 7) over the whole map, with terrain above it. A cell is now wet only when the polygon contains it and the ground height is below the polygon's height. Before, every start was "wet" and the conversion failed (`start not open: seat 1`). Tournament Desert's wet cells fell from 372 to 259. Twilight Flame has no water; `ashfall.json` regenerates byte-identical to `main`.
- **Skipped:** two `TechOilDerrick` on Tournament Desert (no tech buildings in Wargrid).

## Small piles: not converted yet (user, 2026-11-08)

Tournament Desert has 12 `SupplyPileSmall` (`StartingBoxes = 50`, `data\ini\object\civilianbuilding.ini:570` in the pinned root `INIZH.big`; no map override) in two clusters, 600 of the map's 2,200 boxes. Dry Wells ships without them until sources can have their own footprint.

- A first version merged piles closer than one footprint into one source. [M7 economy parity](m7-economy-parity.md) lists that as a mismatch: one source serves one collector at a time, so a merged cluster serves one collector where Zero Hour serves one per pile.
- Under M7's 4 × 5 source footprint the 12 piles form 8 overlapping pairs, so they cannot be separate sources either.
- A small pile is a cylinder of radius 16 units (`civilianbuilding.ini:570`), about 1.3 cells across; the closest two are 32.6 units apart. With a 1 × 1 footprint none overlap (2 × 2: 3 pairs).
- Planned as its own small task: a per-source footprint (small pile 1 × 1), then convert the piles as separate 50-box sources.

## Converter report

Dry Wells: route 1-2 1525.0 (source grid 1524.1, ratio 1.001), width t = 10; buildable within 12: 625 / 625; supply Chebyshev 20 / 15.

Broken Crown: routes 1-2 1850.0, 1-3 2512.7, 1-4 1600.0, 2-3 1600.0, 2-4 2512.7, 3-4 1850.0 (ratios 0.985 to 0.995); widths t = 13 to 15; buildable within 12: 625 each; supply Chebyshev 13 to 16.

## Not done

No map choice exists in the launcher, offline or online: the online `start` message carries no map. That belongs to the "Ashfall playable" task (blueprint §7), which has no design yet.
