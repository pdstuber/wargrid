# frc7 extra-cell spike: verification

Resume record and dated evidence for the handoff (`extra-cell-spike-prompt.txt`, private) and [its plan](../superpowers/plans/2026-11-12-extra-cell-spike.md). Labels: **measured** (run here), **code reading** (path:line at the named tree), **arithmetic**, **unverified**. Rows below the resume record are append-only.

```text
Resume record (updated 2026-11-12 night, Task 1 implementer)
Branch / base commit / working-tree state: dock-hold in ~/projects/wargrid-wt-dock, base df095d7 (the preparation commit); Task 1 changes uncommitted, the coordinator commits after GREEN
Last green task / next incomplete task: Task 1 (uncommitted) / Task 2 (cell pairs over the steady window, Sonnet)
Changed paths since last commit: game/tests/dock_cell_trace.gd, game/tests/dock_cell_trace.gd.uid, game/tests/test_dock_models.gd, this file
Last command / cases / checks / failures / exit / marker: baseline full suite CASES 831 CHECKS 140928 FAILURES 0 exit 0 TESTS PASSED 140928 (before the change); WARGRID_TEST_ONLY=test_cell CASES 9 CHECKS 16 FAILURES 0 exit 0 TESTS PASSED 16; WARGRID_DOCK_PROBE=1 WARGRID_TEST_ONLY=test_cell_trip CASES 1 CHECKS 2 FAILURES 0 exit 0 TESTS PASSED 2; lint, warnings, python checks exit 0; trace.diff sha256 64b8cf4ed9ec1e3e3cce0ff791310f8ee78dd038dddf4c1547bf3759aa953ab3 (tree df095d7 + uncommitted test diff); logs and trip.txt in ~/projects/wargrid-dock-work/extra-cell/
Known red case or blocker: none; leading candidate: not yet named (Task 3 writes it here for Task 4)
Approved decisions, pre-authorizations used, deferred gates: evidence only, no game/scripts or definitions change on dock-hold; measured on dock-hold as is (split judged, hold and c1 reported); c1-rebuild re-measure deferred to the morning; coordinator's local commit after each GREEN task pre-authorized, never push (user, 2026-11-12); causality check in a throwaway detached worktree at ~/projects/wargrid-overnight-work/night-2026-11-13/xcell-causality, one _claim_dock line, never committed, removed at Task 4's end (user, 2026-11-12); Zero Hour dock-cell source read skipped, a caveat (user, 2026-11-12)
Usage so far: not recorded
Next exact action: coordinator commits Task 1, then Task 2 Step 1. Plan deviation: the normal trip leg is a loaded leg with flying 91..103, not 84..96 (the plan's band excludes the run's fast loaded leg, 97; loaded legs here are 133/140/97, empty legs 90/97)
```

## Rows

| date | task | tree | result | evidence |
|---|---|---|---|---|
| 2026-11-12 | plan written | dock-hold d3851e8 | not run | this file, the plan |
| 2026-11-12 | 1 cell recorder and one-trip trace | dock-hold df095d7 + trace diff 64b8cf4e | green; split transplant loaded_flying_median 133.0; slow leg id 4 flying 133 route 3.50 manhattan 3 corners 2 moved_len 3.49; normal leg id 6 flying 97 route 2.60 manhattan 2 corners 1 (not interpreted; Task 3); normal band widened 84..96 to 91..103 | ~/projects/wargrid-dock-work/extra-cell/trip.txt, t1-green.log |
