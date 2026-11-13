import argparse
import re
import sys
import tomllib
from pathlib import Path
from typing import Any

from perf_chart import update_ledger, write_all

ROOT = Path(__file__).resolve().parent.parent
BEGIN = "<!-- roadmap:begin -->"
END = "<!-- roadmap:end -->"
STATES = {
    "done": ("✅", "Done"),
    "doing": ("\U0001f528", "In progress"),
    "next": ("⏭", "Next"),
    "planned": ("\U0001f4cb", "Planned"),
    "idea": ("\U0001f4a1", "Idea"),
}
Item = dict[str, Any]


def load(path: Path) -> list[Item]:
    with path.open("rb") as handle:
        return list(tomllib.load(handle)["item"])


def blueprint_keys(text: str) -> list[str]:
    keys = []
    in_section = False
    for line in text.splitlines():
        if line.startswith("## 7."):
            in_section = True
        elif in_section and (line.startswith("## ") or re.match(r"### 7\.\d", line)):
            break
        elif in_section and line.startswith("### "):
            heading = line[4:]
            ident = re.match(r"(M\d+(\.\d+)?|R1)\b", heading)
            keys.append(ident.group(1) if ident else re.split(r" \(| — ", heading)[0])
    return keys


def validate(items: list[Item], blueprint: str) -> list[str]:
    errors = []
    seen: dict[str, int] = {}
    for n, row in enumerate(items, 1):
        label = f"row {n} ({row.get('name')!r})"
        if not str(row.get("name", "")).strip():
            errors.append(f"{label}: name is empty")
        if row.get("state") not in STATES:
            errors.append(f"{label}: state must be one of {', '.join(STATES)}")
        if row.get("wording") not in ("approved", "draft"):
            errors.append(f"{label}: wording must be approved or draft")
        if row.get("wording") == "draft" and len(row.get("candidates", [])) < 2:
            errors.append(f"{label}: a draft row needs at least 2 candidates")
        for key in row.get("blueprint", []):
            if key in seen:
                errors.append(f"{label}: blueprint item {key} is listed twice (also row {seen[key]})")
            seen[key] = n
    if sum(row.get("state") == "next" for row in items) > 1:
        errors.append("more than one row is marked next")
    keys = blueprint_keys(blueprint)
    errors += [f"blueprint item {key} is not covered by any row" for key in keys if key not in seen]
    errors += [
        f"row {n} lists {key}, which is not a blueprint section 7 heading" for key, n in seen.items() if key not in keys
    ]
    return errors


def block(items: list[Item]) -> str:
    done = sum(row["state"] == "done" for row in items)
    rows = [f"| {STATES[str(row['state'])][0]} | {row['name']} | {STATES[str(row['state'])][1]} |" for row in items]
    return "\n".join([f"**{done} of {len(items)} parts done**", "", "| | What | State |", "| --- | --- | --- |", *rows])


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--toml", type=Path, default=ROOT / "docs" / "roadmap.toml")
    ap.add_argument("--readme", type=Path, default=ROOT / "README.md")
    ap.add_argument("--blueprint", type=Path, default=ROOT / "docs" / "blueprint.md")
    ap.add_argument(
        "--check", action="store_true", help="exit 1 if the data is inconsistent or the README block is stale"
    )
    args = ap.parse_args(argv)
    try:
        items = load(args.toml)
    except (tomllib.TOMLDecodeError, KeyError) as err:
        print(f"{args.toml}: {err!r}", file=sys.stderr)
        return 1
    errors = validate(items, args.blueprint.read_text())
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    try:
        readme = update_ledger(args.readme.read_text(), block(items), BEGIN, END)
    except ValueError as err:
        print(err, file=sys.stderr)
        return 1
    if args.check:
        if readme != args.readme.read_text():
            print("README roadmap is stale: run python3 tools/roadmap.py", file=sys.stderr)
            return 1
        return 0
    write_all([(args.readme, readme)])
    return 0


if __name__ == "__main__":
    sys.exit(main())
