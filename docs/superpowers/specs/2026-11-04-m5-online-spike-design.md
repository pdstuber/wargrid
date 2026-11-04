# M5 — online spike design

Status: **DESIGN APPROVED** by user 2026-11-04; implementation starts only on explicit kickoff. [Blueprint](../../../Wargrid_Kickoff_Blueprint.md) §7 M5 owns scope and exit gate, §11 "Multiplayer" owns the direction; this document refines both. Planning or branch preparation does not start implementation.

## Intent

Find out how hard multiplayer really is for Wargrid, by building the part of it that the long-term target needs anyway: **three friends in different places (all in Bavaria) playing over the internet against three bots** (blueprint §1). User, 2026-11-04: "I definitely want to build the multiplayer in one way or another"; a lobby is needed later so friends can find each other.

The spike is the **thin foundation** M9 builds on, not a throwaway: tested and reviewed lockstep core, protocol and relay; nothing beyond that. Success: a full 1v1 match between macOS and Windows over fly.io without desync, measured latency inside budget, and a findings report that says what M9 still costs.

User's concern (2026-11-04): Generals online was unreliable in their memory ("maybe 20% of matches worked without disconnects or weird bugs"; unverified figure). Source shows why: peer-to-peer UDP with firewall probing and one player acting as packet router (GeneralsGameCode `afc2a103f`, `Core/GameEngine/Include/GameNetwork/FirewallHelper.h`, `Core/GameEngine/Source/GameNetwork/ConnectionManager.cpp:298`), and many desync ("mismatch") bugs (42 commits mentioning mismatch at that head). The design answers each: outbound-only connections to a relay, desync diagnosis built in from day one, and the relay as the single authority on who is connected.

**Non-goals:** lobby, matchmaking, reconnect, a dropped player becoming a bot, dynamic input delay, teams or more than two seats (M6), browser export (M9), authoritative server, binary encoding, accounts.
**Anti-goals:** a match that only works on one OS pair or one machine; a desync that cannot be diagnosed from the files it leaves; clients that disagree about who left; a passing latency number measured on localhost only.

## Approaches

Considered and dropped: Godot's high-level multiplayer API (RPC over `WebSocketMultiplayerPeer`) needs a Godot peer as server, which a Ktor relay is not; an authoritative server (headless Godot runs the simulation, clients receive state) stays the blueprint fallback if lockstep fails, not the spike.

- **A. Dumb relay, clients stamp the execution tick (Generals style). Chosen by user 2026-11-04.** Each client sends one packet per tick; the relay groups connections into matches and forwards packets; clients step tick T only with every seat's packet for T and compare hashes themselves. Relay stays small; moving to B later is additive.
- B. Relay owns the clock (OpenRA style, `OpenRA.Game/Server/Server.cs` adds `OrderLatency` to each order's frame, revision `9636b63eae`). Central place for dynamic delay, disconnect markers and server-side replays, but more Kotlin now and tick-aware pacing in the relay; OpenRA itself has a TODO for the dynamic part.

Accepted addition to A (user, 2026-11-04): **the relay alone decides membership** and announces departures with a tick, so clients cannot disagree about who left.

## Decided

### Lockstep model

- Simulation stays at **30 Hz** (`game/project.godot`). Fixed **input delay 4 ticks** (133 ms): a command issued during local tick t executes at tick t + 4. OpenRA's default is 3 ticks at 40 ms (`mods/cnc/mod.yaml`, `OrderLatency: 3`, `Timestep: 40`).
- Every client sends **exactly one packet per tick** for its own seat, even with no commands; packets pace the match. Ticks 1–4 are pre-filled empty for every seat at match start.
- A client steps tick T only when it holds every seat's packet for T. Otherwise it waits and shows "waiting for player N"; catch-up after a wait is bounded per frame (blueprint §11: no unbounded catch-up).
- **Online, commands enter the simulation only from the lockstep layer**, on every client in the same order (tick, player, sequence), immediately before stepping their execution tick, including the local player's own commands. `issue_command` validates against current state (`simulation.gd:116`), so issuing at different local ticks on different clients would desync. Online, UI and scripts submit to the lockstep layer, never to the simulation directly.
- **Offline play is unchanged** (my call): single-player keeps today's direct path with no input delay, so the pinned scenario and replay traces stay as they are. Both paths end in the same `issue_command`; the end-to-end oracle (test 3) checks the online path against a single-process replay. In-simulation bots (`Skirmish.issue_opponent`) are called on every client at the same tick and never go through the network.
- **Every client applies the decoded wire form** of every command, its own included, so a float or int that changed in encoding changes it on every client alike.
- Snapshot **hash every 30 ticks**, sent in the packet. **Digest (user-approved 2026-11-04, replaces SHA-256 of `var_to_bytes`, which measured 0.83 ms p99 and exceeded the 0.55 ms budget):** `StateHash.digest` = `"%08x%08x" % [snapshot.hash(), core_check(snapshot)]`: Godot's native recursive 32-bit `Dictionary.hash()` over the whole snapshot (measured 0.043 ms p99; every one of 5,418 leaves detected when changed) plus a hand-rolled FNV-1a 32-bit check over core fields (entity id, owner, health, position, credits) that we specify ourselves, so engine-defined hashing is backed by a part whose algorithm we own; the pinned literal in `test_state_hash` run in CI catches engine drift, and a desync report records which half differed. `test_replay.gd` keeps its SHA-256 `_hash`, so replay traces are unchanged. A mismatch stops the match on both clients.
- The scripted opponent stays an in-simulation deterministic function of the snapshot (`Skirmish.issue_opponent`), so later bots need no traffic. In the M5 human-vs-human match both seats use controller `"human"`; `Skirmish.create` currently adds player 2 as `"ai"`, which changes the scan modifier (`combat.gd:30`).
- Restart is disabled online.

### Protocol

- **JSON text frames over WebSocket** (Godot `WebSocketPeer` on the client; works on desktop and web export). Readable, shared test vectors; traffic is small (2 clients × 30 packets/s), bytes are measured.
- Messages, proposed shape: `hello {protocol, build, match}` → `welcome {seat}` → `start {seats, delay}` when all seats are filled; `tick {tick, commands, hash?}` forwarded to the other seats; `left {seat, after_tick}`; `error {reason}`.
- **Version check at join:** a `protocol` or `build` mismatch is refused before the match starts.
- **Shared test vectors** (JSON message samples in the repo) are read by both the GDScript and the Kotlin tests; no code generator.

### Relay (Kotlin, Ktor)

- User's stack: **Kotlin + Ktor**, in its own directory at the repository root (outside `game/`), Gradle wrapper, JDK 21 (Temurin 21 installed locally). **CIO engine**, because Ktor's GraalVM support requires it: "Currently, Ktor Server applications that want to leverage GraalVM have to use CIO as the application engine" (ktor.io/docs/graalvm.html, Ktor 3.6.1).
- Holds no game logic. Rooms keyed by match code; a match starts when both seats are filled; packets are forwarded in arrival order per seat.
- **Membership authority:** when a seat's socket closes or sends nothing for a timeout, the relay sends `left {seat, after_tick}` with the last tick it forwarded from that seat. Clients finish up to that tick and end the match with "player N disconnected". No reconnect.
- Validates at the trust boundary: message size cap, envelope shape, seat may only send its own packets; violators are dropped.
- Hosting on the user's fly.io account (logged in on the development machine 2026-11-04 via `fly auth login --code`), region **`fra`**, shared 256 MB VM, `[http_service]` with stop-when-idle and start-on-connect so cost stays near zero between matches. **Every deploy needs explicit user approval** (cost, public endpoint).

### GraalVM experiment (user request)

Build the same relay twice, JVM and GraalVM native image, both on CIO. On fly, measure **stopped machine → first `welcome` message** and memory in use, five runs each. Ktor's GraalVM page does not mention WebSockets, so the first check is that a native build serves WebSockets at all. The native image is built in a multi-stage Dockerfile on fly's remote builder; no local GraalVM or Docker needed. The result and the chosen image go into the findings report; the losing app is destroyed.

### Desync diagnosis

On a hash mismatch each client writes a **desync report**: the applied command log (tick, player, sequence, command as applied), its hash rows, and **the full snapshot at the mismatching hash tick** (already computed for the hash, so no ring buffer). A tool built on `tools/compare_replays.py` takes both clients' reports, compares the command logs, and diffs the two snapshots field by field; this covers the cross-OS case where the logs agree but results differ (my call). To narrow to the first divergent tick, the same log is replayed on each machine with per-tick hashes. Idea from OpenRA `OpenRA.Game/Network/SyncReport.cs`; own implementation.

### Automated tests (runnable without the user)

1. Relay: Ktor test application; rooms, start, forwarding order, version refusal, `left` tick, trust-boundary rejects; shared vectors.
2. Lockstep core with a fake transport: delay, jitter, a stalled peer, pre-fill, ordering, own commands applied in wire form; same-tick interaction of every existing command against arrival in the same tick (AGENTS rule).
3. Local end-to-end: relay on localhost plus two headless Godot clients play a scripted full skirmish (seat 1: the scripted human from `test_skirmish_match.gd`; seat 2: the opponent policy, submitting through the network). Because execution ticks are fixed by the delay and scripts are functions of state, the result is independent of network timing: both clients' hash logs must be equal and equal a single-process replay of the same command log.
4. Cross-platform: the Linux and Windows CI jobs each run test 3 with exported builds and upload hash logs; the compare job requires them equal. macOS was dropped from CI on 2026-11-03 (runners failed to start; commit `0446211`), so the Mac runs test 3 locally and compares against a CI run, extending `tools/compare_local_traces.sh`. This is the early Mac-vs-Windows determinism signal before any human match.
5. Failure cases: kill one client mid-match (the other ends cleanly at the announced tick); stall one client (the other waits, both resume, no desync); latency spikes through a relay delay setting (shortcut: test-only, off in deployment); one client with a deliberately perturbed simulation (both stop, report names the first divergent hash window); version mismatch refused.

### Measurements

- **Latency budget: click to own command executing ≤ 250 ms at p95**, both clients connected through fly `fra`; recorded with relay round-trip time and wait-per-tick distribution. Localhost numbers do not count toward the gate.
- **Lockstep overhead budget (user, 2026-11-04): 10% of a tick on the target, 3.3 ms; 0.55 ms p99 on the development machine** (encode, decode, and the hash tick, which hits p99). New row in the [performance ledger](../../reference/performance.md) Budgets table; ledger rules apply unchanged. The hash reuses the snapshot the view already takes that tick, so its marginal cost is `var_to_bytes` plus SHA-256. If it does not fit, lower cadence or a hashed subset goes to the user, not changed silently.
- Packet bytes per second per client.

### Exit gate

Blueprint M5 gate plus the user-approved additions:

1. A complete match between macOS and Windows over fly.io without desync; both clients' hash logs equal.
2. Measured latency against the budget above.
3. Relay hosting decided and documented, including the GraalVM-vs-JVM result.
4. Version check, desync report and tool, relay-announced disconnect, and automated tests 1–5 passing (CI green on Linux and Windows; local macOS comparison matched).
5. `sh tools/run_benchmark.sh` passes, a new ledger row, a rendered rerun if presentation changed.
6. A match with one friend from their own location, on exported builds (hard gate, user 2026-11-04).
7. **Findings report** in `docs/reference/` (new M5 note): how hard it was, what broke, measured latency and bytes, cold-start result, and the M9 list (lobby, reconnect, dropped player becomes bot, dynamic delay, more seats, browser).

## Constraints

- Desktop clients first: macOS (development machine) and Windows. The Windows machine for the first human match is the user's own at home.
- **Exported release builds are in scope (user, 2026-11-04):** export presets and pinned Godot 4.7.2 export templates; CI exports Linux and Windows builds and runs test 3 with them, because release templates are compiled differently from the editor binary and determinism must hold for what players run (difference unverified). Builds are unsigned; the findings report and a short player note cover opening them past Gatekeeper and SmartScreen. The `build` value in the version check identifies the exported build.
- M0 rule: ordinary CI must work without sibling projects or retail data; CI gains a JDK for the relay.
- Kotlin and GDScript must agree on the protocol only through the shared vectors.
- Docs say M4.1 is "not merged" while `main` and `m4.1-polish` point at the same commit (`f2c5f9e`); the M4.1 user playtest is still open. M5 kickoff waits for the user to settle both.

## Left to the builder

- Directory and file names for relay, lockstep layer, vectors and the report tool; exact JSON field names beyond the shapes above.
- Match-code creation (proposal: one player creates a match and receives a short random code, the other enters it on a minimal join screen; headless tests pass it as an argument).
- Relay timeout for a silent seat (proposal: 10 s) and the per-frame catch-up bound.
- How the opponent script and scripted human submit through the lockstep layer (the opponent currently calls `sim.issue_command` directly with the current tick, `skirmish.gd` `_send`).
- Godot JSON pitfalls: `JSON.parse_string` returns every number as float, and `JSON.stringify` needs full precision for floats; the simulation requires integer `tick`, `player`, `sequence` and ids.
- Task order, with risk first: lockstep core and the cross-platform CI run before fly deployment and human matches.
