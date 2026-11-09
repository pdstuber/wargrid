# Engine portability and a later horde mode (2026-11-09)

Research by an agent; evidence, not decisions. Read-only: nothing run, nothing measured, nothing changed but this file. **source** = read in the cited file or fetched page (quoted); **inferred** = the agent's reading or arithmetic. Repo paths are relative to the root. Web pages fetched 2026-11-09.

## Question 1: engine-change readiness

### What couples the simulation to Godot today

The sim is 19 `.gd` files, 3,711 lines (`game/scripts/simulation/`, `wc -l`). It uses no nodes, signals, `Time` or `OS` (**source**, `rg` over the folder: 0 hits for `extends Node`, `signal `, `Time.`, `OS.`). Everything is `RefCounted` plus static functions. The boundary in blueprint §3 holds. The coupling sits in five places:

| Coupling | Where (**source**) | Why it matters for a port (**inferred** unless marked) |
|---|---|---|
| **Godot's built-in `Dictionary.hash()` in the state digest** | `state_hash.gd:12` `"%08x%08x" % [state.hash() & MASK, core_check(state)]`. The docs only say it "Returns a hashed 32-bit integer value representing the dictionary contents" (Godot `class_dictionary`, fetched) | The first 8 hex digits of every digest are an undocumented engine hash over the whole snapshot. No other engine can reproduce them, so no CI trace, `FINAL_DIGEST` (`game/tests/test_team_match.gd:13`) or `PINNED` (`game/tests/test_state_hash.gd:6`) can be checked across engines. The second half (`core_check`, FNV over id, owner, hp, position × 1024 and credits, `:16-34`) is already engine-neutral. **Biggest gap.** |
| **`AStarGrid2D` path choice** | `grid_navigation.gd:5, 18-25, 117` (`get_id_path`, Manhattan, no diagonals, no jumping) | When several shortest paths exist, Godot's open-list tie-breaking picks one. A port has to reproduce that order exactly, or every movement trace changes. |
| **`Vector2` is float32; GDScript `float` is float64** | Godot docs: "By default, float is 64-bit in GDScript, but Vector2, Vector3 and Vector4 are 32-bit" (large world coordinates page, fetched). Positions are stored as float arrays (`entity.position[0]`, `state_hash.gd:22-23`) but go through `Vector2` in distance and allocation maths (`combat.gd:37-41, 239, 263`; `destination_allocation.gd:12, 49, 75-76`; `containers.gd:18-20`; 109 `Vector2` hits) | Each `Vector2(...)` rounds silently to float32. A port has to round at exactly those sites (Rust `f32` casts would do it), otherwise distances differ in the last bit and traces diverge. Nobody has written this rule down. |
| **Dictionary-per-entity storage and insertion-ordered iteration** | `simulation.gd:32` `var _entities: Dictionary = {}`; 471 `Dictionary` hits; `.keys()` loops at `containers.gd:85`, `construction.gd:136`, `combat.gd:370, 414`. Docs: "Dictionaries will preserve the insertion order when adding new entries" (fetched) | Ported straight, iteration order has to be preserved too. It is also the main per-unit cost (Question 2). |
| **Godot `RandomNumberGenerator` for start spots** | `start_spots.gd:19-28`, called from `game/scripts/match_settings.gd:33` | Minor. The in-tick RNG is already a portable 32-bit xorshift (`simulation.gd:57-63`). Only start-spot assignment uses Godot's generator. |

Already engine-neutral (**source**):
- The wire format is JSON (`game/scripts/net/wire.gd:19, 28`) and is pinned by `protocol/vectors/*.json` and the Go black-box suite in `protocol/conformance/`.
- Maps are JSON (`game/data/maps/*.json`).
- Unit definitions are JSON-shaped literal dictionaries in GDScript (`definitions/usa.gd:5-11`). Trig is precomputed as literals (`turn_cos`, `turn_sin`), so the tick path has no `sin`/`cos` (`rg`: only a comment, `locomotion.gd:33`). Only `sqrt`, which IEEE 754 rounds correctly, is used.
- Traces are `tick<TAB>digest` TSV files that a Python tool compares (`tools/compare_replays.py:11-26`, `tools/compare_local_traces.sh`). They are produced in CI, not committed (`git ls-files`).

### Candidate engines and stacks

| Stack | Web threads / perf (**source**, fetched) | Determinism | Fit / effort / risk (**inferred**) |
|---|---|---|---|
| **Godot + GDScript (today)** | Thread Support "requires the use of cross-origin isolation headers" (Godot `exporting_for_web`). Already measured slower in Firefox (+4.7 to +8.3 %, `art-perf-levers.md` §4) | Native and WASM digests already match (`performance.md:274`) | No port. The ceiling is GDScript speed per unit. Effort 0. Risk: the horde mode is out of reach (Question 2). |
| **Godot + native sim (GDExtension)** | "GDExtensions still need to be specifically compiled for the web platform to work" (same page). Also "Projects written in C# using Godot 4 currently cannot be exported to the web", so C# is out | FMA contraction risk (`art-perf-levers.md` §5) | Keeps the renderer, UI, audio and relay client. Port only `simulation/`. Rust via godot-rust instead of C++ is possible (not checked). The user prefers an engine change to this. Effort L. |
| **Bevy (Rust)** | `multi_threaded`: "Disabling it forces all engine tasks to run on a single thread" (`bevy/docs/cargo_features.md`). bevy_tasks: "The same API is used in single-threaded environments ... This currently applies to Wasm targets" (`crates/bevy_tasks/README.md`) | Wasm floats are deterministic apart from NaN bit patterns ("there is nondeterminism in determining the specific bits of the NaN") and relaxed SIMD (WebAssembly `Nondeterminism.md`) | Code-only, so a good terminal-first fit. On the web it is single-threaded, like Godot. Gain: compiled Rust instead of GDScript. Cost: renderer, UI, audio, lobby and web glue all rebuilt. API stability across releases not checked. Effort XL. |
| **Custom Rust sim (wasm) + TypeScript/WebGL renderer** | Same Wasm rules. Threads need SharedArrayBuffer/COOP-COEP, like every stack here | As Bevy. JS numbers are float64, so a TS sim is also possible, but slower than Rust | Best fit for "browser is the main target": smallest runtime, and the sim is a plain library that tests, the relay and tools can call. Desktop builds need a wrapper. Most UI work of all options. Effort XL. |
| **Defold (Lua)** | "The threaded engine requires `SharedArrayBuffer` in a secure, cross-origin-isolated page" (Defold HTML5 manual) | Not checked | Lua is in the same class as GDScript, so no speed gain for the sim. Reject. |
| **Unity Web** | "Managed (C#) threads aren't supported on the Web platform ... However, Unity provides multithreading support ... for C# jobs compiled with the Burst compiler" (Unity Web technical overview) | "Physics simulations in Web aren't guaranteed to produce the exact same results" (same page). Burst float determinism not checked | Editor-centred, licence terms, no terminal-first workflow. Reject. |

Verdict (**inferred**):
- No stack gets real web threads for free; the browser stays effectively single-threaded everywhere. A switch therefore buys only compiled-language speed per unit, roughly 10-50× GDScript (not measured here).
- Only a change for the horde mode would justify that. Skirmish already passes on the Deck (`performance.md:180`).
- If it ever happens, the cheapest route is "Rust sim library + keep Godot as renderer via GDExtension" or "Rust sim + web renderer". Both need the same thing first: a sim whose behaviour is pinned by engine-neutral vectors.

## Question 2: horde mode like They Are Billions

### Primary sources on unit counts
- **source**: They Are Billions Steam page: "We have created our custom engine to handle hordes of thousands of the infected, up to 20,000 units in real time" (store.steampowered.com/app/644930, fetched).
- Not verified: a GamesBeat interview reportedly quotes the director on "up to 30,000 zombies", and on Unity being unable to move even about 400 units smoothly. The page returned 403, so this is a search-result summary, **not a primary source**. Do not cite it.
- Not found: a developer post on their engine design (language, pathing technique).
- Flow fields: the Game AI Pro chapter "Crowd Pathfinding and Steering Using Flow Field Tiles" was fetched as a PDF, but no text could be extracted (no PDF tool on this machine). Content **not verified**.

### Where Wargrid stands (ledger numbers, source; arithmetic inferred)
- The `hordes300` layout is 400 fighting units (300 militia against 100 riflemen, `performance.md:155`). On the Deck in Firefox it measures p95 14.54 ms (`:180`); on the Mac natively 2.82-2.86 ms (`:194-195`).
- **inferred**: about 36 µs per fighting unit per tick at p95 on the budget device (14.54 / 400), sim only, no rendering.
- The sim budget is 10 ms per tick on the target (`performance.md:16`). Linear scaling gives about 275 fighting units inside the budget, and about 900 if the sim took the whole 33.3 ms tick with nothing left for drawing.
- TAB-scale 2,000 / 20,000 units would cost about 72 ms / 730 ms per tick. Acquisition and A* grow faster than linear, so real numbers would be worse.
- The Mac native ceiling is about 4,700 units for a whole tick (7 µs per unit), so the Mac is a misleading test box for this.

### What a horde mode would need (inferred)
1. **Simple enemy agents**: no production, no allocation, no veterancy. Each one only reads a flow field and avoids its neighbours.
2. **Pathing**:
   - One flow field (Dijkstra) per goal (the player base), rebuilt when buildings change, instead of per-unit `AStarGrid2D` routes (`grid_navigation.gd:117`). On 196×196 that is about 38k cells per rebuild, bounded and spread over ticks.
   - Blueprint §11 forbids prebuilding flow fields, so they belong to the horde milestone, not before.
3. **Spatial partitioning**: the per-owner target grid already exists (`perf-spike-verification.md` 2b). Neighbour avoidance needs the same grid for separation.
4. **Data-oriented storage**: horde agents in `PackedFloat32Array`/`PackedInt32Array` columns instead of one `Dictionary` per entity. Likely 2-4× in GDScript. Not measured; this is the first thing to measure.
5. **Lower update rate for horde agents** (for example every third tick, staggered, the way `Horde.step` already staggers, `horde.gd:8-9`): about 3×.
6. **Rendering**: the decided triangle array costs 2 GDScript calls per unit per tick (`art-perf-levers.md` §3A). At 2,000 units that is 4,000 calls plus a large vertex upload each tick. For one look-alike enemy kind, a MultiMesh (§3D) avoids the per-unit GDScript cost, but loses depth order between kinds.
7. **Netcode**:
   - Single player needs no lockstep.
   - Co-op over the relay suits lockstep well, because only commands travel (blueprint §11), so bandwidth does not grow with unit count. Every client still runs the full horde, though: the slowest machine sets the cap.

### Can the current stack get there? (inferred)
- Optimistic multipliers: 2-4× from packed columns, 3× from a lower update rate, about 2× from simpler agents. Together about 12-24× cheaper per agent, which gives roughly **3,000-6,000 horde agents** in 10 ms on the Deck in Firefox. That is a guess, never measured.
- Realistic: rendering and flow-field upkeep share the frame, so **about 1,000-2,000 on screen** is a plausible GDScript ceiling.
- It breaks outright at about 300 full Wargrid units (today's model) and at low thousands of simplified agents. TAB's 20,000 is out of reach in GDScript on the browser target.
- A compiled sim (Rust in Wasm), with the same changes on top, would plausibly reach 10,000+.
- **A 1,000-2,000 wave mode is reachable in Godot; a TAB-like 20,000 is not.** A three-hour spike can settle this: 2,000 packed agents on a flow field, Deck Firefox, before any engine decision.

## Cheap prep steps worth doing now (ranked)

1. **Write a determinism rules note** (effort XS). The five couplings above: float32 rounding at `Vector2` sites, float64 elsewhere, `sqrt` only, no trig in ticks, insertion-ordered iteration, xorshift RNG, A* tie-breaking. No-regret: it documents today's behaviour, changes no code, and helps every lockstep review now.
2. **Engine-neutral golden vectors for the sim, like `protocol/vectors`** (effort S). Commit a few small scenarios (commands in) with `core_check` per N ticks and a canonical-JSON snapshot at the last tick. No-regret: it catches regressions today, needs no Godot hash, and becomes the cross-engine conformance suite later.
3. **Move the digest's first half from `Dictionary.hash()` to an FNV over the canonical snapshot** (effort S-M; re-pins `PINNED`, `FINAL_DIGEST` and the relay hash value once). Do it while there are few pins. Measure the hash-tick cost first, so not purely free.
4. **Golden A* vectors** (effort XS): map + start/goal → expected `get_id_path`, committed as JSON. They pin tie-breaking for any reimplementation, or for a later flow field.
5. **Export unit definitions to JSON** (effort S): the dictionaries are already JSON-shaped (`definitions/usa.gd`). Generate the JSON with a tool and keep the `.gd` as loader, or the reverse. No-regret only if traces stay identical.
6. **Rule for new sim code: keep positions as float pairs, add no new `Vector2` maths in hot paths** (effort 0). It avoids widening the float32 surface.

## Things to avoid now
- An engine-abstraction layer or "adapter" over Godot types. Blueprint §3.9 forbids generic frameworks; the vectors give portability without it.
- Rewriting storage to packed arrays or an ECS before the horde mode is designed (blueprint §11: "do not prebuild flow fields, threading or an ECS").
- Converting existing `Vector2` maths to float pairs now: it changes traces and every pin, for a port that may never happen.
- GDExtension/C++ (user decision, blueprint §11), and web threads (measured slower, `art-perf-levers.md` §4).
- Starting an engine evaluation before the art lab and the browser sim spike show the gap.

## Questions
Q1. Should we write down the simulation's number and ordering rules (float sizes, sqrt only, iteration order) as a short note now?
   a) Yes, now   b) Only when an engine change is on the table
   Recommendation: a, because it costs an hour and helps every lockstep review today. Why it matters: a port without it re-discovers each rule through a desync.
Q2. Should we commit small golden scenarios (commands in, per-tick checks out) that any engine could replay, like the relay's protocol vectors?
   a) Yes, three to five scenarios   b) One scenario   c) Not now
   Recommendation: a, because they double as regression tests. Why it matters: they are the only proof a new engine plays the same game.
Q3. Should the state digest stop using Godot's built-in dictionary hash, at the cost of re-pinning a few test values once?
   a) Yes, before more pins pile up   b) Later, only if we port   c) Never
   Recommendation: a, because only the Godot half blocks cross-engine checks. Why it matters: without it no trace can be compared across engines.
Q4. Should unit stats live in JSON files instead of GDScript dictionaries?
   a) Yes, generated from today's data   b) Keep GDScript
   Recommendation: a, if traces stay identical. Why it matters: data in JSON moves to any engine untouched.
Q5. How many enemies on screen should a horde mode aim for at its peak?
   a) About 1,000   b) About 2,000   c) About 5,000   d) Tens of thousands like They Are Billions
   Recommendation: b, because it is the plausible GDScript ceiling in the browser. Why it matters: it decides whether the mode needs an engine change.
Q6. Should a horde mode be single player only, or co-op with friends?
   a) Single player only   b) Co-op over the relay   c) Single player first, co-op later
   Recommendation: c, because lockstep co-op costs little bandwidth but caps hordes at the slowest friend's machine. Why it matters: co-op ties enemy count to every player's device.
Q7. Should horde enemies be simpler than normal units (no veterancy, no garrisons, one path toward the base)?
   a) Yes, simple horde enemies   b) Same units as skirmish
   Recommendation: a, because full units cost about 36 µs each on the Deck in the browser. Why it matters: it multiplies how many fit.
Q8. Before any engine decision, should we run a short spike with 2,000 simple enemies in the browser on the Deck?
   a) Yes, right after the browser sim spike   b) Only once the horde mode is planned   c) Skip it
   Recommendation: b, because the art lab and browser spike come first. Why it matters: it turns the 1,000-2,000 estimate into a measurement.
Q9. If the browser numbers prove unreachable, which change should we look at first?
   a) Rust simulation with Godot kept for drawing   b) Rust simulation with a web renderer   c) Bevy for everything   d) Accept fewer units
   Recommendation: a, because it keeps the renderer, UI and sound, which no other option does. Why it matters: it is the cheapest real speed-up. Note that it means a native extension, which you said you would rather avoid.
Q10. Should horde enemies be drawn with one shared mesh (fast) even if they then overlap other units' depth order slightly wrong?
   a) Yes, shared mesh for horde enemies   b) Same triangle array as all units
   Recommendation: a, if Q5 is b or higher. Why it matters: per-unit drawing calls become the cost at thousands.

## Not verified / gaps
- No numbers here were measured. Per-unit costs are ledger p95 divided by unit count; the multipliers are guesses.
- GamesBeat interview (403), the Game AI Pro flow-field chapter text, Bevy's API stability policy, Burst determinism and godot-rust web support: not read.
- The algorithm behind `Dictionary.hash()` and `AStarGrid2D` tie-breaking was not read in the Godot source.
