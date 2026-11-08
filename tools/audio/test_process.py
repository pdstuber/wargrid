# SPDX-License-Identifier: GPL-3.0-or-later
import tempfile
import unittest
from pathlib import Path

import process

REPO = Path(__file__).resolve().parents[2]
STDERR = """[Parsed_loudnorm_0 @ 0x1]
{
\t"input_i" : "-20.10",
\t"input_tp" : "-3.20",
\t"input_lra" : "5.40",
\t"input_thresh" : "-30.50",
\t"output_i" : "-30.2",
\t"normalization_type" : "dynamic",
\t"target_offset" : "0.12"
}
"""


class ProcessTest(unittest.TestCase):
    def test_refuses_source_in_repo(self) -> None:
        with tempfile.TemporaryDirectory() as d:
            out = Path(d) / "out"
            self.assertEqual(process.main([str(REPO / "tools"), str(out)]), 2)
            self.assertFalse(out.exists())

    def test_second_pass_uses_measured_values(self) -> None:
        self.assertIn(
            "measured_I=-20.10:measured_TP=-3.20:measured_LRA=5.40:measured_thresh=-30.50:offset=0.12:linear=true",
            process.second_pass(STDERR),
        )

    def test_tracks_are_the_five_picks(self) -> None:
        self.assertEqual(set(process.TRACKS), {"stay_the_course", "conflict", "enemy_spotted", "mammoth", "hitman"})


if __name__ == "__main__":
    unittest.main()
