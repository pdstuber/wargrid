#!/usr/bin/env python3
"""Read a playtest session file: print answers and markers, extract JPGs, prepare replays.

Output files (JPGs, .cmd) go next to the session file, never into the repository.
"""

import argparse
import base64
import json
import sys
from pathlib import Path


def load_session(path: Path) -> dict:
    session = json.loads(path.read_text())
    if session.get("format") != 1:
        raise SystemExit(f"unsupported session format {session.get('format')!r} (this tool reads 1)")
    return session


def _jpg_path(path: Path, k: int, i: int) -> Path:
    return path.with_name(f"{path.stem}-m{k}-{i}.jpg")


def write_jpgs(session: dict, path: Path) -> list[Path | None]:
    out: list[Path | None] = []
    for k, match in enumerate(session["matches"], 1):
        for i, marker in enumerate(match["markers"], 1):
            if not marker.get("jpg"):
                out.append(None)
                continue
            target = _jpg_path(path, k, i)
            target.write_bytes(base64.b64decode(marker["jpg"]))
            out.append(target)
    return out


def summary_lines(session: dict, jpgs: list[Path | None]) -> list[str]:
    head = f"SESSION build={session['build']} focus={session['focus']} started={session['started']}"
    lines = [f"{head} matches={len(session['matches'])}"]
    lines += [f"CHECK {cid} {'yes' if done else 'no'}" for cid, done in session["checklist"].items()]
    lines += [f"ANSWER {qid} {a['score']} {a['text']}" for qid, a in session["answers"].items()]
    flat = iter(jpgs)
    for k, m in enumerate(session["matches"], 1):
        lines.append(
            f"MATCH {k} {m['mode']} {m['map']} seed={m['seed']} seat={m['seat']} end_tick={m['end_tick']} result={m['result']}"
        )
        for i, mk in enumerate(m["markers"], 1):
            jpg = next(flat, None)
            camera = ",".join(str(c) for c in mk["camera"])
            selected = ",".join(str(e) for e in mk["selected"])
            lines.append(
                f"MARKER {k}.{i} tick={mk['tick']} {mk['kind']} text={json.dumps(mk['text'])} "
                f"comment={json.dumps(mk['comment'])} camera={camera} selected={selected} jpg={jpg or '-'}"
            )
    return lines


def replay_rows(session: dict, path: Path) -> list[str]:
    rows = []
    for k, m in enumerate(session["matches"], 1):
        cmd = path.with_name(f"{path.stem}-m{k}.cmd")
        cmd.write_text("".join(line + "\n" for line in m["commands"]))
        factions = ",".join(m["factions"]) or "-"
        ticks = ",".join(str(mk["tick"]) for mk in m["markers"]) or "-"
        row = [
            str(k),
            str(cmd),
            m["mode"],
            m["map"],
            str(m["seed"]),
            factions,
            str(m["end_tick"]),
            m["end_digest"],
            ticks,
        ]
        rows.append("\t".join(row))
    return rows


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path)
    parser.add_argument(
        "--replay-args", action="store_true", help="write .cmd files and print one replay row per match"
    )
    args = parser.parse_args(argv)
    try:
        session = load_session(args.file)
    except SystemExit as err:
        print(err, file=sys.stderr)
        return 2
    if args.replay_args:
        lines = replay_rows(session, args.file)
    else:
        lines = summary_lines(session, write_jpgs(session, args.file))
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
