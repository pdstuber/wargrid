# R1 release workflow verification

Plan: [release workflow plan](../superpowers/plans/2026-11-06-release-workflow.md).

## Resume record

```text
Resume record (updated 2026-11-07, R1 done: Tasks 0-5 and the logo, v0.6.0 released)
Branch / base commit / working-tree state: r1-release rebased onto main 025540d on 2026-11-07 (was cut from m7-factions ed48b2e, old tip 1c9ccaf); merged to main, v0.6.0 released, main = origin/main at 1348b06
Last green task / next incomplete task: Task 5 step 6 (real release) / none
Changed paths since last commit: see "Pre-publication review" below
Last command / cases / checks / failures / exit / marker: sh tools/run_tests.sh 277 / 112765 / 0 / exit 0 / TESTS PASSED 112765; python3 -m unittest discover -s tools 52 OK; run_python_checks, run_lint, run_warnings pass; actionlint 1.7.12 with shellcheck 0.11.0 on both workflows: 0 findings (after quoting the packaging step's extras as a bash array), and tests.yml now runs it as job actions-lint
Known red case or blocker: none; deferred minors listed below
Approved decisions, pre-authorizations used, deferred gates: plan Decisions (user, 2026-11-06); final review (Opus, fresh context) found 0 critical, 2 important (both fixed) and 9 minor (1 raised to important and fixed, 8 deferred below)
Usage so far: not recorded
Next exact action: none for R1; later releases follow [development notes > Release](../development.md#release)
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

## Task 5 step 6: real release (2026-11-07, tag `v0.6.0` on `9f3187a`)

- Tests on `9f3187a` green (8 jobs incl. `actions-lint`); release run 42363471406 approved by the user: relay deployed, web deployed, `og.png` check passed, release published (not a prerelease): https://github.com/pdstuber/wargrid/releases/tag/v0.6.0 with Linux 28,975,119, macOS 60,976,747 and Windows 38,601,890 bytes.
- Live: relay `/health` 200; site serves `og.png` (`image/png`), `LICENSE`, `NOTICE.md`, `GODOT_LICENSES.txt` and `index.icon.png` (200), and the page carries the `og:image` tag.
- `WARGRID_RELAY_URL=wss://wargrid-relay-jvm.fly.dev/ws WARGRID_MATCH_WAIT=600 sh tools/run_netplay.sh match`: `NETPLAY PASSED match 30.4 s` (terminal tick 8242).
- After the tag: `0f5b6d1` keeps large CI artifacts briefly (Windows exe and relay binaries 1 day, release artifacts 7 days); Tests on it green.
- Unverified: the Windows exe icon from the Linux runner (local macOS export embeds it), a link preview in WhatsApp (cache), the boot splash on screen.

## 0.11.0 release (2026-11-12, tag `v0.11.0` on `185521c`)

- Test deploy of `main` (`5bc5876`) to `wargrid-web-test` (fly release v13), `/health` 200; user played about 5 minutes in Firefox: new graphics show, a skirmish runs, F3 numbers sane.
- First tag on `333cf25` (the version commit): run 43303488157 red, N5 `controls 0 and 2 do not overlap` on all four Godot jobs. Cause: the launcher hides `ThisBuild` when the playtest helper defaults off, which is the case for any non-`-dev` version; the test measured the unlaid-out control. Reproduced locally, fixed in the test (`185521c`); suite 795 / 140,756 / 0. The tag was moved with the user's approval (nothing had been built or published). Release step 1 in the [development notes](../development.md#release) now runs the version commit through a branch first.
- Release run 43304990341 on `185521c`: all test jobs and Compare replays green; production approved by the user; relay and web deployed; release published: https://github.com/pdstuber/wargrid/releases/tag/v0.11.0 with Linux 40,956,397, macOS 72,959,663 and Windows 50,585,557 bytes. Notes written by hand (`gh release edit --notes-file`).
- Live: web and relay `/health` 200; `--probe-relay wss://relay.pdstuber.dev/ws` printed `RELAY WELCOME 73`; the user opened the live site in Firefox and saw the new look.
- After: `main` set to `0.12.0-dev` (`0ce6471`).
- Unverified: Chrome, Safari, the desktop zips on any machine, an online match on the live build.

## 0.12.0 release (2026-11-14, tag `v0.12.0` on `79ba46f`)

- Before tagging, the full suite at version `0.12.0` on branch `release-0.12.0` caught `R6 the switch stores off without focus cards`: a release build starts with the playtest switch off, so the old test order stored nothing. Fixed test-only in `70b04d2` (flip from the default twice), green in release and `-dev` builds, red when the save line is removed. Branch CI run 43622809456 green.
- Prerelease first to prove the release step changed for the font licence: tag `v0.12.0-rc.1` on its own commit with `config/version="0.12.0-rc.1"` (`tools/release_version.py` requires the tag to equal the version). Run 43623517769 green; the prerelease has the three zips, and the Linux zip carries `PublicSans-OFL.txt` beside `LICENSE`, `GODOT_LICENSES.txt`, `CREDITS.md`, `NOTICE.md` and `README.txt`.
- Release run 43626231660 on `79ba46f`: all test jobs and Compare replays green; production approved by the user on GitHub; relay and web deployed; release published with the Linux, macOS and Windows zips.
- Live: relay and web `/health` 200.
- After: `main` set to `0.13.0-dev` (`3c729d3`, full suite green on it).
- Unverified: the live site opened by a player after the deploy, the desktop zips on any machine, an online match on the live build, `--probe-relay` against the live relay.
