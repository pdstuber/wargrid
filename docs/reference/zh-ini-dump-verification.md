# Zero Hour INI dump tool: verification

Plan: [zh-ini dump plan](../superpowers/plans/2026-11-09-zh-ini-dump.md). Handoff: [zh-ini-dump-prompt.txt](../zh-ini-dump-prompt.txt).

```text
Resume record (updated 2026-11-09, after gate-review fixes)
Branch / base commit / working-tree state: zh-ini-dump / rebased onto main 1bc8392 (Tasks 1, 2 and the gate-review fixes committed: 0608070, d6ca541, 580402b) / clean
Last green task / next incomplete task: Task 2 / none (stop gate: re-check of the fixes, then /ponytail-review)
Changed paths since last commit: none
Last command / cases / checks / failures / exit / marker: python3 -m unittest tools.test_zh_ini (13 tests, OK, exit 0) on the rebased tree; full sh tools/run_python_checks.sh not rerun (needs tools/.venv, deferred until the overnight benchmarks end)
Known red case or blocker: none. Gate review FAIL on first pass at 39aeab6 (see Gate result)
Approved decisions, pre-authorizations used, deferred gates: user approved rebase onto main and merge into main on 2026-11-09; gate re-check of the fixes not done; push waits for the user
Usage so far (python3 tools/session_usage.py <session files>): not measured
Next exact action: commit the fixes with approval, then /ponytail-review, then stop
```

No Godot suite run: Task 1 changes no game code (Python tooling and docs only).

## Evidence

| Check | Tree | Result |
|---|---|---|
| `python3 -m unittest discover -s tools -p 'test_*.py'` | zh-ini-dump @ ea1fe2b + Task 1 files | 106 tests, OK, exit 0 (8 new in `test_zh_ini.py`, real-archive test ran, not skipped) |
| `sh tools/run_python_checks.sh` | same | ruff format + ruff check + mypy (34 files) clean, exit 0 |
| `python3 tools/zh_ini.py dump` | same | `ZH_INI entries=135 blocks=12263 fields=324403 out=<absolute path>/build/zh_ini/inizh.jsonl` (`out=` prints the resolved path), 0.43 s wall; `git status --short` shows nothing under `build/` |
| Task 2 doc link check (paths, anchors) | zh-ini-dump @ 39aeab6 | plan Spec anchor broken since the blueprint §7 heading rename; fixed |
| `python3 -m unittest discover -s tools -p 'test_*.py'` and `sh tools/run_python_checks.sh` | 39aeab6 + gate-review fixes | see Gate result |
| `python3 tools/zh_ini.py dump` | 39aeab6 + gate-review fixes | `ZH_INI entries=135 blocks=12419 fields=324399` |

## Gate result

FAIL on first pass at 39aeab6: three parser defects (`End Upgrade_X` not closing a block, `Attack = ...` and `FireWeapon = ...` opening blocks) dropped 156 blocks while every check passed, because the real-archive test only proved depth balance. Fixes applied: `End` matches on the first token; `Attack` and `FireWeapon` are `BARE_ONLY`; `//` starts a comment only at line start or after whitespace (URLs in `webpages.ini`); the real-archive test now asserts every unindented line without `=` starts a block (allow-list: the `*ButtonDisabled` fields and bare `ParticleSystem` openers that sit unindented inside blocks) and pins `AudioEvent` at `soundeffects.ini:19` and `Object` at `object/americavehicle.ini:2057`; invented-text tests cover top-level opener, `BARE_ONLY`, path whitespace and `End Foo`; the dump writes a temp file and renames. Dropped as no-effect: `ParticlesAttachedToAnimatedBones`, `Nugget`; `*RadiusCursor` and `GeneralPersona*` became suffix and prefix rules (dump byte-identical).

Re-check 2026-11-09 (night run, Opus, read-only, tree main a5073b4): PASS for the fixes in 580402b. `python3 -m unittest tools.test_zh_ini`: 13 tests OK, `test_real_archive` ran (not skipped). Mutation check in scratch copies, each revert turns the suite red: `End` first token (`test_end_with_trailing_token`, `test_real_archive`); `Attack` and `FireWeapon` `BARE_ONLY` (`test_real_archive`); `//` rule (`test_double_slash_inside_value_kept`); temp-file rename (`test_failed_run_keeps_previous_dump`). The column-0 assertion is wired into `test_real_archive` and pins `AudioEvent` at `soundeffects.ini:19` and `Object` at `americavehicle.ini:2057`. Invented-text tests cover top-level opener with `=`, `BARE_ONLY` with `=`, path whitespace and `End Foo`. Not checked: the "dump byte-identical" claim for the suffix and prefix rules, the 12419 block count (not re-run), doc link anchors. Minor findings, none block: (a) `Attack` and `FireWeapon` `BARE_ONLY` membership is guarded only by the real-archive test, which skips without retail data (CI) (closed 2026-11-10: `test_real_bare_only_keys_are_fields` uses the real sets and fails when either name is dropped, checked by mutation); (b) the `ParticleSystem` entry in `UNINDENTED_IN_BLOCK` probably makes the column-0 check blind in `particlesystem.ini` (fits the limit below, not named there); (c) `dump()` leaves the `.tmp` file behind on exceptions other than `OSError`/`ValueError`, such as Ctrl-C.

Python checks on main a5073b4 (2026-11-09, night run): `sh tools/run_python_checks.sh` exit 0 (34 files formatted, lint clean, mypy no issues in 34 source files, python tests passed); log `~/projects/wargrid-overnight-work/logs/py-main.log`.

Remaining limit: the opener set is still hand-derived. A wrongly listed opener whose block compensates with a missing opener elsewhere, or a nested opener missing from the set inside a block, still balances and passes; the checks catch only mis-nesting that moves a known block start or leaves an unindented block header inside another block.

## Departures from the plan's parsing rules

- A top-level `key = value` line whose key is in `OPENERS` opens a block (`StaticGameLOD = Low` ... `End` in `gamelod.ini`); other top-level `key = value` lines stay one-field blocks. Header tokens split on whitespace and `=`, so that block has kind `StaticGameLOD`, name `Low`.
- `BARE_ONLY` keys (`Turret`, `AltTurret`, `ParticleSystem`, `Attack`, `FireWeapon`) open a block only without `=`; with `=` they are plain fields (`Turret = Turret01`, `ParticleSystem = BlackTrail`).
- `path` entries are the opener line with whitespace collapsed (retail aligns `=` with spaces).

## OPENERS

Start list from the plan (14 keys). Method for the additions: parse all 135 entries, fix the entries that raised (`End` outside any block, or block with no `End`), using the key of lines followed by deeper-indented lines as candidates and re-running until every entry balanced. Additions with a first use (entry:line of a block that needs it):

ApplyRandomForce objectcreationlist.ini:3012; Attack objectcreationlist.ini:4210; AttackAreaDecal object/airforcegeneral.ini:575; CreateDebris objectcreationlist.ini:7; CreateObject objectcreationlist.ini:24; DeliverPayload objectcreationlist.ini:4127; DeliveryDecal objectcreationlist.ini:4136; FXListAtBonePos fxlist.ini:5432; FireWeapon objectcreationlist.ini:4202; GridDecalTemplate object/airforcegeneral.ini:6415; ImagePart controlbarscheme.ini:124; InheritableModule default/object.ini:100; LightPulse fxlist.ini:325; Mission campaign.ini:14; OverrideableByLikeKind default/object.ini:109; ParticleSystem fxlist.ini:8; ParticlesAttachedToAnimatedBones object/americacineunit.ini:206; SideInfo default/aidata.ini:67; SideSounds eva.ini:69; SkillSet1 and SkillSet2 default/aidata.ini:73 and 83; SkirmishBuildList default/aidata.ini:405; Sound fxlist.ini:15; Structure default/aidata.ini:406; TargetingReticleDecal object/airforcegeneral.ini:584; TerrainScorch fxlist.ini:616; Tracer fxlist.ini:997; UnitSpecificFX object/airforcegeneral.ini:3698; ViewShake fxlist.ini:591; Window windowtransitions.ini:4; StaticGameLOD gamelod.ini:13; DynamicGameLOD gamelod.ini:76; GeneralPersona0 to 11 challengemode.ini:15 onward; 29 `*RadiusCursor` keys in ingameui.ini:66 onward (listed in `RADIUS_CURSORS`).

All paths above are under `data/ini/`. Set after the gate fixes: 44 listed keys plus the `*RadiusCursor` suffix and `GeneralPersona*` prefix rules. Limit: balance proves the set closes every entry, not that no key is wrongly an opener inside a compensating pair; the three hand-verified values pass.

## Example queries (single values)

- `rg -c '"name": "GLAHole"' build/zh_ini/inizh.jsonl` finds the block (1 line).
- `jq -r 'select(.name=="GLAHole") | .fields[] | select(.key=="WorkerRespawnDelay") | "\(.value) line \(.line)"' build/zh_ini/inizh.jsonl` prints `20000 line 143` (cite as `data\ini\object\factionbuilding.ini:143`).
