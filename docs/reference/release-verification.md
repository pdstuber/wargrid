# R1 release workflow verification

Plan: [release workflow plan](../superpowers/plans/2026-11-06-release-workflow.md).

## Resume record

```text
Resume record (updated 2026-11-06, Tasks 0-4 done and reviewed)
Branch / base commit / working-tree state: r1-release cut from m7-factions ed48b2e; tree clean after the review-fix commit; nothing pushed
Last green task / next incomplete task: Task 4 + final review fixes / Task 0 step 4 and Task 5 (user: repo public, production Environment, fly tokens, version pick, pushes and approval)
Changed paths since last commit: none
Last command / cases / checks / failures / exit / marker: python3 -m unittest discover -s tools OK; sh tools/run_python_checks.sh passes; sh tools/run_lint.sh passes; both workflows parse as YAML (actionlint was denied by the permission classifier, so Actions semantics are unchecked until the first CI run)
Known red case or blocker: unverified until the rehearsal: Godot's built-in ad-hoc signer exporting macOS from a Linux host (fallback: a macos-latest job for that export)
Approved decisions, pre-authorizations used, deferred gates: plan Decisions (user, 2026-11-06); final review (Opus, fresh context) found 0 critical, 2 important (both fixed) and 9 minor (1 raised to important and fixed, 8 deferred below)
Usage so far: not recorded
Next exact action: the user makes the repo public, creates the production Environment (allow tag v* if restricted to selected branches and tags), stores FLY_API_TOKEN_RELAY / FLY_API_TOKEN_WEB, picks the version; then Task 5 step 2 (rc version commit) and the pushes, each with approval.
```

## Task 0: pre-publication history scan (2026-11-06, all refs, tree ed48b2e)

- Secrets: `git log --all -p | rg -i '<token, key and private-key patterns from the plan>'` gave 2 hits, both harmless: the plan's own scan command, and a reference note quoting the header format `Authorization: FlyV1 <token>` with no token. No value of any secret appears in history.
- Secret-bearing file names (`.env`, `.pem`, `.p12`, `id_rsa`) across all 338 paths ever committed: none.
- EA material by file type (`.big .scb .csf .w3d .wnd .str .ini .tga .dds .wav .mp3`): none.
- Largest objects: `game/data/maps/ashfall.json` (about 192 KB, converted from EA's GPL `CnC_Modding_Support` map with EA's copyright line and `data/maps/NOTICE.md`), the blueprint and `test_combat.gd`; nothing unexpected.
- Not covered: content-based detection of EA text inside Wargrid's own files (the reference rules forbid copying it; reviews have checked it per milestone), and secrets in a format none of the patterns match.
- Next: the user makes the repo public and creates the `production` Environment with themselves as required reviewer.

## Final review (2026-11-06, Opus, fresh context, diff ed48b2e..8a72736)

- Fixed: a rerun after a failed first upload left the release as a hidden draft (`gh release edit --draft=false` on the rerun path); the zips did not say where the corresponding source is (GPL-3 §6(d): `README.txt` now links `<repo>/tree/<tag>`, test `test_readme_names_the_source`); macOS 15 removed right-click Open (README now says System Settings > Privacy & Security > Open Anyway, tests in `test_macos_appends_and_keeps_modes`).
- Deferred minors: the relay deploy omits `--dockerfile` (autodetect, unproven); Godot and template pins are duplicated in `tests.yml` and `release.yml` with no guard; a third tag pushed while one run waits for approval cancels the second; the `production` Environment must allow tag `v*` if restricted; the release-version CLI output has no test (a `True` instead of `true` would publish a full release instead of a prerelease); no early check that the web export has `index.wasm` / `index.pck` before the approval; the live web build carries no source link or Godot notices (predates R1, same GPL obligation).
