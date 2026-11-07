# M7 Fm1 blocker: decision (2026-11-07)

Status: decided by the Opus decision agent (user away, design delegated); nothing applied to the repo. Two items need the user's sign-off (end of file). Tree for every number here: `m7-factions` b7c9ae3 plus the uncommitted working tree as of 2026-11-07 (playtest fixes, T1/T2/T3 of [the rework plan](m7-economy-rework-plan.md) Revision 2), copied to scratch (`scratchpad/fm1probe`, probes in `scratchpad/fm1scripts`), Apple M6, headless. Labels: **scratch** (measured in that copy), **source-read**, **derived**.

## Diagnosis

The Fm1 stalemate is a map-supply problem, not a rate or bot bug.

- **Every box on the map is gone.** `skirmish.json` has 2 piles x 200 boxes = 15,000 credits per side (plus 10,000 start). Scratch, Fm1 on the T3 tree: seat 2's pile empties at tick 17290, seat 1's at 17574; income FRC 15,135, USA 16,375 (each side drained its own pile; the few extra credits are salvage/crates). From tick 17999 all 7 laborers and the Chinook are `idle`, credits stay 85 / 300 to the cap. USA has no barracks or factory left (lost about 7500-19500), FRC has every building but no money; laborers have no weapon. Nothing changes after about 22500, so **raising the cap cannot end the match**.
- **The rates are right.** FRC income about 1350 per 1500 ticks = 1620/min (one held pile with 7 laborers: the ZH 4-laborer cap is 1590/min); USA about 1500/min from one Chinook (ZH 1468 at 312.5 units). Collectors are not idle while boxes remain (phases loading / waiting_source / flying at every sample before 17290). The bot keeps 7 laborers and 1 Chinook as designed.
- **Why it ended before.** At b7c9ae3 the faster economy (laborer pile hold 10 ticks) built armies early and the match ended at 10512 with boxes left. The parity economy spends the same 25,000 credits per side over 17,500 ticks; both armies trade evenly and run dry together.
- **Cs1 shows the same pattern**: both piles empty by 19074 and the win at 24916 comes from the army left over, so it is luck, not margin.
- **The 200 is not a Zero Hour number.** It is M3's "one fixed authored 200-box source" ([m3-economy](m3-economy.md) "Explicit M3 departures"), kept when `skirmish.json` was hand-written. The pile is now a 4x5 `SupplyDock` footprint (BOX 50 x 61), and a `SupplyDock` holds 400 boxes (source-read, `object/civilianbuilding.ini:427,505-506`, [m7-economy-parity](m7-economy-parity.md) line 16); the converter (`tools/zh_map/convert.py` `BOXES = {"SupplyDock": 400}`) and `ashfall.json` (12 x 400) already use 400. A ZH 1v1 map also has more than one pile per side (Tournament Desert 2,200 boxes for 2 players), so 400 per side is still lean.

## Decision: D, `skirmish.json` piles 200 -> 400 boxes

Data only: two numbers in one map file. No bot change, no rate change, no faction id, no code. The 5 % parity rows do not move (`test_supply_parity.gd` builds its own layouts). `ashfall.json`, the base scene (its own 200-box source, Bs1) and every `add_supply_source(..., 200)` fixture stay as they are.

Rejected:
- **A, accept a stalemate pin**: freezes a test whose point is a decisive FRC match, and the stalemate is an artefact of M3 data, not of the game.
- **Raise the cap**: shown useless above (no income and no army after about 22500).
- **E, bot changes** (attack when poor, sell, expand): M8 territory; the user owns bot constants.
- **C, retune load/unload**: breaks the parity rows.

## Measured outcome of D (scratch)

| check | T3 tree (200 boxes) | with D (400) | window / pin |
|---|---|---|---|
| Fm1 | ongoing at 45000 | **won 23534, winner 1 (FRC)**; piles 130 / 144 left; income 20,085 / 19,975 | won inside 45000: yes; pinned winner 2: **changes** |
| Fm1 seen | (stalemate) delivery, hub_pair, crate; hole false | delivery, hub_pair, crate true; **hole false** | **hole no longer happens** |
| Cs1 | won 24916, winner 2 | won 26359, winner 2, seen all true, piles not empty | inside cap, same winner |
| S1 | 8501, winner 1 | 8501, winner 1 (match ends before any pile empties) | 7000-17999 winner 1: yes |
| S1 core series | 7172030720134552603 | 7172030720134552603 (unchanged) | re-pin |
| S1 conservation literal | 400 | needs 800 (the check sums both piles) | literal update |
| K1 | boxes 200 | needs 400 | literal update |
| TB3 / TB4 (ashfall, untouched) | 020f659e77ee6c20 / 7692526877276561850 | same | re-pin |
| team match (ashfall) | not run before | `TEAM MATCH cap tick=45000 winner=null units_peak=160` | cap, winner null: yes; `units_peak` 171 -> 160: **user** |
| netplay match terminal | not run | not run (needs the relay) | executing agent re-pins |

Full scratch suite with D: 480 cases / 136,015 checks / 34 failures = the 7 T3 `test_supply` literal groups (Su2, Su4, Su6, Gt1, Gt2, Lb1; unrelated to D, T3/T4 work) + S1 outcome, S1 series, S1 conservation, K1, Cs1 pin, Fm1 pin, Fm1 seen (hole), TB3, TB4.

Why the winner flips: in both the 200 and 400 runs FRC is ahead (USA loses its factory about 7500, power plant and barracks by about 18000); with 200 boxes FRC's pile empties at the same moment, with 400 it keeps producing and finishes the USA base. The old winner 2 belonged to the pre-parity economy.

The **hole** event: no FRC building dies in the new Fm1 (FRC wins), and none in the 200-box stalemate either, so no option (A, cap, D) keeps it; it is a consequence of the parity economy, not of D. The team match on ashfall shows no hole either (scratch, sampled every 30 ticks to 45000). Holes stay covered by the RH1 unit test (`test_rebuild_holes.gd`). Decision: drop `"hole"` from Fm1's `seen` list, pending the user's sign-off.

## Steps for the executing agent

Do these after (or together with) T4's own work; record each pin old (b7c9ae3) -> new with the tree in `m7-verification.md`.

1. `game/data/maps/skirmish.json`: both `"boxes": 200` -> `"boxes": 400` by an asserted replacement (exactly 2 occurrences). Nothing else in the file.
2. `game/tests/test_skirmish.gd` K1: `boxes == 200` (both sources) -> `400`.
3. `game/tests/test_skirmish_match.gd`:
   - S1: `stock + carried + delivered != 400` -> `800`; `TERMINAL_TICK` 9473 -> 8501 (winner 1 unchanged); `S1_CORE_SERIES` 8505231937702596599 -> 7172030720134552603.
   - Cs1: `CHINA_TERMINAL_TICK` 16258 -> 26359 (winner 2 unchanged).
   - Fm1: `FRC_TERMINAL_TICK` 10512 -> 23534, `FRC_WINNER` 2 -> 1; remove `"hole": false` from `seen`, the `if building.has("rebuild"): seen.hole = true` line, and "a hole, " from the check message.
4. `game/tests/test_team_match.gd`: TB3 digest -> 020f659e77ee6c20, TB4 series -> 7692526877276561850 (T3 values; D does not touch ashfall).
5. `tools/run_team_match.sh`: the `units_peak` pin 171 -> 160 is a user item; apply it only as "pending user sign-off" in the record, or leave the script red and say so. Do not loosen the regex.
6. `tools/run_netplay.sh` match terminal tick: run the match scenario on the final tree and re-pin (was 8331).
7. Docs: `m7-verification.md` (record: stalemate diagnosis, D, pins, the two user items); `m7-economy-parity.md` (one line: `skirmish.json` piles 200 -> 400, the `SupplyDock` value, this file). README only if it states the box count (it does not today).
8. Verify on the final tree: full suite (only the still-pending T3 literal cases may fail if T4 has not fixed them; zero after T4), `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/run_team_match.sh`, the netplay scenarios, `sh tools/run_benchmark.sh` (the profile's skirmish phase uses this map) with a ledger row; the replay trace stays identical to the base (the replay test uses its own 200-box source).

Stop and go back to the user if: Fm1 or Cs1 is not won inside 45000 on the final tree, S1 leaves 7000-17999 or winner 1, or any number above differs (the tree moved: re-measure first, then report).

## Needs the user

- Fm1 winner 2 -> 1 and the dropped `hole` observation (section 5 of the rework plan lists both as user decisions). Alternative if the user wants a hole in an integration test: a scripted FRC-loses scenario (new test, not a re-pin).
- Team match `units_peak` 171 -> 160.
- The map change itself (D was not among the three options listed earlier for this stop: bot rule, cap, accept); veto restores 200 and leaves A as the only non-bot option.
