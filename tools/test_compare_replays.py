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


if __name__ == "__main__":
    unittest.main()
