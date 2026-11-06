# Zero Hour parity harness

How to measure a Zero Hour mechanic frame by frame, in any milestone. Origin, routes tried and the first results: [parity harness spike](zero-hour-parity-spike.md). Standing: it measures a **source build** of Zero Hour (native macOS fork plus a small local patch), not the shipped `Game.dat`; label results **measured (source build)**. How far that substitutes for [level 1](zero-hour-verification.md#level-1-protocol-reduced-by-user-decision-2026-11-03) is recorded there.

## When to use it

Whenever a plan or a playtest question touches a mechanic Zero Hour also has (movement, turning, weapon range and cadence, damage and time-to-kill, splash, harvesting, production timing), measure it instead of estimating. Typical uses before the parity gate: calibrate a provisional value, settle "does Zero Hour do X" during design, or explain a playtest feel complaint. Results are evidence; differences go to a decision list in the milestone's design or verification note and never change Wargrid numbers automatically (same rule as the [verification doc](zero-hour-verification.md)).

Not covered: anything that needs the retail binary (exact retail floating point, replay CRCs), rendering, sound or UI feel.

## Setup (once per machine)

1. Game data: extracted retail copy in `/Users/pdstuber/CnC/run/` ([installation](installation.md)). Other location: `ZH_PARITY_DATA=<dir containing INIZH.big>`.
2. Engine: the parity patch exists only in the local branch `wargrid-parity` of `/Users/pdstuber/projects/GeneralsGameCode-macOS` (never pushed; contents in the [spike](zero-hour-parity-spike.md#what-was-built)). On another machine, clone [dvcdsys/GeneralsGameCode-macOS](https://github.com/dvcdsys/GeneralsGameCode-macOS), then carry the branch over without publishing it: on this machine `git -C /Users/pdstuber/projects/GeneralsGameCode-macOS bundle create wargrid-parity.bundle 8fedb1649..wargrid-parity`, on the other `git fetch <path>/wargrid-parity.bundle wargrid-parity:wargrid-parity && git switch wargrid-parity`. Other location: `ZH_PARITY_BIN=<path to generalszh_api>`.
3. Build (about 15 minutes clean, Command Line Tools are enough):
   `cmake --preset apple-arm64-release -DRTS_BUILD_OUTPUT_SUFFIX=_api && cmake --build build/apple-arm64-release --config Release --target z_generals`

The fork is GPL code with EA's additional terms. It stays outside Wargrid; the harness only talks to it over localhost HTTP and contains no EA code or data.

## Run

```sh
python3 -I tools/zh_parity/parity.py [--out DIR] [scenario ...]   # default: all scenarios
python3 -I tools/zh_parity/analyze.py [--traces DIR]              # metrics vs Wargrid values
python3 -I tools/zh_parity/analyze.py --self-test                 # analysis self-check (also in CI)
```

Traces go to `~/CnC/parity/traces/` (outside git): one `<scenario>.tsv` (first line JSON metadata, then one row per unit per logic frame) and a game log per scenario. Each scenario starts its own game: about 20 s start-up plus about one HTTP round-trip per frame, so a 600-frame scenario takes one to two minutes. The game always runs `-headless -noaudio`; the harness aborts if the game reports it is not headless. Never run it windowed without asking (a windowed run plays loud sound).

## Scenarios

| Scenario | Mechanic | Metrics |
|---|---|---|
| `move_<unit>` | straight move from rest | start delay, cruise and peak speed, acceleration, braking |
| `turn_<unit>` | move to a point behind the unit | turn rate, turn frames, start delay |
| `range_<unit>` | `attack_target` from beyond range | first-shot distance, intervals |
| `reach_<unit>` | idle unit, bisected gap | farthest stationary firing distance (centre to centre) |
| `rof_crusader`, `burst_ranger` | firing at a structure | shot interval, burst pattern |
| `duel_<unit>` | mirror duel, defender fires back | time-to-kill, winner |
| `splash_crusader` | tank shell into a five-Ranger cluster | shots to kill, hits, splash damage on neighbours |
| `supply_chinook` | supply centre and warehouse 400 apart | deposit size, cycle frames, cruise speed |
| `retaliate_ranger`, `retaliate_bisect`, `retaliate_return` | an attacker (tank, or a Ranger for `_return`) hits one idle Ranger; Rangers at set distances | who joins (starts moving, fires) and how far they chase; read from the trace by hand, no `analyze.py` metric |

Units: `ranger` = `AmericaInfantryRanger`, `crusader` = `AmericaTankCrusader`, `dozer` = `AmericaVehicleDozer`. Any object template from `INIZH.big` works (see `strings INIZH.big | rg '^Object '`).

## Adding a scenario

1. In `parity.py`, write a factory returning `run(g)`: find space with `g.clear_strip(length, width)`, place units with `g.spawn(template, x, y, angle, owner)` (`owner`: omit for the API player, `g.enemy` for a hostile human slot without AI, `g.civilian` for neutral), order with `g.command(verb, ids, **params)`, then `g.record(ids, frames, rows, stop=..., money=...)`. Return `rows, meta`; `meta` needs `order_frame` and `unit`, plus whatever the metric needs. Add it to `SCENARIOS`.
2. In `analyze.py`, reuse a metric function or add one to `KINDS` (chosen by the name prefix before `_`), add an `EXPECT` row with the Wargrid value, a tolerance (`None` = feel only) and a note, and extend `self_test` with a synthetic trace.
3. API verbs (fork `docs/EXTERNAL_CONTROL_API.md`): `move`, `stop`, `attack_move`, `attack_target`, `guard_zone`, `capture`, `garrison`, `repair`, `train_unit`, `build_structure`, `set_rally`, `special_power`, `ability`, plus `spawn` from the parity patch. Unit fields: position, `angle`, `speed` (units per frame), `lastShotFrame`, `health`. Money: `/resources?player=`.

Engine behaviour learned so far (keep scenarios honest):

- Pause is applied on the logic thread later; the harness waits for a stable frame before stepping, else every sample is one frame off.
- A shot is stamped with the frame of the update that fired it and shows in the next sample; distances are taken where it first shows.
- Idle units ignore neutral (civilian) objects and chase enemies that are visible but out of range; reach tests need an unarmed enemy target and a "did not move" check.
- Civilian targets never shoot back; enemy-owned units retaliate.
- A spawned `AmericaSupplyCenter` creates its own Chinook (one-shot spawn), as a built one does.
- Weapon-fire effects are skipped headless (they crashed); logic is unaffected because effects only use the client random stream.

## Recording results

In the milestone's verification or reference note: scenario name, Wargrid value, measured value, verdict, the Wargrid commit, the fork branch commit, and the trace directory. Label **measured (source build)**. Keep traces outside git; quote the numbers.
