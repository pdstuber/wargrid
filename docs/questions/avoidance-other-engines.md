# How OpenRA and Recoil (Spring) make units avoid each other
Paths below: OpenRA = ~/projects/OpenRA/OpenRA.Mods.Common (OR), Recoil = ~/projects/RecoilEngine/rts/Sim/MoveTypes (RC). ZH side only touched lightly (pointers); the ZH-default labels in the questions are NOT verified here, another researcher owns ZH behaviour.

## Findings (short, cited)

### OpenRA: cell-by-cell, wait, nudge, repath
- **Whole cells are reserved.** A unit occupies FromCell and ToCell while moving (Traits/Mobile.cs:256-265). Path search is a normal grid search; it asks `CanEnterCell` per cell (Traits/World/Locomotor.cs:219-300). **source**
- **Path search tries "blocked by" levels in order** All, Stationary, Immovable, None (Activities/Move/Move.cs:31-37, used :134-139). So the first path ignores nothing; if no route, the unit paths *through* parked/moving friends and handles them when it gets there. **source**
- **Blocked on the next cell** (Move.cs:263-345, `PopPath`): (1) if blocker can never move (building), repath at once ignoring movable units (:297-301 region, "no point in waiting"); (2) else `NotifyBlocker` (:305); (3) wait `WaitAverage` = 40 ticks once (Locomotor.cs:66, Move.cs:309-318; `WaitSpread` = 10 is declared at Locomotor.cs:68 but I found no use in Move.cs: **inferred** unused); (4) if everything in the cell is already leaving, wait more (`CellIsEvacuating`, :321-322, :367); (5) else repath with `BlockedByActor.All` (:325-330); (6) no route: if I block someone, step to a free neighbour ("UnblockDestination", :339-343), else give up with `CompleteDestinationBlocked`. **source**
- **Nudge** = the blocker is asked to leave (ActorExts.cs:61-76 -> `INotifyBlockingMove`; Mobile.cs:881-891). A friendly *idle* blocker queues a `Nudge` activity and walks to a cell next to the nudger (Activities/Move/Nudge.cs:23-38). A friendly *moving* blocker just sets `IsBlocking = true`, which lets it sidestep if it is itself blocked. Enemies are never nudged. **source**
- **Infantry share cells via subcells** (`SharesCell`, Locomotor.cs:70-71; subcell offsets used in Move.cs:228-237 region, `GetAvailableSubCell` Locomotor.cs:307). Up to several infantry per cell, so infantry blobs pass each other without any push. **source** (count per cell: not checked.)
- **Crushing is part of "blocked".** Cells whose occupants the mover can crush do not block (Locomotor.cs:236-238, :365-375); crush classes in `Crushes`/`CrushClasses` (Locomotor.cs:76-77, Traits/Crushable.cs:23-27); `CrushedByFriendlies` default false (Crushable.cs:27); damage on arrival in Mobile.cs:588-601, warning to victim at :811. **source**
- **Weak spots in comments:** `TODO: Change this to BlockedByActor.Stationary after improving the local avoidance behaviour` (Move.cs:133). `HACK: ... units aren't left idling in a transit-only cell` (Mobile.cs:858-861). The design has no local avoidance for moving units: two units head-on in a corridor both wait 40 ticks, then both repath. **inferred** from the flow above (no comment says "deadlock"; I did not run it).
- **Cost shape:** one grid path search per unit per order, plus one per blocked repath (a repath is what hurts in a traffic jam). Per tick per moving unit: O(1) check of one next cell via a per-cell flag cache (Locomotor.cs:219-270 early-outs on cached flags; slow path only for subcell/ignore/transit cases :252-253). No per-neighbour-pair work at all. Cost spikes with number of simultaneously blocked units (each repaths after ~40 ticks). **inferred**
- **Determinism:** trivially fine: integer cells, ordered activities, shared random for aircraft only (Nudge.cs:44-47 uses `SharedRandom`). **source**

### Recoil: continuous positions, steer plus push
- **Paths are on a coarse grid, but units are discs/footprints with free positions.** Per unit, each tick: follow path waypoints, steer, then collision pass (Systems/GroundMoveSystem.cpp:45-130 splits pre-collision, collision detection, collision events). **source**
- **Steering (anticipation).** `GetObstacleAvoidanceDir` (GroundMoveType.cpp:1843): look at solids within `max(speed,1) * 2 * radius` ahead (:1873-1882), skip idle allied units "since collision handling will just push them aside" (:1921-1926), skip things more than 120 degrees off-centre (:1928-1937), weight by head-on angle and distance falloff (:1957-1969), blend 50/50 with the wanted direction and smooth with last frame's result at 0.7 (:1976-1979, constants :1871-1874). Runs only every 3rd frame per unit (`groundUnitCollisionAvoidanceUpdateRate = 3`, Misc/ModInfo.cpp:44; staggered by unit id, :1850). Statics are deliberately not avoided "it interferes too much with PFS" (:1900). **source**
- **Push (reaction).** `HandleUnitCollisions` (:2787): for every unit within footprint + separation distance (quad-field query, :2825-2829) compute overlap; overlapping units get a push vector split by momentum (`CalculatePushVector`, :2973-3008): the heavier/faster unit moves less. Units not yet overlapping but within `separationDistance` also get pushed apart (:2946-2955), which spreads idle groups. Overlap is tolerated (`allowUnitCollisionOverlap = true`, ModInfo.cpp:37). Enemy units are not pushed by default (`allowPushingEnemyUnits = false`, ModInfo.cpp:34); an enemy is treated like a semi-static wall (:2916-2921 comment). **source**
- **Crush:** a mover crushes if not allied (or `allowCrushingAlliedUnits`, default false, ModInfo.cpp:35) and its speed*mass beats the other's (:2896-2903), subject to the target's crush resistance. **source**
- **Stuck handling:** push-resistant (stopped/building-like) units are treated as static (:2926-2927); if both parties are push-resistant "push both to avoid deadlocks" (:2995-3000); a unit that is not moving but has a path counts idle ticks and then re-requests path, then `Fail` ("got stuck in a non-moving crowd", :790-823); repath is rate-limited (`pfRepathDelayInFrames`, `pfRepathMaxRateInFrames`, :860-870). A pusher-wins rule ends push contests at a shared goal: collider "triggers Arrived" if the idle collidee sits at its goal (:296-317). Pushes into static terrain are cancelled: "prevent units from pushing each other into buildings far enough that the pathing systems can't get them out" (:2549-2551). **source**
- **Jitter/oscillation comments:** "if MAX_AVOIDEE_COSINE is too small ... avoidance vector to oscillate --> units with turnInPlace slow to a crawl" (:1942-1946); "repeated coldet push-jittering" (:953); "features do not bounce light units away like jittering pinballs" (:3073); "unit stuck ... open square could not be found ... allow the unit to move so that it gets unstuck eventually. Hopefully this won't look silly" (:3555-3557). **source**
- **Cost shape:** per unit per tick: one spatial query for pushes (cost ~ units within roughly 2 footprint radii: neighbour pairs, each pair visited from both sides), plus one steering query every 3rd tick (radius grows with speed). Dense blobs are the worst case (quadratic in local density). Collision pass is run in parallel (`for_mt`, Systems/GroundMoveSystem.cpp ~:66) while path/steering sections are single-thread "due to the numerous synced vars" (:12 comment region). **source** for structure, **inferred** for big-O.
- **Determinism:** all of this uses floats; Recoil keeps lockstep with synced float types (`SyncedFloat3` waypoints, GroundMoveType.h:11, :229-230) and a replay/checksum model; threads only write per-unit results, applied in unit order. Whether float results match across CPUs/compilers is their problem (they ship one build); **not verified** beyond this. For Wargrid (GDScript floats, WASM + native, lockstep): float steering is a real desync risk, fixed-point/ints would be required. **inferred**

### Comparison in one line each
- OpenRA: exact grid, rare collisions, units visibly queue and shuffle ("waiting, nudging"), cheap per tick, repath storms in jams.
- Recoil: smooth flowing, units visibly shove each other and can overlap, more per-tick math, float-sync risk.
- ZH pointers only (not analysed here): crush check `canCrushOrSquish` in AI/AIPathfind.cpp:4974 and :5087 (GameLogic/AI); blocked counters `isBlockedAndStuck` / `getNumFramesBlocked` used in AI/AIStates.cpp:1821 (waits 2 s then acts); `m_ignoreObstacleID` AI/AIPathfind.cpp:3865.

## Questions
(The ZH-default labels point at the pointers above where one exists; where I have none, I say "ZH: unverified here".)

Q1. When you drag a big group across open ground, what should it look like?
   a) Units flow around each other smoothly, a little jostling, no queueing (Recoil style) — ZH: unverified here   b) Units stay on exact cells, queue and shuffle one by one (OpenRA style)   c) Mostly b), but units make a small side-step early to avoid a crowd
   Recommendation: c), because a) needs float steering that endangers lockstep. Why it matters: it picks the whole avoidance family.

Q2. Can a moving unit shove an idle friendly unit out of its way?
   a) Yes, the idle unit is pushed aside by contact, it does not decide anything (Recoil)   b) Yes, but the idle unit is asked and walks one step to a free cell itself (OpenRA nudge)   c) No, the mover goes around it
   Recommendation: b), because it looks deliberate and stays on cells. Why it matters: decides whether idle armies get messed up by passing traffic.

Q3. A unit's next cell is held by a friendly unit that is moving. How long should it wait before trying another route?
   a) Under 1 second   b) About 1.5 to 2 seconds (OpenRA waits 40 ticks, Move.cs:310 / Locomotor.cs:66; ZH waits about 2 s in some states, AI/AIStates.cpp:1821)   c) Until the blocker is gone, never reroute
   Recommendation: a) or b); pick b) to stay close to both references. Why it matters: too short causes zigzagging, too long looks frozen.

Q4. Two groups meet head-on in a one-cell-wide corridor. What should happen?
   a) Both stop, one side backs out after a wait (OpenRA "UnblockDestination", Move.cs:339-343)   b) The units that arrived first keep going, the others wait   c) They swap places and walk through each other
   Recommendation: b), because a deterministic "first one wins" rule has no oscillation. Why it matters: this is the classic deadlock already listed as a risk.

Q5. Can your units push enemy units out of the way?
   a) No, enemies are walls (Recoil default, ModInfo.cpp:34; OpenRA never nudges enemies, Mobile.cs:883)   b) Yes, same as friends   c) Only the heavier unit pushes the lighter one
   Recommendation: a), because pushing enemies lets you open a wall of units in a fight. Why it matters: affects blocking chokepoints and body-blocking tactics.

Q6. Should tanks flatten infantry only when ordered, or whenever they drive over them?
   a) Automatically whenever a tank's path meets enemy infantry (ZH has crush checks in pathing, AI/AIPathfind.cpp:4974)   b) Only on a dedicated "run over" order (stricter than OpenRA, where crush classes make crushable cells passable, Locomotor.cs:236)   c) Never, tanks go around
   Recommendation: a), because the blueprint lists crushing in combat. Why it matters: decides if infantry can body-block tanks and if tanks can plough through a squad.

Q7. Can tanks crush your own infantry?
   a) Never (Recoil default `allowCrushingAlliedUnits = false`, ModInfo.cpp:35; OpenRA `CrushedByFriendlies = false`, Crushable.cs:27)   b) Yes, accidents happen   c) Only if you order it
   Recommendation: a), because friendly crush punishes normal movement. Why it matters: with a), allied infantry must get out of the way instead.

Q8. How should infantry behave in a crowd?
   a) Several share one cell, so squads walk through each other without pushing (OpenRA subcells, Locomotor.cs:70)   b) One infantry per cell like vehicles   c) Loose squads that spread by a small push, no cells
   Recommendation: a), because it keeps infantry blobs from jamming chokepoints. Why it matters: infantry are the numerous units; this sets how packed a rush looks.

Q9. Is it ok for two moving friendly units to overlap briefly when they cross?
   a) Yes, a short pass-through is fine (Recoil allows overlap, ModInfo.cpp:37; today's M2 design overlaps)   b) No, never; they wait or sidestep   c) Only infantry with infantry
   Recommendation: c), because the firm requirement is "go around" and tanks overlapping is the thing that looked wrong. Why it matters: allowing overlap removes most deadlocks at the cost of the overlapping look that was rejected.

Q10. A unit that cannot reach its spot because friends are standing there: what next?
   a) It gives up and stops where it is (OpenRA `CompleteDestinationBlocked`, Move.cs:343 region)   b) It stops "near enough", and units already at the goal shuffle outward to make room   c) It keeps pushing in until the others move (Recoil pushing contest, ended by an idle-goal rule, GroundMoveType.cpp:296-317)
   Recommendation: b), because it makes big groups end in a neat clump. Why it matters: decides how armies look after a move order.

Q11. When a friendly unit is stuck behind a parked unit, who should make way?
   a) The parked one, if idle (it steps aside)   b) The moving one reroutes   c) Whoever is closer to its own destination keeps its place
   Recommendation: a), then b) if the parked unit is busy (shooting, building). Why it matters: avoids one idle unit blocking a base exit.

Q12. Do you accept units occasionally jittering or wobbling if it keeps groups from freezing?
   a) Yes, small wobble is fine (Recoil has several comments about jitter, GroundMoveType.cpp:953, :1942)   b) No, a unit should stand still and wait rather than wobble   c) Only while moving, never when idle
   Recommendation: c), because idle jitter is the worst thing in screenshots and replays. Why it matters: decides whether push-based spreading is allowed at all.

Q13. Should heavier units push lighter ones aside (a tank vs. a scout buggy)?
   a) Yes, mass decides who yields (Recoil momentum split, GroundMoveType.cpp:2973-2995)   b) No, all friendly units yield the same   c) Only on explicit nudge (the lighter one steps aside)
   Recommendation: c), because it stays readable and cheap. Why it matters: it controls whether big units cut through a crowd of small ones.

## Not found / not verified
- Whether `WaitSpread` is used anywhere in OpenRA's move code (found only the declaration).
- Max infantry per OpenRA cell (subcell count) not checked.
- No ZH behaviour read beyond the grep pointers; I did not measure anything (read-only, nothing run).
