"""Tests for the Zero Hour parity harness: synthetic traces and fake launches, no engine."""

import base64
import inspect
import json
import signal
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any, ClassVar

sys.path.insert(0, str(Path(__file__).parent / "zh_parity"))

import analyze
import parity

COLS = ("frame", "id", "template", "x", "y", "angle", "speed", "lastShotFrame", "health")


def put_trace(d: Path, name: str, rows: list[tuple[Any, ...]], **meta: Any) -> None:
    d.mkdir(parents=True, exist_ok=True)
    body = "# " + json.dumps(meta) + "\n" + "\t".join(COLS) + "\n"
    (d / f"{name}.tsv").write_text(body + "".join("\t".join(map(str, r)) + "\n" for r in rows))


def move_rows(first_id: int, speed: float, start: int = 5, order: int = 100) -> list[tuple[Any, ...]]:
    return [
        (order + i, first_id, "u", i, 0, 0, speed if i >= start else 0, 0, 10) for i in range(0, 40)
    ]  # speed per frame; analyze multiplies by 30


def money_rows(period: int, credit: int, cycles: int = 6) -> list[tuple[Any, ...]]:
    rows: list[tuple[Any, ...]] = []
    cash = 0
    for f in range(1, period * cycles + 1):
        cash += credit if f % period == 0 else 0
        rows.append((f, "money", "money", "", "", "", "", "", cash))
        rows.append((f, 7, "u", 5, 0, 0, 1 if f % 2 else 0, 0, 10))
    return rows


class Pooling(unittest.TestCase):
    def test_summary_spread(self) -> None:
        s = analyze.summarize([10.0, 12.0, 11.0])
        self.assertEqual((s["n"], s["median"], s["min"], s["max"]), (3, 11.0, 10.0, 12.0))
        self.assertAlmostEqual(s["spread"], 2 / 11, places=3)

    def test_find_traces_flat_and_reps(self) -> None:
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            put_trace(root / "rep1", "move_ranger", move_rows(7, 0.5), unit=7, order_frame=100)
            put_trace(root / "rep2", "move_ranger", move_rows(9, 0.5), unit=9, order_frame=100)
            put_trace(root, "turn_ranger", [], unit=1, order_frame=0)
            found = sorted((s, r) for s, r, _ in analyze.find_traces([root]))
            self.assertEqual(found, [("move_ranger", "rep1"), ("move_ranger", "rep2"), ("turn_ranger", "-")])

    def test_json_lines_one_per_trace(self) -> None:
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            put_trace(root / "rep1", "move_ranger", move_rows(7, 0.5), unit=7, order_frame=100)
            lines = [json.loads(x) for x in analyze.json_lines([root])]
            self.assertEqual(len(lines), 1)
            self.assertEqual(lines[0]["scenario"], "move_ranger")
            self.assertEqual(lines[0]["rep"], "rep1")
            self.assertEqual(lines[0]["metrics"]["top_speed"], 15.0)

    def test_pool_across_reps_gives_spread(self) -> None:
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            for rep, speed in (("rep1", 0.6), ("rep2", 0.66), ("rep3", 0.63)):
                put_trace(root / rep, "move_ranger", move_rows(7, speed), unit=7, order_frame=100)
            pooled = analyze.pooled_metrics("move_ranger", analyze.runs_of("move_ranger", [root]))
            self.assertEqual(pooled["top_speed"]["n"], 3)
            self.assertAlmostEqual(pooled["top_speed"]["median"], 18.9, places=1)
            self.assertAlmostEqual(pooled["top_speed"]["spread"], 0.06 * 30 / 18.9, places=2)

    def test_collect_pool_uses_credit_rate(self) -> None:
        meta = {"unit": 7, "collectors": 1, "dist": 10, "pile": [10, 0], "depot": [0, 0], "order_frame": 0}
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            for rep in ("rep1", "rep2"):
                put_trace(root / rep, "collect_truck_6", money_rows(100, 75), **meta)
            pooled = analyze.pooled_metrics("collect_truck_6", analyze.runs_of("collect_truck_6", [root]))
            self.assertEqual(pooled["credits_per_min"]["median"], 75 * 18.0)
            self.assertEqual(pooled["credits_per_min"]["n"], 2)


class Opening(unittest.TestCase):
    ORDER = 100
    DEPOSITS = ((1000, 11), (1200, 12), (1400, 13), (1600, 11), (1800, 12), (2000, 13), (3600, 11), (3601, 12))
    META: ClassVar[dict[str, Any]] = {
        "order_frame": ORDER, "collector_ids": [14, 11, 12, 13], "depot": [0, 0], "pile": [100, 0], "dock": 99,
        "seconds": 130, "steady_from": 60,
    }  # fmt: skip

    def opening_rows(
        self, dock_dies_at: int | None = None, deposits: tuple[tuple[int, int], ...] | None = None, extra=None
    ) -> list[dict[str, str]]:
        """Every collector stands at the pile, then at the depot for the 40 frames around its deposit; 14 is parked at the depot."""
        paid = [(self.ORDER + off, who) for off, who in (deposits or self.DEPOSITS)]
        rows: list[tuple[Any, ...]] = []
        cash = 0
        for f in range(self.ORDER, self.ORDER + 3701):
            cash += 75 if any(f == pf for pf, _ in paid) else 0
            rows.append((f, "money", "money", "", "", "", "", "", cash))
            for c in self.META["collector_ids"]:
                at_depot = c == 14 or any(who == c and pf - 30 <= f <= pf + 10 for pf, who in paid)
                rows.append((f, c, "u", 3 if at_depot else 100, 0, 0, 0, 0, 10))
            for c, x in (extra or {}).get(f, ()):
                rows[self.META["collector_ids"].index(c) - len(self.META["collector_ids"])] = (
                    f,
                    c,
                    "u",
                    x,
                    0,
                    0,
                    0,
                    0,
                    10,
                )
            if dock_dies_at is not None and f >= self.ORDER + dock_dies_at:
                rows.append((f, 99, "dead", "", "", "", "", "", 0))
        with tempfile.TemporaryDirectory() as t:
            put_trace(Path(t), "open_x", rows, **self.META)
            return analyze.load(Path(t) / "open_x.tsv")[1]

    def test_opening_curve(self) -> None:
        c = analyze.opening_curve(self.META, self.opening_rows(), 200)
        self.assertEqual((c["gross"][60], c["gross"][120]), (375, 525))
        self.assertEqual((c["net"][60], c["net"][120]), (175, 325))
        self.assertEqual(c["depositors"], 3)
        self.assertAlmostEqual(c["break_even_s"], 1400 / 30, places=1)
        self.assertAlmostEqual(c["steady_per_min"], 3 * 75 / (1900 / 1800), places=1)
        self.assertIsNone(c["pile_empty_s"])

    def test_pile_empty_cuts_the_steady_rate(self) -> None:
        c = analyze.opening_curve(self.META, self.opening_rows(dock_dies_at=2100), 200)
        self.assertAlmostEqual(c["pile_empty_s"], 70.0, places=1)
        self.assertAlmostEqual(c["steady_per_min"], 75 / (300 / 1800), places=1)

    def test_steady_window_is_fixed_not_tied_to_the_first_deposits(self) -> None:
        late = ((500, 11), (2000, 12), (2300, 11), (3000, 12), (3300, 11))  # 13 first delivers after the window opens
        c = analyze.opening_curve(self.META, self.opening_rows(deposits=late), 200)
        self.assertAlmostEqual(c["steady_per_min"], 4 * 75 / (1900 / 1800), places=1)

    def test_deposit_goes_to_the_collector_that_unloads_not_the_nearest_one(self) -> None:
        # 12 queues loaded and closer to the depot (x=1) while 11 unloads (x=3), there since 30 frames before its deposit
        queue = {f: [(12, 1)] for f in range(100 + 985, 100 + 1006)}
        rows = self.opening_rows(deposits=((1000, 11), (1200, 12)), extra=queue)
        who = [w for _, w, _ in analyze.opening_deposits(self.META, rows)]
        self.assertEqual(who, [11, 12])

    def test_trips_count_every_collector_that_delivers(self) -> None:
        c = analyze.opening_curve(self.META, self.opening_rows(), 200)
        self.assertEqual(c["trips"], {11: 3, 12: 3, 13: 2})
        self.assertEqual((c["trips_min"], c["trips_max"]), (2, 3))

    def test_scenarios_registered(self) -> None:
        names = {
            f"open_{k}_u{u}_x{n}"
            for k, n in (("chinook", 2), ("truck", 3), ("worker", 5), ("worker", 7))
            for u in (1625, 3125)
        }
        self.assertLessEqual(names, set(parity.SCENARIOS))


class DockHold(unittest.TestCase):
    ORDER = 100

    def load_rows(self, rows: list[tuple[Any, ...]]) -> list[dict[str, str]]:
        with tempfile.TemporaryDirectory() as t:
            put_trace(Path(t), "collect_x", rows)
            return analyze.load(Path(t) / "collect_x.tsv")[1]

    def deposits(
        self,
        stop_s: float = 600,
        dead_pile_s: float | None = None,
        period: int = 60,
        credit: int = 75,
        later_credit: int | None = None,
        length: int = 600 * 30,
    ) -> list[dict[str, str]]:
        return self.load_rows(self.deposits_raw(stop_s, dead_pile_s, period, credit, later_credit, length))

    def deposits_raw(
        self,
        stop_s: float = 600,
        dead_pile_s: float | None = None,
        period: int = 60,
        credit: int = 75,
        later_credit: int | None = None,
        length: int = 600 * 30,
    ) -> list[tuple[Any, ...]]:
        rows: list[tuple[Any, ...]] = []
        cash = n = 0
        for off in range(0, length + 1):
            f = self.ORDER + off
            if off and off % period == 0 and off <= stop_s * 30:
                n += 1
                cash += later_credit if later_credit and n > 16 else credit
            rows.append((f, "money", "money", "", "", "", "", "", cash))
            if dead_pile_s is not None and off >= dead_pile_s * 30:
                rows.append((f, 99, "dead", "", "", "", "", "", 0))
        return rows

    META: ClassVar[dict[str, Any]] = {
        "order_frame": 100, "collectors": 2, "dist": 10, "dock": 99,
    }  # fmt: skip

    def test_lock_windows(self) -> None:
        held = (0, 5, 5, 5, 0, 6, 6, 0, 7)
        rows: list[tuple[Any, ...]] = [(f, 9, "lock", "", "", "", "", "", a) for f, a in enumerate(held, 1)]
        rows += [(f, 8, "lock", "", "", "", "", "", 3) for f in range(1, 10)]  # another dock never changes owner
        rows += [
            (f, 9, "SupplyDock", 0, 0, 0, 0, 0, hp) for f, hp in enumerate((1, 2, 3, 4, 5, 6, 7, 8, 9), 1)
        ]  # same id: HP is not a lock
        w = analyze.lock_windows(self.load_rows(rows), 9)
        self.assertEqual((w["lengths"], w["median"], w["count"], w["open"]), ([3, 2], 2.5, 2, 1))
        self.assertEqual(analyze.lock_windows(self.load_rows(rows), 7)["median"], None)

    def test_collect_rates_steady_window(self) -> None:
        rows = self.deposits(later_credit=150)
        r = analyze.collect_rates(self.META, rows)
        self.assertEqual(r["steady_per_min"], 4500.0)  # 150 credits every 2 s
        self.assertEqual(r["old_per_min"], 2250.0)  # first 16 deposits (8 per collector) paid 75
        self.assertEqual(r["old_per_min"], analyze.collecting(self.META, rows, 16)["credits_per_min"])
        self.assertEqual((r["window_end_s"], r["short_window"], r["pile_empty_s"]), (600.0, False, None))

    def test_collect_rates_pile_empty(self) -> None:
        dead = analyze.collect_rates(self.META, self.deposits(dead_pile_s=500))
        self.assertEqual((dead["pile_empty_s"], dead["window_end_s"], dead["short_window"]), (500.0, 500.0, False))
        quiet = analyze.collect_rates(self.META, self.deposits(stop_s=500))
        self.assertEqual((quiet["pile_empty_s"], quiet["window_end_s"], quiet["short_window"]), (500.0, 500.0, False))
        short = analyze.collect_rates(self.META, self.deposits(stop_s=400))
        self.assertEqual((short["pile_empty_s"], short["short_window"]), (400.0, True))
        self.assertEqual(short["steady_per_min"], 2250.0)

    def test_sparse_live_collectors_are_not_an_empty_pile(self) -> None:
        # Chinook-like: 600 credits every 375 frames, trace ends 360 frames after the last deposit
        rows = self.deposits(period=375, credit=600, length=43 * 375 + 360)
        r = analyze.collect_rates(self.META, rows)
        self.assertIsNone(r["pile_empty_s"])
        self.assertEqual(r["window_end_s"], round((43 * 375 + 360) / 30, 1))

    def test_long_rows_registered(self) -> None:
        names = {
            f"collect_{k}_u{u}_x{n}_s600"
            for k, u, n in (
                ("chinook", 3125, 2), ("worker", 1625, 2), ("worker", 1625, 4),
                ("truck", 3125, 2), ("truck", 3125, 4), ("chinook", 3125, 4),
            )
        }  # fmt: skip
        self.assertLessEqual(names, set(parity.SCENARIOS))
        for n in names:
            run = parity.SCENARIOS[n]
            self.assertEqual(inspect.getclosurevars(run).nonlocals["seconds"], 600, n)

    def test_sweep_rows_registered(self) -> None:
        names = {
            f"collect_{k}_u{u}_x{n}_s600"
            for k, u in (("worker", 1625), ("worker", 3125), ("truck", 3125), ("chinook", 3125))
            for n in range(1, 9)
        }
        self.assertEqual(len(names), 32)
        self.assertLessEqual(names, set(parity.SCENARIOS))
        for n in names:
            self.assertEqual(inspect.getclosurevars(parity.SCENARIOS[n]).nonlocals["seconds"], 600, n)

    def test_x1_long_row_metrics(self) -> None:
        meta = {
            "order_frame": 100, "collectors": 1, "dist": 10, "dock": 99, "unit": 7, "depot_id": 55,
            "collector_ids": [7], "depot": [0, 0], "pile": [10, 0],
        }  # fmt: skip
        cycle = [(10, 0), (10, 0), (5, 1), (0, 1), (0, 0), (0, 0)]
        rows: list[tuple[Any, ...]] = []
        cash = 0
        for off in range(0, 600 * 30 + 1):
            f = 100 + off
            px, v = cycle[off % 6]
            cash += 75 if off and off % 6 == 0 else 0
            rows.append((f, "money", "money", "", "", "", "", "", cash))
            rows.append((f, 7, "u", px, 0, 0, v, 0, 10))
            rows.append((f, 99, "lock", "", "", "", "", "", 7 if off % 6 < 2 else 0))
            rows.append((f, 55, "lock", "", "", "", "", "", 7 if off % 6 in (4, 5) else 0))
        m = analyze.metrics("collect_worker_u1625_x1_s600", meta, self.load_rows(rows))
        self.assertEqual(m["depositors"], 1)
        self.assertEqual(m["old_per_min"], 75 / 6 * 1800)
        self.assertGreater(m["pile_lock_count"], 0)
        self.assertGreater(m["depot_lock_count"], 0)
        self.assertGreater(m["steady_per_min"], 0)

    def test_saturation_curve(self) -> None:
        rates = {1: 434, 2: 855, 3: 1270, 4: 1650, 5: 2000, 6: 2010, 7: 2010, 8: 1990}
        s = analyze.saturation(rates, 200)
        self.assertEqual((s["cap"], s["n_cap"], s["n90"], s["spend90"]), (2010, 6, 5, 800))
        self.assertEqual(s["marginal"][6], 10)
        self.assertEqual(s["payback_s"][8], float("inf"))
        self.assertEqual(s["payback_s"][7], float("inf"))
        self.assertEqual(s["payback_s"][2], 200 / ((855 - 434) / 60))
        self.assertEqual(s["skipped"], [])

    def test_saturation_skips_short(self) -> None:
        s = analyze.saturation({1: 400, 2: 800, 3: None, 4: 900, 5: 5000}, 200, short={4, 5})
        self.assertEqual(s["skipped"], [3, 4, 5])
        self.assertEqual((s["cap"], s["n_cap"], s["n90"]), (800, 2, 2))
        self.assertEqual(sorted(s["marginal"]), [2])

    def test_saturation_lines_pool_sweep_dirs(self) -> None:
        meta = {**self.META, "depot_id": 55, "collector_ids": [1, 2], "depot": [0, 0], "pile": [100, 0]}
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            for n, period, stop in ((1, 120, 600), (2, 60, 600), (3, 40, 300)):
                put_trace(root, f"collect_worker_u1625_x{n}_s600", self.deposits_raw(stop, period=period), **meta)
            (line,) = analyze.saturation_lines([root])
        out = json.loads(line)
        self.assertEqual((out["kind"], out["units10"], out["skipped"]), ("worker", 1625, [3]))
        self.assertEqual(out["n_cap"], 2)

    def test_metrics_routes_s600_to_lock_windows(self) -> None:
        meta = {**self.META, "depot_id": 55, "collector_ids": [1, 2], "depot": [0, 0], "pile": [100, 0]}
        rows = self.deposits()
        rows += self.load_rows(
            [(f, 99, "lock", "", "", "", "", "", 4 if 110 <= f < 120 else 0) for f in range(100, 700)]
        )
        rows += self.load_rows(
            [(f, 55, "lock", "", "", "", "", "", 6 if 130 <= f < 150 else 0) for f in range(100, 700)]
        )
        m = analyze.metrics("collect_truck_u3125_x2_s600", meta, rows)
        self.assertEqual((m["pile_lock_count"], m["pile_lock_median"]), (1, 10))
        self.assertEqual((m["depot_lock_count"], m["depot_lock_median"]), (1, 20))
        self.assertIn("steady_per_min", m)

    def test_pooled_s600_has_no_whole_trace_rate_and_any_short(self) -> None:
        meta = {**self.META, "depot_id": 55, "collector_ids": [1, 2], "depot": [0, 0], "pile": [100, 0]}
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            for rep, stop in (("rep1", 600), ("rep2", 400)):
                put_trace(root / rep, "collect_truck_u3125_x2_s600", self.deposits_raw(stop), **meta)
            name = "collect_truck_u3125_x2_s600"
            pooled = analyze.pooled_metrics(name, analyze.runs_of(name, [root]))
        self.assertNotIn("credits_per_min", pooled)
        self.assertIs(pooled["short_window"], True)


class Report(unittest.TestCase):
    def test_md_table_columns_and_verdict(self) -> None:
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            for rep in ("rep1", "rep2"):
                put_trace(root / rep, "move_ranger", move_rows(7, 0.7), unit=7, order_frame=100)
            md = analyze.md_report([root], expect={"move_ranger": [("top_speed", 20, 2, "0.8 cells/s")]})
            lines = md.splitlines()
            self.assertTrue(lines[0].startswith("| scenario | metric | measured"))
            row = next(x for x in lines if x.startswith("| move_ranger | top_speed"))
            self.assertIn("| 21 |", row)
            self.assertIn("| 2 |", row)
            self.assertIn("| 20 |", row)
            self.assertIn("PASS", row)

    def test_accepted_verdict(self) -> None:
        self.assertEqual(analyze.verdict(115, 100, 10, accepted=120), "ACCEPTED")
        self.assertEqual(analyze.verdict(115, 100, 10), "FAIL")
        self.assertEqual(analyze.verdict(100, 100, 10, accepted=120), "PASS")

    def test_wargrid_values_from_definitions(self) -> None:
        speeds = analyze.definition_speeds()
        self.assertEqual(speeds["move_scout"], 60)
        self.assertEqual(speeds["move_crusader"], 30)
        self.assertEqual(analyze.EXPECT["move_scout"][0][1], 60)


class Same(unittest.TestCase):
    def test_same_ignores_absolute_frames_and_ids(self) -> None:
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            put_trace(root, "a", move_rows(7, 0.5, order=100), unit=7, order_frame=100)
            put_trace(root, "b", move_rows(41, 0.5, order=900), unit=41, order_frame=900)
            self.assertIsNone(analyze.same(root / "a.tsv", root / "b.tsv"))

    def test_different_names_first_row(self) -> None:
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            put_trace(root, "a", move_rows(7, 0.5), unit=7, order_frame=100)
            put_trace(root, "b", move_rows(7, 0.6), unit=7, order_frame=100)
            diff = analyze.same(root / "a.tsv", root / "b.tsv")
            self.assertIsNotNone(diff)
            self.assertIn("row 5", diff or "")


class Names(unittest.TestCase):
    def test_glob_and_unknown(self) -> None:
        self.assertEqual(parity.resolve(["move_cru*"]), ["move_crusader"])
        self.assertEqual(parity.resolve(["move_crusader", "move_cru*"]), ["move_crusader"])
        with self.assertRaises(SystemExit) as cm:
            parity.resolve(["move_crusadr"])
        self.assertEqual(cm.exception.code, 2)

    def test_batch_scenarios_are_gone(self) -> None:
        self.assertNotIn("collect_truck_6_b5", parity.SCENARIOS)

    def test_empty_means_all(self) -> None:
        self.assertGreater(len(parity.resolve([])), 50)


class Sweep(unittest.TestCase):
    def test_pending_skips_finished(self) -> None:
        with tempfile.TemporaryDirectory() as t:
            out = Path(t)
            put_trace(out / "rep1", "move_ranger", [])
            jobs = parity.pending(out, ["move_ranger", "turn_ranger"], 2)
            self.assertEqual(jobs, [(1, "turn_ranger"), (2, "move_ranger"), (2, "turn_ranger")])

    def test_partial_tmp_is_not_finished(self) -> None:
        with tempfile.TemporaryDirectory() as t:
            out = Path(t)
            (out / "rep1").mkdir()
            (out / "rep1" / "move_ranger.tsv.tmp").write_text("x")
            self.assertEqual(parity.pending(out, ["move_ranger"], 1), [(1, "move_ranger")])

    def test_write_is_atomic_and_names_scenario(self) -> None:
        with tempfile.TemporaryDirectory() as t:
            out = Path(t)
            parity.write(out, "s", [(1, 2, "x", "", "", "", "", "", 0)], {"order_frame": 1})
            self.assertFalse(list(out.glob("*.tmp")))
            self.assertEqual(analyze.load(out / "s.tsv")[0]["scenario"], "s")

    def test_retry_log_and_distinct_lanes(self) -> None:
        calls: list[tuple[tuple[int, str], int]] = []

        def launch(job: tuple[int, str], port: int) -> tuple[str, int]:
            calls.append((job, port))
            return ("fail", 1) if job == (1, "a") and sum(c[0] == job for c in calls) == 1 else ("ok", 0)

        with tempfile.TemporaryDirectory() as t:
            out = Path(t)
            failed = parity.sweep(out, [(1, "a"), (1, "b")], 2, 1, launch)
            lines = [json.loads(x) for x in (out / "runs.jsonl").read_text().splitlines()]
        self.assertEqual(failed, 0)
        self.assertEqual(
            sorted((x["scenario"], x["attempt"], x["status"]) for x in lines),
            [("a", 1, "fail"), ("a", 2, "ok"), ("b", 1, "ok")],
        )
        self.assertTrue(all(x["port"] % 2 == 0 or parity.PORT % 2 for x in lines))

    def test_config_error_not_retried(self) -> None:
        with tempfile.TemporaryDirectory() as t:
            out = Path(t)
            failed = parity.sweep(out, [(1, "a")], 1, 3, lambda job, port: ("fail", 2))
            self.assertEqual(failed, 1)
            self.assertEqual(len((out / "runs.jsonl").read_text().splitlines()), 1)


class FakeGame:
    def __init__(self, refuse: int = 0, message: str = "illegal build location") -> None:
        self.refuse, self.message = refuse, message
        self.orders: list[float] = []

    def command(self, verb: str, ids: Any = (), **params: Any) -> dict[str, Any]:
        self.orders.append(params["pos"][0])
        if len(self.orders) <= self.refuse:
            raise RuntimeError(self.message)
        return {}


class RecordGame(parity.Game):
    def __init__(self, units: list[dict[str, Any]]) -> None:
        self.units, self.frame = units, 0

    def call(self, path: str, body: Any = None) -> Any:
        if path == "/units":
            return self.units
        return {"frame": self.frame}

    def step(self, n: int = 1) -> None:
        self.frame += n


class Helpers(unittest.TestCase):
    def test_record_lock_rows(self) -> None:
        base = {"template": "SupplyDock", "x": 0, "y": 0, "angle": 0}
        g = RecordGame([{**base, "id": 5, "activeDocker": 7}, {**base, "id": 6}])
        rows: list[tuple[Any, ...]] = []
        g.record([], 1, rows, docks=(5, 9))
        self.assertEqual([r[8] for r in rows if r[2] == "lock"], [7, 0])  # absent dock reads 0
        with self.assertRaises(KeyError):
            g.record([], 1, rows, docks=(6,))  # present without the field: an old fork

    def test_train_affordable_waits_for_money(self) -> None:
        class Bank:
            me = 1

            def __init__(self, money: int) -> None:
                self.money, self.trained = money, 0

            def call(self, path: str) -> dict[str, int]:
                return {"money": self.money}

            def command(self, verb: str, ids: Any, **params: Any) -> None:
                self.money -= 1200
                self.trained += 1

        g = Bank(2500)
        self.assertEqual(parity.train_affordable(g, 5, "Chinook", 1200, 4), 2)
        g.money += 3000
        self.assertEqual(parity.train_affordable(g, 5, "Chinook", 1200, 2), 0)
        self.assertEqual(g.trained, 4)

    def test_place_depot_retries_illegal_spots(self) -> None:
        g = FakeGame(refuse=2)
        self.assertEqual(parity.place_depot(g, 1, "D", 1000, 0, None), 1000 - 15)

    def test_place_depot_reraises_other_errors(self) -> None:
        with self.assertRaises(RuntimeError):
            parity.place_depot(FakeGame(refuse=1, message="boom"), 1, "D", 1000, 0, None)

    def test_settled_and_dead_for(self) -> None:
        rows = [(i, 1, "u", 0, 0, 0, 1 if i < 3 else 0, 0, 5) for i in range(10)]
        self.assertTrue(parity.settled([1], 3)(rows))
        self.assertFalse(parity.settled([1], 9)(rows))
        dead = [(i, 1, "dead", "", "", "", "", "", 0) for i in range(4)]
        self.assertTrue(parity.dead_for(1, 4)(dead))
        self.assertFalse(parity.dead_for(1, 5)(dead))

    def test_clear_strip(self) -> None:
        class G(parity.Game):
            def __init__(self, heights: bytes, types: bytes) -> None:
                self.m = {
                    "cellSize": 10, "width": 20, "height": 12,
                    "type": base64.b64encode(types).decode(),
                    "heightField": {"data": base64.b64encode(heights).decode()},
                }  # fmt: skip

            def call(self, path: str, body: Any = None) -> Any:
                return self.m

        flat = bytes(240)
        x, y = G(flat, bytes(240)).clear_strip(100, width=40)
        self.assertTrue(0 <= x < 200 and 0 <= y < 120)
        with self.assertRaises(RuntimeError):
            G(flat, bytes([1]) * 240).clear_strip(100, width=40)


class Processes(unittest.TestCase):
    def test_stop_group_returns_for_a_child_that_dies_on_sigterm(self) -> None:
        proc = subprocess.Popen(
            ["sleep", "30"], start_new_session=True
        )  # unreaped zombie: killpg(0) raises EPERM on macOS
        parity.stop_group(proc.pid)
        proc.wait(timeout=5)

    def test_stop_group_returns_for_a_dead_group(self) -> None:
        proc = subprocess.Popen(["true"], start_new_session=True)
        proc.wait()
        parity.stop_group(proc.pid)

    def test_kill_run_kills_the_recorded_sweep_parent_and_clears_pidfiles(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            pids = Path(d) / "pids"
            pids.mkdir()
            proc = subprocess.Popen(
                ["python3", "-c", "import time; time.sleep(30)", "parity.py"]
            )  # command line must name parity.py
            (pids / str(proc.pid)).write_text("sweep-parent")
            parity.kill_run(Path(d))
            self.assertEqual(proc.wait(timeout=5), -signal.SIGKILL)
            self.assertEqual(list(pids.glob("*")), [])

    def test_kill_run_spares_a_foreign_pid(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            pids = Path(d) / "pids"
            pids.mkdir()
            proc = subprocess.Popen(["sleep", "30"], start_new_session=True)
            (pids / str(proc.pid)).write_text("game")
            parity.kill_run(Path(d))
            self.assertIsNone(proc.poll())
            proc.kill()
            proc.wait()


if __name__ == "__main__":
    unittest.main()
