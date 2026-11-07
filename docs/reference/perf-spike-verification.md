# Performance spike verification

Handoff: [performance-spike-prompt.txt](../performance-spike-prompt.txt). Ledger: [performance.md](performance.md). Dated evidence rows below the record are append-only.

```text
Resume record (updated 2026-11-07 22:00)
Branch / base commit / working-tree state: main / deec14d / uncommitted: game/benchmarks/run_calibration.gd (+ .uid if Godot made one), this file
Last green task / next incomplete task: Task 0 done pending user decision / Workstream 1 baseline
Changed paths since last commit: game/benchmarks/run_calibration.gd (new, report-only), docs/reference/perf-spike-verification.md
Last command / cases / checks / failures / exit / marker: sh tools/run_lint.sh and sh tools/run_warnings.sh exit 0 (102 files); calibration 2 min on M6 (no suite run)
Known red case or blocker: none. Air dropped by user; ZH pid 50629 killed by user; Codex/WoW/Battle.net closed
Approved decisions, pre-authorizations used, deferred gates: user invoked the spike 2026-11-07; works on main; local commits after green checkpoints pre-authorized; no push/PR/merge/fly/Sprite/window without approval; host = this Mac only (user)
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: user confirms host (this Mac, apps closed, budgets and deltas); then Workstream 1 baseline
```

## Evidence

| Date | Tree | Host | What | Result |
|------|------|------|------|--------|
| 2026-11-07 | deec14d | Apple M6 | start check | load 1.70 / 1.33 / 1.48; ZH parity process pid 50629 running (not ours) |
| 2026-11-07 | deec14d + game/benchmarks/run_calibration.gd (uncommitted) | Apple M6 | calibration 2 min, ZH pid 50629 alive at start (0.7 % CPU, gone by end), Codex app-server daemons idle, WoW/Battle.net not running | load 1.26 start / 1.29 end; per-minute p50 0.698 / 0.699, p95 0.719, p99 0.730, max 1.07 / 0.97 ms |
| 2026-11-07 | deec14d + run_calibration.gd (uncommitted) | Apple M6 | calibration 2 min, apps closed by user, ZH killed, only idle Codex daemons | load 1.26 start / 1.43 end; per-minute p50 0.693 / 0.695, p95 0.712 / 0.715, p99 0.722 / 0.725, max 1.25 / 0.81 ms; p99 within 4.3 % of p50 |
| 2026-11-07 | deec14d | MacBook Air | clone moved to deec14d detached (was m7-factions 11672f4) and script scp-copied (uncommitted); 12 min run started at load 3.38, killed after about 1 min by user decision; Air dropped, partial run discarded, clone left as is | no numbers |
