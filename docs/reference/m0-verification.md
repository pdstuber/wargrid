# M0 verification — 2026-11-01

Status: local correctness PASS; remote CI PENDING. Visuals and reference fidelity UNVERIFIED. M0 exit gate remains pending remote CI; no M1 implementation.

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
