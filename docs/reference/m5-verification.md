# M5 verification

```text
Resume record (updated 2026-11-04, Task 1 done, at stop gate)
Branch / base commit / working-tree state: m5-online / fe53119 + Task 1 commit / clean after commit, nothing pushed
Last green task / next incomplete task: Task 1 (R3 exceeded, resolved by user decision) / gate review of Task 1, then Task 2
Changed paths since last commit: none after the Task 1 commit
Last command / cases / checks / failures / exit / marker: exported macOS suite 160 / 104,030 / 0 / 0 / TESTS PASSED 104030 (env vars set; 104,024 without)
Known red case or blocker: none; R3 digest budget decision made (see below)
Approved decisions, pre-authorizations used, deferred gates: R3: SHA-256(var_to_bytes) 0.83 ms p99 > 0.55; user approved 2026-11-04 digest = Dictionary.hash() plus FNV-1a core-field check (spec line 35, plan Task 2 updated). project.godot gained textures/vram_compression/import_etc2_astc=true (macOS universal export), bundle id io.github.pdstuber.wargrid (subagent choice, user may change). User playtest of M4.1 still pending.
Usage so far (python3 tools/session_usage.py <session files>): not recorded
Next exact action: gate review (fresh-context reviewer) of Task 1, then restart session; resume at Task 2 (measure digest + core_check first, <= 0.25 ms p99)
```

## Evidence

| Item | Command | Result | Tree |
|---|---|---|---|
| Task 0 baseline | `sh tools/run_tests.sh` | 160 cases / 104,024 checks / 0 failures / exit 0, `TESTS PASSED 104024` | `m5-online` at `d66e4b1` clean |

Task 0 status check: README, AGENTS.md, blueprint §7 and session notes already say M4.1 is merged to `main` at `f2c5f9e` with the user playtest pending; no line says "not merged". No edits needed.

| Task 1 risk spike | Opus subagent, scratch scripts | Templates `Godot_v4.7.2-stable_export_templates.tpz` SHA-256 `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011` (matches GitHub asset digest). R1: exported macOS traces vs editor `REPLAYS MATCHED 1200` x3 (Linux/Windows wait for Task 6 CI). R2: user args work; `--script` ignored by release templates, so test builds use feature tag `wargrid_tests` with `run/main_loop_type` override to a `class_name WargridTestRunner` (verified in scratch copy: 160 / 104,030 / 0; add in Task 6). R3 EXCEEDED: SHA-256(var_to_bytes) p50/p95/p99 0.800/0.821/0.830 ms editor, 0.808 release (300 units, 188,852 bytes); JSON stringify+parse 50-command packet 0.063 / 0.063 ms p99. Opus follow-up: `Dictionary.hash()` 0.043 ms p99, all 5,418 contact leaves detected; user chose hash() plus core-field check. R4: 11 command types, 207 checks, 0 failures with `stringify(v, "", true, true)` | `m5-online` e12cde1 |

Task 1 preflight findings: `--script` unavailable in release templates; relative `--export-release` path resolves against `game/`; macOS export needs `bundle_identifier` and ETC2/ASTC import; Windows release exe is GUI subsystem (console wrapper preset set, unchecked on Windows); `_payload_fields` is an instance method, so Task 2/R4 hard-code the 11 command types. Windows console-wrapper output not verified.

Gate review (Task 1, Opus, fresh context, tree e12cde1): code ships; suite `TESTS PASSED 104024`, three exports from a fresh checkout succeed (macOS universal ad-hoc, Windows + console exe, Linux), template SHA-256 matches GitHub, `--script` hang reproduced. Plan fixes applied (docs only, rulings): word-wise FNV-1a (byte-wise 0.378 ms would break the 0.25 ms ceiling), exact core fields (`hp`, buildings excluded), NaN/inf handling, test-runner decision and exported-trace step moved into Task 6, `finish_tick(tick, state)` with a snapshot only on hash ticks (snapshot 0.375 ms p99), compare_replays tick-0 row and equal digest width, console exe for Windows, Task 1 Owns amended. Deferred minors: export_build.sh could pass on a stale output file (use `-nt` marker); `Wire.decode` should validate `hash.value` against `^[0-9a-f]{16}$` (Task 2); Task 7 Gatekeeper instruction (right-click Open) may be outdated on current macOS, check in Task 7; Task 8 must time snapshot plus digest on hash ticks or record the snapshot as a presentation cost.
