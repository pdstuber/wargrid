# frc7 contention gap: measurement design

Status: approved (user, 2026-11-12 night). Evidence only; handoff `frc7-gap-prompt.txt` (private).

## Intent

Wargrid frc7 close loses 14.4 % to the pile bound (split: 2625 against 3068); Zero Hour loses 7 to 10 %. frc7 far is -8.5 % under every model. The answer decides whether a dock rebuild (c1 or split) pays.

## Goals

- Find which candidate cause explains the extra ~1.3 s of flight per trip, or kill them all.
- Stop at a reviewed update of `docs/reference/dock-hold-experiment.md`.

## Non-goals

No dock model adoption, no `definitions/` change, no pinned trace change, no new Wargrid mechanics. c1 and c2 run only when named (`WARGRID_DOCK_MODELS`).

## Approaches

Phase breakdown plus per-candidate kill checks (chosen); fixing a candidate blind and re-running the sweep (rejected: adopts a change before the cause is known); new Zero Hour games for everything (rejected: existing traces first, new games only through `tools/zh_parity/parity.py` after user approval).

## Order (each step has a kill check run first)

1. Sweep against opening, 240/min at n = 7 (split frc7 close: 2385 against 2625). Kill check: run one layout in the other's harness. **Hard gate:** if unexplained, stop and report.
2. Release-to-next-grant gap, both sides (Zero Hour lock rows, Wargrid counter). Kill: Wargrid median <= Zero Hour's.
3. Flight per leg at n = 1 and n = 7, both sides. Kill: n = 1 matches and n = 7 matches means no interference; n = 1 off means pathing or arrival-cell geometry.
4. Count `blocked` 30-tick retries and path-service latency in frc7 close and far. Kill: zero or rare events.
5. frc7 far (gap 9 / 312.5): cycle length lone and with several workers.

## Constraints

Zero Hour traces have no per-unit state: lead-in and waiting only comparable as a sum. Zero Hour runs headless and silent. Wargrid numbers say which tree they ran on.
