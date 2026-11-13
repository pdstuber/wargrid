import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import roadmap

PACKAGES = """# Packages

### Day lane

Intro.

| # | Name | Player change | Rider |
|---|---|---|---|
| P1.1 | Laborers that pay | Dock rule. | none |
| P2 | You clicked | Sound. | none |
| P3 | Camera | Edge scroll. | none |

### Night lane

1. **Tighter gates:** watchdog.

### Later

One line each.

1. **Order controls:** control groups, "Orders that feel yours".
2. **Fog of war:** both before batch A.

Not ordered yet: map pack.
"""

STATUS = """## Packages

| Package | Name | State | Plan | Evidence |
|---|---|---|---|---|
| P1 | Tell us what you see | Done: card 1 playtested | plan | ev |
| P1.1 | Laborers that pay | Done (user, 2026-11-13): merged | plan | ev |
| P2 | You clicked | Planned | plan | ev |
| P3 | Camera | Planned | plan | ev |
| night 1 | Tighter gates | Placed | plan | ev |

## Findings list
"""


def run(argv: list[str]) -> int:
    with contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(io.StringIO()):
        return roadmap.main(argv)


class RowsTest(unittest.TestCase):
    def rows(self, packages: str = PACKAGES, status: str = STATUS) -> tuple[list[roadmap.Row], list[str]]:
        return roadmap.rows(packages, status)

    def test_milestones_come_first_as_done(self) -> None:
        rows, errors = self.rows()
        self.assertEqual(errors, [])
        self.assertEqual(len(roadmap.MILESTONES), 7)
        self.assertEqual(rows[:7], [(m, "done") for m in roadmap.MILESTONES])

    def test_done_package_off_the_day_lane_comes_from_status(self) -> None:
        rows, _ = self.rows()
        self.assertEqual(rows[7], ("Tell us what you see", "done"))

    def test_done_package_still_in_the_day_lane_appears_once(self) -> None:
        rows, _ = self.rows()
        self.assertEqual(rows.count(("Laborers that pay", "done")), 1)
        self.assertEqual(rows.index(("Laborers that pay", "done")), 8)

    def test_first_open_day_package_is_next_rest_planned(self) -> None:
        rows, _ = self.rows()
        self.assertEqual([state for name, state in rows if name in ("You clicked", "Camera")], ["next", "planned"])

    def test_later_items_use_bold_names(self) -> None:
        rows, _ = self.rows()
        self.assertEqual(rows[-2:], [("Order controls", "later"), ("Fog of war", "later")])

    def test_later_name_may_stand_alone_without_colon(self) -> None:
        rows, errors = self.rows(PACKAGES.replace("**Fog of war:** both before batch A.", "**Fog of war**"))
        self.assertEqual((rows[-1], errors), (("Fog of war", "later"), []))

    def test_later_item_without_bold_name_is_an_error(self) -> None:
        _, errors = self.rows(PACKAGES.replace("**Fog of war:**", "Fog of war,"))
        self.assertEqual(errors, ["Later item 2 has no **Name:** lead"])

    def test_open_status_package_missing_from_day_lane_is_an_error(self) -> None:
        status = STATUS.replace("| night 1 |", "| P9 | Lost | Planned | plan | ev |\n| night 1 |")
        _, errors = self.rows(status=status)
        self.assertEqual(errors, ["STATUS package P9 is not done and not in the Day lane"])

    def test_night_rows_are_ignored(self) -> None:
        rows, errors = self.rows()
        self.assertEqual(errors, [])
        self.assertNotIn("Tighter gates", [name for name, _ in rows])

    def test_missing_sections_are_errors(self) -> None:
        _, errors = self.rows("# Packages\n")
        self.assertIn("no Day lane table found in packages", errors)
        self.assertIn("no Later items found in packages", errors)


class FilesTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.packages = self.tmp / "packages.md"
        self.status = self.tmp / "STATUS.md"
        self.readme = self.tmp / "README.md"
        self.packages.write_text(PACKAGES)
        self.status.write_text(STATUS)
        self.readme.write_text(f"# T\n\n## Status\n\nText.\n\n{roadmap.BEGIN}\nold\n{roadmap.END}\n\nTail\n")

    def args(self, *extra: str) -> list[str]:
        return ["--packages", str(self.packages), "--status", str(self.status), "--readme", str(self.readme), *extra]

    def test_writes_the_block_and_keeps_the_rest_idempotently(self) -> None:
        self.assertEqual(run(self.args()), 0)
        text = self.readme.read_text()
        self.assertIn("**9 of 13 parts done**", text)
        self.assertTrue(text.startswith("# T\n\n## Status\n\nText.\n\n") and text.endswith("\n\nTail\n"))
        self.assertEqual(run(self.args()), 0)
        self.assertEqual(self.readme.read_text(), text)

    def test_check_passes_when_current_and_fails_when_stale(self) -> None:
        run(self.args())
        self.assertEqual(run(self.args("--check")), 0)
        self.readme.write_text(self.readme.read_text().replace("Camera", "Hand edited"))
        self.assertEqual(run(self.args("--check")), 1)

    def test_check_does_not_write(self) -> None:
        before = self.readme.read_text()
        self.assertEqual(run(self.args("--check")), 1)
        self.assertEqual(self.readme.read_text(), before)

    def test_invalid_data_writes_nothing(self) -> None:
        self.packages.write_text(PACKAGES.replace("**Fog of war:**", "Fog of war,"))
        before = self.readme.read_text()
        self.assertEqual(run(self.args()), 1)
        self.assertEqual(self.readme.read_text(), before)

    def test_missing_marker_exits_1_and_writes_nothing(self) -> None:
        self.readme.write_text("# T\n")
        self.assertEqual(run(self.args()), 1)
        self.assertEqual(self.readme.read_text(), "# T\n")

    def test_duplicate_marker_exits_1_and_writes_nothing(self) -> None:
        both = f"{roadmap.BEGIN}\n{roadmap.END}\n" * 2
        self.readme.write_text(both)
        self.assertEqual(run(self.args()), 1)
        self.assertEqual(self.readme.read_text(), both)


if __name__ == "__main__":
    unittest.main()
