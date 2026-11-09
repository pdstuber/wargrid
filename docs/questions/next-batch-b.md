# Next: ground batch B systems (stealth, detection, capture)

Sources. **ZH src** = ~/projects/CnC_Generals_Zero_Hour @ 0a05454, paths under `GeneralsMD/Code/GameEngine/Source/`. **INI** = retail root `INIZH.big` decoded into the session scratchpad, cited as archive entry:line. Batch B's scope is "refine after the M7.9 design" (blueprint §7); these questions cover the system rules only, not per-unit numbers. Already decided, not asked: which units and upgrades are in batch B.

## Findings (short, cited)
- **source** What breaks stealth is per unit (`StealthForbiddenConditions`): Pathfinder only while moving, stays hidden while shooting (`data\ini\object\americainfantry.ini:1843-1849`); Jarmen Kell while attacking (`glainfantry.ini:618-620`); Black Lotus while using an ability (`chinainfantry.ini:695-698`); Sentry Drone while firing or moving (`americavehicle.ini:2222-2227`); Rebel camouflage while attacking or using an ability, needs an upgrade (`glainfantry.ini:235-238`).
- **source** Re-hiding takes `StealthDelay`: 0 s Pathfinder, 2 s Kell and Sentry Drone, 2.5 s Black Lotus and Rebel (same lines).
- **source** Detectors: Pathfinder, Black Lotus, Sentry/Scout/Spy Drones, Troop Crawler, Overlord gattling add-on, Listening Outpost, Radar Van, Stinger soldier, and the base defences Patriot, Gattling Cannon, Tunnel Network, plus the Strategy Center (`StealthDetectorUpdate` in `americavehicle.ini`, `chinavehicle.ini`, `glainfantry.ini`, `glavehicle.ini`, `factionbuilding.ini:7080, 15076, 28885, 31660`). Dozers and Workers detect mines only (`ExtraRequiredKindOf = MINE`, americavehicle.ini dozer block).
- **source** Detection range is the detector's vision range unless `DetectionRange` is set (Sentry Drone 225); rescans every 500-900 ms (Object/Update/StealthDetectorUpdate.cpp:191-199; americavehicle.ini:2266-2267).
- **source** "Detected" is a status on the stealthed object (Object/Update/StealthUpdate.cpp:870-895). **inferred** once detected, every enemy sees it, not only the detector's team.
- **source** Some units, once revealed, make idle enemies attack them at once (`OrderIdleEnemiesToAttackMeUponReveal = Yes`: Pathfinder, Burton, Black Lotus, Kell, Rebel, Saboteur, Hijacker, Bomb Truck...).
- **source** Own stealthed units are drawn half see-through to their owner (`StealthFriendlyOpacity = 50.0%`, `data\ini\gamedata.ini:263`).
- **source** Ranger capture building: 3 s to prepare, 20 s to capture, 15 s before the next one (americainfantry.ini:1035-1036; `data\ini\specialpower.ini:491-495`).

## Questions
Q1. Does shooting reveal a stealthed unit?
   a) Depends on the unit, as in ZH (Kell, Rebel, Sentry Drone revealed; Pathfinder stays hidden) — ZH default (americainfantry.ini:1844, glainfantry.ini:619)   b) Always revealed while shooting   c) Never revealed by shooting
   Recommendation: a, because it is per-unit data and gives each stealth unit its role. Why it matters: one data field per unit, no faction branch.

Q2. Does moving reveal a stealthed unit?
   a) Depends on the unit, as in ZH (Pathfinder and Sentry Drone revealed while moving; Kell and Lotus not) — ZH default (americainfantry.ini:1844, americavehicle.ini:2223)   b) Never   c) Always
   Recommendation: a, because it is per-unit data. Why it matters: decides if a sniper must stop to hide.

Q3. How long until a unit hides again after it was revealed?
   a) Per unit: 0 to 2.5 s — ZH default (StealthDelay lines above)   b) A fixed 2 s for all   c) Instantly
   Recommendation: a, because it is ZH data. Why it matters: sets the window for the enemy to shoot back.

Q4. Who can see stealthed units?
   a) Only detectors: listed units plus base defences (Patriot, Gattling Cannon, Tunnel) and the Strategy Center — ZH default (StealthDetectorUpdate entries above)   b) Any unit standing very close   c) Detectors plus any unit that is being shot by it
   Recommendation: a, because base defences detecting is what keeps stealth from being a free win. Why it matters: detection is a new per-tick scan per detector.

Q5. How far does a detector see stealthed units?
   a) Its normal vision range unless set otherwise (Sentry Drone 225), rescanning every 0.5-0.9 s — ZH default (StealthDetectorUpdate.cpp:191-199)   b) Half its vision range   c) A fixed range for all detectors
   Recommendation: a, because it is ZH and reuses the vision value. Why it matters: rescan interval sets the per-tick cost.

Q6. Once a stealthed unit is detected, who can see and shoot it?
   a) Every enemy, not only the detector's team — ZH (status on the object, StealthUpdate.cpp:870-895; inferred)   b) Only the detector's team   c) Only the detector itself
   Recommendation: b, because Wargrid's fog is per team and a third team should not profit from someone else's detector; a is simpler. Why it matters: a 3v3 has only two teams, so a and b differ only with more teams later.

Q7. When a stealth unit is revealed, do idle enemies near it attack it at once?
   a) Yes, for the units ZH marks (Pathfinder, Kell, Lotus, Rebel, Saboteur, Hijacker, Bomb Truck) — ZH default (`OrderIdleEnemiesToAttackMeUponReveal`)   b) Only through normal auto-targeting   c) Never
   Recommendation: a, because it is per-unit data and punishes careless reveals. Why it matters: a reveal event that issues orders to enemy units must stay deterministic.

Q8. How long does capturing a building with infantry take?
   a) 3 s to prepare plus 20 s, then 15 s before the next capture — ZH default for Ranger (americainfantry.ini:1035-1036, specialpower.ini:491-495)   b) 10 s total   c) Instant once the upgrade is bought
   Recommendation: a, because it is ZH data and gives defenders time to react. Why it matters: a long channel needs an interrupt rule (unit hit, building destroyed) in the same-tick table.
