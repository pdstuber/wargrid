# Zero Hour parity harness

How to measure a Zero Hour mechanic frame by frame, in any milestone. Origin, routes tried and the first results: [parity harness spike](zero-hour-parity-spike.md). Standing: it measures a **source build** of Zero Hour (native macOS fork plus a small local patch), not the shipped `Game.dat`; label results **measured (source build)**. How far that substitutes for [level 1](zero-hour-verification.md#level-1-protocol-reduced-by-user-decision-2026-11-03) is recorded there.

## When to use it

Whenever a plan or a playtest question touches a mechanic Zero Hour also has (movement, turning, weapon range and cadence, damage and time-to-kill, splash, harvesting, production timing), measure it instead of estimating. Typical uses before the parity gate: calibrate a provisional value, settle "does Zero Hour do X" during design, or explain a playtest feel complaint. Results are evidence; differences go to a decision list in the milestone's design or verification note and never change Wargrid numbers automatically (same rule as the [verification doc](zero-hour-verification.md)).

Not covered: anything that needs the retail binary (exact retail floating point, replay CRCs), rendering, sound or UI feel.

## Setup (once per machine)

1. Game data: extracted retail copy in `~/CnC/run/` ([installation](installation.md)). Other location: `ZH_PARITY_DATA=<dir containing INIZH.big>`.
2. Engine: the parity patch exists only in the local branch `wargrid-parity` of `~/projects/GeneralsGameCode-macOS` (never pushed; contents in the [spike](zero-hour-parity-spike.md#what-was-built)). On another machine, clone [dvcdsys/GeneralsGameCode-macOS](https://github.com/dvcdsys/GeneralsGameCode-macOS), then carry the branch over without publishing it: on this machine `git -C ~/projects/GeneralsGameCode-macOS bundle create wargrid-parity.bundle 8fedb1649..wargrid-parity`, on the other `git fetch <path>/wargrid-parity.bundle wargrid-parity:wargrid-parity && git switch wargrid-parity`. Other location: `ZH_PARITY_BIN=<path to generalszh_api>`.
3. Build (about 15 minutes clean, Command Line Tools are enough):
   `cmake --preset apple-arm64-release -DRTS_BUILD_OUTPUT_SUFFIX=_api && cmake --build build/apple-arm64-release --config Release --target z_generals`

The fork is GPL code with EA's additional terms. It stays outside Wargrid; the harness only talks to it over localhost HTTP and contains no EA code or data.

## Run

```sh
python3 -I tools/zh_parity/parity.py [--out DIR] [scenario-or-glob ...]   # default: all; unknown names exit 2 before any launch
python3 -I tools/zh_parity/parity.py --list 'collect_*'                   # resolved names
python3 -I tools/zh_parity/parity.py --out DIR --repeats 3 --lanes 3 'collect_truck_*'   # sweep
python3 -I tools/zh_parity/parity.py --kill DIR                           # stop only that sweep's games
python3 -I tools/zh_parity/parity.py --smoke                              # one real game, move_crusader, about 4 s (local only)
python3 -I tools/zh_parity/analyze.py [--traces DIR]                      # metrics vs Wargrid values
python3 -I tools/zh_parity/analyze.py --report md DIR... [--wargrid F.json]   # pooled decision-list table (rep dirs pooled)
python3 -I tools/zh_parity/analyze.py --json DIR...                       # one JSON line per trace
python3 -I tools/zh_parity/analyze.py --same A.tsv B.tsv                  # equal after frame/id normalising? (exit 1 if not)
python3 -m unittest discover -s tools                                     # harness tests (synthetic, no engine; also self-test)
```

Environment: `ZH_PARITY_PORT` (REST port; WS is port+1, so lanes sit 2 apart), `ZH_PARITY_MAP`, `ZH_PARITY_FPS_CAP` (default 0), `ZH_PARITY_BIN`, `ZH_PARITY_DATA`.

Traces go to `~/CnC/parity/traces/` unless `--out` is given (outside git): one `<scenario>.tsv` (first line JSON metadata with `schema`, `seed`, `side`, `fps_cap`, `fork` and `wargrid` commits; then one row per unit per logic frame; written to `.tmp` and renamed, so a file means finished) and a game log. The game always runs `-headless -noaudio`; the harness aborts if the game reports it is not headless. Never run it windowed without asking (a windowed run plays loud sound). Never `pkill` broadly while another agent runs games; use `--kill DIR`.

Speed (measured, M-series): the loop runs uncapped (`GEN_FPS_CAP=0`, the default), start-up is about 2 s, and a recorded frame costs about 5 ms instead of about 170 ms at the engine's 30 Hz cap. `move_crusader` takes 3.5 s end to end; a `collect_*` run takes about 20 s.

Sweeps (`--repeats R` or `--lanes N`): one child process per job (`rep<r>/<scenario>.tsv`), each on its own port (`ZH_PARITY_PORT + 2 * lane`) and `GEN_USER_DATA`, niced. Finished traces are skipped on rerun (resume), failures and timeouts (`--timeout`, default 900 s) retry `--retries` times (default 1), and `runs.jsonl` gets one line per attempt. An uncapped paused game spins one core, so lanes are capped at 6 (default with repeats: cpus/2, at most 6); 3 lanes and 6 lanes gave about the same throughput on 12 cores (6 `collect_truck_6` jobs: 35 s on 3 lanes, 30 s on 6).

## Scenarios

| Scenario | Mechanic | Metrics |
|---|---|---|
| `move_<unit>` | straight move from rest | start delay, cruise and peak speed, acceleration, braking |
| `turn_<unit>` | move to a point behind the unit | turn rate, turn frames, start delay |
| `range_<unit>` | `attack_target` from beyond range | first-shot distance, intervals |
| `reach_<unit>` | idle unit, bisected gap | farthest stationary firing distance (centre to centre) |
| `rof_crusader`, `burst_ranger` | firing at a structure | shot interval, burst pattern |
| `ramp_gattling_*`, `horde_redguard` | spin-up cadence, horde bonus | first intervals, last interval |
| `duel_<unit>` | mirror duel, defender fires back | time-to-kill, winner |
| `splash_crusader` | tank shell into a five-Ranger cluster | shots to kill, hits, splash damage on neighbours |
| `collect_<chinook\|truck\|worker>_<d>[_x2]`, `collect_<kind>_u<units*10>[_xN]` | a built depot `d` cells (or exact units) from a spawned `SupplyDock`, one or more collectors | credits per deposit, credits/min (pooled over repeats), cycle phases (travel, load, unload) |
| `supply_chinook` | supply centre and warehouse 400 apart | deposit size, cycle frames, cruise speed |
| `retaliate_ranger`, `retaliate_bisect`, `retaliate_return` | an attacker (tank, or a Ranger for `_return`) hits one idle Ranger; Rangers at set distances | who joins (starts moving, fires) and how far they chase; read from the trace by hand, no `analyze.py` metric |

Units: `ranger` = `AmericaInfantryRanger`, `crusader` = `AmericaTankCrusader`, `dozer` = `AmericaVehicleDozer`. Any object template from `INIZH.big` works (see `strings INIZH.big | rg '^Object '`).

## Adding a scenario

In `parity.py`, a scenario is a factory returning `run(g)` (about 10 lines), registered in `SCENARIOS` (or `REACH` for a bisected gap):

```python
def fire(attacker, target, gap, frames):
    def run(g):
        x, y = g.clear_strip(gap + 120)                       # flat strip: west end
        aid = g.spawn(attacker, x + 20, y)                    # owner omitted = API player
        tid = g.spawn(target, x + 20 + gap, y, angle=math.pi, owner=g.enemy)   # g.civilian: never shoots back
        rows = []
        g.record([aid, tid], 5, rows)                         # settle, then order
        g.command("attack_target", [aid], targetId=tid)
        g.record([aid, tid], frames, rows, stop=dead_for(tid, 10))
        return rows, {"order_frame": g.frame, "unit": aid, "target": tid}   # meta needs order_frame and unit
    return run
# SCENARIOS["range_x"] = fire("Template", "Target", 300, 400)
```

Then in `analyze.py`: pick a metric via the name prefix (`KINDS`) or add one, add an `EXPECT` row `(metric, Wargrid value, tolerance or None, note[, accepted])` (`accepted` = a decided offset: verdict `ACCEPTED`; `move_*` speeds are read from the definition files, so do not type them), and a synthetic case in `tools/test_zh_parity.py`. Unit tests never use real traces.

API verbs (fork `docs/EXTERNAL_CONTROL_API.md`; `/commands` takes an array): `move`, `stop`, `retreat`, `attack_move`, `attack_target`, `guard_zone`, `capture`, `garrison`, `ungarrison`, `repair`, `sell`, `train_unit`, `build_structure`, `set_rally`, `special_power`, `ability`, plus `spawn` from the parity patch. Unit fields: position, `angle`, `speed` (units per frame), `lastShotFrame` (absolute), `health`. Money: `/resources?player=`.

API quirks learned so far (keep scenarios honest):

- A raw `spawn` creates an unfinished structure: a spawned depot never takes deposits, so depots are built by a builder (power plant first when the faction needs one), and spawned extra collectors never self-start (use `train_unit`). The fork's `spawn` skips the map-object setup (`onBuildComplete`, pathfinding map), so a spawned `SupplyDock` may differ from a map warehouse for collector travel (unverified).
- A builder ordered in its spawn frame gets `buildObjectNow failed`: record 10 frames first.
- Depot placement: the legality check accepts spots very near a spawned dock, or rejects them (`illegal build location`/`buildObjectNow failed`); `place_depot` scans outward in 5-unit steps.
- Idle collectors ignore piles beyond the 700-unit warehouse scan; `collect()` walks the collector into range for longer layouts.
- The API player's faction and the seed are random per game (recorded in meta); spawned units of any faction work regardless. Killing Fields has no flat 1000-unit strip (narrower, sloped strip for the 30-cell rows).
- Money rides in the `health` column of the `money` rows; `lastShotFrame` is absolute (normalise with `order_frame`).
- `/control speed` does nothing for paused stepping on macOS; only `GEN_FPS_CAP` counts.

Engine behaviour learned so far:

- Pause is applied on the logic thread later; the harness waits for a stable frame before stepping, else every sample is one frame off.
- A shot is stamped with the frame of the update that fired it and shows in the next sample; distances are taken where it first shows.
- Idle units ignore neutral (civilian) objects and chase enemies that are visible but out of range; reach tests need an unarmed enemy target and a "did not move" check.
- Civilian targets never shoot back; enemy-owned units retaliate.
- A spawned `AmericaSupplyCenter` creates its own Chinook (one-shot spawn), as a built one does.
- Weapon-fire effects are skipped headless (they crashed); logic is unaffected because effects only use the client random stream.

## Recording results

In the milestone's verification or reference note: scenario name, Wargrid value, measured value, verdict, the Wargrid commit, the fork branch commit, and the trace directory. Label **measured (source build)**. Keep traces outside git; quote the numbers.
