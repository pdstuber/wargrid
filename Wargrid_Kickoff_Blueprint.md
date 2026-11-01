# Wargrid — Project Kickoff Blueprint

**Version:** 0.4

**Date:** 2026-11-01  
**Status:** Revised kickoff specification; implementation has not started

**Working title:** Wargrid

> **North star:** Preserve the strong *game design and feel* of **Command & Conquer: Generals — Zero Hour**, while fixing defects and avoiding its performance limitations, using **Godot** and an original **isometric pixel-art / 2.5D** presentation. Treat the original game as the behavioral reference, not as a codebase to port wholesale.
>
> **Non-negotiable engineering principle:** **Build the behavior-test suite alongside the game, starting on day one.** No mechanic is considered complete merely because it looks right in a screenshot or works in one manual playthrough.

---

## 1. Vision and intent

Wargrid is a passion/learning project: a modern, scriptable, testable, pixel-art recreation of the RTS mechanics that make *Generals: Zero Hour* enjoyable.

**Target: Zero Hour-inspired game design, with reliable behavior and responsive performance.** Preserve faction identity, strategic tradeoffs, economy and combat pacing. Original bugs, exploits, stuck units, command failures and slowdowns are not compatibility requirements. Reference measurements inform design; they do not override an explicitly chosen correction. Start with a constrained playable subset.

### What to preserve

- **Faction identity and asymmetric mechanics:** USA, China, GLA; later the nine Zero Hour general variants.
- **Economy and base-building:** builders/workers, supply collection, construction, power, tech prerequisites, queues, upgrades, repair and destruction.
- **Combat:** infantry, vehicles, aircraft, weapons, targeting, armor, range, veterancy, garrisons, crushing and support powers.
- **Player experience:** responsive selection, move/attack-move/guard behavior, tactical readability, recognizable pacing, useful minimap, fog of war, hotkeys.
- **Strategic structure:** escalation from early economy to late-game units, technologies and superweapons.

### What to change

- **Rendering:** 3D visuals become **2D isometric pixel-art sprites**, environments and effects.
- **Engine and code:** original Godot implementation, data-driven where useful, with testable game simulation separated from visual scenes.
- **Developer workflow:** reproducible, headless tests and command-line automation so Codex / Claude Code can work largely without editor clicking.

### What is *not* the initial goal

- An exact frame-for-frame visual remake.
- All campaigns, maps, online matchmaking or all nine general variants.
- A production-grade networking backend on day one.
- Overengineering a fully generic ECS/framework before a playable slice exists.
- A polished asset pipeline before gameplay correctness can be measured.

### Important boundary

Using Zero Hour as a game-design reference does **not** mean rights to distribute EA branding, music, voice lines, maps, artwork, names or distinctive content are automatically granted. Public distribution must be evaluated separately (see §12).

---

## 2. Visual direction: isometric pixel art

**Chosen:** Isometric / 2.5D pixel art, not a straight overhead camera. Think detailed desert bases, chunky vehicles, readable silhouettes, blue/red faction colors, clear health bars, explosions and smoke, a classic RTS HUD, and a densely populated battlefield.

### Visual target

- **View:** Fixed-angle pseudo-isometric projection. Players perceive terrain depth and building height while controls remain a conventional RTS.
- **World:** Desert maps initially: sandy ground, roads, cliffs, a bridge/river if useful for the first test scenario, occasional vegetation.
- **Units:** Infantry, tanks, construction units and aircraft rendered as directional sprites (start with a small number of directions; increase as needed).
- **Buildings:** Footprints and clear entrances, larger pixel-art silhouettes, construction phases and damage states later.
- **HUD:** Minimap bottom-left, selected-unit details and orders, build/production options, resources, power and population/capacity indicators where applicable.
- **Readability over detail:** Selection rings, color identity, health bars, range feedback, targeting feedback, no vital unit information hidden by scenery.

### Crucial implementation decision

**Simulation coordinates must not be isometric pixel coordinates.**

Maintain a normal 2D top-down **world plane** for unit positions, distances, collisions, pathfinding, grids and combat. Only project world positions into isometric screen coordinates during rendering. The mouse-to-world conversion must be the inverse of that projection (plus camera transform).

This prevents the chosen art style from complicating basic RTS rules, and lets tests run without rendering.

### Pixel-art rendering guidelines

- Pick a consistent reference tile scale and art resolution deliberately; avoid arbitrary per-asset scaling.
- Enforce consistent direction conventions, feet/ground anchors, shadows and occlusion ordering.
- Sort sprites by their world-ground anchor rather than by the tallest visible pixel.
- Keep the camera zoom intentional; test readability with 50+ units on screen.
- Use placeholders until behavior tests pass, then iterate on sprites and effects.

---

## 3. Engine, language, tools

### Initial technology choice

| Concern | Choice | Rationale |
|---|---|---|
| Engine | **Godot 4.x (stable release, pin exact version when initialized)** | Mature 2D rendering, scene editor, TileMapLayer workflow, UI, headless CLI. |
| Primary language | **GDScript** | Fast iteration, close integration, simple headless scripting. |
| Game simulation | **Engine-light GDScript classes/resources** | Keep core rules testable independently of map sprites/scene tree where practical. |
| Visual presentation | **Godot 2D nodes, tile layers, UI Controls and shaders** | Supports isometric sprites without requiring a 3D engine. |
| Automated tests | **Minimal SceneTree runner for M0**; evaluate pinned GdUnit4 later | One headless test path now; no framework compatibility blocker or parallel runners. |
| Assets | **Original/placeholder assets initially** | Avoid production bottlenecks and inherited content licensing. |
| AI workflow | **Codex CLI / Claude Code, Git, shell, CI** | Code-first iteration with observable test results. |
| Platform target | **macOS first; Linux/Windows later** | Convenient development; Steam Deck possible after portability checks. |

Godot remains the preferred engine for this independent implementation. A fork of the old C++ engine might preserve old behavior more directly, but is a poor match for an independent 2D art pipeline and modern headless test architecture.

### Reuse baseline: Hell's Verdict

Use `/Users/pdstuber/projects/hells-verdict` as the local tooling reference (inspected HEAD `3fffcb8`, with existing working-tree changes). Read the relevant files before adapting them; do not modify that project or copy its gameplay code. Its current CI configuration is evidence of a setup, not proof that the remote job or download still works.

| Reference file | Adapt for Wargrid |
|---|---|
| `game/project.godot` and project layout | Keep Godot project under `game/`, with scenes, scripts, data and tests; repository tools/docs stay outside it. |
| `tools/run_tests.sh`, `tools/run_game.sh` | Resolve paths from script location, quote paths, forward launch arguments, check test exit status and completion marker. Add `GODOT_BIN` support and headless import. |
| `.github/workflows/tests.yml` | Pin engine version and verify download checksum; run same wrapper on pushes and pull requests, with a job timeout. Verify artifact/checksum independently before reuse. |
| `AGENTS.md` | Terminal-first commands, explicit decision status, rules separate from scenes, headless checks, no surprise game windows, explicit Git approval. Keep Wargrid's existing personal instructions. |
| `game/tests/run_tests.gd` | Adapt assertion diagnostics and completion checks only. Keep suites small and grouped by system; do not copy the monolithic game-specific suite. |
| `game/scripts/debug/frame_stats.gd` | At M2, adapt percentile-reporting idea for separate tick/frame measurements, including p50/p95/p99. No display-tuning subsystem in M0. |

Wargrid keeps **Compatibility rendering and 30 Hz simulation**. Do not inherit Hell's Verdict's Mobile renderer, Jolt, 60 Hz physics, 144 FPS cap, disabled VSync, shooter inputs, server-authority assumptions or 3D interpolation settings. Choose pixel-art display settings during M1. These small scripts do not warrant a shared cross-project library.

### Architecture: strong boundaries, not premature abstractions

```text
Player input / AI player / replay commands
                  │
                  ▼
           Command queue
                  │
                  ▼
       Fixed-step game simulation
         ├─ Entity state and IDs
         ├─ Economy / production
         ├─ Movement / pathfinding
         ├─ Targeting / combat
         ├─ Construction / tech
         ├─ Fog / visibility
         └─ Rule events and state changes
                  │
        snapshots / emitted events
                  │
                  ▼
      Godot 2D visualization + HUD

Headless test runner ───► same simulation API
Replay runner ──────────► same command queue
```

### Simulation constraints

1. **Fixed simulation timestep: start at 30 Hz.** The checked-out Zero Hour source defines `LOGICFRAMES_PER_SECOND = 30` (§4). Matching this time grid simplifies comparisons; it does not require copying engine scheduling or bugs. Store deadlines as integer ticks; document rounding for each mechanic.
2. **Stable entity IDs**, explicit ownership/team, and serializable commands (e.g. `move`, `attack`, `build`, `train`, `cancel`).
3. **Seeded randomness** and state capture of RNG seed/state where relevant.
4. **Deterministic command processing within the same environment** as an immediate requirement. Cross-platform deterministic lockstep is **not** assumed automatically; floats, physics, ordering and runtime differences require explicit verification or different numerical representations later.
5. **Authoritative simulation state.** Sprites and scene effects should represent state, not own the rules.
6. **Save/replay-friendly state model.** A test should be able to set up a world, issue commands over ticks, then inspect a canonical state snapshot.
7. **No dependence on render frame rate for rule outcomes.** Rendering can interpolate between ticks.
8. **Avoid using Godot's per-unit navigation agent as an unquestioned large-army solution.** Profile small examples, then evaluate group pathfinding, destination assignment and spatial indexing.
9. **Be pragmatic:** do not create a general-purpose engine abstraction for systems that have not yet been exercised by a real slice.

---

## 4. Original Generals / Zero Hour source as a reference

### Official sources

- **Original game source:** https://github.com/electronicarts/CnC_Generals_Zero_Hour
- **EA license terms:** https://github.com/electronicarts/CnC_Generals_Zero_Hour/blob/main/LICENSE.md
- **Additional modding resources:** https://github.com/electronicarts/CnC_Modding_Support
- **EA modding guidance:** https://www.ea.com/games/command-and-conquer/news/modding-faq

The official source repository includes **Generals** and **GeneralsMD** (Zero Hour) directories. It was archived by EA and released under **GPLv3 plus EA's additional terms**. The original project has legacy build dependencies; **do not assume a simple cross-platform build**.

### Reference checkout policy

Keep EA's checkout **outside** the Wargrid game repository, e.g.:

```text
~/projects/
  wargrid/               # Original Godot project
  CnC_Generals_Zero_Hour/ # EA code; separate checkout
```

Record the **source revision/commit hash** used for each research finding. Do not vendor the EA source, assets, or substantial code snippets into Wargrid.

### Verified local reference baseline (2026-11-01)

- Wargrid: `/Users/pdstuber/projects/wargrid`; README, agent instructions, blueprint and reference notes, no game implementation.
- EA checkout: `/Users/pdstuber/projects/CnC_Generals_Zero_Hour`.
- Inspected revision: `0a05454d8574207440a5fb15241b98ad0b435590`. Use this revision in source links and research notes.
- Research **`GeneralsMD/`** for Zero Hour. `Generals/` is the base game; do not mix their behavior without saying so.
- Installed engine reports `4.7.2.stable.official.ed1daf0bf` via `godot --version`. This is an observed local version, not a claim about the latest upstream release. M0 must verify an official matching CI download before adopting this pin.
- The source checkout omits gameplay INIs. User-supplied installation backups under `/Users/pdstuber/CnC` contain readable `INI.big` (Generals) and `INIZH.big` (Zero Hour), including gameplay definitions. See [local data inventory and hashes](docs/reference/installation.md). Use the root Zero Hour archive, not its obsolete nested duplicate; resolve overrides before claiming effective stats.
- Current data baseline: hash-pinned Steam Deck installation backups, inspected 2026-11-01. Exact executable/patch version, mod status and runtime behavior remain **unverified**; do not assume 1.04. Before a measured comparison, record executable/version, mods, effective configuration and scenario. Configuration research is unblocked; measured fidelity still requires runtime observations.

Source entry points below are relative to `GeneralsMD/Code/GameEngine/`. They locate research, not instructions to port the implementation.

| Question | Source entry point |
|---|---|
| Tick duration and conversions | `Include/Common/GameCommon.h`: `LOGICFRAMES_PER_SECOND`, `ConvertDurationFromMsecsToFrames` |
| Simulation update order | `Source/GameLogic/System/GameLogic.cpp` |
| Paths, groups, locomotion | `Source/GameLogic/AI/AIPathfind.cpp`, `Source/GameLogic/AI/AIGroup.cpp`, `Source/GameLogic/Object/Locomotor.cpp` |
| USA collector flight and supply behavior | `Source/GameLogic/Object/Update/AIUpdate/ChinookAIUpdate.cpp` |
| Supply docking | `Source/GameLogic/Object/Update/DockUpdate/SupplyCenterDockUpdate.cpp`, `SupplyWarehouseDockUpdate.cpp` in the same directory |
| Construction and production | `Source/Common/System/BuildAssistant.cpp`, `Source/GameLogic/Object/Update/ProductionUpdate.cpp` |
| Weapon behavior and config parsing | `Source/GameLogic/Object/Weapon.cpp`, `Source/Common/INI/INIWeapon.cpp` |

The pinned [GameCommon.h](https://github.com/electronicarts/CnC_Generals_Zero_Hour/blob/0a05454d8574207440a5fb15241b98ad0b435590/GeneralsMD/Code/GameEngine/Include/Common/GameCommon.h#L72) says `LOGICFRAMES_PER_SECOND = 30`. This establishes a source constant, not a measured guarantee of wall-clock performance. The pinned [README](https://github.com/electronicarts/CnC_Generals_Zero_Hour/blob/0a05454d8574207440a5fb15241b98ad0b435590/README.md) labels compilation “Win32 Only” and lists missing legacy dependencies. Building EA's engine is outside M0.

### How AI agents should use the reference

Treat it as a **behavioral and architectural investigation source**, not a porting template:

1. Ask a **research agent** a narrow question about one mechanic.
2. Find relevant modules, configuration data and code paths in EA's repository.
3. Where possible, **observe the game running** to validate how those paths present to the player; source code alone is not always enough (configuration, mode, bugs, versions and timing matter).
4. Produce a **behavior specification** with evidence, uncertainty, edge cases and proposed tests.
5. Ask an **implementation agent** to build a new Godot implementation from that behavior spec and test cases—not to translate proprietary or GPL code line-by-line.
6. Run parity and regression tests, comparing the implementation against the measured reference.

**Research priorities:** group movement and pathfinding; supply gathering; building construction; weapon/armor/targeting interactions; veterancy; unit AI; build dependencies; power; production queues; fog of war; eventually netcode/replay design.

**Important legal/engineering clarification:** a separate research write-up is helpful for provenance and architectural independence, but is **not** a legal guarantee of independent implementation. Reviewing GPL code and later writing conceptually similar code does not automatically trigger the GPL, but copying or closely adapting its protected expression can create obligations. Get legal advice before distribution.

### Research note format

For each mechanic, write `docs/reference/<mechanic>.md` with:

```markdown
# Mechanic: <name>
- Question:
- EA repository revision:
- Source file paths and relevant symbols:
- Game version / observed scenario:
- Observed behavior:
- Config-derived facts:
- Source-derived interpretation:
- Uncertainties / contradictions:
- Edge cases:
- Proposed parity tests:
- Known/suspected original defects and reproduction evidence:
- Intended Wargrid behavior and regression test for each correction:
- Design choices intentionally different from reference:
- Evidence confidence: observed / source-supported / inferred / unknown
```

Prefer **behavior descriptions**, measurements and hyperlinks over copying source fragments.

---

## 5. Behavior-first testing strategy

> **Testing is part of game design.** The behavior-test suite is the executable specification of Wargrid. Build it **before or alongside every gameplay system**, and make it runnable headlessly from the CLI. This checks intended rules, chosen fidelity targets and deliberate fixes beyond visual resemblance.

### 5.1 Definition of done for **every mechanic**

A mechanic is **not done** until all of these are true:

- [ ] **Behavior documented:** intended Wargrid rule, applicable conditions, source evidence or explicit design choice; identify deliberate fixes.
- [ ] **Unknowns recorded:** missing values are explicitly `unknown`, not silently invented.
- [ ] **Executable automated tests:** at least one normal case and one meaningful edge case, at the correct test level.
- [ ] **Headless operation:** tests do not require a display, a human clicking around, or a GPU-dependent game scene unless explicitly classified as a separate visual test.
- [ ] **Reproducible:** fixed starting state, units, commands, tick count and RNG seed when used.
- [ ] **Observable:** useful failure diagnostics (expected vs actual state, event trace, tick, entity ID).
- [ ] **Validated:** tests pass locally and in CI; any parity differences are documented.
- [ ] **Playable:** short manual verification that the rule feels right in an actual RTS interaction.

A test passing against **self-invented expectations** is not proof of original-game parity. Track **internal correctness** and **reference fidelity** separately.

### 5.2 The test pyramid

| Level | What it checks | Example | Frequency |
|---|---|---|---|
| **Unit tests** | Small pure rules/math | Damage reduction, tech prerequisites, build-queue transitions | Every change |
| **Simulation scenario tests** | Multiple interacting systems over ticks | Gather supplies → deposit → funds increase | Every change |
| **Reference parity / characterization tests** | Measured Gen/Zero Hour behavior | Travel time, time-to-kill, production timing under matched conditions | Every relevant change |
| **Determinism / replay tests** | Same command log gives same canonical state | Run identical battle 10× and compare snapshot hashes | Every change |
| **Property / invariant tests** | Rules that must always hold | Resources never go negative except explicitly allowed mechanics | Every change |
| **Performance regression tests** | Simulation budgets, scaling | 100 / 300 / 500 units, pathfinding spikes | Nightly and before milestone |
| **Visual interaction tests** | Projection, selection, HUD, occlusion | Click and box select match the intended world positions | Milestone / targeted |

**Do not make screenshot comparison the primary gameplay oracle.** It cannot reliably verify resource accounting, attack intervals, command scheduling or state transitions.

### 5.3 Two independent acceptance tracks

1. **Wargrid correctness:** does our implementation obey documented rules and invariants consistently?
2. **Design fidelity:** does it retain the chosen Zero Hour rules and pacing under equivalent conditions, with deliberate fixes documented?

A test may be **green internally** but **unverified for parity** because reference measurements have not yet been collected. Reports must make that distinction visible.

Suggested statuses:

- `PASS` — measured expected state matched.
- `FAIL` — measured expected state did not match.
- `BLOCKED` — test cannot run because of missing feature/environment.
- `UNVERIFIED_REFERENCE` — Wargrid behavior tested, but not yet characterized against Zero Hour.
- `INTENTIONAL_DEVIATION` — documented difference from original, including deliberate defect fixes. Its Wargrid regression test must still pass; this label cannot excuse broken behavior.

Never convert “unknown” into “pass.” Keep `correctness: PASS/FAIL` separate from reference status; a corrected bug can be `PASS` and `INTENTIONAL_DEVIATION` together.

#### Original behavior is evidence, not a requirement to preserve defects

For each suspected original bug, record reproduction/evidence, player impact, intended Wargrid behavior and a regression test. Do not call an unexplained mismatch a bug fix. Preserve source observations in the research note, but assert the corrected outcome in Wargrid tests. Routine correctness fixes are in scope; changes to faction strengths, costs, counters or strategic tradeoffs need an explicit design decision. Unknown original behavior stays unknown.

For example, an unreachable order must terminate or enter a bounded blocked state, never freeze a tick or repath forever. A collector whose deposit building is destroyed must recover or become explicitly idle without duplicating cargo. These are Wargrid requirements, **not claims of verified Zero Hour bugs**.

### 5.4 Evidence ladder: never invent an oracle

Use this priority when determining expected behavior:

1. **Controlled in-game measurements** with version, settings, map, player/faction, replay/video/timestamp when available.
2. **Official data/configuration and source-code behavior**, linked to EA repository revision.
3. **Repeated community observations/documentation**, identified as secondary evidence.
4. **Inference**, explicitly marked as provisional.
5. **Wargrid design choice** when no reference behavior is recoverable, explicitly marked as a divergence or assumption.

Especially for damage, armor, weapon cadence, travel speed and supply rates, do **not** create arbitrary numbers and label them “Generals-accurate.”

### 5.5 Scenario fixtures: commands in, states out

Store small, versioned, human-readable fixtures under `game/tests/fixtures/`.

Each scenario should record:

- `fixture_version`, stable `scenario_id`, description.
- Original game/version and provenance/evidence links, if available.
- Map size, terrain/collision, starting entities with IDs, teams, positions, health, relevant config, supply amount, starting currency.
- RNG seed, tick rate, simulation rules version.
- Ordered commands with **issue ticks** and arguments.
- Assertions at named ticks or eventual/bounded conditions.
- Tolerances if justified (and why); no arbitrary blanket epsilon.
- Expected events / canonical snapshot hash where appropriate.

**Illustrative fixture shape (NOT a measured Generals parity fixture):**

```json
{
  "fixture_version": 1,
  "scenario_id": "move_to_open_tile_v1",
  "classification": "WARGRID_INTERNAL",
  "reference_evidence": null,
  "seed": 1234,
  "tick_rate": 30,
  "world": { "width_tiles": 20, "height_tiles": 20 },
  "entities": [
    { "id": 1, "kind": "test_vehicle", "team": 1, "tile": [2, 2] }
  ],
  "commands": [
    { "tick": 0, "player": 1, "type": "move", "entity_ids": [1], "target_tile": [10, 10] }
  ],
  "assertions": [
    { "type": "eventually_within_tiles", "entity_id": 1,
      "target_tile": [10, 10], "tolerance": 1, "by_tick": 200 }
  ]
}
```

The values above are **test scaffolding examples**, not claims about original game values, scale or timing. The fixture parser/assertion names are a **proposed schema** to implement, not an existing tool/API.

For a **reference parity fixture**, do not enable a passing expected result until evidence exists; enter the discovered value together with provenance and a defensible tolerance.

### 5.6 Canonical state snapshots and replays

As systems appear, grow the test API toward:

```text
new_game(config, seed)
spawn(entity_definition, team, position)
issue_command(tick, player, command)
step_ticks(n)
get_state_snapshot()
get_events_since(tick)
get_canonical_state_hash()
```

These are **conceptual interface names**, not Godot-provided APIs or mandatory M0 scaffolding. §7.1 specifies the smaller initial contract.

Canonical snapshots should use consistent key ordering, stable IDs, explicit numeric representation, and exclude transient render-only state. Do not round authoritative floats solely to hide replay differences; tolerant behavioral comparisons are separate from exact same-environment replay checks. Include meaningful simulation state as each system appears: current tick, next entity ID, pending commands and sequence counter, position, health, orders, economy, build queues, cooldowns, visibility where relevant, and RNG state. Log commands with sequence numbers to settle same-tick ordering.

**Replay test:** initialize game twice with the same seed and command log, run for N ticks, and compare canonical snapshots/event streams. Add stress and multi-platform determinism checks later; initially same-process reproducibility is sufficient.

### 5.7 Essential first test inventory

**Build these tests as systems appear; keep them small and deterministic.**

#### M0 infrastructure

- [x] `test_repeatability` (C11): 1,000 direct simulation steps twice with nonempty orders → identical canonical state and expected final orders.
- [x] `test_same_tick_replacement` / `test_canonical_pending_order` (C4/C10): commands at same tick have a defined stable execution order.
- [x] `test_atomic_rejection` (C5): commands from non-owners or invalid entity IDs do not change entity gameplay state.

#### Movement and pathfinding (M1 onward)

- [ ] `test_world_to_screen_roundtrip`: world → isometric screen → world preserves ground position within chosen precision, including camera pan/zoom in input mapping.
- [ ] `test_move_open_ground`: vehicle reaches valid destination.
- [ ] `test_path_around_building`: blocked obstacle avoided without collision.
- [ ] `test_unreachable_destination`: unit does not stall the simulation; emits appropriate blocked/idle behavior.
- [ ] `test_group_destination_assignment`: 10 vehicles spread instead of stacking on one point.
- [ ] `test_dynamic_blockage_repath`: new obstruction triggers a reasonable response.
- [ ] `test_movement_parity`: matched reference observation of a vehicle route/speed, once measured.

#### Economy and construction

- [ ] `test_build_requires_funds`: insufficient funds rejects production/construction.
- [ ] `test_supply_round_trip`: collection, carrying, deposit and depletion account correctly.
- [ ] `test_queue_order_and_cancel`: build queue and refund behavior are correct.
- [ ] `test_power_offline`: loss of power applies intended building/production effects.
- [ ] `test_build_timing_parity`: measured production/construction durations match reference.

#### Combat

- [ ] `test_weapon_range_boundary`: just inside/outside effective range.
- [ ] `test_target_priority`: valid and invalid targets; guard/attack-move behavior.
- [ ] `test_damage_armor_matrix`: data-driven interactions and damage source.
- [ ] `test_weapon_cooldown`: fire timing independent of render FPS.
- [ ] `test_destroyed_unit_no_actions`: dead units cannot keep firing or harvesting.
- [ ] `test_ttk_parity`: reference-measured time-to-kill for representative pairings.

#### Large scenario / system correctness

- [ ] `test_mirror_match_script`: scripted early-game base + economy + combat produces expected events.
- [ ] `test_resource_conservation`: no resource creation by canceled orders/worker transitions unless intended.
- [ ] `test_replay_hash`: same commands and seed → same result.
- [ ] `test_mass_unit_benchmark`: record tick times at 100, 300 and 500 moving units; track p50/p95/p99, not only mean.

### 5.8 Testing tooling and CLI

Use **one minimal `SceneTree` test runner for M0**, delegating to small explicit suites. It must report counts, fail on zero tests, exit nonzero on failed expectations, and emit `TESTS PASSED <n>` only after every selected suite completes with a positive check count. The wrapper requires both successful exit and that final marker; missing/incomplete suites or script errors cannot pass merely because the process exits zero. Let CI terminate hangs. Do not build discovery plugins, a fixture assertion language or a second runner. Evaluate GdUnit4 when suite size or scene testing justifies migration; first prove its pinned version supports the required engine/headless mode.

Commands below become runnable **after M0 creates the referenced project and scripts**:

```bash
godot --version
sh tools/run_tests.sh
```

`tools/run_tests.sh` will own `godot --headless --path "$repo_root/game" --import` followed by `godot --headless --path "$repo_root/game" --script res://tests/run_tests.gd`. Both wrappers resolve the repository root from their own location and accept `GODOT_BIN` as one executable path, defaulting to `godot`; quote it rather than evaluating shell text. Run POSIX shell wrappers with `sh` from fish, zsh or CI. Do not depend on GNU `timeout` on macOS; configure a CI job timeout. Simulation tests advance `step()` directly; do not copy the FPS game's `--fixed-fps 60` into this wrapper.

For an explicitly requested play session, `sh tools/run_game.sh` launches with `--path "$repo_root/game"` and forwards arguments. Tests, replays and simulation benchmarks stay headless. Ask before checks needing a visible window, including screenshots and rendered-frame benchmarks; batch them into one request. A headless launch does not verify visual quality or game feel.

Primary documentation: [Godot CLI](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) says `--import` “waits for any resources to be imported, and then quits”; script entry points must inherit `SceneTree` or `MainLoop`. [GdUnit4 CLI](https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/cmd/) documents `GODOT_BIN` and its shell runner; a shell runner alone is not proof that a given release supports display-free execution.

#### CI contract

Each pull request / agent change must:

1. Import project headlessly and report parse/import errors.
2. Run all fast unit and simulation tests; fail CI on any failure.
3. Run reference parity fixtures that are implemented and measured; clearly report unverified ones.
4. Check replay consistency.
5. Store test results, failing fixture IDs and useful command/event traces as artifacts.
6. Track performance regression measurements separately rather than making flaky elapsed-time thresholds mandatory from the first week.

Configure push, pull-request and manual triggers. Pin one engine version in README and CI, verify its archive checksum before installing, and set a job timeout. Keep this one Godot job; do not import other projects' engine comparisons or release/signing setup.

**AI acceptance rule:** A coding agent must not say “implemented” without reporting test command, test counts/results and any missing parity evidence. A rendered screenshot is supplemental evidence only.

#### Tolerance policy

- Prefer **exact integers, counts, event ordering and state transitions** where applicable.
- For positions/time measurements, justify tolerances based on tick boundaries, map calibration or observation precision.
- Never widen thresholds just to make a failing test green without explaining the mismatch.
- Mark changes to fixtures and their expected outputs explicitly in review.

#### Bug reports that reproduce themselves

For each simulation bug, capture:

```text
scenario ID + seed + tick rate + source revision (if parity)
initial state + command log + failure tick
expected and actual event/state diff
```

Add a regression fixture **before** implementing the fix wherever possible.

---

## 6. Core systems and recommended implementation order

1. **Simulation kernel:** tick loop, game state, entities, commands, canonical snapshots, headless runner. Add seeded RNG and rule events with the first systems that need them.
2. **Map and projection:** test map, coordinate projection/inversion, selection and movement destinations, simple collision grid.
3. **Single-unit movement:** command processing, simple pathfinding, arrival/blocked semantics.
4. **Group movement:** multiple units, destination spreading, obstacle avoidance, repathing, path cost profiling.
5. **Economy:** supplies, supply collectors, deposits, currency, initial construction and unit production.
6. **Combat:** health, basic weapons/armor, range, cooldowns, target acquisition, death/removal.
7. **USA vertical slice:** dozer + core buildings + infantry/vehicle combat + basic AI.
8. **China and GLA:** faction-specific construction and economy/units after common systems are stable.
9. **Advanced Zero Hour mechanics:** veterancy, garrisons, special abilities, air combat, superweapons, generals variants, multiplayer and campaigns later.

**For every bullet above, a corresponding set of automated tests is part of the deliverable.**

---

## 7. Milestones and exit criteria

### M0 — Project skeleton + executable test foundation (first task)

**Deliverable:** a Godot project that imports cleanly; a simulation object updated by fixed ticks; one headless test command; tests listed in §7.1; minimal README and CI. Temporarily break an existing expectation, verify a nonzero exit, then restore it. Do not leave a disabled failing test in the normal suite.

**Exit gate:** CI can reliably distinguish a failed test from a passed test **before any pretty gameplay exists**.

### M1 — One controllable vehicle

A desert test map; isometric projection; select vehicle; click-to-move; camera movement; simple pathfinding; UI feedback. Include movement/selection/projection tests.

Proposed concrete scope and execution details: [M1 vehicle plan](docs/superpowers/plans/2026-11-01-m1-vehicle.md). It is based on implemented M0 and explicitly migrates stationary-order tests to moving/arrived state. Prototype map, speed and four-way routes are not Zero Hour parity claims.

**Exit gate:** same movement orders yield repeatable results in headless simulation; view projection and click mapping work.

### M2 — Groups and obstacles

Select 10–30 vehicles; group move; building as obstacle; destination allocation; no pile-up that makes play unusable; basic benchmarks.

**Exit gate:** automated scenarios for open ground, blocking, group destinations and repathing; measured performance gates in §11 before expanding scope.

### M3 — Base and supplies

Construction vehicle, supply resource, Chinook-like collector, resource drop-off, basic power plant, production building, construction queue. USA economy requires limited collector flight now: ground obstacles do not block its cruise path; pickup, cargo, deposit and destroyed-destination behavior need explicit rules. Combat aircraft, passenger transport and advanced air interactions remain deferred.

**Exit gate:** fully automated supply and construction sequence with resource accounting assertions; observed timing parity as evidence becomes available.

### M4 — Combat + playable USA mini-match

Infantry, one or two vehicles, targeting, health/damage, basic AI, victory/defeat, build/selection HUD; a **small single-player skirmish**.

**Exit gate:** reproducible scenario test for a scripted 5–10 minute match plus combat reference fixtures and manual playability review. This is the first true vertical slice.

### M5 — Core factions

Add China and GLA distinct rules, units and economy differences using data definitions and behavior-specific tests.

**Exit gate:** three playable faction prototypes; economy/production/combat parity tracked by faction.

### M6 — Expanded Zero Hour scope (later)

Subfactions/generals, superweapons, advanced unit interactions, more environments/maps, campaign/scenario tooling, sophisticated AI and multiplayer research.

**Exit gate:** prioritize by player-visible fidelity, not by total checklist completeness.

### 7.1 M0 implementation plan — stop before movement

**Execution status:** original M0 commit passed local and remote checks; follow-up test additions verified locally. See [verification evidence](docs/reference/m0-verification.md) and [README](README.md) for current state.

**Execution detail:** follow [M0 foundation implementation plan](docs/superpowers/plans/2026-11-01-m0-foundation.md) for exact method signatures, data shapes, concrete acceptance cases and verification order. This section defines milestone scope; the linked plan resolves its implementation details without adding M1 work.

**Goal:** prove commands change inspectable state predictably through the same simulation entry point used by the game and tests.
**Architecture:** one engine-light simulation class; one scene drives it at 30 Hz; one explicit test runner calls `step()` without wall-clock waiting.
**Tech stack:** GDScript, an exactly pinned Godot editor build, shell wrapper and GitHub Actions.
**Spec:** this blueprint, especially §§3, 5 and 7. No gameplay reference data is required for M0.

Defaults below are implementation decisions for kickoff, not claims about EA behavior. Use the existing Superpowers execution workflow when implementing. This section records the M0 contract; the current kickoff prompt names the active milestone. Editing documents alone does not start implementation.

| Create or update when implementing M0 | Responsibility |
|---|---|
| `game/project.godot`, `game/scenes/main.tscn`, `game/scripts/main.gd` | Minimal launchable scene, Compatibility renderer, 30 Hz physics callback calling `step()` once |
| `game/scripts/simulation/simulation.gd` | Tick, entity IDs, ownership, command queue, current orders, snapshot |
| `game/tests/run_tests.gd`, `game/tests/test_simulation.gd` | Explicit test list, diagnostics, positive counts, suite completion and process exit status |
| `tools/run_tests.sh`, `tools/run_game.sh`, `.github/workflows/tests.yml` | Local/CI import and tests; explicit play command; verified pinned engine download; job timeout |
| `.gitignore`, `README.md`, `AGENTS.md` | Generated-file exclusions, exact engine/version and commands, concise project rules |

Do not create the future directory tree in §9 yet. Keep architecture/testing notes in README until they need separate documents. Preserve existing agent instructions.

Godot's `res://` root is `game/`: the simulation script is `res://scripts/simulation/simulation.gd`, and tests are `res://tests/`. Shell paths are repository-relative; do not mix the two conventions.

**Minimal contract:** `spawn(owner, position) -> id`; `issue_command(command) -> validation_result`; `step()` advances one tick; `snapshot() -> Dictionary` returns an independent canonical copy. An M0 `move` command only records a destination/order; actual movement starts in M1. No economy, combat, pathfinder, generic event bus, JSON fixture interpreter or save/load system.

- Tick starts at 0. `step()` consumes commands addressed to current tick, applies them, then increments tick. Commands at tick 0 are visible in the snapshot after the first step (tick 1).
- Command fields: `tick`, `player`, `sequence`, `type`, `entity_ids`, `target`. Process by `(tick, player, sequence)`; sequence is nonnegative, unique and increasing per player. Reject duplicates, past ticks, unsupported types and malformed/non-finite targets. Revalidate entity existence and ownership at execution. Reject a mixed-validity group atomically.
- For successive valid moves on the same entity in one tick, the later command replaces the earlier order. Entity IDs increase monotonically and are never reused during a match.
- Rejection does not change entity gameplay state. Advancing a tick still changes the tick and consumes that queued command; diagnostics may record rejection. Tests must compare affected fields, not demand that the whole snapshot remains unchanged after `step()`.
- Snapshot includes pending commands and sequencing state, sorts entities by ID, and cannot mutate live state. No RNG system until a mechanic uses randomness; adding RNG requires seed/state snapshot coverage then. No hashing library: compare canonical state directly in M0.

**Task A — runnable project and trustworthy runner**

- [x] Verify local engine version and official CI artifact availability; pin one matching version in README and CI. Do not silently install or upgrade to “latest.”
- [x] Create minimal project, scene and runner. Run an intentionally false expectation; record nonzero wrapper status. Restore it and verify success. Verify zero selected tests, a script parse error and a suite abort before completion all fail through the wrapper too; restore valid scripts afterward.
- [x] Adapt Hell's Verdict wrappers and CI using the same test command. Verify wrapper invocation from outside repository root. A fresh checkout must import without editor clicks; missing scripts, script errors or incomplete runner output must not count as success.

**Task B — command/snapshot kernel, test first**

- [x] Write failing tests for tick boundaries, same-tick replacement, wrong owner/missing entity/mixed group rejection, duplicate/past commands, snapshot isolation, and stable IDs. Each failure must be an assertion about behavior, not only a parse error.
- [x] Implement only enough kernel to pass them. Queue a nonempty command sequence, run 1,000 ticks twice, compare full snapshots and final orders. A no-op simulation must fail this test.
- [x] Drive the same `step()` from the scene; smoke-launch headlessly with a bounded run. Pure simulation tests must not instantiate presentation nodes or wait 1,000 real-time frames. Visible play checks wait for a requested play session; report visual validation pending until then.
- [x] Run wrapper locally and in CI; report counts, versions and red/green evidence. If remote CI cannot run, label that gate pending instead of claiming M0 complete. Review diff and stop; no automatic commit, push or M1 work.

**Review focus:** command rejection cannot partially affect a group; queued caller-owned data cannot mutate after submission; sorting cannot depend on dictionary iteration; snapshot copies cannot alias live state; test harness cannot turn script errors or no tests into a green run. Add these cases to the owning task before implementation is accepted.

### Scope discipline

**M0–M4 is the real initial project.** The full game is a very large undertaking, even with AI coding assistance. Build a fun, verifiable small skirmish first. Only then enlarge the content budget.

---

## 8. Data-driven mechanics

Prefer explicit definitions for unit properties, costs, production/tech prerequisites, weapon and armor interactions. Proposed layout (not a required finalized schema):

```text
game/data/
  factions/
  units/
  buildings/
  weapons/
  armor/
  upgrades/
  balance/
```

Track each chosen gameplay value in a fidelity matrix; record intentional design values as such:

| Parameter | Wargrid value | Reference evidence | Confidence | Test fixture | Status |
|---|---|---|---|---|---|
| Example: one vehicle's speed | TBD | In-game measurement / source | Unknown | `movement_parity` | Unverified |
| Example: unit build time | TBD | In-game measurement / config | Unknown | `build_timing_parity` | Unverified |
| Example: supply deposit value | TBD | In-game measurement / config | Unknown | `supply_round_trip` | Unverified |

Do **not** fill this table with guesses and relabel them as sourced facts.

---

## 9. Recommended repository organization

Use Hell's Verdict's `game/` project boundary. Subdirectories below are a later-milestone outline; §7.1 defines the smaller M0 file set. Create folders only as their systems appear.

```text
wargrid/
  Wargrid_Kickoff_Blueprint.md
  README.md
  AGENTS.md
  docs/
    reference/
      installation.md
      movement.md
      economy.md
      combat.md
  game/
    project.godot
    scenes/
      main.tscn
    scripts/
      main.gd
      simulation/
        simulation.gd
      presentation/
      input/
    data/
      units/
      buildings/
    assets/
      placeholder/
      original/
    tests/
      run_tests.gd
      test_simulation.gd
      fixtures/
      parity/
      perf/
  tools/
    run_tests.sh
    run_game.sh
    run_benchmarks.sh
  .github/
    workflows/
      tests.yml
```

Keep `game/.godot/`, build output, local environment files, temporary generated assets, large logs and EA's repository/installation backups out of tracked game source. Track authored scenes, resources and script UID files. Do not add export/signing setup until exports are in scope.

### Agent operating rules

[AGENTS.md](AGENTS.md) owns project-specific workflow instructions. [README.md](README.md) records current implementation status and verified commands; planned commands remain explicitly labeled until implemented and verified. Keep both aligned with this blueprint without duplicating its mechanic specifications.

---

## 10. First playable prototype design

**Scenario:** One compact desert map, USA mirror match against primitive scripted opposition.

**Bounded M4 roster:** construction dozer, Chinook-like supply collector, resource pile, power plant, supply center, barracks, war factory, one infantry type and one tank type. No optional Humvee in this slice. Use working names and placeholder sprites. Include only collector flight from M3; no combat aircraft or transport abilities.

**Interactions:**

- Select units with click / selection rectangle.
- Right-click to move and issue contextual commands.
- Construct a building in a valid footprint.
- Harvest resources; deliver to base; buy a unit.
- Attack an enemy; health decreases; destroyed unit stops acting.
- Basic camera controls and build/selection HUD. Minimap and fog of war are deferred until this loop works; label the test map fully visible.

**Important:** Initial mechanical rates, stats and unit definitions must be treated as **provisional** until researched or measured against the original. Do not block infrastructure work on recovering every exact number; simply distinguish provisional correctness from verified parity.

**Scenario contract:** one hand-authored flat map, two fixed starting bases with dozer and starting funds, finite supplies, no bridges/elevation or procedural generation. A deterministic opponent issues normal commands and pays normal costs; no hidden resource cheats. Proposed slice victory: opponent has no production-capable buildings or builders; evaluate both players after the tick, with simultaneous elimination a draw. This is a Wargrid prototype rule, not a verified Zero Hour victory rule. Restart must reset IDs, commands and world state.

### Prototype success criteria

- Player can complete one recognizable RTS loop: **gather → construct → produce → fight**.
- Headless test can reproduce a scripted version of that loop.
- Multiple units can move around a base without catastrophic crowding.
- Gameplay runs independently of render FPS.
- Clear, categorized parity gaps show exactly what is still different from Zero Hour.
- The game feels legible at the intended camera zoom.

---

## 11. Performance, multiplayer and future architecture

### Performance

Start with representative benchmarks at 100, 300 and 500 units, varying:

- Idle vs moving vs fighting.
- Unobstructed ground vs dense buildings.
- One group command vs many independent orders.
- Pathfinding spikes, collision queries, target scans, simulation tick distributions.

Track p50/p95/p99 tick time and test-machine metadata. At M2, establish a repeatable 300-unit movement workload (open ground and dense obstacles) with a 10-second warmup and 60-second sample. Proposed initial gate on the recorded development Mac: simulation p95 ≤ 8 ms, p99 ≤ 16 ms, and no growing tick backlog at 30 Hz. Measure rendered frame times separately; target p95 ≤ 16.7 ms at the recorded resolution/zoom for 60 FPS. These are engineering targets, not measured results or promises for unspecified hardware. Record engine/build, hardware, map, seed and unit count with each result.

Pathfinding work must be bounded per tick; blocked destinations cannot cause endless immediate retries. A long frame must not trigger unbounded catch-up work or silently drop simulation ticks. First measure the bottleneck, then choose the smallest fix; do not prebuild flow fields, threading or an ECS. Keep hardware-sensitive gates out of ordinary CI; run them before advancing the milestone. If a gate fails, fix it or explicitly revise scope/budget before expanding unit counts.

Use profiling before shifting code to C#, C++ or GDExtension. **Do not infer that Godot's built-in pathfinding will scale to entire armies without proof.**

### Multiplayer

Eventually compare lockstep deterministic simulation versus authoritative-server approaches. The original game can inspire research, but don't lock Wargrid into an architecture solely because Generals used one.

For now, keep commands serializable, state inspectable and simulation repeatable. Those are useful for single player, AI agents, debugging, savegames, replay playback and future multiplayer.

---

## 12. Licensing and release precautions

**Not legal advice.** The source is released under **GPLv3 with additional EA terms**. Notable conditions include restrictions on EA trademarks, notices, accurate attribution and identification of modifications. The source-code license does **not** automatically grant rights to EA trademarks or all game media/content. See the exact license rather than relying on summaries.

- Reusing / closely adapting GPL-covered source into Wargrid can create GPL obligations if Wargrid is distributed.
- Replicating game mechanics based on observation is different from copying protected code, but a literal remake can still implicate other copyrighted expression and trademarks.
- Do not ship EA sprites, music, audio, text, map files or logos without the necessary rights.
- **Noncommercial** or **free** does not automatically equal authorized distribution.
- An internal prototype using placeholder/original art is the lowest-friction starting point, but this is not a blanket legal exemption.
- Before sharing a public build, determine a legitimate route: permission/license, a sufficiently original standalone game, or a legally compliant modification requiring owners to supply the original game, as applicable.
- If public release becomes a serious goal, ask qualified counsel to review the concrete implementation, assets, branding, licensing and distribution model.

Keep the working title **Wargrid** independently of EA branding; also check name availability/trademarks before shipping.

---

## 13. Kickoff prompt for Codex CLI / Claude Code

Use [prompt.txt](prompt.txt) in a new session in the Wargrid repository. It now targets the [M1 vehicle plan](docs/superpowers/plans/2026-11-01-m1-vehicle.md); M0 is implemented. The prompt limits work to M1, requires verification/review and preserves Git/window approval rules. Keep the current handoff prompt in that one file rather than maintaining a second copy here.

### Follow-up prompt for a dedicated research agent

```text
Investigate how Command & Conquer: Generals — Zero Hour implements and
exposes group vehicle movement, pathfinding and destination assignment.

Use the separately checked-out official EA repository and pin its revision.
Find source paths and configuration evidence; validate important behavior
with actual game observations where possible.

Deliver docs/reference/movement.md with:
- externally observable behavior and edge cases;
- source links, revision and confidence labels;
- unanswered questions and an experiment plan;
- numbered, headless, deterministic parity scenarios and their expected
  results ONLY where evidence supports them;
- known/suspected defects, evidence and corrected Wargrid expectations;
- an independent Godot design proposal in world-space coordinates.
Do not reproduce original bugs or slow algorithms for the sake of parity.

Do NOT translate EA C++ into GDScript or paste EA code into Wargrid.
Do NOT fabricate movement speed, formation thresholds, exact timing, or
performance claims. Mark unknowns clearly.
Do not edit the live gameplay implementation in this research task.
```

---

## 14. Decision log

| Decision | Status | Reason |
|---|---|---|
| Name | **Wargrid** (working title) | Short, tactical, memorable. |
| Artistic direction | **Isometric pixel-art 2.5D** | Closer to Generals' visual depth and large-building feel. |
| Game design | **Zero Hour design strengths; deliberate defect fixes** | Preserve strategic identity and feel, without bug or performance compatibility. |
| Engine | **Godot 4.x** | Supports 2D art, UI, map editor and headless development. |
| Language | **GDScript first** | Best iteration speed; optimize after profiling. |
| Code reference | **Official EA Generals + Zero Hour source** | Behavior and architectural research, not direct port. |
| Testing | **Mandatory, concurrent with implementation** | Correctness tests plus selective fidelity checks; corrected defects get regression tests. |
| Simulation cadence | **30 Hz kickoff default** | Verified reference time grid; scheduling remains independent. |
| M0 test harness | **One minimal SceneTree runner** | Prove headless failures before adding a framework. |
| Project layout/tooling | **Adapt Hell's Verdict's `game/` boundary and wrappers** | Familiar commands and CI; small system-specific suites. |
| Desktop checks | **Headless by default** | Visible play on request; ask before rendering-dependent checks. |
| First slice | **Small USA skirmish** | End-to-end playable loop without giant initial scope. |
| Multiplayer | **Deferred** | Simulation/replay architecture first. |
| Public release | **Undecided; legal review required** | Source and content rights must be distinguished. |

---

## 15. Useful references

- EA original source: https://github.com/electronicarts/CnC_Generals_Zero_Hour
- EA GPLv3 + additional terms: https://github.com/electronicarts/CnC_Generals_Zero_Hour/blob/main/LICENSE.md
- EA modding resources: https://github.com/electronicarts/CnC_Modding_Support
- EA modding FAQ: https://www.ea.com/games/command-and-conquer/news/modding-faq
- Godot command-line guide: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- GdUnit4 command-line tests: https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/cmd/

---

**Guiding rule for everyone contributing to Wargrid (including AI agents):**

> **If the game looks right but the simulation is not measurable, we are not finished.**  
> **If our tests pass only because we guessed the expected behavior, we have correctness tests—not yet Generals parity.**  
> **If a mechanic changes, its executable behavior specification changes consciously and visibly.**
