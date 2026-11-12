# Unit avoidance: what Wargrid's own code and rules constrain
(repo ~/projects/wargrid, tree main c04ef27; paths relative to it. "source" = read in code/docs, "inferred" = my reading.)

## Findings (short, cited)
- **Scope is undecided.** Blueprint says only: units go around each other, "a firm requirement from the M7 gate 2 playtest", re-pins every trace, needs own benchmarks, a design spike on one map first, a playtest; risks named: docks, chokepoints, trucks, container boarding, horde clusters, lockstep determinism, WASM cost. Source: docs/blueprint.md:554. "Scope not designed": blueprint.md:547. Comes after converted maps, before ground batch A: blueprint.md:549.
- **Overlap is a deliberate M2 choice**, not a bug: "Reserve destination cells; permit temporary overlap in transit" (docs/superpowers/plans/2026-11-01-m2-groups.md:7); "User chose temporary overlap during travel and distinct reserved destination cells" (docs/reference/group-movement.md:3); blueprint.md:469. Destination reservations exist and use a cell-to-set-of-IDs because overlap is allowed (m2-groups.md:107).
- **No unit collision anywhere in movement.** Units are points: "no footprint clearance, unit collision, dynamic blockers" (docs/reference/movement.md:9). Pathing is 4-way A* (AStarGrid2D) on a cell grid, no diagonals, static obstacles only: game/scripts/simulation/grid_navigation.gd:5,12,108-127. Route waypoints are cell centres plus the exact final target (grid_navigation.gd:120-125).
- **Movement step** is `Simulation._advance` (game/scripts/simulation/simulation.gd:599-626): walks the route at `Locomotion.step` speed; no look at other units. Locomotion (game/scripts/simulation/locomotion.gd:3-31) handles heading, accel, braking to the route end only. Any avoidance must either alter the route (replan) or the per-tick step; both hit these two functions.
- **Units already have radii** for combat (game/scripts/simulation/combat_definitions.gd:16-26, `radius(kind)`, cached), so a collision radius could reuse it. Horde code already has a per-cell spatial bucket (game/scripts/simulation/horde.gd:40-70) and combat has a per-owner target grid; the blueprint expects the spike's grid to be reused (blueprint.md:555).
- **Path requests are rate limited**: at most 8 route searches per tick, queue order (simulation.gd:18, 463-468). Frequent avoidance repaths would starve the queue; a path_pending unit does not move.
- **Positions are floats** (GDScript doubles) in arrays `[x, y]` (simulation.gd:85, 599-624), hashed bit-wise in the state hash (game/scripts/simulation/state_hash.gd:16-26, `_mix` float branch). Locomotion uses a hand-written polynomial atan instead of libm (locomotion.gd:39-50) and the M2 note says scalar float motion was chosen to avoid Vector2 float32 drift (group-movement.md:7). Inferred: avoidance math should follow that style (only + - * / sqrt, no sin/cos/atan2, no Vector2 accumulation, fixed iteration order, sort by id). Cross-platform determinism is "not assumed automatically" (blueprint.md:148) but CI compares Linux and Windows traces (docs/development.md:76) and M5 showed identical traces on three platforms (blueprint.md:749). Neighbour-iteration order over a Dictionary/hash bucket is the main new nondeterminism risk (inferred).
- **Trucks/docks depend on exact position equality.** A collector counts as at its dock only when `unit.position == _arrival(...)` (game/scripts/simulation/supply_collection.gd:142, 175; also :111, 118). Each truck claims a distinct dock cell around the pile/depot ring (supply_collection.gd:40-66, `_claim_dock`), with a small per-target offset so spots differ (:29-35). Waiters queue first-come (:120-127). Any avoidance that nudges a truck off its exact spot breaks admission; docks need an exemption or a tolerance (inferred). A blocked flying_ ground truck gives up, releases and retries after 30 ticks (:164-168).
- **Dock and building approach cells**: ground units finishing orders use `Construction.approach`/free cells; units that end a move on an occupied cell are pushed by allocation, not by movement (game/scripts/simulation/destination_allocation.gd:5-50; `occupied_cells` at simulation.gd:92-98 includes destinations).
- **Container boarding** (tunnels, Chinook-style carriers): a unit boards when edge gap to the host <= BOARD_GAP, not at a point (game/scripts/simulation/containers.gd:80-84); head_for queues a path (containers.gd:55-62). Passengers are teleported to the host position while inside (containers.gd:64-69, 113) and unloaded to the nearest free cell (containers.gd:130-140, `_free_cell`). So boarding already tolerates overlap near the host; unloading already needs free cells (inferred: avoidance there is cheap to make consistent).
- **Hordes** are measured by distance between units (horde.gd:74-90, `_gap_between` with radii), i.e. horde bonuses depend on units being close. Avoidance spreading units out may break hordes or force a larger horde radius (inferred; horde ledger rows exist in docs/reference/performance.md).
- **Move-vs-combat repath**: attack-move halt/resume and chase repath go through `_assign_move` -> `Allocation.assign`, 2.2-2.4 ms per call on big maps (docs/reference/performance.md:30); combat repaths on REPATH_TICKS (simulation.gd:402). Avoidance replans would multiply these.
- **Traces and pins that will change** (all re-pin once, per blueprint.md:555): TEAM_CORE_SERIES (game/tests/test_team_match.gd:15,95), S1_CORE_SERIES and the terminal ticks/winners of the skirmish matches (game/tests/test_skirmish_match.gd:12,26,99,138,179), BM6 combat work ceiling 16000-18500 (game/tests/test_benchmark.gd:183), replay traces (m2-groups.md:78; tools/compare_local_traces.sh, tools/compare_replays.py). PINNED digest in test_state_hash.gd:6 is a fixed-state check (inferred: likely unaffected unless snapshot fields are added; a new per-unit field changes it).
- **Budgets (dev machine, factor F = 5.5)**: sim-only tick p95 1.82 ms, p99 3.64 ms with 300 moving units; current ~0.71/0.69 p95 (open/dense), so roughly 1.1 ms of headroom; rendered Ashfall frame p95 3.04 ms (guard 3.3); lockstep 0.6 ms (docs/reference/performance.md:14-19). Rule: never loosen a budget; report exceeded (AGENTS.md; performance.md:52). `tools/run_benchmark.sh` runs movement (open, dense), combat (10 layouts incl. docks, hordes300, contact) and lockstep and requires exact PASS counts (tools/run_benchmark.sh:17-33); movement layouts "open" and "dense" (dense = three walls with two gaps each, game/scripts/debug/combat_workload.gd:17-21) are the natural chokepoint test; the "docks" layout (combat_workload.gd:96-103) is the natural dock test.
- **Not found**: any existing stuck/deadlock detection for moving units (only "blocked" when no route exists, simulation.gd:576-581), any per-unit footprint other than the combat radius, any unit-vs-unit push/swap logic. Wargrid's own map data has no unit-passable-width concept besides cells (inferred from grid_navigation.gd).

## Questions
Q1. Which situation must work well first in the first playable avoidance version?
   a) Big blobs of 50+ units crossing open ground   b) Chokepoints (walls with gaps, like the dense layout)   c) Supply docks (trucks at piles and depots)   d) Bases (units leaving factories, walking between buildings)
   Recommendation: b, because chokepoints are where going around turns into jams and deadlocks. Why it matters: it decides which test layout the design spike is built on.

Q2. Second priority after Q1?
   a) Docks   b) Chokepoints   c) Big blobs   d) Bases
   Recommendation: a, because trucks need exact spot equality (supply_collection.gd:142) and are the most likely to break the economy. Why it matters: sets the order of work and of tests.

Q3. May a playable first version leave trucks at docks overlapping (docks exempt from avoidance)?
   a) Yes, exempt docks for now, fix later   b) No, docks must be solved in the first version   c) Exempt only the truck on its final dock spot, others avoid it
   Recommendation: c, because it keeps the exact-position admission rule and still stops trucks driving through each other. Why it matters: this is the biggest hidden coupling to the supply code.

Q4. Should a unit standing still (guarding, idle) be moved out of the way when another unit needs to pass?
   a) Yes, idle units step aside (push)   b) No, movers path around idle units   c) Only friendly idle units step aside, enemies are walls
   Recommendation: c, because it matches how a blocked corridor clears without cost for enemies. Why it matters: decides if movement needs a push mechanism or only replanning.

Q5. When two units meet head-on in a narrow gap, what should happen?
   a) One waits, the other passes (lower id goes first)   b) Both slide past each other if the gap is wide enough, else one waits   c) They swap places
   Recommendation: a, because it is deterministic by id and cannot deadlock. Why it matters: it is the core deadlock rule at chokepoints.

Q6. How should a unit that stays blocked for a long time behave?
   a) Wait up to a few seconds, then repath around   b) Give up its order and stop   c) Ignore other units again (ghost through) until clear
   Recommendation: c, because it guarantees no permanent deadlock while still looking right most of the time. Why it matters: decides if a safety-valve overlap exists, which affects how many traces change.

Q7. Do infantry and vehicles avoid each other equally?
   a) Same rule for every ground unit   b) Vehicles push infantry aside, infantry go around vehicles   c) Infantry squads can overlap each other, but not vehicles
   Recommendation: a, because it is simplest to test and the data has per-kind radii already (combat_definitions.gd:16). Why it matters: scope of the first version and number of rules.

Q8. How big is a unit for avoidance?
   a) Use the existing combat radius per kind   b) One fixed size for all ground units   c) A new separate avoidance radius per kind
   Recommendation: a, because radii already exist and are cached. Why it matters: avoids new data and keeps hordes and avoidance consistent.

Q9. Is it acceptable that units in a horde spread out a bit more, so horde bonuses sometimes trigger less often?
   a) Yes, retune the horde radius to compensate   b) Yes, accept weaker hordes   c) No, avoidance must allow close packing for horde units
   Recommendation: a, because hordes are a ZH-feel feature and a one-time number change is cheap. Why it matters: horde rules come from the unit data (horde.gd:74-90).

Q10. How much re-pinning of old tests and traces is acceptable in one go?
   a) All of them once, at the end of the milestone (as blueprint.md:555 plans)   b) Keep some old fixtures with avoidance switchable off so only new tests are pinned   c) Re-pin step by step per sub-feature
   Recommendation: a, because a switch would leave two movement behaviours to maintain. Why it matters: decides if the simulation keeps an avoidance on/off option (extra code and risk).

Q11. How much extra cost per tick may avoidance take on the 300-unit benchmark?
   a) Up to the existing budget (1.82 ms p95), nothing extra allowed   b) Up to half of the remaining headroom (about 0.5 ms)   c) Budget may be re-proposed after measuring
   Recommendation: b, because it leaves room for later content and still gives a clear pass/fail. Why it matters: sets the gate for the algorithm choice (grid cells vs per-unit neighbour search).

Q12. Should the first version cover units that are travelling only, or also units arriving and spreading at their destination?
   a) Travelling only (arrival spreading stays the existing destination reservation)   b) Both   c) Arrival only
   Recommendation: a, because the destination spreading already exists (destination_allocation.gd) and the complaint was about passing through. Why it matters: halves the design surface.

Q13. Should air units ignore avoidance completely?
   a) Yes, air units never avoid   b) Air units avoid each other but not ground units   c) Air units avoid everything
   Recommendation: a, because aircraft are out of scope until later and their path ignores the grid (locomotion.gd:6-8). Why it matters: keeps aircraft code unchanged.

Q14. Do enemy units block each other's paths (walls), or can they pass through enemies?
   a) Enemies block like friends   b) Enemies block, but crushing units can drive over infantry (later)   c) Only friendly units avoid; enemies ignored
   Recommendation: a, because it is simplest and a close ZH match for solid units. Why it matters: affects bot pathing and combat closing in on targets.

Q15. Should the design spike be tested on Dry Wells or a synthetic layout first?
   a) Dry Wells (real docks and chokepoints)   b) Synthetic layouts from the benchmark (dense, docks)   c) Both, synthetic first
   Recommendation: c, because the synthetic layouts already exist as benchmarks and Dry Wells is what the user plays. Why it matters: decides spike effort and how the playtest is judged.
