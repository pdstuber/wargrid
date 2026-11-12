# W3D size reader: verification

Plan: [W3D size reader plan](../superpowers/plans/2026-11-12-w3d-size-reader.md). Handoff: the night-run prompt (private).

```text
Resume record (updated 2026-11-13, Task 2 green, uncommitted)
Branch / base commit / working-tree state: w3d-size-reader / main c2ea952 plus plan commit 97737bf and Task 1 commit 40c36a7 / Task 2 edits uncommitted
Last green task / next incomplete task: Task 2 / Task 3 (fresh Opus review)
Changed paths since last commit: tools/zh_w3d.py, tools/test_zh_w3d.py, docs/development.md, docs/guide/13-testing-and-tooling.md, docs/reference/w3d-size-reader-verification.md
Last command / cases / checks / failures / exit / marker: sh tools/run_python_checks.sh / 17 tests in test_zh_w3d.py (4 dump/CLI, 1 real-archive) / ruff format, ruff check, mypy clean / 0 / 0 / PYTHON TESTS PASSED; sh tools/check_public.sh exit 0, PUBLIC CHECK PASSED
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: local commit after each GREEN task, never push (user, 2026-11-12); coordinator commits; push and merge wait for the user
Usage so far (python3 tools/session_usage.py <session files>): not measured
Next exact action: coordinator commits Task 2 ("Add the W3D size dump and its usage note"), then Task 3 (fresh Opus review, read-only)
```

No Godot suite run: the plan changes no game code (Python tooling and docs only).

## Evidence

| Check | Tree | Result |
|---|---|---|
| Read-only probe of the retail archives (scripts in `~/projects/wargrid-overnight-work/night-2026-11-13/w3d/`, outside the repo) | archives in place, nothing copied | 8896 `.w3d` entries across `W3DZH.big` (4429), `W3DEnglishZH.big` (7) and Generals `W3D.big` (4556), 96 shared between Zero Hour and Generals; every mesh header 116 bytes, version `0x40002`; every HLOD has one LOD; 5 entries (`art\w3d\uisabotr_*.w3d`, `W3DZH.big`) overrun their chunk sizes; `airngr_skn.w3d` and `avleopard.w3d` exist only in Generals `W3D.big` |
| Python baseline before Task 1, then after (`sh tools/run_python_checks.sh`, `sh tools/check_public.sh`) | worktree `w3d-size-reader`, plan commit 97737bf plus uncommitted Task 1 | baseline exit 0; after: exit 0, 12 tests in `tools/test_zh_w3d.py` (red first: `ModuleNotFoundError`), ruff and mypy clean, `PYTHON TESTS PASSED`, `PUBLIC CHECK PASSED` |
| Task 2 tests, real dump, gates (`python3 tools/test_zh_w3d.py`, `python3 tools/zh_w3d.py dump`, `sh tools/run_python_checks.sh`, `sh tools/check_public.sh`) | worktree `w3d-size-reader`, Task 1 commit 40c36a7 plus uncommitted Task 2 | red first (`AttributeError`, no `DEFAULT_ARCHIVES`); then 17 tests OK including `test_real_archives` (not skipped; 8896 entries, 5 skips all `uisabotr_`, pinned Leopard, Ranger skin and barracks values within 0.01); real dump exit 0: entries=8896 rows=7746 meshes=70542 skipped=5, output only under `build/zh_w3d/`, `git status` shows nothing under `build/`; python checks exit 0 `PYTHON TESTS PASSED`; public check exit 0 `PUBLIC CHECK PASSED` |
| Archive hashes (`shasum -a 256`, archives read in place) | local retail install | `W3DZH.big` e308c3aeb49d023ffd98b50400f24643a782a68ac4d2e53171c17fc45d73fdc6; `W3DEnglishZH.big` f5d164d1e294f26744e2b87ecfbe13e68affaf5ceb4cf12f43005beb8f54defd; Generals `W3D.big` 87727b698089cdc32bc378b1746bf315c2a920d5df33cace0d7085e027b67d36 |

## Gate result

Not reviewed yet (Task 3).
