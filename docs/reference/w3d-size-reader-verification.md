# W3D size reader: verification

Plan: [W3D size reader plan](../superpowers/plans/2026-11-12-w3d-size-reader.md). Handoff: the night-run prompt (private).

```text
Resume record (updated 2026-11-13, Task 1 green, uncommitted)
Branch / base commit / working-tree state: w3d-size-reader / main c2ea952 plus plan commit 97737bf / tools/zh_w3d.py and tools/test_zh_w3d.py new (git add -N), this file modified, uncommitted
Last green task / next incomplete task: Task 1 / Task 2
Changed paths since last commit: tools/zh_w3d.py, tools/test_zh_w3d.py, docs/reference/w3d-size-reader-verification.md
Last command / cases / checks / failures / exit / marker: sh tools/run_python_checks.sh / 12 new tests in test_zh_w3d.py / ruff format, ruff check, mypy clean / 0 / 0 / PYTHON TESTS PASSED; sh tools/check_public.sh exit 0, PUBLIC CHECK PASSED
Known red case or blocker: none (open choices settled: body box leaves out hidden and FX meshes; default archives W3DZH.big, W3DEnglishZH.big, then Generals W3D.big; user, 2026-11-12)
Approved decisions, pre-authorizations used, deferred gates: local commit after each GREEN task, never push (user, 2026-11-12); none used yet (coordinator commits); push and merge wait for the user
Usage so far (python3 tools/session_usage.py <session files>): not measured
Next exact action: coordinator commits Task 1 ("Add W3D chunk reader for model sizes"), then Task 2 (dump, CLI, real-archive check, docs)
```

No Godot suite run: the plan changes no game code (Python tooling and docs only).

## Evidence

| Check | Tree | Result |
|---|---|---|
| Read-only probe of the retail archives (scripts in `~/projects/wargrid-overnight-work/night-2026-11-13/w3d/`, outside the repo) | archives in place, nothing copied | 8896 `.w3d` entries across `W3DZH.big` (4429), `W3DEnglishZH.big` (7) and Generals `W3D.big` (4556), 96 shared between Zero Hour and Generals; every mesh header 116 bytes, version `0x40002`; every HLOD has one LOD; 5 entries (`art\w3d\uisabotr_*.w3d`, `W3DZH.big`) overrun their chunk sizes; `airngr_skn.w3d` and `avleopard.w3d` exist only in Generals `W3D.big` |
| Python baseline before Task 1, then after (`sh tools/run_python_checks.sh`, `sh tools/check_public.sh`) | worktree `w3d-size-reader`, plan commit 97737bf plus uncommitted Task 1 | baseline exit 0; after: exit 0, 12 tests in `tools/test_zh_w3d.py` (red first: `ModuleNotFoundError`), ruff and mypy clean, `PYTHON TESTS PASSED`, `PUBLIC CHECK PASSED` |

## Gate result

Not reviewed yet (Task 3).
