# M3 — base and supplies implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: use `superpowers:executing-plans`, sequentially in main session. Executor: Sol at Medium reasoning. Delegate test/build/lint commands; one substantive final reviewer and one Ponytail cuts pass. No per-task implementation/reviewer fan-out and no automatic commits.

**Goal:** playable dozer → reactor → depot/collector → factory → paid vehicle loop, with exact accounting, finite supplies, power and cancellation behavior.

**Architecture:** extend existing Simulation with owned economy dictionaries, explicit command variants and three small internal domain helpers. Reuse M2 navigation/reservations for ground units; collectors use direct bounded flight. Add one base scene using existing presentation/input foundations.

**Tech stack:** Godot 4.7.2, typed GDScript, Compatibility renderer, 30 Hz ticks, existing runner/wrappers/CI, standard-library Python comparator; no new dependencies.

**Spec:** [approved design](../specs/2026-11-02-m3-base-supplies-design.md), [reference evidence](../../reference/m3-economy.md), blueprint M3. Read both fully. User explicitly kicked off M3 on2026-11-03 after verified M2 remote matrix and accepted risk from deferred M2 visible/play/rendered/backlog gates. Those gates remain pending. [Verification](../../reference/m3-verification.md) records execution progress and remaining M3 gates.

## Global constraints and starting checkpoint

- Read AGENTS, README, current session handoff, M1/M2 plans and actual final M2 implementation. Do not implement against recovery stubs. Reconcile changed M2 private names before edits; record any necessary plan adjustment without altering contracts silently.
- Work on `m3-base-supplies` created from verified local `main` after M2 integration. Do not create another worktree/branch by habit. Preserve user edits. No push, PR, merge or M3 commit without new authorization.
- Scope only approved design: one builder, three building kinds, two produced unit kinds, finite source, 9-entry FIFO, no combat/sale/upgrade/AI/faction framework. M2 movement benchmark stays intact.
- Store credits/boxes/work/timers as integers. Use source-derived nominal costs/times and explicit Wargrid geometry from design. Never transplant source code/assets or depend on retail data in tests/runtime.
- Work rate 1000 at sufficient power or zero demand; deficit rate `clampi(int(supply * 1000 / demand), 500, 800)`. All quantities nonnegative; required work = nominal ticks × 1000. No float progress accumulator.
- Full suite must exit 0, print positive `TESTS PASSED N`, and emit no engine diagnostics. Record cases/checks; never require a guessed future count or relax assertions to green. No elapsed-time threshold in ordinary tests.
- Headless only unless user grants batched visible checks. Final evidence separates correctness, performance, remote CI and reference fidelity. Stop at M3.

## Review focus

1. Two accepted future transactions compete for funds/space; only canonical winner charges/creates. Task 2/4.
2. Cancellation/removal at completion boundary must refund once and leave no stale route, dock, queue or binding. Tasks 4/6/8.
3. Power transition must neither regress nor retroactively accelerate earned work; rate is same for all buildings that tick. Tasks 5/6.
4. Last source box, partial load and lost depot must preserve stock/cargo/credit conservation. Tasks 7/8.
5. Ready factory exit, UI drag/placement conflicts and input consumed by buttons must not duplicate units/orders. Tasks 6/10.

## Files and responsibilities

| Path | Work |
|---|---|
| `game/scripts/simulation/simulation.gd` | authoritative state, scenario APIs, command validation/dispatch, intent resolution, tick phases, snapshots |
| `game/scripts/simulation/economy_definitions.gd` (new) | immutable-by-copy selected type definitions, constants, integer rate function |
| `game/scripts/simulation/construction.gd` (new) | placement/approach validation, foundation/pause/resume/cancel, work and footprint union |
| `game/scripts/simulation/production.gd` (new) | paid FIFO, exact-entry cancellation, ready spawn/blocked exit, removal refunds |
| `game/scripts/simulation/supply_collection.gd` (new) | source/depot lookup, single dock admission, box timers/transfer, recovery |
| `game/scripts/presentation/world_view.gd` | building/source placeholders, airborne offset/shadow, object picking and footprint preview |
| `game/scripts/main.gd` | three small scene hooks; retain M2 movement scene behavior |
| `game/scripts/base_main.gd`, `game/scenes/base.tscn` (new) | authored M3 scenario and economy HUD/input; inherits existing main script |
| `game/tests/test_economy.gd`, `test_construction.gd`, `test_production.gd`, `test_supply.gd`, `test_base_scene.gd` (new) | focused behavior suites registered in existing runner |
| `game/tests/economy_fixture.gd` (new) | command/build/step helpers shared by above suites, using public API only |
| Existing simulation/group/repath/view/scene/replay tests | explicit additive snapshot migrations and regression coverage |
| `game/tests/test_replay.gd` | retain M2 replay, add M3 replay and separate trace |
| `.github/workflows/tests.yml`, `tools/compare_replays.py`, `tools/test_compare_replays.py` | only trace wiring required; retain existing strict comparator format |
| README, blueprint links, session notes, `docs/reference/m3-verification.md` (new) | measured results, test migrations, reviews and remaining gates |

Do not split helpers further without an observed readability problem. Domain helpers are static functions accepting `sim: RefCounted`; they may access Simulation's documented internal dictionaries. No copies of authoritative state in helpers, no callbacks/events/service locator. Tests exercise public Simulation API except pure definitions.

## Exact interfaces and state

### Public Simulation surface

Preserve constructor `_init(blocked_cells: Array[Vector2i] = [], size: Vector2i = Navigation.SIZE)` and existing `issue_command`, `step`, `snapshot`, `replace_blocked_cells` return shapes. Add:

- `spawn(owner: int, position: Vector2, kind: String = "vehicle") -> int`; kinds vehicle/builder/collector only; invalid returns -1 without consuming ID. Owner remains positive; existing movement-only worlds need no player record. Air spawn needs finite in-bounds position but ignores ground occupancy/solids.
- `add_player(player: int, credits: int) -> Dictionary`; positive new player, nonnegative credits; duplicate rejects unchanged. No currency setter.
- `add_supply_source(origin: Vector2i, boxes: int) -> int`; fixed 3×3 neutral rectangle, nonnegative boxes, same footprint overlap/bounds/ground-occupancy checks as foundations, without builder/funds/prerequisite checks; invalid -1/unchanged. Zero-box source allowed and remains on map.
- `remove_object(id: int) -> Dictionary`; synchronous scenario operation; unknown ID rejects unchanged. No player destroy command or combat.
- `preview_build(player: int, builder_id: int, kind: String, origin: Vector2i) -> Dictionary`; same current validation as build, copied `{ok,error,cells,approach}`; cells are row-major `[x,y]` arrays, approach null on failure or `[float,float]` on success. Absolutely no mutation/path request/ID allocation.

All Dictionary operation results remain `{ok: bool, error: String}` except preview's additional documented fields. IDs share `_next_entity_id` for units/buildings/sources; production entries share `_next_production_id`, starting 1. Add `_players`, `_buildings`, `_sources`, `_terrain_cells`, `_command_results`; internal dictionaries keyed by integer IDs. Constructor copies terrain. Domain helper methods use these directly, not public mutable accessors.

Snapshot additions (all arrays sorted by ID except FIFO queue):

- Mobile entity adds `kind: String`, `construction_id: null|int`, `collection: null|Dictionary`. Keep every M2 field and float position/target normalization.
- `players: [{id,credits,power_supply,power_demand,work_rate}]`.
- `buildings: [{id,owner,kind,origin:[int,int],completed:bool,work:int,paid_cost:int,builder_id:null|int,approach:null|[float,float],queue:Array,active_collector_id:null|int}]`. Footprint/nominal work derived from kind. No completion-grant flag: only false→true completion path grants free collector, and air spawn cannot be blocked after validated center bounds.
- Queue entry `{id,kind,paid_cost,work}`; ready means work == required work. No redundant percent/status.
- `sources: [{id,origin:[int,int],boxes:int,active_collector_id:null|int}]`.
- Collector `collection` contains `{enabled:bool,preferred_source_id:null|int,target_id:null|int,phase:String,remaining_ticks:int,retry_tick:int,cargo:int}`; initial enabled false, phase idle, all numbers 0, targets null. Other units have null collection.
- `terrain_cells: [[x,y],...]` canonical row-major, distinct from existing `map.blocked_cells` union. `next_production_id`, `command_results` (last completed tick only; empty initially/cleared at next step start). Results only for non-move commands: `{tick,player,sequence,ok,error}`.

Copy deeply, including unit collection, building queues, targets and result errors. Derived power need not be stored separately. Empty economy world still gains empty root fields and default mobile fields; migrate exact literals explicitly, not by dropping equality checks.

### Commands

All use existing envelope `tick`, `player`, `sequence`, `type`. Variant payloads:

| type | required payload | atomic rejection conditions beyond envelope |
|---|---|---|
| move | existing `entity_ids`, `target` | preserve M2 validation; any ground member requires walkable target; all-air needs only bounds/finite |
| build | `builder_id:int`, `building_kind:String`, `origin:[int,int]` | owned builder, player registered, known kind, complete prerequisite, funds, valid footprint/approach |
| resume_build | `builder_id:int`, `building_id:int` | owned builder + own incomplete foundation; legal reachable adjacent approach |
| cancel_build | `building_id:int` | own incomplete foundation |
| produce | `building_id:int`, `unit_kind:String` | own complete matching producer, completed prerequisite at enqueue, funds, queue<9 |
| cancel_production | `building_id:int`, `production_id:int` | own producer contains exact entry |
| gather | `entity_ids:Array[int]`, `source_id:int` | nonempty unique own collectors, registered player, existing source; boxes>0 or every selected collector already carries cargo |
| stop | `entity_ids:Array[int]` | nonempty unique own mobile IDs |

Reject wrong types including bool where int expected, malformed arrays, nonfinite coordinates, unknown IDs/owners/types, duplicate IDs and missing fields without snapshot mutation. Preserve existing policy for surplus fields; normalize only required recognized fields into copied queued command. Missing player record affects economic types, not old move/stop.

Issue-time eligibility is checked against present world, never speculative queued prerequisite/funds. Due-time rechecks mutable facts; earlier valid transactions may make later fail. Accepted sequence is consumed even if later execution fails. `_validate` must take validation stage or call separated shape/current-state routines; do not duplicate large validators. For due move, changed blockers cause M2 allocation failure/blocked state, not replacement of old snapshot semantics.

### Internal helper boundaries

`EconomyDefinitions.unit(kind: String) -> Dictionary`, `building(kind: String) -> Dictionary` return fresh copies or `{}` for unknown; `work_rate(supply:int,demand:int)->int`. Definitions keys: unit `{cost,ticks,speed,air,producer}`; building `{cost,ticks,power,footprint:Vector2i,prerequisite,produces}`. Builder definition cost1000/ticks150/producer empty, recorded but not producible; builder/vehicle speed3, collector6. Empty string means none.

Construction static methods: `preview(sim,player,builder_id,kind,origin)->Dictionary`, `place(sim,command)->Dictionary` (result plus `building_id` and `approach` only on success), `resume(sim,command)->Dictionary` (result plus approach), `cancel(sim,building_id)->void`, `step(sim,rates:Dictionary)->void`, `rebuild_navigation(sim)->void`. Caller validates first; helper still computes placement transaction before charging. Shared `_result` helper only if existing code already warrants one.

Production: `enqueue(sim,building_id,kind)->void`, `cancel(sim,building_id,entry_id)->void`, `refund_all(sim,building_id)->void`, `step(sim,rates:Dictionary)->void`. Queue validation owned by command layer. Supply: `release(sim,unit_id)->void`, `step(sim,unit_ids:Array[int])->void`, `object_removed(sim,id)->void`. Scenario removal in Simulation orchestrates helpers in deterministic order.

`_apply_orders` becomes due-command dispatcher, preserving existing canonical comparator. Accumulate final successful mobile intents in local map `{unit_id: {command,kind,building_id,goal}}` as needed; not persistent state. Apply monetary transactions in order before intent binding. Successful build inserts unattached foundation; final builder intent attaches it. Failed later command never replaces prior successful intent. Cancelled/removed intent targets are discarded at binding. Release all replaced ground destinations before allocating final intent subsets, preserving M2 coalescing. Apply goals in command order, IDs sorted. No command callback object framework.

Intent attachment enforces one builder per foundation: detach previous builder from this building and previous building from this builder; stop displaced builder's construction intent without erasing unrelated manual orders. Stop/manual move releases collector dock and disables auto mode, retains cargo. Completion clears construction binding but preserves builder at arrived approach/destination. Cancel/removal of its active foundation stops builder (idle, empty order/route/destination, removed path entry); unrelated manual orders survive. Ground route queue contains only ground units; collection air motion never queries A*. Canceled construction intents are discarded before releasing prior manual orders, preserving unrelated movement.

Tick order is approved design's order. Capture mobile IDs before progress; new units skip collection/movement until next tick. Rate dictionary captured once before construction/production. Construction-completed producer cannot accrue paid queue work same tick unless queue existed already (impossible through valid commands); depot free spawn activates next tick. Missing/removed IDs safely skipped. `replace_blocked_cells` now replaces authored terrain only; reject new terrain overlapping existing building/source footprints or ground units, then validate union before mutation. Removal/placement rebuild union once and use M2 repath rules; air units excluded from all ground occupancy checks.

## Execution loop

For each numbered task: write specified behavior cases using `cases()`/`runner.check`/`return true`; register suite; delegate `sh tools/run_tests.sh`, record expected behavioral failures; implement only task; delegate same command and require exit0/positive marker. Parse errors or absent method alone are not behavioral red evidence: add minimal typed stub then demonstrate asserted behavior failure. Do not commit between tasks. Record checkpoint in M3 verification note after green so interrupted sessions resume without replaying completed work. Python comparator command: `python3 -m unittest discover -s tools -p 'test_compare_replays.py'`.

### Task 0 — verify completed M2 handoff

- [x] Inspect Git branch/status/log and four M3 prep files. Read final M2 evidence, confirm local correctness/review/performance and required visible gates or explicit user-approved deferrals. Remote CI alone may remain explicitly pending under authorized local-only handoff; it is not proof of cross-platform success. No implementation if milestone remains blocked.
- [x] Delegate full headless baseline and comparator; record counts/markers/exit status. Resolve unexpected failures using systematic debugging, never overwrite M2 code from this plan.
- [x] Map existing Main input/selection methods and snapshot literals to contracts above. Record exact changed-file list. Create M3 verification note with baseline and all future gates pending.

### Task 1 — definitions, players, kinds and snapshots

**Files:** definitions, simulation, new test_economy/fixture, runner; existing exact-state tests.

- [x] Add E1 definitions test: reactor cost800/ticks300/power5/2×2; depot2000/300/-1/3×3; factory2000/450/-1; collector1200/300/speed6/air; vehicle700/300/speed3/ground. Mutate returned record; next read unchanged. Unknown definition empty.
- [x] Add E2 player/spawn tests: add player(1,10000) succeeds once; duplicate/negative/wrong owner reject atomically. Existing `spawn(1, Vector2(1.5,1.5))` returns vehicle. Builder supported; unknown kind returns -1, next ID unchanged. Air rules tested task3.
- [x] Migrate exact snapshot literals in existing tests to additive root/mobile fields. E3 mutates copied player, entity kind/collection and terrain arrays; live snapshot unchanged; initial root arrays and production ID exact.
- [x] Implement definitions/state/snapshots only; do not start economic commands. Complete red/green loop. Fixture exposes `make_world(credits:int=10000,size:Vector2i=Vector2i(32,32))->RefCounted`, creates player1 and builder at (4.5,4.5); `send(sim,payload:Dictionary)->Dictionary` adds current tick/player1/next sequence from snapshot, without overriding supplied future tick. No private state mutation.

### Task 2 — command variants and due-time transaction contract

**Files:** simulation, economy tests/fixture.

- [x] E4 malformed command table: missing each required field; bool/string IDs; fractional origins; unknown types; duplicate/mixed-owner arrays; mutation after acceptance; nonincreasing sequence. Rejected snapshots equal before, including sequence/ID/credits/results.
- [x] E5 queue copy test: future `stop` and `gather`/build validation use only existing objects; copied payload can't mutate pending. Future type-specific orders apply only at exact tick. Non-move results contain processed envelope and outcome for one tick, clear on next; immediate rejected order adds no result.
- [x] Implement shared envelope/variant validation, normalized copies and dispatch skeleton with typed domain stubs for later tasks. Keep currently unavailable variants returning explicit rejection until their owning task; do not claim deferred tests passed. Task2 green covers move/stop/result lifecycle; concrete build/fund-race tests land task4.
- [x] E6 preserve all M2 same-tick group/sequence/replay tests. Stop clears order/route/destination/queue; next unit retains existing path. Later failed command cannot erase accepted earlier intent. Delegate red/green.

### Task 3 — limited air movement and ground isolation

**Files:** simulation movement/spawn/navigation calls, economy/group/repath tests.

- [x] E7 spawn collector above blocked cell and ground unit; succeeds, ground reservation unchanged. Ground cannot spawn on existing ground occupant/reservation. Air still rejects outside/NaN/Inf; no consumed IDs.
- [x] E8 air travel (1.5,1.5)→(4.5,1.5) across full wall: moves .2/tick, arrives exactly after15 steps, no path queue/query. Existing ground .1/tick/blocked semantics unchanged. Mixed command separates air/ground correctly; mixed target on solid rejects whole command, all-air target on solid accepted.
- [x] E9 obstacle edits may cover airborne unit; never ground unit. Air unaffected by conservative ground repath. Manual move/stop on collector retains cargo when supplied later; add initial zero-cargo assertions now.
- [x] Implement per-kind speed/ground filters, direct flight via existing movement machinery where readable; no second tick loop. Delegate red/green.

### Task 4 — placement, travel, pause, resume and cancellation

**Files:** construction, simulation dispatch/terrain/removal, construction tests/fixture.

- [x] Cn1 preview is pure and equals execution legality: funds799 rejects reactor; exact800 succeeds; 2×2 origin(8,4) legal and produces cells[(8,4),(9,4),(8,5),(9,5)]. Reject boundary, terrain/source/building overlap, ground current/reserved cell, unreachable approach and wrong builder; every failure leaves snapshot unchanged.
- [x] Cn2 first placement tick charges800 and inserts foundation/union blockers; travel yields work0 until builder already at approach. Approach nearest squared distance then y/x. Work begins on phase after arrival, rises1000 per active tick. At299 active ticks incomplete; at300 complete. Foundation unlocks nothing until complete.
- [x] Cn3 move-away/stop retains paid foundation/work. Resume same/new owned builder continues; previous binding cleared. Builder disappearance pauses; existing source/terrain blockers survive cancellation. Unknown/cancel complete rejects.
- [x] Cn4 cancel at0 and299000 work returns800 once and releases builder/routes/footprint; accepted duplicate future cancels: first refunds, second due result fails, no second refund. Destruction of incomplete foundation refunds0.
- [x] Cn5 two future reactor commands valid at issue with800 credits: canonical first charges/creates, second due rejects, credits0, one foundation, no ID gap for failed command. Two same-footprint placements same behavior. Build then move same tick creates paid paused foundation; move then failed build preserves move. Same-tick building cancellation leaves no stale final intent.
- [x] Implement `preview/place/resume/cancel/rebuild_navigation`, due transactions/final intents and builder work. Fixture `build(runner,sim,kind,origin,max_ticks=3000)->int` uses public command and bounded stepping until new building completed; fails on no progress/execution error, never teleports/injects work. Delegate red/green.

### Task 5 — prerequisites and power work

**Files:** definitions rate, construction/power derivation, economy/construction tests.

- [x] E10 exact pure rates: (0,0)=1000, (0,2)=500, (5,2)=1000, (5,5)=1000, (5,6)=800, (5,10)=500. Integer output; no floating source duration recomputation.
- [x] Cn6 unfinished reactor doesn't unlock depot; complete does. Factory requires completed depot. Power supply/demand zero for foundations; reactor completion +5, depot completion demand+1, removal reverses exactly once. At low power, both builder work and later production use same captured owner rate.
- [x] Cn7 accumulated work transition: partially completed structure receives150 full-rate work ticks (150000), then only500 each after reactor removed where demand>0; no regression/jump. Completing a reactor midway through building-ID traversal changes all work rates only next tick, independent of insertion order.
- [x] Implement owner rate capture and completed-prerequisite checks. Delegate red/green. Do not add generic tech tree or power-disable statuses.

### Task 6 — FIFO production, refunds and blocked exits

**Files:** production, simulation dispatch/completion/removal, production tests.

- [x] P1 complete depot grants exactly one zero-cargo auto-enabled collector; repeated step/snapshot grants none. Depot accepts collector only, factory vehicle only; wrong/incomplete/enemy producer rejects. Paid queue entries charge immediately and have globally unique production IDs, copied snapshots.
- [x] P2 enqueue2 vehicles at factory costs1400; each needs300 full-rate ticks; only first progresses. After first completion next remainswork0 until next tick. Queue cap9; tenth rejection preserves funds/sequence. Cancellation by ID of active/middle/ready entry refunds stored700 and preserves other entries/order. Missing/foreign/duplicate cancel refunds0.
- [x] P3 prototype exit perimeter cells in y/x order. Occupy/reserve all perimeter cells: head reaches300000 then waits, no unit/ID change or next-head work. Move blocker aside: creates exactly1 vehicle at first free cell, pays no second cost. Ready cancellation refunds once. Collector spawn over depot uses air and cannot be ground-blocked.
- [x] P4 production150 full-rate ticks then remove reactor with positive demand: remaining150000 takes300 half-rate ticks; finish total450 work ticks. Removing prerequisite after enqueue retains queue. Producer removal refunds every paid entry once; completed units remain. Free collector not refunded as queue item.
- [x] Implement paid FIFO and deterministic exits. Use captured mobile IDs to keep completion-spawned units inactive until next tick. Delegate red/green.

### Task 7 — finite source and timed collection

**Files:** supply helper, simulation source API/collection dispatch, supply tests.

- [x] Su1 source200 boxes reserves3×3; invalid source placement/negative stock rejects without ID changes. Source0 valid; empty collector cannot gather it, loaded collector may resume delivery through it. All selected collectors must be loaded if source is empty. Gather requires all owned collectors, nonempty source; invalid mixed array leaves everyone unchanged.
- [x] Su2 collector positioned at source dock: first phase admits/sets36; next35 phases cargo0; next phase cargo1, stock decremented1, delay36 again. At8 boxes sets seeking/departs without ninth full delay. No credits until depot action; depot initializes87, no deposit for86 following phases, next phase credits600 and cargo0 exactly once.
- [x] Su3 source9 boxes and one collector delivers8 then1: total675 credits; source0/cargo0; no negatives and no idle earnings. Source3 boxes produces225 partial deposit. Assert stock+cargo+deposited boxes constant at every sampled tick.
- [x] Su4 two collectors race for one box: exactly one gets it, total deposit75; one active dock, deterministic ID admission. Loaded collector chooses nearest owned complete depot, tie lower ID; rejects unfinished/enemy. Empty collector prefers valid commanded source else nearest nonempty by distance/ID. No source/depot pauses safely with30-tick retries, no A* calls.
- [x] Implement single-active dock with explicit one transition per collector/phase. Dock waiting acquires only at current exact dock position. After transfer/depletion release slot, set seeking and next-tick retry; don't process departure target twice in same phase. Existing zero-economy worlds unaffected. Delegate red/green.

### Task 8 — interruption/removal and whole-loop accounting

**Files:** simulation scenario removal/intent binding, construction/production/supply helpers; corresponding suites.

- [x] Su5 manual move/stop during flight/loading/unloading releases dock, disables loop, retains cargo; later gather reenables and delivers existing cargo before collecting more, including an exhausted but existing preferred source. Invalid replacement command leaves previous action/dock unchanged.
- [x] Su6 remove source/depot at each of travel, wait, active delay, final-transfer boundary. Loaded surviving collector retains cargo and chooses replacement; no depot keeps cargo, new completed depot lets retry succeed. Collector removal loses only its known cargo and frees dock. No dangling active IDs after repeated removal attempts.
- [x] E11 public removal unknown ID unchanged; builder removal pauses, foundation deletion costs lost, completed producer refunds only queue, power/terrain union recomputed. Pending commands targeting removed objects fail at due tick without crashing or consuming entity IDs. Add source stock/remaining targets to snapshot-copy mutation test.
- [x] E12 integrated ledger scenario: start10000; build reactor/depot/factory (spend4800); deposit exactly one8-box load (+600); stop collector before another deposit; queue/complete vehicle (-700). Final credits5100, one free collector, one paid vehicle; source depletion8 plus any carried boxes accounted explicitly. Use 8-box source in this fixture so no hidden second load. All orders through API; bound whole scenario at10000 ticks and assert completion/progress.
- [x] Implement missing cleanup once in shared removal/release paths; no silent deletion of invalid orders without observable economic result. Delegate red/green.

### Task 9 — presentation and reusable scene hooks

**Files:** world_view, main, base_main/base scene skeleton, view/base tests.

- [x] V3 WorldView accepts full snapshots and selection arrays; draws/picks mobile objects, completed/foundation footprints and neutral source; unknown/empty arrays safe. Unit hit precedence over building/source; footprint edges inclusive; enemy selectable only if existing M2 ownership policy allows (commands still reject); base scene selects owned buildings only. Draw order stays grounded, air shadow uses projected ground position with fixed visual height only.
- [x] V4 preview transforms correct at zoom .5/1/2 and two camera centers; preview cannot mutate snapshot/navigation. Foundation progress and power/credits display derive snapshots, never wall clock.
- [x] Extract `_create_simulation() -> RefCounted`, `_refresh_hud(state: Dictionary) -> void` and `_view_selection() -> Array[int]` hooks in Main; `_ready` and `_refresh` call them. Default view selection returns copied selected_ids; BaseMain returns selected building ID singleton when selected, otherwise mobile IDs. Expose `is_selecting() -> bool` from existing active-selection gesture state for base input guard. Preserve M2 scene behavior/test assertions; no generic controller framework.
- [x] BaseMain extends Main, overrides hooks and `_unhandled_input`, delegates unconsumed events to parent. Scene keeps same required WorldView/Camera2D/HUD/Status/SelectionBox paths, adds economy controls. BaseMain consumes B without calling parent M2 obstacle-demo toggle, so its terrain cannot change through that debug key. WorldView adds `pick_object(plane_point:Vector2)->int` (units first, then building/source footprint by ID tie) and `set_build_preview(cells:Array[Vector2i],valid:bool)->void`, copying cells; empty clears. Existing pick_entity/pick_entities unchanged for M2.
- [x] Implement placeholders only, no image assets/editor clicks. Delegate full suite, not just new view cases.

### Task 10 — playable base controls and HUD

**Files:** base script/scene, test_base_scene.

- [x] Bs1 scene creates32×32, player1 credits10000, builder(4.5,4.5), source origin(24,4),200 boxes, no buildings/collector. Physics drives existing step exactly once; camera clamps to projected map corners. M2 main still starts20 vehicles.
- [x] Bs2 builder-selected keys1/2/3 enter placement; hover preview snaps/follows transformed pointer; left release issues1 build; invalid placement remains mode with reason; successful placement exits. Escape/right click cancels preview with no order/spend, preserves selection. Placement freezes selection gesture and consumes wheel/pan according to existing gesture rule; mode switch during active selection waits until gesture ends.
- [x] Bs3 left-click owned building selects it and clears mobile selection. Produce/E queues selected producer's one kind once. Cancel buttons use stable entry IDs, not row index; unfinished building Cancel sends cancel_build. GUI mouse events never reach world selection/move.
- [x] Bs4 builder right-click unfinished own foundation resumes; collector right-click source gathers; mixed mobile contextual click rejects with reason (choose homogeneous builder or collector selection), ordinary ground click preserves mixed move behavior. Ignore context while is_selecting. Same camera/zoom/reverse-drag coverage as M2; no mutation from HUD refresh.
- [x] Bs5 future execution rejection shows latest matching player result; immediate rejection remains visible until next user command or new result, never overwritten by unrelated player's result. Accepted UI issue clears stale immediate error; due failure restores text. Expose `selected_building_id:int=-1` in BaseMain only; clear it if building vanishes, and verify selection outline follows same ID.
- [x] Implement handlers using same command envelope/sequence path as parent; one `_submit(payload:Dictionary)->void` in Main may replace existing `_move` envelope duplication if needed for both scenes now. Test command count, envelope and last sequence instead of only label text. Delegate red/green.

### Task 11 — M3 exact replay and cross-platform wiring

**Files:** replay suite, CI, comparator tests only if required.

- [x] Keep original M2 1200-tick scenario/trace unchanged except new additive snapshots. Add two-world M3 replay advancing1200 ticks with scheduled build/cancel, produce/cancel, gather, power/removal and invalid/future commands; enough scenario setup before trace to include complete producers. Setup through public fixture commands, deterministic; no script-private state mutation.
- [x] For each tick compare entire snapshot exactly, including costs/work/docks/remaining timers/results/next IDs. Mutating returned snapshot has no effect. A scratch one-credit/one-box/one-work-unit mutation must change trace digest on that tick; no rounding/filtering economy fields.
- [x] If `WARGRID_ECONOMY_REPLAY_TRACE` set, write same 1200-row index+SHA256 format to separate file. Since public setup advances simulation, column1 is measured step index1..1200, while digest still includes full absolute snapshot.tick; assert identical setup tick/state in both worlds and never reset tick or omit it from hash. Document column1 as scenario-relative tick for economy trace. Require file/open/write success. Keep original `WARGRID_REPLAY_TRACE` meaning. CI uploads per-platform movement and economy traces, invokes strict existing three-file comparator once per scenario. No comparator generalization or mandatory benchmark CI.
- [x] Delegate full suite/comparator with local trace outputs; compare three independently produced same-host economy traces using existing comparator. Label cross-OS result pending until approved push and real matrix success. Do not call local same-host comparison cross-platform proof.

### Task 12 — final verification, one review and stop

- [x] Delegate full headless suite, comparator, outside-root invocation and fresh copy without .godot; positive counts/markers, exit0, no diagnostics. Runner failure probes only if runner/wrapper behavior changed.
- [x] Delegate existing M2 headless300-unit benchmark; compare final M2 recorded baseline and report actual results/limits. No threshold relaxation, flow fields/threading or benchmark replacement. Profile only observed regressions from M3 changes.
- [x] Request one batched visible base-loop check: build all types, stop/resume builder, cancel/refund, collect finite supplies, queue/cancel/produce, blocked exit, pan/zoom/resize/placement/UI. Source parity remains unverified even if playable.
- [x] One substantive final review, Grok if available else fresh context; review connected code plus command/fund/cleanup boundaries; for each new test name production mutation it detects. Apply findings and delegate affected verification. Final `/ponytail-review` only for unnecessary complexity per AGENTS, apply cuts/reverify; never run second substantive reviewer.
- [x] Update reference labels, exact-state migration ledger, README/blueprint links and session notes. Record commands/counts/exits/markers, benchmark hardware and pending remote/visible/parity gates in M3 evidence. No claim tests prove game feel.
- [x] Stop at M3. This plan does not inherit authorization to commit/merge M3 from earlier M2 integration request. Ask separately before any M3 Git publication/integration.

## Concrete case names and assertion patterns

Use these method names, not only numeric labels, in each suite's `cases()` list. Multiple prose assertions within one named case belong to that case; split only when watchdog/debugging requires it.

| Suite | Cases |
|---|---|
| test_economy | E1 `test_definitions`; E2 `test_players_and_kinds`; E3 `test_economy_snapshot_isolation`; E4 `test_variant_rejection`; E5 `test_future_results_and_copy`; E6 `test_stop_and_intent_order`; E7 `test_air_spawn`; E8 `test_air_and_mixed_move`; E9 `test_air_obstacle_isolation`; E10 `test_power_rates`; E11 `test_remove_objects`; E12 `test_economy_loop` |
| test_construction | Cn1 `test_preview_and_placement`; Cn2 `test_travel_and_work`; Cn3 `test_pause_resume_builder_loss`; Cn4 `test_cancel_refund`; Cn5 `test_competing_build_commands`; Cn6 `test_prerequisites_and_power`; Cn7 `test_construction_power_transition` |
| test_production | P1 `test_producer_and_free_collector`; P2 `test_fifo_payment_and_cancel`; P3 `test_blocked_exit`; P4 `test_production_power_and_removal` |
| test_supply | Su1 `test_source_and_gather_validation`; Su2 `test_dock_timing`; Su3 `test_partial_load_and_conservation`; Su4 `test_dock_competition_and_lookup`; Su5 `test_collection_interruptions`; Su6 `test_dock_loss_recovery` |
| test_view | add V3 `test_economy_picking`; V4 `test_build_preview` |
| test_base_scene | Bs1 `test_base_ready`; Bs2 `test_placement_input`; Bs3 `test_production_ui`; Bs4 `test_context_orders`; Bs5 `test_execution_feedback` |
| test_replay | add `test_economy_repeatability` alongside existing M2 replay case |

Example E10 assertions (production helper signature defined above):

```gdscript
func test_power_rates(runner) -> bool:
    for row in [[0, 0, 1000], [0, 2, 500], [5, 2, 1000], [5, 5, 1000], [5, 6, 800], [5, 10, 500]]:
        runner.check(Definitions.work_rate(row[0], row[1]) == row[2], "E10 rate " + str(row))
    return true
```

Common atomic-rejection assertion, repeated with task's table inputs (not a new production abstraction):

```gdscript
var before: Dictionary = sim.snapshot()
var result: Dictionary = sim.issue_command(invalid_command)
runner.check(not result.ok and not result.error.is_empty(), "rejected with reason")
runner.check(sim.snapshot() == before, "rejection changes no authoritative state")
```

Cn5 test core, after fixture creates player with800 credits and builder ID1; both sites reachable/free:

```gdscript
var first := {"tick": 2, "player": 1, "sequence": 0, "type": "build", "builder_id": 1, "building_kind": "reactor", "origin": [8, 4]}
var second: Dictionary = first.duplicate(true)
second.sequence = 1
second.origin = [12, 4]
runner.check(sim.issue_command(first).ok and sim.issue_command(second).ok, "Cn5 both affordable at issue")
sim.step()
sim.step()
runner.check(sim.snapshot().players[0].credits == 800, "Cn5 no early charge")
sim.step()
var state: Dictionary = sim.snapshot()
runner.check(state.players[0].credits == 0 and state.buildings.size() == 1, "Cn5 only first transaction charges")
runner.check(state.command_results[0].ok and not state.command_results[1].ok, "Cn5 canonical conflict result")
runner.check(state.next_entity_id == 3, "Cn5 rejected transaction consumes no entity ID")
```

P4 work boundary core, with ready fixture producing one vehicle under full power (enqueue step counts as first work tick): assert `queue[0].work == 150000` after150 such ticks; remove reactor before next step; after299 half-rate steps assert work299500 and no produced vehicle; next step creates exactly1 and queue becomes empty. Cn7 uses same earned-work assertions on foundation. This catches source-style retroactive elapsed/duration recalculation.

Su2 timer core after stationary admission: assert remaining36/cargo0; step35, assert remaining1/cargo0; step once, assert cargo1/source boxes decremented1. For unloading assert remaining87; step86, credits unchanged/cargo intact; step once, credits increase600/cargo0. Record source stock before/after every action; changing delay decrement order must fail these cases.

E12 final assertions use source8-box fixture and exactly one produced vehicle:

```gdscript
var state: Dictionary = sim.snapshot()
runner.check(state.players[0].credits == 5100, "E12 10000 - 4800 + 600 - 700")
runner.check(state.sources[0].boxes == 0, "E12 finite source exhausted")
runner.check(collector.collection.cargo == 0, "E12 entire load deposited")
runner.check(state.entities.filter(func(unit: Dictionary) -> bool: return unit.kind == "vehicle").size() == 1, "E12 one paid vehicle")
```

Resolve `collector` from snapshot by kind/ID in test, not internal dictionaries. Remaining cases' exact inputs/outcomes are specified under owning task; preserve original test coverage when extending setup helpers.

## Plan self-review and handoff

Design coverage: funds/commands/state tasks1–2; air3; construction4–5; production6; supply7–8; presentation9–10; replay11; acceptance12. Each review-focus failure has named cases above. No new prerequisite/rate/value is left for executor to invent. Fixture/code bodies intentionally omitted; contracts and assertions decide them.

Fresh design builder check found no consequential planning gaps before this plan. Plan self-review must still reconcile future final M2 names, snapshot literal sites and performance evidence at task0. Remaining M2 visual/rendered/backlog gates were explicitly deferred with risk accepted at M3 kickoff; they remain open. [M3 kickoff prompt](../../m3-prompt.txt) is a separate artifact; root prompt was installed during authorized branch handoff, then explicitly invoked for M3.


## Executed checkpoint — 2026-11-03

Tasks0–12 implemented and headlessly verified. [M3 evidence](../../reference/m3-verification.md) records red/green, final95-case suite, outside-root/fresh-cache/exact replay, repeated M2 benchmark, sole substantive review resolutions and final lean pass. Task12 visible item means batched request completed; user chose headless, so actual play/rendered/backlog gates remain pending, never passed. M3 cross-OS CI awaits approved publication; retail parity unverified. No M4 or Git action authorized.
