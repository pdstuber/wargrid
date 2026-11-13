# Packages

Work after M7 ships as small packages: each gives players something they can feel, goes to the test app, and is playtested in one short session. This page is the plan for P1 to P5 and the rough rest; [STATUS](STATUS.md) holds their state. The blueprint keeps design scope ([§7](blueprint.md#7-milestones-and-exit-criteria)).

Rules, reasons and the full list: [packages and playtest helper design](superpowers/specs/2026-11-11-packages-and-playtest-helper-design.md) (package rules, the next five, the helper). Answers behind it: [design answers](reference/design-answers-2026-11-08.md#planning-overhaul-packages-and-playtest-tooling-user-2026-11-11-night). Order of P1 to P5 is the user's (2026-11-11 night); contents inside each are the agent's proposal until its plan is approved.

## The next five

| # | Name | Player change | Rider |
|---|---|---|---|
| P1 | Tell us what you see | The playtest helper: focus card, checklist, markers, after-match form, one replayable session file | Exceeded-budget summary line and worst-tick lines in `run_benchmark.sh` |
| P2 | You clicked, we heard | An acknowledgement sound per accepted order | Browser against native team-match measurement |
| P3 | Camera that follows you | Edge scrolling, right-drag pan, jump-to-alert and home keys (playtesters find arrow keys cumbersome, user 2026-11-12) | Movement milestone design |
| P4 | Smooth motion | Interpolation rework behind a toggle key | Seeded fuzz and invariant test, before movement; perf overlay `split %` in Safari against Firefox (Safari can stay low, user 2026-11-12) |
| P5 | Smarter paths (toggle) | Movement milestone part 1 behind a toggle key | Late-game 3v3 canary workload |

### P1 in detail

- **Focus cards:** three, in [`game/data/playtest/focus.json`](../game/data/playtest/focus.json), one per sitting. Card 1 (`p1-frc-economy`) is P1's blocking focus; findings from cards 2 (`p1-frc-tunnels-online`) and 3 (`p1-look-and-m6-fixes`) go on the findings list in [STATUS](STATUS.md#findings-list) unless they block play.
- **Plan and evidence:** [plan](superpowers/plans/2026-11-11-packages-and-playtest-helper.md), [verification](reference/p1-playtest-helper-verification.md).
- **Exit:** card 1 playtested with the helper and its findings written into [STATUS](STATUS.md).

### P2 to P5

Each gets a plan and a drafted focus card when it is next; the design holds the proposed card and rider for each. Exit for each: its card playtested, problems in the card's focus fixed, other findings on the list.

## Rough rest

Re-planned as playtests come in; blueprint §7 has the scope of each.

- Menu quick wins (user, 2026-11-12): group the launcher into sections, relay URL under an advanced fold, fix F5; no redesign.
- Map pack (user, 2026-11-12): two or three more maps through `tools/zh_map/convert.py` ([more maps](reference/more-maps.md)), the user picks from a short list; tech buildings stay skipped.
- Is Wargrid healthy (user, 2026-11-12): relay `/metrics` (rooms, players, round trip, desyncs) into fly's hosted Grafana, plus a small public traffic light on the web page. Rider (user, 2026-11-13): deploys (manual and release workflow) wait until the relay reports 0 rooms, with a timeout and an override.
- Relay guards (user, 2026-11-13, from the netplay reference review): lead bound in `room.forward` (a seat's tick at most the minimum over the other seats of `max(lastTick, delay − 1)`, plus the maximum delay, plus 1; review §7 S1), a hello deadline shorter than the 10 s silence, expiry of unstarted lobbies, the relay comparing the `hash` it already parses and logging `DESYNC` with seat groups; a per-IP connection cap and join rate limit (the client address from the proxy header named by an environment variable, trusted only behind the platform edge); `MATCH END` gains max frame bytes and peak bytes per second per seat, to calibrate a per-seat byte budget at M9. Each rule gets conformance cases, including the review's abusive-client rows (max-size frames, racing ticks, many sockets). Also a desync bisect tool: replay a desync report's command log headless with a hash on every tick and diff the snapshots at the first divergent tick (glue over `compare_replays.py` and the oracle path). Rider: check whether Godot's `WebSocketPeer` delays sends (Nagle, flush on the next `poll()`) with timestamps in a two-client local run; fix only if it shows a delay.
- Adaptive input delay (user, 2026-11-13, from the netplay reference review): one agreed delay for all seats, carried in-band (each frame says the delay its seat wants; every client applies the same clamped, rate-limited change), Zero Hour and Warzone 2100 style, instead of the fixed 4 ticks. Ramp: Warzone 2100 rises at most 60 ms and falls 5 ms per update; retail Zero Hour recomputes every 5 s (`NetworkRunAheadMetricsTime = 5000` in `gamedata.ini`, code default 500 ms). The relay's lead bound uses the maximum delay, so changes stay inside it. Measures itself first, since the fault harness comes at M9: arrival-slack and stall telemetry, a `--fixed-delay` baseline on the same seed; adopted only on a measured gain. Second half, measured separately: pace for slow machines in the same in-band way (Zero Hour's run-ahead command also sets the frame rate to the slowest player's FPS; OpenRA slows clients that run early by up to 10 %), instead of today's stall-and-burst at the slowest machine.
- What's new (user, 2026-11-12): one player-facing line per shipped package in a changelog file, shown in the menu and on the web page.
- Order controls ("Orders that feel yours").
- Movement part 2 (toggle becomes default).
- Minimal real HUD.
- Controller flattening (FIX-6) with the `SimPump` seam, inside the HUD packages.
- Unit avoidance behind a toggle.
- Fog of war, before ground batch A.
- Ground batch A, cut into packages of two or three units each.
- Art pass.
- Ground batch B.
- Bots.
- 3v3 online.

## How a package runs

1. Plan it, with a drafted focus card.
2. The user approves plan and card.
3. Deploy to the test app (needs approval).
4. One 15 to 20 minute session with the helper; the session file replays headless (`sh tools/replay_session.sh`).
5. Problems in the card's focus are fixed before the next package; other findings go on the [findings list](STATUS.md#findings-list), which orders later packages.
