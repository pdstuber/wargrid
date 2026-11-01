# M0 verification — 2026-11-01

Status: local correctness PASS (212 checks); remote CI PASS for original commit `20739d6` (199 checks), pending for current additions. Original M0 exit gate passed; no M1 implementation. Visuals and reference fidelity UNVERIFIED.

## Environment and provenance

`godot --version` exited 0: `4.7.2.stable.official.ed1daf0bf`.
Official [GitHub release API](https://api.github.com/repos/godotengine/godot/releases/tags/4.7.2-stable) fetched directly on 2026-11-01. It identifies `Godot_v4.7.2-stable_linux.x86_64.zip` with digest `sha256:cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`. CI verifies that digest before installation. Linux archive execution and remote Actions run have not occurred here.

Hell's Verdict wrapper/CI patterns inspected read-only; its project AGENTS rules inspected as reference only. Wargrid uses its own renderer, tick rate and workflow. No retail backups or EA source inspected for M0.

## Runner and behavioral evidence

Initial smoke: wrapper exit 0; 1 case / 1 check. Seven independent scratch failure probes all exited 1:

| Probe | Observed reason |
|---|---|
| False expectation | Assertion failure |
| Empty cases | Zero tests/checks |
| Suite syntax error | Import/script parse diagnostic |
| Return before checks | Incomplete/empty case |
| Check then bare return | Incomplete case |
| Runtime error then passing case | Script error; later case ran; wrapper rejected |
| Main script syntax error | Import diagnostic rejected |

No probe hung. Restored scratch smoke: exit 0, 1 case / 1 check.

C1–C11 were written against syntactically valid stubs before kernel implementation. Behavioral RED: 11 cases / 184 checks / 37 failures, exit 1; no parse/runtime diagnostics. GREEN: 11 cases / 199 checks / 0 failures, exit 0. Count rises because red-world guards skip assertions requiring entities/orders absent from stub. Test expectations were unchanged. Cases were written as one acceptance group rather than individual red/green increments.

## Final local commands

| Command or condition | Exit | Result |
|---|---:|---|
| `sh tools/run_tests.sh` from repo | 0 | 11 cases / 199 checks |
| `sh /Users/pdstuber/projects/wargrid/tools/run_tests.sh` from `/private/tmp` | 0 | Same counts |
| Wrapper with `GODOT_BIN=/opt/homebrew/bin/godot` | 0 | Same counts |
| Wrapper with temporary executable symlink path containing spaces | 0 | Same counts |
| Fresh scratch project without `.godot` cache | 0 | Import then same counts |
| `godot --headless --path game --quit-after 5` | 0 | No error diagnostics |

All successful test runs emitted `TESTS PASSED 199`, without engine error diagnostics. Sandbox initially denied Godot editor settings/cache writes; authorized escalated runs passed. No window opened. Headless smoke verifies launch, not visuals or exactly five physics ticks.

## Limits

No remote CI, visual/play, performance or original-game parity claims. No engine upgrade, new dependency, commit, push, PR or M1 work. Repository started without HEAD and contained untracked user documentation; preserved it. Commit-range execution helpers could not apply; temporary evidence ledger used instead.

## Review

Independent-family Grok review attempted but stalled without findings; only that process terminated. One fresh-context substantive reviewer then inspected implementation, callers, tests, wrappers, CI and plan: no production defects. Minor test coverage deferred: C10 directly checks player ordering but not tick/sequence sort keys; numeric equality does not prove normalized float types. Current implementation sorts all specified keys and converts target coordinates to floats. Final Ponytail lean pass found no unnecessary M1 code, abstractions or dependencies to cut. Remote CI remains pending.

Review limits accepted: execution-time invalidation guard inspected but unreachable through current public APIs; no artificial public mutation API added. Reviewer accepted recorded red/probe evidence without duplicate test run. Visuals, performance, cross-platform determinism and reference fidelity remain unverified; remote CI pending.

## Test coverage follow-up — 2026-11-01

C4 now checks both queued and applied target coordinates have `TYPE_FLOAT`. C10 submits future ticks in reverse tick order, multiple sequences for one tick/player, and opposite player insertion orders. It asserts exact canonical queue order. Production code unchanged.

`sh tools/run_tests.sh`: 11 cases / 209 checks / 0 failures, exit 0 before and after scratch probes. Independent scratch mutations, all exit 1 with behavioral failures and no parse/runtime diagnostics:

| Mutation | Failures |
|---|---:|
| Omit tick sort key | 1 |
| Omit player sort key | 2 |
| Reverse sequence comparison | 2 |
| Omit X float conversion | 4 |
| Omit Y float conversion | 4 |

Correction to initial review: C4/C11 deep Dictionary equality already rejects unnormalized integer coordinates on this build. Explicit `typeof` checks strengthen diagnostics; float normalization was not wholly uncovered. Sequence reversal is probed because valid submissions already enter in increasing per-player sequence order; removing that comparison may preserve observable order for small queues.

## Remote CI evidence — 2026-11-01

User supplied `/tmp/logs.txt`. GitHub CLI independently confirmed run [41296904731](https://github.com/pdstuber/wargrid/actions/runs/41296904731), status `completed`, conclusion `success`, commit `20739d61547cc8913a93efac791c94ec226ea2cc`. Ubuntu log verifies Linux archive checksum, engine build and `CASES 11 CHECKS 199 FAILURES 0` / `TESTS PASSED 199`, followed by cleanup without test failure. Original M0 remote gate is satisfied. Current uncommitted coverage additions still need their own remote run.

Earlier pending-CI/review entries above describe initial implementation handoff. No visual, performance, cross-platform determinism or reference-fidelity claim follows from Linux CI success.

Follow-up review: Grok timed out without verdict; sole completed fresh-context review found no issues in changed tests, connected kernel or status documentation. C4 catches either missing coordinate conversion; C10 catches omitted tick/player ordering and reversed sequence ordering. Final Ponytail pass found no useful cuts. Reviewer did not rerun recorded command/remote evidence or judge visual/performance/fidelity claims; executor verified local runs and GitHub run metadata directly. No production fix or further test rerun needed after review.

## Whole-branch Grok review and group coverage — 2026-11-01

Grok completed read-only whole-branch review of root commit and uncommitted additions: no Critical, Important or Minor defects. It noted successful multi-entity moves and explicit ID-order coverage as test limitations; execution-time invalidation remains unreachable via M0 public API. Grok did not rerun recorded tests/CI or verify visuals/reference data. Earlier timeout diagnoses were premature: trace showed active reasoning. Subsequent reviews allow Grok time to finish.

User requested addressing coverage limits, then commit and local merge to `main`. C1 now asserts all three entities in ID order. New C12 submits one valid move for two owned entities, with IDs `[2, 1]`; checks full queued group and exact applied snapshot with both orders, unchanged positions, consumed queue and accepted sequence. No private state mutation or extra public API. Removing ID sort can still preserve insertion order under current spawn-only API; deliberate reversed output is the observable regression tested.

`sh tools/run_tests.sh` before/after scratch probes: 12 cases / 212 checks / 0 failures, exit 0. Applying only first group member yields one C12 failure, wrapper exit 1. Reversing entity snapshot IDs yields C1/C12 failures, wrapper exit 1. Neither probe produced parse/runtime diagnostics. Production code unchanged.

Focused Grok follow-up completed: no defects in C1/C12 or updated status docs; no test rerun by reviewer. Final Ponytail pass found no useful cuts. User authorized local commit/merge; updated-suite remote CI still pending separate push approval.
