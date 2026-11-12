# Dock-hold experiment design

**Status: approved by the user (2026-11-12).** Follows decision items 1, 2 and 5 of the [faction income parity](../../reference/faction-income-parity.md#decision-list-for-the-user) note (user, 2026-11-12). Evidence only: no default game number or model changes until the user decides on the rows.

## Why

Wargrid's FRC economy is capped at 1590 credits per minute at a close depot, with 5 workers and with 7; Zero Hour earns 2085 and 2850. The note traced the cap to Wargrid's dock model: one collector holds a pile for its whole stand, (boxes + 1) x `load_ticks` (Laborer 84 ticks, truck 190, Chinook 387; `supply_collection.gd` `_admit` and `step`), so a pile serves at most one Laborer delivery per 84 ticks. Zero Hour also serves one docker at a time, but its lock (`m_activeDocker`, ZH `0a05454` `DockUpdate.cpp`, granted in `update()` line 424, cleared in `onExitReached` line 366 and `cancelDock` line 394) covers only walking in, loading and walking out; waiting at an approach spot (`reserveApproachPosition`, `advanceApproachPosition`, `isClearToAdvance`, lines 136-231) is outside it. Position traces put the locked part at about 44-48 of a lone worker's 84 frames at the pile. USA and China sit just under the same kind of cap (`usa2`, `china3`), so any change moves them too.

The gated multi-collector targets in `test_supply_parity.gd` (`MULTI`, e.g. FRC x4 1590) came from Zero Hour's `collect_*` window (first deposit to the Nth), which includes the ramp-in and understates a steady rate by about 3-8 % (the note's estimate for x4: 1650-1740). The user decided to re-measure them before they judge any dock change.

## Goals

1. Re-measure in Zero Hour the five `MULTI` rows and Chinook x4 (`FOUR_HELICOPTERS_GAP_9`), each on the old window (comparable to today's test) and on a steady window.
2. Measure Zero Hour's locked window per visit directly, per collector kind and per dock (pile, each faction's depot).
3. Build two Wargrid dock models behind an experiment switch whose default is today's model, and report every judging row for each:
   - **A, split hold:** a stand keeps its length; only a measured part of it locks the target.
   - **B, approach queue:** Wargrid's own queue of approach spots; the lock covers moving in, loading or unloading, and moving out.
4. A reference note with the rows and a decision list for the user.

## Non-goals and anti-goals

- No default change: today's model stays the default and the only one in normal play, online, replays and benchmarks. Adopting a variant, changing a `test_supply_parity.gd` target, and the FRC bot collector count (note item 4) are later decisions.
- Headless only (user, 2026-11-12): no playable toggle, no lab scene, no HUD.
- No third-Chinook opening (note item 3). Chinook full load stays open (note item 6).
- Failure even if it "works": a variant that passes by tuning per-row numbers until rows fit; a variant that silently changes a lone collector's cycle (single-collector rows are gated today and must be reported for both variants); any loosened tolerance.

## Approaches

| | What changes | Trade-off |
|---|---|---|
| A split hold | Stand = non-exclusive lead-in, then an exclusive part of measured length E per kind and target; total length unchanged | Small change, lone cycle unchanged by construction; abstract (no visible queue), travel unchanged |
| B approach queue | Waiting collectors stand at ordered approach spots and advance; the head walks in when the lock is free; lock = in + work + out | Closer to Zero Hour, moves arrival spots (may touch the far-depot residual); more code; lone cycle must be recalibrated against the gated rows |
| C retune numbers | Shorter FRC `load_ticks` / `unload_ticks` | Rejected (note item 1, option c): breaks the gated single-worker match |

The user chose to build both A and B and compare them on the same rows (2026-11-12).

## Decided (user, 2026-11-12)

- Lock windows come from the fork: it logs each dock grant and release (frame, dock object, docker object, dock template) into the trace. A local commit on `~/projects/GeneralsGameCode-macOS` branch `wargrid-parity`, like the `dock` verb (`afcaaf198`); never pushed. Runs stay `-headless -noaudio`.
- Re-measure scope: all five `MULTI` rows plus Chinook x4, 3 repeats each, reported on both windows.
- Pass rule for a variant: every one of the eight opening rows (`usa2`, `china3`, `frc5`, `frc7` at gaps 3 and 9) within 5 % of Zero Hour in net at 600 s and in steady rate; every single-collector row of `test_supply_parity.gd` within 5 %; every `MULTI` row and Chinook x4 within 5 % of its re-measured target on the steady window. Old-window numbers are reported, not judged: Wargrid's test spawns all collectors at tick 0 while Zero Hour trains them, so the old window is not like for like. A pass is evidence for the user's decision, not an adoption.
- Code location: the variants stay on branch `dock-hold` as evidence; only the reference note and the Zero Hour harness tooling (`tools/zh_parity/`) go to `main`. If a variant is adopted later, it is rebuilt cleanly as the new model, without a switch.
- Variant B covers flying collectors too: Zero Hour docks Chinooks through the same `DockUpdate` lock. B gets an air rule (waiting spots in the air, lock = fly in, load, fly out), so `usa2` and Chinook x4 say something about B.

## Proposed by the coordinator (correct if wrong)

- **Order:** Zero Hour first (stage 1: fork logging, re-measure sweep, lock windows), then the Wargrid variants (stage 2), then the note (stage 3, stop). Variant A's E values come from stage 1, so stage 2 cannot start before it.
- **Steady window for the re-measure:** 300-600 s after the first collector's gather order, the same fixed window as the openings, so the `collect_*` scenarios run 600 s instead of stopping at N deposits. The Wargrid side reports the same two windows for the same rows.
- **Lock windows from saturated runs:** read from the x4 re-measure rows; a kind that does not saturate there (more than one docker waiting for part of the window) also gets its `open_*` row rerun with logging.
- **A's order inside a stand:** the lead-in (stand minus E) is non-exclusive and comes first; boxes and credits move during the exclusive part. This mirrors Zero Hour, where the approach is not locked and the work is.
- **Where the code lives:** branch `dock-hold` from `main` in worktree `~/projects/wargrid-wt-dock`; work folder `~/projects/wargrid-dock-work/` (outside the repo). The switch is set only by tests; it is not a command, not in replays and not reachable from scenes. With the switch at its default, the full suite passes unchanged on the branch (every pinned trace and digest identical: proof that the default did not move). Because the variant code does not merge, it needs no `sim-interface.md` entry, no ledger row and no benchmark; harness tooling that merges passes `sh tools/run_python_checks.sh`.
- **Reports:** `test_income_openings.gd` and `test_supply_parity.gd` print one report line per row and variant; gates stay on the default model.
- **Dry pile:** one 400-box pile holds 30,000 credits, and Chinook x4 (about 3116 per minute) can empty it near 600 s, more so under a variant that lifts the caps. As in the income plan, the steady window ends at the time the pile empties, and the note reports that time per row; a row whose window ends before 450 s is flagged in the note. A larger pile on the Zero Hour side would need another fork change (the fork has no box-count control); not done.
- **B's calibration:** one in-dock time per collector kind and target, fitted to the single-collector rows only, never to multi-collector or opening rows; the fit is recorded in the note. Anything more is the per-row tuning the anti-goals forbid.
- **Runs:** Opus wrote this design and writes the plan; Sonnet implements the tasks; a fresh Opus reviewer checks the note against traces and test output before the stop.

## Left to the builder

The trace field names for lock events, the rounding of E to ticks, B's spot geometry (Wargrid's own, built from the existing ring cells; no Zero Hour bone or INI data copied), how a test selects the variant, and B's air spot layout.

## Known risks

- Under the pass rule, today's `frc7` far-depot steady rate is already 8.5 % short and far-depot rows are not saturated, so A cannot move them: A fails the rule on the far rows unless that residual has another cause B happens to fix. Reported as found, not hidden.
- B changes arrival positions, so it can also move the gated single-collector rows; its recalibration is part of its cost.
- If the re-measured x4 target lands inside 5 % of 1590, item 2 resolves itself; the experiment still runs.
