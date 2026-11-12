# frc7 extra-cell spike: verification

Resume record and dated evidence for the handoff (`extra-cell-spike-prompt.txt`, private) and [its plan](../superpowers/plans/2026-11-12-extra-cell-spike.md). Labels: **measured** (run here), **code reading** (path:line at the named tree), **arithmetic**, **unverified**. Rows below the resume record are append-only.

```text
Resume record (updated 2026-11-12 night, Task 2 implementer)
Branch / base commit / working-tree state: dock-hold in ~/projects/wargrid-wt-dock, HEAD 3a47bf5 (Task 1 commit); Task 2 changes uncommitted, the coordinator commits after GREEN
Last green task / next incomplete task: Task 2 (uncommitted) / Task 3 (verdicts and note update, Opus)
Changed paths since last commit: game/tests/dock_cell_trace.gd, game/tests/test_dock_models.gd, this file
Last command / cases / checks / failures / exit / marker: full suite CASES 843 CHECKS 140950 FAILURES 0 exit 0 TESTS PASSED 140950; WARGRID_TEST_ONLY=test_cell CASES 12 CHECKS 22 FAILURES 0 exit 0 TESTS PASSED 22; WARGRID_DOCK_PROBE=1 WARGRID_DOCK_MODELS=hold,split,c1 WARGRID_TEST_ONLY=test_cell_rows CASES 1 CHECKS 30 FAILURES 0 exit 0 TESTS PASSED 30; lint, warnings, sim boundary, python checks exit 0; trace2.diff sha256 1134089ab26f4d7fc87d636a80ae835d7e276e4df2ca4d476c4cb72490d1a974 (tree 3a47bf5 + uncommitted test diff); logs, cells.txt (tree line + 128 DOCK lines) in ~/projects/wargrid-dock-work/extra-cell/. Step 2 red run skipped (implementation written with the tests); a first green run failed on a parameter named legs shadowing the recorder field, renamed
Known red case or blocker: none; leading candidate: not yet named (Task 3 writes it here for Task 4)
Approved decisions, pre-authorizations used, deferred gates: evidence only, no game/scripts or definitions change on dock-hold; measured on dock-hold as is (split judged, hold and c1 reported); c1-rebuild re-measure deferred to the morning; coordinator's local commit after each GREEN task pre-authorized, never push (user, 2026-11-12); causality check in a throwaway detached worktree at ~/projects/wargrid-overnight-work/night-2026-11-13/xcell-causality, one _claim_dock line, never committed, removed at Task 4's end (user, 2026-11-12); Zero Hour dock-cell source read skipped, a caveat (user, 2026-11-12)
Usage so far: not recorded
Next exact action: coordinator commits Task 2 ("Add dock cell pair rows to the dock probe"), then Task 3 reads cells.txt. Plan deviation: none in Task 2; Task 1's normal trip band 91..103 stands. Note for Task 3: split sweep_g3_n7 summary is empty 133 / loaded 90 (the slow legs are the empty ones there), split transplant_g3 is empty 90 / loaded 133; cells.txt lists the pairs
```

## Rows

| date | task | tree | result | evidence |
|---|---|---|---|---|
| 2026-11-12 | plan written | dock-hold d3851e8 | not run | this file, the plan |
| 2026-11-12 | 1 cell recorder and one-trip trace | dock-hold df095d7 + trace diff 64b8cf4e | green; split transplant loaded_flying_median 133.0; slow leg id 4 flying 133 route 3.50 manhattan 3 corners 2 moved_len 3.49; normal leg id 6 flying 97 route 2.60 manhattan 2 corners 1 (not interpreted; Task 3); normal band widened 84..96 to 91..103 | ~/projects/wargrid-dock-work/extra-cell/trip.txt, t1-green.log |
| 2026-11-12 | 2 cell pairs over the steady window | dock-hold 3a47bf5 + trace diff 1134089a | green; all cross-checks met exactly: split summary (empty/loaded flying) sweep_g3_n1 90.0/90.0, sweep_g3_n7 133.0/90.0, sweep_g9_n1 270.0/270.0, sweep_g9_n7 270.0/313.0, transplant_g3 90.0/133.0 (loaded within +-3 of 133); hold sweep_g3_n7 loaded 97.0; c1 sweep_g3_n7 90.0/133.0, transplant_g3 90.0/133.0; legs split 58/314/26/170/344, hold 58/209/26/170/208, c1 58/343/26/169/344; not interpreted (Task 3) | ~/projects/wargrid-dock-work/extra-cell/cells.txt, cells.log, t2-full.log |
