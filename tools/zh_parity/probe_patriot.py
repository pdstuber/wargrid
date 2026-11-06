"""Patriot probe: why does AmericaPatriotBattery never fire? Run: python3 -I tools/zh_parity/probe_patriot.py [attempt ...]"""

import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import parity as P


def info(g, ids):
    us = {u["id"]: u for u in g.call("/units")}
    return {
        i: {k: us[i].get(k) for k in ("template", "health", "tags", "lastShotFrame", "status", "x", "y")}
        for i in ids
        if i in us
    }


def shots(rows, uid):
    return sorted({r[7] for r in rows if r[1] == uid and r[7]})


def attempt(name, setup, frames=400, order=None):
    g = P.Game(P.OUT / "probe_patriot.log")
    try:
        x, y = g.clear_strip(600)
        ids = setup(g, x, y)
        rows: list[tuple[str, str]] = []
        g.record(ids["watch"], 5, rows)
        print(
            name,
            "state",
            json.dumps(info(g, ids["watch"][:1]))[:400],
            "res",
            g.call(f"/resources?player={g.me}"),
            flush=True,
        )
        if order:
            order(g, ids)
        g.record(ids["watch"], frames, rows)
        s = shots(rows, ids["watch"][0])
        print(name, "shots", len(s), s[:20], flush=True)
        return rows, s
    finally:
        g.close()


def enemy_target(tpl, gap=150, owner="enemy"):
    def setup(g, x, y):
        pw = g.spawn("AmericaPowerPlant", x + 20, y + 120)
        a = g.spawn("AmericaPatriotBattery", x + 20, y)
        t = g.spawn(tpl, x + 20 + gap, y, angle=math.pi, owner=getattr(g, owner))
        return {"watch": [a, t], "power": pw}

    return setup


def nopower(g, x, y):
    a = g.spawn("AmericaPatriotBattery", x + 20, y)
    t = g.spawn("AmericaVehicleDozer", x + 170, y, angle=math.pi, owner=g.enemy)
    return {"watch": [a, t]}


def two(g, x, y):
    g.spawn("AmericaPowerPlant", x + 20, y + 120)
    a = g.spawn("AmericaPatriotBattery", x + 20, y)
    b = g.spawn("AmericaPatriotBattery", x + 20, y + 60)
    t = g.spawn("AmericaVehicleDozer", x + 170, y, angle=math.pi, owner=g.enemy)
    return {"watch": [a, t, b]}


def cmd_attack(g, ids):
    g.command("attack_target", [ids["watch"][0]], targetId=ids["watch"][1])


ATT = {
    "a1_power_state": lambda: attempt("a1", enemy_target("AmericaVehicleDozer"), 5, None),
    "a2_auto_dozer": lambda: attempt("a2", enemy_target("AmericaVehicleDozer"), 400),
    "a3_auto_crusader": lambda: attempt("a3", enemy_target("AmericaTankCrusader"), 400),
    "a3_auto_ranger": lambda: attempt("a3r", enemy_target("AmericaInfantryRanger"), 400),
    "a3_auto_cmd": lambda: attempt("a3c", enemy_target("GLACommandCenter", 200), 400),
    "a3_cmd_attack": lambda: attempt("a3o", enemy_target("AmericaVehicleDozer"), 400, cmd_attack),
    "a0_no_power": lambda: attempt("a0", nopower, 200),
    "a5_two": lambda: attempt("a5", two, 400),
}

if __name__ == "__main__":
    for n in sys.argv[1:] or ATT:
        ATT[n]()
