# Simulation core options (2026-11-09)

Research by an agent; evidence and a proposal, not decisions. Read-only: nothing run, nothing measured. **source** = read in the cited file or fetched page (quoted); **inferred** = the agent's reading or arithmetic. Builds on [engine portability and horde mode](engine-portability-and-horde-mode.md) (couplings, horde arithmetic, its Q1-Q10, still unanswered); not repeated here. `docs/reference/state-digest-research.md` does not exist yet (checked 2026-11-09), so the digest replacement is only referenced (no-regret step 5). Web pages fetched 2026-11-09.

User input (2026-11-09, late evening): Rust in Godot "sounds like the way forward". An own engine is out unless done for fun. The browser stays the main way to play (perf Q1, `docs/questions/next-perf-targets.md:16-19`); a reduced browser mode is only the fallback if measurements show the browser is too slow (§3).

## Starting point (source)

- Code today (`wc -l`): simulation 3,464 lines in 19 files (the portability note's 3,711 is older), net 654, presentation plus scene scripts 2,352, tests 14,039 in 55 files.
- Budget: sim tick p95 10 ms on Steam Deck Firefox, F = 5.5 (`performance.md:7-8`). Deck Firefox passes every row except hordes300, 14.54 ms for 400 fighting units (`performance.md:325, 329`). Native and WASM digests already match on 8 workloads (`performance.md:274`).
- The sim's outside surface is small. Presentation, net and scene scripts call about 15 methods: `snapshot` (21 call sites), `tick` (13), `match_over` (7), `step` (4), `issue_command` (3), then `spawn`, `map_data`, `preview_build`, `replace_blocked_cells`, `add_supply_source`, `combat_events`, `command_results`, `add_player`, `team_of` (`rg` over `game/scripts`). Lockstep only needs `advance(sim)` / `finish_tick(tick, state)` (`game/scripts/net/lockstep.gd:88, 111`).
- **The tests are not.** 19 of 55 test files read `sim._entities` (137 hits), plus `_buildings` (37), `_players` (7) and `_tick` (6) (`rg 'sim\._[a-z_]+' game/tests`). Those tests check GDScript internals, so they cannot check a native or repacked core without a rewrite.
- One determinism rule is already enforced: `tools/test_sim_math.py:5` bans `sin|cos|tan|atan|acos|asin|exp|log` in sim code. The "2 `sin` calls" in `art-perf-levers.md` §5 are not in today's code: `rg` finds only a comment (`locomotion.gd:33`).
- Godot types the sim depends on: `AStarGrid2D` (`grid_navigation.gd:5, 20-23`), `Vector2` (float32) / `Vector2i` (109 hits), a `Dictionary` per entity, `Dictionary.hash()` in the digest (`state_hash.gd:12`), and `RandomNumberGenerator` for start spots (`start_spots.gd:19`).

## 1. Options

### A) Stay in GDScript and optimise

- **What changes**: hot data moves into packed columns, flow fields for many units heading to one goal, and staggered lower update rates (`Horde.step` already staggers). Blueprint §11: measure first and do not "prebuild flow fields, threading or an ECS".
- **Effort (inferred)**: 1-3 person-weeks for a horde-only agent type next to today's units. 4-8 to move all entities to columns, which touches every system and most of the 137 test hits.
- **Risks**: the gains are guesses (2-4× from columns, 3× from staggering, portability note Q2). Static typing gave only 3-5 % (`performance.md`, Technology findings). Every storage change re-pins traces.
- **Unlocks (inferred)**: skirmish keeps passing. A horde mode of about 1,000-2,000 simple agents in the browser. 20,000 is out of reach.
- **Workflow cost**: none. **Reversible**: fully.

### B) Native simulation core as a GDExtension; Rust (godot-rust/gdext) preferred by the user

**Web support, the key criterion (source, godot-rust book `toolchain/export-web`):**
- Status, verbatim: "Web support in godot-rust is experimental and should be understood as such before proceeding." So it is **supported but experimental**, not unsupported.
- Toolchain: "Install a nightly build of `rustc`, the `wasm32-unknown-emscripten` target for `rustc`, and `rust-src`". Build with `cargo +nightly build -Zbuild-std --target wasm32-unknown-emscripten`. Link args include `-sSIDE_MODULE=2`: "The compiled Wasm binary is a _side module_ which is dynamically loaded by Godot's _main module_ at runtime."
- Required features: `experimental-wasm`, and "At the moment, you'll need to use `api-custom` to export to the web."
- Single-threaded builds need `experimental-wasm-nothreads` plus removing `-pthread` / `+atomics`. Our web build is no-threads (`game/export_presets.cfg:165, 237`), and threads were measured slower in Firefox (`art-perf-levers.md` §4).
- Since Rust 1.93, Wasm exception handling is on by default and needs `-Z emscripten-wasm-eh=false` (summary of the page, not quoted).
- Browsers: "GDExtension support for Firefox requires Godot 4.3+, and can be more limited compared to Chromium-based browsers" (quote truncated by the fetch). Firefox on the Deck is our budget device, so this must be measured first.
- Debugging: "Currently, the only option for Wasm debugging is the "C/C++ DevTools Support" extension for Chrome."
- Failure mode: "godot-rust cannot catch panics in Wasm yet due to limitations in the Rust compiler, so your game will abort."
- Emscripten version: "We recommend version **3.1.74** when targeting Godot 4.3 or later", and "Try using exactly the recommended emcc version in the guide." Godot's own web templates need "Emscripten 4.0.0+" (docs.godotengine.org, compiling_for_web). **inferred**: a side module must be built with an emcc that is compatible with the template's main module. The book's 3.1.74 against Godot's 4.0.0+ is an open mismatch for 4.7.2; unverified, test it first.

**Godot side (source, same for C++ and Rust):**
- Export: "If your project uses GDExtension, Extension Support needs to be enabled." And: "Note that GDExtensions still need to be specifically compiled for the web platform to work. Like thread support, enabling this feature requires the use of cross-origin isolation headers" (`Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp`) (exporting_for_web).
- Templates: "The default export templates do not include GDExtension support for performance and compatibility reasons"; build with `dlink_enabled=yes` (compiling_for_web).
- Emscripten on side modules: "This can add overhead, so for best performance static linking should still be preferred", and "By default, main modules disable dead code elimination" (emscripten.org, Dynamic-Linking).
- Repo state: presets have `extensions_support=false` (`game/export_presets.cfg:164, 236`). CI installs only `web_nothreads_release.zip` (`tools/install_export_templates.py:15-21`). The production `web/sws.toml` sends no COOP/COEP (`rg` empty). The test app proved the headers work, and the relay answers under COEP (`art-perf-levers.md` §4).

**Determinism, Rust against C++ (source, then inferred):**
- Rust RFC 3514: "Rust's floating point operations follow IEEE 754-2008 – with some caveats around operations producing NaNs". It names FMA as a transformation that strict guarantees preclude ("turning `a*b + c` into FMA operations"). And: "The most widely used targets (64bit x86 and 64bit ARM ...) are fully compliant." **inferred**: Rust does not fuse implicitly; `mul_add` is the only way to get an FMA, so native arm64, x86-64 and wasm agree with no flags.
- C++ defaults differ per compiler:
  - clang `-ffp-contract=on`: "enable C and C++ standard compliant fusion in the same statement" (clang Users Manual).
  - GCC: "The default is -ffp-contract=off for C in a standards compliant mode (-std=c11 or similar), -ffp-contract=fast otherwise" (GCC Optimize-Options).
  - MSVC 2022: "Floating-point contractions aren't generated by default under /fp:precise ... Previous compiler versions could generate contractions" (Microsoft Learn, /fp).
  - **inferred**: C++ needs `-ffp-contract=off` (or `-ffp-model=strict`) on every target, never fast-math, plus a CI digest check. Rust gets the same result by default.
- Both languages: "The relaxed SIMD instructions have nondeterministic results", and NaN bits are nondeterministic (WebAssembly `Nondeterminism.md`). So: no relaxed SIMD, never hash NaN bits, and keep today's no-trig rule (libm differs per platform). The float32 rounding at `Vector2` sites maps to explicit `f32` in Rust.
- Fixed-point (integers × 1024, as `core_check` already does, `state_hash.gd:16-34`) agrees by construction. But it re-pins every trace and changes ZH-derived values. Not needed if floats follow the rules above (**inferred**).

**Effort (inferred, person-weeks of agent work):**
- Toolchain, dlink templates in CI, COOP/COEP in production, four targets: 1-2 (C++), 2-3 (Rust, because of nightly and the emcc pin).
- Port with traces identical to GDScript: 4-8 (C++), 5-10 (Rust). The hard part is reproducing `AStarGrid2D` tie-breaking and the `Vector2` rounding. Calling Godot's `AStarGrid2D` through the binding keeps the tie-breaks but ties the core to Godot again.
- Rewriting the 19 test files that read internals: 1-2.
- Total about 6-12 (C++) or 8-15 (Rust).
- Kernel-only variant (`_nearest` or the horde step native, data still in Dictionaries): 1-3. Converting the data at the call boundary may eat most of the gain (not measured).

**Rest of B:**
- Risks:
  - The experimental Rust web path and its nightly churn.
  - More limited GDExtension support in Firefox.
  - A panic aborts the game.
  - Dlink overhead on the GDScript that stays.
  - COOP/COEP in production.
- Unlocks (inferred): compiled speed, roughly 10-50× GDScript per unit (never measured). That plausibly allows 10,000+ simple horde agents.
- Workflow: emsdk plus nightly Rust or three C++ toolchains in CI, longer release builds, Chrome-only wasm debugging. Lint and warnings do not cover the native code (Rust has `clippy`).
- Reversible: medium. Keep the GDScript sim as the reference until the golden vectors pass.
- Rust's own edge (inferred): a Rust sim is also a plain library, so tests, tools and a later wasm-only or relay-side use could run it without Godot. C++ via godot-cpp is the stabler web path today ("godot-cpp v10 can target Godot 4.3 or later"; its README does not mention web).

### C) Own engine: out of scope (user preference, "unless done for fun")

It would rebuild the renderer, HUD, audio, input, 10 export presets, packaging, the 491-case test runner and the profiler zones. Estimate 4-9 person-months to parity (**inferred**). wgpu's web WebGL2 backend is "Downlevel/Best Effort Support" (github.com/gfx-rs/wgpu). Not pursued.

### D) Another existing engine

See the portability note's table: Bevy is single-threaded on wasm and an XL rebuild. Defold (Lua) gains nothing. Unity web lacks determinism guarantees. Not pursued.

## 2. No-regret steps (ranked)

| # | Step | Effort | Improves today | Re-pin? |
|---|---|---|---|---|
| 1 | **Determinism rules note**: float32 at `Vector2` sites, float64 elsewhere, `sqrt` only (enforced, `tools/test_sim_math.py`), insertion order, xorshift, A* tie-breaks, plus the native rules (no implicit FMA, no fast-math, no relaxed SIMD, no NaN in state) | XS | Lockstep reviews; a written rule for new sim code | free |
| 2 | **Golden scenarios as conformance vectors**, like `protocol/vectors`: JSON commands in, `core_check` every N ticks plus a canonical final snapshot out, one GDScript runner | S | A regression net independent of internals; the spec a Rust core must pass | free (new pins only) |
| 3 | **Stable sim API written down**: commands in (`issue_command`), `step()`, snapshot/events out, the ~15 methods above; "outside code never reads `_` fields" (true today) | XS | Keeps the boundary from eroding during the art lab | free |
| 4 | **New tests use the public API**; migrate the 19 files opportunistically | 0 now, M total | Tests also survive option A's packed columns | free |
| 5 | **Engine-neutral digest** (pending state-digest research) | S-M | Cross-engine traces, no undocumented hash | **re-pin** `PINNED`, `FINAL_DIGEST`, relay value |
| 6 | **Golden A* vectors** | XS | Pins tie-breaking for a flow field or a port | free |
| 7 | **Probe: the dlink template plus a hello-world gdext side module on Deck Firefox** (boots? cost on today's Web Bench with nothing native in it?) | S | Settles the key criterion before any port | free; COOP/COEP on the test app only (already allowed) |
| 8 | Unit definitions to JSON (portability note prep 5) | S | Data portable to Rust | free if traces stay identical |

Avoid: an adapter layer over Godot types (blueprint §3.9), and converting `Vector2` maths now (re-pins everything).

## 3. Browser fallback if measurements say it is too slow (not a plan)

The browser stays the main target. If it proves too slow, the fallback would be: browser on the Low graphics preset only, plus per-match simulation reductions. Desktop would then carry the full experience.

**Possible triggers (inferred; thresholds are the user's call):**
- Sim: skirmish rows above 10 ms p95 on Deck Firefox (`performance.md:329`) after options A and B are both tried.
- Rendered: the art lab's High preset misses the 16.7 ms frame p95 on Deck Firefox, and Low only just passes.
- Rust: the gdext web probe (step 7) fails in Firefox, or its overhead cancels the native gain.

**Lockstep constraint (source + inferred):**
- Every client runs the full simulation and only commands travel (blueprint §11, Multiplayer). Simulation switches therefore cannot be per client.
- Any switch (unit cap, update rate for distant or idle units, horde size) must be a per-match setting chosen by the host, sent in the start state, and part of room compatibility. R1.1 matches rooms on "a hash of the simulation scripts and game data" (`docs/blueprint.md:630`); a per-match switch must also be in the match settings, or two clients run different games.
- Graphics quality can stay per client.

**What the fallback would change (inferred):**
- The budget device for full quality moves to desktop (the Deck native, 3.5-4.4 per `performance.md:7`).
- The benchmarks need a second row set: browser at Low with reduced sim.
- Release priority shifts to desktop. All playtesters use the browser today, so they would get the reduced game.

## 4. Recommended path (proposal; the user decides)

1. **Now, small doc/test tasks around the art lab** (no behaviour change): steps 1, 3, 6, then 2. Step 4 becomes a rule. Step 5 follows the state-digest research as its own task with one re-pin.
2. **Simulation performance spike** (already ordered after the art lab). Measure on Deck Firefox:
   - (a) the gdext web probe (step 7) first; it can rule out Rust on the web in a day;
   - (b) 2,000 horde agents in packed GDScript columns on one flow field, staggered;
   - (c) one kernel in Rust (gdext) against its GDScript twin, including the data hand-off;
   - (d) digests equal for native arm64, x86-64 and wasm on that kernel.
3. **Exit rule**:
   - Stay **A** if (b) fits 10 ms at the chosen horde target.
   - Go **B in Rust** if (a) passes in Firefox, (c) shows at least about 5× after the hand-off and (d) is equal.
   - Go **B in C++** if only the Rust web path fails.
   - Otherwise accept fewer units, or take the §3 fallback.
4. **C** stays out (user). Revisit only for fun.

## 5. Questions (RULES.md shape; the portability note's Q1-Q4 overlap steps 1, 2, 5 and 8, so answer those first)

Q1. Should we write down the simulation's public interface (commands in, snapshot and events out) as a short note now?
   a) Yes, now   b) Only if we port
   Recommendation: a, because it costs an hour and stops the boundary eroding. Why it matters: a Rust core plugs in exactly there.
Q2. Should new tests check the game only through that interface, not through internal fields?
   a) Yes, new tests only   b) Yes, and migrate old tests now   c) No rule
   Recommendation: a, because migrating 19 files now is churn. Why it matters: tests on internals cannot check a Rust core.
Q3. Should the first step of the simulation spike be a one-day check that a tiny Rust extension runs in Firefox on the Deck?
   a) Yes, first   b) After the GDScript measurements   c) Skip
   Recommendation: a, because godot-rust calls its web support "experimental" and Firefox "more limited". Why it matters: it can rule Rust in or out in a day.
Q4. If native code wins, Rust or C++?
   a) Rust (gdext)   b) C++ (godot-cpp)   c) Rust, with C++ only if Rust fails in the browser
   Recommendation: c, because Rust needs no float flags but has the experimental web path. Why it matters: it sets the toolchain for years.
Q5. How big a speed-up must Rust show before we accept its build cost?
   a) 3×   b) 5×   c) 10×
   Recommendation: b, because nightly Rust plus emsdk in CI costs weeks. Why it matters: it is the spike's pass line.
Q6. Would you accept the live web game sending cross-origin isolation headers (required for any extension in the browser)?
   a) Yes, if native wins   b) Test app only, always
   Recommendation: a, because the test app already booted and reached the relay with them. Why it matters: without them no Rust core ships in the browser.
Q7. Port the whole simulation or only the hottest loops first?
   a) Whole sim   b) Hot loops first   c) Decide after the spike
   Recommendation: c, because the data hand-off cost decides it. Why it matters: hot loops alone may gain little.
Q8. During a port, should the GDScript simulation stay as the reference until golden scenarios match?
   a) Yes   b) No, replace it directly
   Recommendation: a, because it keeps the change reversible. Why it matters: it is the only rollback.
Q9. Should the simulation switch to whole numbers (fixed-point) so every platform agrees by construction?
   a) No, floats with written rules   b) Yes, before a port   c) Only for a horde mode
   Recommendation: a, because it re-pins every trace and changes tuned values. Why it matters: floats need rules and a CI check instead.
Q10. If the browser proves too slow, which number should trigger the fallback?
   a) Skirmish sim p95 over 10 ms on Deck Firefox after the spike's fixes   b) Frame p95 over 16.7 ms at Low   c) Either one
   Recommendation: c, because players feel both. Why it matters: it makes the fallback a measured call, not a mood.
Q11. In that fallback, should the browser offer only Low graphics?
   a) Yes, Low only   b) Low by default, High allowed with a warning
   Recommendation: b, because fast laptops in browsers can run High. Why it matters: graphics are per player, so this costs no compatibility.
Q12. In that fallback, should the host be able to pick a lower unit cap per match?
   a) Yes   b) No
   Recommendation: a, because it is the simplest switch and the same for every player. Why it matters: a sim switch must be identical on every client.
Q13. In that fallback, should the host be able to make far-away or idle units update less often?
   a) Yes, per match   b) No, always full rate
   Recommendation: b until measured, because it changes fights and needs its own feel test. Why it matters: it is a simulation change, so everyone gets it.
Q14. Should such per-match switches become part of the room compatibility check?
   a) Yes, rooms only match the same switches   b) The host's choice simply applies to everyone who joins
   Recommendation: b, because the host's settings travel in the start state; only the code fingerprint (R1.1) gates rooms. Why it matters: either way, no two clients may run different rules.
Q15. Should golden scenarios include a horde-style one from the start?
   a) Yes   b) Only when a horde mode is planned
   Recommendation: b, because horde agents do not exist yet. Why it matters: vectors should pin real behaviour.

## Not verified / gaps

- Nothing measured: the native speed-up, the dlink overhead, the hand-off cost and gdext in Deck Firefox are unknown.
- The emcc version a gdext side module needs for Godot 4.7.2 templates (book 3.1.74, Godot 4.0.0+) is not resolved.
- Not read in Godot source: whether the GDScript VM ever fuses multiply-add; `AStarGrid2D` tie-breaking; the `Dictionary.hash()` algorithm. Whether Rust's LLVM backend never emits FMA without `mul_add` is inferred from RFC 3514, not from a codegen test.
- Whether the no-threads dlink template truly needs SharedArrayBuffer, or the docs require isolation only by policy: not checked.
- Effort ranges are judgement.
