```text
Resume record (updated 2026-11-12 night, plan written and its choices decided, no task started)
Branch / base commit / working-tree state: c1-dock-rebuild / c2ea952 (= main) / plan and this file uncommitted
Last green task / next incomplete task: none / Task 1 (baseline, docs from dock-hold, lone-cycle pin)
Changed paths since last commit: docs/superpowers/plans/2026-11-12-c1-dock-rebuild.md, docs/reference/c1-dock-rebuild-verification.md
Last command / cases / checks / failures / exit / marker: none on this branch
Known red case or blocker: none; HUD1 fixture risk is a stop condition in Task 4
Approved decisions, pre-authorizations used, deferred gates: c1 chosen, USA overshoot up to +5 %, frc7 rows reported not judged, MULTI targets to the steady window, trace rule (only P1-P10 regenerated) (user, 2026-11-12 night); plan decisions 1-6: same-tick tie to the lower id, lead-standing collectors neither docked nor waiting, dock-hold note and two design-answer sections brought over, one local commit per GREEN task (never push), run_netplay.sh match at night, FRC bot collector count stays 5 (user, 2026-11-12); rendered benchmark, CI, compare_local_traces and playtest deferred to the user
Usage so far (python3 tools/session_usage.py <session files>): n/a
Next exact action: run in ~/projects/wargrid-wt-c1; dispatch Task 1 from docs/superpowers/plans/2026-11-12-c1-dock-rebuild.md
```

Plan: [c1 dock rebuild](../superpowers/plans/2026-11-12-c1-dock-rebuild.md). Work folder for logs: `~/projects/wargrid-dock-work/c1/` (outside the repository). Expected rows: `~/projects/wargrid-dock-work/c/wargrid-c1.txt`.

## Tasks

| Task | What | Model | Status |
|---|---|---|---|
| 1 | Baseline, docs from `dock-hold`, lone-cycle pin (DL0) | Sonnet | open |
| 2 | c1 lock data and rule, spec tests DL1-DL9, hold-timing checks rewritten | Opus (high) | open |
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
