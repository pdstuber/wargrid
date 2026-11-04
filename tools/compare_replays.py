import argparse
from pathlib import Path
import re
import sys


def _tick(i: int, interval: int) -> int:
    return i + 1 if interval == 1 else i * interval


def read_trace(path: Path, interval: int, rows: int) -> tuple[list[str], int]:
    lines = path.read_text().splitlines()
    if rows and len(lines) != rows:
        raise ValueError(f"{path}: expected {rows} rows, got {len(lines)}")
    digests = []
    width = None
    for i, row in enumerate(lines):
        tick = _tick(i, interval)
        match = re.fullmatch(rf"{tick}\t([0-9a-f]{{16}}|[0-9a-f]{{64}})", row)
        if not match:
            raise ValueError(f"{path}: malformed row at tick {tick}")
        width = len(match.group(1))
        digests.append(match.group(1))
    return digests, width


def compare_traces(paths: list[Path], interval: int = 1, rows: int = 1200) -> int:
    if len(paths) < 2:
        raise ValueError("Expected at least two platform traces")
    read = [read_trace(path, interval, rows) for path in paths]
    if len({width for _, width in read}) != 1:
        raise ValueError("traces use different digest widths")
    traces = [digests for digests, _ in read]
    if len({len(t) for t in traces}) != 1:
        raise ValueError("traces have different numbers of rows")
    for i, values in enumerate(zip(*traces)):
        if len(set(values)) != 1:
            tick = _tick(i, interval)
            detail = ", ".join(f"{path.name}={value}" for path, value in zip(paths, values))
            raise ValueError(f"Replay diverged at tick {tick}: {detail}")
    return len(traces[0])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Compare exact 1200-tick replay traces from two or more platforms")
    parser.add_argument("traces", type=Path, nargs="+")
    parser.add_argument("--interval", type=int, default=1)
    parser.add_argument("--rows", type=int, default=1200)
    args = parser.parse_args()
    try:
        count = compare_traces(args.traces, args.interval, args.rows)
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
    print("REPLAYS MATCHED", count)
