# Wargrid Map Analyzer

> **Status 2026-11-05: superseded, kept as an idea source.** Written before the user decided to convert EA's GPL Twilight Flame map instead of hand-authoring one ([M6 design](../superpowers/specs/2026-11-05-m6-teams-full-map-design.md)), so its non-shipping assumption (§1 non-goals, §11) and the Rust CLI with a second parser no longer apply. Taken into [M6 Task 2](../superpowers/plans/2026-11-05-m6-teams-full-map.md): a route-length matrix on the source grid against the resampled grid, and a metric list per start (both report-only). Parked for later: chokepoint and alternative-route analysis (M8 bots), map validation for further maps, per-unit clearance profiles, PNG/HTML reports.

**Project concept and implementation plan**  
**Status:** Proposed / MVP not implemented  
**Primary reference:** Command & Conquer: Generals / Zero Hour maps (starting with Twilight Flame, if a lawfully accessible copy is available)  
**Target game:** Wargrid (Godot)

## 1. Purpose

Build a **local, headless reference-analysis tool** that reads map information from Command & Conquer: Generals, extracts gameplay-relevant properties, and compares those properties against independently authored Wargrid maps.

The goal is **gameplay parity, not asset conversion**. The tool should help answer questions such as:

- Are the starting positions similarly balanced?
- Do vehicles have comparable distances and route choices between bases?
- Are chokepoints, flanking opportunities, and defensible areas similar in strategic effect?
- Are resources similarly accessible and contested?
- Is there sufficient buildable terrain at each starting position?

The analyzer should eventually double as a **general-purpose map validation and bot-AI research tool** for Wargrid.

### Non-goals

- Rendering the original Generals game in Godot.
- Reproducing or distributing EA textures, meshes, sounds, or other proprietary assets.
- Automatically shipping a converted or exact copy of a Generals map as a Wargrid level.
- Building a general-purpose map editor in the MVP.
- Claiming exact movement parity before collision and unit-movement rules are modeled and verified.

## 2. Architecture

```text
Original Generals .map             Wargrid/Godot map
        |                                  |
        v                                  v
  Generals importer                   Wargrid exporter
        |                                  |
        +---------------+------------------+
                        |
                        v
             Common map representation
                        |
                        v
                 Analysis engine
          /        |         |        \
     Navigation  Economy  Buildability  Balance
          \        |         |        /
                        |
                        v
                 Report generator
              /       |         \
         JSON/CSV   PNG layers   HTML report
                        |
                        v
           Automated parity/regression tests
```

**Architectural rule:** Importers only parse and normalize data. Analyses operate on a shared, engine-independent map model; they should not know whether the input came from Generals or Godot.

### Inputs

- **Generals reference:** Original binary `.map` file obtained lawfully; the parser may optionally read locally installed game definitions needed to classify objects and infer footprints.
- **Wargrid candidate:** A stable JSON export from the Godot project's terrain, object, navigation, spawn, and resource definitions.
- **Analysis configuration:** Unit profiles (infantry, tank, large vehicle), movement assumptions, grid resolution, building footprints, and map-metric tolerances.

### Outputs

```text
reports/twilight-flame/
├── map.json
├── overview.png
├── elevation.png
├── passability-infantry.png
├── passability-tank.png
├── chokepoints.png
├── resource-access.png
├── base-distances.csv
└── report.html
```

`map.json` is normalized analysis data. Diagnostic images and HTML are *locally generated visualizations*, not assets intended for game distribution.

## 3. Data extraction

| Original map information | How it is used | Important caveat |
|---|---|---|
| Map dimensions | Normalize scale and positions | Confirm units and coordinate system |
| Heightmap | Elevation, gradients, ridges, ramps | Raw height alone does not establish pathability |
| Terrain/passability data | Approximate traversability | Must be checked against real movement rules |
| Placed objects | Resources, blockers, structures, landmarks | Classification may require external definitions |
| Player starts | Spawn positions and starting fairness | Starts may be identified through conventions/waypoints |
| Waypoints | Editor-authored paths and AI hints | Waypoints are not necessarily complete navigability |
| Terrain metadata | Buildability and terrain effects | Build placement depends on footprints and slope thresholds |

Distinguish in the data model between:

1. **Observed data:** Directly parsed from the source file.
2. **Resolved data:** Interpreted using game-definition tables or explicit metadata.
3. **Inferred data:** Derived by a heuristic or approximate simulation.

Record provenance and confidence where practical. Do not present inferred ramps, chokepoints, or travel times as ground truth without validation.

### Parser options to investigate

- [iron-curtain-engine/cnc-formats](https://github.com/iron-curtain-engine/cnc-formats): Rust format-parsing project. Check current module coverage and test it against a real Generals `.map` before relying on it.
- [OpenSAGE/OpenSAGE](https://github.com/OpenSAGE/OpenSAGE): Reference project for the SAGE engine and its formats.
- [EA CnC Modding Support](https://github.com/electronicarts/CnC_Modding_Support): Official released source/materials and associated license terms. Verify whether the desired map is actually included.
- Original Generals **World Builder → File → Dump Map to File**, where available: Potential quick starting point for object/waypoint text data, but not a replacement for full terrain parsing.

**First technical gate:** Confirm that a legally obtained Twilight Flame map can be parsed sufficiently to extract heightmap dimensions, object categories, and spawn coordinates. If the parser lacks these features, scope or extend it before doing pathfinding work.

## 4. Common map representation

The normalized model should be independent of both source engines.

```rust
struct AnalyzedMap {
    dimensions: MapDimensions,
    terrain: TerrainGrid,
    objects: Vec<MapObject>,
    starts: Vec<StartPosition>,
    resources: Vec<ResourceSite>,
}
```

Suggested additions when implementing:

- Explicit **world units and coordinate transforms**; never compare raw coordinates from different engines without normalization.
- **Navigation layers** per unit profile, including clearance radius, maximum slope, and obstacle rules.
- **Source provenance** per important fact or feature.
- **Map metadata** (source game/version, importer version, analysis profile version).
- A versioned **JSON schema** to keep generated reports compatible with tests and future tools.

Keep reference-specific raw data in local analysis directories. Only independently authored Wargrid map geometry and art should be included in the shipped game.

## 5. Analyses

### A. Ground navigation

Compute traversability and shortest-path measurements for different movement profiles.

- Rasterize terrain and obstacle geometry to traversable/non-traversable masks.
- Apply footprint/clearance and slope constraints per profile.
- Use **A\*** for interactive point-to-point path queries and **Dijkstra** for distance fields/many-target analysis.
- Produce a base-to-base shortest-path distance matrix.
- Test alternate paths by blocking important corridors and measuring route degradation.
- Distinguish **distance estimates** from time estimates; actual travel time depends on acceleration, turn behavior, collision, and other movement rules.

Useful metrics: shortest path length, accessible area, route redundancy, detour ratio, and path changes after simulated corridor closure.

### B. Chokepoints and connectivity

Construct a simplified navigation graph from the traversability grid.

- Estimate corridor widths relative to each unit profile.
- Find narrow passages connecting large reachable regions.
- Measure graph articulation points, bridges, and approximate betweenness centrality.
- Evaluate alternative ground routes between starting positions.
- Generate a chokepoint heatmap.

**Caution:** A topological chokepoint does not always equal a tactically important chokepoint. Strategic importance depends on resource positions, threats, terrain, and unit capabilities.

### C. Economy

- Locate resource sites and classify safe, contested, and remote resources.
- Measure shortest traversable routes from starts to nearby resources.
- Compare expansion routes and exposure to opponents.
- If game rules are known, model worker paths and collection-cycle assumptions.

Do not treat path length as income rate until collection rules and resource values have been modeled.

### D. Buildability

- Find sufficiently flat and unobstructed terrain.
- Apply building footprint dimensions, clearance, and placement rules.
- Calculate available area and the number of representative production/defensive structures that can be placed.
- Measure how layout capacity varies by starting location.

A large flat polygon may still be impractical for base-building if it has poor access or is fragmented by obstacles.

### E. Starting-position balance

Compare starts using a metric vector rather than presuming symmetric geometry is necessary.

- Nearest resource travel distance.
- Total accessible buildable space.
- Route distance to each opponent.
- Number and quality of alternative attack corridors.
- Access to expansions and contested positions.
- Accessibility for different unit classes.

Do not force all differences into a single score during MVP development. Expose the individual measurements and annotate significant trade-offs.

## 6. CLI interface

**Proposed commands** (illustrative, not an existing implementation):

```bash
wargrid-map analyze \
  --input "Twilight Flame.map" \
  --output ./reports/twilight-flame

wargrid-map compare \
  --reference ./reports/twilight-flame/map.json \
  --candidate ./wargrid/maps/duskfire/map.json
```

Additional useful commands later:

```bash
wargrid-map inspect --input "Twilight Flame.map"
wargrid-map validate --input ./wargrid/maps/duskfire/map.json
wargrid-map render --input ./reports/twilight-flame/map.json --layer navigation
```

Initial CLI should run cleanly on **macOS Apple Silicon**, entirely offline after dependencies and inputs are present, without invoking Godot or requiring a graphical desktop.

## 7. Report design

### Visual layers

The simplest useful HTML report embeds a shared 2D map view with toggles for:

- Terrain elevation.
- Infantry/tank passability.
- Spawn locations.
- Resource locations and accessibility.
- Shortest paths between selected bases.
- Chokepoints and narrow corridors.
- Buildable areas.

Start with generated PNGs and a static HTML page. Add a clickable two-point route inspector only after the CLI and metrics are reliable.

### Sample comparison

**Illustrative values only — not actual Twilight Flame measurements.**

| Metric | Reference | Wargrid | Difference |
|---|---:|---:|---:|
| Ground route length: base A → B | 1,200 | 1,250 | +4.2% |
| Buildable area: base A | 18,000 | 17,500 | −2.8% |
| Resource access time | 42 s | 44 s | +4.8% |
| Independent attack corridors | 3 | 3 | Match |

Comparison logic should:

- Normalize for coordinate scale.
- Use the **same analysis configuration and unit profile** on both maps.
- Report absolute and percentage differences where meaningful.
- Keep connectivity/route-category mismatches explicit, not hidden in an average.
- Support configurable tolerances and machine-readable test outcomes.

## 8. Behavior tests alongside the tool

The analyzer is most valuable when its measurements feed repeatable tests.

### Parser and model tests

- Loading the same file produces deterministic map dimensions and normalized coordinates.
- All start positions and resources fall inside the declared bounds.
- Import/export round trips preserve normalized map semantics where supported.
- Parser errors distinguish unsupported fields from corrupt input.

### Navigation tests

- A known open corridor is reachable for a small infantry profile.
- An obstacle blocks paths that intersect its footprint.
- A wider vehicle correctly fails to pass through a narrow gap.
- Blocking a sole connector disconnects the expected regions.
- Equivalent scaled maps produce comparable normalized route lengths.

### Parity regression tests

- Base-to-base route distances remain within justified tolerances.
- Required attack routes remain available for relevant profiles.
- Starting positions retain sufficient buildable terrain.
- Resource accessibility does not regress unexpectedly.
- Changes in chokepoint structure are called out explicitly.

Prefer small synthetic fixture maps for algorithm correctness and separate larger reference-map reports for qualitative validation. This prevents a flawed importer from making both the inputs and the expected values wrong.

## 9. Suggested repository layout

```text
wargrid/
├── game/                         # Godot game
├── tools/
│   └── map-analyzer/
│       ├── Cargo.toml
│       ├── src/
│       │   ├── import/
│       │   │   ├── generals.rs
│       │   │   └── wargrid.rs
│       │   ├── model/
│       │   ├── analysis/
│       │   │   ├── navigation.rs
│       │   │   ├── economy.rs
│       │   │   ├── chokepoints.rs
│       │   │   └── buildability.rs
│       │   ├── reports/
│       │   └── main.rs
│       └── tests/
│           ├── fixtures/
│           └── parity.rs
├── maps/
│   └── reference/                # Keep copyrighted source inputs private
└── docs/
    └── map-analyzer.md
```

The analyzer itself is a **Rust CLI**. Godot should provide a simple export path for its map data rather than being loaded by the analyzer. A shared specification (JSON schema) defines how geometry, units and obstacles are represented.

## 10. MVP milestones

### Milestone 1 — Parse and visualize one real map

**Deliverables:**

- [ ] Verify a lawfully accessible Twilight Flame `.map` source and its license/provenance.
- [ ] Evaluate `cnc-formats` parser coverage against that file.
- [ ] Extract dimensions, elevation, key object categories, and starting positions.
- [ ] Generate `overview.png`, `elevation.png`, and a summary JSON.
- [ ] Add small synthetic fixtures and parser sanity tests.

**Definition of done:** A deterministic CLI produces a readable elevation image and shows mapped start positions. Unknown object types are reported rather than silently ignored.

### Milestone 2 — Navigation analysis

**Deliverables:**

- [ ] Introduce configurable unit movement profiles.
- [ ] Compute traversability and shortest-path maps.
- [ ] Produce base-to-base ground distance CSVs.
- [ ] Add corridor-width and route-redundancy measurements.
- [ ] Verify representative paths against source behavior or hand-inspected geometry.

**Definition of done:** The tool explains why a representative unit can or cannot reach each base and visualizes its chosen routes.

### Milestone 3 — Wargrid comparison and regression testing

**Deliverables:**

- [ ] Export Godot map data to the shared schema.
- [ ] Run identical analyses on source and Wargrid maps.
- [ ] Produce difference tables and basic visual comparisons.
- [ ] Add configurable thresholds for meaningful regressions.
- [ ] Wire analysis into a repeatable local/CI test command.

**Definition of done:** One command reports key gameplay similarities and differences between a reference analysis and an independently authored Wargrid map.

### After the MVP

- Economy/accessibility models.
- Base-placement and buildability scoring.
- Multi-profile navigation including air/water restrictions where appropriate.
- Browser-based interactive report.
- Map quality checks and map-awareness inputs for improved bot AI.

## 11. Legal and distribution boundaries

Wargrid is a **standalone Godot game**, not necessarily an authorized Generals mod. Accordingly:

1. **Verify the exact license and terms of any released source files.** Availability of game code or map data under GPL does not mean all Generals art and branding are freely reusable, nor that all standalone uses are authorized.
2. **Keep reference game data separate from shipped assets.** Original maps and any derived detailed geometry should remain in the local analysis workflow unless redistribution rights have been specifically verified.
3. **Create original terrain, textures, landmarks and props** for Wargrid. Gameplay-inspired features such as map scale, faction counts, and broad balance objectives are safer design targets than a mechanically traced copy of a distinctive original level.
4. **Avoid claiming legal safety solely because assets were redrawn.** An exact level layout can raise separate issues from textures and models.
5. **Review licensing before public release**, especially if the game or its maps closely reproduce a named original map.

This is a practical risk-reduction workflow, not legal advice or a guarantee of non-infringement.

## 12. Guiding decisions

- **Prefer Rust** for fast, deterministic, portable offline analysis; check existing parser crates before writing a new parser.
- **Prefer measurements over subjective resemblance.** Route choices and economic balance matter more than matching every decoration.
- **Prefer layered, inspectable outputs over one opaque parity score.**
- **Keep data provenance explicit** so approximations are not mistaken for facts.
- **Build behavior tests from day one**, especially for navigation and map fairness.
- **Start with one map and one unit profile** before expanding into a complex multi-map system.

**Recommended first task:** Confirm that a lawful Twilight Flame file can be read by `cnc-formats` (or another parser), then print map dimensions, start positions, and generate a grayscale heightmap. That is the smallest vertical slice that proves the idea is viable.
