# Native simulation core spike: report

Written 2026-11-10 by T12 of the [plan](../superpowers/plans/2026-11-10-native-sim-spike.md), spec in the [handoff](../native-sim-spike-prompt.txt). Branch `spike-native-sim`, base `main` dde868e. Labels: **measured** (a row in the [verification file](native-sim-spike-verification.md)), **source** (quoted file or fetched page), **inferred** (arithmetic or reasoning on measured rows), **unverified**. Every derived number in section 1 is worked out in the verification file under "T12 rows (decision-rule arithmetic)". Other notes: [boundary](native-sim-spike-boundary.md), [horde slice](native-sim-spike-slice-horde.md), [movement slice](native-sim-spike-slice-move.md), [candidates](native-sim-spike-candidates.md).

> **Later evidence (2026-11-11), this report is not rewritten:** "hot loops are a dead end" below was measured with per-unit Dictionary storage, where copying state out cost 60-73 % of a slice. With the state in packed arrays a Rust kernel reached E 34-58 at a hand-off of 0.1-0.4 %, digests equal natively and in Firefox, on a horde workload ([performance next](performance-next.md), section 5.4). The whole-port verdict therefore holds for today's storage only.

## 1. Recommendation

**Outcome: CONDITIONAL GO, whole-port branch only.** Hot loops are a dead end: the incremental gain G_inc stays near 1.09 against a need of 2.20-2.26, and even all flat-buffer candidates with infinitely fast native code stop at 2.14 under the measured template tax. Only the whole-port projection G_port reaches the line: **3.3-4.6 (estimate)**, a margin of about 1.5-2×, and only if the presentation hand-off uses packed columns and the GDScript read side of those columns stays cheap (unmeasured; if it costs as much per entity as today's `snapshot()`, G_port is 1.34 and fails). Per the decision rule, the next step is the golden scenarios, not more Rust. Nothing in this spike moves the game off GDScript.

Gate: passed. The extension loaded and ran in Firefox 159 on the Steam Deck: probe ×3, native runs ×3 per row, digests equal to the Mac's (measured, T11). Stage 5 rows: green apart from Windows, which is unverified (needs CI, so a push).

### Decision-rule table (Deck Firefox 159, gate device; hordes300, sums over 1800 sampled ticks, medians of three interleaved runs)

| Ratio | horde | move | both slices | Mac Firefox 160 (not the gate) | Label |
|---|---|---|---|---|---|
| K language gain (lower .. upper) | 27.7 .. 69.5; per-run kernel spread 12 %, lower end 25.3-28.4 | 87.8 .. 193.1; kernel spread 17 %, lower end 81-97 | 44.5 .. 104.1 | horde 19.8 .. 51.6, move 117 .. 250, both 37.8 .. 88.2 | inferred from measured sums (T11, T10) |
| H hand-off per tick | 1.37 ms, 4.66 µs and 46 B in / 0.5 B out per entity, 64 % of `gd` | 1.71 ms, 6.96 µs, 133 B / 45 B per entity, 73 % | 3.09 ms, 5.7 µs per entity, 69 % | 0.86 ms per tick, 1.58 µs per entity, 67 % | inferred from measured sums |
| E effective gain | 1.54 | 1.35 | 1.43 | 1.52 / 1.42 / 1.46 | inferred from measured sums |
| T template tax (W2/W1 - 1), p50 / p95 | | | +6.9 % / +6.0 % (A/A 1.6 / 1.2 %) | +9.9 % / +8.8 % | measured (T8, T10) |
| s share of tick | 0.189 | 0.204 | 0.397 | 0.409 (Mac profile on `main`: 0.407) | measured |
| Q need (W1 hordes300 p95 / 10 ms) | | | 14.64 / 10 = **1.46** (T8) to 15.04 / 10 = 1.50 (T11), so Q × 1.5 = **2.20-2.26** | (not the gate) | measured (T8, T11, two sessions) |
| G_inc = 1 / ((1+T)(1-s) + s/E) | 1.02 | 1.01 | **1.09** (p95 tax 0.060; 1.08 at the p50 tax 0.069), ceiling 1.56 | 1.08, ceiling 1.56 | estimate (inferred) |
| G_inc at s = 0.559 (all flat-buffer candidates incl. target grid and scan) | | | 1.17 at E = 1.43; ceiling **2.14** | | estimate; s from the Mac profile |
| **G_port, packed hand-off plus GDScript read side at the per-entity H** (p = 0.18-0.26) | | | **4.6-3.3** (K 27.7) / 4.9-3.5 (K 44.5) | | estimate, headline; read side unmeasured |
| G_port, packed, read side as costly per entity as today's `snapshot()` (p = 0.71) | | | **1.34**, below the line | | estimate, downside |
| G_port, packed, Rust write only, charged in full (p = 0.017) | | | 18.9 (K 27.7) / 25.6 (K 44.5) / 38.1 (K 104) | 16.6 / 27.5 (K 19.8 / 37.8) | estimate, upper bound: no read side, and the probe omits 7 of 16 fields |
| G_port, packed, only the cost beyond today's `snapshot()` (p clamped to 0) | | | = K: 27.7 / 44.5 / 104 | = K | estimate; the raw p is negative (0.19 ms against today's 7.9 ms) and is clamped to 0; holds only if the read side costs no more than today's snapshot |
| G_port, Dictionary-shaped hand-off, in full (p = 2.86) | | | **0.35** | 0.29 | estimate |
| G_port, Dictionary-shaped, beyond today's snapshot (p = 2.16) | | | **0.45** | 0.37 | estimate |

p is the presentation hand-off per tick as a fraction of the hordes300 mean tick on Deck Firefox (11.32 ms, extension template, native path off): p = (Rust writing the packed probe, 0.189 ms + 400 entities × GDScript read cost per entity) / 11.32 ms. The headline takes the read cost equal to the measured per-entity hand-off H (4.66-6.96 µs, horde to move); the downside takes it equal to today's `snapshot()` per entity (7.89 ms / 400 = 19.7 µs).

How to read the table:
- K is huge because the kernel itself is tiny: 56 ms (horde) and 22 ms (move) of about 4 s of GDScript work over 1800 ticks (measured). The cost sits in getting data out of the Dictionaries: packing alone is 60-73 % of the GDScript slice time on every host and browser (measured, T10 and T11). The hand-off cost H decides the question, as the Stage 1 hypothesis expected.
- Floors (inferred): each slice is a net gain on the Deck, but only barely. The test is s(1 - 1/E) against T(1 - s): horde 0.067 > 0.049, move 0.053 > 0.048, and at the p50 tax (T = 0.069) move fails it, 0.053 < 0.055. Together, 0.119 > 0.036, because the tax is paid once.
- Measured whole tick, which outranks the projection. Deck Firefox hordes300 p95: today's template (W1) 15.04 ms; extension template with the native path off 16.16 ms; both slices native 14.42 ms. That is 1.04× against W1 and 1.12× against off, beyond the A/A spread of 0.5-3.1 %. **14.42 ms is still 1.44× the 10 ms budget: EXCEEDED.** Mac desktop release p95: 2.32 → 2.05 ms (-12 %). Mac Firefox: 4.48 → 4.04 ms (-10 %) (measured).
- K from two slices stands in for the whole simulation. This is the weakest assumption in the rule. The headline uses the lowest lower end (horde, 27.7); the slices spread 27.7 to 87.8 at the lower end. A second assumption sits under it: G_port lets the whole tick gain K, but work that is already compiled (`AStarGrid2D` path search in `grid_navigation.gd`, engine built-ins) gains about 1, so G_port is capped at 1 / that share. Its share on hordes300 is unverified (no profile zone for it).
- Joint pass condition for the whole port (inferred): G_port ≥ 2.20 means **1/K_lower + p ≤ 0.455** (≤ 0.442 for 2.26). At K 27.7 that allows p up to 0.42 (4.7 ms of hand-off per tick); at the headline's p = 0.26 it needs K ≥ 5.2. K and p cannot both sit at a loose limit: K 4 with p 0.42 gives 1.49 and fails.
- What the packed probe leaves out: (a) the GDScript drawing code would have to read packed columns instead of today's Dictionaries, and that read side is unmeasured; (b) the packed variant carries 10 columns covering 9 of the 16 real snapshot keys (`PROBE keys real=...`, T11 probe log). It drops `order` and `combat` (both Dictionaries), `destination`, `heading`, `max_hp`, `construction_id` and `collection`, and stores `status` and `kind` as u8 instead of String (`native/godot/src/probe.rs` `snapshot_packed`). So "packed costs 2.4 % of today's `snapshot()`" compares different payloads; the headline p adds a read cost per entity to make up for part of that.
- The probe's 400 entities carry 60-point routes, so its `snapshot()` (7.9 ms per call on the Deck) may be heavier than the hordes300 average. On the Mac profile, `snapshot` is 49.5 % of `step` (inferred; it changes p only in the "beyond today's snapshot" column and the downside row).

### The rest of section 1

- **Simulation language:** Rust (decided; nothing here argues against it). **Adapter:** Rust gdext 0.5.5. **C ABI:** not warranted now. The standalone runner and a possible Rust frontend use the crate directly. A C ABI is worth building only for a non-Rust caller, such as the godot-cpp fallback (B) or a C++ frontend.
- **Blockers:** none hard. **The template tax alone breaks a passing row:** on Deck Firefox the dlink template with no extension pushes `combat_open` p95 from 9.76 to 10.34 ms, over the 10 ms budget (EXCEEDED), and `combat_dense` from 9.24 to 9.88 ms (measured, T8, W2 against W1). So shipping any native build turns `combat_open` from passing into EXCEEDED before a single slice runs, and a slice or port must first win back about 6 % on every row. Other costs that last: a Rust panic aborts the whole page in Firefox, Safari and Vivaldi (measured), so the core must return errors and never panic. Web builds need the pinned `nightly-2026-03-15` (the `-Z emscripten-wasm-eh=false` flag), and Godot PR 124118 will move that pin on an engine upgrade (source). Besides the +6-7 % tick time, the dlink template adds +16 % export size for the whole game, used or not (measured). A native extension cannot load from a downloaded pack, so every core change needs a desktop shell update (source, handoff). The first-import crash did not reproduce in any spike tree, but `place` and exports keep the double import (measured).
- **Performance case:** none for hot loops. A whole port is plausible on paper (G_port 3.3-4.6, estimate; below the line if the presentation read side exceeds about 4.7 ms per tick) but rests on two-slice K and an unmeasured presentation read side. **Portability case**, stated separately: it has value. `wargrid_core` has no dependencies (`cargo tree`), builds and passes 24 tests in a Linux container with no Godot, and its runner replays recorded GDScript fixtures bit for bit on macOS arm64, Linux x86-64 (container) and the Deck (measured). That does not rescue the performance case.
- **Lockstep rule the recommendation relies on:** every client runs the native core, so only native and WASM builds must agree. They agree on every platform measured: Mac arm64, Linux x86-64 container, Deck x86-64, WASM in Firefox on the Mac and the Deck. Keeping GDScript in some builds would promise GDScript and Rust bit-identical for good, a much heavier promise. The spike shows it is possible for these two slices (shadow mode, 0 mismatches), not that it is cheap to keep.
- **Next action:** the golden scenarios with the engine-independent digest (approved plan [2026-11-09-state-digest-golden-scenarios](../superpowers/plans/2026-11-09-state-digest-golden-scenarios.md), unplaced), and next to them the packed-column GDScript experiment ([sim-core-options](sim-core-options.md) §4.2 b). **That comparison is still missing, so this report cannot say "GDScript is enough".** Packing being 60-73 % of the GDScript slice suggests GDScript's own cost is mostly Dictionary access, which a packed GDScript layout also attacks (inferred).
- **Open items, each with the check that closes it and its pass value:**
  1. §4.2 b packed GDScript columns, on Deck Firefox. If they reach a gain of 2.20 on hordes300, stay on GDScript (sim-core-options §4.3 "Stay A") and the whole port is off.
  2. Presentation read side: drawing from packed columns with all 16 snapshot fields, on Deck Firefox, gives p.
  3. K beyond these two slices, for a later ported piece of `Combat.plan` bookkeeping (about 25 % of the tick, no kernel shape), gives K_lower. Items 2 and 3 share one pass condition: **1/K_lower + p ≤ 0.455** (0.442 for 2.26), with K_lower the lowest lower end over all ported slices. The share of already-compiled work (path search) caps the result at 1 / that share and is measured with item 2.
  4. Windows replay `REPLAY OK` in CI (needs a push).
  5. Safari and Vivaldi three-run sets. They are single runs now, though consistent with Firefox. Pass: in each, both slices native beat `off` on hordes300 p95 by more than that browser's A/A spread, and the digests equal Firefox's.
  6. Production hosting serving `index.side.wasm` and `wargrid_native.wasm` (fly, not checked; a deploy needs approval). Pass: a W3 export served by the production configuration loads in Deck Firefox and prints `PROBE echo ok=true` with no page error.
- **Evidence that would change this:**
  - A pair (s, E) that solves 1/((1+T)(1-s) + s/E) = 2.20. Only this reopens hot loops; with E as measured (1.35-1.54) it cannot. At T = 0: s 0.56 needs E ≥ 41, s 0.70 needs E ≥ 4.5, s 0.80 needs E ≥ 3.1. At the measured T = 0.060: s 0.56 is impossible, s 0.70 needs E ≥ 5.1, s 0.80 needs E ≥ 3.3 (inferred).
  - 1/K_lower + p above 0.455 (a presentation read side above about 4.7 ms per tick at K 27.7, or a further slice with K_lower below 5.2 at p 0.26), or packed GDScript reaching 2.20. Any of these closes the whole port.
  - Already-compiled work (path search) above about 45 % of the hordes300 tick, which caps G_port below 2.20.

### Re-evaluate later (after the movement and avoidance milestones)

1. `sh tools/run_profile.sh` on the new tree gives s. The Mac and Deck shares agreed here (0.407 against 0.397, measured).
2. Deck Firefox W1 on hordes300, three runs (the ledger's [target factor how-to](performance.md#target-factor-measurement-2026-11-06)), gives Q. `bench_runner.gd` on `main` has no hordes300 and no `only=`. Those come from this branch (`game/benchmarks/bench_runner.gd`), so carry that change over or re-run from this branch's tools.
3. Recompute G_inc and G_port with this table's K, H, E and T. Which of them need a new measurement:
   - T: on any Godot or template upgrade.
   - H and E: when the per-entity fields grow. Avoidance adds velocities and neighbours, more bytes per entity. The movement milestone rewrites `_advance`, so the move slice's E dies with it; its per-entity H is the part that transfers.
   - p: when `snapshot()` grows (avoidance, fog).
   - K: a property of language and algorithm. It stays unless the algorithm changes; it would have to be re-measured against packed GDScript if §4.2 b lands.

### Mapping onto sim-core-options §4.3

| §4.3 item | Result |
|---|---|
| (a) gdext web probe passes in Firefox | passed on the Deck (measured) |
| (b) packed GDScript columns | not run, so "Stay A" cannot be decided |
| (c) about 5x after the hand-off | E 1.35-1.54: fails for slices (measured) |
| (d) digests equal on arm64, x86-64 and wasm | equal (measured; Windows unverified) |

"Go B in Rust" is not met on slice evidence. "Go B in C++" does not apply, because Rust works in every browser tried. So the open choice is A (pending b) against a whole port gated by the golden scenarios. The §3 browser fallback is not triggered yet.

## 2. Current architecture

| Piece | Where (source) | Role for a port |
|---|---|---|
| Tick | `simulation.gd` `step()` :504 runs, in order: apply orders, `Combat.plan` (`combat.gd:93`), rates, construction, `Production.step`, supply, service paths, the movement loop (`_advance` :602 with `Locomotion.step`, `locomotion.gd:3`), `Containers.step`, `Horde.step` (`horde.gd:15`), `Salvage.step`, fire | the slices are two of these; the spike hooks them at :552-558 behind `static var native` |
| State | `simulation.gd:32` `_entities`: one Dictionary per entity, insertion-ordered | the hand-off cost: packing reads these |
| Paths | `grid_navigation.gd:5` `AStarGrid2D` (already compiled) | paths are inputs to any slice |
| Digest | `state_hash.gd:10` `StateHash.digest`: `Dictionary.hash()` plus the engine-neutral `core_check` | two Godot runs can compare; no other language can reproduce it |
| State out | `snapshot()` :631, read by `world_view.gd`, `skirmish_main.gd`, `online_main.gd` (lockstep checks) | presentation hand-off (the p term) |
| Events out | `combat_events()`, `command_results()` to `SoundDirector`/`SoundPlayer`/`VisualDirector` `collect_step` (`sound_director.gd:32`, `sound_player.gd:48`) | must become an event stream in a whole port |
| Interface | [sim interface](sim-interface.md); tests use only it (`tools/test_sim_boundary.py`) | the spec a whole port meets |

Already engine-neutral (source, [engine portability note](engine-portability-and-horde-mode.md#what-couples-the-simulation-to-godot-today)): no nodes, signals, `Time` or `OS` in `game/scripts/simulation/`; in-tick xorshift RNG; `sqrt` only, no trig; JSON wire format, maps and traces. Still coupled (source, [determinism rules](determinism-rules.md#couplings-a-port-must-reproduce)): `Dictionary.hash()` in the digest, `AStarGrid2D` tie-breaks, float32 at `Vector2` sites against float64 floats, Dictionary insertion order, `RandomNumberGenerator` for start spots, and definitions as GDScript constants, passed to the core as table buffers here (measured, slice notes).

## 3. Decision matrix

| Axis | Baseline GDScript | A gdext + Rust core (built) | B godot-cpp + C ABI + Rust core | C godot-cpp + C++ core | D GDScript + native helpers |
|---|---|---|---|---|---|
| Browser performance | Deck Firefox hordes300 p95 15.04 ms, EXCEEDED (measured) | slices: whole tick ×1.04 against W1, E 1.35-1.54 (measured); whole port 3.3-4.6, downside 1.34 (estimate) | same core speed as A plus one call layer (inferred) | same as A for the same layout (handoff rule; unverified) | worst: per-call hand-off with no batching; A's slices are already batched helpers and reach E 1.4 (inferred from measured E) |
| Native and web compatibility | ships everywhere (measured, CI) | Firefox, Safari, Vivaldi on the Mac, Firefox on the Deck, macOS desktop (measured); Linux: core and runner only (measured), Godot loading the gdext `.so` unverified; Windows unverified; dlink template needed | godot-cpp README silent on web (source); unverified | unverified | as A or C |
| Determinism | native and web digests equal (source, earlier spikes) | equal to GDScript bit for bit on both slices; arm64, x86-64, wasm (measured) | as A for the core (inferred) | FMA contraction needs `-ffp-contract=off` (source, determinism rules; unverified) | mixed float32/float64 seams per helper (inferred) |
| Safety | memory safe | safe Rust; a panic aborts the page (measured) | unsafe FFI seam (inferred) | no memory safety (inferred) | per language |
| Effort | 0 | each slice ported, tested and replayed inside its 150-180 min time box (measured, T5/T6); a whole port is L (inferred) | A plus a C++ adapter (inferred) | rewrite in C++ (inferred) | small per function (inferred) |
| Maintenance | none | nightly pin, emsdk pin, double import, template +6-7 % (pushes `combat_open` over budget) and +16 % size (measured) | two toolchains (inferred) | SCons + emsdk (inferred) | as A, with logic split across two languages (inferred) |
| Portability | Godot only | core crate with no dependencies, Godot-free runner (measured) | C ABI: any language (inferred) | C++ callers only (inferred) | none |

Zig or others: one paragraph in the [candidates note](native-sim-spike-candidates.md); nothing built.

## 4. Evidence

All rows, commands and raw-log paths are in the [verification file](native-sim-spike-verification.md) (T2-T11 rows; this report's arithmetic under "T12 rows").
- **Revisions:** base dde868e. Task trees were cherry-picked onto `spike-native-sim`. Measured builds: W1 and W2 from 1d43859 (T8); W3 from e2693e7 plus the T9 fixes (T10, T11); macOS Bench and Mac exports from 1eb8f89 (T10); W1 from 1eb8f89 (T11).
- **Toolchains (measured):** Godot 4.7.2.stable.official ed1daf0bf, template `web_dlink_nothreads_release` (its banner: Emscripten 4.0.20). gdext `=0.5.5` with `api-4-7`, plus `experimental-wasm`, `experimental-wasm-nothreads` and `lazy-function-tables` for the web. Rust `nightly-2026-03-15` (1.96.0-nightly 03749d625) with `-Zbuild-std`, target `wasm32-unknown-emscripten`; clippy from stable 1.99.1. Emscripten 3.1.74 main, 4.0.20 as the comparison (same results). Linux container `rust:1.94-slim` (1.94.1).
- **Commands:** `sh native/tools/build.sh <mac|web|linux|all|place|remove>`, `sh native/tools/export_tree.sh <W1|W2|W3|R1|R2>`, `sh native/tools/web_run.sh <mac|deck> <browser> <export> '<query>' <label>`, and `native/target/release/wargrid_runner <replay|bench> <fixture>`. Options are in the plan's "Conventions".
- **Raw results:** `~/projects/wargrid-native-work/results/` (`t8-*`, `t10-*`, `t11-*`, `mac/desktop/`), logs in `logs/`, fixtures in `fixtures/`.
- **Builds that failed:** stub replay `REPLAY ERROR ... not implemented` (intended, T2). Unquoted `&` in the Deck query (fixed, T11). The rendered completion line was not accepted (fixed, T8). Two deliberate mutations were caught: the float32 divisor and the horde `rubbed` flag (T5, T6).
- **Stage 5 rows (measured, all green):**
  1. Shadow mode on all 8 rows: 16 `SLICE` lines, mismatch none.
  2. Native repeated ×3: digests equal.
  3. Replay OK on Mac arm64, Linux x86-64 container and the Deck.
  4. WASM digests equal to native in Mac Firefox (T9) and Deck Firefox (T11).
  5. Suite 737 cases, 139,594 checks, 0 failures with the native path off; netplay `match` passed; suite with the extension placed and required: 139,639 checks, 0 failures.
- **Platform coverage:**

| Platform | Replay | Digests | Timing |
|---|---|---|---|
| macOS arm64 | OK | OK | 3 runs |
| Linux x86-64 container | OK | not run | none |
| Deck x86-64 native | OK | not run | none |
| Mac Firefox | n/a | OK | 3 runs |
| Mac Safari, Vivaldi | n/a | probe-level only | 1 run each |
| Deck Firefox | n/a | OK | 3 runs |
| Windows | **unverified** | **unverified** | **unverified** |

  `compare_local_traces.sh` was not run (needs a CI run id).
- **Snapshot probe** (400 entities × 300, Deck Firefox, measured): `snapshot()` 2,353-2,376 ms, Rust → `Array[Dictionary]` 9,497-9,872 ms, Rust → packed columns 55.5-57.7 ms. Dictionaries built from Rust cost about 4× today's whole snapshot; packed columns cost about 2.4 % of it, but carry only 9 of its 16 fields and no GDScript read side (section 1).
- **Memory growth:** a 256 MB allocation inside the extension while GDScript holds a packed array: the held array stays valid (heap 260 → 320 MB, Deck). **Build times (Mac):** clean 7 s mac and 13 s web; incremental under 1 s and 1 s (measured, T10).
- **Rendered (report-only):** R2 against R1 on the Deck, ashfall: +7 to +16 % tick and frame. The horde frame tail is bimodal, not a template effect. On the Mac R2 is within the R1 spread (measured, T8, T10).
- **Observation outside the spike (inferred from T8/T9 rows):** the `team` row now runs to the 45,000-tick cap (`team_match.gd:8`). The 2026-11-06 row ended at tick 20425, and Deck W1 `team` p95 is 11.44 ms, above 10. It is not comparable with the earlier ledger row; the cause was not investigated.

## 5. Boundary sketch and the standalone example

The [boundary note](native-sim-spike-boundary.md) has the built contract. GDScript owns the entities; every tick it packs structure-of-arrays buffers (buffer 0 = ids, ascending), the core validates before any work, and a rejected input yields no output and a GDScript fallback for that tick. Ids are never reused. Outputs are allocated by Rust and owned by Godot; nothing is held across a call, so WASM memory growth is safe (measured). It also sketches how the shape grows into the whole-simulation contract: `init`, tick-stamped `submit`, `advance`, events / presentation state / canonical state kept apart, and the four formats kept separate (in-process, wire, trace, presentation snapshot). Avoidance state becomes more core-owned columns, not a new boundary. The slice notes fix the buffer layouts and the number audits: no float32 site in the horde slice, float32 rounding at the `Vector2` sites in movement, including `Vector2::operator/(real_t)` narrowing the divisor (measured by mutation).

The standalone example is `native/runner` (`wargrid_runner replay|bench`). It depends only on `wargrid_core`, reads the documented fixture format and replays GDScript's recorded outputs bit for bit. It is the one required non-Godot caller.

## 6. Migration recommendation (not implemented)

1. Golden scenarios plus the engine-independent digest, through the public interface (the approved plan). These are the oracle any whole port must pass; they re-pin once.
2. §4.2 b packed GDScript columns on Deck Firefox. This decides "Stay A" against a whole port.
3. Only if 2 falls short of 2.20 and the joint check passes (1/K_lower + p ≤ 0.455, open items 2-3): plan a whole port in Rust behind the sketched contract, with tests already on the public interface. GDScript stays the reference until the golden scenarios match.
   - Stays in GDScript: rendering, HUD, audio, input, net glue, and the drawing code reading packed columns.
   - Rollback: the hook is one null check per slice, and the extension is absent by default.
4. Where it fits in blueprint §7: after the movement and avoidance milestones, which change the slices, H and p anyway. Re-run the "re-evaluate later" recipe after each.
5. Engine upgrade: the gdext `api-4-x` feature, the `=0.5.5` pin, the Rust nightly (PR 124118 changes exception handling) and the Emscripten pin all move together, so re-run the web probe on every Godot minor release.
6. Follow-up: evaluate Permafrost Engine's chunk flow fields for pathing (deferred by the user 2026-11-10; [design answers](design-answers-2026-11-08.md), "Movement and pathing").

## 7. Another frontend later

What a frontend could reuse unchanged (measured that it runs without Godot): `wargrid_core` (rules, buffers, fixture format) and the runner pattern. Godot would still own rendering, HUD, audio, input, export and the editor tools. A Rust frontend (wgpu was named) would link the crate directly; a C ABI would only serve a non-Rust frontend. No engine design here.

## 8. Working tree

- **Changed paths** (`git diff --stat main...spike-native-sim`, 47 files):
  - `native/` (core, adapter, runner, tools, toolchain files);
  - `game/scripts/native/native_bridge.gd` and `game/scripts/simulation/native_{horde,move}.gd`;
  - the two hook lines in `simulation.gd`;
  - `game/benchmarks/{bench_runner,native_fixture,native_probe}.gd`;
  - `game/tests/test_native_{horde,move}.gd`, `run_tests.gd`, `test_map.gd` (preset count 11 → 13);
  - two appended presets in `game/export_presets.cfg`, `tools/serve_web_bench.py`, `.gitignore`;
  - the spike notes, and one ledger row in `performance.md`.
- **Build, run, remove:** `sh native/tools/build.sh mac` (or `web`, `linux`, `all`), then `sh native/tools/build.sh place`, then the runner with `-- native=<off|shadow|native|pass> slices=horde,move timing=1 only=<row>`. To remove: `sh native/tools/build.sh remove`. Deleting the branch removes the spike; `main` is untouched.
- **Checks run, with their tree** (verification file): T9 on `spike-native-sim` e2693e7 plus fixes ran the suite, netplay, lint, warnings, cargo test and clippy. T2-T7 ran in their task trees.
- **Failure caused by this branch, fixed:** `test_map.gd` preset count. T3's two appended presets (1d43859) broke it; T9 updated the count 11 → 13 (the new presets pass the NOTICE and CREDITS checks).
- **Checks not performed:** Windows; `compare_local_traces.sh`; the Safari and Vivaldi A/A spread; production hosting; source-level browser debugging of the side module; §4.2 b; the presentation read side of packed columns.
- **Not changed:** existing presets, CI, `web/`, production hosting; no push, PR or deploy.
