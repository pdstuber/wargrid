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
import signal
import subprocess
import time
import urllib.request
from pathlib import Path
from typing import Any

HOME = Path.home()
BIN = Path(
    os.environ.get(
        "ZH_PARITY_BIN",
        HOME / "projects/GeneralsGameCode-macOS/build/apple-arm64-release/GeneralsMD/Release/generalszh_api",
    )
)
DATA = Path(os.environ.get("ZH_PARITY_DATA", HOME / "CnC/run/Command & Conquer Generals - Zero Hour"))
OUT = HOME / "CnC/parity/traces"
PORT = int(os.environ.get("ZH_PARITY_PORT", "3459"))
API = f"http://127.0.0.1:{PORT}"
MAP = r"maps\Killing Fields\Killing Fields.map"
FIELDS = ("frame", "id", "template", "x", "y", "angle", "speed", "lastShotFrame", "health")


class Game:
    def __init__(self, log_path):
        env = dict(
            os.environ,
            GEN_AUTO_SKIRMISH="1",
            GEN_AUTO_EXTERNAL="1",
            GEN_NO_VIEWS="1",
            GEN_API_LOG_OFF="1",
            GEN_FPS_CAP=os.environ.get("ZH_PARITY_FPS_CAP", "0"),
            GEN_API_PORT=str(PORT),
            GEN_AUTO_MAP=MAP,
        )
        self.log = open(log_path, "w")  # noqa: SIM115 - held open for the child process lifetime
        # -headless -noaudio always: a windowed run once blasted sound at the user.
        self.proc = subprocess.Popen(
            [str(BIN), "-headless", "-noaudio"],
            cwd=DATA,
            env=env,
            stdout=self.log,
            stderr=subprocess.STDOUT,
            start_new_session=True,  # own process group, so close() never needs a broad pkill
        )
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
        try:
            with urllib.request.urlopen(req, timeout=10) as r:
                return json.loads(r.read() or "null")
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"{path} {e.code}: {e.read().decode()}") from None

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

    def can_make(self, template):
        options = (o for b in self.call(f"/buildable?player={self.me}")["builders"] for o in b["options"])
        return next((o["canMake"] for o in options if o["template"] == template), None)

    def own(self, fragment):
        return [u["id"] for u in self.call(f"/units?player={self.me}") if fragment in u["template"]]

    def step(self, n=1):
        self.call("/control", {"action": "step", "value": n})
        target = self.frame + n
        while (f := self.call("/healthz")["frame"]) < target:
            pass
        assert f == target, f"stepped past frame {target} to {f}"
        self.frame = f

    def record(self, ids, frames, rows, stop=None, money=False, batch=1):
        for _ in range(0, frames, batch):
            self.step(batch)
            units = {u["id"]: u for u in self.call("/units")}
            cash = self.call(f"/resources?player={self.me}")["money"] if money else None
            assert self.call("/healthz")["frame"] == self.frame, "frame advanced during sampling"
            for i in ids:
                u = units.get(i)
                if u is None:
                    rows.append((self.frame, i, "dead", "", "", "", "", "", 0))
                    continue
                rows.append(
                    (
                        self.frame,
                        i,
                        u["template"],
                        round(u["x"], 3),
                        round(u["y"], 3),
                        round(u["angle"], 5),
                        round(u.get("speed", 0.0), 5),
                        u.get("lastShotFrame", 0),
                        u.get("health", 0),
                    )
                )
            if money:
                rows.append((self.frame, "money", "money", "", "", "", "", "", cash))
            if stop and stop(rows):
                break

    def clear_strip(self, length, width=80, slope=2):
        """World (x, y) of the west end of a flat, passable east-west strip nearest the map centre."""
        m = self.call("/map?ds=1")
        size, w, h = m["cellSize"], m["width"], m["height"]
        types = base64.b64decode(m["type"])
        heights = base64.b64decode(m["heightField"]["data"])
        lx, wy = math.ceil(length / size), math.ceil(width / size)
        cells = sorted(
            ((cx, cy) for cy in range(h - wy) for cx in range(w - lx)),
            key=lambda c: (c[0] + lx / 2 - w / 2) ** 2 + (c[1] - h / 2) ** 2,
        )
        for cx, cy in cells:
            block = [(cy + j) * w + cx + i for j in range(wy) for i in range(lx)]
            hs = [heights[k] for k in block]
            if all(types[k] == 0 for k in block) and max(hs) - min(hs) <= slope:
                return cx * size + size / 2, (cy + wy / 2) * size
        raise RuntimeError("no clear strip")

    def close(self):
        os.killpg(self.proc.pid, signal.SIGTERM)
        try:
            self.proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(self.proc.pid, signal.SIGKILL)
        self.log.close()


def settled(ids, idle_frames):
    """Stop once every id reported speed 0 for idle_frames consecutive frames after having moved."""

    def check(rows):
        tail = rows[-idle_frames * len(ids) :]
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
        rows: list[tuple[Any, ...]] = []
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
        rows: list[tuple[Any, ...]] = []
        g.record([uid], 5, rows)
        g.command("move", [uid], pos=[x + 50, y, 0])
        meta = {"order_frame": g.frame, "unit": uid}
        g.record([uid], 600, rows, stop=settled([uid], 15))
        return rows, meta

    return run


def power_for(g, attacker, x, y):
    # A POWERED defence is dark without a plant; the spawn is complete (no construction needed).
    if attacker == "AmericaPatriotBattery":
        g.spawn("AmericaPowerPlant", x + 20, y + 120)
    if attacker == "ChinaGattlingCannon":
        g.spawn("ChinaPowerPlant", x + 20, y + 120)


def fire(attacker, target, gap, frames, target_owner="enemy"):
    def run(g):
        x, y = g.clear_strip(gap + 120)
        power_for(g, attacker, x, y)
        aid = g.spawn(attacker, x + 20, y)
        tid = g.spawn(target, x + 20 + gap, y, angle=math.pi, owner=getattr(g, target_owner))
        rows: list[tuple[Any, ...]] = []
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
        power_for(g, attacker, x, y)
        aid = g.spawn(attacker, x + 20, y)
        # Enemy, not civilian: idle units ignore neutral objects. Keep the target unarmed.
        tid = g.spawn(target, x + 20 + gap, y, angle=math.pi, owner=g.enemy)
        rows: list[tuple[Any, ...]] = []
        meta = {"order_frame": g.frame, "unit": aid, "target": tid, "gap": gap}
        g.record([aid, tid], 90, rows)
        return rows, meta

    return run


def horde(template, count, target, gap, frames):
    """count units spawned together fire at one structure; the horde bonus shows as a shorter last interval."""

    def run(g):
        x, y = g.clear_strip(gap + 120)
        aids = [g.spawn(template, x + 20, y + 8 * i) for i in range(count)]
        tid = g.spawn(target, x + 20 + gap, y, angle=math.pi, owner=g.enemy)
        rows: list[tuple[Any, ...]] = []
        g.record([*aids, tid], 5, rows)
        g.command("attack_target", aids, targetId=tid)
        meta = {"order_frame": g.frame, "unit": aids[0], "target": tid}
        g.record([*aids, tid], frames, rows)
        return rows, meta

    return run


def splash(gap=140, spacing=15):
    """Crusader fires at the centre Ranger of a plus-shaped civilian cluster (civilians do not shoot back)."""

    def run(g):
        x, y = g.clear_strip(gap + 120, width=120)
        aid = g.spawn("AmericaTankCrusader", x + 20, y)
        cx = x + 20 + gap
        offsets = ((0, 0), (spacing, 0), (-spacing, 0), (0, spacing), (0, -spacing))
        tids = [
            g.spawn("AmericaInfantryRanger", cx + dx, y + dy, angle=math.pi, owner=g.civilian) for dx, dy in offsets
        ]
        rows: list[tuple[Any, ...]] = []
        g.record([aid, *tids], 5, rows)
        g.command("attack_target", [aid], targetId=tids[0])
        meta = {"order_frame": g.frame, "unit": aid, "target": tids[0], "neighbours": tids[1:], "spacing": spacing}
        g.record([aid, *tids], 3000, rows, stop=dead_for(tids[0], 10))
        return rows, meta

    return run


def until(g, rows, dock, done, what, limit=4000):
    for _ in range(limit):
        if done():
            return
        g.record([dock], 1, rows)
    raise RuntimeError(f"no {what} within {limit} frames")


def supply():
    """Dozer builds a supply centre 400 units from a neutral warehouse; money sampled every frame once the centre's Chinook exists."""

    def run(g):
        x, y = g.clear_strip(640, width=160)
        dock = g.spawn("SupplyDock", x + 560, y, owner=g.neutral)  # map warehouses belong to the neutral player
        dozer = g.spawn("AmericaVehicleDozer", x + 100, y)
        rows: list[tuple[Any, ...]] = []
        g.record([dock], 10, rows)  # a dozer ordered in its spawn frame gets "buildObjectNow failed"
        # A raw spawn never runs onBuildComplete and instant placement stays under construction,
        # so a dozer builds the centre; the API player is not American, hence its prerequisite first.
        g.command("build_structure", [dozer], template="AmericaPowerPlant", pos=[x + 100, y + 150, 0])
        until(g, rows, dock, lambda: g.can_make("AmericaSupplyCenter") == "ok", "buildable supply centre")
        g.command("build_structure", [dozer], template="AmericaSupplyCenter", pos=[x + 160, y, 0])
        until(g, rows, dock, lambda: g.own("Chinook"), "supply centre's Chinook")
        unit = g.own("Chinook")[0]
        meta = {"order_frame": g.frame, "unit": unit, "dock": dock, "build_frames": g.frame - rows[0][0] + 1}
        g.record([unit, dock], 3600, rows, money=True)
        return rows, meta

    return run


# faction -> (builder, depot, power plant or None, collector template, units per frame is read from the trace)
COLLECTORS = {
    "chinook": ("AmericaVehicleDozer", "AmericaSupplyCenter", "AmericaPowerPlant", "AmericaVehicleChinook"),
    "truck": ("ChinaVehicleDozer", "ChinaSupplyCenter", "ChinaPowerPlant", "ChinaVehicleSupplyTruck"),
    "worker": ("GLAInfantryWorker", "GLASupplyStash", None, "GLAInfantryWorker"),
}


def place_depot(g, builder, depot, pile_x, y, dist):
    """Order the depot at distance dist (centre to centre) west of the pile, or at the nearest legal distance if dist is None."""
    gaps = [dist] if dist else range(5, 400, 5)
    for gap in gaps:
        try:
            g.command("build_structure", [builder], template=depot, pos=[pile_x - gap, y, 0])
        except RuntimeError as e:
            if "illegal build location" not in str(e) and "buildObjectNow failed" not in str(e):
                raise
            continue
        return pile_x - gap
    raise RuntimeError(f"no legal {depot} placement at {dist or 'any'} units from the pile")


def collect(kind, dist, collectors=1, deposits=8, limit=22000, batch=1):
    """Build a depot dist units from one SupplyDock (dist None: the nearest legal spot) and record the first collector's trips."""
    builder_t, depot_t, power_t, collector_t = COLLECTORS[kind]

    def run(g):
        x, y = g.clear_strip((dist or 400) + 250, *((200, 2) if (dist or 0) <= 400 else (60, 12)))
        pile_x = x + (dist or 0) + 150 if dist else x + 400
        pile = g.spawn("SupplyDock", pile_x, y, owner=g.neutral)  # map warehouses belong to the neutral player
        builder = g.spawn(builder_t, x + 40, y)
        rows: list[tuple[Any, ...]] = []
        g.record([pile], 10, rows)  # a builder ordered in its spawn frame gets "buildObjectNow failed"
        if g.can_make(depot_t) != "ok":
            g.command("build_structure", [builder], template=power_t, pos=[x + 40, y + 70, 0])
            until(g, rows, pile, lambda: g.can_make(depot_t) == "ok", f"buildable {depot_t}")
        before = set(g.own(""))
        place_depot(g, builder, depot_t, pile_x, y, dist)
        until(g, rows, pile, lambda: set(g.own(collector_t)) - before - {builder}, f"{depot_t}'s collector")
        first = next(iter(set(g.own(collector_t)) - before - {builder}))
        depot = next(u for u in g.call(f"/units?player={g.me}") if u["template"] == depot_t)
        order = g.frame
        if dist and dist > 650:  # beyond the 700-unit warehouse scan an idle collector never starts; walk it into range
            g.command("move", [first], pos=[pile_x - 450, y, 0])
        units = [first]
        if collectors > 1:
            for _ in range(collectors - 1):
                g.command("train_unit", [depot["id"]], template=collector_t)
        meta = {
            "order_frame": order, "unit": first, "dock": pile, "builder": builder, "kind": kind, "collectors": collectors,
            "pile": [pile_x, y], "depot": [depot["x"], depot["y"]], "dist": abs(pile_x - depot["x"]), "requested": dist,
            "depot_template": depot_t, "build_frames": g.frame - rows[0][0] + 1,
        }  # fmt: skip

        extra: list[int] = []
        seen, last = 0, None
        for _ in range(0, limit, batch):
            if len(extra) < collectors - 1:  # trained collectors appear later; record them as they do
                extra += [u for u in g.own(collector_t) if u not in {*units, *extra, builder, *before}]
            g.record([*units, *extra, builder, pile], batch, rows, money=True, batch=batch)
            cash = rows[-1][8]
            seen += last is not None and cash > last
            last = cash
            if seen >= deposits * collectors:
                break
        meta["collector_ids"] = [*units, *extra]
        return rows, meta

    return run


def retaliate(
    gap=140, offsets=((0, 0), (0, 25), (0, -25), (0, 70), (0, -140)), attacker="AmericaTankCrusader", frames=900
):
    """An attacker hits one idle enemy Ranger; do the others join, how far do they chase, do they walk home?"""

    def run(g):
        x, y = g.clear_strip(gap + 160, width=200)
        aid = g.spawn(attacker, x + 20, y)
        vx = x + 20 + gap
        # (dx, dy) from the victim; the first is the victim itself. Wargrid's joiner radius is 4.8 cells = 120 units.
        tids = [g.spawn("AmericaInfantryRanger", vx + dx, y + dy, angle=math.pi, owner=g.enemy) for dx, dy in offsets]
        rows: list[tuple[Any, ...]] = []
        g.record([aid, *tids], 5, rows)
        g.command("attack_target", [aid], targetId=tids[0])
        meta = {"order_frame": g.frame, "unit": aid, "victim": tids[0], "group": tids[1:], "offsets": offsets}
        g.record([aid, *tids], frames, rows)
        return rows, meta

    return run


CHINA_MOVERS = [
    ("redguard", "ChinaInfantryRedguard", 300),
    ("tankhunter", "ChinaInfantryTankHunter", 300),
    ("battlemaster", "ChinaTankBattleMaster", 400),
    ("gattlingtank", "ChinaTankGattling", 400),
    ("cndozer", "ChinaVehicleDozer", 400),
    ("truck", "ChinaVehicleSupplyTruck", 400),
]

FRC_MOVERS = [
    ("worker", "GLAInfantryWorker", 300),
    ("rebel", "GLAInfantryRebel", 300),
    ("tunneldefender", "GLAInfantryTunnelDefender", 300),
    ("technical", "GLAVehicleTechnical", 400),
    ("scorpion", "GLATankScorpion", 400),
]

SCENARIOS = {
    "move_ranger": move("AmericaInfantryRanger", 300),
    "move_crusader": move("AmericaTankCrusader", 400),
    "move_dozer": move("AmericaVehicleDozer", 400),
    "move_rocket": move("AmericaInfantryMissileDefender", 300),
    "move_scout": move("AmericaVehicleHumvee", 400),
    "turn_ranger": turn("AmericaInfantryRanger"),
    "turn_crusader": turn("AmericaTankCrusader"),
    "turn_dozer": turn("AmericaVehicleDozer"),
    "turn_rocket": turn("AmericaInfantryMissileDefender"),
    "turn_scout": turn("AmericaVehicleHumvee"),
    "range_crusader": fire("AmericaTankCrusader", "AmericaVehicleDozer", 300, 300),
    "range_rocket": fire("AmericaInfantryMissileDefender", "AmericaVehicleDozer", 300, 400),
    "range_scout": fire("AmericaVehicleHumvee", "AmericaVehicleDozer", 250, 400),
    "range_battery": fire("AmericaPatriotBattery", "AmericaVehicleDozer", 300, 400),
    "range_ranger": fire("AmericaInfantryRanger", "AmericaVehicleDozer", 250, 400),
    "rof_crusader": fire("AmericaTankCrusader", "GLACommandCenter", 300, 600),
    "burst_ranger": fire("AmericaInfantryRanger", "GLACommandCenter", 250, 600),
    "rof_rocket": fire("AmericaInfantryMissileDefender", "GLACommandCenter", 150, 600),
    "rof_scout": fire("AmericaVehicleHumvee", "GLACommandCenter", 130, 600),
    "burst_battery": fire("AmericaPatriotBattery", "GLACommandCenter", 200, 600),
    "duel_ranger": fire("AmericaInfantryRanger", "AmericaInfantryRanger", 90, 1200),
    "duel_crusader": fire("AmericaTankCrusader", "AmericaTankCrusader", 140, 1200),
    **{f"move_{name}": move(template, distance) for name, template, distance in CHINA_MOVERS},
    **{f"turn_{name}": turn(template) for name, template, _ in CHINA_MOVERS},
    "range_redguard": fire("ChinaInfantryRedguard", "AmericaVehicleDozer", 250, 400),
    "range_tankhunter": fire("ChinaInfantryTankHunter", "AmericaVehicleDozer", 300, 400),
    "range_battlemaster": fire("ChinaTankBattleMaster", "AmericaVehicleDozer", 300, 300),
    "range_gattlingtank": fire("ChinaTankGattling", "AmericaVehicleDozer", 300, 400),
    "rof_redguard": fire("ChinaInfantryRedguard", "GLACommandCenter", 250, 600),
    "rof_battlemaster": fire("ChinaTankBattleMaster", "GLACommandCenter", 300, 600),
    "ramp_gattling_tank": fire("ChinaTankGattling", "GLACommandCenter", 250, 600),
    "ramp_gattling_cannon": fire("ChinaGattlingCannon", "GLACommandCenter", 200, 600),
    "horde_redguard": horde("ChinaInfantryRedguard", 5, "GLACommandCenter", 80, 600),
    **{f"move_{name}": move(template, distance) for name, template, distance in FRC_MOVERS},
    **{f"turn_{name}": turn(template) for name, template, _ in FRC_MOVERS},
    "range_rebel": fire("GLAInfantryRebel", "AmericaVehicleDozer", 250, 400),
    "range_tunneldefender": fire("GLAInfantryTunnelDefender", "AmericaVehicleDozer", 300, 400),
    "range_technical": fire("GLAVehicleTechnical", "AmericaVehicleDozer", 300, 400),
    "range_scorpion": fire("GLATankScorpion", "AmericaVehicleDozer", 300, 400),
    "burst_rebel": fire("GLAInfantryRebel", "GLACommandCenter", 250, 600),
    "rof_technical": fire("GLAVehicleTechnical", "GLACommandCenter", 130, 600),
    "rof_scorpion": fire("GLATankScorpion", "GLACommandCenter", 300, 600),
    "rof_tunnel": fire("GLATunnelNetwork", "GLACommandCenter", 200, 600),
    "splash_crusader": splash(),
    "supply_chinook": supply(),
    **{
        f"collect_{kind}_{d}{'_x2' if n == 2 else ''}": collect(kind, d * 25 if d else None, n)
        for kind in COLLECTORS
        for d, n in ((6, 1), (12, 1), (30, 1), (0, 1), (12, 2))  # d 0: the nearest legal depot spot
    },
    # Wargrid layouts reach 162.5 / 312.5 / 762.5 units exactly (4x5 pile, 3x3 depot); name = units x 10.
    **{
        f"collect_{kind}_u{int(units * 10)}{f'_x{n}' if n > 1 else ''}": collect(kind, units, n)
        for kind in COLLECTORS
        for units, n in ((162.5, 1), (312.5, 1), (762.5, 1))
    },
    **{f"collect_{kind}_u3125_x{n}": collect(kind, 312.5, n) for kind in ("chinook", "truck") for n in (2, 4)},
    **{f"collect_worker_u1625_x{n}": collect("worker", 162.5, n) for n in (2, 4)},
    **{f"collect_truck_6_b{b}": collect("truck", 150, 1, 8, batch=b) for b in (1, 5, 10)},
    "retaliate_ranger": retaliate(),
    # An API Ranger attacker (range 100) 95 units away; the group stands behind the victim and walks out to kill it, then home.
    "retaliate_return": retaliate(
        gap=95, offsets=((0, 0), (40, 0), (70, 0), (100, 0), (0, 60)), attacker="AmericaInfantryRanger", frames=1500
    ),
    "retaliate_bisect": retaliate(offsets=((0, 0), (0, 100), (0, -115), (0, 125), (0, -130))),
}
# name -> (attacker, target, gap that fires, gap that does not)
REACH = {
    "reach_ranger": ("AmericaInfantryRanger", "AmericaVehicleDozer", 100, 160),
    "reach_crusader": ("AmericaTankCrusader", "AmericaVehicleDozer", 150, 220),
    "reach_rocket": ("AmericaInfantryMissileDefender", "AmericaVehicleDozer", 150, 260),
    "reach_scout": ("AmericaVehicleHumvee", "AmericaVehicleDozer", 100, 220),
    "reach_battery": ("AmericaPatriotBattery", "AmericaVehicleDozer", 150, 300),
    "reach_redguard": ("ChinaInfantryRedguard", "AmericaVehicleDozer", 100, 160),
    "reach_tankhunter": ("ChinaInfantryTankHunter", "AmericaVehicleDozer", 150, 260),
    "reach_battlemaster": ("ChinaTankBattleMaster", "AmericaVehicleDozer", 150, 220),
    "reach_gattlingtank": ("ChinaTankGattling", "AmericaVehicleDozer", 100, 260),
    "reach_gattlingcannon": ("ChinaGattlingCannon", "AmericaVehicleDozer", 150, 320),
    "reach_rebel": ("GLAInfantryRebel", "AmericaVehicleDozer", 100, 160),
    "reach_tunneldefender": ("GLAInfantryTunnelDefender", "AmericaVehicleDozer", 150, 260),
    "reach_technical": ("GLAVehicleTechnical", "AmericaVehicleDozer", 100, 220),
    "reach_scorpion": ("GLATankScorpion", "AmericaVehicleDozer", 100, 220),
    "reach_tunnel": ("GLATunnelNetwork", "AmericaVehicleDozer", 150, 260),
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
    still = [p[1] and not p[2] for p in probes]  # beyond weapon range idle units chase, so "fired" alone is not enough
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
    write(
        out,
        name,
        sorted(probes),
        {"attacker": attacker, "target": target, "farthest_fire": lo},
        ("gap", "fired", "moved"),
    )
    return lo


def raise_exit():
    raise SystemExit(143)


def main():
    signal.signal(signal.SIGTERM, lambda *_: raise_exit())  # run the finally blocks so the game dies with its lane
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
