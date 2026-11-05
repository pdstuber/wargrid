# Wargrid: Fair, Intelligent RTS Bots — Research and Implementation Notes

**Prepared:** 2026-11-05  
**Project:** Wargrid — a Godot-based, Generals-style RTS  
**Goal:** Build opponents that play competently and convincingly **without privileged vision, bonus resources, accelerated construction, or arbitrary rule-breaking**.

> **Status (Wargrid, 2026-11-05):** user-supplied input for M8. Checked the same day against primary sources (READMEs and code via `gh api`, the local OpenRA clone at `9636b63eae`, the Petra coverage page): the repository, licence, README and Petra-multiplier claims hold. Not checked: the SparCraft wiki claims and the Petra commit link in §3.8. Corrections found: OpenRA's bots do not respect fog (§3.1); Zero-K CAI's own source admits a maphax path (§3.2); microRTS is deprecated (§3.9); Petra's easier levels are penalised too (§3.8). Zero Hour facts checked at EA `0a05454`: `GameDifficulty` has three values (`GeneralsMD/Code/GameEngine/Include/Common/GameCommon.h:141`) and selects per-side data such as gatherer counts (`Source/GameLogic/AI/AIPlayer.cpp:203`); whether the retail AI respects the shroud is not audited (`AIGroup.cpp:648` only concerns map-border clamping). Decisions drawn from this note: [blueprint §7 M7.9–M8.1](../../Wargrid_Kickoff_Blueprint.md).

> This is a research and engineering reference, not an assertion that every listed bot is perfectly fair. A strong bot, a non-cheating bot, and a human-like bot are different things. Repository claims are distinguished from independently proven properties wherever possible.

## 1. Executive recommendation

**Keep OpenRA as the architectural frontrunner.** Its modular bot components map naturally to a C&C/Generals-style game. Supplement it with:

1. **UAlbertaBot / BOSS** for production planning and goal-driven build orders.
2. **Zero-K CAI** for the practical breadth of a full skirmish AI: economy, jobs, expansion, threat estimation, and army control.
3. **Stardust and SparCraft** for combat evaluation, engagement prediction, and retreat decisions.
4. **PurpleWave** for strategic variety across matchups and opponent observations.
5. **BWMetaAI** for recognizable, human-inspired openings and unit compositions.
6. **microRTS** as a research playground for algorithms that are expensive to experiment with inside Wargrid.

Do **not** begin with reinforcement learning, deep neural networks, or full-game Monte Carlo tree search. First make one competent, auditable, rule-compliant bot. Expand difficulty through competence rather than economic bonuses.

## 2. What “fair and smart” should mean

| Attribute | Definition | Implication for Wargrid |
|---|---|---|
| **Fairness** | AI obeys the same game rules and is limited to information a player could observe. | Hard boundary at the observation and command APIs. |
| **Strength** | AI wins through good economy, preparation, tactics, scouting, and adaptation. | Measure outcomes in repeated, controlled matches. |
| **Human likeness** | AI uses recognizable strategies, limited attention, imperfect estimates, and coherent reactions. | Avoid perfect unit-level omniscience and limitless micro. |
| **Enjoyability** | The opponent's actions are readable, learnable, and counterable. | Prefer plausible, explainable strategies to invisible, optimal exploits. |

An AI can be **fair but not human-like**: it might command 100 units simultaneously with impeccable timing while using only legal information. Conversely, a human-like AI may still be strategically weak. Treat these as separate design targets.

### Non-negotiable constraints

- Same starting resources, income rules, construction rules, tech prerequisites, unit stats, damage, and movement as a human.
- Same map and fog-of-war rules. Radar and sight must retain their normal information limits; a radar contact is not automatically a fully identified unit.
- No querying hidden enemy positions, production queues, resource totals, or orders.
- Last-seen information may be remembered, but must be timestamped and explicitly uncertain.
- AI commands are submitted through the normal validated player-command pathway.
- Every consequential decision should be explainable in terms of available observations, estimates, and goals.
- Any optional difficulty modifier that changes the rules must be clearly separated from **fair-play** difficulty modes; ideally, do not ship such modifiers.

## 3. Open-source reference projects

### At-a-glance comparison

| Project / bot | Code / language | Best reason to read | Fairness and limitations |
|---|---|---|---|
| **OpenRA** | C# and YAML | Modular C&C-style bot architecture | Well suited to structure; weighted heuristics don't automatically imply deep strategy. **Squad targeting ignores shroud and fog** (§3.1): not a fairness model. |
| **Zero-K — CAI** | Lua | Integrated full-game skirmish AI | One LOS/radar helper with a single caller; the source itself marks the threat check `FIXME: … involves maphax` (§3.2). |
| **UAlbertaBot** | C++ | BOSS build-order search; SparCraft battle simulation | Valuable algorithms, but inactive since 2021. |
| **Stardust** | C++ / BWAPI | High-performance competitive bot; terrain and combat simulation | Primarily optimized for bot competitions, not necessarily human-like play. |
| **PurpleWave** | Scala / BWAPI | Varied strategies, matchup coverage, tournament success | Complex; not the simplest architecture to port. |
| **Warzone 2100 — Cobra** | JavaScript | Dynamic build/research and threat-priority memory | Easy mode deliberately slows behavior; inspect API knowledge rules yourself. |
| **Warzone 2100 — PeacemakerAI** | JavaScript | Explicit fair-play and enemy-observation memory approach | Fairness and outperforming other bots are **author claims**, not independent verification. |
| **0 A.D. — Petra** | JavaScript | Economic and military management at game scale | **Not a model of fair difficulty scaling:** hard/very hard use gathering/trading bonuses. |
| **microRTS** | Java | Search and partially observable RTS experimentation | Small abstraction; not a complete production-game AI. **Deprecated 2025-08-11** (§3.9). |
| **BWMetaAI** | Brood War AI scripts | Human-inspired builds and believable variety | Explicitly not intended as a top-strength competition bot; weak micro. |

### 3.1 OpenRA — most relevant architecture

- **Repository:** https://github.com/OpenRA/OpenRA
- **Red Alert bot configuration:** https://github.com/OpenRA/OpenRA/blob/bleed/mods/ra/rules/ai.yaml
- **What to inspect:** `ModularBot`, `HarvesterBotModule`, `BaseBuilderBotModule`, `UnitBuilderBotModule`, `SquadManagerBotModule`, `SupportPowerBotModule`, and configuration for Rush / Normal / Turtle / Naval bots.

OpenRA breaks RTS control into cooperating bot modules. The source configuration contains production constraints, base-building weights and thresholds, harvester setup, and squad-management settings. This is highly relevant to a Generals-like game.

**Borrow:** loose coupling between economy, production, defense, squads, and special abilities; data-driven faction and personality configuration.

**Improve:** replace too many fixed thresholds with strategic goals, observations, priorities, and opponent modeling. Modularity alone is not intelligence.

**Fairness (checked 2026-11-05 in the local clone at `9636b63eae`):** the bots do not respect fog. `SquadManagerBotModule.IsPreferredEnemyUnit` filters only through `IVisibilityModifier`, which in `OpenRA.Mods.Common` only `Cloak` implements; `FindClosestEnemy` runs over `World.Actors`, and the rush logic searches enemy construction yards through a world-wide actor index. `BaseBuilderQueueManager.cs:548` places defences near the closest enemy `Targetable` actor with no visibility check. Some paths do check `CanBeViewedByPlayer`: `SupportPowerDecision.cs:156`, `Squad.IsTargetVisible` (used in `ProtectionStates.cs:49`) and `CaptureManagerBotModule` (opt-in setting). Not checked: whether anything outside the bot modules limits what a bot sees. Use OpenRA for structure, never as a fairness model.

### 3.2 Zero-K — CAI: full-game intelligence

- **Repository:** https://github.com/ZeroK-RTS/Zero-K
- **CAI source:** https://github.com/ZeroK-RTS/Zero-K/blob/master/LuaRules/Gadgets/ai_CAI.lua
- **Concrete point to inspect:** `isUnitVisible(unitID, allyTeam)` consults `Spring.GetUnitLosState` and checks line of sight or radar.

CAI is useful because it implements a broad range of interconnected skirmish responsibilities: resources, construction work, factory priorities, threat handling, and combat forces.

**Borrow:** resource/production job allocation, scouting needs, threat-map concepts, and the integration of economy with army decisions.

**Fairness caveat:** a visibility check in one function does **not** prove every AI subsystem follows human information restrictions. Checked 2026-11-05 in `ai_CAI.lua` (master): `isUnitVisible` (line 257) has a single caller (line 1686), and the scouting heatmap uses `spIsPosInLos` (line 2277). The threat check `isPosThreatened` (line 536) scans enemies with `spGetUnitsInCylinder` and no LOS test, under the author's own comment `FIXME: this actually involves maphax - 'course it wouldn't need to if it remembered where bad guy turrets are...`. So hidden-information use in threat estimation is confirmed by the source's own comment (not traced end to end through every caller). Audit every input to threat maps, targeting, and strategic evaluation; that is itself a key design lesson for Wargrid.

### 3.3 UAlbertaBot — build planning and combat modeling

- **Repository:** https://github.com/davechurchill/ualbertabot
- **BOSS directory:** https://github.com/davechurchill/ualbertabot/tree/master/BOSS
- **SparCraft directory:** https://github.com/davechurchill/ualbertabot/tree/master/SparCraft
- **Wiki / architecture guide:** https://github.com/davechurchill/ualbertabot/wiki
- **Wiki mirror with BOSS and SparCraft overview:** https://github-wiki-see.page/m/davechurchill/ualbertabot/wiki
- **SparCraft capabilities and limitations:** https://github-wiki-see.page/m/davechurchill/ualbertabot/wiki/SparCraft-Introduction

**BOSS** (Build Order Search System) models and searches construction/production sequences toward goals, given costs, prerequisites, and timing. **SparCraft** simulates RTS engagements to support combat decisions.

**Borrow:** a production planner with explicit goals such as *field anti-armor before an expected push* or *expand while preserving defense*; lightweight approximate battle evaluation for attack/retreat choices.

**Important limitation:** SparCraft's documented standalone model omits mechanics such as fog of war, unit collisions, and some special abilities. Feed any evaluator only observed/estimated forces, never hidden ground-truth game state. UAlbertaBot's repository says it is not actively maintained since early 2021.

### 3.4 Stardust — competitive combat decision-making

- **Repository:** https://github.com/bmnielsen/Stardust
- **README:** https://github.com/bmnielsen/Stardust/blob/main/README.md
- **Referenced libraries:** BWEM for terrain analysis and a modified Fast Approximation (FAP) for combat simulation.

Stardust is a Protoss Brood War bot written in C++ with BWAPI and aimed primarily at AI competitions.

**Borrow:** use terrain representation to assess routes and tactical choke points, then evaluate potential fights before committing. Example questions: *Can this force defeat the defense? Is a supply target worth the losses? Should it retreat and reinforce?*

**Caution:** the repository states MIT terms **with an added tournament-fork restriction**. Read the actual license before copying code; borrowing high-level ideas is a separate question from copying implementation.

### 3.5 PurpleWave — strategic breadth and adaptation

- **Repository:** https://github.com/dgant/PurpleWave
- **README:** https://github.com/dgant/PurpleWave/blob/master/readme.md

PurpleWave is a Scala Brood War bot that can play all three races and multiple professional-style strategies. Its repository documents multiple competition wins and later podium finishes.

**Borrow:** a repertoire of openings and transitions, informed by what the bot has scouted. Model decisions as *hypotheses* rather than secretly knowing the opponent's army.

Example: scouting an airfield could increase the expected probability of an air-focused build. The bot may respond by producing anti-air, additional scouts, or a strategic counter—but cannot know unseen planes have spawned.

### 3.6 Warzone 2100 — Cobra

- **Repository:** https://github.com/KJeff01/Cobra
- **Warzone 2100 engine:** https://github.com/Warzone2100/warzone2100

Cobra's README describes dynamic build/research orders and a **grudge counter**. Hostile actions increase a per-opponent value; the bot tends to prioritize the most aggressive observed opponent. Allies can influence this prioritization.

**Borrow:** long-lived opponent threat/reputation scores, and practical coordination policies for free-for-all and team modes.

**Caution:** Easy mode intentionally slows its behavior, and its advertised modes are not a proof of no other fairness compromises. Inspect the actual game API and scripts before adopting fairness assumptions.

### 3.7 Warzone 2100 — PeacemakerAI

- **Repository:** https://github.com/duckfood/PeacemakerAI

PeacemakerAI explicitly aims at fair play: observed-object spatial stores, remembered information, ordinary game knowledge, and droid self-preservation. Its author claims that it can defeat a number of other Warzone bots, including Cobra.

**Borrow:** last-known enemy-object stores, spatial query design, and a deliberate fairness-first architecture.

**Caution:** competitive superiority and absence of cheating are claims from the README; no independent tournament benchmarking was established here. Still worth reading for implementation ideas.

### 3.8 0 A.D. — Petra

- **Historical GitHub mirror (archived in 2024):** https://github.com/0ad/0ad
- **Historical Petra AI directory:** https://github.com/0ad/0ad/tree/master/binaries/data/mods/public/simulation/ai/petra
- **Current project Git service:** https://gitea.wildfiregames.com/0ad/0ad
- **Petra difficulty modifiers, source excerpt:** https://docs.wildfiregames.com/js-coverage/simulation/ai/petra/config.js.gcov.html
- **More recent Petra-description change documenting difficulty bonuses:** https://git.phylogix.dev/mirrors/0ad/commit/88dc947b6a

Petra offers substantial examples of gathering, building, and attack coordination. It is also the clearest **counterexample** to the fair-difficulty goal:

- Medium gathering/trade modifier: **1.00×**.
- Hard: **1.25×**.
- Very Hard: **1.56×**.
- Easier difficulties receive reduced resource/trade rates; some also have slower building/training/research.

These numbers are present in documented code; they are not estimates. The boost alters the economy rather than just increasing strategic skill.

The same table (`rate` array in `config.js`, checked 2026-11-05) penalises the lower levels, applied to gather speed and trader gain: Sandbox 0.42×, Very Easy 0.56×, Easy 0.75×, with a build-time factor of 1.40, 1.25 and 1.10. That is the "fake weakness" §5 warns against.

**Borrow:** broad economy and construction logic. **Do not borrow:** its resource-based difficulty scaling.

### 3.9 microRTS — AI research workbench

- **Current repository:** https://github.com/Farama-Foundation/MicroRTS
- **Older URL, which redirects to the current repository:** https://github.com/santiontanon/microrts
- **Example partially observable behavior:** https://github.com/Farama-Foundation/MicroRTS/blob/master/src/ai/abstraction/partialobservability/POWorkerRush.java

microRTS is a small, deterministic, simultaneous-action RTS environment that supports fully and partially observable games. It contains hand-coded approaches and research implementations such as minimax variants, Monte Carlo search, and Monte Carlo Tree Search.

**Borrow:** experimental methodology. Test an algorithm quickly in a small, controlled world before taking on full Wargrid economy, pathfinding, terrain, factions, and tactics.

**Caution:** the simplified environment cannot establish that an algorithm will be efficient or fun in an actual Generals-like match. Its README (checked 2026-11-05) says the project was deprecated on 2025-08-11 and is no longer planned to receive updates or support; usable as a frozen sandbox only.

### 3.10 BWMetaAI — human-style strategies rather than peak strength

- **Repository:** https://github.com/jncraton/BWMetaAI

BWMetaAI aims to reproduce recognizable Brood War build orders, unit compositions, and midgame transitions. Its stated goal is varied, scoutable games that resemble playing against contemporary human strategies.

The author explicitly says it is **not** designed for especially strong play and acknowledges poor micro and building placement.

**Borrow:** authentic-looking openings, transitions, and matchup-specific personalities. **Do not mistake** this for a top-tier tactical engine.

## 4. Proposed Wargrid architecture

```text
                      ENGINE / TRUE GAME STATE
                                 |
                 visibility + allowed-info filtering
                                 v
                      PlayerObservation API
                 (no privileged game-state handle)
                                 |
                    Observation / Memory Model
         (known terrain, visible units, last sightings,
           inferred tech, uncertainty and timestamps)
                                 |
                         Strategic Director
         (defend, expand, pressure, scout, tech, recover)
                  /             |             \
                 v              v              v
          Economy Planner   Military Planner  Tactical Controller
           + Production     + Army Missions    + Engagement Eval
                  \             |             /
                   v            v            v
                    Legal PlayerCommand API
                                 |
                    Engine-side command validation
                                 |
                           Game simulation
```

### Observation boundary

An immutable per-player snapshot should include only:

- Own entities, own resources, own production queues, and owned orders.
- Currently visible enemy information, with sight/radar distinctions.
- Public information known to humans (for example global announcements if the game exposes them).
- Terrain that the player is allowed to know, including explored vs. currently visible areas.
- Events and previously observed locations that the bot may remember itself.

It should **not** include:

- Hidden enemy entity objects or references that allow resolving their live positions.
- Enemy inventory or queues not revealed by game mechanics.
- Global omniscient threat grids, exact hidden routes, or engine-internal target data.
- Full enemy tech state when the player has no evidence of it.

Enemy memory belongs to the bot's own world model and should look approximately like:

```text
EnemyContact:
  observed_type: "tank" | "unknown_vehicle" | ...
  last_position: (x, y)
  last_seen_tick: 12340
  observation_source: line_of_sight | radar | ally_shared_intel
  confidence: 0.0 .. 1.0
  estimated_speed_range: ...
  suspected_destination: optional
```

After a unit enters fog, its real position is no longer accessible. The bot can predict where it may have gone, but predictions remain guesses.

### Main systems

| System | Responsibilities | First implementation |
|---|---|---|
| Observation adapter | Legal facts and visibility filtering | Immutable snapshot per decision tick |
| World model | Contacts, uncertainty, map control, recent threats | Last-seen enemy records, simple threat map |
| Strategic director | Choose high-level goals | Utility-score 4–6 candidate goals |
| Economy manager | Worker supply, expansion, repair | Rules + target income/production ratios |
| Production planner | Unit mix, tech dependencies, production queues | Templates + counters; later BOSS-inspired search |
| Army manager | Create squads, assign objectives, reserve defense | Mission-oriented squads |
| Combat evaluator | Fight/retreat choice | Unit-value heuristic; later local fast simulation |
| Scouting manager | Discover bases, locate threats, reduce uncertainty | Priority map of unseen/important areas |
| Team coordinator | Respond to ally attacks, synchronized pushes | Shared-intel goals and coordination requests |
| Command scheduler | Limit command bursts, dedupe orders | Budgeted, stable, bounded actions |
| Explanation / tracing | Why each decision was made | Structured decision events with evidence IDs |

### Decision-making cadence

Different systems need different tick rates. For example:

- Long-horizon strategic goal reevaluation: every several in-game seconds or after a major event.
- Economy and production: every 0.5–2 seconds depending on game mechanics.
- Squad reassignment: subsecond to a few seconds.
- Combat reactions: faster, but bounded by an explicit attention and command budget.

**These are starting design ideas, not researched optimal numbers.** Measure game feel, latency, and CPU cost in headless tests. Avoid repeatedly issuing the same unchanged order.

## 5. Designing difficulty without cheating

A useful ladder changes **planning competence, knowledge acquisition, and coordination**, not the physics/economy.

| Capability | Casual | Skilled | Expert |
|---|---|---|---|
| Opening | One reliable build | Several valid openings | Matchup-/map-aware repertoire |
| Economy | Basic resource management | Avoids stalls; expands opportunistically | Forecasts resource and production needs |
| Scouting | Irregular | Scheduled and goal-directed | Information-value-driven scouting |
| Counterplay | Basic | Reacts to observed threats | Maintains competing hypotheses |
| Combat | Uses group strength thresholds | Recognizes bad fights | Evaluates likely outcomes and trades |
| Retreat | Rare | Preserves important forces | Retreats, reinforces, reengages intelligently |
| Multi-front play | Mostly one front | Occasional diversion | Coordinated, multi-front objectives |
| Teamplay | Independent | Responds to requests | Allocates roles and synchronizes attacks |

### Avoid fake weakness

A *Casual* bot should not constantly cancel units, deliberately let workers idle, or throw armies into obvious losses. Those behaviors look broken, not human. Better ways to reduce strength:

- Simpler opening repertoire and less strategic flexibility.
- Fewer simultaneously considered goals.
- Less frequent or less effective scouting.
- Lower-quality predictions rather than secretly corrupted game mechanics.
- More conservative army coordination.
- Fewer specialized counters, while retaining basic competence.

### Superhuman micro is a separate problem

A legal bot may still micro dozens of units with superhuman precision. Consider:

- A global limit on high-priority tactical command changes per interval.
- A cap on simultaneous squads receiving fine-grained attention.
- Minimum reaction cadence to new **observations** for selected skill profiles.
- Stable orders and hysteresis to avoid instant perfect target switching.

Keep basic pathing and safety behaviors functional for all difficulties; constrain exceptional micro, not fundamental unit responsiveness.

### Personalities versus skill levels

Skill and personality should be orthogonal. A skilled defensive bot and a skilled aggressive bot should have comparable strength yet distinct patterns.

Suggested personalities:

- **Aggressive:** early pressure, denial of enemy expansions.
- **Economic:** greedy openings, proactive expansions, later power spikes.
- **Defensive:** holds strategic choke points and counterattacks.
- **Mobile raider:** harassment, flanks, high-value economic targets.
- **Adaptive generalist:** scouts first, then chooses a strategy.

## 6. Concrete example: fair adaptation in a Generals-like match

1. The GLA bot scouts an enemy USA main base and **sees** two War Factories.
2. Its world model increases the probability of a vehicle-heavy opening, while noting uncertainty about actual production.
3. It reinforces an exposed road with anti-vehicle capability and requests more scouting.
4. A scout later observes an undefended USA supply expansion.
5. The strategic director weighs a raid on that expansion against a direct base assault.
6. It sends a mobile force toward the expansion through previously explored terrain.
7. When enemy defenders appear, the tactical controller re-evaluates the engagement and may retreat.
8. After the defenders vanish into fog, the bot remembers the last sighting **without** tracking them perfectly.

**What makes this smart:** the bot selects targets and counters based on evidence, uses a coherent strategy, and preserves valuable forces. **What makes this fair:** it never needed the hidden production queue or live positions of invisible units.

## 7. Tactical evaluation: start cheap

A practical early heuristic is:

```text
relative_strength = estimated_friendly_combat_value /
                    max(epsilon, estimated_enemy_combat_value)
```

Where each side's value considers:

- Unit health, DPS, range, mobility, armor, and relevant counters.
- Position, terrain, choke points, and defensive structures.
- Ability to attack current opposing targets (anti-air vs. ground-only, for example).
- Uncertainty about enemy units outside vision.
- Strategic objective value and replacement cost.

Then combine *fight outcome* with *mission value*:

```text
engagement_utility = expected_objective_gain
                   - expected_friendly_losses
                   - risk_penalty
                   - opportunity_cost
```

A force may correctly accept losses to destroy a critical supply site. Equally, it may decline a winnable fight when the trade is strategically terrible.

For later iterations, run a lightweight local battle simulator over the bot's **observed and inferred** forces. SparCraft and Stardust/FAP are good conceptual references; a simulation must never access the true hidden enemy army.

## 8. Team AI for future 3v3 / Twilight Flame-style play

Individual competent bots do **not** automatically make competent teammates. Add a lightweight, explicit team planner rather than hoping independent strategies align.

Possible team-level goals:

- Defend an ally's exposed flank.
- Coordinate attacks arriving within the same tactical window.
- Divide expansion opportunities instead of competing for the same area.
- Allocate responsibility for anti-air or artillery threats.
- Distract one opponent while an ally attacks another.
- Transfer information about **observed** enemy movements where the game's ally vision/communication rules permit it.

A simple team mission structure:

```text
TeamMission:
  type: defend_flank | raid_expansion | push_center | counter_air
  target_region: ...
  participating_players: [...] 
  desired_arrival_window: ...
  evidence: [...] 
  priority: ...
  expiration_tick: ...
```

**Caution:** team sharing must not become a loophole around fog-of-war rules. Shared intelligence should be legal player/team information, not a globally omniscient database.

## 9. Behavior-driven testing and fairness auditing

Because Wargrid is being developed with a behavior-test suite alongside the game, make bot quality measurable from day one.

### Core fairness tests

| Test | Setup | Required result |
|---|---|---|
| Hidden army | Enemy approaches outside vision and detection | Bot does not react to its **actual position** without evidence |
| Hidden build queue | Opponent secretly changes production | AI cannot immediately select exact counters |
| Last-seen enemy | Tank enters fog and changes direction | Bot retains last sighting, not updated coordinates |
| Unexplored resource | Supply point exists outside explored map | Bot cannot target it using privileged location data |
| Radar-only contact | Enemy appears on radar but not visual sight | Bot knows only information that radar reveals |
| Resources | Bot orders unaffordable unit/building | Command rejected or queued under normal player rules |
| Production | Bot requests a unit before prerequisites | Normal command validator rejects request |
| Timers | Bot repeatedly orders construction | Cannot bypass build-time limits |
| Team intelligence | Ally sees enemy; own bot does not | Shared knowledge only if normal team rules permit it |
| Replay determinism | Identical seed + observations + AI version | Repeatable decisions, except where controlled randomness is intended |

### Competence tests

| Scenario | Desired behavior |
|---|---|
| Scout sees enemy airfield | Reassess anti-air requirements; avoid unconditional perfect counters |
| Army is outnumbered | Skilled/expert bot considers retreat or reinforcement |
| Main supply exhausted | Find legal, known/observed expansion or scout for one |
| Opponent overinvests in static defense | Consider another front, expansion, tech, or harassment |
| Enemy feints | Bot may be deceived; beliefs should update with evidence |
| Ally is attacked | Consider assistance according to team priorities |
| Repeated bad attacks | Avoid endlessly repeating a losing plan |
| Enemy tech transition | Adapt over time rather than receiving instant privileged knowledge |

### Automated evaluation harness

Run headless matches with:

- Fixed random seeds and map layouts for regression.
- Diverse seeds, starting slots, factions, and map shapes for generalization.
- Cross-play among bot versions and personalities.
- Reference opponents: scripted baseline, previous release, expert variant, and eventually humans/replays.
- Side/slot swapping to detect spawn bias.

Record:

- Win rate and uncertainty interval across many matches.
- Game duration, economy income, resource float, idle production time.
- Time to first scout, expansion, and attack; scouting coverage.
- Army value traded and lost; percentage of unwinnable fights taken.
- Base defense response time and losses to raids.
- Command volume and CPU time per AI system.
- Team assistance, attack synchronization, and objective success.
- **Fairness violations** (expected to be zero).

Win rate alone is insufficient: an AI that wins by exploiting absurd precision can still be an unpleasant opponent.

### Explainability overlay / trace

For a selected bot, show:

```text
Strategic goal: RAID EASTERN SUPPLIES
Reason: supply depot observed; defensive threat estimated low
Known enemy: 2 tanks seen 18 seconds ago near middle crossing
Confidence: 0.63
Alternative considered: attack main base (rejected: high defense estimate)
Assigned squad: Raider-2
Next review: on new observation, losses, or strategy timer
```

Every decision should link to evidence IDs or observations. Include estimated beliefs, not just conclusions. That makes fairness audits, tests, and debugging much easier.

## 10. Practical implementation roadmap

### Milestone A — one legal, competent baseline bot

- Implement strict observation and validated command APIs.
- Build a world model with last-seen enemy objects.
- Add stable worker, construction, production, and basic attack logic.
- Build headless 1v1 regression tests and an event trace.
- **Done when:** bot can finish matches without unfair information or economy bonuses, manage basic economy, and avoid catastrophic stalls.

### Milestone B — scouting and strategic adaptation

- Add strategic goals: defend, expand, scout, tech, attack, raid.
- Introduce a small opening repertoire.
- Build an opponent-tech hypothesis model.
- Choose production counters from observed evidence.
- **Done when:** unseen enemy strategy changes do not trigger knowledge leaks; observed changes produce sensible responses.

### Milestone C — better tactical decisions

- Add local combat-value estimation and retreat hysteresis.
- Build squads with goals and reserve defense.
- Limit high-frequency command churn and impossible attention splitting.
- Benchmark changes against previous versions.
- **Done when:** bot preserves armies better and improves trade quality without relying on faster-than-human micro.

### Milestone D — difficulty, personality, teams

- Add competence profiles and independent strategic personalities.
- Add team missions, shared-intelligence restrictions, and cooperative behavior.
- Test 3v3 matches on maps with central choke points, multiple flanks, and contested supplies.
- **Done when:** profiles differ meaningfully, feel fair, and perform consistently across maps.

### Milestone E — advanced methods, only if justified

- Introduce BOSS-like production search if templates become limiting.
- Introduce SparCraft/FAP-like local combat simulations if heuristics fail in complex engagements.
- Experiment with Monte Carlo planning in a microRTS-style sandbox before production integration.
- Explore learned strategy classifiers only when you have enough data and clear evaluation criteria.

## 11. Suggested source-reading order

A pragmatic sequence for a Godot/Generals-style project:

1. **OpenRA AI YAML:** learn interfaces, responsibilities, and configurable personalities.  
   https://github.com/OpenRA/OpenRA/blob/bleed/mods/ra/rules/ai.yaml
2. **Zero-K CAI:** study how production, economy and army priorities interact.  
   https://github.com/ZeroK-RTS/Zero-K/blob/master/LuaRules/Gadgets/ai_CAI.lua
3. **UAlbertaBot Wiki/BOSS:** understand production-goal planning and search.  
   https://github.com/davechurchill/ualbertabot/wiki  
   https://github.com/davechurchill/ualbertabot/tree/master/BOSS
4. **SparCraft:** read how engagements can be approximated with a fast local model.  
   https://github.com/davechurchill/ualbertabot/tree/master/SparCraft
5. **Stardust:** inspect how strong competition bots connect terrain and fight evaluation.  
   https://github.com/bmnielsen/Stardust
6. **PurpleWave:** read to understand strategic diversity and matchups.  
   https://github.com/dgant/PurpleWave
7. **Cobra / PeacemakerAI:** compare opponent memory and fair observation design.  
   https://github.com/KJeff01/Cobra  
   https://github.com/duckfood/PeacemakerAI
8. **BWMetaAI:** study recognizable human-inspired build orders.  
   https://github.com/jncraton/BWMetaAI
9. **microRTS:** use as a research lab if considering search/planning algorithms.  
   https://github.com/Farama-Foundation/MicroRTS
10. **Petra:** inspect its full economy logic and explicitly avoid difficulty resource multipliers.  
    https://gitea.wildfiregames.com/0ad/0ad  
    https://docs.wildfiregames.com/js-coverage/simulation/ai/petra/config.js.gcov.html

## 12. Additional caveats: licenses, confidence, and portability

- **Concepts versus code:** studying a strategy or architecture is different from copying source. Review each project's license and any attribution/redistribution obligations before importing code.
- **Stardust:** has an additional restriction concerning tournament-submitted forks on top of its described MIT terms.
- **0 A.D. source freshness:** the `0ad/0ad` GitHub mirror is archived; use its newer Gitea repository for current project work.
- **microRTS repository:** old `santiontanon/microrts` URL redirects to `Farama-Foundation/MicroRTS`.
- **Fairness is not inherited:** a repo being open source, competitive, or advertised as non-cheating does not mean all information paths and difficulty settings are fair.
- **Engine mismatch:** BWAPI, Spring/Recoil, Warzone and OpenRA all have different state models. Use ideas and algorithms, not blind source-level ports.
- **Benchmarks matter:** claims of strong bots should ideally be supported by tournaments, repeated match data, or reproducible tests. Some project README claims are self-reported.
- **Specific Zero-K caveat:** the source carries its own `FIXME … maphax` comment on the threat check (§3.2), so a hidden-information path exists there. How far it reaches through other callers was not traced.
- **OpenRA is not a fairness model:** squad targeting ignores shroud and fog (§3.1).

## 13. Bottom line

A convincing Wargrid bot is achievable as a traditional, modular RTS AI—**no machine learning required initially**. The hard part is not making it follow a build order; it is giving it a coherent information model, strategically meaningful goals, tactical judgment, and an attention budget without taking shortcuts.

The strongest combination for this project is:

> **OpenRA architecture + Zero-K full-game ideas + UAlbertaBot production planning + Stardust/SparCraft combat evaluation + a Wargrid-specific fairness and behavior-test harness.**

Build **one** strong, fair opponent first. Then create skill levels by selectively improving its scouting, planning, adaptation, and coordination—not by changing the rules.
