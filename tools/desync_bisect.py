import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from compare_replays import first_divergence, read_trace
from desync_diff import _walk, ring_divergence

# A script error in oracle mode can leave Godot hanging with no output.
ORACLE_TIMEOUT_S = 600


def wire_lines(command_log: list[dict]) -> list[str]:
    by_tick: dict[int, list[dict]] = {}
    for command in command_log:
        by_tick.setdefault(command["tick"], []).append(command)
    return [
        json.dumps({"commands": commands, "seat": 0, "tick": tick, "type": "tick"}, sort_keys=True)
        for tick, commands in by_tick.items()
    ]


def seat_verdict(report_ring: list[str], local_digests: list[str]) -> int | None:
    local = {str(i + 1): digest for i, digest in enumerate(local_digests)}
    rows = dict(row.split("\t") for row in report_ring)
    return next((int(t) for t in sorted(rows, key=int) if t in local and rows[t] != local[t]), None)


def _client(env: str | None) -> list[str]:
    if env:
        return env.split()
    return ["godot", "--headless", "--path", str(Path(__file__).resolve().parent.parent / "game")]


def replay(
    client: list[str], report: dict, out: Path, tag: str, ticks: int, state_ticks: list[int] | None = None
) -> bool:
    log = out / "commands.log"
    log.write_text("".join(f"{line}\n" for line in wire_lines(report["command_log"])))
    args = ["--netclient", "--replay-log", str(log), "--map", str(report["map"]), "--seed", str(report["seed"])]
    args += ["--oracle-ticks", str(ticks), "--ring-log", str(out / f"ring-{tag}.tsv")]
    if state_ticks:
        args += ["--state-ticks", ",".join(map(str, state_ticks)), "--snapshot-dir", str(out / tag)]
    try:
        run = subprocess.run(
            [*client, "--", *args], capture_output=True, text=True, check=False, timeout=ORACLE_TIMEOUT_S
        )
    except subprocess.TimeoutExpired as expired:
        _write_oracle_log(out, tag, expired.stdout, expired.stderr)
        return False
    ok = run.returncode == 0 and "ORACLE FINAL" in run.stdout
    if not ok:
        _write_oracle_log(out, tag, run.stdout, run.stderr)
    return ok


def _oracle_log(out: Path, tag: str) -> Path:
    return out / f"oracle-{tag}.log"


def _write_oracle_log(out: Path, tag: str, stdout: str | bytes | None, stderr: str | bytes | None) -> None:
    # TimeoutExpired carries bytes even when the run asked for text.
    text = [x.decode(errors="replace") if isinstance(x, bytes) else x or "" for x in (stdout, stderr)]
    _oracle_log(out, tag).write_text(f"--- stdout ---\n{text[0]}\n--- stderr ---\n{text[1]}\n")


def _ring_digests(out: Path, tag: str) -> list[str]:
    return read_trace(out / f"ring-{tag}.tsv", 1, 0)[0]


def _snapshot_field(report_snapshot: dict, out: Path, tag: str, tick: int) -> str:
    local = json.loads((out / tag / f"tick-{tick}.json").read_text())
    return _walk(report_snapshot, local, "snapshot") or f"none (snapshots at tick {tick} are identical)"


def _last_tick(report: dict) -> int:
    ring = report.get("hash_ring", [])
    return max([int(ring[-1].split("\t")[0]) if ring else 0, report["tick"]])


def _seat_lines(reports: list[dict], out: Path, client: list[str], ticks: int) -> tuple[list[str], bool]:
    local = _ring_digests(out, "a")
    verdicts = [seat_verdict(r["hash_ring"], local) if r.get("hash_ring") else None for r in reports]
    wanted = sorted({t for r, v in zip(reports, verdicts, strict=True) if v for t in (v - 1, v, r["snapshot"]["tick"])})
    if wanted and not replay(client, reports[0], out, "a", ticks, wanted):
        raise ValueError(f"oracle failed on the snapshot pass, see {_oracle_log(out, 'a')}")
    lines = []
    diverged = False
    for report, verdict in zip(reports, verdicts, strict=True):
        seat = report["seat"]
        if not report.get("hash_ring"):
            lines.append(f"SEAT {seat} HAS NO RING")
            diverged = True
        elif verdict is None:
            lines.append(f"SEAT {seat} MATCHES LOCAL REPLAY")
        else:
            field = _snapshot_field(report["snapshot"], out, "a", report["snapshot"]["tick"])
            lines += [f"SEAT {seat} DIVERGES FROM LOCAL REPLAY AT TICK {verdict}", f"SEAT {seat} FIRST FIELD {field}"]
            diverged = True
    return lines, diverged


def _clients_line(report: dict, out: Path, clients: list[list[str]], ticks: int) -> tuple[str, bool]:
    if not replay(clients[1], report, out, "b", ticks):
        raise ValueError(f"client B oracle failed, see {_oracle_log(out, 'b')}")
    a, b = _ring_digests(out, "a"), _ring_digests(out, "b")
    index = first_divergence([a, b])
    if index is None and len(a) != len(b):
        return f"CLIENTS DIFFER IN LENGTH {len(a)} AND {len(b)} TICKS", True
    if index is None:
        return f"CLIENTS MATCH {len(a)} TICKS", False
    tick = index + 1
    for client, tag in zip(clients, "ab", strict=True):
        if not replay(client, report, out, tag, ticks, [tick - 1, tick]):
            raise ValueError(f"oracle failed on the snapshot pass, see {_oracle_log(out, tag)}")
    snapshots = [json.loads((out / tag / f"tick-{tick}.json").read_text()) for tag in "ab"]
    field = _walk(snapshots[0], snapshots[1], "snapshot") or "none"
    return f"CLIENTS DIVERGE AT TICK {tick} FIRST FIELD {field}", True


def _bisect(reports: list[dict], out: Path, client_b: str | None) -> int:
    diverged = False
    if len(reports) == 2:
        differ = _walk(reports[0]["command_log"], reports[1]["command_log"], "command_log")
        if differ:
            print(f"COMMAND LOGS DIFFER {differ}")
            return 1
        tick = ring_divergence(*reports)
        print("RINGS AGREE" if tick is None else f"RINGS DIVERGE AT TICK {tick}")
        diverged = tick is not None
    ticks = max(_last_tick(r) for r in reports)
    clients = [_client(os.environ.get("WARGRID_CLIENT")), _client(client_b) if client_b else []]
    if not replay(clients[0], reports[0], out, "a", ticks):
        raise ValueError(f"oracle failed or timed out, see {_oracle_log(out, 'a')}")
    lines, seats_diverged = _seat_lines(reports, out, clients[0], ticks)
    print("\n".join(lines))
    diverged = diverged or seats_diverged
    if client_b:
        line, clients_diverged = _clients_line(reports[0], out, clients, ticks)
        print(line)
        diverged = diverged or clients_diverged
    print(f"SNAPSHOTS {out}")
    return 1 if diverged else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="desync_bisect.py")
    parser.add_argument("reports", type=Path, nargs="+")
    parser.add_argument("--client-b")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args(argv)
    if len(args.reports) > 2:
        parser.error("at most two reports")
    try:
        reports = [json.loads(path.read_text()) for path in args.reports]
        out = args.out or Path(tempfile.mkdtemp(prefix="desync-bisect-"))
        out.mkdir(parents=True, exist_ok=True)
        return _bisect(reports, out, args.client_b)
    except (OSError, ValueError, KeyError, TypeError, IndexError) as error:
        print(f"BISECT FAILED {error!r}")
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
