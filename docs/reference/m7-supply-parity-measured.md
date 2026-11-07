# M7 supply cycle measured in Zero Hour (2026-11-07, narrowed sweep, 30-cell rows pending)

Status: harness extended and working; the narrowed sweep ran as parallel instances (ports via `ZH_PARITY_PORT`, no clashes seen with 5-8 concurrent games). Labels: **measured (source build)**, **formula** ([m7-economy-parity.md](m7-economy-parity.md) section 3), **Wargrid today** (headless scratch sim on the working tree, see below), **unverified**. Zero Hour names appear only here as evidence.

## Provenance

- Wargrid tree: `b7c9ae3` on `m7-factions` plus uncommitted work of other agents (definitions with `SOURCE_FOOTPRINT` 4x5) and the uncommitted harness change.
- Fork: `~/projects/GeneralsGameCode-macOS` branch `wargrid-parity` @ `eb595cfc9`, binary `build/apple-arm64-release/GeneralsMD/Release/generalszh_api`, always `-headless -noaudio`. No fork change was needed.
- Scenarios `collect_<chinook|truck|worker>_<6|12|30|0>` and `_12_x2` in `tools/zh_parity/parity.py` (`collect()`), metrics in `analyze.py` (`collecting()`; `analyze.py --traces DIR` prints one JSON line per `collect_*` trace). Distances are centre to centre in cells (6/12/30 = 150/300/750 units); `_0` = nearest legal depot spot found by retrying `build_structure` every 5 units (the API rejects illegal spots); `_x2` = a second collector trained at the depot.
- Setup per run: neutral `SupplyDock` (400 boxes, INI), one builder (dozer or worker) builds the faction power plant if needed, then the depot; the depot's free collector starts the loop by itself. Standard skirmish money (10000, read from `/players`). Credits seen as increases of the API player's money each logic frame; a deposit is one increase. Rate = credits after the first deposit / frames between first and last deposit x 1800.
- Scratch traces: `/private/tmp/claude-501/-Users-pdstuber-projects-wargrid/77c02dce-6b2d-4f3e-b2bf-73a55134f5e7/scratchpad/` : `t0/collect_truck_6.tsv`, `r4/` (chinook 6/12/12_x2, truck 12, worker 6/12; first worker_0 from a scan starting at 30 units), `r5/collect_worker_0.tsv` (scan from 5 units, final). Nothing written to `~/CnC/parity/traces`.

## Harness findings (measured)

- A raw `spawn` of a depot gives a collector that never deposited (stood about 45 units away, money unchanged in 1400 frames). A raw-spawned extra collector never self-starts. So depots are built by a builder and extra collectors come from `train_unit`.
- The API player's faction is random per game; spawned builders of the wanted faction work regardless.
- Closest legal depot: the GLA stash is accepted by the API legality check at 90 units (3.6 cells) from a 400-box dock (scan 5-unit steps from 5; nearer spots were refused or `buildObjectNow failed`). A first scan starting at 30 units reported 30 units, which the later scan contradicts; treat 90 as the answer. The Chinook and truck `_0` rows were still running.
- Killing Fields has no 1000-unit strip that is flat to 2 height units; the 30-cell rows use a 60-wide strip with slope up to 12 (a gentle slope, affects speed little).

## Pooled results (ZH measured, source build; 3 runs per row, uncapped engine loop)

Method: each run builds a depot (builder), then records one collector (or several) for at least 8 deposits per collector; 3 independent games per row (random faction and seed per game). Pooled = all credits after each run's first deposit / all frames first to last deposit x 1800; spread = (max - min) / pooled across the 3 runs. Phases = median cycle frames (travel / standing nearer the pile / standing nearer the depot; position-based, includes dock handling). Wargrid today = scratch sim `wg_supply2.gd` on the working tree (base `b7c9ae3` plus uncommitted tree), c-c 6.5 / 12.5 / 30.5 cells = 162.5 / 312.5 / 762.5 units. Traces: scratchpad `.../scratchpad/U/rep1..rep3` (`.tsv` + `.log` per run). Fork `eb595cfc9`, run `-headless -noaudio`, `GEN_FPS_CAP=0`.

| collector | distance (units) | runs | ZH pooled credits/min | spread | cycle phases | Wargrid today | Wargrid vs ZH | within 5 %? |
|---|---|---|---|---|---|---|---|---|
| Chinook | 162.5 | 3 | 1646 | 0.0 % | 657 (289 / 309 / 57) | 2438 | +48 % | NO |
| Chinook | 312.5 | 3 | 1468 | 0.0 % | 733 (359 / 317 / 57) | 2147 | +46 % | NO |
| Chinook | 762.5 | 3 | 1181 | 0.0 % | 847 median gap (airborne, not split) | 1581 | +34 % | NO |
| Chinook x2 | 312.5 | 3 | 2770 (1.89x one) | 0.0 % | | 3743 | +35 % | NO |
| Chinook x4 | 312.5 | 3 | 3116 (2.12x one) | 0.3 % | | 3743 | +20 % | NO |
| China truck | 162.5 | 3 | 1294 | 2.2 % | 410 (172 / 188 / 50) | 1598 | +23 % | NO |
| China truck | 312.5 | 3 | 829 | 1.0 % | 650 (412 / 188 / 50) | 957 | +15 % | NO |
| China truck | 762.5 | 3 | 407 | 0.2 % | 1330 (1092 / 188 / 50) | 436 | +7 % | NO |
| China truck x2 | 312.5 | 3 | 1668 (2.01x one) | 0.5 % | | 1931 | +16 % | NO |
| China truck x4 | 312.5 | 3 | 2814 (3.39x one) | 0.2 % | | 3588 | +28 % | NO |
| GLA worker | 162.5 | 3 | 434 | 0.4 % | 312 (148 / 84 / 79) | 808 | +86 % | NO |
| GLA worker | 312.5 | 3 | 201 | 0.0 % | 673 (509 / 84 / 80) | 256 | +28 % | NO |
| GLA worker x2 | 162.5 | 3 | 855 (1.97x one) | 1.2 % | | 1623 | +90 % | NO |
| GLA worker x4 | 162.5 | 3 | 1590 (**3.66x one**) | 1.1 % | | not run at this layout (spawn spots overlapped the pile; 1037 at 312.5 = 4.05x one) | n/a | n/a |
| GLA worker | 762.5 | 0 | **not measured**: the worker made 1 deposit in 22000 frames (all 3 runs) | | | 84 | n/a | n/a |

Findings:
- **Worker x4 / x1 = 3.66 (spread 1.1 %), above the plan's 3.6 stop line by 1.8 %.** Two workers give 1.97x, four 3.66x: dock handling of several workers overlaps, so it is not held per dock. A ZH deposit costs the same time per worker with 4 on a pile (the pile does not serialise them, unlike Wargrid's one-docker rule). Whether 3.66 is "above 3.6" is inside the noise of a 1 % spread; it is the sign, not the margin, that matters for the fold rule.
- Chinook: the 762.5-unit pooled 1181 matches the plan's constant-model prediction of 1180 (identical in all 3 runs; Chinook runs are fully deterministic here). Multi-Chinook scaling is weak: 2 give 1.89x, 4 give 2.12x one.
- Truck: scales to 2.01x with 2 and 3.39x with 4.
- Truck phases differ between sweeps: capped-loop runs earlier today gave 424 (186 / 188 / 50) at 162.5; this uncapped sweep 410 (172 / 188 / 50), and the 6-cell run 388-389 (150-151 / 188 / 50) against 409 (171 / 188 / 50) in the first capped run. Chinook and worker phases are identical between the capped and uncapped sweeps. The truck differences are 14-21 travel frames, i.e. the truck's route depends on something that varies between sweeps (random faction and builder position, strip choice); treat the truck pooled value as +-3 % uncertain, which is smaller than every Wargrid deviation but matters at the 5 % gate for the 762.5 row (+7 %).
- Wargrid worker x4 and the worker 762.5 rows need harness work (spawn spacing, a collector that keeps working beyond the 700-unit scan).

## Legal minimum depot-to-pile distance (source-read, not measured)

From the placement-rules note (`SupplyBuildBorder` 20 units, centre to centre along the pile's 50-unit half-extent): USA supply centre 114 units (4.56 cells), China supply centre 122 units (4.88 cells), GLA stash 106 units (4.24 cells). The coordinator's message listed stash 114 / USA 122 / China 106; the planning doc, which I follow, has USA 114 / China 122 / stash 106. **Unverified.** The API's own legality check could not measure it (it accepted overlapping placements 5 units from a spawned dock), so the closest-legal (`_0`) rows were dropped.

## Harness notes

- The macOS loop is capped at 30 Hz; `GEN_FPS_CAP=0` in the game environment makes a recorded frame about 27x cheaper (a 14000-frame collect run took 12 s instead of 7 min). `parity.py` now sets it by default (`ZH_PARITY_FPS_CAP` overrides).
- Each game now runs in its own session and `close()` kills its process group; SIGTERM is turned into `SystemExit` so the lane's `finally` runs. The batched `step(n)` option is kept but not needed and unproven; use `batch=1`.
- Ports: REST `p` and WS `p+1`, so lanes need ports at least 2 apart.
- Control for the spawned neutral `SupplyDock` (may not be a pathfinding obstacle): not run.

## Unverified / missing

- Worker at 762.5 units; Wargrid worker x4; map-placed-pile control; legal minimum distances; capped-versus-uncapped equality for the truck (one capped control run was still unfinished).
- The Wargrid scratch script lives only in the scratch dir (`wg_supply2.gd`).
