import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import roadmap

BLUEPRINT = """## 7. Milestones
### M0 — Skeleton
### M4.1 — Polish (done)
### Ground batch A (after avoidance; not designed)
### Later
### 7.1 M0 implementation plan
### Not a milestone
"""


def item(
    name: str = "Move units", state: str = "done", keys: tuple[str, ...] = ("M0",), **extra: object
) -> dict[str, object]:
    return {"name": name, "state": state, "blueprint": list(keys), "wording": "approved", **extra}


def run(argv: list[str]) -> int:
    with contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(io.StringIO()):
        return roadmap.main(argv)


class RenderTest(unittest.TestCase):
    def test_block_has_headline_and_rows(self) -> None:
        items = [item("Move units"), item("Fog of war", "idea", ("M7.9",)), item("Art pass", "next", ("M7.5",))]
        self.assertEqual(
            roadmap.block(items),
            "**1 of 3 parts done**\n\n| | What | State |\n| --- | --- | --- |\n"
            "| ✅ | Move units | Done |\n| \U0001f4a1 | Fog of war | Idea |\n| ⏭ | Art pass | Next |",
        )

    def test_all_states_have_an_icon_and_a_label(self) -> None:
        self.assertEqual(set(roadmap.STATES), {"done", "doing", "next", "planned", "idea"})
        self.assertEqual(roadmap.STATES["planned"], ("\U0001f4cb", "Planned"))


class ValidateTest(unittest.TestCase):
    def errors(self, items: list[dict[str, object]], blueprint: str = BLUEPRINT) -> list[str]:
        return roadmap.validate(items, blueprint)

    def full(self) -> list[dict[str, object]]:
        return [
            item(keys=("M0",)),
            item("Polish", keys=("M4.1",)),
            item("More units", "idea", ("Ground batch A", "Later")),
        ]

    def test_consistent_data_has_no_errors(self) -> None:
        self.assertEqual(self.errors(self.full()), [])

    def test_unknown_state(self) -> None:
        items = self.full()
        items[0]["state"] = "soon"
        self.assertTrue(any("state" in e for e in self.errors(items)))

    def test_two_next_rows(self) -> None:
        items = self.full()
        items[0]["state"] = items[1]["state"] = "next"
        self.assertTrue(any("next" in e for e in self.errors(items)))

    def test_draft_needs_two_candidates(self) -> None:
        items = self.full()
        items[0].update(wording="draft", candidates=["only one"])
        self.assertTrue(any("candidates" in e for e in self.errors(items)))
        items[0]["candidates"] = ["a", "b"]
        self.assertEqual(self.errors(items), [])

    def test_bad_wording_value_and_empty_name(self) -> None:
        items = self.full()
        items[0]["wording"] = "maybe"
        items[1]["name"] = " "
        errors = self.errors(items)
        self.assertTrue(any("wording" in e for e in errors))
        self.assertTrue(any("name" in e for e in errors))

    def test_blueprint_item_missing_from_the_data(self) -> None:
        errors = self.errors(self.full()[:2])
        self.assertTrue(any("Ground batch A" in e and "not covered" in e for e in errors))

    def test_unknown_blueprint_key_in_the_data(self) -> None:
        items = self.full()
        items[0]["blueprint"] = ["M0", "M42"]
        self.assertTrue(any("M42" in e for e in self.errors(items)))

    def test_blueprint_key_in_two_rows(self) -> None:
        items = self.full()
        items[1]["blueprint"] = ["M4.1", "M0"]
        self.assertTrue(any("M0" in e and "twice" in e for e in self.errors(items)))

    def test_blueprint_keys_stop_at_the_numbered_subsections(self) -> None:
        self.assertEqual(roadmap.blueprint_keys(BLUEPRINT), ["M0", "M4.1", "Ground batch A", "Later"])


class FilesTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.toml = self.tmp / "roadmap.toml"
        self.readme = self.tmp / "README.md"
        self.blueprint = self.tmp / "blueprint.md"
        self.blueprint.write_text(BLUEPRINT)
        self.toml.write_text(
            '[[item]]\nname = "Move units"\nstate = "done"\nblueprint = ["M0"]\nwording = "approved"\n\n'
            '[[item]]\nname = "Polish"\nstate = "done"\nblueprint = ["M4.1"]\nwording = "approved"\n\n'
            '[[item]]\nname = "More units"\nstate = "idea"\nblueprint = ["Ground batch A", "Later"]\nwording = "approved"\n'
        )
        self.readme.write_text(f"# T\n\n## Status\n\nText.\n\n{roadmap.BEGIN}\nold\n{roadmap.END}\n\nTail\n")

    def args(self, *extra: str) -> list[str]:
        return ["--toml", str(self.toml), "--readme", str(self.readme), "--blueprint", str(self.blueprint), *extra]

    def test_writes_the_block_and_keeps_the_rest_idempotently(self) -> None:
        self.assertEqual(run(self.args()), 0)
        text = self.readme.read_text()
        self.assertIn("**2 of 3 parts done**", text)
        self.assertTrue(text.startswith("# T\n\n## Status\n\nText.\n\n") and text.endswith("\n\nTail\n"))
        self.assertEqual(run(self.args()), 0)
        self.assertEqual(self.readme.read_text(), text)

    def test_check_passes_when_current_and_fails_when_stale(self) -> None:
        run(self.args())
        self.assertEqual(run(self.args("--check")), 0)
        self.readme.write_text(self.readme.read_text().replace("Polish", "Hand edited"))
        self.assertEqual(run(self.args("--check")), 1)

    def test_check_does_not_write(self) -> None:
        before = self.readme.read_text()
        self.assertEqual(run(self.args("--check")), 1)
        self.assertEqual(self.readme.read_text(), before)

    def test_invalid_data_writes_nothing(self) -> None:
        self.toml.write_text(self.toml.read_text().replace('"done"', '"soon"', 1))
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

    def test_malformed_toml_and_missing_table_exit_1(self) -> None:
        for bad in ("[[item", "x = 1\n"):
            self.toml.write_text(bad)
            self.assertEqual(run(self.args()), 1)

    def test_blueprint_keys_stop_at_the_next_top_level_section(self) -> None:
        text = "## 7. Milestones\n### M0 — A\n## 8. Other\n### M9 — Not a milestone\n"
        self.assertEqual(roadmap.blueprint_keys(text), ["M0"])


class RealFilesTest(unittest.TestCase):
    def test_readme_roadmap_matches_the_data_and_the_blueprint(self) -> None:
        self.assertEqual(run(["--check"]), 0)


if __name__ == "__main__":
    unittest.main()
