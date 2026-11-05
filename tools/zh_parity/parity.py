"""Run Zero Hour parity scenarios headless via the macOS fork's external-control API.

Each scenario launches a fresh headless, silent game, spawns units on a flat clear strip,
issues one order and records every logic frame to <out>/<scenario>.tsv. Reach scenarios
bisect the farthest stationary firing distance over several games instead.
Setup and how to add a scenario: docs/reference/zero-hour-parity-harness.md.
Usage: python3 -I tools/zh_parity/parity.py [--out DIR] [scenario ...]   (default: all)
"""
import argparse
import base64
import json
import math
import os
import subprocess
import time
import urllib.request
from pathlib import Path

HOME = Path.home()
BIN = Path(os.environ.get("ZH_PARITY_BIN", HOME / "projects/GeneralsGameCode-macOS/build/apple-arm64-release/GeneralsMD/Release/generalszh_api"))
DATA = Path(os.environ.get("ZH_PARITY_DATA", HOME / "CnC/run/Command & Conquer Generals - Zero Hour"))
OUT = HOME / "CnC/parity/traces"
API = "http://127.0.0.1:3459"
MAP = r"maps\Killing Fields\Killing Fields.map"
FIELDS = ("frame", "id", "template", "x", "y", "angle", "speed", "lastShotFrame", "health")


class Game:
    def __init__(self, log_path):
        env = dict(os.environ, GEN_AUTO_SKIRMISH="1", GEN_AUTO_EXTERNAL="1", GEN_NO_VIEWS="1",
                   GEN_API_LOG_OFF="1", GEN_AUTO_MAP=MAP)
        self.log = open(log_path, "w")
        # -headless -noaudio always: a windowed run once blasted sound at the user.
        self.proc = subprocess.Popen([str(BIN), "-headless", "-noaudio"], cwd=DATA, env=env,
                                     stdout=self.log, stderr=subprocess.STDOUT)
        deadline = time.time() + 180
        while True:
            if self.proc.poll() is not None:
                raise RuntimeError(f"game exited early ({self.proc.returncode}); see {log_path}")
            try:
                if self.call("/healthz")["inGame"]:
                    break
            except OSError:
                pass
            if time.time() > deadline:
                raise RuntimeError("game not in-game after 180 s")
            time.sleep(0.5)
        assert self.call("/session")["headless"], "flags ignored: game is not headless"
        self.call("/control", {"action": "pause"})
        players = self.call("/players")
        self.me = next(p["index"] for p in players if p["controller"] == "external")
        self.enemy = next(p["index"] for p in players if p["controller"] == "human" and p["side"] != "Observer")
        self.civilian = next(p["index"] for p in players if p["side"] == "Civilian")
        self.neutral = next(p["index"] for p in players if p["controller"] == "computer" and not p["name"])
        self.frame = self.stable_frame()

    def stable_frame(self):
        # Pause lands on the logic thread later; a frame read before then leaves a step in flight.
        last = self.call("/healthz")["frame"]
        while True:
            time.sleep(0.3)
            f = self.call("/healthz")["frame"]
            if f == last:
                return f
            last = f

    def call(self, path, body=None):
        data = None if body is None else json.dumps(body).encode()
        req = urllib.request.Request(API + path, data=data, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read() or "null")

    def command(self, verb, ids=(), **params):
        r = self.call("/command", {"player": self.me, "ids": list(ids), "verb": verb, "params": params})
        if not r.get("accepted"):
            raise RuntimeError(f"{verb} rejected: {r}")
        return r

    def spawn(self, template, x, y, angle=0.0, owner=None):
        params = {"template": template, "pos": [x, y, 0], "angle": angle}
        if owner is not None:
            params["owner"] = owner
        return self.command("spawn", **params)["objectId"]

    def own(self, fragment):
        return [u["id"] for u in self.call(f"/units?player={self.me}") if fragment in u["template"]]

    def step(self):
        self.call("/control", {"action": "step"})
        target = self.frame + 1
        while (f := self.call("/healthz")["frame"]) < target:
            pass
        assert f == target, f"stepped past frame {target} to {f}"
        self.frame = f

    def record(self, ids, frames, rows, stop=None, money=False):
        for _ in range(frames):
            self.step()
            units = {u["id"]: u for u in self.call("/units")}
            cash = self.call(f"/resources?player={self.me}")["money"] if money else None
            assert self.call("/healthz")["frame"] == self.frame, "frame advanced during sampling"
            for i in ids:
                u = units.get(i)
                if u is None:
                    rows.append((self.frame, i, "dead", "", "", "", "", "", 0))
                    continue
                rows.append((self.frame, i, u["template"], round(u["x"], 3), round(u["y"], 3),
                             round(u["angle"], 5), round(u.get("speed", 0.0), 5),
                             u.get("lastShotFrame", 0), u.get("health", 0)))
            if money:
                rows.append((self.frame, "money", "money", "", "", "", "", "", cash))
            if stop and stop(rows):
                break

    def clear_strip(self, length, width=80):
        """World (x, y) of the west end of a flat, passable east-west strip nearest the map centre."""
        m = self.call("/map?ds=1")
        size, w, h = m["cellSize"], m["width"], m["height"]
        types = base64.b64decode(m["type"])
        heights = base64.b64decode(m["heightField"]["data"])
        lx, wy = -(-length // size), -(-width // size)
        cells = sorted(((cx, cy) for cy in range(h - wy) for cx in range(w - lx)),
                       key=lambda c: (c[0] + lx / 2 - w / 2) ** 2 + (c[1] - h / 2) ** 2)
        for cx, cy in cells:
            block = [(cy + j) * w + cx + i for j in range(wy) for i in range(lx)]
            hs = [heights[k] for k in block]
            if all(types[k] == 0 for k in block) and max(hs) - min(hs) <= 2:
                return cx * size + size / 2, (cy + wy / 2) * size
        raise RuntimeError("no clear strip")

    def close(self):
        self.proc.terminate()
        try:
            self.proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.proc.kill()
        self.log.close()


def settled(ids, idle_frames):
    """Stop once every id reported speed 0 for idle_frames consecutive frames after having moved."""
    def check(rows):
        tail = rows[-idle_frames * len(ids):]
        moved = any(r[6] not in ("", 0, 0.0) for r in rows)
        return moved and len(tail) == idle_frames * len(ids) and all(r[6] in ("", 0, 0.0) for r in tail)
    return check


def dead_for(uid, frames):
    def check(rows):
        return sum(1 for r in rows if r[1] == uid and r[2] == "dead") >= frames
    return check


def move(template, distance):
    def run(g):
        x, y = g.clear_strip(distance + 80)
        uid = g.spawn(template, x + 20, y)
        rows = []
        g.record([uid], 5, rows)
        g.command("move", [uid], pos=[x + 20 + distance, y, 0])
        meta = {"order_frame": g.frame, "unit": uid, "distance": distance}
        g.record([uid], 900, rows, stop=settled([uid], 15))
        return rows, meta
    return run


def turn(template):
    def run(g):
        x, y = g.clear_strip(300)
        uid = g.spawn(template, x + 250, y, angle=0.0)
        rows = []
        g.record([uid], 5, rows)
        g.command("move", [uid], pos=[x + 50, y, 0])
        meta = {"order_frame": g.frame, "unit": uid}
        g.record([uid], 600, rows, stop=settled([uid], 15))
        return rows, meta
    return run


def fire(attacker, target, gap, frames, target_owner="enemy"):
    def run(g):
        x, y = g.clear_strip(gap + 120)
        aid = g.spawn(attacker, x + 20, y)
        tid = g.spawn(target, x + 20 + gap, y, angle=math.pi, owner=getattr(g, target_owner))
        rows = []
        g.record([aid, tid], 5, rows)
        g.command("attack_target", [aid], targetId=tid)
        meta = {"order_frame": g.frame, "unit": aid, "target": tid}
        g.record([aid, tid], frames, rows, stop=dead_for(tid, 10))
        return rows, meta
    return run


def reach(attacker, target, gap):
    """No order: does an idle attacker fire at a target gap units away (centre to centre)?"""
    def run(g):
        x, y = g.clear_strip(int(gap) + 120)
        aid = g.spawn(attacker, x + 20, y)
        # Enemy, not civilian: idle units ignore neutral objects. Keep the target unarmed.
        tid = g.spawn(target, x + 20 + gap, y, angle=math.pi, owner=g.enemy)
        rows = []
        meta = {"order_frame": g.frame, "unit": aid, "target": tid, "gap": gap}
        g.record([aid, tid], 90, rows)
        return rows, meta
    return run


def splash(gap=140, spacing=15):
    """Crusader fires at the centre Ranger of a plus-shaped civilian cluster (civilians do not shoot back)."""
    def run(g):
        x, y = g.clear_strip(gap + 120, width=120)
        aid = g.spawn("AmericaTankCrusader", x + 20, y)
        cx = x + 20 + gap
        offsets = ((0, 0), (spacing, 0), (-spacing, 0), (0, spacing), (0, -spacing))
        tids = [g.spawn("AmericaInfantryRanger", cx + dx, y + dy, angle=math.pi, owner=g.civilian) for dx, dy in offsets]
        rows = []
        g.record([aid] + tids, 5, rows)
        g.command("attack_target", [aid], targetId=tids[0])
        meta = {"order_frame": g.frame, "unit": aid, "target": tids[0], "neighbours": tids[1:], "spacing": spacing}
        g.record([aid] + tids, 3000, rows, stop=dead_for(tids[0], 10))
        return rows, meta
    return run


def supply():
    """Supply centre (spawns its own Chinook) 400 units from a neutral warehouse; money sampled every frame."""
    def run(g):
        x, y = g.clear_strip(640, width=160)
        dock = g.spawn("SupplyDock", x + 560, y, owner=g.neutral)	# map warehouses belong to the neutral player
        g.spawn("AmericaSupplyCenter", x + 160, y)
        rows = []
        g.record([dock], 30, rows)
        chinooks = g.own("Chinook") or [g.spawn("AmericaVehicleChinook", x + 160, y + 100)]
        meta = {"order_frame": g.frame, "unit": chinooks[0], "dock": dock, "spawned_by_centre": bool(g.own("Chinook"))}
        g.record([chinooks[0], dock], 3600, rows, money=True)
        return rows, meta
    return run


def retaliate(gap=140):
    """Crusader hits one idle enemy Ranger; do the others join, how far do they chase, do they walk home?"""
    def run(g):
        x, y = g.clear_strip(gap + 160, width=200)
        aid = g.spawn("AmericaTankCrusader", x + 20, y)
        vx = x + 20 + gap
        # (dx, dy) from the victim: two inside the Wargrid joiner radius (48 units), one just outside, one far.
        offsets = ((0, 0), (0, 25), (0, -25), (0, 70), (0, -140))
        tids = [g.spawn("AmericaInfantryRanger", vx + dx, y + dy, angle=math.pi, owner=g.enemy) for dx, dy in offsets]
        rows = []
        g.record([aid] + tids, 5, rows)
        g.command("attack_target", [aid], targetId=tids[0])
        meta = {"order_frame": g.frame, "unit": aid, "victim": tids[0], "group": tids[1:], "offsets": offsets}
        g.record([aid] + tids, 900, rows)
        return rows, meta
    return run


SCENARIOS = {
    "move_ranger": move("AmericaInfantryRanger", 300),
    "move_crusader": move("AmericaTankCrusader", 400),
    "move_dozer": move("AmericaVehicleDozer", 400),
    "turn_ranger": turn("AmericaInfantryRanger"),
    "turn_crusader": turn("AmericaTankCrusader"),
    "turn_dozer": turn("AmericaVehicleDozer"),
    "range_crusader": fire("AmericaTankCrusader", "AmericaVehicleDozer", 300, 300),
    "range_ranger": fire("AmericaInfantryRanger", "AmericaVehicleDozer", 250, 400),
    "rof_crusader": fire("AmericaTankCrusader", "GLACommandCenter", 300, 600),
    "burst_ranger": fire("AmericaInfantryRanger", "GLACommandCenter", 250, 600),
    "duel_ranger": fire("AmericaInfantryRanger", "AmericaInfantryRanger", 90, 1200),
    "duel_crusader": fire("AmericaTankCrusader", "AmericaTankCrusader", 140, 1200),
    "splash_crusader": splash(),
    "supply_chinook": supply(),
    "retaliate_ranger": retaliate(),
}
# name -> (attacker, target, gap that fires, gap that does not)
REACH = {
    "reach_ranger": ("AmericaInfantryRanger", "AmericaVehicleDozer", 100, 160),
    "reach_crusader": ("AmericaTankCrusader", "AmericaVehicleDozer", 150, 220),
}


def run_once(scenario, log):
    g = Game(log)
    try:
        return scenario(g)
    finally:
        g.close()


def write(out, name, rows, meta, fields=FIELDS):
    with open(out / f"{name}.tsv", "w") as f:
        f.write("# " + json.dumps(meta) + "\n" + "\t".join(fields) + "\n")
        f.writelines("\t".join(map(str, r)) + "\n" for r in rows)


def fired_still(rows, meta):
    a = [r for r in rows if r[1] == meta["unit"] and r[2] != "dead"]
    return any(r[7] for r in a), any(r[6] for r in a)


def bisect(out, name, attacker, target, lo, hi):
    """Farthest centre gap (1-unit resolution) at which an idle attacker fires without moving."""
    probes = []
    for gap in (lo, hi):
        fired, moved = fired_still(*run_once(reach(attacker, target, gap), out / f"{name}.log"))
        probes.append((gap, int(fired), int(moved)))
    still = [p[1] and not p[2] for p in probes]	# beyond weapon range idle units chase, so "fired" alone is not enough
    if not (still[0] and not still[1]):
        raise RuntimeError(f"{name}: bracket {lo}..{hi} invalid: {probes}")
    while hi - lo > 1:
        mid = (lo + hi) // 2
        fired, moved = fired_still(*run_once(reach(attacker, target, mid), out / f"{name}.log"))
        probes.append((mid, int(fired), int(moved)))
        if fired and not moved:
            lo = mid
        else:
            hi = mid
    write(out, name, sorted(probes), {"attacker": attacker, "target": target, "farthest_fire": lo}, ("gap", "fired", "moved"))
    return lo


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=OUT)
    ap.add_argument("names", nargs="*")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for name in args.names or [*SCENARIOS, *REACH]:
        if name in REACH:
            print(f"{name}: farthest firing gap {bisect(args.out, name, *REACH[name])}")
            continue
        rows, meta = run_once(SCENARIOS[name], args.out / f"{name}.log")
        write(args.out, name, rows, meta)
        print(f"{name}: {len(rows)} rows, order at frame {meta['order_frame']}")


if __name__ == "__main__":
    main()
