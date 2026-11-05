# M6 verification

Plan: [M6 plan](../superpowers/plans/2026-11-05-m6-teams-full-map.md). Run rules: [milestone prompt](../milestone-prompt.md).

```text
Resume record (updated 2026-11-05)
Branch / base commit / working-tree state: m6-teams-map / 9ea11bc (main) / clean after Task 0 commit
Last green task / next incomplete task: Task 0 / Task 1
Changed paths since last commit: docs/reference/m6-verification.md, game/tests/test_skirmish_match.gd
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh, 222 cases, 104,554 checks, 0 failures, exit 0, TESTS PASSED (tree: Task 0 commit)
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: design approved 2026-11-05; local commits after green checkpoints pre-authorized; no push/PR/merge/window/BM6 re-pin without approval
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: start Task 1 (Opus high session) on this branch
```

## Task 0: baseline (2026-11-05, tree 9ea11bc + Task 0 test)

- Base tree `9ea11bc`: `sh tools/run_tests.sh` exit 0, `CASES 221 CHECKS 104553 FAILURES 0`, matches the latest record.
- Pins at base:

  | Pin | File | Value |
  |---|---|---|
  | `TERMINAL_TICK` | `test_skirmish_match.gd` | 9938 (winner 1) |
  | netplay s1 end tick | `tools/run_netplay.sh` | 8423 |
  | `PINNED` | `test_state_hash.gd` | `15df35ca15bcc43b` |
  | BM6 ceiling / floor | `test_benchmark.gd` | 15500 / 13000 |
  | `S1_CORE_SERIES` (new) | `test_skirmish_match.gd` | 1224646555515136482 |

- Move gap `g`: infantry at (5,5), `move` to (10,5) issued at tick 0: the first snapshot after one `step()` (tick 1) already shows `moving` and a changed position. `g = 1`, so the plan's start-delay rule (+2) yields the measured 3.

## Departures and deferrals

- Zero Hour's one-cell cliff dilation is not copied.
- Trees, civilian and tech buildings are not converted.
- The Crusader first-frame acceleration lurch is not copied.
- Turrets and turn-to-aim are deferred; firing ignores heading.
- Air (collector) movement is unchanged.
- Ranger cadence 4/4/22 was measured on the source build (VC6 unverified).
- Wheels follow the route instead of arcing or reversing.
- Halts by `stop` and attack-move engagement stay instant (no braking).
- Production exits spawn with heading `[1, 0]`, not facing out of the door.
