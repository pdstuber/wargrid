import contextlib
import csv
import io
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))

import perf_chart
import perf_record

HEADLESS_LOG = """\
HEADLESS open tick_ms={"max":3.443,"n":1800,"p50":0.634,"p95":0.707,"p99":0.832} command_tick_ms={"max":3.6,"n":2,"p50":3.443,"p95":3.6,"p99":3.6} queue_peak=292 queue_drain_ticks=38 timed_counts={"arrived":0,"blocked":0,"moving":300,"path_pending":0} completed_legs=2 drain_ticks=231 final_counts={"arrived":300,"blocked":0,"moving":0,"path_pending":0} unique_destinations=300
HEADLESS dense tick_ms={"max":3.471,"n":1800,"p50":0.642,"p95":0.691,"p99":0.893} command_tick_ms={"max":3.471,"n":2,"p50":3.455,"p95":3.471,"p99":3.471} queue_peak=292 queue_drain_ticks=38 timed_counts={"arrived":0,"blocked":0,"moving":300,"path_pending":0} completed_legs=2 drain_ticks=269 final_counts={"arrived":300,"blocked":0,"moving":0,"path_pending":0} unique_destinations=300
BENCHMARK PASSED 2
COMBAT open tick_ms={"max":2.951,"n":1800,"p50":1.221,"p95":1.866,"p99":2.214} warmup_tick_ms={"max":4.644,"n":300,"p50":1.331,"p95":1.409,"p99":1.523} snapshot_ms={"max":1.046,"n":1800,"p50":0.472,"p95":0.852,"p99":0.872} combat_work={"max":8898.0,"n":1800,"p50":193.0,"p95":1381.0,"p99":3585.0} allocation_calls={"max":0.0,"n":1800,"p50":0.0,"p95":0.0,"p99":0.0} shots=5035 deaths=176 first_shot=297 alive_start=300 alive_end=124 scan_chases_warmup=0 scan_chases_window=1425 retaliations_window=4
COMBAT dense tick_ms={"max":3.108,"n":1800,"p50":1.023,"p95":1.805,"p99":2.094} warmup_tick_ms={"max":4.585,"n":300,"p50":1.328,"p95":1.472,"p99":1.704} snapshot_ms={"max":0.973,"n":1800,"p50":0.383,"p95":0.809,"p99":0.86} combat_work={"max":11298.0,"n":1800,"p50":116.0,"p95":1522.0,"p99":4356.0} allocation_calls={"max":0.0,"n":1800,"p50":0.0,"p95":0.0,"p99":0.0} shots=5585 deaths=203 first_shot=271 alive_start=300 alive_end=97 scan_chases_warmup=0 scan_chases_window=1608 retaliations_window=0
COMBAT TRANSPORTS passenger_shots_window=335 passengers=100
COMBAT HORDES300 checks_window=17689 level2_peak_window=288
COMBAT BENCHMARK PASSED 10
LOCKSTEP overhead_ms={"max":0.162,"n":1800,"p50":0.009,"p95":0.016,"p99":0.07} snapshot_ms_on_hash_ticks={"max":0.541,"n":60,"p50":0.127,"p95":0.492,"p99":0.541} hash_ticks=60 busy_30_tick_windows=60 alive_end=30
LOCKSTEP BENCHMARK PASSED 1
"""

RENDERED_PROFILE_LOG = """\
RENDERED SAMPLE ashfall wall_seconds=60.000078 physics_ticks=1800 tick_ms={"max":5.201,"n":1800,"p50":1.591,"p95":1.868,"p99":2.083} frame_interval_ms={"max":11.011,"n":69921,"p50":0.746,"p95":2.317,"p99":3.672} command_tick_ms={"max":5.486,"n":2,"p50":5.201,"p95":5.486,"p99":5.486} draw_calls={"max":45.0,"n":69921,"p50":45.0,"p95":45.0,"p99":45.0}
PROFILE rendered_ashfall zone=draw mean_ms=1.1166 share=100.0% p50=1.1400 p95=1.1620 max=1.196 calls_per_tick=1.00
PROFILE rendered_ashfall zone=draw.units mean_ms=1.0411 share=93.2% p50=1.0650 p95=1.0860 max=1.114 calls_per_tick=1.00
PROFILE rendered_ashfall zone=snapshot mean_ms=0.7354 share=65.9% p50=0.7460 p95=0.7910 max=2.205 calls_per_tick=1.00
PROFILE rendered_ashfall zone=step mean_ms=0.4936 share=44.2% p50=0.5790 p95=0.7970 max=2.367 calls_per_tick=1.00
PROFILE rendered_ashfall zone=view.copy mean_ms=0.0830 share=7.4% p50=0.0840 p95=0.1120 max=0.187 calls_per_tick=1.00
PROFILE rendered_ashfall zone=view.sort mean_ms=0.0525 share=4.7% p50=0.0520 p95=0.0560 max=0.065 calls_per_tick=1.00
RENDERED BENCHMARK PASSED 4
"""

HEADLESS_P95_OPEN = 0.707
LOCKSTEP_P99 = 0.07


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def row(**kw: str) -> dict[str, str]:
    base = {c: "" for c in perf_record.COLUMNS}
    base.update(date="2026-11-09", label="L", machine="dev", run="1", method="P1", load="1.0")
    base.update(kw)
    return base


def mv(label: str, p95: str, **kw: str) -> dict[str, str]:
    return row(label=label, metric="movement_tick", scenario="open", p95_ms=p95, **kw)


class PerfChartTest(unittest.TestCase):
    def test_worst_over_runs(self) -> None:
        rows = [mv("a", v, run=str(i + 1)) for i, v in enumerate(["1.0", "1.1", "1.5"])]
        (point,) = perf_chart.series(rows, perf_chart.LINES[0])
        self.assertAlmostEqual(point.worst_pct, 82.4, delta=0.1)

    def summary(self, rows: list[dict[str, str]], prefix: str = "movement p95") -> str:
        return next(s for s in perf_chart.summary_lines(rows) if s.startswith(prefix))

    def test_summary_worst_vs_worst(self) -> None:
        rows = [
            mv("a", "1.00", date="2026-11-01", run="1"),
            mv("a", "0.50", date="2026-11-01", run="2"),
            mv("b", "1.10", date="2026-11-02"),
        ]
        text = self.summary(rows)
        self.assertIn("(b, 2026-11-02), 10% slower than a (worst vs worst); run-to-run spread up to 50%", text)
        self.assertNotIn("noise", text)

    def test_summary_unchanged(self) -> None:
        rows = [mv("a", "1.00", date="2026-11-01"), mv("b", "1.001", date="2026-11-02")]
        self.assertIn("unchanged vs a (worst vs worst)", self.summary(rows))

    def test_summary_rounding_never_hides_exceeded(self) -> None:
        text = self.summary([mv("a", "1.8135")])
        self.assertIn("99% of budget (a, 2026-11-09)", text)
        self.assertNotIn("exceeded", text)
        self.assertIn("100% of budget, exceeded (a, 2026-11-09)", self.summary([mv("a", "1.82")]))

    def test_summary_exceeded(self) -> None:
        self.assertIn("120% of budget, exceeded (a, 2026-11-09)", self.summary([mv("a", "2.184")]))

    def test_summary_without_previous(self) -> None:
        self.assertIn("no previous run", self.summary([mv("a", "1.0")]))

    def test_summary_epoch_change(self) -> None:
        rows = [mv("a", "1.0", date="2026-11-01", method="pre-P1"), mv("b", "1.0", date="2026-11-02")]
        self.assertIn("not comparable (method pre-P1 \u2192 P1)", self.summary(rows))

    def test_summary_skips_label_without_metric(self) -> None:
        gap = row(label="b", date="2026-11-02", metric="plumbing", scenario="horde:profile", mean_ms="0.5")
        rows = [mv("a", "1.00", date="2026-11-01"), gap, mv("c", "1.10", date="2026-11-03")]
        self.assertEqual(
            self.summary(rows),
            "movement p95: 60% of budget (c, 2026-11-03), 10% slower than a (worst vs worst); run-to-run spread up to 50%",
        )
        rows[0] = mv("a", "1.00", date="2026-11-01", method="pre-P1")
        self.assertIn("not comparable (method pre-P1 \u2192 P1)", self.summary(rows))

    def test_summary_noise_not_measured_and_busy(self) -> None:
        rows = [
            row(label="a", date="2026-11-01", metric="plumbing", scenario="horde:profile", mean_ms="0.91"),
            row(label="b", date="2026-11-02", metric="plumbing", scenario="horde:profile", mean_ms="0.91", load="3.1"),
        ]
        text = self.summary(rows, "plumbing, horde")
        self.assertIn("run-to-run spread not measured", text)
        self.assertTrue(text.endswith("busy host (load 3.1)"))

    def test_busy_only_from_rows_feeding_the_line(self) -> None:
        calm = mv("a", "1.0", load="1.0")
        busy_rendered = row(label="a", metric="frame_interval", scenario="open", p95_ms="3.0", load="4.0")
        rows = [calm, busy_rendered]
        self.assertNotIn("busy", self.summary(rows))
        self.assertNotIn("busy host", self.table_row(rows, "Unit movement"))
        self.assertIn("busy host (load 4.0)", self.summary(rows, "rendered tick-frame p95"))

    def test_table_shows_row_date(self) -> None:
        old = self.table_row([mv("a", "1.0", date="2026-10-01")], "Unit movement")
        self.assertTrue(old.endswith("| 2026-10-01 |"))
        self.assertIn("(a, 2026-10-01)", self.summary([mv("a", "1.0", date="2026-10-01")]))

    def make_docs(self, tmp: str, ledger: str, readme: str, data: list[dict[str, str]] | None = None) -> list[str]:
        d = Path(tmp)
        (d / "l.md").write_text(ledger)
        (d / "r.md").write_text(readme)
        with (d / "h.csv").open("w", newline="") as handle:
            w = csv.DictWriter(handle, perf_record.COLUMNS)
            w.writeheader()
            w.writerows(data or [mv("a", "1.0")])
        return [
            "--csv",
            str(d / "h.csv"),
            "--ledger",
            str(d / "l.md"),
            "--readme",
            str(d / "r.md"),
        ]

    def test_ledger_markers_required(self) -> None:
        for bad in (f"x\n{perf_chart.BEGIN}\n", f"{perf_chart.BEGIN}{perf_chart.BEGIN}{perf_chart.END}", ""):
            with self.assertRaises(ValueError):
                perf_chart.update_ledger(bad, "B")
        readme = f"{perf_chart.PT_BEGIN}\n{perf_chart.PT_END}\n"
        with tempfile.TemporaryDirectory() as tmp:
            args = self.make_docs(tmp, f"head\n{perf_chart.BEGIN}\n", readme)
            self.assertEqual(perf_chart.main(args), 1)
            self.assertEqual((Path(tmp) / "l.md").read_text(), f"head\n{perf_chart.BEGIN}\n")
            self.assertEqual((Path(tmp) / "r.md").read_text(), readme)

    def test_missing_readme_marker_leaves_ledger_untouched(self) -> None:
        good = f"{perf_chart.BEGIN}\n{perf_chart.END}\n"
        with tempfile.TemporaryDirectory() as tmp:
            args = self.make_docs(tmp, good, "no markers\n")
            self.assertEqual(perf_chart.main(args), 1)
            self.assertEqual((Path(tmp) / "l.md").read_text(), good)
            self.assertEqual((Path(tmp) / "r.md").read_text(), "no markers\n")

    def test_ledger_block_replaced_idempotent(self) -> None:
        text = f"top\n{perf_chart.BEGIN}\nold\n{perf_chart.END}\nbottom\n"
        once = perf_chart.update_ledger(text, "new")
        self.assertEqual(once, f"top\n{perf_chart.BEGIN}\nnew\n{perf_chart.END}\nbottom\n")
        self.assertEqual(perf_chart.update_ledger(once, "new"), once)

    def test_main_writes_both_blocks_idempotent(self) -> None:
        good = f"{perf_chart.BEGIN}\n{perf_chart.END}\n"
        readme = f"top\n{perf_chart.PT_BEGIN}\n{perf_chart.PT_END}\nbottom\n"
        with tempfile.TemporaryDirectory() as tmp:
            args = self.make_docs(tmp, good, readme)
            self.assertEqual(perf_chart.main(args), 0)
            ledger_text, readme_text = (Path(tmp) / "l.md").read_text(), (Path(tmp) / "r.md").read_text()
            self.assertIn("| Unit movement |", ledger_text)
            self.assertIn("Details:", ledger_text)
            self.assertIn("movement p95:", ledger_text)
            self.assertIn("Performance against the low-end budget (generated):", readme_text)
            self.assertIn("| Unit movement |", readme_text)
            self.assertTrue(readme_text.startswith("top\n") and readme_text.endswith("bottom\n"))
            self.assertEqual(perf_chart.main(args), 0)
            self.assertEqual((Path(tmp) / "l.md").read_text(), ledger_text)
            self.assertEqual((Path(tmp) / "r.md").read_text(), readme_text)

    def table_row(self, rows: list[dict[str, str]], name: str) -> str:
        return next(
            r
            for r in perf_chart.status_table(rows).splitlines()
            if r.startswith(f"| {name} |") or r.startswith(f"| **{name}** |")
        )

    def test_table_headline_and_sort(self) -> None:
        rows = [mv("a", "1.0"), row(label="a", metric="combat_tick", scenario="contact", p95_ms="2.0")]
        lines = perf_chart.status_table(rows).splitlines()
        self.assertEqual(lines[0], "**1 of 2 areas over budget**")
        self.assertEqual(lines[2], "| Area | Status | Budget used | vs last run | As of |")
        self.assertTrue(lines[4].startswith("| **Combat, normal fights** |"))
        self.assertTrue(lines[5].startswith("| Unit movement |"))
        self.assertEqual(perf_chart.status_table([mv("a", "1.0")]).splitlines()[0], "**Nothing over budget**")
        self.assertIn(perf_chart.CAPTION, perf_chart.status_table(rows))

    def test_table_over_close_ok_rows(self) -> None:
        over = self.table_row([mv("a", "2.73")], "Unit movement")
        self.assertEqual(
            over,
            "| **Unit movement** | \U0001f534 Over | \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u25b6 150% | \U0001f195 first run | 2026-11-09 |",
        )
        close = self.table_row([mv("a", "1.7")], "Unit movement")
        self.assertEqual(
            close,
            "| Unit movement | \U0001f7e1 Close | \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2591 93% | \U0001f195 first run | 2026-11-09 |",
        )
        ok = self.table_row([mv("a", "1.13")], "Unit movement")
        self.assertEqual(
            ok,
            "| Unit movement | \U0001f7e2 OK | \u2588\u2588\u2588\u2588\u2588\u2588\u2591\u2591\u2591\u2591 62% | \U0001f195 first run | 2026-11-09 |",
        )

    def test_table_exceeded_never_shown_below_100(self) -> None:
        self.assertIn("\u25b6 100%", self.table_row([mv("a", "1.82")], "Unit movement"))
        self.assertIn("\u2591 99%", self.table_row([mv("a", "1.8135")], "Unit movement"))

    def test_table_85_boundary(self) -> None:
        self.assertIn("Close", self.table_row([mv("a", "1.547")], "Unit movement"))
        self.assertIn("OK", self.table_row([mv("a", "1.5")], "Unit movement"))

    def test_table_vs_last_run(self) -> None:
        def vs(prev: str, latest: str, **kw: str) -> str:
            rows = [mv("a", prev, date="2026-11-01", **kw), mv("b", latest, date="2026-11-02")]
            return self.table_row(rows, "Unit movement").split(" | ")[-2]

        self.assertEqual(vs("1.0", "1.08"), "\U0001f53a 8% worse")
        self.assertEqual(vs("1.0", "0.99"), "\U0001f53b 1% better")
        self.assertEqual(vs("1.0", "1.001"), "\u2796 same")
        self.assertEqual(vs("1.0", "1.0", method="pre-P1"), "\u26a0\ufe0f method changed")

    def test_area_prefers_tick_frame_within_a_label(self) -> None:
        rows = [
            row(label="lab", metric="tick_frame", scenario="open", p95_ms="2.9", method="tick-frame"),
            row(label="lab", metric="frame_interval", scenario="open", p95_ms="0.6", method="tick-frame"),
        ]
        line = next(x for x in perf_chart.LINES if x.name == "Drawing the screen")
        (point,) = perf_chart.series(rows, line)
        self.assertAlmostEqual(point.worst_pct, 2.9 / 3.04 * 100)

    def test_switch_to_tick_frame_reads_as_method_change(self) -> None:
        rows = [
            row(label="a", date="2026-11-01", metric="frame_interval", scenario="open", p95_ms="0.6", method="post-P1"),
            row(label="b", date="2026-11-02", metric="tick_frame", scenario="open", p95_ms="2.9", method="tick-frame"),
        ]
        table = perf_chart.status_table(rows)
        self.assertIn("method changed", next(x for x in table.splitlines() if "Drawing the screen" in x))

    def test_zero_previous_counts_as_new(self) -> None:
        rows = [mv("a", "0", date="2026-11-01"), mv("b", "1.0", date="2026-11-02")]
        self.assertIn("\U0001f195 first run", self.table_row(rows, "Unit movement"))
        self.assertIn("no previous run", next(x for x in perf_chart.summary_lines(rows)))

    def test_replaced_files_keep_mode(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            args = self.make_docs(
                tmp, f"{perf_chart.BEGIN}\n{perf_chart.END}\n", f"{perf_chart.PT_BEGIN}\n{perf_chart.PT_END}\n"
            )
            for name in ("l.md", "r.md"):
                (Path(tmp) / name).chmod(0o644)
            self.assertEqual(perf_chart.main(args), 0)
            for name in ("l.md", "r.md"):
                self.assertEqual((Path(tmp) / name).stat().st_mode & 0o777, 0o644)

    def test_failed_write_leaves_both_files(self) -> None:
        good, readme = f"{perf_chart.BEGIN}\n{perf_chart.END}\n", f"{perf_chart.PT_BEGIN}\n{perf_chart.PT_END}\n"
        with tempfile.TemporaryDirectory() as tmp:
            args = self.make_docs(tmp, good, readme)
            with mock.patch.object(perf_chart.os, "replace", side_effect=OSError("boom")), self.assertRaises(OSError):
                perf_chart.main(args)
            self.assertEqual((Path(tmp) / "l.md").read_text(), good)
            self.assertEqual((Path(tmp) / "r.md").read_text(), readme)
            self.assertEqual(sorted(p.name for p in Path(tmp).iterdir()), ["h.csv", "l.md", "r.md"])

    def test_table_busy_suffix(self) -> None:
        busy = self.table_row([mv("a", "1.0", load="3.1")], "Unit movement")
        self.assertTrue(busy.endswith("\U0001f195 first run (busy host) | 2026-11-09 |"))


class PerfRecordTest(unittest.TestCase):
    def setUp(self) -> None:
        self._dir = tempfile.TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.dir = Path(self._dir.name)
        self.csv = self.dir / "history.csv"

    def write_log(self, name: str, text: str) -> Path:
        path = self.dir / name
        path.write_text(text)
        return path

    def record(self, log: Path, *extra: str) -> int:
        return perf_record.main([str(log), "--label", "T", "--csv", str(self.csv), *extra])

    def test_parse_headless_log(self) -> None:
        s = {(x.metric, x.scenario): x for x in perf_record.parse_log(HEADLESS_LOG)}
        self.assertEqual(s["movement_tick", "open"].p95_ms, HEADLESS_P95_OPEN)
        self.assertEqual(s["lockstep_overhead", "contact"].p99_ms, LOCKSTEP_P99)
        self.assertIn(("combat_tick", "dense"), s)
        self.assertNotIn(("combat_tick", "TRANSPORTS"), s)
        self.assertNotIn(("combat_tick", "HORDES300"), s)

    def test_profiled_rendered_rows_suffixed(self) -> None:
        s = {(x.metric, x.scenario): x for x in perf_record.parse_log(RENDERED_PROFILE_LOG)}
        self.assertIn(("frame_interval", "ashfall:profile"), s)
        self.assertIn(("tick_frame", "ashfall:profile"), s)
        self.assertNotIn(("tick_frame", "ashfall"), s)
        self.assertAlmostEqual(s["plumbing", "ashfall:profile"].mean_ms or 0, 0.7354 + 0.0830 + 0.0525)
        self.assertIsNone(s["plumbing", "ashfall:profile"].p95_ms)
        self.assertEqual(s["step", "ashfall:profile"].mean_ms, 0.4936)
        self.assertEqual(s["draw", "ashfall:profile"].mean_ms, 1.1166)  # not draw.units 1.0411

    def test_unprofiled_rendered_rows_plain(self) -> None:
        lines = [x for x in RENDERED_PROFILE_LOG.splitlines() if not x.startswith("PROFILE")]
        s = {(x.metric, x.scenario) for x in perf_record.parse_log("\n".join(lines))}
        self.assertEqual(s, {("frame_interval", "ashfall"), ("tick_frame", "ashfall")})

    def test_rendered_sample_records_tick_frame(self) -> None:
        line = (
            'RENDERED SAMPLE open wall_seconds=60.0 physics_ticks=1800 tick_ms={"max":4.0,"n":1800,"p50":1.0,'
            '"p95":2.9,"p99":3.5} frame_interval_ms={"max":9.0,"n":6000,"p50":0.3,"p95":0.6,"p99":1.2}\n'
        )
        log = line + "RENDERED BENCHMARK PASSED 4\n"
        s = {(x.metric, x.scenario): x for x in perf_record.parse_log(log)}
        self.assertEqual(s["tick_frame", "open"], perf_record.Sample("tick_frame", "open", 2.9, 3.5, None))
        self.assertEqual(s["frame_interval", "open"].p95_ms, 0.6)

    def test_tick_frame_rows_get_their_own_method(self) -> None:
        log = RENDERED_PROFILE_LOG
        self.assertEqual(self.record(self.write_log("h.log", HEADLESS_LOG), "--method", "P1"), 0)
        self.assertEqual(self.record(self.write_log("a.log", log)), 0)
        by_metric = {r["metric"]: r["method"] for r in read_rows(self.csv)}
        self.assertEqual(by_metric["tick_frame"], "tick-frame")
        self.assertEqual({by_metric["frame_interval"], by_metric["plumbing"]}, {"P1"})
        self.assertEqual(self.record(self.write_log("b.log", log.replace("1.868", "1.9"))), 0)
        self.assertEqual({r["method"] for r in read_rows(self.csv) if r["metric"] != "tick_frame"}, {"P1"})

    def test_explicit_method_also_marks_tick_frame_rows(self) -> None:
        log = RENDERED_PROFILE_LOG
        self.assertEqual(self.record(self.write_log("a.log", log), "--method", "P9"), 0)
        self.assertEqual(self.record(self.write_log("b.log", log.replace("1.868", "1.9"))), 0)
        self.assertEqual({r["method"] for r in read_rows(self.csv)}, {"P9"})

    def test_current_main_log_lines_parse(self) -> None:
        extra = (
            "WORST TICK tests open ms=3.443 tick=412\n"
            "OVER BUDGET dense p95=2.000 p99=3.000 budget=1.82/3.64\n"
            "BUDGET EXCEEDED dense (regression ceilings held)\n"
        )
        lines = HEADLESS_LOG.splitlines(keepends=True)
        log = "".join(lines[:2]) + extra + "".join(lines[2:])
        s = {(x.metric, x.scenario) for x in perf_record.parse_log(log)}
        self.assertEqual(s, {x[:2] for x in perf_record.parse_log(HEADLESS_LOG)})

    def test_incomplete_log_refused(self) -> None:
        truncated = HEADLESS_LOG.replace("COMBAT BENCHMARK PASSED 10\n", "")
        with self.assertRaisesRegex(ValueError, "COMBAT BENCHMARK PASSED 10"):
            perf_record.parse_log(truncated)
        with self.assertRaisesRegex(ValueError, "ERROR: x"):
            perf_record.parse_log(HEADLESS_LOG + "ERROR: x\n")
        self.assertEqual(self.record(self.write_log("t.log", truncated), "--method", "P1"), 1)
        self.assertFalse(self.csv.exists())
        godot = HEADLESS_LOG + "SCRIPT ERROR: Parse Error: y\n"
        with self.assertRaisesRegex(ValueError, "SCRIPT ERROR: Parse Error: y"):
            perf_record.parse_log(godot)
        self.assertEqual(self.record(self.write_log("g.log", godot), "--method", "P1"), 1)
        self.assertFalse(self.csv.exists())

    def test_record_appends_with_load_and_run(self) -> None:
        other = HEADLESS_LOG.replace("0.707", "0.708")
        self.assertEqual(self.record(self.write_log("a.log", HEADLESS_LOG), "--method", "P1"), 0)
        self.assertEqual(self.record(self.write_log("b.log", other)), 0)
        rows = read_rows(self.csv)
        self.assertEqual(sorted({r["run"] for r in rows}), ["1", "2"])
        self.assertEqual(rows[0]["date"], perf_record.today())
        self.assertEqual(list(rows[0]), list(perf_record.COLUMNS))
        float(rows[0]["load"])
        self.assertTrue(rows[0]["commit"])
        self.assertTrue(rows[0]["source"].startswith("log sha256:"))
        self.assertEqual({r["method"] for r in rows}, {"P1"})

    def test_duplicate_log_refused(self) -> None:
        log = self.write_log("a.log", HEADLESS_LOG)
        self.assertEqual(self.record(log, "--method", "P1"), 0)
        count = len(read_rows(self.csv))
        self.assertEqual(self.record(log), 1)
        self.assertEqual(len(read_rows(self.csv)), count)

    def test_method_defaults_to_last_row(self) -> None:
        self.assertEqual(self.record(self.write_log("a.log", HEADLESS_LOG)), 1)
        self.assertFalse(self.csv.exists())
        self.assertEqual(self.record(self.write_log("b.log", HEADLESS_LOG), "--method", "P1"), 0)
        self.assertEqual(self.record(self.write_log("c.log", HEADLESS_LOG.replace("0.707", "0.7"))), 0)
        self.assertEqual({r["method"] for r in read_rows(self.csv)}, {"P1"})

    def test_next_run_is_per_label_and_machine(self) -> None:
        rows = [{"label": "T", "machine": "dev", "run": "2"}, {"label": "U", "machine": "dev", "run": "5"}]
        self.assertEqual(perf_record.next_run(rows, "T", "dev"), 3)
        self.assertEqual(perf_record.next_run(rows, "T", "deck"), 1)


def _git_repo(path: Path) -> None:
    def git(*args: str) -> None:
        env = {
            **os.environ,
            "GIT_AUTHOR_NAME": "t",
            "GIT_AUTHOR_EMAIL": "t@t",
            "GIT_COMMITTER_NAME": "t",
            "GIT_COMMITTER_EMAIL": "t@t",
        }
        subprocess.run(["git", *args], cwd=path, env=env, capture_output=True, check=True)

    git("init", "-q", "-b", "main")
    git("add", ".")
    git("commit", "-qm", "init")


class AutoRecordTest(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.repo = Path(tmp.name)
        self.csv = self.repo / "docs" / "reference" / "perf-history.csv"
        self.csv.parent.mkdir(parents=True)
        with self.csv.open("w", newline="") as handle:
            writer = csv.DictWriter(handle, perf_record.COLUMNS, lineterminator="\n")
            writer.writeheader()
            writer.writerow(row(label="seed", metric="movement_tick", scenario="open", p95_ms="1.0", source="seed"))
        (self.repo / "README.md").write_text("r")
        (self.repo / "docs" / "reference" / "performance.md").write_text("p")
        self.log = self.repo.parent / f"{self.repo.name}.log"
        self.log.write_text(HEADLESS_LOG)
        self.addCleanup(self.log.unlink)
        _git_repo(self.repo)
        other = tempfile.TemporaryDirectory()
        self.addCleanup(other.cleanup)
        cwd = os.getcwd()
        os.chdir(other.name)
        self.addCleanup(os.chdir, cwd)
        patch = mock.patch.object(perf_record, "REPO", self.repo)
        patch.start()
        self.addCleanup(patch.stop)

    def auto(self, *extra: str) -> tuple[int, str]:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = perf_record.main([str(self.log), "--auto", "--csv", str(self.csv), *extra])
        return code, out.getvalue()

    def labels(self) -> set[str]:
        return {r["label"] for r in read_rows(self.csv)}

    def test_records_on_clean_main_with_auto_label(self) -> None:
        self.assertEqual(self.auto()[0], 0)
        self.assertEqual(len([x for x in self.labels() if x.startswith("auto ")]), 1)

    def test_skips_off_main(self) -> None:
        subprocess.run(["git", "checkout", "-qb", "spike-x"], cwd=self.repo, check=True)
        code, out = self.auto()
        self.assertEqual((code, out), (0, "perf: not recording (branch spike-x, tree clean)\n"))
        self.assertEqual(self.labels(), {"seed"})

    def test_skips_detached_head(self) -> None:
        subprocess.run(["git", "checkout", "-q", "--detach"], cwd=self.repo, check=True)
        code, out = self.auto()
        self.assertEqual((code, out), (0, "perf: not recording (branch HEAD, tree clean)\n"))
        self.assertEqual(self.labels(), {"seed"})

    def test_skips_dirty_main(self) -> None:
        (self.repo / "stray.txt").write_text("x")
        code, out = self.auto()
        self.assertEqual((code, out), (0, "perf: not recording (branch main, tree dirty)\n"))
        self.assertEqual(self.labels(), {"seed"})

    def test_generated_files_do_not_make_tree_dirty(self) -> None:
        (self.repo / "README.md").write_text("changed")
        (self.repo / "docs" / "reference" / "performance.md").write_text("changed")
        self.assertEqual(self.auto()[0], 0)
        self.assertEqual(len(self.labels()), 2)

    def test_label_forces_record_off_main(self) -> None:
        subprocess.run(["git", "checkout", "-qb", "spike-x"], cwd=self.repo, check=True)
        self.assertEqual(self.auto("--label", "M9 gate")[0], 0)
        self.assertIn("M9 gate", self.labels())

    def test_label_or_auto_required(self) -> None:
        with self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
            perf_record.main([str(self.log), "--csv", str(self.csv)])

    def test_real_error_exits_one(self) -> None:
        self.assertEqual(self.auto("--label", "dup")[0], 0)
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(self.auto("--label", "dup")[0], 1)


STUB_GODOT = """#!/bin/sh
case "$*" in
*run_movement*) cat "$STUB_DIR/movement.out" ;;
*run_combat*) cat "$STUB_DIR/combat.out" ;;
*run_lockstep*) cat "$STUB_DIR/lockstep.out" ;;
esac
exit 0
"""


def _stub_outputs() -> dict[str, str]:
    head, rest = HEADLESS_LOG.split("COMBAT open", 1)
    combat, lock = ("COMBAT open" + rest).split("LOCKSTEP overhead_ms", 1)
    return {
        "movement": head + "BUDGET PASS a\nBUDGET PASS b\n" + "WORST TICK movement open ms=1.000 tick=1\n" * 2,
        "combat": combat + "COMBAT BUDGET PASS x\n" * 7 + "WORST TICK combat open ms=1.000 tick=1\n" * 10,
        "lockstep": "LOCKSTEP overhead_ms"
        + lock
        + "LOCKSTEP BUDGET PASS y\n"
        + "WORST TICK lockstep contact ms=1.000 tick=1\n",
    }


class RunBenchmarkTest(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.repo = Path(tmp.name) / "repo"
        tools = Path(__file__).parent
        (self.repo / "tools").mkdir(parents=True)
        (self.repo / "game").mkdir()
        (self.repo / "game" / ".keep").write_text("")
        for name in ("run_benchmark.sh", "perf_record.py", "perf_chart.py"):
            shutil.copy(tools / name, self.repo / "tools" / name)
        ref = self.repo / "docs" / "reference"
        ref.mkdir(parents=True)
        # Fixtures, not the real files: an edit to README or the ledger must never fail CI.
        (ref / "performance.md").write_text(f"# Ledger\n\n{perf_chart.BEGIN}\n{perf_chart.END}\n\nProse.\n")
        (self.repo / "README.md").write_text(f"# Readme\n\n{perf_chart.PT_BEGIN}\n{perf_chart.PT_END}\n")
        self.csv = ref / "perf-history.csv"
        with self.csv.open("w", newline="") as handle:
            writer = csv.DictWriter(handle, perf_record.COLUMNS, lineterminator="\n")
            writer.writeheader()
            writer.writerow(row(label="seed", metric="movement_tick", scenario="open", p95_ms="1.0", source="seed"))
        self.stub = Path(tmp.name) / "stub"
        self.stub.mkdir()
        for name, text in _stub_outputs().items():
            (self.stub / f"{name}.out").write_text(text)
        godot = self.stub / "godot"
        godot.write_text(STUB_GODOT)
        godot.chmod(0o755)
        _git_repo(self.repo)

    def run_script(self, **env: str) -> subprocess.CompletedProcess[str]:
        full = {k: v for k, v in os.environ.items() if not k.startswith("PERF_")}
        full |= {"GODOT_BIN": str(self.stub / "godot"), "STUB_DIR": str(self.stub), **env}
        return subprocess.run(
            ["sh", "tools/run_benchmark.sh"], check=False, cwd=self.repo, env=full, capture_output=True, text=True
        )

    def test_records_and_regenerates_tables_on_clean_main(self) -> None:
        readme = self.repo / "README.md"
        before = readme.read_bytes()
        self.assertEqual(self.run_script().returncode, 0)
        auto = [r for r in read_rows(self.csv) if r["label"].startswith("auto ")]
        self.assertEqual(len(auto), 5)
        self.assertNotEqual(readme.read_bytes(), before)

    def test_off_main_run_still_regenerates_tables(self) -> None:
        subprocess.run(["git", "checkout", "-qb", "spike-x"], cwd=self.repo, check=True)
        readme = self.repo / "README.md"
        before = readme.read_bytes()
        result = self.run_script()
        self.assertEqual(result.returncode, 0)
        self.assertIn("not recording", result.stdout)
        self.assertEqual({r["label"] for r in read_rows(self.csv)}, {"seed"})
        self.assertNotEqual(readme.read_bytes(), before)

    def test_chart_failure_after_record_is_warning_only(self) -> None:
        readme = self.repo / "README.md"
        readme.write_text("no markers\n")
        result = self.run_script(PERF_LABEL="m")
        self.assertEqual(result.returncode, 0)
        self.assertIn("perf: WARNING", result.stdout)
        self.assertIn("m", {r["label"] for r in read_rows(self.csv)})

    def test_perf_label_passed_through(self) -> None:
        subprocess.run(["git", "checkout", "-qb", "spike-x"], cwd=self.repo, check=True)
        self.assertEqual(self.run_script(PERF_LABEL="M9 gate").returncode, 0)
        self.assertIn("M9 gate", {r["label"] for r in read_rows(self.csv)})

    def test_disabled_record_leaves_csv_and_status(self) -> None:
        before = self.csv.read_bytes()
        self.assertEqual(self.run_script(PERF_RECORD="0", PERF_LABEL="x").returncode, 0)
        self.assertEqual(self.csv.read_bytes(), before)

    def test_recorder_failure_does_not_fail_gate(self) -> None:
        self.assertEqual(self.run_script(PERF_LABEL="dup").returncode, 0)
        result = self.run_script(PERF_LABEL="dup")
        self.assertEqual(result.returncode, 0)
        self.assertIn("perf: WARNING", result.stdout)

    def test_missing_worst_tick_line_still_fails_the_gate(self) -> None:
        lockstep = self.stub / "lockstep.out"
        lockstep.write_text(lockstep.read_text().replace("WORST TICK lockstep contact ms=1.000 tick=1\n", ""))
        before = self.csv.read_bytes()
        self.assertNotEqual(self.run_script(PERF_LABEL="x").returncode, 0)
        self.assertEqual(self.csv.read_bytes(), before)

    def test_failed_benchmark_never_records(self) -> None:
        (self.stub / "combat.out").write_text("ERROR: boom\n")
        before = self.csv.read_bytes()
        self.assertNotEqual(self.run_script(PERF_LABEL="x").returncode, 0)
        self.assertEqual(self.csv.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
