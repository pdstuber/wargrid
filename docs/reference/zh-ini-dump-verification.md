# Zero Hour INI dump tool: verification

Plan: [zh-ini dump plan](../superpowers/plans/2026-11-09-zh-ini-dump.md). Handoff: [zh-ini-dump-prompt.txt](../zh-ini-dump-prompt.txt).

```text
Resume record (updated 2026-11-09, after Task 1)
Branch / base commit / working-tree state: zh-ini-dump / ea1fe2b / Task 1 files uncommitted (coordinator commits)
Last green task / next incomplete task: Task 1 / Task 2 (point readers at the tool)
Changed paths since last commit: tools/zh_ini.py, tools/test_zh_ini.py, docs/reference/zh-ini-dump-verification.md
Last command / cases / checks / failures / exit / marker: python3 -m unittest discover -s tools -p 'test_*.py' (106 tests, 0 failures, exit 0, "OK"); sh tools/run_python_checks.sh (ruff format, ruff check, mypy 34 files, exit 0); python3 tools/zh_ini.py dump (exit 0)
Known red case or blocker: none
Approved decisions, pre-authorizations used, deferred gates: local commit after Task 1 pre-authorized (milestone prompt); gate review (Opus high) and /ponytail-review after Task 2; push and merge wait for the user
Usage so far (python3 tools/session_usage.py <session files>): not measured
Next exact action: Task 2 of the plan
```

No Godot suite run: Task 1 changes no game code (Python tooling and docs only).

## Evidence

| Check | Tree | Result |
|---|---|---|
| `python3 -m unittest discover -s tools -p 'test_*.py'` | zh-ini-dump @ ea1fe2b + Task 1 files | 106 tests, OK, exit 0 (8 new in `test_zh_ini.py`, real-archive test ran, not skipped) |
| `sh tools/run_python_checks.sh` | same | ruff format + ruff check + mypy (34 files) clean, exit 0 |
| `python3 tools/zh_ini.py dump` | same | `ZH_INI entries=135 blocks=12263 fields=324403 out=build/zh_ini/inizh.jsonl`, 0.43 s wall; `git status --short` shows nothing under `build/` |

## Departures from the plan's parsing rules

- A top-level `key = value` line whose key is in `OPENERS` opens a block (`StaticGameLOD = Low` ... `End` in `gamelod.ini`); other top-level `key = value` lines stay one-field blocks. Header tokens split on whitespace and `=`, so that block has kind `StaticGameLOD`, name `Low`.
- `BARE_ONLY` keys (`Turret`, `AltTurret`, `ParticlesAttachedToAnimatedBones`, `ParticleSystem`) open a block only without `=`; with `=` they are plain fields (`Turret = Turret01`, `ParticleSystem = BlackTrail`).
- `path` entries are the opener line with whitespace collapsed (retail aligns `=` with spaces).

## OPENERS

Start list from the plan (14 keys). Method for the additions: parse all 135 entries, fix the entries that raised (`End` outside any block, or block with no `End`), using the key of lines followed by deeper-indented lines as candidates and re-running until every entry balanced. Additions with a first use (entry:line of a block that needs it):

ApplyRandomForce objectcreationlist.ini:3012; Attack objectcreationlist.ini:4210; AttackAreaDecal object/airforcegeneral.ini:575; CreateDebris objectcreationlist.ini:7; CreateObject objectcreationlist.ini:24; DeliverPayload objectcreationlist.ini:4127; DeliveryDecal objectcreationlist.ini:4136; FXListAtBonePos fxlist.ini:5432; FireWeapon objectcreationlist.ini:4202; GridDecalTemplate object/airforcegeneral.ini:6415; ImagePart controlbarscheme.ini:124; InheritableModule default/object.ini:100; LightPulse fxlist.ini:325; Mission campaign.ini:14; OverrideableByLikeKind default/object.ini:109; ParticleSystem fxlist.ini:8; ParticlesAttachedToAnimatedBones object/americacineunit.ini:206; SideInfo default/aidata.ini:67; SideSounds eva.ini:69; SkillSet1 and SkillSet2 default/aidata.ini:73 and 83; SkirmishBuildList default/aidata.ini:405; Sound fxlist.ini:15; Structure default/aidata.ini:406; TargetingReticleDecal object/airforcegeneral.ini:584; TerrainScorch fxlist.ini:616; Tracer fxlist.ini:997; UnitSpecificFX object/airforcegeneral.ini:3698; ViewShake fxlist.ini:591; Window windowtransitions.ini:4; StaticGameLOD gamelod.ini:13; DynamicGameLOD gamelod.ini:76; GeneralPersona0 to 11 challengemode.ini:15 onward; 29 `*RadiusCursor` keys in ingameui.ini:66 onward (listed in `RADIUS_CURSORS`).

All paths above are under `data/ini/`. Final set: 87 keys. Limit: balance proves the set closes every entry, not that no key is wrongly an opener inside a compensating pair; the three hand-verified values pass.

## Example queries (single values)

- `rg -c '"name": "GLAHole"' build/zh_ini/inizh.jsonl` finds the block (1 line).
- `jq -r 'select(.name=="GLAHole") | .fields[] | select(.key=="WorkerRespawnDelay") | "\(.value) line \(.line)"' build/zh_ini/inizh.jsonl` prints `20000 line 143` (cite as `data\ini\object\factionbuilding.ini:143`).
