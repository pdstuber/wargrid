# ZH defaults follow-up: veterancy, radar/minimap, bot behaviour

Sources. **ZH src** = ~/projects/CnC_Generals_Zero_Hour @ 0a05454, paths under GeneralsMD/Code/GameEngine/Source/. **INI** = root INIZH.big decoded to /tmp/zhq (outside the repo), cited as archive entry:line. Archive entry `data\ini\aidata.ini` is a 3-line stub ("set the values in ini/default/aidata.ini"); the real values are in `data\ini\default\aidata.ini`. That settles the open `AttackPriorityDistanceModifier` contradiction: **100.0** (default\aidata.ini:25).

## Findings (short, cited)

### Veterancy
- **source** Four levels: Regular, Veteran, Elite, Heroic (ZH src Include/Common/GameCommon.h:206-218).
- **source** XP comes only from kills. The killer gets the victim's `ExperienceValue` for the victim's current level. Not for allies or own units, not for victims under construction (ZH src GameLogic/Object/Object.cpp:2940-2965; Object/ExperienceTracker.cpp:61-68).
- **source** Level = highest level whose `ExperienceRequired` is at most the total XP (cumulative total, not per level) (ExperienceTracker.cpp:155-180). Values are per unit:
  - Ranger: gives 20 20 40 60, needs 0 40 60 120 (data\ini\object\americainfantry.ini:884-885).
  - Crusader: gives 100 100 200 400, needs 0 200 300 600 (data\ini\object\americavehicle.ini:1434-1435).
  - Humvee needs 0 100 150 300 (americavehicle.ini:109 block).
- **source** Weapon bonuses (data\ini\gamedata.ini:333-338): Veteran damage 110%, rate of fire 120%; Elite 120% / 140%; Heroic 130% / 160%.
- **source** Max health (data\ini\gamedata.ini:352-354): Veteran 120%, Elite 130%, Heroic 150%. Current health keeps its ratio (ZH src Object/Body/ActiveBody.cpp:55-63).
- **source** Self-heal: every object inherits an `AutoHealBehavior` that switches on at Elite or Heroic: 10 HP every 1000 ms, healing pauses 5000 ms after each hit (data\ini\default\object.ini:101-106; ZH src Object/Behavior/AutoHealBehavior.cpp:160-176).
- **source** No armor change by level: code has an `ARMORSET_VETERAN` flag (ActiveBody.cpp:1482-1497) but no object INI uses a veterancy armor set (0 matches for `Conditions = VETERAN/ELITE/HERO`). Not found beyond that.
- **source** Promotion sound and animation play for the owner (ActiveBody.cpp:1412-1436; Object.cpp:3109-3111).

### Radar / minimap
- **source** The minimap is drawn only while `Player::hasRadar()`. Otherwise the panel is blank (ZH src GameEngineDevice/.../W3DControlBar.cpp:80; W3DRadar.cpp:1355; Common/RTS/Player.cpp:3239-3246). `hasRadar` means at least one radar-providing building and radar not disabled by power.
- **source** USA: the Command Center grants `Upgrade_AmericaRadar` for free when construction finishes (data\ini\object\factionbuilding.ini:1177-1180, 1211-1212; upgrade.ini:31 comment "free radar"). Ready-made Command Center, so radar from tick 0.
- **source** China: the Command Center has a radar module, but the player must buy "Radar" ($500, 20 s) at the Command Center (factionbuilding.ini:3756-3758; upgrade.ini:253-259; commandset.ini:841; commandbutton.ini:1271-1278).
- **source** GLA: the Command Center has no radar. Radar comes from the Radar Van ($500, 10 s, needs Arms Dealer; built at the Command Center) (glavehicle.ini:5822-5930; commandset.ini:1118). The van is `DisableProof = Yes`.
- **source** Losing it: when a radar building is destroyed, sold or captured, or becomes disabled, the player's radar count drops, and radar is gone once the count hits 0 (ZH src GameLogic/Object/Upgrade/RadarUpgrade.cpp:72-120; Object.cpp:3825-3848; Player.cpp:3160-3200). Several providers stack. An "offline" and an "online" voice cue play on the edge (Player.cpp:3174, 3197).
- **source** Low power: `onPowerBrownOutChange` calls `disableRadar()`, and everything powered is set `DISABLED_UNDERPOWERED` (Player.cpp:3260-3272). Brownout means production below consumption, or power sabotaged (ZH src Common/RTS/Energy.cpp:100-108). Only radar flagged `DisableProof` ignores it (GLA Radar Van). When power returns the minimap returns (`enableRadar`).
- **inferred** The dish extends over 4 s (`RadarExtendTime = 4000`, factionbuilding.ini:1188-1190); presentation only.

### Skirmish AI
- **source** ZH has three levels, not four: lobby slots Easy, Medium, Brutal map to `DIFFICULTY_EASY/NORMAL/HARD` (ZH src GameLogic/System/GameLogic.cpp:1429-1431). Wargrid's five levels are already decided, so only the levers matter.
- **source** Gatherer counts (`ResourceGatherersEasy/Normal/Hard`) are identical across levels in every faction (default\aidata.ini:68-70 etc., checked all 16 entries: 2 or 5, never different between levels). So gatherers are not a lever at all in the shipped data.
- **source** Levers that do change with level:
  - Which scripts run: each script has Easy/Normal/Hard flags (ZH src ScriptEngine/ScriptEngine.cpp:6955-6972; Common/RTS/Team.cpp:1155-1177). That decides the attack waves: Easy has 3 waves, Normal 4, Hard 5; escalation tick 20 s / 10 s / 10 s; first launch about 300 s / 150 s / 10 s (decoded in docs/reference/m7-verification-archive-research.md "Wave timing").
  - Victim choice inside a squad: Easy shoots a random unit, Normal the closest, Hard all units focus the same one (ZH src AI/AIStates.cpp:5964-6030; humans always get the Hard behaviour).
  - Easy gets no shared team attack target (Team.cpp:1510-1514).
  - Easy attack priorities use a different, shorter list (research doc line "Easy uses Easy Priority").
- **source** Not a lever in skirmish: `SOLO_AI_*` rate-of-fire (80/100/120%) and health bonuses apply only when `isInSinglePlayerGame()`, which is `GAME_SINGLE_PLAYER` only, not `GAME_SKIRMISH` (Player.cpp:3370-3400; GameLogic.cpp:299-303; gamedata.ini:346-348, 356-358). So ZH skirmish bots do not cheat in stats. Matches Wargrid's "same rules".
- **source** Picking the enemy player (`AISkirmishPlayer::acquireEnemy`, ZH src AI/AISkirmishPlayer.cpp:485-552): keeps its target until that player has no units or no build facility; otherwise picks the closest enemy by base centre distance; a crippled enemy counts as far away (0.5 x huge distance); +500 distance penalty if another skirmish bot already targets that enemy; -25 distance bonus for the one that targets me. Re-checked every 5 s (line 554-563).
- **source** Picking what to hit: score = priority - floor(distance / 100), minimum 1, priority 0 never attacked (ZH src AI/AI.cpp:683-720 per the research doc; modifier 100.0 default\aidata.ini:25). Priority lists in docs/reference/m7-verification-archive-research.md "Targeting".
- **source** Attack frequency: not a fixed timer. Waves are driven by script counters (see wave table in the research doc): a wave launches when its team stands at the perimeter and the Execute script re-evaluates (30 to 210 s delay per level).
- **source** Surrender / resign: not found. `ALLOW_SURRENDER` in ZH src Common/RTS/ActionManager.cpp:637-645, 1178 is about capturing surrendered enemy infantry (prisoners), not players. No AI code path gives up. The defeat check is a generated script `MULTIPLAYER_PLAYER_DEFEAT` (GameLogic.cpp:1559-1612). Rebuilding after loss waits `RebuildDelayTimeSeconds = 30` (default\aidata.ini:58).
- **source** Reaction speed: no commands-per-second cap exists. Timers instead: base-build check every 2 s (AISkirmishPlayer.cpp:882-897, AIPlayer.cpp:2736-2742), team-build check every 2 s in skirmish (AISkirmishPlayer.cpp:922-945; base AIPlayer.cpp:2916-2922 uses 5 s), one structure at a time, `StructureSeconds = 0`, `TeamSeconds = 10` (default\aidata.ini:7-8). Guard scan 500 ms, return scan 1000 ms (default\aidata.ini:21-22). Script conditions are evaluated at their `delay` seconds with a random 0-2 s offset (research doc "Reading rules").

## Questions

Q1. How many veterancy levels do units have?
   a) Four: Regular, Veteran, Elite, Heroic — ZH default (GameCommon.h:206-218)   b) Three: Regular, Veteran, Elite   c) Two: Regular and Veteran
   Recommendation: a, because the data and the planned ground batch A (levels, XP from kills) are written for four. Why it matters: it sets every XP and bonus table.

Q2. How do units earn veterancy?
   a) Only from kills; each unit type has its own XP given and XP needed (Ranger needs 40/60/120, Crusader 200/300/600) — ZH default (Object.cpp:2962, americainfantry.ini:884-885, americavehicle.ini:1434-1435)   b) Only from kills, but one shared XP table for every unit   c) From kills and from damage dealt
   Recommendation: a, because it is already per-unit data and a more expensive unit is worth more XP. Why it matters: decides how fast armies level.

Q3. How much stronger does a promoted unit shoot?
   a) Veteran +10% damage and +20% rate of fire; Elite +20% / +40%; Heroic +30% / +60% — ZH default (gamedata.ini:333-338)   b) Same percentages but damage only   c) Half of the ZH percentages
   Recommendation: a, because it is the tuned value and the parity harness can measure it. Why it matters: veterans are the main reason to keep units alive.

Q4. How much more health does a promoted unit have?
   a) Veteran 120%, Elite 130%, Heroic 150% of max health, current health keeps its ratio — ZH default (gamedata.ini:352-354, ActiveBody.cpp:55-63)   b) No health bonus   c) Same bonus but the unit is also healed to full on promotion
   Recommendation: a, because it is the ZH value and the simplest. Why it matters: it is the only survivability bonus in ZH (no armor change by level).

Q5. Do promoted units heal themselves?
   a) Elite and Heroic units heal 10 HP per second, starting 5 s after the last hit — ZH default (default\object.ini:101-106, AutoHealBehavior.cpp:160-176)   b) No self-heal   c) Only Heroic heals
   Recommendation: a, because it is the ZH value. Why it matters: it lets high-level units recover without a repair building.

Q6. Where does a player get the minimap?
   a) It depends on the faction: USA gets it free from the Command Center, China buys a $500 Command Center upgrade, GLA builds a $500 Radar Van — ZH default (factionbuilding.ini:1177-1212, 3756; glavehicle.ini:5822-5930)   b) All factions get it free with the Command Center   c) All factions must build a separate radar building
   Recommendation: b, because Wargrid has no separate upgrade or van yet and the HUD milestone needs a minimap early; revisit when the factions have those items. Why it matters: it decides if the minimap is a tech choice or always there.

Q7. What happens to the minimap when power is low?
   a) It goes blank until power returns (an "offline" voice plays); the GLA Radar Van is immune — ZH default (Player.cpp:3260-3272, Energy.cpp:100-108, W3DRadar.cpp:1355)   b) It goes blank for every faction, no exception   c) It keeps working at low power
   Recommendation: a, because power is already in Wargrid and this is the reason to defend power plants. Why it matters: it gives low power a real cost for players.

Q8. What happens to the minimap when its radar building is lost?
   a) It goes blank once the last radar provider is destroyed, sold or captured; a second provider keeps it on — ZH default (RadarUpgrade.cpp:72-120, Player.cpp:3160-3200)   b) Once you have had it, it stays for the whole game   c) It stays but freezes on the last picture
   Recommendation: a, because it matches Q7 and keeps the Command Center worth protecting. Why it matters: it decides how much a Command Center raid hurts.

Q9. Which enemy does a bot pick to attack in a 3v3?
   a) The closest enemy base, skipping a crippled enemy, with a penalty if another bot already picked it, and a small preference for whoever attacks it — ZH default (AISkirmishPlayer.cpp:485-552)   b) Always the closest enemy base   c) Always the enemy with the weakest army (as the team sees it)
   Recommendation: a, because it already spreads three bots across three enemies, and it needs only team-visible information if the base centre is taken from what the team has seen. Why it matters: it decides if the three bots gang up or split.

Q10. How does a bot pick what to hit once it reaches the enemy?
   a) Each target gets a score of its priority minus 1 per 100 distance; defences, tanks and artillery rank highest, command buildings lowest — ZH default (AI.cpp:683-720, default\aidata.ini:25)   b) The closest thing that can hurt it   c) The weakest thing in range
   Recommendation: a, because it is cheap and reads only visible objects; the exact priority numbers can be tuned later. Why it matters: it decides if bots snipe harvesters or walk into defences.

Q11. When does a bot launch an attack?
   a) On a timed wave schedule that depends on level: for example the first wave about 150 s on Normal, 300 s on Easy, 10 s on Hard, waves repeat while their team stands ready — ZH default (research doc "Wave timing")   b) When its own estimate says the army is stronger than what it saw of the enemy   c) Both: a schedule sets the earliest time, the estimate sets the actual launch
   Recommendation: c, because a pure timer ignores the situation and a pure estimate may never fire. Why it matters: it is the main driver of how a level feels.

Q12. How do lower levels play worse in a fight?
   a) Low levels pick a random enemy unit to shoot, middle levels the closest, top levels all focus the same one; Easy also shares no common target — ZH default (AIStates.cpp:5964-6030, Team.cpp:1510)   b) Same targeting at every level; only the decision quality (Q11, Q13) changes   c) Low levels shoot the closest unit, top levels focus the weakest
   Recommendation: b, because "never fake weakness" is already decided for M8.1 and random targeting looks like a bug to players. Why it matters: it picks whether focus fire is a skill the bot has or a level switch.

Q13. How often does a bot make a decision?
   a) Every 2 s for building and production, every 5 s to re-pick its enemy, and script checks 30 to 210 s apart; no commands-per-second cap — ZH default (AISkirmishPlayer.cpp:882-945, 554-563; default\aidata.ini:7-8)   b) A decision every 1 s at the top level and every 5 s at the lowest, inside the human command budget   c) A decision every 2 s at every level
   Recommendation: b, because the budget is already decided to grow with level and a slower tick is an honest way to build the lower levels. Why it matters: it is the concrete number that implements the human-plausible budget.

Q14. Does a bot ever give up?
   a) Never: it plays until every building and unit is gone, and rebuilds lost base buildings after 30 s — ZH default (default\aidata.ini:58; no surrender code found)   b) It leaves the game (counts as defeated) when it has no production building and no army for a set time   c) It never leaves, but stops attacking and only defends when it has no production
   Recommendation: a, because a human in the match decides when the game ends and a quitting bot can end a 3v3 early. Why it matters: it decides how long an already-lost bot match drags on.
