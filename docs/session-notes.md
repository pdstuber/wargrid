# Session notes

Working handoff record, not authoritative design. Follow [kickoff](kickoff.md) and [wrap-up](wrapup.md). Setup lives in [README](../README.md); design in [blueprint](../Wargrid_Kickoff_Blueprint.md).

## Session

2026-11-03 M3 explicitly kicked off on prepared `m3-base-supplies` at `d7acea9`, after verified [M2 matrix41591616563](https://github.com/pdstuber/wargrid/actions/runs/41591616563), head `4be6b7b`, successful Linux/macOS/Windows/replay jobs. User accepted risk of deferring M2 visible/play/rendered-frame/backlog gates: "yeah let's run with the risk recorded". Gates remain pending, never passed. User initially chose headless-only M3 verification. Subsequently reported positive M3 playtest; see newest dated entry for evidence and limits.

Tasks0–11 implemented sequentially with delegated red/green evidence. Added economy definitions/state/commands, limited air, construction/power, paid FIFO/refunds, finite supplies/docks/recovery, base view/controls/HUD and separate exact economy replay. M2 behavior assertions retained through additive C1/C11 snapshot migration. No dependencies, retail data/code/assets, combat or M4.

Final ordinary suite **95 cases / 101,305 checks / zero failures / exit0**, `TESTS PASSED 101305`. Final outside-root/fresh-cache/third trace variants each95/101,309/zero failures/exit0 with marker; both1200-row scenarios match exactly across three independent same-host runs. Python6 and base headless30-frame smoke pass without diagnostics. Final M2 benchmark repeated after review fixes: open p95/p99/max1.452/1.495/7.803ms; dense1.487/1.548/7.789ms; both budgets pass,300 unique final goals/zero blocked.

Sole completed substantive review was fresh-context fallback after bounded four-minute Grok stall; no Grok report counted. Fixed queue Cancel node lifetime across press/tick/release and lower-ID dock waiter arbitration. Closed four grouped coverage gaps through public API/input scenarios; all37 named tests have production-mutation mapping. Lean-only `/ponytail-review` removed unused constant/test preload/binding; no framework/dependency. [M3 verification](reference/m3-verification.md) owns red/green, final logs/counts, review resolutions and limits. No unresolved substantive findings.

## Pending user action

- M3 fast-forwarded into local `main` during wrap-up; publishing `main` and any PR need separate approval.
- User confirmed positive M2 playability and no M3 visual issues; M4 mention corrected to M3. Rendered-frame/backlog measurements and retail parity remain unverified; no itemized visible checklist inferred.
- M3 cross-OS tests and both exact replay comparisons passed at `303006b`; see [verification](reference/m3-verification.md).

## Deferred experiments and research

- Source/config-supported economy remains RETAIL_UNVERIFIED; geometry, flight speed, docking simplification and work accumulation departures stay explicit in reference/design.
- M4 planning requested; implementation remains unauthorized. Sale, upgrade, passengers, later factions, multiplayer and art expansion remain excluded.

## Next action

**M4 in progress (2026-11-03, uncommitted on `m4-combat`).**
- **Done:** Tasks 1–4 plus 4c are green: 113 cases / 101,543 checks / exit 0. Evidence: [M4 verification](reference/m4-verification.md); ledger: `.superpowers/sdd/2026-11-03-m4-combat/progress.md`.
- **Reviewed:** the Tasks 1–4 checkpoint got an Opus in-session review plus a Grok review. One Grok finding was fixed; the rest went into the plan.
- **Update 3 (end of M4 implementation session):** Tasks 8–10 done. 135 cases / 103,899 checks, benchmarks pass (combat margins 2–4% on open/dense). Final review: Grok returned nothing, Opus fresh-context review fixed (contact layout, budget gate, A/S vs pan, tests). Lean review done. **Next: user authorizes one batched visible check** (`sh tools/run_game.sh res://scenes/skirmish.tscn` plus the rendered benchmark rerun); after approval switch the launcher default; commits, push and CI for the third trace need separate approval. Exit gate NOT met until then.
- **Update 2:** Tasks 6–7 green (127 cases / 101,696 checks, suite 14.6 s). Scenario pinned at terminal tick 9943, winner 1 (scripted human). 7c review done and fixed; pin is now terminal tick 9943, winner 1. Task 8 next.
- **Decision:** `tools/run_game.sh` with no args will default to the skirmish scene at the M4 gate, after the user approves playability (script change, `project.godot` untouched). Recorded in plan Task 10.
- **Update:** 4d and Task 5 are green (118 cases / 101,605 checks); stopped at the 5b review gate. Next is Task 6 after review. Older line follows: Sonnet/medium resumes with plan **step 4d**: user-approved P1 throttled acquisition and P2 halted attack-move keeps its slot; exact contract, tests and mutations are in the plan.
- **Then Task 5:** read its "Pre-checked against live code" block first. `test_target_removed_cleanup` is a known genuine red: unit removal lacks `Combat.object_removed`.
- **Prompt stop points:** stop after 5b and after 7c for stronger-model review.

Read [M4 approved design](superpowers/specs/2026-11-03-m4-combat-design.md) and [Sol/Medium execution plan](superpowers/plans/2026-11-03-m4-combat.md). User approved M4 design on2026-11-03. Do not ask for design approval again. Implementation kickoff remains pending (inherited rendered-frame/backlog measurements were completed 2026-11-03; see [performance ledger](reference/performance.md)); Git publication and visible checks require explicit authorization. Review remaining evidence gaps in [M3 verification](reference/m3-verification.md); do not restart completed implementation or reviews. Original prompts below remain historical task contracts.

## 2026-11-03 — Performance open points and real-game verification

- Rendered benchmark was broken since M2 (untyped `[]` to typed `set_state`); fixed with regression `test_rendered_probe_ticks`, suite then 96 cases / 101,306 checks / exit 0 (now 97 / 101,355 with later tests and the builder-speed change; see below). Corrected rerun completed but **fails the frame budget** (about 3 fps, p95 320/340 ms; backlog grows). Simulation cost fine. Headless probe shows script-side `_draw` is 3–5 ms, so cost is renderer-side; rendered probe confirmed the per-tile terrain loop (about 8,200 canvas commands) costs about 80 ms/frame vs about 2 ms for a one-polygon-plus-multiline variant. Fix applied (`WorldView._draw_terrain`); real benchmark rerun: ~120 fps, zero backlog, frame p95 19.6/19.5 ms vs 16.7 budget (marginal fail, tail likely tick frames, unprofiled). Builder speed now 1.2 (user directed speed from `Locomotor.ini` ÷25; infantry 0.8/tank 1.2 go into M4 definitions; legacy vehicle stays 3.0). Suite 96 cases / 101,351 checks / exit 0. Frame-tail follow-up: plumbing is ~2.3 ms/tick headless; tick frames spend ~13 ms waiting in render submission (vsync on) vs ~2 ms with vsync off in an earlier probe, so the p95 tail is likely vsync pacing; untested. Vsync-off rerun done (`--disable-vsync`): frame p95 3.6/5.1 ms, max 15.8 ms, zero backlog: rendered benchmark passes; the vsync-on tail was display pacing. Decided by user: benchmark scene disables vsync itself (done; header `vsync=off`; frame p95 4.1/6.5 ms, dense max 19.5 ms). Raised by user: target is a low-end device/browser (WebAssembly). Done: [performance ledger](reference/performance.md) (assumed 6× slowdown, derived budgets: plumbing and rendered frame currently exceed, sim passes with ~12% margin; per-milestone History rows) and M4 plan Task9a combat benchmark (150 v 150, three layouts, sim-only budgets, no implementation yet). Not done: CI trend logging, machine-independent counters, web export spike. No `AGENTS.md` change (a one-line ledger rule there is optional). See [M2 verification](reference/m2-verification.md).
- M4 plan corrected: baseline/wall-time, watchdog is one 60 s suite budget (task7 gate ≤30 s), HP bars only selected/damaged, open decisions listed.
- New [Zero Hour verification plan](reference/zero-hour-verification.md): level 0 found ground speeds 2.5–3.75× faster than range scale implies; level 1 observation protocol proposed; gate before M5 proposed. Needs user decisions: speed scale, rendering fix, level 1 session.
- Item 2 (machine-independent counters): added `test_snapshot_size_ceiling` (open 79,481 / dense 80,345 nodes at the step-38 peak, busiest unit 322; mutation of the ceiling by 1 fails) and an engine draw-call print in the rendered benchmark (not yet run in a window). A* expansions not countable (built-in `AStarGrid2D`); canvas commands not observable headless. Plan Task9a adds `combat_work()` counter. [AGENTS.md](../AGENTS.md) updated: M4 reading list, performance ledger rule, rendered-benchmark etiquette, parity goal.
- Doc consistency sweep: counts (now 97 cases / 101,355 checks), rendered-gate status, speeds, vsync, M4 prompt and design aligned; historical M3 text kept with forward pointers.
- User approved the integration plan: branch `m4-prep` from `c441a7f` with three commits (benchmark/terrain fix, builder speed, docs), then push for CI, then fast-forward `main`, then fast-forward `m4-combat`. Each code commit passed the suite alone (97 cases / 101,310 then 101,355 checks). [CI run 41676948968](https://github.com/pdstuber/wargrid/actions/runs/41676948968) at `c11bf71`: Linux and Windows passed; the macOS job waited 15 minutes for a free runner and was cancelled with no steps run, so `compare-replays` was skipped. Substitute evidence, not CI: macOS traces generated locally on the same commit (97 cases / 101,359 checks incl. four trace-file checks, exit 0) matched the CI Linux and Windows traces, `REPLAYS MATCHED 1200` for both movement and economy. User approved fast-forwarding `main` on that basis; the macOS CI job was re-queued and remains unverified. Read git log/status and CI for current publication state. No M4 implementation. Code changes: `movement_benchmark.gd` (typed selection, vsync off, draw-call print), `world_view.gd` terrain, `economy_definitions.gd` builder speed, tests in `test_benchmark.gd` and `test_economy.gd`.

## 2026-11-03 — Prep for M4 Tasks 4, 5, 7 (for a Sonnet/medium run)

- User will run Sonnet 5.5 at medium effort on `prompt.txt`; asked for prep on the densest tasks. All four packages done, uncommitted on `m4-combat`:
  - **Refactor** (`simulation.gd`, behavior-preserving): `_validate_target`, `_assign_move`, target float normalization for any `target` field. Suite unchanged at 97 cases / 101,355 checks; benchmark sim p95 1.498 / 1.529 ms; `/ponytail-review` removed one unreachable guard.
  - **Envelope spike** (scratch, headless): [note](reference/m4-scenario-envelope.md) with timeline, army sizes, travel, 19-tick building-death stall, allocation cost. Main finding: production stops at 8 infantry / about 11 tanks unless units are moved; armies about 19 per side; attack-start range corrected to 9000..9800.
  - **Plan**: new "Code anchors and pitfalls" section (11 items), Tasks 4, 5, 7 split into checkpoints with stop conditions and stronger-model review requests.
  - **Test appendix**: [unrun red-test sketches](superpowers/plans/2026-11-03-m4-tests-4-5.md) for Tasks 4 and 5.
- User decision: the building-death stall and allocation cost are documented only, not fixed; the executor stops and reports if they block a test or budget.
- Not verified: the appendix tests (written before the API exists), and whether Sonnet at medium finishes. Nothing committed or pushed.

## 2026-11-03 — M4 planning

- User confirmed positive M2 playability and no M3 visual issues; corrected M4 playtest mention to M3. Reference notes updated; no M4 playtest or performance measurements inferred.

- User explicitly approved M4 design. Updated design/plan/prompt status; no implementation kickoff or inherited-gate deferral inferred.

- Added proposed design, source/config evidence and sequential Sol/Medium execution plan. No game-code changes or implementation kickoff.
- Read hash-verified root INIZH.big and pinned official source; selected rifle burst/reload, tank, health/armor and barracks values. Geometry, direct-hit simplifications and runtime parity remain explicitly provisional/unverified.
- Fresh Sol/Medium builder check resolved mixed armed selection and real match-duration assertions. Final scripted schedule/outcome must be measured and pinned during bounded task7 calibration.
- User subsequently authorized M4 branch and Sol prompt preparation: created `m4-combat` from local `main` at `c441a7f`, preserving uncommitted planning files; replaced root `prompt.txt` with M4 handoff. Historical M3 prompt remains `docs/m3-prompt.txt`. No implementation kickoff.
- Existing runtime test counts remain historical; no game tests or visible checks run for planning/preparation. No commit/push/PR/merge.

## 2026-11-03 — M3 playtest and wrap-up

- Implementation `303006b` already published on `m3-base-supplies`. Verified [M3 matrix](https://github.com/pdstuber/wargrid/actions/runs/41605911340): Linux/macOS/Windows and compare-replays successful at that exact head.
- Default launcher intentionally opens M2; supplied explicit M3 base-scene command. User then reported “test was looking good”; detailed checklist coverage and rendered measurements were not supplied.
- User requested documentation consistency and local merge into `main`. Updated current status, preserved historical evidence and fast-forwarded `main` through wrap-up commit `17f2f12`. No production changes or new implementation review needed; previous substantive review and Ponytail pass remain applicable.
- Post-merge headless verification passed: 95 cases / 101,305 checks / zero failures / exit 0; Python 6 tests / exit 0. Sandbox import needed a retry with macOS settings access; no code fix. Docs: 103 local links, zero missing.
- Publishing `main` still needs approval. No M4, PR, screenshots or rendered benchmark.

## 2026-11-01 — M0 local foundation

- [Execution plan](superpowers/plans/2026-11-01-m0-foundation.md) local checks complete; remote gate pending.
- [Verification record](reference/m0-verification.md) contains counts, failure probes, source provenance, review result and limits.
- Sole completed substantive review found no production defects; final Ponytail pass found no cuts. Grok attempt stalled, then fresh-context fallback completed.
- No engine upgrade, visible window, retail-data access, commit, push, PR or M1 work.

## 2026-11-01 — Session commands

- Added `.claude/commands/kickoff.md` and `.claude/commands/wrapup.md`, delegating to agent-neutral docs.
- Replaced Last Hearth paper-run/ruleset steps with Wargrid verification and document ownership. Existing task instructions override a redundant kickoff question.
- No checker script, game behavior or Git action added.

## 2026-11-01 — Wrap-up trial

- Fresh headless wrapper run: 11 cases / 199 checks / 0 failures, exit 0; final completion marker present. Old test agent retained restrictive sandbox and failed during import; fresh agent passed with current permissions. No game changes needed.
- Fixed stale planning-only status in AGENTS by linking README; blueprint local checkboxes now match evidence. Remote CI checkbox remains open. No design decision changed.
- Checked local documentation links/paths and handoff headings. Existing implementation reviews retained; no duplicate review.
- Proposed first commit includes initial user-authored planning/reference files, M0 implementation and session commands. No staging, branch creation or commit before approval. `.godot` cache ignored; scratch evidence stays outside repo. No active Wargrid background process found.
- Process deviations retained: grouped acceptance red/green cycle; stalled Grok attempt replaced by sole completed fresh-context review. Optional coverage gaps stay deferred.

## 2026-11-01 — First-commit approval

- User explicitly approved branch `m0-foundation` and first commit `Initialize Wargrid M0 foundation and session workflow`, covering all 26 authored files.
- Approval includes planning/reference documentation, M0 implementation/tooling/CI and session workflow. Cache and temporary evidence excluded.
- No push, PR or merge authorized. Next gate is remote CI after separate push approval.

## 2026-11-01 — M0 coverage follow-up

- C4 explicitly checks normalized float types on both axes before/after execution. C10 covers tick/player/sequence canonical queue order without weakening accepted sequence rules.
- Local suite: 11 cases / 209 checks, exit 0. Five independent scratch regressions each fail behavior assertions; production untouched.
- Corrected historical review assumption: existing deep Dictionary comparisons also detect removed float conversion on this build; new explicit checks improve diagnostic precision.
- User provided Actions log; GitHub CLI independently confirmed successful run for `20739d6`. Original remote gate passed, updated tests still local.
- No new commit, push, PR, merge or M1 work authorized.

- Coverage follow-up review complete: no findings; final Ponytail pass found no cuts. Grok timed out; fresh-context fallback was sole completed substantive review.

## 2026-11-01 — Group coverage and local integration

- Grok whole-branch review completed without defects; coverage limits prompted public-API tests for successful multi-entity orders and exact entity-ID snapshot order.
- C1/C12 additions pass: 12 cases / 212 checks, exit 0. Scratch first-member-only and reverse-ID mutations fail behavioral checks, exit 1. Production unchanged.
- User authorized pending M0 test/documentation commit and local merge into `main`; no push. Neither local nor remote `main` exists, so initialize local `main` at original M0 commit before fast-forwarding reviewed follow-up.
- Forced internal insertion reordering is unreachable through current API; no test-only mutation hooks added. Earlier Grok attempts were stopped too soon; whole-branch review eventually completed by waiting.

- Focused Grok follow-up review completed with no defects; final Ponytail pass found no cuts. Integration verification runs on local `main`; read Git log/status for exact commit/branch state.

## 2026-11-01 — M1 planning

- User requested an execution plan suitable for Sol at Medium; no implementation request yet.
- Inspected production kernel, all 12 existing cases, runner, scene, wrappers and CI. Fresh baseline: 12 cases / 212 checks / exit 0 via test subagent.
- Added bounded static-grid movement, projection/view/input contracts, intentional M0 test migrations, headless scene cases and async-runner failure probes. Prototype choices remain labeled; no parity claims.
- Updated current prompt, README, AGENTS and blueprint links. No game code, visible launch, commit or push.

## 2026-11-01 — M1 planning wrap-up

- Documentation-only scope: M1 plan plus AGENTS, README, blueprint, prompt and this handoff. No game, test, wrapper or engine changes; no game test rerun required.
- Checked 38 local Markdown links/paths, four kickoff handoff headings and diff whitespace. Proposed plan paths for future implementation are not existing-file claims.
- M0 remains implemented; M1 remains proposed, with implementation awaiting explicit kickoff. Existing local test evidence and remote/visual/reference limits remain unchanged.
- Proposed branch `m1-vehicle-plan`, commit `Plan M1 vehicle slice and handoff`; no staging, branch creation, commit or push before approval. No design decisions changed during wrap-up.

## 2026-11-01 — M1 planning commit approval

- User explicitly approved branch `m1-vehicle-plan` and six-file documentation commit `Plan M1 vehicle slice and handoff`.
- No push, PR, merge or M1 implementation authorized.

## 2026-11-01 — Commit reference and remote-state check

- Verified `20739d6` is original M0, `7d67481` is M0 coverage follow-up, and `1a3e316` is M1 planning. Historical baseline hashes remain correct; no game/test/tool/CI changes between the latter two.
- GitHub branch API confirms `main` at `7d67481`, `m1-vehicle-plan` at `1a3e316`; default branch is `main`. Branch publication is observed state, not an inferred approval history.
- [M0 follow-up CI](https://github.com/pdstuber/wargrid/actions/runs/41299222791) and [M1 planning CI](https://github.com/pdstuber/wargrid/actions/runs/41301269564) both completed successfully; fetched logs show 12 cases / 212 checks / 0 failures and `TESTS PASSED 212`.
- Earlier dated pending-CI/approval notes describe their historical checkpoints. Current handoff supersedes them. `prompt.txt` contains no commit hashes and needs no correction.

## 2026-11-01 — Final documentation wrap-up

- Verified published `m1-vehicle-plan` at `3c0f150`, successful remote CI and GitHub default `main`. Publication observed, not performed during wrap-up; M1 branch remains unmerged.
- Corrected stale CI summaries in README, blueprint and M0 evidence; refreshed current handoff. No design or implementation change. Historical commit baselines retained.
- Documentation-only checks: local links/paths, kickoff headings, diff whitespace and status consistency. No game rerun, visible check or implementation review required. No stray untracked files or active game/test processes found.
- Proposed commit on `m1-vehicle-plan`: `Refresh wrap-up and verified CI summaries`. Commit awaits approval; no push, PR or merge included. Tomorrow: review M1 plan on this branch and choose whether to start implementation.

## 2026-11-01 — M1 implementation

- Followed adopted vehicle plan in order: projection/navigation red/green, movement and named M0 migrations, view picking, scene/input/camera. Pulled async runner setup forward only to enable scene red tests; recorded in session ledger.
- Red evidence: helper 13 failures; movement 39; view picking 3; scene skeleton 24. Diagnosed wrong arrow constants with engine-key assertions and double-transformed headless mouse injection; fixed config/injector, preserved production coordinate conversion and tolerances.
- `sh tools/run_tests.sh`: 32 cases / 1089 checks / 0 failures, exit 0, final marker. Outside-root and fresh-cache copy match. Pinned-engine headless smoke exit 0; all eight runner failure probes exit 1, including actual watchdog timeout.
- Existing test agents kept old sandbox across allow-all switch; fresh agent picked up current permissions. No project workaround needed.
- Batched visible check authorized. Game launched without diagnostics; Computer Use denied Godot access. User screenshot and second recording confirm static scene/HUD plus selection, moving targets, arrival and camera pan. User confirms resize/zoom and ignored blocked/outside clicks. Basic visible smoke covered; HUD error text/post-transform re-selection explicitly checked headlessly, not separately captured in video. No commit, push, PR, merge, engine upgrade or sibling edits. Sole Grok review complete; test gaps closed and mutation-verified. Ponytail pass found no cuts.

## 2026-11-01 — M1 final handoff

- Final exact checkout, outside-root and fresh-cache suites each pass: 32 cases / 1089 checks / 0 failures, exit 0, `TESTS PASSED 1089`. Headless smoke exit 0. Eight runner probes exit 1.
- Three review regressions each pass old check and fail tightened check; production unchanged after review. Grok completed substantive report; capture-shell readonly-variable error means its exit code unknown, not an unfinished review. No duplicate substantive review. Final Ponytail lean pass: no cuts.
- Basic visible smoke supported by second user recording plus reports: selection, movement around obstacle, retargeting, arrival, pan, resize/zoom and ignored blocked/outside targets. HUD rejection text/post-transform re-selection established automatically, not separately recorded visually. No exhaustive feel/performance/reference claim.
- README, movement/verification notes and plan checkboxes reflect local evidence. No commit, push, PR or merge; M1 remote CI pending approved publication. Stop at M1.

## 2026-11-01 — M1 commit approval

- User explicitly authorized committing everything currently in repo, including pre-existing documentation changes and reviewed M1 implementation/tests/evidence. No push, PR or merge included. Read Git log/status for resulting commit.


## 2026-11-02 — recovery and M3 planning

- Reconciled README, AGENTS, blueprint, M2 plan, reference status and root prompt against actual unfinished checkout. Game code untouched. Fresh delegated Godot result: 54 cases / 95,914 checks / 42 failures / exit1; Python comparator6 tests/exit0. Test subagent interruption recovered; original usage-limit stop unverified.
- User chose Zero Hour research first, then source-informed playable M3 slice; approved design for detailed planning. Read pinned GeneralsMD source and hash-verified root INIZH.big selected configuration. Original archives/source unchanged; no EA implementation/assets added. Research limits and explicit fixes recorded in M3 reference.
- Added M3 design, detailed sequential Sol/Medium execution plan, source/config record and separate docs/m3-prompt.txt. One fresh design builder check found no consequential gaps; plan self-review mapped scope, signatures, tests and lifecycle boundaries. Planning only; M2 gates precede M3 execution.
- User authorized future local M2 completion commits, local main merge and creation of m3-base-supplies carrying full repo/preparation documents. Root prompt includes exact handoff and installs M3 root prompt only after branch switch; no push/PR or M3 implementation during that run. No Git action performed here.
- Documentation verification delegated: diff whitespace and local Markdown link targets checked; final result recorded in response. No game rerun after documentation-only changes, no rendered checks, no M2 implementation review claimed.
