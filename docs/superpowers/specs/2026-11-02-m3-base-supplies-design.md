# M3 — base and supplies design

Status: **DESIGN APPROVED / PLANNING ONLY**. User chose research first, selected source-informed playable slice, and approved this design for detailed planning on 2026-11-02. Engineering defaults below were proposed by assistant and approved for planning; implementation remains separately gated. M2 must close its exit gates before M3 implementation is authorized. [README](../../../README.md) owns current state; [blueprint M3](../../../Wargrid_Kickoff_Blueprint.md) owns milestone scope.

## Intent and approaches

Build one playable USA-style economy loop: dozer constructs reactor, supply depot and factory; flying collector moves finite supplies into credits; factory spends credits on a noncombat vehicle. Preserve researched economic rules while keeping deterministic headless simulation and original placeholder presentation. No claim of retail timing/feel parity.

Chosen approach: source-informed playable slice. Alternative considered: calibrate retail geometry, locomotion and docking first; stronger spatial fidelity but requires runtime setup/measurement before a useful economy slice. User selected first approach. An invented generic economy was rejected in favor of source/data research. Evidence belongs in `docs/reference/m3-economy.md`; do not copy EA code/assets.

Excluded: combat/health simulation, building sales, repairs, upgrades, passengers, alternate factions, AI opponent, victory, fog, save/load, terrain height, construction assists, construction queues per builder, rally controls, generic ECS/config loaders and multiplayer. One owned builder per foundation. Scenario removal tests destruction consequences without adding combat. Existing M2 movement demo/benchmark remain runnable.

## Reference rules and deliberate differences

Base-USA definitions from hash-pinned root INIZH.big; prices in integer credits, durations in 30 Hz ticks:

| Wargrid key | Reference object | Cost | Nominal ticks | Completed power | Prerequisite |
|---|---|---:|---:|---:|---|
| `reactor` | AmericaPowerPlant | 800 | 300 | +5 | none |
| `depot` | AmericaSupplyCenter | 2000 | 300 | -1 | completed reactor |
| `factory` | AmericaWarFactory | 2000 | 450 | -1 | completed depot |
| `collector` | AmericaVehicleChinook | 1200 | 300 | 0 | completed depot; produced there |
| `vehicle` | AmericaVehicleHumvee, economy only | 700 | 300 | 0 | completed factory; produced there |
| `builder` | AmericaVehicleDozer | scenario-spawn only | — | 0 | — |

Dozer production/command center are excluded from M3. Reactor completion unlocks depot; depot completion unlocks factory. Foundation does not satisfy prerequisite. Completed depot grants exactly one free collector; additional collectors use its paid FIFO queue. Queue capacity 9 includes active/ready head. No repeated free grant after snapshot reads or failed spawns.

Construction and production charge full price on execution, before builder travel or queue wait. Cancel unfinished foundation/any queued item refunds its stored paid cost exactly once. Completed building cannot use construction cancel. Destroyed producer refunds remaining queued items; destruction of a foundation does not refund construction. Losing prerequisite after enqueue does not cancel accepted production. Building sale and its percentage refund are excluded.

Power counts completed structures only. Equality or zero demand means full speed. Otherwise work rate per tick is integer `clamp(floor(supply * 1000 / demand), 500, 800)`; full speed is 1000. Nominal required work = nominal ticks × 1000. Both construction and production accumulate work; no retroactive progress jump when power changes. This fixes source's elapsed/current-duration production behavior and zero-demand edge; exact source truncation is not retained. Rates are captured once at beginning of work phase; completions affect next tick's rate. Supply collection continues under low power; depot/factory lack POWERED flag in inspected INI.

Collector holds 8 boxes, 75 credits each. Warehouse transfers one box every 36 stationary dock ticks; depot deposits entire cargo after 87 dock ticks. Stop loading immediately when full or source empty, omitting source's extra full-capacity retry interval. Partial last loads return. These delays exclude flight and presentation animations. No upgrade bonuses. Source stock is integer boxes, not arbitrary cash.

Grid footprints, flight speed, dock positions, retry interval and test map are provisional Wargrid geometry: do not convert source world-unit radii/speeds without calibration. Hard collision remains deferred. Record all departures in reference note.

## State and integration

Extend existing Simulation; no second simulation, duplicate tick loop or inheritance-based economy mode. Simulation owns commands, IDs, units and authoritative dictionaries. Small internal helpers handle construction, production and supply transitions; they mutate same state through explicit internal methods, without signals, callbacks or generic jobs. Definitions contain only selected types/constants and return copied records.

Retain `spawn(owner, position)` behavior by adding optional `kind = "vehicle"`. Existing move command shape remains valid. All mobile snapshots gain `kind`, `construction_id` (null unless assigned builder), and `collection` (null unless collector). Building/source records live in separate ID-sorted snapshot arrays. One global next entity ID spans units, buildings and sources. Queue item IDs use a separate monotonic `next_production_id`. Snapshots deep-copy all queues, dock ownership, timers, targets, costs, work, players and scenario terrain; no authoritative state hidden in scene/helper caches.

Players have `{id, credits}`; power is derived from buildings and exposed in snapshot. Existing M2 worlds may have no player economy records and still accept movement. Economic commands require registered player. Scenario methods add player, source or typed unit and remove objects synchronously between ticks; they validate before mutation and are recorded with tick by replay harness. No public mutable dictionary accessor.

Keep authored terrain separately from construction/source footprints. Navigation receives union. Foundation appears/blocks ground immediately; cancellation/removal clears only its footprint, preserving terrain/other objects. Reject foundations overlapping any terrain/source/building, ground unit current cell or reserved ground destination; air units do not block placement. Reuse M2 conservative route invalidation and eight-query budget after changed footprint. Builder approach chosen from free orthogonally adjacent cells in its reachable component, nearest squared distance to builder then y/x. No valid approach => atomic rejection before payment. Later blocking can pause builder without refund or teleport.

Air collectors ignore ground solids, reservations and path queue; move directly at provisional 6 world units/second (0.2/tick), bounds/finite checks still apply. Air may overlap ground/air and hover over depot/source dock. Ground default speed remains M2 3 units/second. Mixed move command allocates ground goals and gives air exact target; target must be walkable if any ground member. Manual move suspends collection, releases dock, retains cargo. Ground reservations/spawn checks exclude air.

## Commands and deterministic order

Common envelope remains integer `tick`, `player`, `sequence`, string `type`; shared monotonic per-player sequence and canonical `(tick, player, sequence)` ordering. New payloads: build(builder/type/origin), resume_build(builder/building), cancel_build(building), produce(building/unit type), cancel_production(building/entry), gather(collector IDs/source), stop(unit IDs). Exact field names and validation matrix belong to execution plan.

At issue: validate shape, finiteness, current ownership/existence and current eligibility; reject without any snapshot change. Accepted commands only queue/copy and consume sequence. At due tick: revalidate mutable facts (funds/prerequisites/space/objects/ownership), then atomically execute or record failure. No future escrow. Two orders competing for same money resolve in canonical order. Store last tick's economic command results `{tick,player,sequence,ok,error}` in snapshot; clear at next step start. UI must display execution rejection as well as immediate rejection.

Process due commands canonically. Monetary transactions each execute once; successful unit instructions replace earlier successful instruction for same unit. Failed commands do not erase earlier instruction. Build then move pays/creates foundation but leaves it paused; it does not undo purchase. After processing, release reservations/old task bindings for replaced units, then assign final move/build/gather/stop intents in canonical command order and ID order; retain M2 same-tick move coalescing and allocation tests. New foundation may invalidate an earlier selected approach; leave foundation paid and builder blocked, recover via resume_build.

Tick phases: clear last results; apply due commands/final intents; capture IDs existing at start of work and owner power rates; construction and production work by building ID; collection/dock transitions by unit ID; service bounded ground route queue; move captured units by ID; increment tick. New completion-spawned units activate next tick. Work requires builder already arrived before this tick's movement. Dock timer starts on first collection phase after arrival; that phase initializes full delay without decrement. A full N dock ticks then triggers transfer. No work credit during travel, queue wait or blocked exit.

## Construction and production behavior

Footprints (unrotated integer rectangles): reactor 2×2, depot 3×3, factory 3×3. Origin is top-left world cell. Reject outside map; no extra edge margin. Builder routes to deterministic adjacent cell, stays outside footprint and works there. Move/stop interrupts work but retains foundation/progress; owned builder can resume it. Assigning a new builder releases old builder binding. Cancel releases builder/dock/queue state and footprint, refunds once, never changes unrelated units. Builder removal pauses its foundation.

Queue is FIFO, paid at insertion, capped at 9. Only head earns work. On completion attempt spawn; ready blocked head waits at full work and prevents following work. For vehicle spawn choose free orthogonally adjacent perimeter cell in y/x order, excluding current/reserved ground cells. No exit => no ID allocated, no overlap, no duplicate, no queue advance; retry once/tick. Collector exits at depot center (air overlap allowed). Each building creates at most one paid unit per tick; next head begins next tick. Free collector is separate one-time depot-completion effect. Completed factory/depot accept only listed unit kind; no free production from spawn fixture in gameplay.

Scenario removal: unknown ID rejects unchanged. Builder removal pauses work; collector removal loses carried boxes, releases dock; completed building removal updates power, footprint and refunds all queue entries once; source removal releases dock while preserving loaded cargo on surviving collectors. No ownership transfer, death animation or salvage.

## Supply loop

Source footprint 3×3, neutral, finite boxes; dock is rectangle center. Completed owned depots are legal delivery targets; unfinished/enemy depots are not. Each source/depot has one active collector ID, released on departure/stop/removal. Collector snapshot stores enabled flag, preferred source ID, target dock ID, phase and remaining delay plus cargo. Phases: seeking, flying_source, waiting_source, loading, flying_depot, waiting_depot, unloading, idle. Waiting air collectors hover at center; admission by ID among waiting arrivals each tick. No persistent FIFO queue needed; no fairness claim beyond deterministic bounded tests.

Positive cargo seeks nearest legal owned depot; empty cargo prefers commanded nonempty source, otherwise nearest nonempty source; squared ground distance then object ID breaks ties. All map sources eligible: source scan radius is intentionally omitted pending world-scale calibration. Do not search paths for flight. Two collectors cannot take same last box; transfer stock->cargo is atomic. No depot preserves cargo and retries seeking every 30 ticks; no source preserves idle collector and retries likewise. Removal/depletion releases active slot and re-seeks next tick. Partial cargo never disappears and always seeks depot first. Completed depot's free/newly produced collectors start automatic seeking; manually gathered collector enables loop; a loaded collector may use an existing exhausted source command to resume delivery. Stop disables auto loop without losing cargo. No teleport after lost target.

## Playable scene and acceptance

Add separate base scene and main script; reuse WorldView, projection, camera and M2 selection behaviors through a small shared controller only if copying would duplicate logic. Preserve M2 scene as movement regression/benchmark fixture. Base scene is 32×32, fully visible, one owner, 10,000 credits, builder at (4.5,4.5), one 3×3 source at (24,4) with 200 boxes, no initial structures. No free collector until depot completes. Noncombat vehicles selectable/movable.

HUD: credits, supply/demand, selected unit/building, work, queue and rejection text. Builder-selected keys 1/2/3 enter reactor/depot/factory placement; preview snaps footprint, green/red validity; left release places once, Escape cancels placement without changing funds/selection, right click cancels placement. Ordinary selection/move otherwise remains M2 behavior. Building left click selects building; depot/factory HUD Produce button queues allowed unit; per-entry Cancel buttons address exact entry IDs; unfinished building Cancel refunds; builder right-click owned unfinished building resumes, collector right-click source gathers. Unit hits take precedence over building footprint; other right-clicks move selected mobile units. Buttons consume input, never issue world move. Keyboard E may produce selected building's sole unit as equivalent to button. No building multi-selection or new controls system.

Headless tests establish: exact accounting/refunds; placement atomicity/footprint restoration; build travel/pause/resume; completed-only prerequisites; low-power transitions; FIFO/cancellation/blocked spawn; cargo conservation/depletion/two collectors; removal at every phase; exact repeated snapshots/replays; existing M2 regression coverage; transformed scene input and no duplicate UI commands. One scripted scenario constructs all three buildings, gathers/deposits a load, pays for and produces vehicle; assert funds ledger and stock/cargo/earned conservation. Detailed expected numbers belong in plan.

Final gates: full suite/outside-root/fresh cache; extended cross-platform replay after separately approved publication; M2 300-unit benchmark regression; one substantive reviewer and final Ponytail cuts; batched visible base-loop check only after permission. Source/data evidence is not retail play validation. No M4 work. No automatic commits/push/PR/merge.
