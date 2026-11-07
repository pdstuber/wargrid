# M7: three factions with their signature mechanics design

Status: **DESIGN APPROVED** by the user on 2026-11-06 (builder check done). Implementation started after the plan and an explicit kickoff; gates 1-3 are done (gate 2 signed off 2026-11-07) and merged to `main` at the exit gate (2026-11-07), see the [plan](../plans/2026-11-06-m7-factions.md).

**Amended at planning 2026-11-06 (user decisions, see the [plan](../plans/2026-11-06-m7-factions.md)):** survival follows Zero Hour (§2); the performance task is limited to trace-preserving fixes, and the two candidates named in §1 already landed in M6 (§1); four Zero Hour behaviours join the scope (§6, §7); the match windows widen (Stop gates). Each is marked where it applies.

Related docs:
- Scope: blueprint §7 M7 (to be rewritten from this design on approval, together with the roster order and the new milestones below); long-term target §1.
- Source evidence: [M7 faction evidence](../../reference/m7-factions.md). Per-unit stats not listed there are extracted at planning.
- Budgets: [performance ledger](../../reference/performance.md) (F = 5.5 since 2026-11-06).
- Contracts this design changes: [M3 design](2026-11-02-m3-base-supplies-design.md) (one collector kind, builder-only start), [M4 design](2026-11-03-m4-combat-design.md) (unit kinds, survival rule, opponent build order), [M5 design](2026-11-04-m5-online-spike-design.md) (match start online).

## Intent

Wargrid has one faction with five unit kinds. The long-term target is three friends against three bots as USA, China and GLA, and the long-term roster goal (user, 2026-11-06) is every military unit of those three Zero Hour factions. M7 makes three factions that play like their Zero Hour counterparts, each with its signature mechanics, and builds the faction model so the remaining 32 ground units arrive later mostly as data.

Success, judged by the user's playtest at each stop gate: playing China or GLA feels like that faction, not like USA with other numbers. That means GLA tunnels, the three ways to build and to collect supplies, China's horde bonus with larger tank armies, GLA salvage, and the Scorpion.

**Goals:**
- The roster below for all three factions, playable offline against the existing skirmish bot and online between two players, with each player's faction chosen in the launcher.
- Signature mechanics: per-faction construction and gathering, Command Centers, GLA rebuild holes, horde, salvage, gattling ramp-up, transports and the tunnel network, buildings that fire.
- A faction model where systems ask units for capabilities and never ask for a faction.
- The rows over budget today (combat stress `open` / `dense`, the team match) brought under the F = 5.5 budget before faction work adds cost.

**Non-goals:** the other 32 ground units, aircraft, superweapons, generals' variants, upgrades and the tech tree beyond the prerequisites the roster needs, veterancy, stealth and detection, travelling projectiles and minimum range (all later, see Order), smarter bots (M8), fog of war (M7.9), the Generals-style HUD and minimap (own milestone after M7.5), playing on Ashfall (separate task before M7).

**Anti-goals:**
- Faction checks in simulation code: a `if faction == …` branch, or a China copy of the Chinook logic.
- A budget, ceiling, tolerance or pin moved to make a row pass. Pins move only for a recorded, deliberate behaviour change.
- EA names, text or trademarks in code identifiers, data or UI (AGENTS, blueprint §12).
- Faction choice that can differ between two online clients, so the match desyncs at tick 0.
- A generic component or ECS framework.

## User decisions (2026-11-06)

- **Roster** (user's list; Zero Hour names as reference only, see Naming):

  | | USA | China | GLA |
  |---|---|---|---|
  | Builder | Dozer | Dozer | Worker |
  | Collector | Chinook | Supply Truck | Worker |
  | Rifle infantry | Ranger | Red Guard | Rebel |
  | Rocket infantry | Missile Defender | Tank Hunter | RPG Trooper |
  | Light vehicle | Humvee | Battlemaster | Technical |
  | Tank | Crusader | Gattling Tank | Scorpion |
  | Defence | Patriot | Gattling Cannon | Tunnel Network |

- **Signature mechanics:** tunnel network; how each faction builds and collects; China horde bonus with larger tank armies; GLA salvage; Scorpion.
- **Construction difference:** Dozer against Worker, plus GLA rebuild holes. Nothing more.
- **Command Centers** for all three factions: the start building; it trains the builder.
- **Structures** the roster needs: USA power plant, supply center, barracks, war factory, Patriot; China the same with Gattling Cannon; GLA supply stash (also trains Workers), barracks, arms dealer, tunnel network, no power.
- **Faction choice:** the launcher picks both factions offline; online, each player picks their own.
- **Opponent:** the existing skirmish policy (M4), with build order and units per faction from data.
- **Instant hits stay.** Travelling shots arrive with artillery in ground batch A.
- **Performance task first.** The over-budget rows go under budget before any faction work.
- **Stop gates:** one playable gate per faction, each with a user playtest (see Stop gates).
- **Turn, movement and attack parity check** (user, 2026-11-05, blueprint §7): every new unit, and the USA units again, through the parity harness `turn_`, `move_`, `range_` and `reach_` scenarios, comparing whole traces.
- **Order after M7:** ground batch A (units needing only M7 systems plus veterancy, upgrades, poison, transports), M7.5 art, M7.6 Generals-style HUD, M7.9 fog, ground batch B (stealth, detection, hacking), M8 bots, aircraft later. This replaces the proposed "M7.1 roster fill". Ashfall becomes playable in a small task before M7.

## Approaches

User picked A on 2026-11-06.

- **A (chosen): capability data, the way Zero Hour and OpenRA do it.** Definitions carry capability fields; systems query capabilities; a small faction table holds start setup and bot build order. Batches A and B then become mostly data rows. Cost: a rename first, which recalibrates every trace and pin once.
- **B: one script per faction with override hooks.** Quicker for the first special rule, but Chinook and Supply Truck become near-copies and every later unit adds faction branches. Rejected: the batches get more expensive.
- **Generic component / ECS framework.** Ruled out by AGENTS ("no generic frameworks"); A gets the reuse with plain data.

## Design

### 1. Performance task (gate 1, before anything else)

Bring combat stress `open` and `dense` and the team match under 1.82 / 3.64 ms p95 / p99 on the idle development machine, measured with `run_benchmark.sh`, `run_team_match.sh` and the bench runner. Candidates from the [performance spike](../../reference/performance-spike.md): allocation without the full component sort and component lists without `sort_custom` **already landed in M6 (11a, 11b)**, so the plan picks new ones from profiling (amended 2026-11-06). **Fixes must preserve every trace and pin (user, 2026-11-06):** a fix that changes traces (staggered rescans, a path-request budget) is a stop for the user, not a recorded behaviour change. `run_combat.gd` also stops at the first breach (`open`), so `dense`, already over its own ceiling, is never reported; the plan makes it report every layout. Proposal, needs the user's OK at the gate: once under budget, re-pin the stress ceilings lower so `run_benchmark.sh` passes again. Traces must not change.

**Scope and fallback (user, 2026-11-06):**
- **Time box:** the task covers only these three simulation rows. The plan sets its length.
- **What's left after the time box** is recorded as exceeded and goes to the user at gate 1; faction work doesn't wait on it silently.
- **The two presentation rows** (plumbing about 1.9 against 0.91 ms; rendered frame 5.4 / 6.7 against 3.04 ms) wait for M7.5 / M7.6 and the Ashfall terrain batching.
- **Reporting:** gates and the M7 exit gate report every row still over budget as exceeded. None is loosened.

### 2. Faction model

- **Definitions** stay typed GDScript constants (today `economy_definitions.gd`, `combat_definitions.gd`), split into one file per faction plus shared tables (armor, damage types). Each kind has its faction and capability fields. Capabilities come from what the roster needs:
  - `builds` (structures a builder can place);
  - `produces` (units a building trains);
  - `collects {boxes, ticks_per_box, locomotor}`;
  - `contains {slots, shared}`;
  - `horde {count, radius, same_kind, bonus}`;
  - `salvage weapon|money`, plus weapon tiers;
  - `ramp {shots_mean, shots_fast, coast, rates}` on weapons;
  - `rebuild_hole {delay, regen}`;
  - `spawns_on_complete`.
  No field is added before a unit uses it.
- **Faction table:** per faction the id, display name, starting structure and unit, the bot build order and the bot's unit choice per producer. Nothing else.
- **Seat:** a `faction` field per seat, part of the snapshot and the state hash.
- **Survival rule (Zero Hour, user 2026-11-06; replaces the earlier "my call"):** a seat survives while it owns a building, foundation or completed, whose kind has the capability `counts_for_victory`. Units never count, inside containers or not. The flag is set on Command Centers, power plants, supply centers, barracks, factories, the GLA Supply Stash, Arms Dealer and rebuild holes, and not on defences or tunnels. Source: `GameLogic.cpp:1630` sets `VICTORY_NOBUILDINGS`; `Team::hasAnyBuildings` (`Team.cpp:1711-1726`) needs STRUCTURE and `MP_COUNT_FOR_VICTORY` ([evidence](../../reference/m7-factions.md#findings)). Matches run longer than before, because Command Centers have 5000 HP and every counting building must fall.
- **Rules read capabilities:** survival (today hard-coded `builder`, `depot`, `barracks`, `factory` in `simulation.gd:101-106`; reads `counts_for_victory`), production, construction, collection, targeting categories in the skirmish policy, HUD build keys. One guard test fails if a faction id appears in simulation code outside the definition files.
- **Rename first:** today's generic kinds become the new per-faction ids in one task, before any new rule. All replay traces, digests and match pins change for that reason alone. The task records old against new values and proves no behaviour changed: same event sequence, only names differ.

### 3. Naming (constraint, proposal for the user)

AGENTS forbids EA text and trademarks in Wargrid, and blueprint §12 restricts EA trademarks. The precedent is Ashfall instead of Twilight Flame. So code ids, data and UI use Wargrid's own names. The evidence note keeps the mapping to Zero Hour objects.

**Decided (user, 2026-11-06):**
- **Ids** have the form `<faction>_<role>` from the roster table rows, e.g. `usa_rifle_infantry`, `china_tank`, `frc_builder`. Ids are fixed at the rename; changing them later recalibrates every pin again.
- **Faction ids** are `usa`, `china` and `frc`. GLA's counterpart is the **FRC — Free Resistance Coalition**.
- **Unit display names** are generic and derived at planning, e.g. "Rifleman", "Rocket Trooper", "Light Tank", "Supply Truck". The user may change them later. They are UI text, so a change costs no pin.
- **Real-world product names** (Humvee, Patriot, Chinook) are trademarks too; the same rule applies.

### 4. Start setup, Command Center, construction

- Each seat starts with its faction's Command Center and one builder. The Command Center trains the builder; the GLA Supply Stash also trains Workers.
- **USA and China Dozers** keep today's construction rules.
- **GLA Worker** is infantry: it builds with the same construction rules and also collects (see 5).
- **GLA rebuild holes:** a destroyed GLA building leaves a hole that regenerates and, after the delay, spawns a Worker that rebuilds the building, unless the hole is destroyed first.
- **GLA has no power;** its structures neither need nor supply it.
- Values come from the evidence note; values still missing are extracted at planning.

### 5. Gathering

One collection system with per-kind `collects` data:
- **Chinook:** today's flying collector.
- **Supply Truck:** drives, 4 boxes, one box per second.
- **Worker:** walks, 1 box, one box per 150 ms.

Cargo and destroyed-destination rules stay as M3 defines them. Locomotion decides air or ground path.

- **Ground docking (my call, 2026-11-06).** M3's dock is air-only: collectors hover at the centre of a blocked footprint and stack there. Ground collectors can't do that. Truck and Worker dock the way Zero Hour does: approach and queue positions next to the pile and the depot, one collector active per dock, the rest waiting in line. Positions and timing come from `SupplyWarehouseDockUpdate.cpp` / `SupplyCenterDockUpdate.cpp` at planning. The Chinook keeps M3's rule. The plan measures the extra navigation work in a benchmark.

### 6. Combat additions

- **Firing buildings:** Patriot, Gattling Cannon and the Tunnel Network fire with today's weapon rules (instant hits, edge-to-edge range).
- **Horde:** Red Guard, Tank Hunter and Battlemaster get their bonus while enough of the same kind stand close. The check runs on Zero Hour's cadence, not every tick, inside the combat budget.
- **Added at planning (user, 2026-11-06):** passengers fire from a Humvee (not from a Technical); the Patriot and Gattling Cannon hold fire while the seat's power demand exceeds its supply; a Red Guard order trains two units; when a transport dies its passengers take its passenger-damage share first (Humvee 100 %, Technical 10 %) and the survivors exit.
- **Gattling ramp-up:** consecutive shots on the same target raise the fire rate in two steps; the speed-up is lost after the coast time without firing.
- **Salvage:** a vehicle killed by a GLA salvager drops a crate that only GLA sees. A weapon salvager picks it up for its next weapon tier (two tiers); others get money. **Departure:** Wargrid has no veterancy, so Zero Hour's 25 % level-up branch is money instead, until veterancy arrives in batch A.
- **Rockets:** the three rocket infantry use instant hits (decided), with their own damage types and armor rows.

### 7. Containers and the tunnel network

- **One container system:** Humvee and Technical hold 5 each.
- **Tunnel network:** all tunnels of one player share one container of 10. A unit enters one tunnel and exits from any other; occupants heal to full within 5 s.
- **On completion,** the tunnel spawns 2 rocket infantry once.
- **When the last tunnel dies,** whoever is inside is removed without death events (source: `TunnelTracker.cpp:211-247` deletes them with `destroyObject`; confirmed at planning, [evidence](../../reference/m7-factions.md#findings)). With another tunnel left, occupants stay safe.
- **Same-tick interaction cases** with every existing command and with removal go into the plan (AGENTS).

### 8. Faction choice and match start

- **Offline:** the launcher picks the player's and the opponent's faction and passes them into the skirmish setup.
- **Online:** each player picks their own faction, and both clients must hold the same factions before tick 0. **Proposal, the builder may change it with reasons:** send the choice as an in-band lockstep command before the match starts. Then the relay, `protocol/vectors` and the conformance suite stay unchanged, and replays record the factions.
- **Build menu:** a plain button grid generated from the selected builder's `builds` or the producer's `produces`, with the queue visible. Each HUD change gets a headless layout test.

### 9. Opponent

The M4 skirmish policy reads the build order and per-producer unit from the faction table, and its target categories from capabilities. No new strategy.

**My call (2026-11-06), three small rule changes to the approved M4 policy.** Without them the exit-gate 3v3 wouldn't exercise M7's mechanics:
- each producer cycles through a short unit list from the faction table instead of one fixed unit, so rocket infantry, hordes and transports appear;
- the bot trains a builder from its Command Center when it has none;
- the GLA bot keeps one Worker as its builder and trains the others from the Supply Stash as collectors, so building doesn't strip its income.

Nothing else changes. Strategy stays M8's job.

## Stop gates

Each gate is playable offline and online, followed by a user playtest. Each runs the full checks: suite, lint, warnings, replay traces, netplay scenarios, `run_benchmark.sh`, a new ledger row, the rendered benchmark if presentation changed, and the parity harness for the gate's units.

1. **USA complete:** the performance task, the faction model and rename, Command Centers, faction choice offline and online, the build menu, USA additions (rocket infantry, armed Humvee with transport, Patriot).
2. **China:** power plant, supply center, Supply Truck, Red Guard, Tank Hunter, horde, Battlemaster, Gattling Tank and Gattling Cannon with ramp-up.
3. **GLA:** Worker building and collecting, no power, rebuild holes, Rebel, RPG Trooper, Technical with transport, Scorpion, salvage, tunnel network. This is also the M7 exit gate.

**Exit gate (M7):** all three gates passed. A headless 3v3 bots-only team match on Ashfall with all three factions runs deterministically to a result. Its ledger rows are inside the simulation budgets, and anything still over is reported as exceeded under the fallback in §1. Parity results are recorded as a decision list.

**Match windows (user, 2026-11-06).** Command Centers and the Zero Hour survival rule lengthen matches. From the Command Center task on, the scripted 1v1 test accepts a terminal tick in 8000-17999 (`TICK_LIMIT` 18000, winner still team 1) and the team match cap is 45000 with result `won`. A result beyond those is a stop.

**Plan detail (user, 2026-11-06).** The [plan](../plans/2026-11-06-m7-factions.md) is written at step level for gate 1 only. Gates 2 and 3 are outlines that an Opus (high) planning session expands after the preceding gate's playtest, while execution runs on Sonnet (medium).

## Constraints

- **Determinism:** the simulation alone owns faction state, horde, ramp-up, salvage and containers; ticks are explicit and randomness is injected. Replay traces match across Linux, Windows and macOS.
- **Performance:** F = 5.5 budgets. New per-tick work (horde, ramp, containers, crates) shows up in a benchmark that asserts the mechanic runs inside the timed window.
- **Verification rules:** AGENTS rules apply: a behaviour test per mechanic, same-tick interaction cases for every new command, HUD layout tests, report the tree each check ran on.
- **Reference rules:** values from config are labelled config-based until measured; departures stay explicit; no EA assets, names or text.

## Left to the builder

- Plan order inside each gate; which performance fixes to apply.
- Per-unit stats (cost, HP, armor, weapons, speeds, footprints, vision) from `INIZH.big`, scaled to Wargrid units like M6.
- The exact capability field shapes; the in-band faction command (or a better way that keeps the protocol fixed).
- Footprints and placement for the new structures.
- Which existing pins change at the rename and at each gate, with reasons.
