# R1 release workflow verification

Plan: [release workflow plan](../superpowers/plans/2026-11-06-release-workflow.md).

## Resume record

```text
Resume record (updated 2026-11-06, Task 0 scan done)
Branch / base commit / working-tree state: r1-release cut from m7-factions ed48b2e
Last green task / next incomplete task: Task 0 scan (steps 1-3) / Tasks 1-4 (code), Task 0 step 4 and Task 5 wait for the user
Changed paths since last commit: docs/reference/release-verification.md
Last command / cases / checks / failures / exit / marker: history scan below
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: plan Decisions section (user, 2026-11-06); repo goes public after this scan (user action)
Usage so far: not recorded
Next exact action: Task 1 (version guard)
```

## Task 0: pre-publication history scan (2026-11-06, all refs, tree ed48b2e)

- Secrets: `git log --all -p | rg -i '<token, key and private-key patterns from the plan>'` gave 2 hits, both harmless: the plan's own scan command, and a reference note quoting the header format `Authorization: FlyV1 <token>` with no token. No value of any secret appears in history.
- Secret-bearing file names (`.env`, `.pem`, `.p12`, `id_rsa`) across all 338 paths ever committed: none.
- EA material by file type (`.big .scb .csf .w3d .wnd .str .ini .tga .dds .wav .mp3`): none.
- Largest objects: `game/data/maps/ashfall.json` (about 192 KB, converted from EA's GPL `CnC_Modding_Support` map with EA's copyright line and `data/maps/NOTICE.md`), the blueprint and `test_combat.gd`; nothing unexpected.
- Not covered: content-based detection of EA text inside Wargrid's own files (the reference rules forbid copying it; reviews have checked it per milestone), and secrets in a format none of the patterns match.
- Next: the user makes the repo public and creates the `production` Environment with themselves as required reviewer.
