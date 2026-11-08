# Converted maps playable (design, approved by the user 2026-11-08)

Small task, not a milestone; blueprint §7 "Converted maps playable". Handoff and every decision with its evidence: [converted maps prompt](../../converted-maps-prompt.txt), section "Decided". This design adds only the points settled after it; it does not repeat the handoff.

## Intent

Dry Wells, Broken Crown and Ashfall become selectable maps, offline and in online 1v1, so later work (unit avoidance, M8 bots, playtests) runs against real maps. Both online clients are guaranteed the same map or refuse to start. The launcher also gets an in-game Credits panel, because the web build shows no music, map or engine credit today.

## Goals and non-goals

- Goals: map choice offline and online; host's settings carried by the relay with a relay seed (protocol 2); start spots by Zero Hour's rule; joiner refuses a map mismatch; existing bots build, collect and attack on all three maps; Credits panel; pins and traces unchanged.
- Non-goals: the M9 lobby (slots, chosen starts, teams in the UI), bot tuning (M8), tech buildings, a minimap, map transfer, relay deploy (needs the user).
- Anti-goals: tests, replays, benchmarks or the CI netplay client silently moving off `skirmish.json`; a client that plays a guessed map; a pin that changes without its old and new values recorded.

## Approaches

Online map agreement (user, 2026-11-08): (A) map in the build string, no relay change; (B) host announces the map in its first tick frame, no relay change; (C) host's opaque `settings` in `hello`, echoed by the relay in `start` with a relay seed. **C picked**: later settings need no relay change, a tampered host cannot steer random starts, and it matches Zero Hour's host-owned game info and Recoil's opaque start script. Credits: (A) a longer launcher footer line; (B) a Credits panel. **B picked**: one place for all notices, works offline and on the web, same as Zero Hour and OpenRA.

## Settled in the 2026-11-08 brainstorm (user approved as proposed)

- **Launcher map choice:** a map dropdown (`OptionButton`) next to the faction dropdowns, listing Dry Wells, Broken Crown, Ashfall; used by Play offline and Create match. Join has no map choice and follows the host. Opening `skirmish.tscn` directly, tests and benchmarks keep `skirmish.json`.
- **Credits:** a Credits button under the play buttons opens a scrollable panel with a Close button; content per the handoff's "Decided" credits entry.
- **Joiner refusal:** the joiner shows the exact reason (e.g. "Your copy of Ashfall differs from the host's") and closes. The host sees the existing `left` before the first tick and shows "Opponent left before the start (different map files or version)". No new message type.
- **Netplay tooling:** `game/scripts/net/headless_client.gd` takes `--map <name>`; `tools/run_netplay.sh` keeps `skirmish.json` by default, so its scenarios and pins are unchanged.
- **Map dropdown row (plan deviation, accepted):** the dropdown gets its own row, because the existing launcher layout test caps the faction row at 520 px.

## Added after the brainstorm (user, 2026-11-08, from a friend's playtest)

- **Launcher:** while waiting for player 2, a Cancel button closes the connection and returns to the launcher, and a Copy button puts the match code on the clipboard (browser clipboard unverified until a web run).
- **Bot economy:** collectors per supply center, counting the depot's free one, same at every difficulty: USA 2, China 3, FRC 5 (down from 7); the map converter puts each start's supply-center slot at the open site nearest the nearest full dock (small piles ignored), up to 12 cells from the start, and the three converted maps regenerate. Pins moved by the collector change may be re-pinned with old and new values recorded, in their own commit; any other pin change stays a stop. Both are stopgaps that M8 revisits. Evidence: [design answers](../../reference/design-answers-2026-11-08.md#friends-playtest-reported-by-the-user-2026-11-08).

## Unattended-run rules (user, 2026-11-08, for the overnight run)

- One local commit per green task on branch `converted-maps`, so each part can be reverted; no merge, push or fly deploy.
- A budget exceeded on the new maps is recorded with its numbers in the performance ledger and the run continues; never loosened. The user decides in the morning.
- If bots never attack or never collect on Broken Crown or Ashfall: only the smallest fix inside the existing bot code (`Skirmish.issue_opponents` and what it calls), test-first; anything bigger is recorded as a finding for M8.
- Visible windows are allowed tonight (the user's monitor stays on, sound at 0); start them with `--audio-driver Dummy`.
- Game-design questions that no decision above answers are recorded for the morning, not decided by the run.

## Left to the plan

Task order and contracts, exact wire shapes for `settings` and `seed` and the new protocol vectors, the start-spot function's interface (taken spots as input, per the handoff), the map hash function, how `issue_opponents` gets its seats from the chosen starts, the Credits parser and layout test, and the bot-vs-bot and rendered checks per map.
