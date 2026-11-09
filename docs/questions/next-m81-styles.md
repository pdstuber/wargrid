# Next: what the three bot play styles do, and how levels are tested (M8.1)

Sources. **ZH src** = ~/projects/CnC_Generals_Zero_Hour @ 0a05454, paths under `GeneralsMD/Code/GameEngine/Source/`. **Research doc** = wargrid `docs/reference/m7-verification-archive-research.md` (decoded `SkirmishScripts.scb`). Already decided, not asked: about five levels cut by removing competence, never by rule or economy bonuses; three styles (aggressive, economic, defensive) plus "random"; one difficulty and one style setting for all bots (blueprint §7 M8.1, lobby mockup, design-answers 2026-11-08). ZH has no play styles; the ZH options below are the closest things in its skirmish scripts.

## Findings (short, cited)
- **source** ZH's level differences come from scripts: Easy 3 waves, Normal 4, Hard 5; first launch about 300 s / 150 s / 10 s (`zh-defaults-followup.md` Skirmish AI; research doc "Wave timing").
- **source** ZH Hard opens with a "Rush" team (4 Missile Defenders + 2 Crusaders) that hunts as soon as it is built, plus 2 Humvee "Supply Hunters" that go for supply lines via the back route (research doc line 99).
- **source** ZH defences: first defence at escalation >= 10 (about 100 s) with credits > 1200, a flank defence at >= 20; Hard adds Patriots up to 6 and Fire Bases up to 4 later when rich (research doc lines 131, 142).
- **source** ZH's "random" faction and colour are drawn from the game's seeded random at match start, colours never repeat (ZH src GameLogic/System/GameLogic.cpp:718-806); the lobby shows the choice as "Random" (Include/GameNetwork/GameInfo.h:110-113 `getApparent*`; **inferred** others see "Random" until the game starts).
- **not found** Any ZH test or rule for how much stronger one level is than the next.

## Questions
Q1. What is the main thing that makes the aggressive style aggressive?
   a) An early rush: a first attack within the first minute or two, like ZH Hard's "Rush" team (research doc line 99)   b) More attacks over the whole game, each smaller   c) More army and fewer defences, same timing
   Recommendation: a, because an early rush is the clearest thing a player can feel. Why it matters: sets what the style test must measure (time of first attack).

Q2. Should the aggressive style also raid collectors?
   a) Yes, a small fast group goes for collectors by the back route, like ZH's "Supply Hunters" (research doc line 99)   b) No, all units go with the main attack   c) Only at higher levels
   Recommendation: c, because raiding is a competence that lower levels can lack. Why it matters: "raider" was cut as a style; this keeps the behaviour inside aggressive.

Q3. What is the main thing that makes the economic style economic?
   a) It expands to a second supply center early   b) It runs more collectors per supply center   c) It teches to stronger units before attacking
   Recommendation: a, because expansion is visible on the map and ZH bots do expand (research doc line 141 build order). Why it matters: needs the expansion rule (still open in `playtest-repair-bots.md` Q13).

Q4. When does the economic style attack?
   a) Later, with one big army   b) At the same time as the others, but with better units   c) Only when its estimate says it is stronger
   Recommendation: c, because it fits the "combat estimate before committing" in the M8 scope. Why it matters: gives economic a weak early window players can punish.

Q5. What is the main thing that makes the defensive style defensive?
   a) More base defences, early and on every approach route, like ZH Hard's extra Patriots and Fire Bases (research doc lines 131, 142)   b) Keeps its army at home until it is large   c) Both
   Recommendation: c, because defences alone are a static wall; a home army makes it play differently. Why it matters: decides the build order split.

Q6. Does the defensive style ever counter-attack?
   a) Yes, right after it beats back an attack   b) Only late in the game   c) Never; it wins by attrition
   Recommendation: a, because a bot that never attacks makes long, dull games (no time limit in ZH). Why it matters: avoids matches that never end.

Q7. When a bot's style is "random", when is the style drawn and who sees it?
   a) Drawn at match start from the match seed and hidden from players until the end — ZH draws random factions from the seed at start (GameLogic.cpp:718-806)   b) Drawn at start and shown at once   c) Drawn in the lobby and shown there
   Recommendation: a, because guessing the style is part of the fun and the seed keeps lockstep clients in agreement. Why it matters: the draw must use simulation random only.

Q8. How clearly must each level beat the one below in the ladder test?
   a) In at least 70 % of 20 seeded matches, both start slots   b) At least 60 %   c) At least 80 %
   Recommendation: a, because 60 % over 20 games is too close to chance and 80 % may force too few levels. Why it matters: it is the M8.1 exit threshold "set at planning". No ZH default.

Q9. How close in strength must the three styles of one level be?
   a) Each style wins 35 % to 65 % against the others of the same level over 20 seeded matches   b) 40 % to 60 %   c) No band; styles may differ in strength
   Recommendation: a, because styles should feel different without one being the obvious pick. Why it matters: the blueprint asks for a "strength band"; this sets it.
