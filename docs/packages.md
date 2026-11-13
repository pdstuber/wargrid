# Packages

What comes when. Work after M7 ships as small packages: player packages run by day, go to the test app and get one short playtest; engine packages run headless at night. [STATUS](STATUS.md) holds each package's state, the blueprint holds design scope ([§7](blueprint.md#7-milestones-and-exit-criteria)), the [packages design](superpowers/specs/2026-11-11-packages-and-playtest-helper-design.md) holds the rules. Order and contents: user, 2026-11-11 night, reviewed 2026-11-13 ([design answers](reference/design-answers-2026-11-08.md#package-review-user-2026-11-13)).

## Roadmap

### Now

- **P1.1 Laborers that pay:** done: the c1 dock rebuild is merged, card 1 replayed fine and F2 (Laborer back pack) is done (state in [STATUS](STATUS.md#packages)).
- **Card 3 sitting:** P1's card 3 (`p1-look-and-m6-fixes`) in any free 15 minutes on 0.11.0, helper switched on in the launcher.

### Day lane

Player packages, in order. Exit for each: its focus card playtested, problems in the card's focus fixed, other findings on the [findings list](STATUS.md#findings-list).

| # | Name | Player change | Rider |
|---|---|---|---|
| P1.1 | Laborers that pay | c1 dock rule: collectors at one pile overlap except for a short exclusive window, so FRC income is no longer capped per pile ([dock-hold note](reference/dock-hold-experiment.md)); F2 Laborer back pack shorter and wider. Card: replay card 1 (`p1-frc-economy`) | none |
| P2 | You clicked, we heard | Acknowledgement sound per accepted order; F4 music shuffle; menu quick wins (launcher sections, You/Bot faction rows, relay URL and `?relay=` override in prerelease builds only, join link, paste fix for web text fields); F1 scale legend in the after-match form | Browser against native team-match measurement; late-game 3v3 canary (report-only); a recorded playtest match as a benchmark row |
| P2.1 | New launcher | Minimal launcher in today's grey look ([Play](images/launcher-mockups/minimal-play-bot.webp), [all screens](images/launcher-mockups/), [decisions](reference/design-answers-2026-11-08.md#new-launcher-user-2026-11-13)): sidebar Play, Join, Settings, Credits, version at the bottom; labels above fields; Play: your faction, an opponent slot switched between Bot (its faction) and Friend (open slot, advanced settings in test builds only), map, one primary button (Start match, or Create match with a hint); Join: match code and your faction; a waiting view after Create match (invite link with Copy, both player slots, map, Cancel match); the launcher opens on Play with Bot and the last settings preselected; Settings: audio and the playtest switch. No Back button, no mode-card start screen, no controls for features that do not exist (bot level and play style come with the bot levels). Later packages restyle it into the [fancy set](images/launcher-mockups/fancy-play-bot.webp) (flat dark look, map preview with a rendered thumbnail, own faction emblems, bot level and play style) | Headless layout tests at 1280x720 and 1920x1080 (user, 2026-11-13) |
| P2.2 | Quick rematch | A lobby waiting for player 2 survives minutes of silence, so a host can switch apps to send the link (the 10 s rule stays for running matches); a "Play again" button after a match keeps both players in the same room with no new link. Relay change with conformance cases; relay deploy needs approval | P2's hidden-tab check as the before row; coordinate with Relay guards (lobby expiry caps the wait) (user, 2026-11-13) |
| P3 | Camera that follows you | Edge scrolling, right-drag pan, Space to last alert, H to Command Center | Movement design, ending with movement cut into packages of 2 to 3 days each |
| P4 | Smooth motion | Interpolation rework behind a toggle key | Seeded fuzz and invariant test, before movement; perf overlay `split %` in Safari against Firefox |
| P5 | Smarter paths (toggle) | First movement package as cut by P3's design, behind a toggle key | Set by P3's design |

### Night lane

Engine packages, in order, at most one between two day packages. Headless, unattended ([night run](night-run.md)), no focus card. Details under [package notes](#package-notes).

1. **Sim quick wins:** splash index, per-tick hash ring and desync bisect tool, `step.advance` split, scaling row. No trace re-pin.
2. **Flatter worst ticks:** bot decisions staggered by seat, path cap by route cells. One trace re-pin.
3. **Relay guards:** lead bound, hello deadline, lobby expiry, relay hash comparison, per-IP limits, byte fields in `MATCH END`.
4. **Adaptive input delay:** one agreed delay in-band, adopted only on a measured gain; if adopted, one online session with a friend (P1's card 2 with it) before it becomes the default.

### Later

One line each; scope in blueprint §7. In this order (approved with the packages design, 2026-11-11):

1. Order controls, "Orders that feel yours": control groups (Zero Hour layout), Shift-queued move points, Shift-placed building queue, Ctrl force-attack, idle-builder key. Rider: forward budget table from P2's measurement.
2. Movement packages after P5, until the toggle becomes the default; then the golden scenarios, with browser digests (simulation review X7).
3. Minimal real HUD (credits and power, production buttons with hotkeys, minimap rectangle, base-under-attack alert), with controller flattening (FIX-6) and the `SimPump` seam (worker thread stage 1). The worker thread itself only after a browser measurement shows a main-thread win ([worker thread design](superpowers/specs/2026-11-12-worker-thread-design.md)).
4. Unit avoidance behind a toggle.
5. Fog of war and one targetability predicate, both before ground batch A.
6. Ground batch A, in packages of two or three units; the roster stays at four per faction until three recorded 1v1 matches are reviewed.
7. Art pass (F6 docks and piles, F7 Chinook look).
8. Ground batch B.
9. Bots.
10. 3v3 online.

Not ordered yet (placed 2026-11-12): map pack, Is Wargrid healthy, What's new, Steam Deck controls spike (after P3).

Matching with friends beyond P2.2 (user, 2026-11-13): a permanent friend link and other modern, easy ways to meet a friend are re-explored with the M9 lobby; quick match for strangers comes after M9. No integration with any chat or storefront service (Discord, Steam): the link and code work through any channel.

## How a package runs

1. Plan it; a day package gets a drafted focus card.
2. The user approves plan and card.
3. Day: deploy to the test app (needs approval) and play one 15 to 20 minute session with the helper; the session file replays headless (`sh tools/replay_session.sh`). Night: run unattended per [night run](night-run.md); the user reviews the morning summary.
4. Problems in the package's focus are fixed before the next package; other findings go on the [findings list](STATUS.md#findings-list), which orders later packages.

## Package notes

Scope cuts agreed when each package was placed. Numbers and their sources stay in the linked reviews.

- **P1 (done):** three focus cards in [`game/data/playtest/focus.json`](../game/data/playtest/focus.json). Card 1 (`p1-frc-economy`) was the blocking focus; cards 2 (`p1-frc-tunnels-online`) and 3 (`p1-look-and-m6-fixes`) feed the findings list unless they block play. [Plan](superpowers/plans/2026-11-11-packages-and-playtest-helper.md), [verification](reference/p1-playtest-helper-verification.md).
- **P1.1 Laborers that pay (user, 2026-11-13):** c1 merged to `main` 2026-11-13; plan and resume record (`docs/superpowers/plans/2026-11-12-c1-dock-rebuild.md`, `docs/reference/c1-dock-rebuild-verification.md`). F2 lands as its own commit after the c1 tasks, because the c1 plan stops on any presentation change. The extra-cell re-measure follows the merge.
- **P2 additions (user, 2026-11-13):** the order hook is new (today only buttons play the `click` cue, `sound_player.gd`); menu quick wins (user, 2026-11-12) is a grouping, not a redesign; the canary and the recorded match row moved here from P5 because they feed P3's movement design (audit answer: canary before the movement design). Design and plan approved 2026-11-13 (user): spoken line per unit role at click time ([design](superpowers/specs/2026-11-13-p2-you-clicked-we-heard-design.md), [plan](superpowers/plans/2026-11-13-p2-you-clicked-we-heard.md)). Focus card `p2-you-clicked` ("Every order heard") is first in [`game/data/playtest/focus.json`](../game/data/playtest/focus.json); the three P1 cards follow unchanged.
- **Map pack (user, 2026-11-12):** two or three more maps through `tools/zh_map/convert.py` ([more maps](reference/more-maps.md)), the user picks from a short list; tech buildings stay skipped.
- **Is Wargrid healthy (user, 2026-11-12):** relay `/metrics` (rooms, players, round trip, desyncs) into fly's hosted Grafana, plus a small public traffic light on the web page. Rider (user, 2026-11-13): deploys (manual and release workflow) wait until the relay reports 0 rooms, with a timeout and an override.
- **What's new (user, 2026-11-12):** one player-facing line per shipped package in a changelog file, shown in the menu and on the web page.
- **Sim quick wins** (user, 2026-11-13, [simulation review](reference/simulation-reference-review.md#review-2026-11-13)): no trace re-pin. Splash victims from a small index built from live positions right before `Combat.fire`, only on ticks with a splash shot, and also serving `Combat.fire_defences` (it runs after `fire` has removed its dead, so removed objects must be skipped). Today every shot of a weapon with a blast radius scans every object (contact row: splash zone max 8.8 ms against a `combat_fire` max of 10.3 ms, 19.8 against 23.3 in warm-up); the query window comes from the largest blast (the pickup cannon's infantry blast gives ±4.05, up to 3 × 3 grid cells). Victims stay sorted by id. Desync localisation: a ring of the last 64 per-tick hashes (one combined hash per tick, not the per-subsystem sync rings the netplay review deferred) over units, buildings (hp, progress), sources (amount), player credits and the RNG, floats by raw bits (`core_check` covers only units and credits, quantised to 1/1024), carried in the desync report; plus the bisect tool, moved here from Relay guards: replay a desync report's command log headless with a hash on every tick and diff the snapshots at the first divergent tick (glue over `compare_replays.py` and the oracle path). Split the `step.advance` profiler zone (movement, containers, horde bonus, salvage). A report-only scaling row (the combat open layout at 50, 100, 200, 400 and 800 units; zones that grow faster than the unit count), run before and after the splash index. One profiler pass on the hordes300 `combat_fire` worst tick (5.4 ms with no splash weapon behind it; evidence only). One ledger row.
- **Flatter worst ticks** (user, 2026-11-13, [simulation review](reference/simulation-reference-review.md#review-2026-11-13)): one trace re-pin for both. Bot decisions staggered by seat (`tick % 30 == seat % 30`) instead of all six on one tick (7.6 ms worst tick on the team match), each bot reading a light state (view rows plus the fields bots use) or one snapshot reused across the window (a few ticks stale for later seats), because a full `snapshot()` per seat would add about 0.1 ms to the mean tick (0.17 ms at the worst snapshot cost); this also moves the 1v1 bot, so 1v1 skirmish traces re-pin too; and a path cap by route cells per tick instead of 8 requests (7.1 ms worst tick), the value set in the package plan. Route cells stand in for searched cells, which `AStarGrid2D` does not report; Zero Hour counts searched cells (no new search once 5,000 were searched in a frame; a started search always finishes). P5's node budget replaces the cap later.
- **Relay guards** (user, 2026-11-13, [netplay review](reference/netplay-reference-review.md#review-2026-11-13)): lead bound in `room.forward` (a seat's tick at most the minimum over the other seats of `max(lastTick, delay − 1)`, plus the maximum delay, plus 1; review §7 S1), a hello deadline shorter than the 10 s silence, expiry of unstarted lobbies, the relay comparing the `hash` it already parses and logging `DESYNC` with seat groups; a per-IP connection cap and join rate limit (the client address from the proxy header named by an environment variable, trusted only behind the platform edge); `MATCH END` gains max frame bytes and peak bytes per second per seat, to calibrate a per-seat byte budget at M9. Each rule gets conformance cases, including the review's abusive-client rows (max-size frames, racing ticks, many sockets). Rider: check whether Godot's `WebSocketPeer` delays sends (Nagle, flush on the next `poll()`) with timestamps in a two-client local run; fix only if it shows a delay.
- **Adaptive input delay** (user, 2026-11-13, [netplay review](reference/netplay-reference-review.md#review-2026-11-13)): one agreed delay for all seats, carried in-band (each frame says the delay its seat wants; every client applies the same clamped, rate-limited change), Zero Hour and Warzone 2100 style, instead of the fixed 4 ticks. Ramp: Warzone 2100 rises at most 60 ms and falls 5 ms per update; retail Zero Hour recomputes every 5 s (`NetworkRunAheadMetricsTime = 5000` in `gamedata.ini`, code default 500 ms). The relay's lead bound uses the maximum delay, so changes stay inside it. Measures itself first, since the fault harness comes at M9: arrival-slack and stall telemetry, a `--fixed-delay` baseline on the same seed; adopted only on a measured gain. Second half, measured separately: pace for slow machines in the same in-band way (Zero Hour's run-ahead command also sets the frame rate to the slowest player's FPS; OpenRA slows clients that run early by up to 10 %), instead of today's stall-and-burst at the slowest machine.
