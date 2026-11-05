# M6: teams, full-scale map, combat and movement feel design

Status: **DESIGN APPROVED** by the user on 2026-11-05. Implementation starts only on explicit kickoff, using the [execution plan](../plans/2026-11-05-m6-teams-full-map.md).

Related docs:
- Scope and exit gate: blueprint §7 M6; map-scale cost note in §11.
- Source evidence: [M6 map and feel evidence](../../reference/m6-map-and-feel.md); measured values: [parity spike](../../reference/zero-hour-parity-spike.md).
- Rules this design changes: [M1 vehicle plan](../plans/2026-11-01-m1-vehicle.md) (instant movement), [M4 design](2026-11-03-m4-combat-design.md) (range, cadence, no splash), [M5.1 design](2026-11-05-m5.1-playtest-findings-design.md) (two-player hostility).
- Budgets: [performance ledger](../../reference/performance.md).

## Intent

Move from a 1v1 on a 48×32 test field towards the long-term target (blueprint §1): three friends against three bots on a map that plays like Twilight Flame. M6 delivers the map and team play in the simulation, makes combat and movement feel like Zero Hour, and proves the cost fits a low-end device before content and bots grow on top of it.

Success:
- A deterministic headless 3v3 match of bots on the full-scale map runs to a team victory, and its ledger rows are inside the budgets.
- The map has Twilight Flame's scale, elevation (cliffs and ramps), eight start positions and attack routes.
- Units fire at Zero Hour's edge-to-edge distances, Rangers fire at the measured cadence, tank shells splash, and units start, accelerate and turn like Zero Hour.

**Non-goals:** playing or watching the big map (camera, minimap, big-map rendering), online play with more than two seats (M9), bot strategy beyond the existing skirmish policy (M8), turrets and turn-to-aim before firing (departure, later), China and GLA (M7), fog of war, elevation effects on combat, air-unit movement feel, civilian buildings and trees as obstacles.

**Anti-goals:** a budget, tolerance or pin moved to make a row pass; a measured number adopted without its decision; EA's map shipped without its notice; non-deterministic movement (platform-dependent trigonometry) breaking cross-platform traces.

## Approaches

User picked B on 2026-11-05.

- **A.** Split: M6 = map, teams, scaling (existing 1v1 pins unchanged, a free regression check for the team refactor); M6.1 = combat and movement feel plus Chinook, one pin recalibration. Two ledger rounds.
- **B (chosen).** One M6, ordered map and teams first, then the feel changes, then measurement and scaling last, so the ledger rows measure the final mechanics. One exit gate, one recalibration at the end.
- **C.** Feel first on the small map, then teams and scale. Rejected: builds feel before knowing whether the big map fits the budget.

## User decisions (2026-11-05)

- Headless is enough. The 1v1 skirmish stays on 48×32; no big-map presentation.
- Range: edge-to-edge. Ranger cadence: measured 4/4/22. Tank splash: added. Movement: start delay, acceleration/braking and turn-in-place, all three.
- Map: converted by a repo tool from EA's GPL `Twilight Flame.map` (CnC_Modding_Support `3aad8e4`); EA copyright notice and additional terms kept with the derived data; Wargrid's own map name; AGENTS.md amended to allow GPL-released map sources. What matters most: scale, terrain elevation, starting positions, attack routes.
- Elevation affects passability only: cliffs block, ramps connect; height is kept per cell for later rendering.
- Teams as proposed below; splash follows Zero Hour's default and hurts own and allied units (INI mask checked first).
- Firing ignores heading in M6: no turret, no turn-to-aim; recorded as a departure for later.

"My call" marks a planning default the user can overrule.

## Ordering inside M6

1. Map converter and map data; simulation loads a map from data.
2. Seats, teams and team victory; bots in every seat; the 3v3 match harness (first, current mechanics; a baseline measurement, no gate).
3. Combat feel: edge-to-edge range, cadence, splash.
4. Movement feel: start delay, acceleration and braking, turn-in-place.
5. Chinook supply scenario fixed in the parity harness; M3 collector timing decided from it.
6. Measure the 3v3 match, then the smallest scaling fixes, measured again.
7. Pins (skirmish match, netplay, replays, BM6) confirmed once on the final tree; the feel tasks re-pin them provisionally inside their windows so the suite stays green (plan Global Constraints). Then benchmark and rendered rerun, ledger rows.

The 1v1 match must stay identical through steps 1–2 (my call): same per-tick `core_check` (positions, HP, credits) and same outcome pins; the full digest may change only by new snapshot fields (team ids, per-seat survival, height). That proves the map loader and team refactor change nothing for two players on one team each.

## Map

**Converter (my call: Python, `tools/zh_map/`, stdlib only).** Reads the `.map`: RefPack decode, `CkMp` chunks, `HeightMapData`, the painted cliff bits from `BlendTileData` (layout still to read; height rule `> 9.8` over the corners only as fallback for older versions), water polygon triggers, and `ObjectsList` start waypoints `Player_1_Start … Player_8_Start` and supply objects. It writes Wargrid map data. Runs only on the user's machine with the EA checkout; CI tests the converter on small synthetic chunk files and tests the committed output, never needs the EA checkout (M0 rule). The RefPack decoder is a small algorithm ported from `refdecode.cpp` with the comment the porting rule requires (repo, revision, path, EA copyright line, pointer to the additional terms).

**Resampling (my call).** Zero Hour samples every 10 units; Wargrid keeps 25-unit cells (blueprint §14), so 2.5 × 2.5 samples fold into one cell. A Wargrid cell is blocked when at least half of its area is cliff or water; height is the mean of its samples. Zero Hour's one-cell cliff dilation is not copied (it is a 10-unit pathfinder detail). The converter asserts that every start reaches every other start through open cells and prints the narrowest width of each route between neighbouring starts, so a ramp that vanished in the resampling fails the conversion instead of silently changing the map.

**What is converted:** playable area only (border dropped), cell passability, cell height, eight starts, supply sources with their box count (from the object dict, else the template's INI `StartingBoxes`, read from `INIZH.big` with the existing parity tooling, recorded in the evidence note). **Not converted (my call):** trees, civilian buildings, oil derricks and other tech buildings, scripts, teams, lighting. Each skipped object class is listed in the evidence note; civilian buildings that block a route would be a fidelity gap noted there.

**Data file (my call).** `game/data/maps/<name>.json`: size, rows of passability characters (`.` open, `#` cliff, `~` water), rows of heights, starts (cell, seat number from the waypoint), supply sources, a `notice` field with EA's copyright line and a pointer to `game/data/maps/NOTICE.md` (EA's additional terms and the source path and revision). Map name (my call): **Ashfall**; anything not "Twilight Flame".

**Simulation.** `Simulation.new` already takes obstacles and a size; a loader builds those from the file. Blocked map cells behave like today's obstacles. Building placement rejects blocked cells. Height is stored but unused by rules.

## Seats, teams and victory

Confirmed by the user on 2026-11-05 (proposed as my calls, then accepted):
- Up to eight seats, each with a team id; `start_match` takes 2–8 players with teams. Hostile means different team; all `owner != x` hostility checks go through one rule (`combat.gd`, `skirmish.gd`, `scripted_human.gd`). Allies never target each other.
- Splash follows the weapon's `RadiusDamageAffects` mask from INI: if it includes allies (the source default), splash hurts own and allied units.
- A team loses when none of its seats survives (today's `_survives` per seat); the match ends when one team remains. The winner field becomes the winning team, with per-seat survival in the snapshot.
- Supply sources and producers stay per seat; no shared money or shared control.
- Lockstep, relay and the online scene stay two-seat (M9).

**Bots.** Each bot seat runs the existing `Skirmish.issue_opponent` policy unchanged in spirit: build order, production, base defence, attack after `ATTACK_TICK`, now against the nearest hostile seat. Base slots are map data per start (my call): the 48×32 skirmish map lists today's `LEFT_ORIGINS` and their mirror, so the 1v1 keeps its placement; the converter computes slots for the big map by a deterministic search around each start (nearest buildable footprint in a fixed spiral order) and commits them in the JSON. One placement path in the simulation. The 3v3 seats and teams are picked from the converted starts so each team holds one half of the map (my call; listed in the plan with their coordinates).

**If the 3v3 match does not end (my call).** The harness has a tick cap. The plan may tune harness constants (seat choice, `ATTACK_TICK`) but not the policy's logic; if no team wins under the cap, the exit gate is reported as not met and the user decides (M8 owns bot strategy).

**Same-tick cases** for every changed command (plan lists them): team hostility under attack, attack-move and retaliation; two allies hitting one enemy; splash killing an ally and an enemy in one tick; the last seat of a team dying on the same tick as the last seat of the other team (draw rule: my call, both eliminated in one tick is a draw, as today's two-player rule).

## Combat feel

- **Range.** Fire when `centre distance − r_attacker − r_target ≤ range − 0.1 cell` (Zero Hour's 2.5-unit undersize). Every unit and building kind gets a bounding radius in Wargrid's definitions: units from the Zero Hour geometry (INI, read and recorded first; the measured maxima are the check), buildings from their own footprint (half diagonal, matching Zero Hour's box rule). Applies to acquisition, firing, chase destination and `_firing_cell`.
- **Cadence.** Rifle 4/4/22 (`delay_ticks` 4, `reload_ticks` 22). Documented as "measured on the source build, VC6 unverified".
- **Splash.** Cannon gets primary and secondary radius and damage from INI (read first), step function, no falloff, victims by distance minus their radius, mask from INI. Splash events appear in combat events and traces.

## Movement feel

- **Start delay.** A unit starts moving on the third tick after its order is applied (measured 3 frames). Same rule for move, attack-move, chase and production exit (my call: production exit included, since Zero Hour's exit is a move order).
- **Acceleration and braking** per kind from INI (measured matches: Ranger 100/100, Dozer 30/50, Crusader 1000 without the first-frame lurch). Braking so the unit stops on its destination, no overshoot.
- **Turning** with a heading per unit and `TurnRate` per kind. Treads (tank): Zero Hour's goal-speed rule, turn in place at ≥ 45° error. Wheels (builder, vehicle): no turn in place, minimum turn speed. Legs (infantry): turn in place (measured: 180° then move, 11 frames); the source rule is still unread, the plan reads it first.
- **Determinism (my call, required).** No runtime `sin`, `cos`, `atan2` or other libm functions in the simulation: headings are unit vectors, turning rotates by per-kind constants written as literals, angle tests use dot and cross products. `sqrt` stays (IEEE-exact). Cross-platform trace comparison (CI compare-replays) is the check.
- **Air units** (collector) keep instant movement (non-goal).
- **Presentation (my call).** The 48×32 view draws a small heading mark per ground unit, so turn-in-place and the start delay read as turning, not as a stall; covered by a headless view test and the rendered rerun.
- Allocation and arrival keep their M2 contracts: destinations and slots unchanged, only the path along the route changes.

## Chinook supply scenario

Fix the parity scenario first: the evidence points to the harness spawning `AmericaSupplyCenter` without `onBuildComplete()`, so the centre never registers. Then measure a full trip (load, flight, deposit, money per trip) and decide M3's provisional collector timing from it in the decision list. A measured value never changes Wargrid automatically.

## Scaling

Measure first on the 3v3 match (current, then final mechanics), with machine-independent counters. Known suspects: `snapshot()` copies the whole terrain and navigation on every call, and every bot calls it every 30 ticks; navigation rebuilds and `Allocation.assign` grow with map area; acquisition scans (P3 not approved); path queue bursts on attack ticks. The 3v3 rows (my call): sim-only tick p50/p95/p99/max over the match after a 300-tick warmup until victory or the cap, against the existing per-tick sim budgets; bot decisions count inside the sim tick (bots run in the simulation on every client, §11); the row records peak and mean unit count, since the budgets were set at 300 units and the match has no unit cap. Fix only what the measurement names, smallest fix first; each fix that needs a new structure (an index, incremental navigation) is proposed to the user before building. Budgets stay as they are; a row that does not pass is reported as exceeded.

## Acceptance

- Converter: synthetic-chunk unit tests; committed map passes connectivity and route-width assertions; NOTICE present.
- Map loader, teams, victory: behaviour tests per rule and every listed same-tick case; 1v1 traces identical after steps 1–2.
- Combat and movement: spec-worded tests per rule (range at the measured maxima, 4/4/22 cycle of 30, splash hits and mask, start on tick 3, acceleration curve, 45° turn-in-place, no wheel turn-in-place); parity results for the measured cases recorded beside Wargrid's.
- 3v3: deterministic headless match to a team victory; trace compared across platforms in CI (a shorter fixed-tick prefix if the full match is too long for CI, my call).
- Exit gate: `sh tools/run_benchmark.sh` passes with the 3v3 rows and the recalibrated BM6; rendered benchmark rerun (movement presentation changes); new ledger rows; all pins recalibrated once with the reasons recorded.

## Left to the builder

- `BlendTileData` layout and where the cliff bits sit; INI values (geometry, locomotors, Crusader weapon, `StartingBoxes`, `ValuePerSupplyBox`); Legs locomotor rule.
- Exact JSON layout and the loader's API; which existing tests move to the new map vs stay on 48×32.
- The scaling fixes, after measurement and user approval where they add structure.
- Pin recalibration values, each with its cause.
