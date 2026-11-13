# hordes300 step.combat_fire spike (5.4 ms at tick 776)

Status: evidence only, measured 2026-11-13 night (Tighter gates night run, backup 2); the fix is placed in the Flatter worst ticks package (user, 2026-11-13, [packages](../packages.md#package-notes)). Diffs, drivers and logs stay outside the repository in `~/projects/wargrid-overnight-work/tighter-gates/` (below: `logs/` means that folder's `logs/`).

Revision: `main` 4bd8711 (scratch worktree, since removed). Host load 1.6-2.5 during the timing runs, 3.08 at the end of the suite run; one run each, so treat ms values as +-10 %.

## Cause

One death fans out into N single-unit move orders, and each order rescans every entity twice over.

- `Simulation.remove_object` erases the dead unit, then calls `Combat.object_removed` (simulation.gd:772-781).
- `Combat.object_removed` loops all entities; every unit in mode `retaliate` whose `target_id` was the dead unit calls `_go_home` (combat.gd:576-583), which calls `sim._assign_move([unit], unit.combat.goal)` (combat.gd:638-643). Confirmed: at tick 776, 1 death, 2 shots, `_allocation_calls` delta 20.
- Each `_assign_move` call runs `_unavailable_cells` (simulation.gd:318-331): full scan of ~396 entities into a dict, then an array (4.1 ms total, 0.2 ms per call).
- Then `Allocation.assign` turns that ~400-cell array back into a dict (destination_allocation.gd:20-22) before looking at a handful of cells near the goal. This is most of the 0.93 ms `allocation.assign`; the facts file missed it.
- The calls really differ: each call leaves out its own unit's position, and each call's new destination counts for the next one. A cross-check during the probe saw the set change between consecutive calls in the same batch 109 times on hordes300 (90 on contact, 20 on skirmish3v3). So a plain per-tick memo of `_unavailable_cells` would change behaviour. Batching the 20 calls into one `_assign_move` is not possible either: each unit has its own home goal.

## Fix tried (probe, exact)

The set is "cells where (ground positions not in members) + (all ground destinations) > 0". The probe keeps that as a refcount map `cell -> count`. It is built once, on the first retaliator inside `object_removed`, and kept current through the loop:
- before each allocation, subtract the members' positions; add them back after;
- swap the members' old destination count for the new one;
- `_stop_unit` on attack-mode units in the same loop subtracts their destination.

`Allocation.assign_excluding` takes the map directly (it only calls `has`), so the array-to-dict round trip goes away. All other `_assign_move` callers keep the old path.

Diff (clean, lint- and warnings-clean): `hordes300-probe.diff` in that folder. Instrumented version with the cross-check: `hordes300-probe-instrumented.diff`. Scratch drivers: `logs/cf-probe.gd`, `logs/cf-digest.gd`.

Core of it:

```diff
 		if unit.combat.mode == "retaliate":
+			if not sim._reserving: sim._begin_reservations()
 			_go_home(sim, unit)
 		if unit.combat.mode == "attack":
 			unit.combat.mode = "guard"
+			if sim._reserving: sim._reserve(unit, "destination", -1)
 			sim._stop_unit(unit)
+	sim._end_reservations()
```
```diff
+	if _reserving:
+		for unit in ground: _reserve(unit, "position", -1)
+		goals = Allocation.assign_excluding(_navigation, ground, point, _reserved)
+		for unit in ground:
+			_reserve(unit, "position", 1)
+			_reserve(unit, "destination", -1)
+	else:
+		(old _unavailable_cells + Allocation.assign path)
+	_place_goals(members, target, goals)
+	if _reserving:
+		for unit in ground: _reserve(unit, "destination", 1)
```

## Measured effect (`sh tools/run_profile.sh`, combat_hordes300 sample phase)

| | before | after |
|---|---|---|
| step.combat_fire max | 5.403 ms | 1.067 ms |
| step max | 7.571 ms | 4.214 ms |
| step mean / p95 | 1.979 / 2.845 | 1.973 / 2.835 |
| tick 776 combat_fire (probe) | 5.418 ms (unavailable 4.118 + assign 0.926) | 1.062 ms (allocation.reserved 0.344) |

Logs: `logs/cf-base-profile.log`, `logs/cf-base-probe.log`, `logs/cf-fix-profile.log`, `logs/cf-fix-probe.log`. The mean does not move; this fixes a tail spike only.

## Determinism

- State-hash digests every 100 ticks over 2100 ticks for hordes300, dense, skirmish3v3, contact and open: 105/105 identical, before vs. probe with the cross-check on, and again for the clean diff (`logs/cf-digest-base.log`, `cf-digest-probe.log`, `cf-digest-clean.log`).
- Cross-check: refcount set vs. a fresh `_unavailable_cells` before every batched allocation, 0 mismatches.
- Full suite on the instrumented tree: `CASES 849 CHECKS 144200 FAILURES 0`, exit 0 (`logs/cf-fix-suite.log`). This covers the pinned team/skirmish series and the replay traces. Run on the instrumented tree, not re-run on the clean diff (the difference is probe-only code).
- `run_lint.sh` and `run_warnings.sh` pass on the clean diff.
- Risk: exactness depends on nothing else changing a ground unit's position or destination while `_reserving` is true. Today only `_go_home -> _assign_move` and `_stop_unit` run inside that window. A future write inside the `object_removed` loop, such as a new branch that moves a unit, would desync the map silently. The fix should ship with a test that keeps the cross-check as a debug assert: a death with 3 or more retaliators that compares the map to `_unavailable_cells`.
- Set membership is all that matters: `Allocation` reads `excluded` only through `has` (destination_allocation.gd:69), so insertion order does not leak into behaviour.

## Unverified

- Rendered benchmark, netplay and conformance not run (no presentation or wire change).
- One timing run per side on a host under moderate load. A quiet re-run is needed before a ledger row.
- The non-batched `_go_home` callers in `_plan_retaliate` (combat.gd:657, 660, in step.combat_plan) still do the full scan: `assign_move.unavailable` max 0.745 ms after the fix. Where the new step max of 4.21 ms sits was not checked; step.combat_plan max is 2.93 ms.
- `_begin_reservations` costs one entity scan per death that has retaliators, so a death with exactly one retaliator costs about the same as before.
- Simpler option not tried: a cell index kept up to date across the whole tick. Rejected because positions and destinations are written in many places.
