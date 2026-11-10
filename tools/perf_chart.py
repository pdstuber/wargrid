"""Render docs/reference/perf-history.csv as a status table in the ledger and the README."""

import argparse
import csv
import math
import os
import shutil
import sys
import tempfile
from pathlib import Path
from typing import NamedTuple

BUSY_LOAD = 2.5
DEV = "dev"


class Budget(NamedTuple):
    target_ms: float
    dev_ms: float
    stat: str


class Line(NamedTuple):
    title: str
    metric: str
    budget: Budget
    scenarios: tuple[str, ...]
    name: str


class Point(NamedTuple):
    label: str
    date: str
    method: str
    machine: str
    worst_pct: float
    load: float

    @property
    def busy(self) -> bool:
        return self.load > BUSY_LOAD


SIM_P95 = Budget(10.0, 1.82, "p95")
SIM_P99 = Budget(20.0, 3.64, "p99")
PLUMBING = Budget(5.0, 0.91, "mean")
FRAME = Budget(16.7, 3.04, "p95")
LOCKSTEP = Budget(3.3, 0.6, "p99")
GATED = ("contact", "skirmish3v3", "transports", "defences", "docks", "ramp", "frc")

LINES = (
    Line("movement p95", "movement_tick", SIM_P95, ("open", "dense"), "Unit movement"),
    Line("movement p99", "movement_tick", SIM_P99, ("open", "dense"), "Unit movement, slowest moments"),
    Line("combat gated p95", "combat_tick", SIM_P95, GATED, "Combat, normal fights"),
    Line("combat gated p99", "combat_tick", SIM_P99, GATED, "Combat, normal fights, slowest moments"),
    Line("combat stress p95", "combat_tick", SIM_P95, ("open", "dense", "hordes300"), "Combat, huge battles"),
    Line(
        "plumbing, movement layouts",
        "plumbing",
        PLUMBING,
        ("ashfall:profile", "open:profile", "dense:profile"),
        "Background upkeep, armies on the move",
    ),
    Line(
        "plumbing, horde",
        "plumbing",
        PLUMBING,
        ("horde:profile", "large_196:profile"),
        "Background upkeep, huge crowds",
    ),
    Line("rendered frame p95", "frame_interval", FRAME, ("open", "dense"), "Drawing the screen"),
    Line("Ashfall frame p95", "frame_interval", FRAME, ("ashfall",), "Drawing the screen, big map (Ashfall)"),
    Line("lockstep p99", "lockstep_overhead", LOCKSTEP, ("contact",), "Online play overhead"),
)
_REF = Path(__file__).resolve().parent.parent / "docs" / "reference"
DEFAULT_CSV = _REF / "perf-history.csv"
DEFAULT_LEDGER = _REF / "performance.md"
DEFAULT_README = _REF.parent.parent / "README.md"


def load_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def _value(rows: list[dict[str, str]], line: Line) -> float | None:
    values = [
        float(r[line.budget.stat + "_ms"])
        for r in rows
        if r["metric"] == line.metric and r["scenario"] in line.scenarios and r[line.budget.stat + "_ms"]
    ]
    return max(values) if values else None


def series(rows: list[dict[str, str]], line: Line) -> list[Point]:
    groups: dict[str, list[dict[str, str]]] = {}
    for r in rows:
        if r["machine"] == DEV and r["metric"] == line.metric and r["scenario"] in line.scenarios:
            groups.setdefault(r["label"], []).append(r)
    points = []
    for label, group in groups.items():
        runs: dict[str, list[dict[str, str]]] = {}
        for r in group:
            runs.setdefault(r["run"], []).append(r)
        values = [v for v in (_value(run, line) for run in runs.values()) if v is not None]
        if not values:
            continue
        load = max((float(r["load"]) for r in group if r["load"]), default=0.0)
        points.append(
            Point(
                label,
                min(r["date"] for r in group),
                group[0]["method"],
                DEV,
                max(values) / line.budget.dev_ms * 100,
                load,
            )
        )
    return sorted(points, key=lambda p: p.date)


BEGIN = "<!-- perf-charts:begin -->"
END = "<!-- perf-charts:end -->"
PT_BEGIN = "<!-- perf-table:begin -->"
PT_END = "<!-- perf-table:end -->"
_MOVEMENT_SPREAD, _GATED_SPREAD, _STRESS_SPREAD = 50.3, 57.5, 40.7
NOISE_PCT: dict[str, float] = {
    "movement p95": _MOVEMENT_SPREAD,
    "movement p99": _MOVEMENT_SPREAD,
    "combat gated p95": _GATED_SPREAD,
    "combat gated p99": _GATED_SPREAD,
    "combat stress p95": _STRESS_SPREAD,
}


class Change(NamedTuple):
    kind: str  # "new", "method" or "pct"
    pct: float = 0.0
    prev: Point | None = None


def _change(latest: Point, prev: Point | None) -> Change:
    if prev is None or prev.worst_pct == 0:
        return Change("new")
    if prev.method != latest.method:
        return Change("method", prev=prev)
    return Change("pct", (latest.worst_pct / prev.worst_pct - 1) * 100, prev)


def areas(rows: list[dict[str, str]]) -> list[tuple[Line, Point, Change]]:
    out = []
    for line in LINES:
        dev = series(rows, line)
        if dev:
            out.append((line, dev[-1], _change(dev[-1], dev[-2] if len(dev) > 1 else None)))
    return out


def _compare(latest: Point, change: Change) -> str:
    if change.kind == "new":
        return "no previous run"
    prev = change.prev
    assert prev is not None
    if change.kind == "method":
        return f"not comparable (method {prev.method} \u2192 {latest.method})"
    if f"{abs(change.pct):.0f}" == "0":
        return f"unchanged vs {prev.label} (worst vs worst)"
    return f"{abs(change.pct):.0f}% {'slower' if change.pct > 0 else 'faster'} than {prev.label} (worst vs worst)"


def _budget_text(latest: Point) -> str:
    stamp = f"({latest.label}, {latest.date})"
    if latest.worst_pct >= 100:
        return f"{latest.worst_pct:.0f}% of budget, exceeded {stamp}"
    return f"{math.floor(latest.worst_pct)}% of budget {stamp}"


def summary_lines(rows: list[dict[str, str]]) -> list[str]:
    out = []
    for line, latest, change in areas(rows):
        noise = NOISE_PCT.get(line.title)
        spread = f"run-to-run spread up to {noise:.0f}%" if noise is not None else "run-to-run spread not measured"
        text = f"{line.title}: {_budget_text(latest)}, {_compare(latest, change)}; {spread}"
        if latest.busy:
            text += f", busy host (load {latest.load:.1f})"
        out.append(text)
    return out


def update_ledger(text: str, block: str, begin: str = BEGIN, end: str = END) -> str:
    if text.count(begin) != 1 or text.count(end) != 1 or text.index(begin) > text.index(end):
        raise ValueError(f"needs exactly one {begin} before one {end}")
    head, rest = text.split(begin)
    return f"{head}{begin}\n{block}\n{end}{rest.split(end)[1]}"


CAPTION = (
    "Percent of the limit for a low-end device, estimated from this Mac (see the ledger for how). "
    "\U0001f53a = used more of the limit than last run. Small changes can be run-to-run noise. "
    "As of = when that area was last measured; areas drawn from rendered runs update only at milestone gates."
)
BAR_CELLS = 10
CLOSE_PCT = 85


def _used(worst_pct: float) -> str:
    n = int(worst_pct) if worst_pct < 100 else round(worst_pct)
    if worst_pct >= 100:
        return f"{'\u2588' * BAR_CELLS}\u25b6 {n}%"
    filled = n // BAR_CELLS
    return f"{'\u2588' * filled}{'\u2591' * (BAR_CELLS - filled)} {n}%"


def _vs_last(change: Change) -> str:
    if change.kind == "new":
        return "\U0001f195 first run"
    if change.kind == "method":
        return "\u26a0\ufe0f method changed"
    if f"{abs(change.pct):.0f}" == "0":
        return "\u2796 same"
    n = f"{abs(change.pct):.0f}"
    return f"\U0001f53a {n}% worse" if change.pct > 0 else f"\U0001f53b {n}% better"


def _status(worst_pct: float) -> str:
    if worst_pct >= 100:
        return "\U0001f534 Over"
    return "\U0001f7e1 Close" if worst_pct >= CLOSE_PCT else "\U0001f7e2 OK"


def status_table(rows: list[dict[str, str]]) -> str:
    entries = areas(rows)
    entries.sort(key=lambda e: e[1].worst_pct, reverse=True)
    over = sum(1 for _, latest, _ in entries if latest.worst_pct >= 100)
    head = f"**{over} of {len(entries)} areas over budget**" if over else "**Nothing over budget**"
    table = ["| Area | Status | Budget used | vs last run | As of |", "| --- | --- | --- | --- | --- |"]
    for line, latest, change in entries:
        name = f"**{line.name}**" if latest.worst_pct >= 100 else line.name
        vs = _vs_last(change) + (" (busy host)" if latest.busy else "")
        table.append(f"| {name} | {_status(latest.worst_pct)} | {_used(latest.worst_pct)} | {vs} | {latest.date} |")
    return "\n".join([head, "", *table, "", CAPTION])


def _ledger_block(rows: list[dict[str, str]]) -> str:
    details = "\n".join(f"- {s}" for s in summary_lines(rows))
    return f"{status_table(rows)}\n\nDetails:\n\n{details}"


def _readme_block(rows: list[dict[str, str]]) -> str:
    return (
        "Performance against the low-end budget (generated):\n\n"
        f"{status_table(rows)}\n\nDetails: [performance ledger](docs/reference/performance.md)."
    )


def _write_all(files: list[tuple[Path, str]]) -> None:
    temps = []
    try:
        for path, text in files:
            with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False, suffix=".tmp") as handle:
                handle.write(text)
            shutil.copymode(path, handle.name)
            temps.append((Path(handle.name), path))
        for tmp, path in temps:
            os.replace(tmp, path)
    finally:
        for tmp, _ in temps:
            tmp.unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    ap.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    ap.add_argument("--readme", type=Path, default=DEFAULT_README)
    args = ap.parse_args(argv)
    rows = load_rows(args.csv)
    try:
        ledger = update_ledger(args.ledger.read_text(), _ledger_block(rows))
        readme = update_ledger(args.readme.read_text(), _readme_block(rows), PT_BEGIN, PT_END)
    except ValueError as err:
        print(err, file=sys.stderr)
        return 1
    _write_all([(args.ledger, ledger), (args.readme, readme)])
    return 0


if __name__ == "__main__":
    sys.exit(main())
