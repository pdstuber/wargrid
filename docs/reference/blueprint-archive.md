# Blueprint archive

Blueprint sections moved verbatim from the [blueprint](../blueprint.md) at commit `78a7c84` (2026-11-08), under their original headings; links adjusted for this folder. The blueprint keeps each heading with a link here.

## 5.7 Essential first test inventory (archived 2026-11-08)

**Build these tests as systems appear; keep them small and deterministic.**

#### M0 infrastructure

- [x] `test_repeatability` (C11): 1,000 direct simulation steps twice with nonempty orders → identical canonical state and expected final state.
- [x] `test_same_tick_replacement` / `test_canonical_pending_order` (C4/C10): commands at same tick have a defined stable execution order.
- [x] `test_atomic_rejection` (C5): commands from non-owners or invalid entity IDs do not change entity gameplay state.

#### Movement and pathfinding (M1 onward)

- [x] `test_world_to_screen_roundtrip`: world → isometric screen → world preserves ground position within chosen precision, including camera pan/zoom in input mapping.
- [x] `test_move_open_ground`: vehicle reaches valid destination.
- [x] `test_path_around_building`: blocked obstacle avoided without collision.
- [x] `test_unreachable_destination`: unit does not stall the simulation; emits appropriate blocked/idle behavior.
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

## 7.1 M0 implementation plan — stop before movement (archived 2026-11-08)

**Execution status:** M0 including follow-up test additions passed local and remote checks. See [verification evidence](m0-verification.md) and [README](../../README.md) for current state.

**Execution detail:** follow [M0 foundation implementation plan](../superpowers/plans/2026-11-01-m0-foundation.md) for exact method signatures, data shapes, concrete acceptance cases and verification order. This section defines milestone scope; the linked plan resolves its implementation details without adding M1 work.

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

## 9. Recommended repository organization (archived 2026-11-08) (tree)

Use Hell's Verdict's `game/` project boundary. Subdirectories below are a later-milestone outline; §7.1 defines the smaller M0 file set. Create folders only as their systems appear.

```text
wargrid/
  README.md
  AGENTS.md
  docs/
    blueprint.md
    development.md
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

## 10. First playable prototype design (archived 2026-11-08)

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

## 13. Kickoff prompt for Codex CLI / Claude Code (archived 2026-11-08)

Use the root `prompt.txt` (written when a milestone is kicked off; none is active now) in a new session in the Wargrid repository. It records the current milestone handoff and follows the [milestone prompt](../milestone-prompt.md); earlier handoffs live in `docs/m3-prompt.txt`, `docs/m4-prompt.txt`, `docs/m4.1-prompt.txt`, `docs/m5-prompt.txt`, `docs/m5.1-prompt.txt` and `docs/m6-prompt.txt`. The prompt limits work to one milestone, requires verification/review and preserves Git/window approval rules. Keep the current handoff prompt in that one file rather than maintaining a second copy here.

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

Do NOT bulk-translate EA C++ into GDScript; small cited ports follow the rule in AGENTS.md (historical prompt, updated 2026-11-03 after the GPL decision).
Do NOT fabricate movement speed, formation thresholds, exact timing, or
performance claims. Mark unknowns clearly.
Do not edit the live gameplay implementation in this research task.
```
