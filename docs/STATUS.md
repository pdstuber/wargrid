# Status

Where Wargrid stands: packages first, then finished work. Plans for packages: [packages](packages.md). Setup and commands: [development notes](development.md). Labels (confirmed, proposed, provisional, deferred) are kept as the evidence files give them; "(user, DATE)" marks the owner's decision.

## Packages

| Package | Name | State | Plan | Evidence |
|---|---|---|---|---|
| P1 | Tell us what you see | In progress (approved by the user 2026-11-11 night; run started 2026-11-12) | [plan](superpowers/plans/2026-11-11-packages-and-playtest-helper.md), [design](superpowers/specs/2026-11-11-packages-and-playtest-helper-design.md) | [verification](reference/p1-playtest-helper-verification.md) |
| P2 | You clicked, we heard | Planned | [packages](packages.md#the-next-five) | none yet |
| P3 | Camera that follows you | Planned | [packages](packages.md#the-next-five) | none yet |
| P4 | Smooth motion | Planned | [packages](packages.md#the-next-five) | none yet |
| P5 | Smarter paths (toggle) | Planned | [packages](packages.md#the-next-five) | none yet |

## Findings list

Open items that order later packages. P1's blocking focus is card 1; the others go here unless they block play. Cards: [`focus.json`](../game/data/playtest/focus.json).

| Open item | Where recorded | Card | Likely package |
|---|---|---|---|
| M7 exit gate waits on the user's playtest (FRC economy, tunnels and pickups, online FRC) | [M7 verification](reference/m7-verification.md) | `p1-frc-economy`, `p1-frc-tunnels-online` | after P1 |
| Full load for air collectors is not applied; fairness of the asymmetry unchecked | [M7 verification](reference/m7-verification.md) | `p1-frc-economy` | after P1 |
| M6 playtest fixes verified headless only, not seen on screen | [M6 verification](reference/m6-verification.md#playtest-findings-fixed-2026-11-06) | `p1-look-and-m6-fixes` | after P1 |
| Art-lab defaults not yet seen in a real match | [art lab verification](reference/art-lab-verification.md) | `p1-look-and-m6-fixes` | after P1 |
| Controls from a friend's playtest (camera, force-attack, queued orders) | [blueprint §7](blueprint.md#controls-small-task-after-converted-maps-user-2026-11-08-not-designed) | none | P3 and order controls |
| Repeat friend match on the fixed online build; leash-driven return timing | [M5 verification](reference/m5-verification.md), [M5.1 verification](reference/m5.1-verification.md) | none | online packages |
| On Ashfall a seat can still end a match without hitting a building (M8) | [converted maps verification](reference/converted-maps-verification.md), [more maps](reference/more-maps.md#converted-maps-playable-2026-11-09) | none | bots |
| Budget rows exceeded, not loosened | [performance ledger](reference/performance.md) | none | P4, P5 riders |

## Finished work

State phrases come from each item's own verification or evidence file. Several resume records in those files are the last state before a merge (the file says "merge pending"); the merge itself is in `git log`. Design and plan links: [development notes, Start here](development.md#start-here).

| Item | State | Evidence |
|---|---|---|
| M0 foundation | Original exit gate passed; local and remote CI pass; visuals and reference fidelity unverified | [M0](reference/m0-verification.md) |
| M1 vehicle | Implemented; basic visible smoke passes within the recorded scope; reference status `UNVERIFIED_REFERENCE` | [M1](reference/m1-verification.md), [validation](reference/m1-validation.md) |
| M2 groups | Local and remote matrix verified; positive user playability; user accepted deferring remaining gates 2026-11-03 | [M2](reference/m2-verification.md) |
| M3 base and supplies | Headless and cross-OS CI verified; positive user playtest; performance and parity gaps remain | [M3](reference/m3-verification.md), [economy](reference/m3-economy.md) |
| M4 combat | Implemented; user playtest 2026-11-03 ("plays great", two remarks fixed); replays matched on Linux, Windows and local macOS; merged to `main` | [M4](reference/m4-verification.md), [combat](reference/m4-combat.md) |
| M4.1 polish | Merged; user declared the playtest done 2026-11-04, findings recorded in the file | [M4.1](reference/m4.1-verification.md) |
| M5 online | Merged to `main` (`55beae4`); repeat friend match on the fixed build deferred by the user, open | [M5](reference/m5-verification.md) |
| M5.1 friend-match findings | Complete; user playtest done 2026-11-05; leash-driven return timing and repeat friend match open | [M5.1](reference/m5.1-verification.md) |
| M6 teams and full map | Merged to `main` (`de647e1`); user 1v1 playtest findings fixed 2026-11-06, not seen on screen; over-budget rows accepted by the user until the performance spike | [M6](reference/m6-verification.md) |
| M7 factions | Merged to `main` 2026-11-07; CI green and macOS traces matched; exit gate waits on the user's playtest | [M7](reference/m7-verification.md) |
| Post-M7 performance spike | Done and merged to `main` 2026-11-08; remaining work listed in the ledger | [spike](reference/performance-spike.md), [verification](reference/perf-spike-verification.md) |
| More maps (Dry Wells, Broken Crown) | Merged to `main` (`4c98b9a`) 2026-11-08 | [more maps](reference/more-maps.md) |
| Sound spike | Released in 0.9.0; Firefox web check and offline playtest done, online covered by tests only (not heard) | [sound spike verification](reference/sound-spike-verification.md), [evidence](reference/sound-spike.md) |
| Converted maps playable | Merged (`17e7f3d`) 2026-11-09 and released as 0.10.0 (tag `v0.10.0`); user playtest 2026-11-09; Ashfall attack check open (M8) | [verification](reference/converted-maps-verification.md) |
| Art lab spike | Merged to `main` (`874c6a3`) 2026-11-10; A/B winners are production defaults | [art lab verification](reference/art-lab-verification.md) |
| Sim interface and determinism notes | Done 2026-11-10 | [interface](reference/sim-interface.md), [determinism](reference/determinism-rules.md) |
| Native simulation core spike | Done 2026-11-11; CONDITIONAL GO, whole port only | [report](reference/native-sim-spike.md), [verification](reference/native-sim-spike-verification.md) |
| Performance next | Done 2026-11-11 and merged to local `main`; merge and later work in the design answers | [note](reference/performance-next.md), [verification](reference/performance-next-verification.md) |
| GDScript static checks | Tasks 1 and 2 done and merged (`3e3aae0`); Task 3 skipped by the user 2026-11-06 | [plan](superpowers/plans/2026-11-05-gdscript-static-checks.md) |
| Releases (R1) | Done 2026-11-07; v0.6.0 released | [release verification](reference/release-verification.md) |
| Test environment, logo | On `main` (`68bcc0a`, `73b48a4`) 2026-11-07 | [test environment](superpowers/plans/2026-11-07-test-environment.md), [logo](superpowers/plans/2026-11-07-logo.md) |
| Zero Hour INI dump tool | Tasks 1 and 2 and the gate-review fixes done 2026-11-09; on `main` | [verification](reference/zh-ini-dump-verification.md) |
