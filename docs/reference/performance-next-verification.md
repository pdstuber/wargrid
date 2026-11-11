# Performance next: verification

```text
Resume record (updated 2026-11-11 11:10)
Branch / base commit / working-tree state: perf-next / 5f9efee / clean after T0 commit
Last green task / next incomplete task: T0 / T1
Changed paths since last commit: this file
Last command / cases / checks / failures / exit / marker: T0 baseline on perf-next 5f9efee: tests 728 cases / 139569 checks / 0 failures, TESTS PASSED, exit 0
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: user 2026-11-11: local commits on perf-next after each GREEN, never push. Gates 1-3 pending.
Usage so far: n/a
Next exact action: dispatch T1 (Sonnet).
```

## Evidence rows (append-only)

- 2026-11-11 11:10-11:20, tree perf-next 5f9efee, load 1.1-1.8, no WoW/godot running, measured. Logs ~/projects/wargrid-perf-work/logs/t0-*.log.
  - run_tests: CASES 728 CHECKS 139569 FAILURES 0, TESTS PASSED, exit 0. (Handoff cited 737/139594 from the spike branch with native path; main differs by design, not a mismatch.)
  - run_lint: no problems, exit 0. run_warnings: 137 files, exit 0.
  - run_benchmark: all PASS (BENCHMARK 2, COMBAT 10, LOCKSTEP 1); open/dense/hordes300 stress rows exceed 1.82/3.64 budget but inside ceilings (accepted until spike).
  - run_profile (mean/p95 ms): skirmish3v3 step 0.705/1.313, snapshot 0.321/0.572, view.batch 0.468/0.835; team_match step 1.071/1.929, snapshot 0.507/0.790, view.batch 0.798/1.205; hordes300 step 1.987/2.850, snapshot 0.990/1.172, view.batch 1.742/2.004. Within 10 % of note section 2 (0.70/1.30, 0.32, 0.47; 1.98/2.84, 0.99, 1.74).
