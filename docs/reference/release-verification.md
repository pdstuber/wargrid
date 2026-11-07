# R1 release workflow verification

Plan: [release workflow plan](../superpowers/plans/2026-11-06-release-workflow.md).

## Resume record

```text
Resume record (updated 2026-11-07, Tasks 0-4 done and reviewed, pre-publication fixes uncommitted)
Branch / base commit / working-tree state: r1-release rebased onto main 025540d on 2026-11-07 (was cut from m7-factions ed48b2e, old tip 1c9ccaf); pre-publication fixes below uncommitted; nothing pushed
Last green task / next incomplete task: Task 4 + final review fixes + pre-publication fixes / Task 0 step 4 and Task 5 (user: repo public, production Environment, fly tokens, version pick, pushes and approval)
Changed paths since last commit: see "Pre-publication review" below
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh 277 / 112765 / 0 / exit 0 / TESTS PASSED 112765; python3 -m unittest discover -s tools 52 OK; run_python_checks, run_lint, run_warnings pass; actionlint 1.7.12 with shellcheck 0.11.0 on both workflows: 0 findings (after quoting the packaging step's extras as a bash array), and tests.yml now runs it as job actions-lint
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

## Pre-publication review (2026-11-07, Opus, fresh context, all refs)

- Rebased: R1 had been cut from `m7-factions`, so it carried 34 M7 commits. Its 8 commits (2 plan commits plus Tasks 0-4) now sit on `main`; a test merge of `m7-factions` afterwards conflicts only in the AGENTS.md and blueprint status lines.
- `main` was red since the Web preset (`MP5 nine presets checked`, CI failing on `main` since 2026-11-06); took the same one-line fix as M7's `7251464` (`presets == 10`).
- Web build: the site now carries `LICENSE`, the map notice and `GODOT_LICENSES.txt` (`release.yml` and `tools/deploy_web.sh`), and the launcher shows a copyright, GPL and no-warranty line with the source link (test N5). Closes the deferred "live web build carries no source link or Godot notices".
- Pins: `test_release_builds_with_the_tested_engine` fails when `release.yml`'s Godot or template pins drift from `tests.yml` (mutation checked). Closes that deferred minor.
- Licence wording: EA's `CnC_Modding_Support` `LICENSE.md` (read via `gh api`, revision `3aad8e4`) says "GPL V3" without "or later", so the map notice, `convert.py` and `ashfall.json` now say GPL-3.0; `refpack.py` keeps "or later", matching EA's `refdecode.cpp` header.
- Wording and privacy: "clone" dropped from AGENTS.md and the verification plan; README opens with what Wargrid is, how to play, status and the AI-agent workflow, and its licence section no longer claims "no EA data"; home paths written as `~/`; a friend's town removed. History still holds the old text. README screenshot `docs/images/skirmish.png` (user request, 2026-11-07): `main` plus R1 in a 1280×720 window, bot against bot on the skirmish map at tick 6000, taken by a scratch script outside the repo.
- History scan of all 282 commits: author email is the noreply address only, no co-author trailers, no secrets, no binary files ever, no EA files.

## Task 5 rehearsal (2026-11-07, tag `v0.6.0-rc.1` on `b70925c`)

- Steps 1-2: `production` Environment with the user as required reviewer (self-review allowed), tag rule `v*`, Environment secrets `FLY_API_TOKEN_RELAY` and `FLY_API_TOKEN_WEB` (names checked, values never seen); version `0.6.0` picked by the user, suite 277 / 112765 / 0 on `0.6.0-rc.1`.
- Step 3: branch CI run 42359699690 green (7 jobs); release run 42360626663: `version`, all `tests` jobs including `actions-lint`, and `build` green, so the macOS export from the Linux runner works; `publish` waited for approval.
- Step 4: approved by the user; fly installs and both deploys skipped (prerelease); prerelease https://github.com/pdstuber/wargrid/releases/tag/v0.6.0-rc.1 with Linux 28,970,230, macOS 61,011,510 and Windows 38,699,279 bytes.
- Step 5: each zip lists `LICENSE`, `NOTICE.md`, `GODOT_LICENSES.txt`, `README.txt`; README links `tree/v0.6.0-rc.1`; the macOS app is ad-hoc signed (`io.github.pdstuber.wargrid`) and `--headless --quit-after 120` exits 0 with no `ERROR` lines.
- Open: step 6 (real release). The builds still carry Godot's icon; the logo design (`docs/superpowers/specs/2026-11-07-logo-design.md`) lands first.

## Logo (2026-11-07, uncommitted on `b70925c`, plan `docs/superpowers/plans/2026-11-07-logo.md`)

- Suite 279 / 112777 / 0 (`TESTS PASSED 112777`, adds LG1 icon = master ×16 nearest and LG2 settings); lint, actionlint and warnings (75 files, `test_logo.gd` included once staged) pass.
- Fresh review (Opus): 1 important fixed (the boot splash stretched to the full window and browser; now `stretch_mode=0`, Web shows `fullsize--false`), 5 minors deferred.
- Local exports with `0.6.0-rc.1`: Web `index.html` has the `og:image` tag, and `index.icon.png` (512) and `index.apple-touch-icon.png` (180) are navy `26364a` at master pixel (8, 8); macOS `icon.icns` 1024 px has the exact outline/rim edge at x 159/160 (nearest-neighbour); Windows exe gains a 16-512 px icon set (512 px navy at (136, 136)).
- Windows warns `Invalid version number "0.6.0-rc.1"` with `modify_resources=true`: the icon still embeds; only version-info strings are skipped for prerelease versions (Windows wants numeric versions). `0.6.0` is valid.
