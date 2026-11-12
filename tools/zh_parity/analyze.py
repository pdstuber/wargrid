"""Turn Zero Hour parity traces into metrics and compare them with Wargrid's values.

Usage: python3 -I tools/zh_parity/analyze.py [--traces DIR]
       python3 -I tools/zh_parity/analyze.py --json DIR...        one JSON line per trace (DIR/*.tsv, DIR/rep*/*.tsv)
       python3 -I tools/zh_parity/analyze.py --report md DIR... [--wargrid FILE.json]   pooled decision-list table
       python3 -I tools/zh_parity/analyze.py --same A.tsv B.tsv   equal after normalising frames and ids?
       python3 -I tools/zh_parity/analyze.py --self-test
Units: world units (1 Wargrid cell = 25), logic frames at 30 Hz. Expected values are Wargrid's
(they equal the INI per tools/check_reference.py unless noted); "feel" rows have no pass/fail.
"""

import argparse
import itertools
import json
import math
import re
import statistics
from pathlib import Path
from typing import Any

FPS = 30
OPENING_TIMES = (60, 120, 180, 300, 600)
OPENING_MOVE_WINDOW = 150  # frames; a unit unloading stood still for less than this
TRACES = Path.home() / "CnC/parity/traces"

# name, top speed, tolerance, turn rate (deg/s)
CHINA_MOVERS = [
    ("redguard", 25, 3, 500),
    ("tankhunter", 20, 2, 500),
    ("battlemaster", 25, 3, 180),
    ("gattlingtank", 40, 4, 180),
    ("cndozer", 30, 3, 90),
    ("truck", 40, 4, 90),
]

FRC_MOVERS = [
    ("worker", 25, 3, 500),
    ("rebel", 20, 2, 500),
    ("tunneldefender", 20, 2, 500),
    ("technical", 90, 9, 180),
    ("scorpion", 40, 4, 180),
]

# scenario -> [(metric, Wargrid value, tolerance or None, note)]
EXPECT: dict[str, Any] = {
    "move_ranger": [("top_speed", 20, 2, "0.8 cells/s"), ("accel", 100, None, "Wargrid instant; INI 100")],
    "move_crusader": [("top_speed", 30, 3, "1.2 cells/s"), ("accel", 1000, None, "Wargrid instant; INI 1000")],
    "move_dozer": [("top_speed", 30, 3, "1.2 cells/s"), ("accel", 30, None, "Wargrid instant; INI 30")],
    "move_rocket": [("top_speed", 20, 2, "0.8 cells/s"), ("accel", 100, None, "Wargrid instant; INI value unchecked")],
    "move_scout": [("top_speed", 75, 7, "3.0 cells/s"), ("accel", 1000, None, "Wargrid instant")],
    "turn_rocket": [("turn_rate", 500, None, "Wargrid instant; 16.7 deg/tick")],
    "turn_scout": [("turn_rate", 180, None, "Wargrid instant; 6 deg/tick")],
    "range_rocket": [("first_shot_distance", 175, 10, "7 cells centre to centre")],
    "range_scout": [("first_shot_distance", 150, 10, "6 cells centre to centre")],
    "range_battery": [("first_shot_distance", 225, 10, "9 cells centre to centre")],
    "reach_rocket": [("farthest_fire", 175, 10, "7 cells centre to centre")],
    "reach_scout": [("farthest_fire", 150, 10, "6 cells centre to centre")],
    "reach_battery": [("farthest_fire", 225, 10, "9 cells centre to centre")],
    "turn_ranger": [("turn_rate", 500, None, "Wargrid instant; INI 500")],
    "turn_crusader": [("turn_rate", 180, None, "Wargrid instant; INI 180")],
    "turn_dozer": [("turn_rate", 90, None, "Wargrid instant; INI 90")],
    "range_crusader": [("first_shot_distance", 150, 10, "6 cells centre to centre; fires on the move")],
    "range_ranger": [("first_shot_distance", 100, 10, "4 cells; approach-and-stop distance")],
    "reach_ranger": [("farthest_fire", 100, 10, "4 cells centre to centre; ZH stationary maximum")],
    "reach_crusader": [("farthest_fire", 150, 10, "6 cells centre to centre; ZH stationary maximum")],
    "rof_crusader": [("shot_interval", 60, 1, "DelayBetweenShots 2000 ms")],
    "burst_ranger": [("burst_pattern", "3,3,21", 1, "delay 3, clip 3, reload 21")],
    "rof_rocket": [("shot_interval", 30, 1, "DelayBetweenShots 1000 ms")],
    "rof_scout": [("shot_interval", 6, 1, "DelayBetweenShots 200 ms")],
    "burst_battery": [("burst_pattern", "8,8,8,60", 1, "delay 8, clip 4, reload 60")],
    "duel_ranger": [("ttk_frames", 303, None, "36 hits of 5 HP at 3/3/21")],
    "duel_crusader": [("ttk_frames", 420, None, "8 hits of 60 HP every 60 ticks")],
    **{
        f"move_{name}": [("top_speed", speed, tol, f"{speed / 25:.1f} cells/s")] for name, speed, tol, _ in CHINA_MOVERS
    },
    **{f"turn_{name}": [("turn_rate", rate, None, f"Wargrid {rate} deg/s")] for name, _, _, rate in CHINA_MOVERS},
    **{f"move_{name}": [("top_speed", speed, tol, f"{speed / 25:.1f} cells/s")] for name, speed, tol, _ in FRC_MOVERS},
    **{f"turn_{name}": [("turn_rate", rate, None, f"Wargrid {rate} deg/s")] for name, _, _, rate in FRC_MOVERS},
    "range_rebel": [("first_shot_distance", 100, 10, "4 cells")],
    "range_tunneldefender": [("first_shot_distance", 175, 10, "7 cells")],
    "range_technical": [("first_shot_distance", 150, 10, "6 cells")],
    "range_scorpion": [("first_shot_distance", 150, 10, "6 cells")],
    "reach_rebel": [("farthest_fire", 100, 10, "4 cells")],
    "reach_tunneldefender": [("farthest_fire", 175, 10, "7 cells")],
    "reach_technical": [("farthest_fire", 150, 10, "6 cells")],
    "reach_scorpion": [("farthest_fire", 150, 10, "6 cells")],
    "reach_tunnel": [("farthest_fire", 175, 10, "7 cells, no power needed")],
    "burst_rebel": [("burst_pattern", "3,3,21", 1, "as the Ranger")],
    "rof_technical": [("shot_interval", 6, 1, "delay 6")],
    "rof_scorpion": [("shot_interval", 30, 1, "delay 30")],
    "rof_tunnel": [("shot_interval", 8, 1, "delay 8")],
    "range_redguard": [("first_shot_distance", 100, 10, "4 cells")],
    "range_tankhunter": [("first_shot_distance", 175, 10, "7 cells")],
    "range_battlemaster": [("first_shot_distance", 150, 10, "6 cells")],
    "range_gattlingtank": [("first_shot_distance", 150, 10, "6 cells")],
    "reach_redguard": [("farthest_fire", 100, 10, "4 cells")],
    "reach_tankhunter": [("farthest_fire", 175, 10, "7 cells")],
    "reach_battlemaster": [("farthest_fire", 150, 10, "6 cells")],
    "reach_gattlingtank": [("farthest_fire", 150, 10, "6 cells")],
    "reach_gattlingcannon": [("farthest_fire", 225, 10, "9 cells")],
    "rof_redguard": [("shot_interval", 30, 1, "delay 30")],
    "rof_battlemaster": [("shot_interval", 60, 1, "delay 60")],
    "ramp_gattling_tank": [("first_intervals", "12,12,6,6,6,6,4", 1, "delay 12, ramp x2 after 2, x3 after 6")],
    "ramp_gattling_cannon": [("first_intervals", "8,4,4,4,4,2,2", 1, "delay 8, ramp after 1 and 5")],
    "horde_redguard": [("last_interval", 20, 1, "five together, horde rate")],
    "splash_crusader": [("shots_to_kill", 30, None, "direct 6 HP hits, no splash or scatter")],
    "supply_chinook": [("deposit", 600, None, "8 boxes x 75"), ("cruise_speed", 150, None, "6 cells/s, provisional")],
}


DEFS = Path(__file__).resolve().parents[2] / "game/scripts/simulation/definitions"
# move_<suffix> scenario -> Wargrid definition id; speeds are cells/s there, 25 world units per cell
WG_KIND = {
    "ranger": "usa_rifle_infantry", "crusader": "usa_tank", "dozer": "usa_builder",
    "rocket": "usa_rocket_infantry", "scout": "usa_light_vehicle",
    "redguard": "china_rifle_infantry", "tankhunter": "china_rocket_infantry",
    "battlemaster": "china_light_vehicle", "gattlingtank": "china_tank",
    "cndozer": "china_builder", "truck": "china_collector",
    "worker": "frc_builder", "rebel": "frc_rifle_infantry", "tunneldefender": "frc_rocket_infantry",
    "technical": "frc_light_vehicle", "scorpion": "frc_tank",
}  # fmt: skip


def definition_speeds() -> dict[str, float]:
    """move_<unit> -> Wargrid top speed in world units per second, read from the definition files."""
    speed = {}
    for f in DEFS.glob("*.gd"):
        for m in re.finditer(r'^\t"(\w+)": \{[^\n]*?"speed": ([0-9.]+)', f.read_text(), re.M):
            speed[m[1]] = float(m[2]) * 25
    return {f"move_{k}": round(speed[v], 3) for k, v in WG_KIND.items() if v in speed}


def apply_definitions() -> None:
    for name, v in definition_speeds().items():
        _, _, tol, _ = EXPECT[name][0]
        EXPECT[name][0] = ("top_speed", v, tol, f"{v / 25:.1f} cells/s (definitions)")


apply_definitions()


def load(path):
    lines = path.read_text().splitlines()
    meta = json.loads(lines[0][2:])
    head = lines[1].split("\t")
    return meta, [dict(zip(head, line.split("\t"), strict=False)) for line in lines[2:]]


def series(rows, uid, key):
    return [(int(r["frame"]), float(r[key])) for r in rows if r["id"] == str(uid) and r[key] != ""]


def death_frame(rows, uid):
    # Health 0, not removal: dead infantry stay on the map for about 240 frames.
    return next((int(r["frame"]) for r in rows if r["id"] == str(uid) and float(r["health"] or 0) <= 0), None)


def movement(meta, rows):
    sp = series(rows, meta["unit"], "speed")
    start = next(f for f, v in sp if v > 0)
    peak = max(v for _, v in sp)
    top = statistics.median(v for _, v in sp if v > 0)  # cruise speed; peak can be a one-frame lurch
    rising = [b - a for (_, a), (_, b) in itertools.pairwise(sp) if b - a > 1e-3]
    falling = [a - b for (_, a), (_, b) in itertools.pairwise(sp) if a - b > 1e-3]
    return {
        "start_delay_frames": start - meta["order_frame"],
        "top_speed": round(top * FPS, 3),
        "peak_speed": round(peak * FPS, 3),
        "accel": round(statistics.median(rising) * FPS * FPS, 1),
        "frames_to_top": next(f for f, v in sp if v >= 0.99 * top) - start,
        "braking": round(statistics.median(falling) * FPS * FPS, 1) if falling else None,
    }


def turning(meta, rows):
    ang = [v for _, v in series(rows, meta["unit"], "angle")]
    deltas = [math.remainder(b - a, 2 * math.pi) for a, b in itertools.pairwise(ang)]
    turning_deltas = [abs(d) for d in deltas if abs(d) > 1e-3]
    return {
        "turn_rate": round(math.degrees(max(turning_deltas)) * FPS, 1) if turning_deltas else 0.0,
        "turn_frames": len(turning_deltas),
        "start_delay_frames": next(f for f, v in series(rows, meta["unit"], "speed") if v > 0) - meta["order_frame"],
    }


def shot_rows(rows, uid):
    """(shot frame, row frame where it first shows) per shot; a shot is stamped one frame before it appears."""
    out, last = [], 0
    for f, v in series(rows, uid, "lastShotFrame"):
        if v and v != last:
            out.append((int(v), f))
        last = v
    return out


def distance_at(rows, frame, a, b):
    pos = {r["id"]: r for r in rows if int(r["frame"]) == frame and r["x"] != ""}
    if str(a) in pos and str(b) in pos:
        pa, pb = pos[str(a)], pos[str(b)]
        return round(math.hypot(float(pa["x"]) - float(pb["x"]), float(pa["y"]) - float(pb["y"])), 2)
    return None


def shots(meta, rows):
    fired = shot_rows(rows, meta["unit"])
    frames = [s for s, _ in fired]
    intervals = [b - a for a, b in itertools.pairwise(frames)]
    out = {"shots": len(frames), "intervals": intervals}
    if fired:
        out["first_shot_distance"] = distance_at(rows, fired[0][1], meta["unit"], meta["target"])
        out["first_shot_delay_frames"] = frames[0] - meta["order_frame"]
    if intervals:
        out["shot_interval"] = statistics.median(intervals)
        out["burst_pattern"] = ",".join(map(str, intervals[:3]))
        out["first_intervals"] = ",".join(map(str, intervals[:7]))
        out["last_interval"] = intervals[-1]
    return out


def duel(meta, rows):
    """Mirror duel: time from the killer's first shot to the victim reaching 0 health (first death if both die)."""
    out = shots(meta, rows)
    deaths = {k: death_frame(rows, meta[k]) for k in ("unit", "target")}
    dead = sorted((f, k) for k, f in deaths.items() if f is not None)
    if not dead:
        return {**out, "winner": "none", "ttk_frames": None}
    victim_frame, victim = dead[0]
    killer = "target" if victim == "unit" else "unit"
    killer_shots = [s for s, _ in shot_rows(rows, meta[killer]) if s < victim_frame]
    out["winner"] = "both died" if len(dead) == 2 else killer
    out["ttk_frames"] = victim_frame - killer_shots[0] if killer_shots else None
    out["killer_shots"] = len(killer_shots)
    return out


def damage_events(rows, uid, until):
    hp = [(f, v) for f, v in series(rows, uid, "health") if f <= until]
    return [a - b for (_, a), (_, b) in itertools.pairwise(hp) if a - b > 1e-6]


def splashing(meta, rows):
    died = death_frame(rows, meta["target"])
    end = died or int(rows[-1]["frame"])
    shots_until = [
        s for s, _ in shot_rows(rows, meta["unit"]) if s < end
    ]  # a shot stamped at the death frame shows after it
    hits = damage_events(rows, meta["target"], end)
    splash = [d for n in meta["neighbours"] for d in damage_events(rows, n, end)]
    return {
        "shots_to_kill": len(shots_until) if died else None,
        "target_hits": len(hits),
        "target_damage_per_hit": sorted(set(round(d, 2) for d in hits)),
        "splash_events": len(splash),
        "splash_damage": round(sum(splash), 2),
        "frames_to_kill": end - shots_until[0] if died and shots_until else None,
    }


def supplying(meta, rows):
    cash = [(int(r["frame"]), float(r["health"])) for r in rows if r["id"] == "money"]
    deposits = [(f2, b - a) for (_, a), (f2, b) in itertools.pairwise(cash) if b > a]
    gaps = [b - a for (a, _), (b, _) in itertools.pairwise(deposits)]
    sp = [v for _, v in series(rows, meta["unit"], "speed") if v > 0]
    return {
        "deposits": len(deposits),
        "deposit": statistics.median(d for _, d in deposits) if deposits else None,
        "first_deposit_frame": deposits[0][0] - meta["order_frame"] if deposits else None,
        "cycle_frames": statistics.median(gaps) if gaps else None,
        "cruise_speed": round(statistics.median(sp) * FPS, 2) if sp else None,
        "peak_speed": round(max(sp) * FPS, 2) if sp else None,
    }


def collecting(meta, rows):
    cash = [(int(r["frame"]), float(r["health"])) for r in rows if r["id"] == "money"]
    deps = [(f2, b - a) for (_, a), (f2, b) in itertools.pairwise(cash) if b > a]
    out: dict[str, Any] = {
        "deposits": len(deps),
        "collectors": meta["collectors"],
        "dist_units": round(meta["dist"], 1),
    }
    if len(deps) < 3:
        return out
    span = deps[-1][0] - deps[0][0]
    out["credits_per_deposit"] = statistics.median(d for _, d in deps)
    out["credits_per_min"] = round(sum(d for _, d in deps[1:]) / span * FPS * 60, 1)
    if meta["collectors"] == 1:
        out.update(phases(meta, rows, deps))
    return out


def phases(meta, rows, deps):
    """Per-cycle frames split into travel (moving), load (standing nearer the pile) and unload (standing nearer the depot)."""
    pile, depot = meta["pile"], meta["depot"]
    pos = {
        int(r["frame"]): (float(r["x"]), float(r["y"]), float(r["speed"]))
        for r in rows
        if r["id"] == str(meta["unit"]) and r["x"] != ""
    }
    last = None
    for f in range(min(pos), max(pos) + 1):  # batched traces sample every n frames; hold the last sample
        last = pos.get(f, last)
        pos[f] = last  # type: ignore[assignment]
    cycles = []
    for (f0, _), (f1, _) in itertools.pairwise(deps):
        travel = load = unload = 0
        for f in range(f0 + 1, f1 + 1):
            x, y, v = pos[f]
            if v > 0:
                travel += 1
            elif math.dist((x, y), pile) < math.dist((x, y), depot):
                load += 1
            else:
                unload += 1
        cycles.append((f1 - f0, travel, load, unload))
    med = [statistics.median(c[i] for c in cycles) for i in range(4)]
    return dict(zip(("cycle_frames", "travel_frames", "load_frames", "unload_frames"), med, strict=True))


def opening_deposits(meta, rows):
    """[(frames after the order, collector id, credits)]: each positive money step, credited to the collector nearest the depot."""
    order, depot = meta["order_frame"], meta["depot"]
    cash = [(int(r["frame"]), float(r["health"])) for r in rows if r["id"] == "money" and int(r["frame"]) >= order]
    at = {(int(r["frame"]), r["id"]): (float(r["x"]), float(r["y"])) for r in rows if r["x"] != ""}
    moved = {(int(r["frame"]), r["id"]) for r in rows if r["x"] != "" and float(r["speed"]) > 0}
    out = []
    for (_, a), (f, b) in itertools.pairwise(cash):
        if b > a:
            # a unit that never moved cannot have delivered; parked builders stand near the depot
            live = [
                c for c in meta["collector_ids"] if any((f - d, str(c)) in moved for d in range(OPENING_MOVE_WINDOW))
            ]
            near = min(live or meta["collector_ids"], key=lambda c: math.dist(at.get((f, str(c)), (1e9, 1e9)), depot))
            out.append((f - order, near, b - a))
    return out


def opening_curve(meta, rows, spend):
    """Gross and net credits at fixed seconds after the depot order, steady credits/min, break-even, depositors, pile empty."""
    deps = opening_deposits(meta, rows)
    last_frame = max(int(r["frame"]) for r in rows) - meta["order_frame"]
    dock = str(meta["dock"])
    gone = next(
        (int(r["frame"]) - meta["order_frame"] for r in rows if r["id"] == dock and r["template"] == "dead"), None
    )
    gross = {t: sum(c for f, _, c in deps if f <= t * FPS) for t in OPENING_TIMES}
    first: dict[int, int] = {}
    for f, who, _ in deps:
        first.setdefault(who, f)
    end = min(last_frame, gone if gone is not None else last_frame, meta.get("seconds", 600) * FPS)
    start = max(first.values(), default=None)
    steady = None
    if start is not None and end > start:
        steady = round(sum(c for f, _, c in deps if start < f <= end) / ((end - start) / FPS / 60), 1)
    total, break_even = 0, None
    for f, _, c in deps:
        total += c
        if total >= spend:
            break_even = round(f / FPS, 1)
            break
    return {
        "gross": gross,
        "net": {t: g - spend for t, g in gross.items()},
        "steady_per_min": steady,
        "break_even_s": break_even,
        "depositors": len(first),
        "pile_empty_s": None if gone is None else round(gone / FPS, 1),
    }


def opening(meta, rows):
    """opening_curve flattened to scalar keys so pooled_metrics can pool them."""
    c = opening_curve(meta, rows, meta["spend"])
    flat = {f"{k}_{t}": v for k in ("gross", "net") for t, v in c[k].items()}
    return flat | {k: c[k] for k in ("steady_per_min", "break_even_s", "depositors", "pile_empty_s")}


def reaching(meta, rows):
    return {
        "farthest_fire": meta["farthest_fire"],
        "probes": [(int(r["gap"]), int(r["fired"]), int(r["moved"])) for r in rows],
    }


KINDS = {
    "move": movement,
    "turn": turning,
    "duel": duel,
    "splash": splashing,
    "supply": supplying,
    "reach": reaching,
    "collect": collecting,
    "open": opening,
}


def metrics(name, meta, rows) -> dict[str, Any]:
    return KINDS.get(name.split("_")[0], shots)(meta, rows)


def verdict(value, expected, tol, accepted=None):
    if tol is None or value is None:
        return "feel"
    if accepted is not None and verdict(value, expected, tol) == "FAIL" and verdict(value, accepted, tol) == "PASS":
        return "ACCEPTED"  # a decided offset, e.g. a known geometry difference
    if isinstance(expected, str):
        got = [int(x) for x in str(value).split(",") if x]
        want = [int(x) for x in expected.split(",")]
        return (
            "PASS"
            if len(got) == len(want) and all(abs(g - w) <= tol for g, w in zip(got, want, strict=True))
            else "FAIL"
        )
    return "PASS" if abs(value - expected) <= tol else "FAIL"


def report(traces):
    report_collect(traces)
    print("scenario\tmetric\tmeasured\twargrid\tverdict\tnote\tother")
    for name, checks in EXPECT.items():
        path = traces / f"{name}.tsv"
        if not path.exists():
            print(f"{name}\t-\tMISSING")
            continue
        m = metrics(name, *load(path))
        for key, exp, tol, note, *acc in checks:
            other = {k: v for k, v in m.items() if k != key and k != "intervals"}
            v = verdict(m.get(key), exp, tol, *acc)
            print(f"{name}\t{key}\t{m.get(key)}\t{exp}\t{v}\t{note}\t{other}")


def credit_totals(rows):
    """(credits after the first deposit, frames first to last deposit), or None with fewer than 3 deposits."""
    cash = [(int(r["frame"]), float(r["health"])) for r in rows if r["id"] == "money"]
    deps = [(f2, b - a) for (_, a), (f2, b) in itertools.pairwise(cash) if b > a]
    if len(deps) < 3:
        return None
    return sum(d for _, d in deps[1:]), deps[-1][0] - deps[0][0]


def pool(runs):
    """Pooled credits/min over runs (all credits after each first deposit / all frames first to last) and run spread."""
    totals = [t for _meta, rows in runs if (t := credit_totals(rows))]
    if not totals:
        return None
    rates = [c / f * FPS * 60 for c, f in totals]
    pooled = sum(c for c, _ in totals) / sum(f for _, f in totals) * FPS * 60
    return {"runs": len(rates), "pooled": round(pooled, 1), "spread": round((max(rates) - min(rates)) / pooled, 3)}


def summarize(values):
    med = statistics.median(values)
    spread = (max(values) - min(values)) / abs(med) if med else 0.0
    return {"n": len(values), "median": med, "min": min(values), "max": max(values), "spread": round(spread, 4)}


def find_traces(dirs):
    """(scenario, rep, path) for DIR/*.tsv (rep '-') and DIR/rep*/*.tsv."""
    return [
        (p.stem, p.parent.name if p.parent.name.startswith("rep") else "-", p)
        for d in dirs
        for p in sorted([*d.glob("*.tsv"), *d.glob("rep*/*.tsv")])
    ]


def runs_of(name, dirs):
    return [load(p) for s, _, p in find_traces(dirs) if s == name]


def pooled_metrics(name, runs):
    """Per metric across runs: numbers get n/median/min/max/spread, strings the most common value and distinct count."""
    per_run = [metrics(name, meta, rows) for meta, rows in runs]
    out: dict[str, Any] = {}
    for key in per_run[0] if per_run else []:
        vals = [m[key] for m in per_run if m.get(key) is not None]
        if vals and all(isinstance(v, int | float) and not isinstance(v, bool) for v in vals):
            out[key] = summarize(vals)
        elif vals and all(isinstance(v, str) for v in vals):
            out[key] = {"n": len(vals), "value": statistics.mode(vals), "distinct": len(set(vals))}
    if (po := pool(runs)) and name.startswith("collect"):
        out["credits_per_min"] = {**out.get("credits_per_min", {}), "n": po["runs"], "pooled": po["pooled"]}
        out["credits_per_min"]["median"] = po["pooled"]
        out["credits_per_min"]["spread"] = po["spread"]
    return out


def json_lines(dirs):
    for name, rep, path in find_traces(dirs):
        meta, rows = load(path)
        yield json.dumps(
            {
                "schema": 1,
                "scenario": name,
                "rep": rep,
                "path": str(path),
                "meta": meta,
                "metrics": metrics(name, meta, rows),
            }
        )


def fmt(v):
    return f"{v:g}" if isinstance(v, int | float) else str(v)


def md_report(dirs, expect=None, wargrid=None):
    """Markdown decision-list table: one row per EXPECT metric with a trace, plus every collect_* credits/min."""
    expect = EXPECT if expect is None else expect
    wargrid = wargrid or {}
    names = sorted({s for s, _, _ in find_traces(dirs)})
    head = ["scenario", "metric", "measured (source build)", "runs", "spread", "Wargrid", "delta", "verdict", "note"]
    lines = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    for name in names:
        pm = pooled_metrics(name, runs_of(name, dirs))
        checks = list(expect.get(name, []))
        if name.startswith("collect") and "credits_per_min" in pm:
            checks.append(
                ("credits_per_min", wargrid.get(name, {}).get("credits_per_min"), 0.05, "tolerance is relative")
            )
        for key, exp, tol, note, *acc in checks:
            s = pm.get(key)
            if s is None:
                continue
            got = s.get("median", s.get("value"))
            numeric = isinstance(got, int | float) and isinstance(exp, int | float)
            if key == "credits_per_min":
                v = "-" if exp is None else ("PASS" if abs(got / exp - 1) <= tol else "FAIL")
            else:
                v = verdict(got, exp, tol, *acc)
            delta = fmt(round(got - exp, 3)) if numeric else "-"
            if key == "credits_per_min" and numeric:
                delta = f"{(exp / got - 1) * 100:+.0f} %"
            spread = f"{s['spread'] * 100:.1f}%" if "spread" in s else f"{s['distinct']} distinct"
            lines.append(
                f"| {name} | {key} | {fmt(got)} | {s['n']} | {spread} | {fmt(exp) if exp is not None else '-'} | {delta} | {v} | {note} |"
            )
    return "\n".join(lines)


def normalised(path):
    meta, rows = load(path)
    base = int(meta.get("order_frame", 0))
    ids: dict[str, int] = {}
    out = []
    for r in rows:
        uid = r["id"] if r["id"] == "money" else ids.setdefault(r["id"], len(ids))
        shot = int(r["lastShotFrame"]) - base if r.get("lastShotFrame") not in ("", "0", None) else 0
        out.append(
            (int(r["frame"]) - base, uid, *[r[k] for k in ("template", "x", "y", "angle", "speed")], shot, r["health"])
        )
    return out


def same(a, b):
    """None when the traces are equal relative to their order frame (ids by first appearance), else the first difference."""
    ra, rb = normalised(a), normalised(b)
    for i, (x, y) in enumerate(itertools.zip_longest(ra, rb)):
        if x != y:
            return f"row {i}: {x} != {y}"
    return None


def report_collect(traces):
    for path in sorted(traces.glob("collect_*.tsv")):
        meta, rows = load(path)
        print(path.stem, json.dumps(collecting(meta, rows)))


def self_test():
    def hp_rows(uid, healths, x="150"):
        return [
            {
                "frame": str(i),
                "id": str(uid),
                "template": "dead" if hp is None else "b",
                "x": "" if hp is None else x,
                "y": "" if hp is None else "0",
                "angle": "0",
                "speed": "0",
                "lastShotFrame": "0",
                "health": str(hp or 0),
            }
            for i, hp in enumerate(healths)
        ]

    def trace(speeds, angles=None, shots_at=(), health=None, unit_health=None):
        rows, last = [], 0
        for i, v in enumerate(speeds):
            last = i - 1 if (i - 1) in shots_at else last  # engine stamps the shot one frame before it shows
            rows.append(
                {
                    "frame": str(i),
                    "id": "1",
                    "template": "a",
                    "x": str(i),
                    "y": "0",
                    "angle": str(angles[i] if angles else 0.0),
                    "speed": str(v),
                    "lastShotFrame": str(last),
                    "health": str(unit_health[i] if unit_health else 10),
                }
            )
        return rows + hp_rows(2, health or [10] * len(speeds))

    jitter = [0.3, 0.30001, 0.29999] * 3  # plateau float noise must not count as acceleration or braking
    m = movement({"unit": 1, "order_frame": 2}, trace([0, 0, 0, 0, 0.1, 0.2, *jitter, 0.2, 0.1, 0]))
    assert m["start_delay_frames"] == 2 and m["top_speed"] == 9.0 and m["accel"] == 90.0, m
    assert m["frames_to_top"] == 2 and m["braking"] == 90.0, m
    lurch = movement({"unit": 1, "order_frame": 0}, trace([0, 0.6] + [0.3] * 8 + [0]))
    assert lurch["top_speed"] == 9.0 and lurch["peak_speed"] == 18.0, lurch
    step = math.radians(6)
    t = turning(
        {"unit": 1, "order_frame": 0}, trace([0, 0.1, 0.1, 0.1], [3.1, 3.1 + step, -3.1 + step, -3.1 + 2 * step])
    )
    assert abs(t["turn_rate"] - 180.0) < 1e-6 and t["turn_frames"] == 3 and t["start_delay_frames"] == 1, t
    s = shots({"unit": 1, "target": 2, "order_frame": 0}, trace([0] * 40, shots_at=(10, 13, 16, 37)))
    assert s["burst_pattern"] == "3,3,21" and s["shots"] == 4, s
    assert s["first_shot_distance"] == 139.0, s  # x at the row where the shot first shows (frame 11)
    hp = [10, 10, 10, 10, 10, 10, 6, 6, 2, 0, None]  # health 0 at frame 9 counts as death, removal comes later
    d = duel({"unit": 1, "target": 2, "order_frame": 0}, trace([0] * 11, shots_at=(5, 7, 8, 9), health=hp))
    assert d["winner"] == "unit" and d["ttk_frames"] == 4 and d["killer_shots"] == 3, (
        d
    )  # shot stamped at death not counted
    late = [10] * 10 + [0]  # attacker dies later from an outstanding projectile
    both = duel(
        {"unit": 1, "target": 2, "order_frame": 0}, trace([0] * 11, shots_at=(5, 7, 8), health=hp, unit_health=late)
    )
    assert both["winner"] == "both died" and both["ttk_frames"] == 4, both
    noshot = duel({"unit": 1, "target": 2, "order_frame": 0}, trace([0] * 11, health=hp))
    assert noshot["ttk_frames"] is None and noshot["killer_shots"] == 0, noshot
    neighbour = hp_rows(3, [10] * 7 + [4] * 4, x="165")
    sp = splashing(
        {"unit": 1, "target": 2, "neighbours": [3], "order_frame": 0},
        trace([0] * 11, shots_at=(5, 7, 8, 9), health=hp) + neighbour,
    )
    assert sp["shots_to_kill"] == 3 and sp["target_hits"] == 3 and sp["target_damage_per_hit"] == [2.0, 4.0], sp
    assert sp["splash_events"] == 1 and sp["splash_damage"] == 6.0 and sp["frames_to_kill"] == 4, sp
    alive = splashing({"unit": 1, "target": 2, "neighbours": [], "order_frame": 0}, trace([0] * 6, shots_at=(1,)))
    assert alive["shots_to_kill"] is None and alive["frames_to_kill"] is None, alive
    cash = [
        {
            "frame": str(f),
            "id": "money",
            "template": "money",
            "x": "",
            "y": "",
            "angle": "",
            "speed": "",
            "lastShotFrame": "",
            "health": str(v),
        }
        for f, v in enumerate([0, 0, 600, 600, 600, 1200])
    ]
    su = supplying({"unit": 1, "order_frame": 0}, trace([0, 5, 5, 0, 0, 0]) + cash)
    assert su["deposits"] == 2 and su["deposit"] == 600 and su["cycle_frames"] == 3 and su["cruise_speed"] == 150, su
    assert verdict("3,4,20", "3,3,21", 1) == "PASS" and verdict("3,3", "3,3,21", 1) == "FAIL"
    assert verdict(152.0, 150, 10) == "PASS" and verdict(161, 150, 10) == "FAIL"

    def mrow(f, cash, uid="money", x="", v=""):
        return {
            "frame": str(f),
            "id": str(uid),
            "template": "t",
            "x": x,
            "y": "0" if x else "",
            "speed": v,
            "health": str(cash),
        }

    # one collector: 2 frames moving, 1 at the pile (x=10), 2 moving, 1 at the depot (x=0), deposit 75 on frames 6 and 12
    path = [(10, 0), (10, 0), (5, 1), (0, 1), (0, 0), (0, 0)] * 3
    rs = []
    for f, (px, v) in enumerate(path, 1):
        rs += [mrow(f, 75 * (f // 6), 7, str(px), str(v)), mrow(f, 75 * (f // 6))]
    co = collecting({"unit": 7, "collectors": 1, "dist": 10, "pile": [10, 0], "depot": [0, 0]}, rs)
    assert co["credits_per_deposit"] == 75 and co["cycle_frames"] == 6 and co["travel_frames"] == 2, co
    assert co["load_frames"] == 2 and co["unload_frames"] == 2, co
    two: list[Any] = [({}, rs), ({}, rs)]
    po = pool(two)
    assert po and po["runs"] == 2 and po["spread"] == 0 and po["pooled"] == round(75 / 6 * 1800, 1), po
    print("self-test OK")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--traces", type=Path, default=TRACES)
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--json", nargs="+", type=Path, metavar="DIR")
    ap.add_argument("--report", choices=["md"], help="pooled markdown table over the DIRs given as arguments")
    ap.add_argument(
        "--wargrid", type=Path, help="JSON {scenario: {metric: value}} for Wargrid column of collect_* rows"
    )
    ap.add_argument("--same", nargs=2, type=Path, metavar="TSV")
    ap.add_argument("dirs", nargs="*", type=Path)
    a = ap.parse_args()
    if a.json:
        print("\n".join(json_lines(a.json)))
    elif a.report:
        print(md_report(a.dirs, wargrid=json.loads(a.wargrid.read_text()) if a.wargrid else None))
    elif a.same:
        diff = same(*a.same)
        print("same" if diff is None else diff)
        raise SystemExit(0 if diff is None else 1)
    else:
        self_test() if a.self_test else report(a.traces)
