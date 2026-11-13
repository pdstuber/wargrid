# SPDX-License-Identifier: GPL-3.0-or-later
import tempfile
import unittest
import wave
from pathlib import Path

import numpy as np
import synth
from scipy.io import wavfile

REPO = Path(__file__).resolve().parents[2]
OFFSETS = {
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
SECONDS = {
    "rifle_burst": 0.7,
    "carbine": 0.6,
    "cannon": 1.5,
    "explosion": 1.6,
    "vehicle_death": 1.3,
    "building_small": 2.2,
    "building_large": 3.6,
    "infantry_death": 0.3,
    "click": 0.05,
    "error": 0.3,
}


class SynthTest(unittest.TestCase):
    def test_effect_ids_and_seeds(self) -> None:
        self.assertEqual(set(synth.EFFECTS), set(OFFSETS))
        for name, (seed, _) in synth.EFFECTS.items():
            self.assertEqual(seed, name.replace("_", "-") + "-f")

    def test_effects_sane(self) -> None:
        for name in synth.EFFECTS:
            x = synth.prototype_effect(name)
            self.assertEqual(x.ndim, 1)
            self.assertEqual(x.dtype, np.float64)
            self.assertTrue(np.all(np.isfinite(x)))
            self.assertAlmostEqual(float(np.max(np.abs(x))), 0.7, delta=1e-9)
            self.assertAlmostEqual(len(x) / synth.SR, SECONDS[name], delta=SECONDS[name] * 0.1, msg=name)

    def test_same_seed_same_samples(self) -> None:
        for name in synth.EFFECTS:
            self.assertTrue(np.array_equal(synth.prototype_effect(name), synth.prototype_effect(name)))

    def test_effect_targets(self) -> None:
        for name, offset in OFFSETS.items():
            self.assertAlmostEqual(synth.effect_target(name), -30.0 + offset)

    def test_scale_to(self) -> None:
        x = np.array([0.1, -0.05, 0.02])
        got = synth.scale_to(x, -29.6, lambda _: -20.0, "t")
        self.assertTrue(np.allclose(got, x * 10 ** (-9.6 / 20)))
        with self.assertRaisesRegex(ValueError, "t"):
            synth.scale_to(np.array([0.9]), -10.0, lambda _: -20.0, "t")

    def test_load_line_pads_and_resamples(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            raw = Path(d) / "voice" / "raw" / "kristin"
            raw.mkdir(parents=True)
            wavfile.write(raw / "x.wav", 22050, np.full(2205, 1000, dtype=np.int16))
            self.assertEqual(len(synth.load_line(Path(d), "x")), 4410 + 882 + 6615)

    def test_unit_lines(self) -> None:
        self.assertEqual(
            synth.UNIT_LINES,
            {"infantry": ["move", "attack"], "vehicle": ["move", "attack"], "worker": ["move", "work"]},
        )
        self.assertEqual(synth.UNIT_VARIANTS, 2)

    def test_load_line_reads_voice_folder(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            raw = Path(d) / "voice" / "raw" / "john"
            raw.mkdir(parents=True)
            wavfile.write(raw / "x.wav", 22050, np.full(2205, 1000, dtype=np.int16))
            self.assertEqual(len(synth.load_line(Path(d), "x", voice="john")), 4410 + 882 + 6615)

    def test_radio_band_limited(self) -> None:
        x = 0.1 * np.random.default_rng(1).standard_normal(synth.SR)
        a = synth.radio(x, np.random.default_rng(5))
        b = synth.radio(x, np.random.default_rng(5))
        self.assertEqual(len(a), len(x))
        self.assertTrue(np.all(np.isfinite(a)))
        self.assertTrue(np.array_equal(a, b))
        power = np.abs(np.fft.rfft(a)) ** 2
        freqs = np.fft.rfftfreq(len(a), 1 / synth.SR)
        self.assertLess(power[freqs < 200].sum() / power.sum(), 0.01)

    def test_treatments_known(self) -> None:
        self.assertEqual(set(synth.TREATMENTS), {"clean", "radio", "c1n"})
        for voice, treatment in synth.UNIT_PICKS.values():
            self.assertIn(treatment, synth.TREATMENTS)
            self.assertIn(voice, {"john", "norman", "bryce"})

    def test_c1n_deterministic(self) -> None:
        x = np.random.default_rng(1).standard_normal(synth.SR // 2)
        a = synth.c1n(x, np.random.default_rng(5))
        b = synth.c1n(x, np.random.default_rng(5))
        self.assertEqual(len(a), len(x))
        self.assertTrue(np.all(np.isfinite(a)))
        self.assertTrue(np.array_equal(a, b))

    def test_refuses_src_in_repo(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "out"
            self.assertEqual(synth.main([str(REPO / "tools"), str(out)]), 2)
            self.assertFalse(out.exists())

    def test_wav_format(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "a.wav"
            synth.write_wav(p, np.linspace(-0.5, 0.5, 100))
            with wave.open(str(p)) as w:
                self.assertEqual((w.getnchannels(), w.getsampwidth(), w.getframerate()), (1, 2, 44100))


if __name__ == "__main__":
    unittest.main()
