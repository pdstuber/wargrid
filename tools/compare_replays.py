import argparse
from pathlib import Path
import re
import sys


def read_trace(path: Path) -> list[str]:
    rows = path.read_text().splitlines()
    if len(rows) != 1200:
        raise ValueError(f"{path}: expected 1200 ticks, got {len(rows)}")
    digests = []
    for tick, row in enumerate(rows, 1):
        if not re.fullmatch(rf"{tick}\t[0-9a-f]{{64}}", row):
            raise ValueError(f"{path}: malformed row at tick {tick}")
        digests.append(row.split("\t")[1])
    return digests


def compare_traces(paths: list[Path]) -> None:
    if len(paths) < 2:
        raise ValueError("Expected at least two platform traces")
    traces = [read_trace(path) for path in paths]
    for tick, values in enumerate(zip(*traces), 1):
        if len(set(values)) != 1:
            detail = ", ".join(f"{path.name}={value}" for path, value in zip(paths, values))
            raise ValueError(f"Replay diverged at tick {tick}: {detail}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Compare exact 1200-tick replay traces from two or more platforms")
    parser.add_argument("traces", type=Path, nargs="+")
    args = parser.parse_args()
    try:
        compare_traces(args.traces)
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
    print("REPLAYS MATCHED 1200")
