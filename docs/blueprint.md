# Wargrid blueprint: design and milestones

Living design and milestone plan; current status lives in the [development notes](development.md).

**Working title:** Wargrid

> **North star:** Preserve the strong *game design and feel* of **Command & Conquer: Generals — Zero Hour**, while fixing defects and avoiding its performance limitations, using **Godot** and an original **isometric geometric 2.5D** presentation (§2). Treat the original game as the behavioral reference, not as a codebase to port wholesale.
>
> **Non-negotiable engineering principle:** **Build the behavior-test suite alongside the game, starting on day one.** No mechanic is considered complete merely because it looks right in a screenshot or works in one manual playthrough.

---

## 1. Vision and intent

Wargrid is a passion/learning project: a modern, scriptable, testable recreation of the RTS mechanics that make *Generals: Zero Hour* enjoyable.

**Target: Zero Hour-inspired game design, with reliable behavior and responsive performance.** Preserve faction identity, strategic tradeoffs, economy and combat pacing. Original bugs, exploits, stuck units, command failures and slowdowns are not compatibility requirements. Reference measurements inform design; they do not override an explicitly chosen correction. Start with a constrained playable subset.

### Long-term target (user, 2026-11-03)

**Three friends play 3v3 against three bots over the internet**, as USA, China and GLA, on a map that roughly resembles the classic Twilight Flame. Zero Hour generals are not needed for that goal. Colored-rectangle graphics are acceptable until play shows they are not.

**Roster goal (user, 2026-11-06):** every military unit of the three factions as in Zero Hour (ground and air; no generals' variants, civilians or campaign units), under Wargrid's own names; GLA becomes the FRC (Free Resistance Coalition). The milestone sequence in §7 is ordered toward this target.

### What to preserve

- **Faction identity and asymmetric mechanics:** USA, China, GLA; later the nine Zero Hour general variants.
- **Economy and base-building:** builders/workers, supply collection, construction, power, tech prerequisites, queues, upgrades, repair and destruction.
- **Combat:** infantry, vehicles, aircraft, weapons, targeting, armor, range, veterancy, garrisons, crushing and support powers.
- **Player experience:** responsive selection, move/attack-move/guard behavior, tactical readability, recognizable pacing, useful minimap, fog of war, hotkeys.
- **Strategic structure:** escalation from early economy to late-game units, technologies and superweapons.

### What to change

- **Rendering:** 3D visuals become **isometric geometric 2.5D shapes** drawn by Wargrid, with matching environments and effects (§2).
- **Engine and code:** original Godot implementation, data-driven where useful, with testable game simulation separated from visual scenes.
- **Developer workflow:** reproducible, headless tests and command-line automation so Codex / Claude Code can work largely without editor clicking.

### What is *not* the initial goal

- An exact frame-for-frame visual remake.
- All campaigns, maps, public online matchmaking or all nine general variants. (Private online play with friends is a goal; see the long-term target.)
- A production-grade networking backend on day one.
- Overengineering a fully generic ECS/framework before a playable slice exists.
- A polished asset pipeline before gameplay correctness can be measured.

### Important boundary

Using Zero Hour as a game-design reference does **not** mean rights to distribute EA branding, music, voice lines, maps, artwork, names or distinctive content are automatically granted. Public distribution must be evaluated separately (see §12).

---

## 2. Visual direction: geometric 2.5D

**Chosen (user, 2026-11-09; replaces the earlier pixel-art plan):** refined geometric minimalism. Units and buildings are built from a few flat primitives with simple top and side faces in the fixed isometric view, bright owner colour over quiet terrain, no textures. Details, colour values and the eight reference sheets: [art direction](art-direction/ART_DIRECTION.md); Godot findings: [art pass integration note](reference/art-godot-integration.md). Material that left the repository (interview images, GPT's QA and bookkeeping) lives in `~/projects/wargrid-art-archive/`.

The art-direction interview (2026-11-08, [answers](art-direction/interview/INTERVIEW_ARCHIVE.md)) is the starting point; any answer may be revisited (user, 2026-11-09):

1. High-contrast flat geometry from rectangles, circles and triangles; no pixel art or detailed low-poly.
2. Functional icons: tracks, turrets, blades and machinery from simple primitives.
3. Filled shapes with selective outlines and accents.
4. Responsive, punchy animation: recoil, small hull reactions, impacts; no cartoon bounce.
5. Minimal 2.5D: one top and one or two darker side faces.
6. Muted, darker biomes with bright units and effects.
7. Small geometric destruction normally; spectacle only for powerful attacks.
8. Shared role silhouettes with faction-specific construction; faction never shown by colour.
9. Buildings read by silhouette, with selective mechanical animation.
10. Matte shaded objects; only energy parts, shots, selection and key effects glow.
11. Progressive simplification when zoomed out; role features stay.
12. Owner colour on large top surfaces, neutral sides and machinery.
13. Refined minimalism: proportions, spacing and timing before extra detail.

Questions for M7.5 (mostly answered 2026-11-09): [scope](questions/next-m75-art-scope.md), [look](questions/next-m75-art-look.md), [world](questions/next-m75-art-world.md).

**Gameplay vs interface (user, 2026-11-09):** Zero Hour is from 2003. Wargrid should play like it, but the interface, controls and feedback may adopt improvements from modern RTS games, and the art style is Wargrid's own (above).

### Visual target

- **View:** Fixed-angle pseudo-isometric projection. Players perceive terrain depth and building height while controls remain a conventional RTS.
- **World:** Desert maps initially: sandy ground, roads, cliffs, a bridge/river if useful for the first test scenario, occasional vegetation.
- **Units:** Infantry, tanks, construction units and aircraft drawn as geometry at their simulation heading.
- **Buildings:** Footprints and clear entrances, functional silhouettes, construction phases and damage states later.
- **HUD:** Minimap bottom-left, selected-unit details and orders, build/production options, resources, power and population/capacity indicators where applicable.
- **Readability over detail:** Selection rings, color identity, health bars, range feedback, targeting feedback, no vital unit information hidden by scenery.

### Crucial implementation decision

**Simulation coordinates must not be isometric pixel coordinates.**

Maintain a normal 2D top-down **world plane** for unit positions, distances, collisions, pathfinding, grids and combat. Only project world positions into isometric screen coordinates during rendering. The mouse-to-world conversion must be the inverse of that projection (plus camera transform).

This prevents the chosen art style from complicating basic RTS rules, and lets tests run without rendering.

### Rendering guidelines

- Pick a consistent reference tile scale deliberately; avoid arbitrary per-object scaling.
- Enforce consistent direction conventions, feet/ground anchors, shadows and occlusion ordering.
- Sort drawn objects by their world-ground anchor rather than by their tallest visible point.
- Keep the camera zoom intentional; test readability with 50+ units on screen.
- Use placeholders until behavior tests pass, then iterate on shapes and effects.

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
| Platform target | **Developed on macOS; releases ship Linux, Windows, macOS and Web** (browser build live since 2026-11-06) | Convenient development; Steam Deck possible after portability checks. |

Godot remains the preferred engine for this independent implementation. A fork of the old C++ engine might preserve old behavior more directly, but is a poor match for an independent 2D art pipeline and modern headless test architecture.

### Reuse baseline: Hell's Verdict

Use `~/projects/hells-verdict` as the local tooling reference (inspected HEAD `3fffcb8`, with existing working-tree changes). Read the relevant files before adapting them; do not modify that project or copy its gameplay code. Its current CI configuration is evidence of a setup, not proof that the remote job or download still works.

| Reference file | Adapt for Wargrid |
|---|---|
| `game/project.godot` and project layout | Keep Godot project under `game/`, with scenes, scripts, data and tests; repository tools/docs stay outside it. |
| `tools/run_tests.sh`, `tools/run_game.sh` | Resolve paths from script location, quote paths, forward launch arguments, check test exit status and completion marker. Add `GODOT_BIN` support and headless import. |
| `.github/workflows/tests.yml` | Pin engine version and verify download checksum; run same wrapper on pushes and pull requests, with a job timeout. Verify artifact/checksum independently before reuse. |
| `AGENTS.md` | Terminal-first commands, explicit decision status, rules separate from scenes, headless checks, no surprise game windows, explicit Git approval. Keep Wargrid's existing personal instructions. |
| `game/tests/run_tests.gd` | Adapt assertion diagnostics and completion checks only. Keep suites small and grouped by system; do not copy the monolithic game-specific suite. |
| `game/scripts/debug/frame_stats.gd` | At M2, adapt percentile-reporting idea for separate tick/frame measurements, including p50/p95/p99. No display-tuning subsystem in M0. |

Wargrid keeps **Compatibility rendering and 30 Hz simulation**. Do not inherit Hell's Verdict's Mobile renderer, Jolt, 60 Hz physics, 144 FPS cap, disabled VSync, shooter inputs, server-authority assumptions or 3D interpolation settings. Choose display settings during M1. These small scripts do not warrant a shared cross-project library.

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
4. **Deterministic command processing within the same environment** as an immediate requirement. Cross-platform deterministic lockstep is **not** assumed automatically; floats, physics, ordering and runtime differences require explicit verification or different numerical representations later. Evidence so far: movement, economy and combat traces match exactly across Linux x86, Windows x86 and macOS ARM (CI run 41713005327 plus the local macOS comparison). From M5 cross-platform determinism becomes a requirement, checked by trace comparison and in-match hash exchange.
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

- Wargrid: `~/projects/wargrid`; README, agent instructions, blueprint and reference notes.
- EA checkout: `~/projects/CnC_Generals_Zero_Hour`.
- Inspected revision: `0a05454d8574207440a5fb15241b98ad0b435590`. Use this revision in source links and research notes.
- Research **`GeneralsMD/`** for Zero Hour. `Generals/` is the base game; do not mix their behavior without saying so.
- Installed engine reports `4.7.2.stable.official.ed1daf0bf` via `godot --version`. This is an observed local version, not a claim about the latest upstream release.
- The source checkout omits gameplay INIs. User-supplied installation backups under `~/CnC` contain readable `INI.big` (Generals) and `INIZH.big` (Zero Hour), including gameplay definitions. See [local data inventory and hashes](reference/installation.md). Use the root Zero Hour archive, not its obsolete nested duplicate; resolve overrides before claiming effective stats.
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

Archived: the test inventory checklist (M0 infrastructure, movement, economy, combat, large scenarios) is in the [blueprint archive](reference/blueprint-archive.md#57-essential-first-test-inventory-archived-2026-11-08). Current suites and counts: [development notes](development.md).

### 5.8 Testing tooling and CLI

Use **one minimal `SceneTree` test runner for M0**, delegating to small explicit suites. It must report counts, fail on zero tests, exit nonzero on failed expectations, and emit `TESTS PASSED <n>` only after every selected suite completes with a positive check count. The wrapper requires both successful exit and that final marker; missing/incomplete suites or script errors cannot pass merely because the process exits zero. Let CI terminate hangs. Do not build discovery plugins, a fixture assertion language or a second runner. Evaluate GdUnit4 when suite size or scene testing justifies migration; first prove its pinned version supports the required engine/headless mode.

Commands:

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

Configure push, pull-request and manual triggers. Pin one engine version in the development notes and CI, verify its archive checksum before installing, and set a job timeout. CI runs Linux and Windows with a dependent replay comparison job (macOS was dropped from CI 2026-11-03); see the CI paragraph in [development notes](development.md#setup-and-commands). No engine comparisons or release/signing setup.

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

Adopted concrete scope and execution details: [M1 vehicle plan](superpowers/plans/2026-11-01-m1-vehicle.md). It is based on implemented M0 and explicitly migrates stationary-order tests to moving/arrived state. Prototype map, speed and four-way routes are not Zero Hour parity claims.

**Exit gate:** same movement orders yield repeatable results in headless simulation; view projection and click mapping work.

### M2 — Groups and obstacles

Select 10–30 vehicles; group move; building as obstacle; destination allocation; no pile-up that makes play unusable; basic benchmarks.

Adopted execution contracts: [M2 groups plan](superpowers/plans/2026-11-01-m2-groups.md). Temporary travel overlap and distinct reserved destinations are deliberate prototype choices. Current implementation/verification status lives in the [development notes](development.md); [verification evidence](reference/m2-verification.md) records local correctness/simulation measurements and deferred visible/rendered/backlog gates and verified M2 remote matrix.

**Exit gate:** automated scenarios for open ground, blocking, group destinations and repathing; measured performance gates in §11 before expanding scope.

### M3 — Base and supplies

Construction vehicle, supply resource, Chinook-like collector, resource drop-off, basic power plant, production building, construction queue. USA economy requires limited collector flight now: ground obstacles do not block its cruise path; pickup, cargo, deposit and destroyed-destination behavior need explicit rules. Combat aircraft, passenger transport and advanced air interactions remain deferred.

**Adopted contracts:** [approved M3 design](superpowers/specs/2026-11-02-m3-base-supplies-design.md), [source/config evidence](reference/m3-economy.md), and [execution plan](superpowers/plans/2026-11-02-m3-base-supplies.md). Source-informed economy slice implemented after explicit2026-11-03 kickoff and accepted risk from deferred M2 visible/rendered/backlog gates. [M3 verification](reference/m3-verification.md) records automated accounting, cross-OS CI and user playtest evidence separately from remaining visible/performance/parity gaps.

**Exit gate:** fully automated supply and construction sequence with resource accounting assertions; observed timing parity as evidence becomes available.

### M4 — Combat + playable USA mini-match

Infantry, one or two vehicles, targeting, health/damage, basic AI, victory/defeat, build/selection HUD; a **small single-player skirmish**.

**Approved design (2026-11-03):** [combat and mini-match design](superpowers/specs/2026-11-03-m4-combat-design.md), [execution plan for Sol/Medium](superpowers/plans/2026-11-03-m4-combat.md), and [source/config evidence](reference/m4-combat.md). Implemented, verified and merged 2026-11-03; evidence in [M4 verification](reference/m4-verification.md).

**Exit gate:** reproducible scenario test for a scripted 5–10 minute match plus combat reference fixtures and manual playability review. This is the first true vertical slice.

### M4.1 — Polish from the first playtest (implemented and merged, playtest done, findings open)

User playtest notes, 2026-11-03: a rally point per producer (also fixes production stalling once a producer's perimeter is full), opponent base defense and reaction to enemies just beyond weapon range, read-only info for selected enemy objects, visible collector dock/waiting state at supply piles, and one HUD line "1/2/3/4 build".

**Approved design (2026-11-03):** [playtest polish design](superpowers/specs/2026-11-03-m4.1-playtest-polish-design.md) and [execution plan](superpowers/plans/2026-11-03-m4.1-playtest-polish.md): retail idle scan (vision × guard-outer modifier, both sides), opponent base defence, rally points with a default; AI moods deferred to M8. Implemented on `m4.1-polish` (2026-11-04), merged at `f2c5f9e`: suite 160 cases / 104,024 checks, benchmarks and CI green; playtest done 2026-11-04, findings open. Evidence: [M4.1 verification](reference/m4.1-verification.md).

**Exit gate:** a behavior test per note, the six-minute scenario recalibrated and re-pinned, benchmarks unchanged within budget, a user playtest.

### M5 — Online spike (two machines, lockstep)

Today's 1v1 skirmish played between two machines: deterministic lockstep with a small input delay, a minimal self-hosted WebSocket relay, periodic snapshot-hash exchange that stops the match on desync, waiting when a peer lags. No lobby, reconnect or matchmaking. See §11.

**Exit gate:** a complete match between macOS and Windows without desync, both clients' replay hashes equal, measured command latency against a budget, relay hosting decided and documented.

**M5 status (2026-11-04):** implemented and merged to `main` (`55beae4`); the macOS-Windows match ran on the pre-pacing-fix build and the repeat on the fixed build is a user-accepted deferral, to be played later. Findings: [M5 findings](reference/m5-online.md).

### M5.1 — Fixes from the friend-match playtest (implemented and merged, playtest done)

Fixes the four notes from the 2026-11-04 friend match:

- Human units acquire like Zero Hour: only in weapon range, no chase, plus retaliation when hit.
- Group orders skip dead and unarmed members.
- A hint marks each ground click, and the resume order has feedback.

**Exit gate:** the [milestone prompt](milestone-prompt.md) exit gate, with both match pins recalibrated.

Approved design (2026-11-05): [findings design](superpowers/specs/2026-11-05-m5.1-playtest-findings-design.md), [execution plan](superpowers/plans/2026-11-05-m5.1-playtest-findings.md).

### M6 — Teams and a full-scale map

**Status (2026-11-05):** implemented and merged to `main`; CI green, user 1v1 playtest done; the four logged findings were fixed 2026-11-06 (not seen on screen); see [M6 verification](reference/m6-verification.md).

Matches with up to eight players in teams with team victory; a map converted from EA's GPL-released Twilight Flame source (an official 8-player Zero Hour map, 4,900 × 4,900 world units, about 196 × 196 cells at 25 units per cell; user decision 2026-11-05, replacing "hand-authored, no EA map data"), under Wargrid's own name with EA's notice kept; navigation, allocation and snapshot costs scaled for that size (measure first; candidate fixes: incremental navigation updates, local destination search). Still USA only.

**Planning inputs (decided 2026-11-05):** decide the [parity spike decision list](reference/zero-hour-parity-spike.md#decision-list-proposal-for-the-next-combat-feel-work) (edge-to-edge range, Ranger cadence 4/4/22, tank splash, start delay and turning) and budget the pin re-calibration it forces (skirmish, netplay, BM6); fix the Chinook supply scenario to turn M3's provisional collector timing into measured values.

**Exit gate:** a deterministic headless 3v3 bots-vs-bots match on the full map within the [performance ledger](reference/performance.md) budgets, with new ledger rows.

**Planned 2026-11-05:** [approved design](superpowers/specs/2026-11-05-m6-teams-full-map-design.md), [evidence](reference/m6-map-and-feel.md), [execution plan](superpowers/plans/2026-11-05-m6-teams-full-map.md). User decisions: one milestone (not split); headless only; edge-to-edge range, Ranger cadence 4/4/22, tank splash hurting allies too, start delay, acceleration and turn-in-place; elevation affects passability only; firing ignores heading (no turrets yet; superseded in ground batch A by turret aiming, user 2026-11-10).

### Converted maps playable (small task; user, 2026-11-06; renamed from "Ashfall playable" and placed before unit avoidance 2026-11-08)

**Handoff:** [converted maps prompt](converted-maps-prompt.txt) (user, 2026-11-08): Dry Wells, Broken Crown and Ashfall selectable offline and online 1v1, both clients guaranteed the same map, the existing bots build, collect and attack on all three. Not the M9 lobby, and not bot tuning (M8). Also in scope (user, 2026-11-08): a Credits button and panel in the launcher showing the music, voice, map, Godot and Wargrid notices in every build; details and sources in the handoff's "Decided" section. **Decided (user, 2026-11-08):** the host's opaque `settings` (map and map hash) travel in `hello` and the relay echoes them in `start` with a relay-generated seed (protocol 2); the joiner refuses a map mismatch; 1v1 starts follow Zero Hour's start-spot rule. Details in the handoff's "Decided" section.

**Status (2026-11-09):** implemented and merged to `main` at `17e7f3d`, relay (protocol 2) and test web deployed, playtested by the user and **released as 0.10.0** the same evening (task done): map choice offline and online, protocol 2, start-spot rule, Credits panel; waves target enemy bases and fight units met on the way; pins re-pinned and `Fm1` green (cap 50,000); relay conformance 41 cases. CI green on Linux and Windows, macOS traces match. Open for M8: wave size (Ashfall `china,china` seed 1 seat 1 never hit a building). Evidence and open items: [converted maps verification](reference/converted-maps-verification.md), [more maps](reference/more-maps.md#converted-maps-playable-2026-11-09).

Make the converted maps playable in the launcher (Ashfall, plus Dry Wells and Broken Crown converted 2026-11-07, see [more maps](reference/more-maps.md); the online `start` message needs a map field first): map choice offline and online, terrain drawn as one batch (the performance spike measured about 5 fps with per-cell drawing). No minimap yet (HUD milestone).

**Partly done (2026-11-08, [more maps](reference/more-maps.md)):** the launcher plays Dry Wells offline and online (camera starts on the own base); terrain draws as one cached batch (`a1dfb03`) and structures in a cached layer; supply sources have their own footprint, so small piles exist ([design](superpowers/specs/2026-11-08-small-supply-piles-design.md)). Still open: map choice offline and online (the online `start` message carries no map, so two clients on different maps desync at the first hash check; different builds are already refused), Broken Crown and Ashfall in the launcher. Camera limits need no work: `main.gd` clamps panning to the map's own size (checked 2026-11-08); pan speed and the empty corners on the big maps are noted in the rendered check.

### M7 — Three factions with their signature mechanics

**Approved design (2026-11-06):** [M7 factions design](superpowers/specs/2026-11-06-m7-factions-design.md), [evidence](reference/m7-factions.md). USA, China and the FRC (Free Resistance Coalition, Wargrid's own name for Zero Hour's GLA) with the user's seven-row roster each, Command Centers, per-faction construction and gathering, GLA-style rebuild holes, horde, salvage, gattling ramp-up, transports and the tunnel network, buildings that fire; faction choice in the launcher offline and online; a plain data-driven build menu. Capability data, no faction branches in simulation code; Wargrid's own names in code and UI. Starts with a performance task on the three simulation rows over the F = 5.5 budget (trace-preserving fixes only). A seat survives while it owns a building flagged as counting for victory, as in Zero Hour (user, 2026-11-06). Three stop gates with a user playtest each (USA, China, FRC). [Execution plan](superpowers/plans/2026-11-06-m7-factions.md) (2026-11-06): gates 1 and 2 implemented (gate 2 signed off by the user 2026-11-07), gate 3 expanded to step level in its own planning session (2026-11-07) and implemented, plus the Zero Hour economy parity rework (4x5 piles, supply clearance, edge margin, dock arrival points, collector cycle data, skirmish piles 400); merged to `main` 2026-11-07 at its stop gate; the exit gate waits on the user's playtest ([resume record](reference/m7-verification.md#resume-record)). The three-faction 3v3 ends at the 45000-tick cap without a winner ("won inside 45000" waived by the user for that match, 2026-11-07).

**Pre-M7 gate (proposed 2026-11-03):** run or explicitly defer the reduced level 1 spot checks (S1–S3) in [Zero Hour verification](reference/zero-hour-verification.md) before kickoff. **Met 2026-11-05 (user decision)** by the [parity harness](reference/zero-hour-parity-harness.md); its [decision list](reference/zero-hour-parity-spike.md#decision-list-proposal-for-the-next-combat-feel-work) was decided in M6.

**Turn, movement and attack check (user, 2026-11-05):** for every new China and GLA unit, and again for the USA units, run the [parity harness](reference/zero-hour-parity-harness.md) `turn_`, `move_`, `range_` and `reach_` scenarios against the Wargrid simulation and compare whole traces (angle, speed and position per frame), not only the first-move frame. M6 compared the Dozer only at first move and at INI values; the full trace showed Wargrid turning twice as fast (fixed in M6: wheeled turn follows speed). The retail Dozer also slowed to 0.15 cells/s mid-turn at frames 70–80 (cause not identified); look for it in the other wheeled and tracked units.

**Exit gate:** the three stop gates passed; a deterministic headless 3v3 bots-only match on Ashfall with all three factions, simulation ledger rows inside the budgets or reported as exceeded (design §1); parity results as a decision list.

### Controls (small task after converted maps; user, 2026-11-08; not designed)

From a friend's playtest. Camera: edge scrolling also in a window and the browser, right-drag pans while a short right-click still orders, Space jumps to the last alert, H centres on the Command Center. Orders: Ctrl + right-click force-attacks, Shift + right-click queues move points, Shift + place queues buildings for a builder. Selection: control groups on the number keys (Zero Hour layout), period (.) next idle builder, comma (,) next idle army unit. The mouse stays StarCraft style with no option to switch. Letter hotkeys on HUD buttons and camera spots on F1-F8 wait for M7.6. Evidence and sources: [design answers](reference/design-answers-2026-11-08.md#controls-friends-playtest-user-2026-11-08).

### Order after M7; unit avoidance (user, 2026-11-07; order recommended and accepted 2026-11-07, scope not designed)

**Order:** M7 exit gate, performance spike, converted maps playable (user, 2026-11-08), controls (small task, user, 2026-11-08), unit avoidance milestone, then ground batch A, M7.5, M7.6, M7.9, ground batch B, M8, M8.1, M9. Added 2026-11-09 (user): an evidence-only art lab spike on its own branch soon, ahead of the rest of M7.5, then a simulation performance spike right after it; slot (user, 2026-11-10): avoidance spike round 3, the art lab, the simulation interface and determinism rules notes ([interface plan](superpowers/plans/2026-11-09-sim-interface-note.md), [determinism plan](superpowers/plans/2026-11-09-determinism-rules-note.md); approved 2026-11-10), the native simulation core spike ([handoff](native-sim-spike-prompt.txt); it is the simulation performance spike), then the unit avoidance milestone. Handoff for the spike: [performance spike prompt](performance-spike-prompt.txt).

**Status (2026-11-08):** the performance spike is done and merged to `main` (pushed 2026-11-08 with `4c98b9a`); results, remaining work and the tightened gates are in the [performance ledger](reference/performance.md#post-m7-performance-spike-2026-11). The next step in this order is the converted maps playable task ([handoff](converted-maps-prompt.txt)), then the unit avoidance milestone (not designed).

- **Performance spike** right after M7, simulation cost first; rendered cost only for two items the user added on 2026-11-07 (large-map terrain and per-frame redraws, the unexplained rendered tick tail of about 10 ms since the terrain cache). The exceeded rows in the [performance ledger](reference/performance.md) are accepted until then (combat stress, team match p99, the horde layout). Reported as exceeded, never loosened. It also answers whether a threaded web export is feasible.
- **Unit avoidance milestone** after the spike: units go around each other instead of through each other (a firm requirement from the M7 gate 2 playtest; today the M2 design permits overlap in transit). It changes pathing for every unit, so it re-pins every trace and needs its own benchmarks, a design spike on one map first, and a playtest. Risks to design for: deadlocks at docks and chokepoints, trucks, container boarding, horde clusters, lockstep determinism and WASM cost. **User answers (2026-11-08):** scope and behaviour, mostly Zero Hour's rules (standing friends step aside, vehicles over infantry, infantry pass through infantry, trucks on a supply run drive through units, crushing, last-resort pass-through after about 5 s, 0.5 ms cost cap): [design answers](reference/design-answers-2026-11-08.md#unit-avoidance-scope). Spike round 1 done on `spike-avoidance` (neither approach passed the cap); round 2 decisions (user, 2026-11-09 late evening): [avoidance follow-up](reference/design-answers-2026-11-08.md#unit-avoidance-behaviour). Also here: own units standing on a newly placed building's footprint move to the nearest free cell ([friend's playtest](reference/design-answers-2026-11-08.md#friends-playtest-reported-by-the-user-2026-11-08)).
- **Why this order:** the spike gives avoidance a measured per-tick baseline and probably its spatial grid; avoidance comes before new content so later rosters, the art pass and the M8 bots are tuned once against the final movement, and the trace re-pin happens once. Fog and art do not touch movement. Converted maps playable goes first (user, 2026-11-08) so avoidance is designed against real docks and chokepoints, later playtests have map choice and M8 is tuned on three maps.

### Sound spike (user, 2026-11-08; after M7, before Ground batch A)

Futuristic generated effects for every weapon of USA, China and FRC, deaths and destroyed buildings, a vocoder announcer for the local player, launcher and match music and three volume sliders. Presentation only: no simulation, replay or netplay trace change. Design: [sound spike design](superpowers/specs/2026-11-08-sound-spike-design.md); plan: [sound spike plan](superpowers/plans/2026-11-08-sound-spike.md); handoff: [sound spike prompt](sound-spike-prompt.txt). Exit: user playtest offline and online.

### Zero Hour data dump tool (small task, user 2026-11-09; before ground batch A planning; tool done, `0608070`; readers pointed 2026-11-09)

Plan: [zh-ini dump plan](superpowers/plans/2026-11-09-zh-ini-dump.md), handoff [zh-ini-dump-prompt.txt](zh-ini-dump-prompt.txt). `tools/zh_ini.py dump` parses every block of the pinned root `INIZH.big` (the existing `read_big`) into a local, gitignored JSONL file: one object or block per line with archive entry and line numbers, so findings stay citable as path:line and agents query it with `rg`, `jq` or `python3` instead of each writing its own decoder (a hand-rolled parse of `factionbuilding.ini` came out garbled on 2026-11-09). The tool and its test are tracked; the dump never is (EA data stays out of the public repo, §1); extracted values keep going into the reference notes with their sources. The task also points every reader at the tool, so later milestones use it instead of decoding by hand (user, 2026-11-09): AGENTS.md (reference handling), docs/development.md (setup and commands), docs/milestone-prompt.md (planning rules), docs/questions/RULES.md (research agents), the parity harness and Zero Hour verification notes, and the next milestone handoff: the ground batch A handoff, when written, must name the tool (none exists yet).

### Ground batch A (after unit avoidance; user, 2026-11-06; scope refined 2026-11-07, not designed)

**User answers (2026-11-08):** veterancy as Zero Hour (four levels, XP from kills per unit type, Zero Hour bonuses and Elite/Heroic self-heal): [design answers](reference/design-answers-2026-11-08.md#veterancy-ground-batch-a). Repair also lands here: idle builders auto-repair own buildings, plus a repair order, 2 % per second, free, as Zero Hour: [repair](reference/design-answers-2026-11-08.md#repair-friends-playtest-user-2026-11-08). Systems (user, 2026-11-09, all Zero Hour defaults): upgrades, add-ons, prerequisites, shells, scatter, minimum range, hazards, Palace, USA building self-heal: [batch A systems](reference/design-answers-2026-11-08.md#ground-batch-a-systems-user-2026-11-09). Turret aiming (user, 2026-11-10, all Zero Hour defaults): turrets turn at their own rate and fire once aligned, soldiers turn to face their target, turreted units fire while driving; one re-pin with shells and minimum range: [turret aiming](reference/design-answers-2026-11-08.md#turret-aiming-user-2026-11-10-impact-note).

The ground units that need only M7's systems plus veterancy, upgrades and the tech tree, hazard fields (poison, fire, radiation), new transport kinds, and travelling shots with minimum range (artillery). Replaces the earlier proposed "M7.1 roster fill". Per-unit evidence and the 32-unit split: [batch classification](reference/m7-factions.md#batch-classification-config-2026-11-07).

**User decisions (2026-11-07):**
- **Rank-gated units** (Paladin, Nuke Cannon, Marauder, Scud Launcher need a rank-1 promotion in Zero Hour) are gated by their building prerequisites only. No player rank; recorded departure until general's powers.
- **All rockets and shells travel**, the existing ones and the Patriot assist weapon included (the M7 weapon parity carry-over). Every combat trace re-pins once.
- **Upgrades:** every upgrade whose effect needs no batch B system. Camouflage, capture building, mines, booby traps, Radar Van Scan, CIA Intelligence and the Scout Drone go to batch B; MOAB waits for general's powers.
- **China's nuclear silo** arrives as an upgrade building without its missile power, for Uranium Shells, Nuclear Tanks and Neutron Shells.
- **To batch B:** Sentry Drone and Bomb Truck (stealth is their identity), the Terrorist's car bomb (with the Hijacker). The Terrorist itself ships in A with its suicide attack.
- **Cut:** a systems gate first, then one gate per faction, each with a user playtest.

**Roster (21 units, USA 6, China 6, FRC 9):**

| | USA | China | FRC |
|---|---|---|---|
| Units | Hazmat tech, Tomahawk, Ambulance, Paladin, Avenger, Microwave tank | Overlord (bunker, gattling and propaganda add-ons), Troop Crawler, Dragon tank, Inferno cannon, Nuke cannon, ECM tank | Terrorist, Angry Mob, Quad Cannon, Toxin Truck, Rocket Buggy, Marauder, Scud Launcher, Combat Cycle, Battle Bus |
| Add-ons | Battle and Hellfire drones on USA vehicles | Overlord add-ons | – |
| Buildings | Strategy Center | Propaganda Center, nuclear silo (no missile) | Palace (garrison 5), Black Market |

Batch B keeps the other 11: Burton, Pathfinder, Sentry Drone, Hacker, Black Lotus, Listening Outpost, Hijacker, Jarmen Kell, Saboteur, Radar Van, Bomb Truck.

**Proposed gates (not approved):**
- **A1 systems, on existing units:** veterancy (levels, experience from kills, rate-of-fire, damage and health bonuses; salvage's level-up branch replaces the M7 money departure); travelling shots with flight time and minimum range; hazard fields (damage ticks, fixed lifetime with no stacking as Zero Hour, user 2026-11-09; cleanup by Hazmat and Ambulance later); upgrades as capability data (per player and per object) and building prerequisites. User playtest of veterancy and travelling shots.
- **A2 USA, A3 China, A4 FRC:** units, buildings and upgrades as data, plus each faction's new mechanics. USA: point-defence laser, target designator, building disable, drones as follower units. China: Overlord add-ons, assault deploy, missile jammer and vehicle disable, deploy-to-fire, Nationalism and Subliminal on horde. FRC: spawn nexus, rider-dependent weapons, second life, suicide weapons, three salvage tiers, garrison, rebuild holes (user, 2026-11-09; [design answers](reference/design-answers-2026-11-08.md#ground-batch-a-systems-user-2026-11-09)).
- **Exit gate:** a deterministic headless 3v3 bot match on Ashfall with the new units in the bot lists, ledger rows inside budgets or reported as exceeded, parity decision list (`turn_`, `move_`, `range_`, `reach_` per new unit, flight time per projectile), CI, one review and `/ponytail-review`, user playtest.

**Line of sight for direct fire (user, 2026-11-09):** direct-fire units need a clear line over terrain and obstacles to auto-target, artillery does not, as in Zero Hour; this lands in batch A with artillery and replaces M6's "elevation affects passability only" ([design answers](reference/design-answers-2026-11-08.md#fog-of-war-m79)).

**Not in batch A:** aircraft; anti-air halves of ground weapons have no targets until then (Avenger's air laser, Quad Cannon's air gun); superweapons, general's powers and promotions.

**Risks:** as many units as M7's whole roster plus five new systems, so the design session may still split it. Travelling shots and hazard fields add per-tick objects on the rows the performance spike works on; measure in A1 before any roster gate. Scatter and jammer redirection must use simulation randomness only.

### R1 — Releases (small separate task, not a milestone; user, 2026-11-06; done 2026-11-07, `v0.6.0` released)

A pushed `v*` tag runs the full test suite on that commit, builds Linux, Windows, macOS and Web, and after one approval (GitHub Environment `production`) deploys the relay, then the web build, to fly and publishes unsigned desktop builds as a GitHub Release. The repository goes public first, after a history scan. Execution plan: [release workflow plan](superpowers/plans/2026-11-06-release-workflow.md). Fits between M7 gates; it changes no game behaviour.

**R1.1 — Room matching on a simulation fingerprint (user, 2026-11-06; not planned yet):** clients send a hash of the simulation scripts and game data as the relay's `build` string instead of the exact version, so UI-only releases share rooms and any simulation change never does. The version stays for display and release names.

**R1.2 — Release notes (user, 2026-11-08; not planned yet):** each GitHub Release says in players' words what changed since the last tag. `release.yml` uses `--generate-notes`, which lists merged pull requests; branches here are merged locally, so `v0.7.0` listed only a Dependabot bump and a compare link. The notes of `v0.6.0-rc.1` through `v0.8.0` were rewritten by hand on 2026-11-08. `v0.9.0` and `v0.10.0` got hand-written notes too. **Recommended approach (2026-11-09, user asked to record it; not planned yet):** a `CHANGELOG.md` with an "Unreleased" section in players' words, filled as features land (milestone and wrap-up work add the line), whose section becomes the release text; plus a short `/release` skill like kickoff and wrap-up that checks `main` is green, sets the version, tags, drafts or copies the notes and asks the user before every push, approval and deploy. Generated notes (release-please, changesets, PR labels) need pull requests or structured commits, which this repository does not use.

**R1.3 — Test relay (user, 2026-11-09; not planned yet):** a relay change should be tested on a test relay before it reaches production, as web builds already are (`wargrid-web-test`, which today shares the production relay by design: [test environment plan](superpowers/plans/2026-11-07-test-environment.md)). The protocol 2 deploy of 2026-11-09 goes straight to production as a one-off.

### M7.5 — Art pass (placement decided by the user 2026-11-05; scope proposed, not approved)

Give the game a deliberate look instead of placeholder rectangles and text labels. Placed after ground batch A so most units are styled once, and before M8 so the bot playtests are played on the real look.

**User note (2026-11-05):** the coloured-rectangle look is more fun than expected, so a stylised geometric direction is explored before sprites are committed to. Blueprint §2 chose pixel-art sprites; switching is a design change the user decides after the comparison below.

**Direction chosen (user, 2026-11-09):** geometric 2.5D replaces pixel art (§2), from an art-direction interview with reference sheets. The pixel-sprite candidate (A) below is dropped; the scope was reworked in the [scope questions](questions/next-m75-art-scope.md) (answered 2026-11-09, below). New look, Wargrid-made art: GPL-3.0-or-later (user, 2026-11-09).

**Scope answers (user, 2026-11-09; [scope questions](questions/next-m75-art-scope.md) Q3-Q11):** shapes as a short list per kind (boxes and cylinders) drawn by one shared function, triangulated once at load and sent as one triangle array per tick (the data-plus-one-renderer pattern of OpenRA, Recoil and Zero Hour); colour and shape look questions first on SVG A/B pages in Firefox; then an evidence-only art lab spike on its own branch soon (not after batch A), with two in-game variants per look question the SVG pages cannot settle (motion, shake, fog, effects, cost); lab objects: tank, bulldozer, infantry, power plant, war factory, supply source, supply depot; lab exit needs a native rendered row and a Web frame-time measurement of the same scene; visual events collected after every simulation step (as sound); buildings and units drawn in one depth-sorted list. The rest of M7.5 stays after batch A. Draft handoff for the lab: [art lab prompt](art-lab-prompt.txt) (slot: right after avoidance spike round 3; turrets drawing only in the lab, turret aiming lands in ground batch A; user 2026-11-10).

**Look answers without A/B pages (user, 2026-11-09; [look](questions/next-m75-art-look.md), [world](questions/next-m75-art-world.md)):** Zero Hour's 8 owner colours retuned to the sheet style; turrets turn toward their target at a fixed rate (whether turn rate gates firing is checked in planning); one detail level per zoom step; no text or glyphs on the map (progress and amounts in the selection panel); supply stacks shrink as boxes are taken; buildings rise out of the ground while built; water muted blue-grey, distinct from cliffs; converter brings back roads, rocks and tree clusters as decoration only; grid only while placing; infantry bodies fade within about 2 s; an ally/enemy colour option, off by default.

**Look answers from the A/B mock-up pages (user, 2026-11-09):** mid-tone ground instead of the sheets' dark ash; white selection mark as a thin ground diamond; health bars green to yellow to red; a small shadow under every unit on High; calmer, darker owner colour on whole roofs; exaggerated faction outline differences; infantry at true size (1.5x looked too big); damaged buildings darker with a missing corner at 70 % and 35 %, plus a thin static smoke column below 35 %; cliffs as a low raised step. Still open for the in-game lab: map biome, fog look, travelling shells, signature effects, camera shake, hit flash, wrecks.

**Earlier proposed scope (superseded 2026-11-09 by the scope answers below; only its last sentence still applies):** Task 1 is an art-direction spike on one scene with two candidates: (A) USA unit and building sprites (asset source decided first; no EA assets, see §1) and (B) the current geometry pushed further with per-faction shape language, outlines, shading and effects, kept varied at full-match unit counts. Each gets a rendered benchmark row. The user picks one (or a mix) from a neutrally labelled A/B page opened in Firefox, the workflow the user liked in the sound spike (see session notes 2026-11-08); the rest of M7.5 applies it to terrain, selection and health feedback, shot and death effects, and the other factions. Visuals only represent simulation state and never own rules (§2).

**Proposed exit gate:** the user's chosen direction recorded (blueprint §2 updated if it changes), a rendered benchmark row in the [performance ledger](reference/performance.md) with the chosen look and effects on, inside the same budgets and assumed slowdown; no simulation, replay or netplay trace change; user playtest of the look.

### M7.6 — Generals-style HUD (user, 2026-11-06; scope not designed)

**User answers (2026-11-08):** queue of 9, minimap flash on attack, minimap free with the Command Center for now, blank at low power or without a radar provider; "keep formation" command considered here; follow-ups 2026-11-09: selling (every building, 50 %, 3 s), Guard order, no selection limit, chevrons on all sides, map pings without text, health bars when selected, damaged or hovered; HUD round the same night: compact bottom dock, pinned factory panel, position-grid hotkeys, control-group row, production strip, alert feed: [design answers](reference/design-answers-2026-11-08.md#hud-m76).

The interface, not the world graphics: a bottom control bar with minimap, command buttons with icons, build queue with progress, credits and power, selection info. Layout need not follow Zero Hour closely (user, 2026-11-09, after a GPT HUD mock-up); the decided selection colours, real scale and HUD answers still apply. Reference mock-up (GPT, a proposal, not a decision; its optional panels and pinned factory context are open questions): [HUD v2](images/hud-v2/wargrid-hud-v2.png) with [notes](images/hud-v2/wargrid-hud-v2-notes.md), and [HUD v3](images/hud-v3/wargrid-hud-v3-notes.md) (Steam Deck, compact, 120-unit selection, placement). Both are kept on purpose: v3 builds on v2's scene but shows the optional panels (alert feed, team strip, tooltip, control groups) only collapsed, so v2 is the only frame with them open; review points for both are in [next-m76-hud.md](questions/next-m76-hud.md). Own art only (§12). The minimap lands here.

### M7.9 — Fog of war (placement and need decided by the user 2026-11-05; scope proposed, not approved)

**User answers (2026-11-08):** Zero Hour's model: map revealed at start as in retail multiplayer (`UseShroud = No`; changed from "black at start" by the user 2026-11-09), grey fog that hides enemy units, last-seen enemy buildings, no reveal from foundations, shared team vision: [design answers](reference/design-answers-2026-11-08.md#fog-of-war-m79).

Fair bots only mean something when a human and a bot see the same limited picture, so fog of war lands before the bots. Starting point is the Zero Hour model: shroud (never seen), fog (explored, not visible now) and live vision from units and buildings, shared inside a team.

**Proposed scope (not approved):** first audit how retail Zero Hour handles shroud and record departures; then visibility as deterministic simulation state per team, included in the snapshot hash; the renderer and minimap only display it (§2). Vision values come from the existing unit definitions (M4.1 already uses Ranger 100 and Crusader 150).

**Proposed exit gate:** visibility tests (own, allied, enemy, explored versus live), replay and netplay traces still matching, ledger rows for six players on Ashfall inside the budgets, and a user playtest.

### Ground batch B (after M7.9; user, 2026-11-06, scope not designed)

Stealth and detection, hacking, hijacking and capture: they need fog's visibility model first. Refine after the M7.9 design is approved.

**Moved here by the ground batch A decisions (user, 2026-11-07; evidence in the [batch classification](reference/m7-factions.md#batch-classification-config-2026-11-07)):**
- Units: Burton, Pathfinder, Sentry Drone, Hacker, Black Lotus, Listening Outpost, Hijacker, Jarmen Kell, Saboteur, Radar Van, Bomb Truck; the Scout Drone add-on.
- The Terrorist's car bomb, with the Hijacker.
- Upgrades: Camouflage, capture building, Mines, Booby Trap, Radar Van Scan, CIA Intelligence.

### M8 — Bots worth playing

**User answers (2026-11-08):** start from Zero Hour's enemy choice, target scores and wave timing, then develop Wargrid's own, better rules; far from parity is fine for bots; a losing bot never gives up: [design answers](reference/design-answers-2026-11-08.md#bots-m8). **Do not forget (user, 2026-11-08):** the bot's supply depot site is a map-converter stopgap (slot nearest the supplies, converted maps task); M8 replaces it with the bot choosing its depot near supplies itself, as Zero Hour's `buildBySupplies` / `findSupplyCenter` (AIPlayer.cpp:1849-1960, 2180-2250).

**Stopgaps from the converted maps task (user, 2026-11-08):** Bot depot placement: the converter's slot near supplies is a stopgap (2026-11-08); M8 replaces it with the bot choosing the depot site near supplies itself, Zero Hour's buildBySupplies/findSupplyCenter (AIPlayer.cpp:1849-1960, 2180-2250). Bot collector counts per supply center (USA 2, China 3, FRC 5, user 2026-11-08, what human players do) are a stopgap; M8 revisits them, with stronger difficulty levels making increasingly optimal economic choices.

**Wave size (user, 2026-11-09):** since waves target enemy bases and fight units met on the way (`DEFENCE_RADIUS`), armies meet mid-map; the side that wins the first battle camps there and each new 6-unit wave of the loser (`WAVE_MIN`) dies near its own base, so a losing bot may never reach a building on Ashfall ([diagnosis in the converted maps verification](reference/converted-maps-verification.md)). M8 decides wave size: bigger or growing waves, or new waves joining live ones.

**End-game income (user, 2026-11-09; placement not decided):** once the supply boxes run out, Zero Hour players live on secondary income built up earlier: USA Supply Drop Zone, China Internet Center with Hackers, GLA (Wargrid FRC) Black Market. Wargrid has none of these, so bots go broke and grind (Fm1 on `skirmish.json`: supply gone near tick 30,000, FRC wins only at 73,560; [converted maps verification](reference/converted-maps-verification.md)). Zero Hour's own skirmish bots build all three (`AIData.ini` in retail `INIZH.big`: `AmericaSupplyDropZone` :483, `ChinaInternetCenter` :620, `GLABlackMarket` :711; income amounts and timings not yet read). Today's plan has the Black Market in ground batch A and the Hacker in batch B; the Internet Center and the Supply Drop Zone are in no milestone yet (all buildings are wanted, see "Later"). To decide: where each lands so M8 bots can use them, and whether other end-game money sources are needed as well.

**Deliberate departure from Zero Hour (user, 2026-11-05):** fairness and challenge over parity. Zero Hour has three difficulties (`GameDifficulty`: easy, normal, hard); Wargrid bots follow the fair-play rules in the [fair bots research](reference/fair-bots-research.md) (user-supplied input, partly unverified; read it with its status note). A bot plays by the same rules, sees only what its team could see, and is held to a human-plausible command budget. No reference bot is a fairness model: checked 2026-11-05, OpenRA's squad targeting ignores shroud and fog, and Zero-K CAI marks its own threat check `FIXME: … maphax` (details in the research note), so the invariance test below is the real gate.

**Proposed scope (not approved), one full-strength fair bot:**

- One observation entry point: own state, what its team currently sees, public information and its own timestamped last-seen memory. Nothing else from the snapshot. Commands only through `issue_command`.
- A human-plausible attention budget (order changes per interval, squads under fine control); numbers chosen at planning from evidence, never guessed in this section.
- Economy, per-faction production from the faction data (M7 and both ground batches) with counters chosen from observed evidence, base defence, scouting, squads with missions, a combat estimate before committing and retreat with hysteresis, team coordination between bot seats through team-shared vision only.
- AI moods (Sleep, Alert 1.1, Aggressive 1.5), deferred from M4.1, and the parked chokepoint analysis from the M6 map-analyzer notes.
- A headless decision trace (goal, evidence, alternatives rejected).
- **First task, research (user, 2026-11-06):** re-read and decode all Zero Hour game data and sources for the bots (the decoded `SkirmishScripts.scb`, `AIData.ini`, AI C++), resolve the INI contradictions found so far (for example `AttackPriorityDistanceModifier`: one finding reads 100 from `AIData.ini`, another found the root file a stub) and write down what parity with Zero Hour's bots would look like. The result is a baseline and a source of ideas only: parity with the original bots is not a goal (the user judges them poor). The M7 gate 1 wave update (rally, release at 6 idle units or 60 s, one priority-minus-distance score, shared wave target) is a stopgap with guessed constants and is replaced by this milestone's bot. Starting evidence: [M7 verification](reference/m7-verification.md) sections "ZH skirmish AI vs defensive structures" and "ZH skirmish scripts decoded".
- Deterministic on every lockstep client: simulation RNG only, a per-tick CPU budget in the [performance ledger](reference/performance.md).

**Proposed exit gate:** the fairness suite (research §9) with zero violations, including a hidden-state invariance test (changing hidden enemy state leaves the bot's commands identical); the bot beats the M4 skirmish policy and a passive player across seeded matches in both slots, and defends; a ledger row for three bots on Ashfall; a local user playtest (online 3v3 needs M9).

### M8.1 — Difficulty levels and play styles (proposed 2026-11-05, scope not approved)

**User answer (2026-11-08):** three play styles besides "random": aggressive, economic, defensive: [design answers](reference/design-answers-2026-11-08.md#bots-m81).

**User decisions (2026-11-05):** about five levels, the hardest should beat the user and friends regularly, every level keeps a human-plausible command budget (larger at higher levels), play styles are selectable next to difficulty with "random" as an option.

**Proposed scope (not approved):** five levels cut from the M8 bot by removing competence (opening repertoire, scouting, prediction quality, counters, fight judgement, retreat, multi-front play, team coordination, budget size), never by changing economy or rules and never by fake weakness such as idle workers or cancelled units. Five, not finer: every level must be measurably stronger than the one below, and finer steps are neither distinguishable by players nor cheap to test. Styles (aggressive, economic, defensive, raider, adaptive) are separate from skill; scenario or command-line setting until the M9 lobby.

**Proposed exit gate:** a ladder test (each level beats the one below in most seeded matches, both slots; threshold set at planning), styles of one level inside a strength band, the fairness suite still at zero violations, and a user playtest at two or more levels.

### M9 — 3v3 online

Lobby with slots, faction, team, bot difficulty and play style (layout candidates are chosen by the same labelled A/B pages in Firefox as the sound spike used); three humans plus three bots through the relay; handling a dropped player (pause, or the player becomes a bot); browser export (exists since 2026-11-06) over the same WebSocket transport.

**Lobby look (user, 2026-11-08):** get close to [this mockup](images/lobby-mockup.jpg) (ChatGPT-generated): dark panels with cyan accents; map choice with starting positions on the left; your team (you plus two friend slots) and the bot team with a faction each; bot difficulty 1–5 and play style for all bots; Create match (gives a code to share) and Join by code. Panels and settings are confirmed at M9 planning.

**Lobby backend direction (user, 2026-11-09 late evening; [brainstorm](reference/lobby-backend-brainstorm.md), [deep dive](reference/lobby-backend-deep-dive.md); details and 20 questions wait for M9 planning):** option B: a Go lobby service (chi/v5, one WebSocket per client via `gws`, one goroutine per lobby room, Origin check) beside the relay; the lobby signs a per-player HMAC ticket the relay checks, so the relay never calls the lobby; a test pair with its own secret covers R1.3. Operational data in SQLite on a fly volume with Litestream backups to Tigris, standard SQL only; one lobby instance is fine (a restart loses only unstarted lobbies), the room code names its owning lobby for a later second instance. Analytics and telemetry (friends' benchmark results, match history as evidence, desync uploads) are kept separate and append-only; their store is decided when the benchmark page is built. **Correction:** the relay cannot stay unchanged: its seat count is global and a room starts when full (`relay/main.go:129`, `relay/room.go:159-166`), so any lobby needs relay protocol 3.

**Backend stack (user, 2026-11-08):** the relay stays as it is (`net/http` plus `gws`). More complex supporting services, such as the lobby if it needs its own service, use Go with `github.com/go-chi/chi/v5`, unless detailed milestone planning finds a good reason against it.

**Relay beyond one machine (user, 2026-11-04; design proposed):** rooms on several machines with the owner encoded in the match code, region-aware placement, deploys that drain live rooms, and reconnect by replaying the room's command log. Cloud-agnostic (user decision): no routing, discovery or placement feature that exists on one provider only. fly.io stays the host for now; Railway was evaluated in the 2026-11-05 [relay stack spike](reference/relay-stack-spike.md) instead of M5 Task 11 (fly kept). Options and host evidence: [relay scaling](reference/relay-scaling.md). **Scale versus availability (user, 2026-11-05):** one machine is acceptable for now and probably goes far; what it lacks is high availability (a crash or deploy loses live rooms), so M9 planning compares the availability options in [relay scaling](reference/relay-scaling.md#high-availability-options-proposed-2026-11-05) (including a Redis-compatible store, which fly offers as the third-party Upstash extension) before building the several-machine design. **Machine type (user, 2026-11-05; not measured):** rethink it at M9 planning, before the 3v3 gate: `shared-cpu-1x` throttles to a 6.25 % baseline under sustained load, and fly's `performance-1x` (100 % quota, listed at $33/month for 30 days running, billed per second, so little when suspended between matches) is the candidate; measure one room against ten before choosing.

**Exit gate:** a real 3v3 match with friends without desync.

### Later

Aircraft (USA 4, China 2) with air combat; superweapons; more maps; campaign tooling. The three factions' full military rosters are a goal (user, 2026-11-06); Zero Hour generals' variants are not. Order beyond that by what play shows.

**Every building and unit except superweapons (user, 2026-11-09):** the full roster includes all buildings, not only units; superweapons (Particle Cannon, Nuke Silo missile, Scud Storm) come later. The 2026-11-07 batch split classified units and their prerequisite buildings only, so these buildings are in no milestone yet (retail `commandset.ini` dozer and worker sets; [evidence](reference/m7-factions.md#batch-classification-config-2026-11-07)): USA Supply Drop Zone, Fire Base, Airfield; China Internet Center, Bunker, Speaker Tower, Airfield; FRC Stinger Site, Demo Trap. Placement not decided.

### 7.1 M0 implementation plan — stop before movement

Archived: the M0 task plan is in the [blueprint archive](reference/blueprint-archive.md#71-m0-implementation-plan--stop-before-movement-archived-2026-11-08); the contract stays in the [M0 foundation plan](superpowers/plans/2026-11-01-m0-foundation.md) and [M0 verification](reference/m0-verification.md).

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

Archived: the early repository tree (out of date: it predates `relay/`, `protocol/`, `web/` and the release workflows) is in the [blueprint archive](reference/blueprint-archive.md#9-recommended-repository-organization-archived-2026-11-08-tree). Current layout: README "How it's built".

Keep `game/.godot/`, build output, local environment files, temporary generated assets, large logs and EA's repository/installation backups out of tracked game source. Track authored scenes, resources and script UID files.

### Agent operating rules

[AGENTS.md](../AGENTS.md) owns project-specific workflow instructions. The [development notes](development.md) record current implementation status and verified commands; planned commands remain explicitly labeled until implemented and verified. Keep both aligned with this blueprint without duplicating its mechanic specifications.

---

## 10. First playable prototype design

Archived: the first playable prototype design (delivered in M4) is in the [blueprint archive](reference/blueprint-archive.md#10-first-playable-prototype-design-archived-2026-11-08).

---

## 11. Performance, multiplayer and future architecture

### Performance

Start with representative benchmarks at 100, 300 and 500 units, varying:

- Idle vs moving vs fighting.
- Unobstructed ground vs dense buildings.
- One group command vs many independent orders.
- Pathfinding spikes, collision queries, target scans, simulation tick distributions.

Track p50/p95/p99 tick time and test-machine metadata. At M2, establish a repeatable 300-unit movement workload (open ground and dense obstacles) with a 10-second warmup and 60-second sample. Proposed initial gate on the recorded development Mac: simulation p95 ≤ 8 ms, p99 ≤ 16 ms, and no growing tick backlog at 30 Hz. Measure rendered frame times separately; target p95 ≤ 16.7 ms at the recorded resolution/zoom for 60 FPS. These are engineering targets, not measured results or promises for unspecified hardware. Record engine/build, hardware, map, seed and unit count with each result.

**Low-end target (2026-11-03):** the project targets a low-end device and a browser (WebAssembly; the browser is the main target since 2026-11-09, see below). Budgets derive from a measured 5.5× slowdown relative to the development machine (Steam Deck browser run, 2026-11-06; the browser is a target next to desktop), tracked per milestone in the [performance ledger](reference/performance.md); the rendered benchmark runs with vsync off so it measures render cost. Existing development-machine gates above stay in force; the ledger adds stricter derived ones.

**Targets for the new look (user, 2026-11-09; [questions](questions/next-perf-targets.md)):** the browser build is the main target (unless good numbers prove unreachable there; then an engine change may be considered); the budget stays Steam Deck in Firefox (F = 5.5); friends get a benchmark page that sends results automatically (endpoint not decided); cross-origin isolation headers on the test web app only. Units update 30 times a second in the art lab; interpolation comes later as a High option. Graphics quality Low and High, picked from measured frame time and changeable in settings; Low drops outlines, shadows and extra effects and uses the far-zoom shapes at every zoom; A/B art decisions are judged on both. The rendered benchmark gets a fixed draw-call ceiling. Browser threads only once Godot's "Separate" render thread proves fast with the new graphics, measured once after the art lab (desktop and threaded web). No C++ for now; C++ in Godot (GDExtension) is acceptable later (user, 2026-11-09 late evening, replacing "rather change engine than port parts to C++"); a simulation performance spike for the browser horde overrun follows the art lab. **Simulation core (user, 2026-11-09 late evening; [decisions](reference/design-answers-2026-11-08.md#simulation-core-and-state-digest-user-2026-11-09-late-evening), [options](reference/sim-core-options.md), [digest research](reference/state-digest-research.md)):** own engine out of scope; the spike starts with a one-day Rust-in-Firefox-on-Deck check, Rust (C++ as backup) must show 5x after the data hand-off; fixed-point only together with a port. No-regret small tasks, placement open: a simulation interface note (new tests use only it), a determinism rules note, then our own full-state FNV-1a digest together with golden scenarios (one re-pin; CI traces too). The browser stays primary; a reduced browser mode is only a measured fallback.

Pathfinding work must be bounded per tick; blocked destinations cannot cause endless immediate retries. A long frame must not trigger unbounded catch-up work or silently drop simulation ticks. First measure the bottleneck, then choose the smallest fix; do not prebuild flow fields, threading or an ECS. Keep hardware-sensitive gates out of ordinary CI; run them before advancing the milestone. If a gate fails, fix it or explicitly revise scope/budget before expanding unit counts.

Use profiling before shifting code to C#, C++ or GDExtension. **Do not infer that Godot's built-in pathfinding will scale to entire armies without proof.**

### Multiplayer

**Decided (user, 2026-11-08): lockstep through the relay, decided by the M5 spike (2026-11-04).** The direction as first proposed (2026-11-03), kept as history, with the alternatives:

- **Deterministic lockstep.** Every client runs the full simulation; only commands travel. Commands already carry tick, player and sequence, and snapshots already hash exactly; trace comparison already shows identical results across three platforms.
- **Bots run inside the simulation on every client.** The opponent policy is a deterministic function of the snapshot, so all clients compute identical bot commands without extra traffic. From M8 it reads only that player's observation (own state, team vision, its own memory), not the full snapshot; the code rule is enforced by tests, since lockstep gives every client the full state.
- **Transport: WebSocket through a small relay server** (user choice: relay rather than one player hosting). Godot's high-level multiplayer API works over a WebSocket peer on desktop and in web exports, while ENet is not available in browsers, so one transport keeps the later browser build open. The relay forwards per-tick command batches and hashes and holds no game logic. Hosting: the user's existing fly.io account (sample config in the sibling `sb-watcher` project: `fly.toml`, region `fra`, shared 256 MB VM). Unlike that always-on worker, the relay accepts inbound WebSocket connections, so it needs an `[http_service]` section; letting fly stop idle machines and start them on connection keeps cost near zero between matches. Details belong to the M5 design.
- **Clients:** desktop builds first (user choice), browser later; the browser build has been live since 2026-11-06.
- **Desync detection:** clients exchange the per-tick snapshot hash periodically; a mismatch stops the match with a report.
- **More than one relay machine (proposed 2026-11-04, M9):** M5 runs one machine because rooms live in memory. Scaling keeps rooms in memory and routes by an owner encoded in the match code, without provider-specific features; see [relay scaling](reference/relay-scaling.md). Since 2026-11-05 one machine is acceptable and availability, not scale, is the open question.
- **Map scale drives cost:** the target map is about 196 × 196 cells; navigation rebuilds and destination allocation measured at 64 × 64 (see the [performance ledger](reference/performance.md)) would grow roughly 9×, so M6 measures and scales them before content depends on the map.

Authoritative-server simulation stays the fallback if lockstep fails the M5 gate. (History, before the 2026-11-08 decision: lockstep passed M5.) Keep commands serializable, state inspectable and simulation repeatable; that serves single player, AI agents, debugging, savegames, replays and multiplayer alike.

---

## 12. Licensing and release precautions

**Not legal advice.** The source is released under **GPLv3 with additional EA terms**. Notable conditions include restrictions on EA trademarks, notices, accurate attribution and identification of modifications. The source-code license does **not** automatically grant rights to EA trademarks or all game media/content. See the exact license rather than relying on summaries.

- **Public (user, 2026-11-08):** the repository and builds are public (released since v0.6.0); no formal legal review was done.
- **Decided by user 2026-11-03:** Wargrid code is GPL-3.0-or-later (`LICENSE`), compatible with EA's and OpenRA's "version 3 or later" grants, so small cited ports are allowed under the rule in `AGENTS.md`; ported EA code carries EA's notice and additional terms. Asset licence for original art is undecided.
- Replicating game mechanics based on observation is different from copying protected code, but a literal remake can still implicate other copyrighted expression and trademarks.
- Do not ship EA sprites, music, audio, text, map files or logos without the necessary rights.
- **Decided by user 2026-11-07:** Wargrid-made audio (generated effects, rendered announcer lines) is GPL-3.0-or-later; third-party audio keeps its CC0/CC-BY terms, listed in `game/audio/CREDITS.md`.
- **Decided by user 2026-11-05:** maps in EA's `CnC_Modding_Support` repository are released under GPL v3 with EA's additional terms; Wargrid may ship map data converted from them, keeping EA's notice and terms, under its own map names (rule in `AGENTS.md`).
- **Noncommercial** or **free** does not automatically equal authorized distribution.
- An internal prototype using placeholder/original art is the lowest-friction starting point, but this is not a blanket legal exemption.
- Before sharing a public build, determine a legitimate route: permission/license, a sufficiently original standalone game, or a legally compliant modification requiring owners to supply the original game, as applicable.
- If public release becomes a serious goal, ask qualified counsel to review the concrete implementation, assets, branding, licensing and distribution model. (History, before the 2026-11-08 decision: public, no formal legal review.)

Keep the working title **Wargrid** independently of EA branding; also check name availability/trademarks before shipping.

---

## 13. Kickoff prompt for Codex CLI / Claude Code

Archived: the root `prompt.txt` handoff and the M1-era research-agent prompt are in the [blueprint archive](reference/blueprint-archive.md#13-kickoff-prompt-for-codex-cli--claude-code-archived-2026-11-08). Handoffs live at `docs/<task>-prompt.txt` (current: [converted maps prompt](converted-maps-prompt.txt)).

---

## 14. Decision log

| Decision | Status | Reason |
|---|---|---|
| Name | **Wargrid** (working title) | Short, tactical, memorable. |
| Artistic direction | **Isometric geometric 2.5D** (user, 2026-11-09; was pixel art) | Keeps Generals' visual depth and large-building feel; the placeholder rectangles proved geometry fun and readable. §2 |
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
| Multiplayer | **Deterministic lockstep through the relay, decided by the M5 spike (2026-11-04)** (user, 2026-11-08) | Long-term target is 3v3 with friends; simulation, command and hash design already fit lockstep. |
| Online clients | **Desktop first, browser later** (user, 2026-11-03); the browser build has been live since 2026-11-06 | Same WebSocket transport serves both. |
| Performance target | **Browser as an option next to desktop; F = 5.5** (user, 2026-11-06) | Measured on a Steam Deck: Firefox/WebAssembly 4.9–5.5× the Mac editor build, native 3.4–4.2× ([ledger](reference/performance.md#target-factor-measurement-2026-11-06)). |
| Online connection | **Small relay server on the user's fly.io account** (user, 2026-11-03) | Easiest for friends; relay holds no game logic; existing account and deployment pattern. |
| Target map | **Full scale, Twilight-Flame-inspired, about 196 × 196 cells** (user, 2026-11-03) | Recognizable travel times; requires M6 scaling work. |
| Map source | **Converted from EA's GPL Twilight Flame map, own name "Ashfall"** (user, 2026-11-05) | Exact scale, elevation, starts and routes; EA notice and terms kept. |
| Bots | **Fair: same rules, same information, human-plausible command budget at every level** (user, 2026-11-05) | Challenge through decisions, not bonuses or machine-speed micro; deliberate departure from Zero Hour. |
| Difficulty | **About five competence levels plus selectable play styles; strong bot first (M8), ladder after (M8.1)** (user, 2026-11-05) | Levels cut once from the finished bot; finer steps are not distinguishable by players. |
| Fog of war | **M7.9, before the bots** (user, 2026-11-05) | Fair information limits need fog; otherwise bots would be built twice. |
| Faction model | **Capability data, no faction branches in simulation code; own names (`usa`, `china`, `frc`)** (user, 2026-11-06) | Same pattern as Zero Hour and OpenRA; later units become data rows; AGENTS forbids EA names. |
| Roster order | **After M7: performance spike, converted maps, avoidance spike round 3, art lab spike, sim interface and determinism rules notes, native simulation core spike (slots: user, 2026-11-10), unit avoidance, ground batch A, M7.5 art, M7.6 HUD, M7.9 fog, ground batch B, M8 bots, M8.1, M9; aircraft later** (user, 2026-11-06/08; order in §7) | Each batch lands after the systems it needs (stealth after fog). |
| Art | **Colored rectangles acceptable for now** (user, 2026-11-03) | Gameplay and online play first. |
| Public release | **Public: the repository and builds are public (released since v0.6.0); no formal legal review was done** (user, 2026-11-08) | Source and content rights must be distinguished. |

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
