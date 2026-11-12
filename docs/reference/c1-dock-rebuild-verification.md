```text
Resume record (updated 2026-11-12 night, Task 2 GREEN, uncommitted)
Branch / base commit / working-tree state: c1-dock-rebuild / 96dd9b9 (Task 1 commit) / Task 2 changes uncommitted
Last green task / next incomplete task: Task 2 (uncommitted) / Task 3 (MULTI targets on the steady window)
Changed paths since last commit: game/scripts/simulation/definitions/usa.gd, china.gd, frc.gd, game/scripts/simulation/supply_collection.gd, game/tests/test_dock_lock.gd, game/tests/test_supply.gd, game/tests/test_skirmish_scene.gd (_pile_world), this file
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh / 805 / 140926 / 11 / exit 1 / no TESTS PASSED (expected red: test_multi_collector_rates and P1-P8 cases only; tree 96dd9b9 + Task 2 changes)
Known red case or blocker: test_multi_collector_rates (Task 3), P1-P8 (Task 4); tools/audio/test_synth.py in run_python_checks.sh fails on missing numpy (environment); HUD1 fixture risk is a stop condition in Task 4
Approved decisions, pre-authorizations used, deferred gates: c1 chosen, USA overshoot up to +5 %, frc7 rows reported not judged, MULTI targets to the steady window, trace rule (only P1-P10 regenerated) (user, 2026-11-12 night); plan decisions 1-6: same-tick tie to the lower id, lead-standing collectors neither docked nor waiting, dock-hold note and two design-answer sections brought over, one local commit per GREEN task (never push), run_netplay.sh match at night, FRC bot collector count stays 5 (user, 2026-11-12); rendered benchmark, CI, compare_local_traces and playtest deferred to the user
Usage so far (python3 tools/session_usage.py <session files>): n/a
Next exact action: coordinator commits Task 2 locally; dispatch Task 3 from docs/superpowers/plans/2026-11-12-c1-dock-rebuild.md
```

Plan: [c1 dock rebuild](../superpowers/plans/2026-11-12-c1-dock-rebuild.md). Work folder for logs: `~/projects/wargrid-dock-work/c1/` (outside the repository). Expected rows: `~/projects/wargrid-dock-work/c/wargrid-c1.txt`.

## Tasks

| Task | What | Model | Status |
|---|---|---|---|
| 1 | Baseline, docs from `dock-hold`, lone-cycle pin (DL0) | Sonnet | GREEN (96dd9b9) |
| 2 | c1 lock data and rule, spec tests DL1-DL9, hold-timing checks rewritten | Opus (high) | GREEN (uncommitted) |
| 3 | MULTI targets on the steady window | Sonnet | open |
| 4 | Re-pin P1-P10 | Sonnet | open |
| 5 | Headless benchmark and ledger row | Sonnet | open |
| 6 | Docs: economy guide, status, note | Sonnet | open |
| 7 | Exit checks on the final tree | Sonnet | open |
| 8 | Fresh-context review and lean pass | Opus (high) | open |

## Re-pins (Task 4; old -> new, filled in by the run)

| # | Pin | Old | New | Must still hold, checked |
|---|---|---|---|---|
| P1 | `S1_CORE_SERIES` | 6600229479106917126 | | |
| P2 | `TERMINAL_TICK` (winner 1, 7000-17999) | 8569 | | |
| P3 | `CHINA_TERMINAL_TICK` (winner 2, cap 45000) | 11220 | | |
| P4 | `FRC_TERMINAL_TICK` (winner 1, cap 50000) | 48051 | | |
| P5 | `FINAL_DIGEST` | 91106ae278c29044 | | |
| P6 | `TEAM_CORE_SERIES` | 1748824102688385527 | | |
| P7 | `EXPECTED_DIGEST` (view rows) | 6882f9cad3a49db67034c1f7467c3d93670ccb1a542f7071cf082371de4c0880 | | |
| P8 | `HUD_TEXTS` | 6 strings at c2ea952 | | |
| P9 | `run_team_match.sh` `units_peak` (cap, winner null) | 261 | | |
| P10 | `run_netplay.sh` match terminal tick | 9024 | | |

## Evidence rows (append-only)

- 2026-11-12, tree c1-dock-rebuild c2ea952 (clean before the plan), plan written; no suite run. Read-only checks: `git diff 4b444a2 main -- game/scripts/simulation game/scripts/net game/tests/test_income_openings.gd game/tests/test_supply_parity.gd game/tests/economy_fixture.gd` empty, so the `dock-hold` c1 report lines are the expected output of the rebuild.
- 2026-11-12 night, readiness review of the plan (read-only, no suite run): paths, symbols, snippets, test names and pinned values checked against c2ea952 and `dock-hold`; plan edits: working directory rule, absolute log paths, Task 2 red/stop wording, DL3 setup, DL4 mixed pile case, DL7 pile flag, DL8 `extras`, `resume_build` row and attack row, INCOME lines into the evidence row, Task 3 red and 2 % stop, P3 and P8 notes, Task 5 stop on the `BUDGET EXCEEDED` line, Task 6 income note items, Task 8 lean-pass limit. Log folder `~/projects/wargrid-dock-work/c1/` created.
- 2026-11-12 night, Task 1, tree c1-dock-rebuild 443c281 clean: baseline `sh tools/run_tests.sh` CASES 795 CHECKS 140756 FAILURES 0, TESTS PASSED, exit 0. `test_income_openings` INCOME lines (8) equal `wargrid-hold.txt` minus ` model=hold` (diff empty). Docs import: `git diff main dock-hold` old-line count 10 as expected; design answers +21 lines only, three headings as expected.
- 2026-11-12 night, Task 1, tree 443c281 + Task 1 changes: DL0 (`test_dock_lock.gd`, 6 checks) green; red under scratch mutation frc `load_ticks` 42 -> 43 (FAIL for `frc_builder` gap 3 and 9 only; reverted, `git diff game/scripts` empty). Full suite CASES 796 CHECKS 140762 FAILURES 0, TESTS PASSED, exit 0. `run_lint.sh` exit 0, `run_warnings.sh` exit 0, `check_public.sh` PASSED. `run_python_checks.sh` exit 1: ruff, format and mypy pass; `tools/audio/test_synth.py` fails `No module named 'numpy'` (environment, no Python changed). Logs `~/projects/wargrid-dock-work/c1/t1-*.log`.
- 2026-11-12 night, Task 2, tree c1-dock-rebuild 96dd9b9 clean: baseline `sh tools/run_tests.sh` CASES 796 CHECKS 140762 FAILURES 0, TESTS PASSED, exit 0. Red: DL1-DL9 added to `test_dock_lock.gd` before any production change, `WARGRID_TEST_ONLY=test_dock_lock` CASES 10 FAILURES 28, assertion failures only, no `SCRIPT ERROR`; DL0 green; DL1, DL2, DL3, DL4, DL5, DL7, DL9 and all eleven DL8 lead rows plus the depot row red; DL6 and the DL8 locked rows green except "gather same" (lead restart).
- 2026-11-12 night, Task 2, tree 96dd9b9 + Task 2 changes (lock data as in Global Constraints, rule exactly as Step 4): `WARGRID_TEST_ONLY=test_dock_lock` CASES 10 CHECKS 130 FAILURES 0; `=test_supply.gd` CASES 31 CHECKS 2752 FAILURES 0 (Su2, Su4, Su6 unloading, Gt1, Gt2, Lb1, Gd11, Sp1, Sp3, Sp4 rewritten to the table; no other check changed); `=test_supply_pile_labels` 5 checks green (`_pile_world` steps 3 -> 19); `=test_collector_rates_match_zero_hour` 8 checks green (single TARGETS unchanged). DL7 precondition held at the planned spawn `Vector2(6.5, 12.5)`. INCOME lines equal `wargrid-c1.txt` minus ` model=c1` (diff empty, 8 lines):
  - `INCOME usa2 gap=3 gross=1200,4200,7200,13200,27600 net=-2000,1000,4000,10000,24400 steady=2880.0 break_even=98.1 depositors=2 pile_empty=-`
  - `INCOME china3 gap=3 gross=1500,4200,7200,12900,27600 net=-1200,1500,4500,10200,24900 steady=2940.0 break_even=84.7 depositors=3 pile_empty=-`
  - `INCOME frc5 gap=3 gross=975,2850,4875,9000,19425 net=-1125,750,2775,6900,17325 steady=2085.0 break_even=94.8 depositors=5 pile_empty=-`
  - `INCOME frc7 gap=3 gross=1125,3675,6225,11250,24000 net=-1375,1175,3725,8750,21500 steady=2550.0 break_even=91.0 depositors=7 pile_empty=-`
  - `INCOME usa2 gap=9 gross=1200,4200,7200,13200,27600 net=-2000,1000,4000,10000,24400 steady=2880.0 break_even=100.1 depositors=2 pile_empty=-`
  - `INCOME china3 gap=9 gross=900,3300,5700,10500,22200 net=-1800,600,3000,7800,19500 steady=2340.0 break_even=102.7 depositors=3 pile_empty=-`
  - `INCOME frc5 gap=9 gross=375,1425,2250,4200,9000 net=-1725,-675,150,2100,6900 steady=960.0 break_even=163.6 depositors=5 pile_empty=-`
  - `INCOME frc7 gap=9 gross=525,1800,3150,5775,12225 net=-1975,-700,650,3275,9725 steady=1290.0 break_even=152.7 depositors=7 pile_empty=-`
- 2026-11-12 night, Task 2 mutation proofs (each reverted; `git diff game/scripts` back to the green tree): (a) lead check without `and collection.phase.begins_with("flying_")`: `test_dock_lock` FAILURES 49 across DL0, DL2, DL3, DL4, DL5, DL6, DL7, DL8, DL9 (a lead's end re-enters the lead, nothing loads); (b) exclusive lead (`target.active_collector_id = unit.id` in the lead branch): FAILURES 46, DL3 among them ("one laborer loads while another stands its lead"). Logs `~/projects/wargrid-dock-work/c1/t2-mut-a.log`, `t2-mut-b.log`.
- 2026-11-12 night, Task 2 full suite, tree 96dd9b9 + Task 2 changes: CASES 805 CHECKS 140926 FAILURES 11, exit 1. Failing cases exactly the allowed set: `test_multi_collector_rates` (Ep4 2 x usa_collector gap 9 got 2922.9 vs 2770; 4 x frc_builder gap 3 got 1736.3 vs 1590), P1 S1 core series (got 3617151610679531047), P2 S1 outcome (8753, winner 1), P3 Cs1 (11578, winner 2, won), P4 Fm1 (48321, winner 1, won), P5 TB3 final digest (3958ceaab11986af at tick 20000), P6 TB4 (8513092129969516499), P7 VR1 (7c7fbc8d27b1683f96f27525ac6f66c24a851a581dbf5433223ed2b09348a9e7, both checks), P8 HUD1 texts (a Chinook shows `lead_source`; "HUD1 fixture: every case has its unit" passes). Not re-pinned here (Task 4). Expected-unchanged pins (`test_state_hash` PINNED, `test_world_batch` GOLDEN, SS6, MP3, replay, single TARGETS) green. `run_lint.sh` exit 0, `run_warnings.sh` exit 0 (154 files), `tools/test_sim_boundary.py` OK, `check_public.sh` PASSED; `run_python_checks.sh` exit 1 only on `tools/audio/test_synth.py` missing numpy (ruff and mypy pass). Logs `~/projects/wargrid-dock-work/c1/t2-*.log`.
