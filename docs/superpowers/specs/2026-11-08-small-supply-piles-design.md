# Small supply piles as separate sources (design, 2026-11-08)

Status: approved by the user 2026-11-08 (short design); implemented and merged to `main` at `4c98b9a` (2026-11-08). Small task, not a milestone.

## Intent

Dry Wells (Tournament Desert) ships with its 4 supply docks only. Its 12 `SupplyPileSmall` (600 of the map's 2,200 boxes) are skipped, because every Wargrid source is 4 × 5 cells and the piles, about 1.3 cells apart, would overlap ([more maps](../../reference/more-maps.md)). Merging them into one source per cluster was rejected: one source serves one collector at a time, and Zero Hour serves one per pile ([M7 economy parity](../../reference/m7-economy-parity.md), mismatch 1). Goal: each small pile becomes its own 50-box source, as in Zero Hour.

- **Goals:** the full 2,200 boxes on Dry Wells; one source per pile; a pile behaves as Zero Hour's does where Wargrid models it (see the evidence below).
- **Non-goals:** a parity-harness measurement of small-pile collection (follow-up only if timing looks off); other source kinds (`SupplyPile`, `SupplyWarehouse`); map choice in the launcher.
- **Anti-goals:** any change to `skirmish.json`, Ashfall or the pinned traces and benchmarks; faction branches in simulation code.

## Approaches

1. **Per-source footprint (chosen by the user).** A source carries its own footprint; small piles are 1 × 1. On Dry Wells no piles overlap and every pile keeps 6 to 8 of its 8 dock cells free.
2. Merge piles per 4 × 5 footprint: data only, but six clusters of up to three piles keep the concurrency mismatch. Rejected.
3. Skip the piles (today's state): loses 600 boxes. Interim only.

A 2 × 2 footprint would be closer to the pile's 32-unit diameter but overlaps three pairs on Dry Wells, so it needs merging again.

## Design

- **Data.** A map source entry may carry `footprint: [w, h]` (absent means `SOURCE_FOOTPRINT`, 4 × 5) and `delete_when_empty: true` (absent means false). The simulation keeps the same rule on its source records: the key exists only for non-default sources, so sources from `skirmish.json` and Ashfall, their snapshots and state hashes stay byte-identical.
- **Simulation and view.** Every place that uses `SOURCE_FOOTPRINT` for a source (navigation blocking, the supply-clearance placement check, dock ring, map loader, `add_supply_source`, drawing, picking, labels) reads the source's own footprint.
- **Empty small piles.** Removed in the step that takes their last box, through the existing `remove_object` path, which frees their cells; the collector keeps the box and delivers it. A source carries a `delete_when_empty` flag only when set (small piles), so dock records stay unchanged. Docks are not removed.
- **Converter.** `SupplyPileSmall` becomes a separate 50-box source with footprint 1 × 1 at its own cell; no merging. Dry Wells is regenerated; Ashfall must regenerate byte-identical.
- **Verification.** Test-first per behaviour; suite totals grow, existing pins and replay traces unchanged; `sh tools/run_benchmark.sh` passes; a bot-vs-bot run on Dry Wells shows collectors using the piles.

## Zero Hour evidence

Retail root `INIZH.big` (`data\ini\object\civilianbuilding.ini`, `gamedata.ini`) and EA source `~/projects/CnC_Generals_Zero_Hour` @ `0a05454` (paths below under `GeneralsMD/Code/GameEngine/Source/`). Research notes: subagent report 2026-11-08; the removal and obstacle items were re-read by the coordinator.

| Item | Zero Hour | Wargrid after this change |
|---|---|---|
| Pile object | `SupplyPileSmall` (`civilianbuilding.ini:570-615`): KindOf `STRUCTURE IMMOBILE SUPPLY_SOURCE …`, `SupplyWarehouseDockUpdate` with `StartingBoxes = 50`, `DeleteWhenEmpty = Yes`, `NumberApproachPositions = -1`; `Geometry = CYLINDER`, `GeometryMajorRadius = 16`, `GeometryIsSmall = No`. `SupplyDock` (`:427-517`): 400 boxes, no `DeleteWhenEmpty`, BOX 50 × 61. | 50 boxes, 1 × 1 cell; docks unchanged |
| Empty pile | `SupplyWarehouseDockUpdate.cpp:113-121`: when the collector gains the last box, `destroyObject` runs in the same `action()` call, while the collector is still docked; nothing remains (`~Object` removes the pathfinding footprint, `Object.cpp:608`). How the collector's AI reacts was not verified. | removed in the step that takes its last box; the collector keeps that box and carries on (Wargrid rule, tested) |
| Docking | Boneless dock: unlimited waiters (`DockUpdate.cpp:116,167-181`), one active docker (`:417-427`), approach spot = pile centre + 8 units toward the collector, then `findPositionAround` (`:446-487`) | unchanged: one active collector per source, dock cells on the footprint's ring |
| Pathing | Obstacle: a `STRUCTURE`, immobile, not small, on the ground (`AI/AIPathfind.cpp:4181-4195`); cylinder footprint from radius 16, cells within 20 units of the centre on the 10-unit pathfinding grid (`:4267-4322`) | blocks its 1 × 1 cell (25 units, smaller than Zero Hour's ~40-unit disc: Wargrid's choice so Dry Wells' piles do not overlap) |
| Build distance | `SupplyBuildBorder = 20` (`gamedata.ini:252`) from the source's geometry edge, for `CANNOT_BUILD_NEAR_SUPPLIES` buildings, against the single nearest source (`BuildAssistant.cpp:968-994`, `Geometry.cpp:263-268`) | each supply center's `supply_clearance` (1 cell, from `m7-placement-rules.md`) measured from the pile's own footprint; Wargrid keeps testing every source, not only the nearest |
| Map | Tournament Desert: 12 piles, angle 0, owner `teamPlyrCivilian`, layer "Small Supply Piles", no box override; closest pair 32.6 units apart | 12 sources of 50 boxes |

## Left to the builder

Test names and file split; how the footprint lookup is shared between simulation, view and loader; the order of the plan's tasks.
