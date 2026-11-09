# Zero Hour INI dump tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `python3 tools/zh_ini.py dump` turns every block of the pinned retail `INIZH.big` into a local, gitignored JSONL file with archive entry and line numbers, so agents query Zero Hour data with `rg`/`jq` instead of hand-decoding.

**Architecture:** One small module `tools/zh_ini.py` reuses `load_archive` from `tools/check_reference.py` (BIG reading and the pinned-hash check), parses each `.ini` entry into top-level blocks with their fields and nested sub-block path, and writes one JSON object per top-level block. Tests use invented INI text in a synthetic BIG; a real-archive test runs only when the archive is present.

**Tech Stack:** Python 3 standard library only; `unittest`; ruff and mypy via `sh tools/run_python_checks.sh`.

**Spec:** [blueprint §7 "Zero Hour data dump tool"](../../blueprint.md#zero-hour-data-dump-tool-small-task-user-2026-11-09-before-ground-batch-a-planning-tool-done-0608070-readers-pointed-2026-11-09) (user, 2026-11-09). Handoff: [docs/zh-ini-dump-prompt.txt](../../zh-ini-dump-prompt.txt). Resume record and evidence: `docs/reference/zh-ini-dump-verification.md` (created by Task 1).

## Global Constraints

- EA data never enters the repository: the dump is written under `build/` (already gitignored) and is never committed; tests contain only Wargrid-invented INI text. Single values with path:line may be quoted in docs, never decoded blocks (AGENTS.md, reference handling; blueprint §1).
- Default archive: `$HOME/CnC/run/Command & Conquer Generals - Zero Hour/INIZH.big`; default output: `build/zh_ini/inizh.jsonl` relative to the repo root. The pinned hash is checked unless `--skip-hash` is given (same flag name as `check_reference.py`).
- Line numbers are 1-based and refer to the decoded entry text exactly as `load_archive` returns it, so a finding is citable as `<entry>:<line>` (entry names are lower-case with backslashes, e.g. `data\ini\gamedata.ini`).
- Standard library only; typed code that passes `sh tools/run_python_checks.sh`; tests run with `python3 -m unittest discover -s tools -p 'test_*.py'`.
- No change to game code, relay, protocol or any trace.

## Review Focus

- **`End` in any case and with a trailing comment** (`END`, `End ; done`): must close the current block (retail uses `End` 62,390 times and `END` 1,075 times). Test in Task 1.
- **Comments:** `;` and `//` to end of line are stripped from keys and values; a line that is only a comment produces no field. Test in Task 1.
- **Nested sub-blocks** (a module such as `Behavior = SomeUpdate ModuleTag_01` ... `End` inside an `Object`): fields inside carry the opener line in `path`; the nested `End` must not close the outer block. Test in Task 1, plus the real-archive balance check.
- **Unbalanced input** (missing `End` at end of file, or a stray `End` at top level): the parser raises `ValueError` naming entry and line; it never silently drops data. Test in Task 1.
- **Header tokens beyond the name** (`ObjectReskin NewName OldName`, a block with no name such as `GameData`): kept as `name` (or `null`) plus `args`. Test in Task 1.

---

## Risk first

1. **Telling nested-block openers from plain fields.** Retail INI has no syntax that marks an opener; Zero Hour's parser knows it per field. The parser uses an explicit `OPENERS` set of keys, filled from the real archive and checked by the balance test (every entry ends at depth 0, no stray `End`). If a consistent set cannot be found, that is a stop condition, not a guess.
2. **EA text leaking into the repo** through fixtures or docs. Fixtures are invented; the real-archive test asserts only single values at a line.

## File structure

- Create `tools/zh_ini.py`: `parse_entry`, `dump`, `main` (CLI). One responsibility: INI text to JSONL records.
- Create `tools/test_zh_ini.py`: unit tests on invented text; real-archive test skipped when the archive is missing.
- Modify docs in Task 2 only.

---

### Task 1: Parser, dump command and real-archive check

**Files:**
- Create: `tools/zh_ini.py`
- Create: `tools/test_zh_ini.py`
- Create: `docs/reference/zh-ini-dump-verification.md` (resume record block from `docs/milestone-prompt.md`, then evidence rows)

**Interfaces:**
- Consumes: `check_reference.load_archive(path: str, check_hash: bool = True) -> dict` (entry name to decoded text); test helper `test_check_reference.big(files: dict) -> bytes` builds a synthetic BIG from `{entry name: text}` (reuse it, or write an equivalent local helper if importing it is awkward).
- Produces:
  - `Field = TypedDict("Field", {"line": int, "key": str, "value": str, "path": list[str]})`
  - `Block = TypedDict("Block", {"entry": str, "line": int, "end_line": int, "kind": str, "name": str | None, "args": list[str], "fields": list[Field]})`
  - `parse_entry(entry: str, text: str) -> list[Block]`
  - `dump(files: dict[str, str], out: Path) -> tuple[int, int, int]` writes one `json.dumps(block, ensure_ascii=False)` per line, entries in sorted name order, blocks in file order; returns `(entries, blocks, fields)`.
  - `main(argv: list[str], out=sys.stdout) -> int`: `dump [archive] [--out PATH] [--skip-hash]`; prints one line `ZH_INI entries=<n> blocks=<n> fields=<n> out=<path>`; returns 0, or 1 with the error on stderr.

Parsing rules (the decisions the implementer cannot infer):
- A top-level block starts at a non-blank, non-comment line outside any block: `kind` is its first token, `name` the second (or `None`), `args` the rest. A top-level line containing `=` outside a block is a field of no block: record it as a block with `kind` = its key, `name` = None, `end_line` = `line`, one field.
- Inside a block, a line whose stripped, comment-free text equals `end` (case-insensitive) closes the innermost open block.
- Inside a block, a line opens a nested block when its key (text before `=`, or the first token if there is no `=`) is in `OPENERS`; its full comment-free stripped text is pushed on `path`. Any other line is a field: `key` before `=` (stripped), `value` after it (stripped); without `=`, `key` = first token and `value` = the rest.
- `OPENERS: frozenset[str]` is a module constant, case-sensitive as retail writes it. Start from the module keys seen in retail objects (`Draw`, `Behavior`, `Body`, `ClientUpdate`, `ArmorSet`, `WeaponSet`, `ConditionState`, `DefaultConditionState`, `TransitionState`, `UnitSpecificSounds`, `Prerequisites`, `Turret`, `AltTurret`, `Nugget`) and extend it until the balance test passes; record the final list and how each addition was found in the verification file.

- [ ] **Step 1: Write the failing unit tests** in `tools/test_zh_ini.py` on invented text, for example an entry `data\ini\test.ini` holding:

```text
; header comment
Widget Alpha
  Speed = 12 ; trailing comment
  Module = SpinUpdate Tag_01
    Rate = 3 // other comment
  END
  Label   Hello World
End
Gadget
  Size = 4
End ; closing comment
Reskin Beta Alpha
End
```

  with `OPENERS` patched to include `Module` for the test. Assertions:
  - `test_blocks_and_lines`: three blocks; Widget `line` 2, `end_line` 8, `name` "Alpha", `args` []; Gadget `line` 9, `end_line` 11, `name` None; Reskin `line` 12, `name` "Beta", `args` ["Alpha"].
  - `test_fields_and_comments`: Widget has exactly three fields: `Speed`/"12" line 3 path []; `Rate`/"3" line 5 path ["Module = SpinUpdate Tag_01"]; `Label`/"Hello World" line 7 path []. Gadget: `Size`/"4" line 10.
  - `test_end_case_and_comment`: `END` and `End ; closing comment` both close.
  - `test_unbalanced_raises`: text ending inside a block raises `ValueError` whose message contains the entry and the opening line; a top-level `End` raises naming its line.
  - `test_dump_and_cli`: write a synthetic BIG with the fixture, run `main(["dump", path, "--out", tmp, "--skip-hash"])`, assert exit 0, the summary line `ZH_INI entries=1 blocks=3 fields=…`, and that every output line is valid JSON with keys `entry,line,end_line,kind,name,args,fields`.
  - `test_missing_archive`: a missing path returns 1 with a message on stderr, no output file.

- [ ] **Step 2: Run them to verify they fail**

Run: `python3 -m unittest tools.test_zh_ini -v` (from the repo root; or `discover -s tools -p 'test_zh_ini.py'`)
Expected: FAIL / ImportError (`zh_ini` does not exist).

- [ ] **Step 3: Implement `parse_entry`, `dump`, `main` and `OPENERS` in `tools/zh_ini.py`** following the rules above. A stack of open nested-block texts; top-level block appended when its `End` is read.

- [ ] **Step 4: Run the unit tests and the Python checks**

Run: `python3 -m unittest discover -s tools -p 'test_*.py'` and `sh tools/run_python_checks.sh`
Expected: all OK, ruff and mypy clean.

- [ ] **Step 5: Add the real-archive test** `test_real_archive` in `tools/test_zh_ini.py`, skipped with `unittest.skipUnless` when the default archive path does not exist. It parses every entry of the real archive and asserts:
  - no `ValueError` from any of the 135 `.ini` entries (balance check);
  - `data\ini\gamedata.ini` has a field `ValuePerSupplyBox` with value `75` at line 248;
  - `data\ini\object\factionbuilding.ini` block `Object GLAHole` has field `WorkerRespawnDelay` (value starting `20000`) at line 143 whose `path` has one element starting `Behavior = RebuildHoleBehavior`;
  - `data\ini\object\civilianbuilding.ini` has a field `StartingBoxes` with value starting `400` at line 406.
  These three are single values verified by hand on 2026-11-09 (session notes; `docs/reference/design-answers-2026-11-08.md` batch A section); if one fails, the line numbering or the opener rule is wrong, not the pin.

- [ ] **Step 6: Run it, extend `OPENERS` until it passes, then run the real dump**

Run: `python3 -m unittest discover -s tools -p 'test_zh_ini.py' -v`, then `python3 tools/zh_ini.py dump`
Expected: `test_real_archive` passes (not skipped on this machine); the dump prints `ZH_INI entries=135 blocks=<n> fields=<n> out=build/zh_ini/inizh.jsonl`; `git status --short` shows nothing under `build/`.

- [ ] **Step 7: Record evidence** in `docs/reference/zh-ini-dump-verification.md`: resume record; the `ZH_INI` line, wall time of the dump, the final `OPENERS` list with how each non-starting key was found (entry:line of a first use), the test counts, and two example queries that work on the dump (one `rg`, one `jq`; output not pasted beyond single values).

- [ ] **Step 8: Run all checks again**: `python3 -m unittest discover -s tools -p 'test_*.py'`, `sh tools/run_python_checks.sh`. Expected: OK. Coordinator commits (pre-authorized local commit): `Add Zero Hour INI dump tool`.

### Task 2: Point every reader at the tool

**Files:**
- Modify: `AGENTS.md` (Reference handling: one sentence: query Zero Hour INI data through `python3 tools/zh_ini.py dump` and the local `build/zh_ini/inizh.jsonl`, never a hand-rolled decoder)
- Modify: `docs/development.md` (Setup and commands: the dump command, its output path, that it needs the local archive and is never committed)
- Modify: `docs/milestone-prompt.md` (Planning rules: Zero Hour values come from the dump, cited as entry:line)
- Modify: `docs/questions/RULES.md` (retail config line: use the dump instead of decoding with `read_big`)
- Modify: `docs/reference/zero-hour-parity-harness.md` and `docs/reference/zero-hour-verification.md` (one line each where they describe reading retail INI)
- Modify: `docs/blueprint.md` §7 "Zero Hour data dump tool": status to done with the commit, and one line that the ground batch A handoff, when written, must name the tool (no batch A handoff exists yet)

**Interfaces:** consumes the command line and output path from Task 1 exactly as implemented.

- [ ] **Step 1: Make the edits** with the Edit tool, one sentence each, linking rather than repeating; keep the AGENTS.md line short.
- [ ] **Step 2: Check links and paths** in the changed files (relative links resolve, anchors exist); `rg -n "read_big|hand-rolled|decode" AGENTS.md docs/questions/RULES.md docs/milestone-prompt.md` shows no remaining instruction to hand-decode.
- [ ] **Step 3: Run** `python3 -m unittest discover -s tools -p 'test_*.py'` once more (docs only, sanity). Update the resume record. Coordinator commits: `Point readers at the Zero Hour INI dump`.

## Stop gate and exit

**Exit gate (end of Task 2):** an Opus (high) gate review of the branch diff against this plan and the Global Constraints (EA data, line numbers, opener rule), findings fixed or recorded; then `/ponytail-review` on the diff. Then stop: push and merge wait for the user.

**Stop conditions** (notify, ask, wait): no consistent `OPENERS` set makes every entry balance; any test would need EA text in the repo; the pinned hash check fails on this machine; a pinned value in Step 5 disagrees with the archive.
