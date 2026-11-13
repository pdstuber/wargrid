# SPDX-License-Identifier: GPL-3.0-or-later
"""Renders the effects and announcer lines. Usage: synth.py [--prototype] SRC_DIR OUT_DIR

Ported unchanged (numerics and operation order) from the heard prototypes; tools write only into OUT_DIR.
"""

import functools
import itertools
import subprocess
import sys
import tempfile
import wave
from collections.abc import Callable
from pathlib import Path
from typing import Any

import numpy as np
import numpy.typing as npt
import process
from scipy import signal
from scipy.io import wavfile
from scipy.signal import butter, resample_poly, sosfilt

Arr = npt.NDArray[np.float64]
Rng = np.random.Generator

SR = 44100
MUSIC_LUFS = -30.0
VOICE_LUFS = -24.0
PEAK_LIMIT = 10 ** (-1 / 20)
LINES = [
    "base_under_attack",
    "building_lost",
    "unit_ready",
    "construction_complete",
    "insufficient_funds",
    "low_power",
    "victory",
    "defeat",
]
OFFSET_DB = {
    "rifle_burst": 0.4,
    "carbine": 0.4,
    "cannon": 4.2,
    "explosion": -0.8,
    "vehicle_death": 6.2,
    "building_small": 6.2,
    "building_large": 6.2,
    "infantry_death": -2.0,
    "click": -4.3,
    "error": -4.3,
}


def t(sec: float) -> Arr:
    return np.arange(int(sec * SR)) / SR


def rng_for(name: str) -> Rng:
    return np.random.default_rng(sum(ord(c) * 31**i for i, c in enumerate(name)) % (2**32))


def filt(x: Arr, kind: Any, cutoff: Any, order: int = 4) -> Arr:
    sos = signal.butter(order, cutoff, btype=kind, fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def decay(x: Arr, tau: float, attack: float = 0.0005) -> Arr:
    tt = np.arange(len(x)) / SR
    return x * np.exp(-tt / tau) * np.minimum(1.0, tt / attack if attack > 0 else 1.0)


def sine_sweep(sec: float, f0: float, f1: float) -> Arr:
    tt = t(sec)
    freq = f0 * (f1 / f0) ** (tt / sec)
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def reverb(x: Arr, rng: Rng, length: float, tau: float, cutoff: float, wet: float) -> Arr:
    ir = rng.standard_normal(int(length * SR))
    ir = filt(ir, "low", cutoff, 2) * np.exp(-np.arange(len(ir)) / SR / tau)
    ir[: int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))
    tail = signal.fftconvolve(x, ir / np.sqrt(np.sum(ir**2)))[: len(x) + len(ir)]
    out = np.zeros(len(tail))
    out[: len(x)] += x * (1 - wet)
    return out + tail * wet


def mix(*parts: tuple[int, Arr, float]) -> Arr:
    n = max(off + len(sig) for off, sig, _ in parts)
    out = np.zeros(n)
    for off, sig, gain in parts:
        out[off : off + len(sig)] += sig * gain
    return out


def sat(x: Arr, drive: float) -> Arr:
    return np.tanh(x * drive)


def tail_fade(x: Arr, sec: float = 0.05) -> Arr:
    k = min(len(x), int(sec * SR))
    x[-k:] *= np.linspace(1, 0, k)
    return x


def fade_bands(x: Arr, cutoffs: list[float], sweep_sec: float) -> Arr:
    pos = np.clip(np.arange(len(x)) / SR / sweep_sec, 0, 1) * (len(cutoffs) - 1)
    out = np.zeros_like(x)
    for i, c in enumerate(cutoffs):
        out += filt(x, "low", c, 2) * np.maximum(0.0, 1 - np.abs(pos - i))
    return out


def saw_sweep(sec: float, f0: float, f1: float) -> Arr:
    tt = t(sec)
    freq = f0 * (f1 / f0) ** (tt / sec)
    return 2 * ((np.cumsum(freq) / SR) % 1.0) - 1


def fm_sweep(sec: float, f0: float, f1: float, ratio: float, index: float, tau: float) -> Arr:
    tt = t(sec)
    freq = f0 * (f1 / f0) ** (tt / sec)
    ph = np.cumsum(freq) / SR
    return np.sin(2 * np.pi * ph + index * np.exp(-tt / tau) * np.sin(2 * np.pi * ratio * ph))


def bitcrush(x: Arr, bits: int, hold: int) -> Arr:
    x = np.repeat(x[::hold], hold)[: len(x)]
    q = 2 ** (bits - 1)
    return np.round(x * q) / q


def wet(x: Arr, rng: Rng, length: float, tau: float, cutoff: float, amount: float, trim: float) -> Arr:
    return reverb(x, rng, length, tau, cutoff, amount)[: int(trim * SR)]


def f_pew(rng: Rng, f0: float, f1: float, dur: float, index: float, tau: float) -> Arr:
    x = decay(fm_sweep(dur, f0, f1, 2.0, index, tau), tau, 0.001)
    click = decay(filt(rng.standard_normal(int(0.004 * SR)), "high", 4000), 0.001, 0.0001)
    return mix((0, x, 1.0), (0, click, 0.2))


def f_rifle_burst(rng: Rng) -> Arr:
    parts = [(int(k * 0.133 * SR), f_pew(rng, 1800 * (1 + 0.06 * k), 520, 0.1, 3, 0.04), 1.0) for k in range(3)]
    return tail_fade(wet(mix(*parts), rng, 0.5, 0.15, 5000, 0.2, 0.7), 0.15)


def f_carbine(rng: Rng) -> Arr:
    x = mix((0, f_pew(rng, 1100, 260, 0.2, 4, 0.07), 1.0), (0, decay(sine_sweep(0.12, 160, 70), 0.04), 0.5))
    return tail_fade(wet(x, rng, 0.5, 0.15, 4000, 0.2, 0.6), 0.1)


def f_cannon(rng: Rng) -> Arr:
    body = decay(fade_bands(saw_sweep(0.8, 500, 45), [3000, 1200, 500, 200], 0.5), 0.25, 0.003)
    burst = decay(filt(rng.standard_normal(int(0.2 * SR)), "low", 2200, 2), 0.06, 0.001)
    sub = decay(sine_sweep(0.9, 70, 30), 0.3, 0.004)
    return tail_fade(
        sat(wet(mix((0, body, 0.8), (0, burst, 0.6), (0, sub, 1.0)), rng, 0.8, 0.3, 3000, 0.3, 1.5), 1.3), 0.3
    )


def f_explosion(rng: Rng) -> Arr:
    n = int(0.9 * SR)
    noise = bitcrush(fade_bands(rng.standard_normal(n), [5000, 2000, 800, 300], 0.7), 5, 4)
    noise = decay(noise, 0.3, 0.002)
    zap = decay(fm_sweep(0.4, 1500, 60, 1.5, 4, 0.15), 0.15, 0.002)
    dry = mix((0, noise, 1.0), (0, zap, 0.6))
    echo = filt(dry, "low", 1500, 2)
    return tail_fade(
        sat(
            wet(
                mix((0, dry, 1.0), (int(0.12 * SR), echo, 0.35), (int(0.26 * SR), echo, 0.18)),
                rng,
                1.0,
                0.4,
                2500,
                0.3,
                1.6,
            ),
            1.2,
        ),
        0.3,
    )


def f_vehicle(rng: Rng) -> Arr:
    a = decay(fade_bands(saw_sweep(0.9, 420, 40), [2500, 900, 300], 0.8), 0.35, 0.003)
    b = decay(fade_bands(saw_sweep(0.9, 432, 41), [2500, 900, 300], 0.8), 0.35, 0.003)
    parts = [(0, a, 0.7), (0, b, 0.7)]
    for _ in range(6):
        g = bitcrush(decay(filt(rng.standard_normal(int(0.02 * SR)), "band", [800, 5000], 2), 0.008, 0.0005), 4, 3)
        parts.append((int(rng.uniform(0.0, 0.7) * SR), g, 0.5))
    return tail_fade(wet(mix(*parts), rng, 0.4, 0.12, 3500, 0.15, 1.3), 0.3)


def _stack(base: float, ratios: list[float], dur: float, drop: float, tau: float, mod: float) -> Arr:
    parts = []
    for r in ratios:
        x = fm_sweep(dur, base * r, base * r * drop, 1.0, mod, tau) * np.exp(-t(dur) / tau)
        parts.append((0, x, 1.0 / len(ratios)))
    return mix(*parts)


def f_building_small(rng: Rng) -> Arr:
    burst = decay(filt(rng.standard_normal(int(0.1 * SR)), "low", 3000, 2), 0.03, 0.001)
    stack = _stack(220, [1, 1.5, 2, 3], 1.8, 0.7, 0.5, 2.0)
    return tail_fade(wet(mix((0, burst, 0.8), (0, stack, 1.2)), rng, 1.8, 0.5, 3000, 0.4, 2.2), 0.4)


def f_building_large(rng: Rng) -> Arr:
    burst = decay(filt(rng.standard_normal(int(0.15 * SR)), "low", 2000, 2), 0.05, 0.001)
    stack = _stack(110, [1, 1.5, 2, 3], 3.2, 0.6, 0.9, 2.5)
    sub = decay(sine_sweep(3.2, 45, 28), 1.0, 0.05)
    return tail_fade(wet(mix((0, burst, 0.8), (0, stack, 1.2), (0, sub, 0.9)), rng, 3.0, 0.9, 2500, 0.5, 3.6), 0.6)


def f_infantry(rng: Rng) -> Arr:
    tt = t(0.18)
    f = 900 * (220 / 900) ** (tt / 0.18) * (1 + 0.03 * np.sin(2 * np.pi * 22 * tt))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.07)
    return tail_fade(wet(x, rng, 0.3, 0.1, 3000, 0.15, 0.3), 0.05)


def f_click(rng: Rng) -> Arr:
    return tail_fade(decay(np.sin(2 * np.pi * 1400 * t(0.05)), 0.01, 0.0005), 0.01)


def f_error(rng: Rng) -> Arr:
    a = decay(
        np.sin(
            2 * np.pi * sine_sweep(0.14, 330, 260) * 0
            + 2 * np.pi * np.cumsum(330 * (220 / 330) ** (t(0.14) / 0.14)) / SR
        ),
        0.08,
        0.003,
    )
    b = decay(np.sin(2 * np.pi * np.cumsum(260 * (160 / 260) ** (t(0.18) / 0.18)) / SR), 0.1, 0.003)
    return tail_fade(mix((0, a, 1.0), (int(0.12 * SR), b, 1.0)), 0.02)


def band_edges(n: int, lo: float = 120, hi: float = 7500) -> Arr:
    return np.geomspace(lo, hi, n + 1)


def env(x: Arr, cutoff: float = 40) -> Arr:
    sos = butter(2, cutoff, "low", fs=SR, output="sos")
    return np.maximum(sosfilt(sos, np.abs(x)), 0)


def saw(f: float, n: int, rng: Rng) -> Arr:
    ph = (np.arange(n) * f / SR + rng.random()) % 1.0
    return 2 * ph - 1


def carrier(n: int, rng: Rng, freqs: tuple[float, ...], detune: float, noise: float) -> tuple[Arr, Arr]:
    c = sum(saw(f * (1 + d), n, rng) for f in freqs for d in (-detune, 0, detune))
    c = c / np.max(np.abs(c))
    return c, rng.standard_normal(n) * noise


def load_line(src_dir: Path, line: str, voice: str = "kristin") -> Arr:
    sr, x = wavfile.read(src_dir / "voice" / "raw" / voice / f"{line}.wav")
    x = resample_poly(x.astype(np.float64) / 32768, SR, sr)
    return np.concatenate([np.zeros(int(0.02 * SR)), x, np.zeros(int(0.15 * SR))])


def c1n(x: Arr, rng: Rng, bands: int = 32, env_hz: float = 80, sib: float = 0.35, pitch: float = 110.0) -> Arr:
    tone, hiss = carrier(len(x), rng, (pitch,), 0.0, 1.0)
    out = np.zeros_like(x)
    edges = band_edges(bands)
    for lo, hi in itertools.pairwise(edges):
        sos = butter(4, [lo, hi], "band", fs=SR, output="sos")
        c = sosfilt(sos, hiss if lo >= 2800 else tone)
        out += c / (np.sqrt(np.mean(c**2)) + 1e-9) * env(sosfilt(sos, x), env_hz)
    return out + sib * filt(x, "high", 2500)


def radio(x: Arr, rng: Rng) -> Arr:
    return sat(filt(x, "band", [300, 3400]), 1.5) + 0.003 * rng.standard_normal(len(x))


TREATMENTS: dict[str, Callable[[Arr, Rng], Arr]] = {
    "clean": lambda x, rng: x,
    "radio": radio,
    "c1n": c1n,
    "c1n90": functools.partial(c1n, pitch=90.0),
    "c1n140": functools.partial(c1n, pitch=140.0),
}
UNIT_LINES = {"infantry": ["move", "attack"], "vehicle": ["move", "attack"], "worker": ["move", "work"]}
UNIT_VARIANTS = 2
UNIT_PICKS: dict[str, tuple[str, str]] = {}


def unit_line(src: Path, role: str, line: str, n: int) -> Arr:
    voice, treatment = UNIT_PICKS[role]
    x = load_line(src, f"unit_{line}_{n}", voice)
    x = TREATMENTS[treatment](x, rng_for(f"unit-{role}-{line}-{n}"))
    return tail_fade(scale_to(x, VOICE_LUFS, lufs, f"{role}_{line}_{n}"), 0.03)


EFFECTS: dict[str, tuple[str, Callable[[Rng], Arr]]] = {
    "rifle_burst": ("rifle-burst-f", f_rifle_burst),
    "carbine": ("carbine-f", f_carbine),
    "cannon": ("cannon-f", f_cannon),
    "explosion": ("explosion-f", f_explosion),
    "vehicle_death": ("vehicle-death-f", f_vehicle),
    "building_small": ("building-small-f", f_building_small),
    "building_large": ("building-large-f", f_building_large),
    "infantry_death": ("infantry-death-f", f_infantry),
    "click": ("click-f", f_click),
    "error": ("error-f", f_error),
}


def prototype_effect(name: str) -> Arr:
    seed, build = EFFECTS[name]
    x = build(rng_for(seed))
    return x / np.max(np.abs(x)) * 0.7


def effect_target(name: str) -> float:
    return MUSIC_LUFS + OFFSET_DB[name]


def lufs(x: Arr) -> float:
    with tempfile.TemporaryDirectory() as d:
        path = Path(d) / "m.wav"
        wavfile.write(path, SR, x.astype(np.float32))
        cmd = ["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "ebur128", "-f", "null", "-"]
        err = subprocess.run(cmd, capture_output=True, text=True, check=True).stderr
    return float(err.rsplit("I:", 1)[1].split()[0])


def looped(x: Arr) -> Arr:
    return np.tile(x, -(-3 * SR // len(x)))


def scale_to(x: Arr, target: float, measure: Callable[[Arr], float], name: str) -> Arr:
    y = x * 10 ** ((target - measure(x)) / 20)
    if np.max(np.abs(y)) > PEAK_LIMIT:
        raise ValueError(f"{name}: peak over -1 dBFS at {target} LUFS")
    return y


def write_wav(path: Path, x: Arr) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def peak_db(x: Arr) -> float:
    return 20 * float(np.log10(np.max(np.abs(x))))


def main(argv: list[str]) -> int:
    prototype = "--prototype" in argv
    args = [a for a in argv if a != "--prototype"]
    if len(args) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    src, out = Path(args[0]), Path(args[1])
    if process.inside_repo(src):
        print("SRC_DIR must be outside the repository", file=sys.stderr)
        return 2
    for name in EFFECTS:
        x = prototype_effect(name)
        if not prototype:
            x = scale_to(x, effect_target(name), lambda y: lufs(looped(y)), name)
        write_wav(out / "sfx" / f"{name}.wav", x)
        print(f"sfx/{name} lufs {lufs(looped(x)):.1f} peak {peak_db(x):.1f} dBFS")
    for line in LINES:
        x = tail_fade(scale_to(c1n(load_line(src, line), rng_for(f"voice-{line}")), VOICE_LUFS, lufs, line), 0.03)
        write_wav(out / "voice" / f"{line}.wav", x)
        print(f"voice/{line} lufs {lufs(x):.1f} peak {peak_db(x):.1f} dBFS")
    for role, names in UNIT_LINES.items():
        if role not in UNIT_PICKS:
            continue
        for line, n in itertools.product(names, range(1, UNIT_VARIANTS + 1)):
            x = unit_line(src, role, line, n)
            write_wav(out / "voice" / "units" / f"{role}_{line}_{n}.wav", x)
            print(f"voice/units/{role}_{line}_{n} lufs {lufs(x):.1f} peak {peak_db(x):.1f} dBFS")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
