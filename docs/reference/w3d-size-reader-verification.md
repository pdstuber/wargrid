# W3D size reader: verification

Plan: [W3D size reader plan](../superpowers/plans/2026-11-12-w3d-size-reader.md). Handoff: the night-run prompt (private).

```text
Resume record (updated 2026-11-12, plan written, nothing implemented)
Branch / base commit / working-tree state: w3d-size-reader / main c2ea952 / plan and this file uncommitted
Last green task / next incomplete task: none / Task 1
Changed paths since last commit: docs/superpowers/plans/2026-11-12-w3d-size-reader.md, docs/reference/w3d-size-reader-verification.md
Last command / cases / checks / failures / exit / marker: none on this branch
Known red case or blocker: none (open choices settled: body box leaves out hidden and FX meshes; default archives W3DZH.big, W3DEnglishZH.big, then Generals W3D.big; user, 2026-11-12)
Approved decisions, pre-authorizations used, deferred gates: local commit after each GREEN task, never push (user, 2026-11-12); none used yet; push and merge wait for the user
Usage so far (python3 tools/session_usage.py <session files>): not measured
Next exact action: Task 1, session start steps 1, 2, 4 and the Python baseline
```

No Godot suite run: the plan changes no game code (Python tooling and docs only).

## Evidence

| Check | Tree | Result |
|---|---|---|
| Read-only probe of the retail archives (scripts in `~/projects/wargrid-overnight-work/night-2026-11-13/w3d/`, outside the repo) | archives in place, nothing copied | 8896 `.w3d` entries across `W3DZH.big` (4429), `W3DEnglishZH.big` (7) and Generals `W3D.big` (4556), 96 shared between Zero Hour and Generals; every mesh header 116 bytes, version `0x40002`; every HLOD has one LOD; 5 entries (`art\w3d\uisabotr_*.w3d`, `W3DZH.big`) overrun their chunk sizes; `airngr_skn.w3d` and `avleopard.w3d` exist only in Generals `W3D.big` |

## Gate result

Not reviewed yet (Task 3).
