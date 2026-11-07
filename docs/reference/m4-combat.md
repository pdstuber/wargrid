# M4 combat reference — 2026-11-03

Status: **SOURCE/CONFIG SUPPORTED; RETAIL UNVERIFIED**. Planning research only. User selected source-informed stats with provisional grid geometry. No implementation or runtime parity claim.

## Provenance

Read local official checkout `~/projects/CnC_Generals_Zero_Hour`, revision `0a05454d8574207440a5fb15241b98ad0b435590`. Read root member `Command & Conquer Generals - Zero Hour/INIZH.big` from `~/CnC/Command & Conquer Generals - Zero Hour.tar.gz` in memory; verified SHA-256 `1a6d41a7a2cb31e67ad2f868aca9264ad069c275e0074f8a0d970a336071e9a0`, checked entry bounds. Decoded selected payloads only in `/tmp/wargrid-m4-plan/`, outside repository. Archives unchanged. Effective retail overrides/mod/version remain unresolved: [installation evidence](installation.md).

## Selected data

Paths below are embedded BIG payloads; line numbers refer to decoded text. Values are observations, not copied implementation.

| Payload and lines | Observed fields | Approved M4 use |
|---|---|---|
| `Data\INI\Object\AmericaInfantry.ini` 856–882, 923–924 | Ranger primary rifle; HumanArmor; barracks prerequisite; cost225, build5s, health180 | infantry225/150 ticks/180HP |
| `Data\INI\Object\AmericaVehicle.ini` 1413–1432,1464–1465 | Crusader primary tank gun; TankArmor; cost900, build10s, factory prerequisite; health480; secondary machine gun commented out | tank900/300 ticks/480HP, one weapon |
| Same 1698,1729; 98,147 | DozerArmor/250HP; HumveeArmor/240HP | builder health; legacy unarmed vehicle health |
| `Data\INI\Object\AmericaAir.ini` 2213,2242 | ChinookArmor/300HP | collector health; air target excluded by M4 ground weapons |
| `Data\INI\Object\FactionBuilding.ini` 21888–21919 | Barracks600/10s/0 power, StructureArmor/1000HP; reactor prerequisite commented out | barracks600/300 ticks, no prerequisite |
| Same 4825,4844;18724,18742;24932,24950 | StructureArmor; reactor800HP/depot2000HP/factory2000HP | building health |
| `Data\INI\Weapon.ini` 729–747 | Rifle5 damage, SMALL_ARMS, range100 source units, 100ms shot delay, clip3, reload700ms | 5000 milliHP,3-tick shot delay,3 shots,21-tick reload; grid range4 provisional |
| Same 325–346 | Tank60 damage, ARMOR_PIERCING, range150, delay2000ms, unlimited clip; projectile speed400, radius5, scatter vs infantry10 | 60000 milliHP,60 ticks, grid range6; projectile/splash/scatter omitted explicitly |
| `Data\INI\Armor.ini` 48–63,124–143,145–165,251–270,513–527,562–585 | Human AP10%, default small arms100%; Tank/Dozer small arms25%, default AP100%; Humvee small arms50%; Structure small arms50%, AP100%; Chinook default50% | integer percentage matrix for two selected damage types |

Unspecified armor coefficients initialize to 1.0 in `GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Armor.cpp` 54–64. Same file67–79 multiplies damage by coefficient: `damage *= m_damageCoefficient[t];`. Source clamps negative damage to zero. Wargrid represents health/damage in integer thousandths; rifle against tank loses1.25HP, not rounded1HP.

`GeneralsMD/Code/GameEngine/Source/GameLogic/Object/Weapon.cpp` 407–408 converts milliseconds to logic frames with ceiling. At30Hz,100/700/2000ms become3/21/60 ticks. Lines2642–2671 decrement ammo, reload empty clip, otherwise set next shot to now+delay; reload at1908–1915 resets ammo and sets next fire to reload start+reload duration. Proposed stationary rifle fixture fires at ticks0,3,6,27,30,33; tank0,60,120. This is a bounded source-informed timing fixture, not measured retail TTK.

## Deliberate departures and open evidence

All grid ranges, movement speeds, footprint distance, full-health foundations, instantaneous direct hits, no line-of-sight occlusion, simultaneous damage and simplified target priority are Wargrid prototype choices. No splash, scatter, projectiles, friendly fire, upgrades, veterancy, healing/repair, air attacks or tank crushing. Source tank-vs-infantry behavior includes scatter/radius: the adopted direct6HP hit does NOT establish retail matchup fidelity. Range calibration, retail shots/TTK, effective config and manual playability remain open.

Ground-only targeting leaves collectors immune to this roster; they do not count for victory. Scenario removal still tests their death cleanup. Buildings and builders remain attackable, so this does not prevent match completion. Never describe this as verified Zero Hour targeting.

[Approved design](../superpowers/specs/2026-11-03-m4-combat-design.md) owns adoption decisions; [execution plan](../superpowers/plans/2026-11-03-m4-combat.md) owns exact contracts. Keep source-supported facts separate from these proposals.
