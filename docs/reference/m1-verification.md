# M1 verification — 2026-11-01

Implementation follows [M1 plan](../superpowers/plans/2026-11-01-m1-vehicle.md). Reference status: `UNVERIFIED_REFERENCE`; see [movement note](movement.md). Pinned local engine remains `4.7.2.stable.official.ed1daf0bf`. Wrappers and pinned CI unchanged.

## Baseline and red/green evidence

Baseline from pristine HEAD scratch: `sh tools/run_tests.sh`, 12 cases / 212 checks / 0 failures, exit 0, `TESTS PASSED 212`. Four pre-existing modified documentation files preserved; no M0 implementation rebuilt.

| Cycle | Red | Green |
|---|---|---|
| Projection/navigation | 18 cases / 261 checks / 13 behavioral failures / exit 1 | 18 / 269 / 0 / exit 0 |
| Movement and M0 migration | 26 / 1019 / 39 behavioral failures / exit 1 | 26 / 1019 / 0 / exit 0 |
| View picking | 27 / 1028 / 3 behavioral failures / exit 1 | Green in scene red run |
| Scene/input/camera | 32 / 1066 / 24 behavioral failures / exit 1 | 32 / 1087 / 0 / exit 0 |

Minimal valid schema/helper stubs enabled behavioral red runs. An initial navigation stub test indexed absent blocked-cell data; guarded access and reran red without runtime errors. First scene implementation run found wrong arrow constants through engine KEY assertions and selection failures; neither assertions nor tolerance changed to hide them. Scratch instrumentation showed headless window 64×64 versus logical viewport 1280×720. `Input.parse_input_event` converts window coordinates to viewport coordinates; tests injected viewport coordinates, applying stretch twice. Injector now uses `runner.root.get_final_transform()` before parsing; production `make_canvas_position_local` stays unchanged. Six pan/zoom combinations retain exact target assertions. Additional S1 engine-key assertions cover WASD/arrows/Escape; counts therefore grew from scene red.

## Intentional M0 test migration

All C1–C12 retained. C1 gains map/status/route literals. C2/C4 assert one movement budget instead of stationary position; C3 retains due-tick checks and adds no-early-motion/first-budget assertions. C4 retains both-axis target float-type checks. C5–C8 retain validation, ownership, sequence, malformed inputs and command-copy coverage. C9 mutates nested map/route data as well as prior snapshot aliases. C10 remains exact comparison across submission orders. C11 retains full tick/ID/queue/sequence comparison and now expects exact arrived target with cleared route/order. C12 retains sorted IDs, both accepted members and independent targets, and checks each moves within one budget. No stationary compatibility mode.

## Final local commands

All run headlessly through test subagents, using unchanged wrappers and pinned engine. No error diagnostics; suite runs require both exit 0 and final marker.

| Command / location | Result |
|---|---|
| `sh tools/run_tests.sh` from repo | 32 cases / 1089 checks / 0 failures, exit 0, `TESTS PASSED 1089` |
| `sh /Users/pdstuber/projects/wargrid/tools/run_tests.sh` from `/tmp` | Same counts/marker, exit 0 |
| `sh tools/run_tests.sh` in fresh scratch `game/` + `tools/` copy excluding `.godot` | Same counts/marker, exit 0 |
| `godot --headless --path game --quit-after 30` | Exit 0, no diagnostics |
| `godot --version` | `4.7.2.stable.official.ed1daf0bf` |

## Runner failure probes

Isolated scratch copies replace suite registration and probe source; production runner remains unchanged. All eight wrapper runs exit 1; none prints success marker.

| Probe | Observed failure |
|---|---|
| False check | 1 case / 1 check / 1 failure |
| Empty suite | 0 cases / 0 checks / 2 failures |
| Suite parse error | Import/parse diagnostics rejected |
| Synchronous check then early return | Incomplete case; 1 case / 1 check / 1 failure |
| Coroutine after await checks then early returns | Incomplete case; 1 case / 1 check / 1 failure |
| Coroutine runtime error after await, later passing case | Runtime diagnostic + incomplete case; later pass reached; 2 cases / 2 checks / 1 failure |
| Synchronous runtime error, later passing case | Same safety behavior and counts |
| Abandoned coroutine waiting on unsent signal | `FAIL: watchdog timeout in probe`, exit 1 after 60-second runner deadline (61.6 s including import) |

Probes and logs stored in session scratch `/tmp/wargrid-m1/probes`; not build dependencies or tracked source. Initial sandbox blocked Godot editor-setting writes. Early test agents retained old sandbox after permission change; fresh agent ran verification without escalation. No project workaround or environment-setting change needed.

## Review and remaining gates

Single Grok review completed against tracked and untracked M1 files. No production correctness defect; three test gaps fixed: S2 now verifies non-center `(4.25,3.1)` click, S4 checks both diagonal axes, N5 fixture distinguishes row-first sorting and same-row x order. Three isolated production mutations pass corresponding old tests and fail tightened tests: cell-center snapping → S2; small-delta diagonal Y omission → S4; x-first map sort → N5. Final suite grows to 1089 checks; no production behavior or tolerance changed. Grok's wrapper ended with zsh readonly `status` assignment error after review output; Grok's own exit code was not captured. Completed findings/coverage map are present; no second substantive reviewer run.

Final `/ponytail-review` lean pass: no cuts at one-vehicle scope. Existing wrappers, built-in A*, pure projection and copied-state view reused; no dependency/framework/future system added. Remote CI for M1 pending approved push; existing M0/planning CI does not verify new implementation. Visible evidence is bounded by smoke scope below; exhaustive visual quality, feel, performance, cross-platform determinism and Zero Hour parity unverified. No commit, push, PR, merge, engine upgrade or sibling-project edit performed.

## Review coverage map

Reviewer named production changes that each case detects; one representative per case retained here. No whole case vacuous. Corrected checks are included below.

| Case | Production regression detected |
|---|---|
| C1 | Consume ID on rejected spawn |
| C2 | Skip movement on apply tick |
| C3 | Apply future command early |
| C4 | Keep first replacement target or lose target float normalization |
| C5 | Accept another player's entity |
| C6 | Accept duplicate sequence |
| C7 | Accept nonfinite target or retain unknown command fields |
| C8 | Alias caller command arrays |
| C9 | Return shallow nested snapshot |
| C10 | Retain submission order instead of canonical pending order |
| C11 | Ignore future retarget or retain order after arrival |
| C12 | Apply accepted group order to only first ID |
| P1 | Change projection scale or break inverse |
| N1 | Accept solid/out-of-bounds endpoint |
| N2 | Omit required start center or exact target |
| N3 | Allow diagonal obstacle route or wrong distance |
| N4 | Permit diagonal escape or wall crossing |
| N5 | Sort x-first, omit deduplication or alias returned cells |
| M1 | Change speed or fail to finish at 30 ticks |
| M2 | Overshoot short target or leave same-position order active |
| M3 | Spend budget on replaced order |
| M4 | Move during submission/read or exceed tick budget |
| M5 | Cross solid or miss 40-tick arrival |
| M6 | Reject unreachable walkable target at submission or fail recovery |
| M7 | Consume ID/sequence on spatial rejection |
| M8 | Let snapshot mutations alter next step or break exact replay |
| V1 | Pick outside bounds/other owner or retain caller state alias |
| S1 | Spawn twice or change map count, input bindings, renderer/tick/HUD settings |
| S2 | Skip camera inverse, snap non-center click or queue wrong command envelope |
| S3 | Consume sequence on rejected target or omit HUD/deselect behavior |
| S4 | Omit zoom division, diagonal Y motion or camera clamp |
| S5 | Remove/duplicate physics callback step |

Review limits: no call-count assertion for repeated empty repaths, no held-key injection through live `_process`, and no dedicated mutation guard for an extra render-callback tick. Production only advances from physics callback and routes only replacement orders; no test-only instrumentation added. Wrapper checks error-log silence across invalid navigation queries. Rendering pixels, performance, remote CI and reference parity remain separate evidence tracks. Excluded groups/dynamic blockers/polish/network judged outside M1; pre-existing dirty docs preserved and status updated within authorized scope.

## Visible smoke

User authorized batched visible play/screenshots. `sh tools/run_game.sh` launched pinned Compatibility renderer without diagnostics. Computer Use refused Godot access (`Computer Use was not approved to use Godot`); user supplied evidence instead.

| Evidence | Observed scope |
|---|---|
| Screenshot `codex-clipboard-yYHg87.png` | Map, obstacle, vehicle and readable HUD render; idle state, tick advancing |
| `Screen Recording 2026-11-01 at 16.24.11.mov` | Selection outline; changing targets while moving; travel on sand around obstacle; arrival clears target cross; camera pan with fixed HUD |
| User report | Resize and zoom work; blocked/outside targets ignored without unwanted movement |

Second recording supersedes less useful 16.23.46 clip. Inspected extracted frames at one-second intervals plus contact sheet (18.408 s source, 1504×1008, 60 fps). Basic visible smoke passes within listed scope. Explicit HUD rejection text and post-transform re-selection were not separately captured; automated S2/S3 cover them. Continuous frame-by-frame collision, quantitative feel/frame-time, exhaustive legibility and parity not established. Original media stays outside repo; analysis frames remain session scratch.
