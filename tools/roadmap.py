import argparse
import itertools
import re
import sys
from pathlib import Path

from perf_chart import update_ledger, write_all

ROOT = Path(__file__).resolve().parent.parent
BEGIN = "<!-- roadmap:begin -->"
END = "<!-- roadmap:end -->"
MILESTONES = (
    "Move and select units",
    "Build a base and mine supplies",
    "Fight with infantry and tanks",
    "Play online with a friend",
    "Teams and big maps",
    "Choose your faction",
    "Releases and sound",
)
STATES = {
    "done": ("✅", "Done"),
    "next": ("⏭", "Next"),
    "planned": ("\U0001f4cb", "Planned"),
    "later": ("\U0001f4a1", "Later"),
}
Row = tuple[str, str]


def section(text: str, heading: str) -> list[str]:
    lines = text.splitlines()
    start = next((n for n, line in enumerate(lines) if line.strip() == heading), None)
    if start is None:
        return []
    end = next((n for n in range(start + 1, len(lines)) if lines[n].startswith("#")), len(lines))
    return lines[start + 1 : end]


def table_rows(lines: list[str]) -> list[list[str]]:
    table = list(
        itertools.takewhile(
            lambda line: line.startswith("|"), itertools.dropwhile(lambda line: not line.startswith("|"), lines)
        )
    )
    cells = [[c.strip() for c in line.strip().strip("|").split("|")] for line in table]
    return [row for row in cells[1:] if not set(row[0]) <= set("-: ")]


def status_packages(text: str) -> list[tuple[str, str, bool]]:
    return [
        (row[0], row[1], row[2].startswith("Done"))
        for row in table_rows(section(text, "## Packages"))
        if len(row) >= 3 and not row[0].lower().startswith("night")
    ]


def day_lane(text: str) -> list[tuple[str, str]]:
    return [(row[0], row[1]) for row in table_rows(section(text, "### Day lane")) if len(row) >= 2]


def later_names(text: str) -> list[str]:
    items = [line for line in section(text, "### Later") if re.match(r"\d+\. ", line)]
    return [m.group(1) if (m := re.match(r"\d+\. \*\*(.+?):?\*\*", line)) else "" for line in items]


def rows(packages: str, status: str) -> tuple[list[Row], list[str]]:
    errors = []
    lane = day_lane(packages)
    later = later_names(packages)
    if not lane:
        errors.append("no Day lane table found in packages")
    if not later:
        errors.append("no Later items found in packages")
    errors += [f"Later item {n} has no **Name:** lead" for n, name in enumerate(later, 1) if not name]
    pkgs = status_packages(status)
    done_ids = {ident for ident, _, done in pkgs if done}
    lane_ids = {ident for ident, _ in lane}
    errors += [
        f"STATUS package {ident} is not done and not in the Day lane"
        for ident, _, done in pkgs
        if ident.startswith("P") and not done and ident not in lane_ids
    ]
    out: list[Row] = [(m, "done") for m in MILESTONES]
    out += [(name, "done") for ident, name, done in pkgs if done and ident not in lane_ids]
    next_taken = False
    for ident, name in lane:
        if ident in done_ids:
            out.append((name, "done"))
        else:
            out.append((name, "planned" if next_taken else "next"))
            next_taken = True
    out += [(name, "later") for name in later if name]
    return out, errors


def block(items: list[Row]) -> str:
    done = sum(state == "done" for _, state in items)
    lines = [f"| {STATES[state][0]} | {name} | {STATES[state][1]} |" for name, state in items]
    return "\n".join(
        [f"**{done} of {len(items)} parts done**", "", "| | What | State |", "| --- | --- | --- |", *lines]
    )


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--packages", type=Path, default=ROOT / "docs" / "packages.md")
    ap.add_argument("--status", type=Path, default=ROOT / "docs" / "STATUS.md")
    ap.add_argument("--readme", type=Path, default=ROOT / "README.md")
    ap.add_argument(
        "--check", action="store_true", help="exit 1 if the data is inconsistent or the README block is stale"
    )
    args = ap.parse_args(argv)
    items, errors = rows(args.packages.read_text(), args.status.read_text())
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    try:
        readme = update_ledger(args.readme.read_text(), block(items), BEGIN, END)
    except ValueError as err:
        print(err, file=sys.stderr)
        return 1
    if args.check:
        if readme != args.readme.read_text():
            print("README roadmap is stale: run python3 tools/roadmap.py", file=sys.stderr)
            return 1
        return 0
    write_all([(args.readme, readme)])
    return 0


if __name__ == "__main__":
    sys.exit(main())
