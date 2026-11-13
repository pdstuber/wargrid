"""Append one benchmark log's timings to docs/reference/perf-history.csv."""

import argparse
import csv
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import NamedTuple

COLUMNS = (
    "date",
    "commit",
    "label",
    "machine",
    "metric",
    "scenario",
    "run",
    "p95_ms",
    "p99_ms",
    "mean_ms",
    "method",
    "load",
    "source",
)
DEFAULT_CSV = Path(__file__).resolve().parent.parent / "docs" / "reference" / "perf-history.csv"

MARKERS = {
    "headless": "BENCHMARK PASSED 2",
    "combat": "COMBAT BENCHMARK PASSED 10",
    "lockstep": "LOCKSTEP BENCHMARK PASSED 1",
    "rendered": "RENDERED BENCHMARK PASSED 4",
}
HEADLESS = re.compile(r"^HEADLESS (\S+) tick_ms=(\{[^}]*\})", re.M)
COMBAT = re.compile(r"^COMBAT ([a-z0-9_]+) tick_ms=(\{[^}]*\})", re.M)
LOCKSTEP = re.compile(r"^LOCKSTEP overhead_ms=(\{[^}]*\})", re.M)
RENDERED = re.compile(r"^RENDERED SAMPLE (\S+) .*? tick_ms=(\{[^}]*\}).*? frame_interval_ms=(\{[^}]*\})", re.M)
PROFILE = re.compile(r"^PROFILE rendered_(\S+) zone=(\S+) mean_ms=([\d.]+)", re.M)
PLUMBING_ZONES = ("snapshot", "view.copy", "view.sort")
TICK_FRAME = "tick_frame"
TICK_FRAME_METHOD = "tick-frame"


class Sample(NamedTuple):
    metric: str
    scenario: str
    p95_ms: float | None
    p99_ms: float | None
    mean_ms: float | None


def _percentiles(metric: str, scenario: str, raw: str) -> Sample:
    d = json.loads(raw)
    return Sample(metric, scenario, d["p95"], d["p99"], None)


def _profile_samples(text: str) -> tuple[list[Sample], set[str]]:
    zones: dict[str, dict[str, float]] = {}
    for layout, zone, mean in PROFILE.findall(text):
        zones.setdefault(layout, {})[zone] = float(mean)
    out: list[Sample] = []
    for layout, z in zones.items():
        scenario = f"{layout}:profile"
        for metric, zone in (("step", "step"), ("draw", "draw")):
            if zone in z:
                out.append(Sample(metric, scenario, None, None, z[zone]))
        if all(k in z for k in PLUMBING_ZONES):
            out.append(Sample("plumbing", scenario, None, None, round(sum(z[k] for k in PLUMBING_ZONES), 4)))
    return out, set(zones)


def parse_log(text: str) -> list[Sample]:
    error = re.search(r"^.*ERROR:.*$", text, re.M)
    if error:
        raise ValueError(error.group(0))
    samples: list[Sample] = []
    found: set[str] = set()
    for name, raw in HEADLESS.findall(text):
        found.add("headless")
        samples.append(_percentiles("movement_tick", name, raw))
    for name, raw in COMBAT.findall(text):
        found.add("combat")
        samples.append(_percentiles("combat_tick", name, raw))
    for raw in LOCKSTEP.findall(text):
        found.add("lockstep")
        samples.append(_percentiles("lockstep_overhead", "contact", raw))
    profile, profiled = _profile_samples(text)
    for layout, tick_raw, frame_raw in RENDERED.findall(text):
        found.add("rendered")
        suffix = ":profile" if layout in profiled else ""
        samples.append(_percentiles("frame_interval", layout + suffix, frame_raw))
        samples.append(_percentiles(TICK_FRAME, layout + suffix, tick_raw))
    samples += profile
    if not found:
        raise ValueError("no benchmark samples found")
    for family in sorted(found):
        if not re.search(rf"^{re.escape(MARKERS[family])}\b", text, re.M):
            raise ValueError(f"missing marker: {MARKERS[family]}")
    return samples


def next_run(rows: list[dict[str, str]], label: str, machine: str) -> int:
    runs = [int(r["run"]) for r in rows if r["label"] == label and r["machine"] == machine]
    return max(runs, default=0) + 1


def log_source(text: str) -> str:
    return "log sha256:" + hashlib.sha256(text.encode()).hexdigest()[:12]


def today() -> str:
    return datetime.date.today().isoformat()


REPO = Path(__file__).resolve().parent.parent


def _git(*args: str) -> str:
    return subprocess.run(["git", "-C", str(REPO), *args], capture_output=True, text=True, check=True).stdout.strip()


GENERATED = (
    ":!docs/reference/perf-history.csv",
    ":!docs/reference/performance.md",
    ":!README.md",
)


def commit_id() -> str:
    dirty = _git("status", "--porcelain", "--", ".", *GENERATED)
    return _git("rev-parse", "--short", "HEAD") + ("+dirty" if dirty else "")


def auto_label() -> str | None:
    branch = _git("rev-parse", "--abbrev-ref", "HEAD")
    tree = "dirty" if _git("status", "--porcelain", "--", ".", *GENERATED) else "clean"
    if branch == "main" and tree == "clean":
        return f"auto {_git('rev-parse', '--short', 'HEAD')}"
    print(f"perf: not recording (branch {branch}, tree {tree})")
    return None


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def _cell(value: float | None) -> str:
    return "" if value is None else repr(value)


def _append(path: Path, rows: list[dict[str, str]]) -> None:
    fresh = not path.exists() or path.stat().st_size == 0
    with path.open("a", newline="") as handle:
        writer = csv.DictWriter(handle, COLUMNS, lineterminator="\n")
        if fresh:
            writer.writeheader()
        writer.writerows(rows)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("log", type=Path)
    ap.add_argument("--label")
    ap.add_argument("--auto", action="store_true", help="record on a clean main, or with --label; else skip")
    ap.add_argument("--machine", default="dev")
    ap.add_argument("--method")
    ap.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    args = ap.parse_args(argv)
    label = args.label
    if label is None:
        if not args.auto:
            ap.error("--label is required without --auto")
        label = auto_label()
        if label is None:
            return 0
    text = args.log.read_text()
    try:
        samples = parse_log(text)
    except ValueError as err:
        print(f"FAIL: {err}", file=sys.stderr)
        return 1
    existing = read_rows(args.csv)
    source = log_source(text)
    if any(r["source"] == source for r in existing):
        print(f"FAIL: {source} already recorded", file=sys.stderr)
        return 1
    method = args.method or next(
        (r["method"] for r in reversed(existing) if r["machine"] == args.machine and r["metric"] != TICK_FRAME), ""
    )
    if not method:
        print("FAIL: no --method and no earlier row to inherit it from", file=sys.stderr)
        return 1
    tick_method = args.method or next(
        (r["method"] for r in reversed(existing) if r["machine"] == args.machine and r["metric"] == TICK_FRAME),
        TICK_FRAME_METHOD,
    )
    common = {
        "date": today(),
        "commit": commit_id(),
        "label": label,
        "machine": args.machine,
        "run": str(next_run(existing, label, args.machine)),
        "method": method,
        "load": str(round(os.getloadavg()[0], 2)),
        "source": source,
    }
    _append(
        args.csv,
        [
            {**common, "metric": s.metric, "scenario": s.scenario}
            | ({"method": tick_method} if s.metric == TICK_FRAME else {})
            | {"p95_ms": _cell(s.p95_ms), "p99_ms": _cell(s.p99_ms), "mean_ms": _cell(s.mean_ms)}
            for s in samples
        ],
    )
    print(f"recorded {len(samples)} rows, run {common['run']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
