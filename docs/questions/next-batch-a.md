# Next: ground batch A systems (upgrades, travelling shots, hazards, garrison, regeneration)

Sources. **ZH src** = ~/projects/CnC_Generals_Zero_Hour @ 0a05454, paths under `GeneralsMD/Code/GameEngine/Source/`. **INI** = retail root `INIZH.big` decoded into the session scratchpad, cited as archive entry:line. Already decided, not asked: veterancy (all ZH), repair, rank-gated units by prerequisites only, all shells travel, upgrade split, nuclear silo without missile, batch A/B unit split (blueprint §7, design-answers 2026-11-08). Wargrid today refunds a destroyed factory's queue (`simulation.gd:794, 812`), as ZH does (ProductionUpdate.cpp:1133-1137); not asked.

## Findings (short, cited)
- **source** Player-wide upgrades are only taken away when their research is cancelled (Object/Update/ProductionUpdate.cpp:379; Common/RTS/Player.cpp:3118 has no other caller). So losing the building that researched an upgrade keeps the upgrade. Per-object add-ons die with their object (Object/Die/UpgradeDie.cpp:75).
- **source** Prerequisites are checked only when an order is queued (ProductionUpdate.cpp:392 `canMakeUnit` in `queueCreateUnit`; Common/System/BuildAssistant.cpp:1308-1332 `CANMAKE_NO_PREREQ`). No later re-check found, so queued units finish after a prerequisite is lost.
- **source** A dumb shell flies to the target's position at the moment of firing (Object/Behavior/DumbProjectileBehavior.cpp:358-395). It only follows a moving target when `FlightPathAdjustDistPerFrame > 0` (:601-621); no retail object sets it (0 matches in `data\ini\object\`). Crusader shell: 400 units/s, damage radius 5 (`data\ini\weapon.ini:325-334`). **inferred** a fast unit can outrun a slow shell.
- **source** Tank shells hit structures and walls on the way (`ProjectileCollidesWith = STRUCTURES WALLS`, weapon.ini:345); against infantry they scatter up to 10 units at random (`ScatterRadiusVsInfantry = 10.0`, weapon.ini:328).
- **source** Minimum range: a unit too close to its target backs away to fire (Object/Weapon.cpp:2028-2040). Tomahawk 100, Inferno Cannon 50 (weapon.ini:2823, 3714).
- **source** Poison and radiation fields hurt allies, own units and neutrals, not aircraft (`RadiusDamageAffects = ALLIES ENEMIES NEUTRALS NOT_AIRBORNE`, weapon.ini:3451, 3468, 3604). The Toxin Truck's own spray also hurts allies (weapon.ini:3031).
- **source** A small poison field lives a fixed 10 s from creation (`data\ini\object\system.ini:1910-1912`) and blasts a small cleaning shot at its core when created so fields do not stack (system.ini:1915-1916). Not "until some time after the last hit" as the blueprint's batch A text puts it.
- **source** Hazard damage by armour: tanks take 25 % poison and 50 % radiation, trucks 50 % poison, buildings 1 % poison and 0 % radiation, Hazmat troops 0 % (`data\ini\armor.ini:130, 132, 194, 568, 571, 70-71`). **inferred** ordinary infantry take 100 % (no POISON line in `HumanArmor`, armor.ini:48-61).
- **source** The FRC-equivalent Palace (GLA Palace) holds 5 and its garrison cannot be cleared by flame/toxin "clear building" weapons (`ContainMax = 5`, `ImmuneToClearBuildingAttacks = Yes`, `data\ini\object\factionbuilding.ini:16997-17001`).
- **source** Only USA buildings slowly self-heal: 0.3 % of max health per second after 3 s without damage (`data\ini\gamedata.ini:392-393`; `BaseRegenerateUpdate` on 12 USA buildings only, e.g. Command Center factionbuilding.ini:1195; logic in Object/Update/BaseRenerateUpdate.cpp:118-142, not while under construction or being sold).

## Questions
**Answered 2026-11-09: all a (Zero Hour default)**; recorded in the [design answers](../reference/design-answers-2026-11-08.md#ground-batch-a-systems-user-2026-11-09).

Q1. If the building that researched an upgrade is destroyed, does the player keep the upgrade?
   a) Yes, researched upgrades stay — ZH default (ProductionUpdate.cpp:379, Player.cpp:3118)   b) No, the upgrade is lost with the building   c) Lost until the building is rebuilt
   Recommendation: a, because it is ZH and needs no extra state. Why it matters: sets the value of raiding tech buildings.

Q2. If a vehicle with an add-on (for example an Overlord's gattling) dies, is the add-on gone?
   a) Yes, add-ons belong to that one vehicle — ZH default (UpgradeDie.cpp:75)   b) The player keeps a credit for the next vehicle
   Recommendation: a, because add-ons are per-object upgrades in the decided split. Why it matters: decides where add-on state lives.

Q3. If a prerequisite building is lost while units are queued, what happens to the queue?
   a) Queued units still finish; new orders are refused until it is rebuilt — ZH default (ProductionUpdate.cpp:392, BuildAssistant.cpp:1308-1332)   b) Queued units pause until it is rebuilt   c) Queued units are cancelled and refunded
   Recommendation: a, because the check happens once, at queueing, which is cheap and same-tick safe. Why it matters: needs a same-tick case against "building destroyed".

Q4. Where does a tank shell land if its target moves after the shot?
   a) Where the target was when the shell was fired; a fast unit can dodge — ZH default (DumbProjectileBehavior.cpp:358-395, :601-621 unused in retail)   b) The shell follows the target   c) It always hits if the target was in range when fired
   Recommendation: a, because it is ZH and simplest to make deterministic. Why it matters: decides if speed protects light vehicles.

Q5. Does a tank shell hit a building that stands between the tank and its target?
   a) Yes, shells hit structures and walls on the way — ZH default (weapon.ini:345)   b) No, shells fly over everything   c) Only low shots are blocked
   Recommendation: a, because it is ZH and protects units behind buildings. Why it matters: needs a per-tick collision check for every shell in flight.

Q6. Should tank shells randomly miss soldiers?
   a) Yes, up to a small radius (Crusader 10 units) using the simulation's seeded random — ZH default (weapon.ini:328)   b) No, shells hit soldiers exactly   c) Only artillery scatters
   Recommendation: a, because it is the ZH reason tanks are weak against infantry, and it uses the existing seeded random. Why it matters: changes time-to-kill on infantry and re-pins combat traces.

Q7. When an artillery unit is ordered to hit something too close, what does it do?
   a) It backs away until the target is past its minimum range, then fires — ZH default (Weapon.cpp:2028-2040)   b) It refuses the order   c) It waits until the target moves away
   Recommendation: a, because players expect an order to be carried out. Why it matters: needs a "back away" movement goal next to "approach".

Q8. Do poison and radiation fields hurt your own and allied units?
   a) Yes, everyone on the ground except aircraft — ZH default (weapon.ini:3451, 3468, 3604)   b) Only enemies   c) Enemies and neutrals only
   Recommendation: a, because splash already hurts allies in Wargrid (M6 decision) and it keeps one rule. Why it matters: Toxin Truck positioning needs care.

Q9. How long does a poison field last?
   a) A fixed 10 s per field; a new field cleans the spot first so fields never stack — ZH default (system.ini:1910-1916)   b) Until a set time after the last hit (as the blueprint text says)   c) Fields stack and add damage
   Recommendation: a, because it is ZH and bounds the number of live fields. Why it matters: the blueprint wording differs from ZH; one must change.

Q10. How much do poison and radiation hurt vehicles and buildings?
   a) ZH armour table: tanks 25 % poison and 50 % radiation, trucks 50 % poison, buildings 1 % poison and 0 % radiation, Hazmat troops immune — ZH default (armor.ini:70-71, 130-132, 194, 568-571)   b) Hazards hurt infantry only   c) Full damage to everything
   Recommendation: a, because it is ZH data and armour types exist already. Why it matters: decides if toxins are anti-infantry only.

Q11. Can flame or toxin weapons clear the soldiers out of the FRC Palace?
   a) No, the Palace is immune to clear-building weapons — ZH default (factionbuilding.ini:16997-17001)   b) Yes, like any garrisoned building
   Recommendation: a, because it is ZH and the Palace is the FRC's late-game anchor. Why it matters: one flag per garrisonable building.

Q12. Should USA buildings slowly repair themselves?
   a) Yes, USA buildings only: 0.3 % of max health per second after 3 s without damage — ZH default (gamedata.ini:392-393, factionbuilding.ini:1195, BaseRenerateUpdate.cpp:118-142)   b) All factions' buildings   c) None; only builders repair (already decided)
   Recommendation: a, because it is capability data on the USA buildings, not a faction branch. Why it matters: it was not part of the repair answers and changes how long damaged USA bases last.
