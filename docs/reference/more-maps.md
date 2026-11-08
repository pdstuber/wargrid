# More converted maps (2026-11-07, rebased onto M7 2026-11-08)

Small task, not a milestone; merged to `main` at `4c98b9a` (2026-11-08). Two more maps converted with `tools/zh_map/convert.py` (`convert.py <map> <out.json> <name>`), same rules as Ashfall (AGENTS.md map-data rule; notice in `game/data/maps/NOTICE.md`). Supply docks are 4 × 5 cells, small piles 1 × 1, and starts carry M7's six slots (`power_plant`, `supply_center`, `barracks`, `factory`, `command_center`, `defence`).

| Wargrid name | Source (CnC_Modding_Support `3aad8e4`, `Zero Hour/Maps/official/`) | Cells | Seats | Sources |
|---|---|---|---|---|
| Dry Wells | `Tournament Desert/Tournament Desert.map` | 81 × 108 | 2 | 4 docks of 400 + 12 small piles of 50 |
| Broken Crown | `Fallen Empire/Fallen Empire.map` | 112 × 100 | 4 | 8 docks of 400 |

## Converter changes

- **Water height.** Fallen Empire has one water polygon (height 7) over the whole map, with terrain above it. A cell is now wet only when the polygon contains it and the ground height is below the polygon's height. Before, every start was "wet" and the conversion failed (`start not open: seat 1`). Tournament Desert's wet cells fell from 372 to 259. Twilight Flame has no water; `ashfall.json` regenerates byte-identical to `main`.
- **Skipped:** two `TechOilDerrick` on Tournament Desert (no tech buildings in Wargrid).

## Small piles (2026-11-08)

Design: [small supply piles](../superpowers/specs/2026-11-08-small-supply-piles-design.md); plan: [execution plan](../superpowers/plans/2026-11-08-small-supply-piles.md). Tournament Desert's 12 `SupplyPileSmall` (`StartingBoxes = 50`, `data\ini\object\civilianbuilding.ini:570` in the pinned root `INIZH.big`) are now separate sources.

- Rule: 1 × 1 footprint, 50 boxes, removed in the step that takes the last box (`delete_when_empty`); the collector keeps the box it carries. Docks are unchanged (4 × 5, 400, never removed). Only non-default sources carry `footprint` / `delete_when_empty`.
- Converter: emits piles as their own sources and checks that no two footprints overlap. Ashfall and Broken Crown regenerate byte-identical.
- Checks on 82c4c53 (Apple M6, headless): suite `CASES 504 CHECKS 136252 FAILURES 0` (baseline 493), converter 19 tests OK, lint, warnings and python checks exit 0, `sh tools/run_benchmark.sh` exit 0 (`BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1`, same as the baseline on 36c39e0).
- Bot vs bot on Dry Wells (scratch script, cap 45,000 ticks): small boxes left at the end / piles removed: USA-USA 510 / 1 (cap), China-China 600 / 0 (ends tick 10,200), FRC-FRC 598 / 0 (10,500), USA-China 550 / 1 (11,400), China-FRC 600 / 0 (10,800), FRC-USA 595 / 0 (26,100). Collectors mostly stay on the docks, so this is data, not a failure. Forced run USA-China with every dock set to 0 boxes (cap 15,000): ended tick 11,700, 1 pile removed, 486 small boxes left (first pile below 50 at tick 1,200); credits are spent by the bots, so the credit trace (max 18,200, end 275) does not show the rise on its own, the 114 boxes taken do.
- Rendered (window, `vsync=off`, 1280 × 720, camera on the eastern cluster, single run): see the [performance ledger](performance.md) row 2026-11-08 small supply piles; no regression against the old map.
- Not measured: parity-harness timing (design non-goal).
- Playtest item: labels of neighbouring 1 × 1 piles overlap on screen.
- Builds before and after this change must not play Dry Wells online together (the map file and the sim records differ).

## Converter report

Dry Wells: route 1-2 1525.0 (source grid 1524.1, ratio 1.001), width t = 10; buildable within 12: 625 / 625; supply Chebyshev 20 / 15.

Broken Crown: routes 1-2 1850.0, 1-3 2512.7, 1-4 1600.0, 2-3 1600.0, 2-4 2512.7, 3-4 1850.0 (ratios 0.985 to 0.995); widths t = 13 to 15; buildable within 12: 625 each; supply Chebyshev 13 to 16.

## Dry Wells is the play map (user, 2026-11-07)

Real play uses Dry Wells: the launcher sets `SkirmishMain.map_path` (as it sets `SkirmishMain.factions`) before it opens the offline or online scene, and the scenes pass it to `Skirmish.create` as the fourth argument after `factions`. Without the launcher, scenes, tests, replays, the netplay client and benchmarks keep the 48 × 32 `skirmish.json`, so every pin is unchanged (user, 2026-11-08: tests may use the old map). The camera starts on the local player's base instead of the map centre.

- Bot vs bot on Dry Wells after the rebase onto M7 (scratch script, `Skirmish.issue_opponents` for both seats, cap 45,000 ticks, Apple M6, headless; `f254fba`..`28e3ba1`): every pair fights (first combat tick 6,000-7,800). Wins: China-China seat 1 at 9,600, USA-China seat 1 at 9,900, China-FRC seat 2 at 10,800, FRC-USA seat 2 at 44,100; USA-USA and FRC-FRC still ongoing at the cap. Same script on `skirmish.json`: FRC-FRC also ongoing at the cap and USA-USA ends at 34,800, so long mirror matches are existing bot behaviour, not the map.
- Rendered frame time on Dry Wells after the rebase: measured in the small-piles section above and the 2026-11-08 ledger row in [performance](performance.md).
- The terrain cache this needed (`terrain_view.gd`, ledger row 2026-11-07) reached `main` through M7 (`a1dfb03`).
- Online play uses a different map than the CI netplay client, which still plays `skirmish.json`. Old and new builds must not play each other online.
- Still no map choice in the launcher and the online `start` message carries no map: that belongs to the "Converted maps playable" task (blueprint §7).
