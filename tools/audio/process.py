# SPDX-License-Identifier: GPL-3.0-or-later
"""Normalises the picked music tracks to -30 LUFS and encodes them. Usage: process.py SRC_DIR OUT_DIR"""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TRACKS = {
    "stay_the_course": "music/incompetech/Stay the Course.mp3",
    "conflict": "music/oga-conflict/conflict.ogg",
    "enemy_spotted": "music/oga-enemy-spotted/Enemy spotted.ogg",
    "mammoth": "music/oga-mammoth/mammoth_0.ogg",
    "hitman": "music/incompetech/Hitman.mp3",
}
LOUDNORM = "loudnorm=I=-30:TP=-1:LRA=20"


def inside_repo(path: Path) -> bool:
    return path.resolve().is_relative_to(REPO)


def last_json(stderr: str) -> dict[str, str]:
    start = stderr.rindex("{")
    return json.loads(stderr[start : stderr.index("}", start) + 1])


def second_pass(first_pass_stderr: str) -> str:
    m = last_json(first_pass_stderr)
    return (
        f"{LOUDNORM}:measured_I={m['input_i']}:measured_TP={m['input_tp']}:measured_LRA={m['input_lra']}"
        f":measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true"
    )


def ffmpeg(*args: str) -> str:
    cmd = ["ffmpeg", "-hide_banner", "-nostats", "-y", *args]
    return subprocess.run(cmd, capture_output=True, text=True, check=True).stderr


def encode(src: Path, dest: Path, name: str) -> None:
    with tempfile.TemporaryDirectory() as d:
        wav = Path(d) / "t.wav"
        first = ffmpeg("-i", str(src), "-af", f"{LOUDNORM}:print_format=json", "-f", "null", "-")
        second = ffmpeg(
            "-i",
            str(src),
            "-af",
            f"{second_pass(first)}:print_format=json",
            "-ar",
            "44100",
            "-ac",
            "2",
            "-c:a",
            "pcm_s16le",
            str(wav),
        )
        if last_json(second)["normalization_type"] == "dynamic":
            raise RuntimeError(f"{name}: loudnorm fell back to dynamic mode")
        dest.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["oggenc", "-b", "96", "-o", str(dest), str(wav)], capture_output=True, check=True)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    src, out = Path(argv[0]), Path(argv[1])
    if inside_repo(src):
        print("SRC_DIR must be outside the repository", file=sys.stderr)
        return 2
    for name, rel in TRACKS.items():
        if not (src / rel).is_file():
            print(f"{name}: missing source {src / rel}", file=sys.stderr)
            return 1
    try:
        for name, rel in TRACKS.items():
            encode(src / rel, out / "music" / f"{name}.ogg", name)
            print(f"music/{name}.ogg")
    except (RuntimeError, subprocess.CalledProcessError, OSError, ValueError) as e:
        print(f"process failed: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
