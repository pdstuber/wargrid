from pathlib import Path
import tempfile
import unittest

from compare_replays import compare_traces


class ReplayComparisonTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.paths = [Path(self.directory.name) / f"{name}.tsv" for name in ["linux", "windows", "macos"]]
        self.rows = [f"{tick}\t{'a' * 64}" for tick in range(1, 1201)]
        for path in self.paths:
            path.write_text("\n".join(self.rows) + "\n")

    def test_matching_traces(self):
        compare_traces(self.paths)

    def test_first_divergent_tick(self):
        changed = self.rows.copy()
        changed[416] = "417\t" + "b" * 64
        self.paths[1].write_text("\n".join(changed))
        with self.assertRaisesRegex(ValueError, "tick 417"):
            compare_traces(self.paths)

    def test_missing_file(self):
        self.paths[1].unlink()
        with self.assertRaises((OSError, ValueError)):
            compare_traces(self.paths)

    def test_truncated_trace(self):
        self.paths[1].write_text("\n".join(self.rows[:-1]))
        with self.assertRaisesRegex(ValueError, "1200"):
            compare_traces(self.paths)

    def test_invalid_tick_and_digest(self):
        for row in ["1\t" + "a" * 64, "3\t" + "a" * 64, "2\t" + "z" * 64]:
            with self.subTest(row=row):
                changed = self.rows.copy()
                changed[1] = row
                self.paths[1].write_text("\n".join(changed))
                with self.assertRaises(ValueError):
                    compare_traces(self.paths)

    def test_accepts_two_platforms(self):
        compare_traces(self.paths[:2])

    def test_requires_at_least_two_platforms(self):
        with self.assertRaisesRegex(ValueError, "at least two"):
            compare_traces(self.paths[:1])

    def _netplay(self, name, ticks, digest="a" * 16):
        path = Path(self.directory.name) / name
        path.write_text("\n".join(f"{t}\t{digest}" for t in ticks) + "\n")
        return path

    def test_interval_rows_start_at_tick_zero(self):
        paths = [self._netplay(n, range(0, 301, 30)) for n in ["a.tsv", "b.tsv"]]
        compare_traces(paths, interval=30, rows=0)

    def test_any_length_must_be_equal(self):
        paths = [self._netplay("a.tsv", range(0, 301, 30)), self._netplay("b.tsv", range(0, 271, 30))]
        with self.assertRaisesRegex(ValueError, "rows"):
            compare_traces(paths, interval=30, rows=0)

    def test_interval_divergence_names_tick(self):
        good = self._netplay("a.tsv", range(0, 91, 30))
        bad = Path(self.directory.name) / "b.tsv"
        bad.write_text("0\t" + "a" * 16 + "\n30\t" + "a" * 16 + "\n60\t" + "b" * 16 + "\n90\t" + "a" * 16 + "\n")
        with self.assertRaisesRegex(ValueError, "tick 60"):
            compare_traces([good, bad], interval=30, rows=0)

    def test_mixed_digest_width_rejected(self):
        wide = self._netplay("a.tsv", range(0, 91, 30), "a" * 64)
        narrow = self._netplay("b.tsv", range(0, 91, 30))
        with self.assertRaises(ValueError):
            compare_traces([wide, narrow], interval=30, rows=0)

    def test_interval_row_tick_must_be_multiple(self):
        paths = [self._netplay(n, [0, 30, 61]) for n in ["a.tsv", "b.tsv"]]
        with self.assertRaises(ValueError):
            compare_traces(paths, interval=30, rows=0)


if __name__ == "__main__":
    unittest.main()
