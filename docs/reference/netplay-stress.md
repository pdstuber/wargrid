# Netplay stress research (2026-11-14)

Evidence only: no production code, test gate or deploy changed. Written during the One controller night run as a backup task; code read on `main` at `74950e5`, and line numbers refer to that commit (`online_main.gd` and `main.gd` moved into `game/scripts/match/` with One controller). The throwaway proxy (`fault_proxy.py`, a stdlib asyncio TCP proxy), its case runner and run logs stay in the private working notes; the runs named below used them. A second note checked 22 ideas from a draft chaos-testing brief against the repository; its verdicts are summarised in [Ideas from the draft brief](#ideas-from-the-draft-brief). Reviewed with the user on 2026-11-14: [Review 2026-11-14](#review-2026-11-14).

## 0. Short answer

- **Coverage is wider than the inbox item says.**
  - `tools/run_netplay.sh` has 11 scenarios, not 4. Three already stress timing: `stall` (3 s freeze), `silent` (15 s freeze, the relay drops the seat) and `spike` (the relay holds every forwarded tick 200 ms).
  - CI runs only 5 of them: `match perturb relay-down maps map-mismatch` (`ci.yml:151`), on Linux and Windows.
  - Nothing ever sits between a client and the relay.
  - All 11 run the client `--uncapped`. The real-time pacing the 133 ms window depends on never runs against a real relay.
- **Faults that can happen over WebSocket/TCP:**
  - added latency;
  - jitter, as varying delay only, never reordering;
  - loss, which the application sees as hold-and-burst: the retransmit stalls the stream, then everything arrives at once;
  - reset or close;
  - blackhole: the path goes silent while the socket stays open;
  - slow reader (backpressure);
  - slicing or coalescing inside the stream. This always happens, and the WebSocket layer reassembles it.
- **Faults that cannot happen inside one connection:** reordering, duplication, corruption, bytes missing from the middle. A proxy that drops chunks of the byte stream (the draft brief named a Toxiproxy `packet_loss` toxic; not confirmed upstream) does what TCP never does, and against a WebSocket it causes a framing error, not loss.
- **Key property:** headless seat scripts run only when a tick can step (`headless_client.gd:156-158`). Their commands depend on simulation state, not wall time. Any fault that does not end the match must therefore still give terminal tick 9129 and equal three-way hashes, so pass criteria can be exact.
  - Run: hold-and-burst on seat 2 (3 s and 2 s) plus 7-byte slicing passed the unchanged `match` scenario: 9129, hashes equal to the oracle.
  - Run: 20 ± 15 ms per hop on both seats also passed.
- **Two gaps:**
  1. The headless client has no silence check. A blackholed seat 2 sat for 25 s until the proxy closed the socket; the online scene would have ended it after 5 s. Reproduced.
  2. No netplay scenario exercises the online scene's catch-up credit. Only the fake-transport N5 tests do.
- **Recommendation** (superseded in part by the [review](#review-2026-11-14): Go, not Python; jitter left out of CI):
  - A stdlib Python fault proxy in `tools/`.
  - Four timing-independent CI scenarios: clean, jitter (shortened), hold-and-burst plus slicing, and reset. Add blackhole once the headless silence check exists.
  - Ship it as an addition to the Relay guards package: its lead bound is exactly what hold-and-burst stresses.

## 1. What run_netplay.sh covers today

All scenarios use two headless Godot clients and a locally built relay on a random port. `WARGRID_RELAY_URL` allows only `match` (:82).

| Scenario | Fault | Asserts | Cannot reveal |
|---|---|---|---|
| match (:86-93) | none | both `match_over`; terminal tick 9129 on both; hashes equal on both seats and against an offline replay of seat 1's command log (oracle, :76-80) | timing: uncapped, loopback, about 12 s for 9129 ticks |
| kill (:94-98) | `OS.kill` on seat 2 at tick 600 | seat 1 `ended_left` at tick ≥ 600 | delivery order of the last frames |
| stall (:99-104) | `OS.delay_msec(3000)` on seat 2 at tick 300 (`headless_client.gd:182-186`) | both `match_over`; the hook ran; hashes equal | how long seat 1 waited. The whole process freezes and pings stop, so this is a 3 s blackhole, not a slow simulation |
| silent (:105-111) | the same hook, 15 s | seat 1 `ended_left` within 12 s (relay read deadline is 10 s) | the client's own 5 s silence rule, which the headless client does not have |
| spike (:112-117) | relay `WARGRID_TEST_DELAY_MS=200`: forwarded ticks are delayed in order; pongs and `left` get no delay of their own but queue behind pending ticks (`room.go:190`, `main.go:138`, `sender.go:27-45`) | both `stopped` at tick 900; hashes equal | the 133 ms window, because uncapped clients just run slower; also only one fixed value, same on all seats, no jitter |
| perturb (:118-141) | +1 credit at tick 40 | `ended_desync` with report tick 60; diff and bisect tools name `players` and ring tick 41 | any desync caused by the network |
| version, maps, map-mismatch | handshake | refusal reasons, diagonal starts, map hash | nothing network-related |
| relay-down, relay-term (:185-206) | relay `kill -9` / SIGTERM | both `ended_relay` within 2 s (TERM: drain + 2 s); `MATCH END` logged on TERM | a path that dies while the relay lives |

Other coverage:
- Conformance: profiles default 38, delay 2, silence 1.
- Relay Go tests: `TestStalledPeerStillProducesLeft` (write deadline) and `TestSlowReaderBacklogIsCapped` (1 MiB cap).
- Online pacing: only with a fake transport, `test_online_scene.gd:166-186` (N5).

## 2. How the lockstep window behaves, traced in code

### 2.1 Latency and the 133 ms window

How a tick gets its inputs:
- A command is stamped `_last_sent+1` (`lockstep.gd:55`).
- `finish_tick(after)` sends the packet for `after+delay` (`:120-128`).
- `advance` runs tick T only when every seat's packet for T is in. Otherwise it reports waiting (`:93-95`). There is no timeout in lockstep.

So a packet leaves its sender at T-4 and a peer at the same pace needs it 4 ticks later. The window is about 133 ms one-way, seat to seat, across 2 hops.

Three things shrink it (read in code, not measured):
- The receive side polls once per physics frame: `online_main.gd:51`, one `_step_simulation` per physics frame at 30 Hz (`main.gd:105-109`, `project.godot:46`).
- The send happens after the step in the same frame (`online_main.gd:59`).
- The two machines' physics frames are not phase-aligned.

The real margin is therefore roughly 100-133 ms. (Note: `online_main.gd` and `main.gd` line numbers are `74950e5`; the One controller branch moved this code into `game/scripts/match/`.)

**Send side, settled from source** (the netplay review had this as unverified):
- Godot 4.7.2 native: `p_tcp->set_no_delay(true)` on connect (`modules/websocket/wsl_peer.cpp:109`, tag 4.7.2-stable). The doc says "Disable Nagle's algorithm on the underlying TCP socket (default)".
- `send` calls `wslay_event_send` immediately (`wsl_peer.cpp:798`); it does not wait for the next `poll()`.
- Go side, per `go doc net.TCPConn.SetNoDelay`: "The default is true (no delay), meaning that data is sent as soon as possible after a Write."
- Not covered: the web export ("Not available in the Web export") and the case of a full kernel send buffer.

**Beyond the window:** with L the one-way seat-to-seat delay, the cycle is 8 ticks per 2L, so the rate is about 4/L ticks per second. At L = 200 ms that is about 20 tps: the game runs at 2/3 speed with a short wait every tick, not frozen. Uncapped clients follow the same 4/L formula at any latency.
- Run: 20 ± 15 ms per hop gives L ≈ 40 ms, so the prediction is 100 tps.
- Observed: 9129 ticks in 101.5 s, about 90 tps. This checks the model; it is not a benchmark.

### 2.2 Jitter and catch-up credit

Per frame (`online_main.gd:53-56`): `_credit = mini(_credit+1, 4)`, then up to 2 advances, each costing 1.
- One late frame is repaid in full on the next frame.
- About 3 waiting frames are repaid at 2 ticks per frame.
- Anything longer is lost wall time. This is intended.

Determinism is untouched either way: timing never changes what a tick computes.

### 2.3 Loss and reset

**Loss** looks like retransmit, head-of-line blocking, then a burst. The burst is bounded: a peer can be at most about 2×delay+2 packets ahead (per the comment at `lockstep.gd:7`), far below the `MAX_QUEUED_TICKS` limit of 300 (`:201-203`).
- Run: holds of 3 s and 2 s on seat 2, plus 7-byte slices.
- Result: 9129, hashes equal to the oracle, no protocol error. The run took 19.3 s against 12-15 s clean.

**Reset** (there is no resume):
- The reset seat ends `ended_relay` via `closed()` (`headless_client.gd:145`, `online_main.gd:52`).
- The relay runs `OnClose`, `room.leave` and sends `left{after_tick}` (`main.go:95-100`, `room.go:197-201`).
- The other seat ends `ended_left` once it passes `after_tick` (`lockstep.gd:92`, `:207-212`).
- Run: RST at 4 s. Seat 2 ended `ended_relay` at tick 5218 and seat 1 `ended_left` at tick 5223, both within about 10 ms. The 174 hash rows they share were equal.

### 2.4 Stalled or slow seat, and blackhole

The relay's 10 s read deadline is refreshed by every message, including JSON ping (`main.go:91`, `:114`, `:148`).

| Case | Behaviour |
|---|---|
| Seat alive but its simulation is slow | It keeps pinging, so no timeout fires; the others wait without limit. |
| Seat frozen | The relay drops it after 10 s; the others get `left`. This is the `silent` scenario. |
| Path blackholed | The relay drops the seat after 10 s. The online scene ends itself after 5 s of no frames (`relay_transport.gd:6`, `:58-59`; `online_main.gd:52`). **The headless client never calls `silent()`** (`headless_client.gd:142-152`). |
| Slow reader | Write deadline plus the 1 MiB cap (`main.go:68-84`); covered by the Go tests. |

The blackhole row was reproduced with a 25 s blackhole on seat 2:
- Seat 1 ended `ended_left` about 10 s in; the relay logged `i/o timeout`.
- Seat 2 hung until the proxy closed at 28 s.
- Their 123 shared hash rows were equal.

Two side findings:
- **Send errors are ignored.** `RelayTransport.send_text` discards the result of `_peer.send_text` (`relay_transport.gd:41`). Godot refuses a send once the outbound buffer is full (`wsl_peer.cpp:789-790`); Wargrid sets that buffer to 128 KiB (`relay_transport.gd:5`, `:19`). A packet lost that way would make the relay reject the next tick as out of order (`room.go:179`), so the match ends with `left`, not a desync. Read in code only; the 10 s deadline fires first in practice.
- **A user-space proxy hides backpressure.** It reads eagerly, so a bandwidth toxic never reaches the relay's write deadline or queue cap. Slow-reader coverage should stay in the Go tests.

### 2.5 Reordered and sliced frames

- **Reordering is impossible within one TCP connection.** The relay keeps per-socket order even under its test delay (`due = max(lastDue, ...)`, `sender.go:32-36`). Frames from different seats can interleave, which is harmless because packets are keyed by (seat, tick). "tick out of order" (`lockstep.gd:194-196`) only fires on a buggy or modified peer or relay.
- **Slicing is normal.** The WebSocket libraries (gws, wslay) reassemble frames. Run: 7-byte writes in both directions passed.

## 3. Ways to inject faults

CI today:
- `godot-export` runs on ubuntu-latest and windows-latest with Go, Python, a prebuilt relay and the exported client (`ci.yml:90-157`).
- GitHub docs: "The Linux and macOS virtual machines both run using passwordless sudo"; "Windows virtual machines are configured to run as administrators with User Account Control (UAC) disabled."

| Option | Setup | CI fit | Determinism | What it proves |
|---|---|---|---|---|
| Toxiproxy v2.13.0 (2026-10-14) | pinned server binary per OS from the release assets (`toxiproxy-server-linux-amd64`, `-windows-amd64.exe`) with a checksum; HTTP API on 8474 driven by curl | both runners; the Docker image is Linux only | exact results; timing is random (`rand.Int63n`, `toxics/latency.go:25`) | latency+jitter, timeout, reset_peer, slicer, bandwidth, limit_data, down. Hold-and-burst only by adding then deleting a large latency (inferred from `latency.go:45-47`, "Exit fast without applying latency"; not tried) |
| Stdlib Python proxy (this run, about 130 lines) | none; one file under `tools/`; ruff/mypy apply | both runners in principle; Windows asyncio and the `SO_LINGER` struct layout not verified | seeded jitter; timeline in seconds since the seat connected | everything in section 2 except real retransmission; per-seat faults by accept order (seat 1 connects first via `start_pair`) |
| Go proxy (`tools/netfault`, the review's section 8 plan) | about 150 lines; built like the relay | both runners; gets race and lint checks | same as Python | same as Python |
| tc netem (Linux) | `sudo tc` on `lo`. Man page: "Packets will also get reordered if jitter is large enough"; "Each packet loss is independent" | Linux only; hits the whole loopback, so per-seat faults need `tc filter` | random | real loss and RTO; one manual run would confirm that loss behaves like hold-and-burst |
| macOS dnctl/pfctl | dummynet ("delay, queue size and packet loss rate"); needs root | no (root, and night runs deny it) | random | same as netem |
| Delay hook in the headless client (`--hold-rx-at-tick`, `--slow-ms`) | small typed GDScript | both, no extra process | can be keyed to ticks | lockstep behaviour without sockets. `--slow-ms` (slow simulation that still pings) is the one fault a proxy cannot make |
| Relay-side hook (extend `WARGRID_TEST_DELAY_MS` per seat, with jitter or hold) | change to the shipped binary, plus conformance cases | relay-test job | seedable | relay forwarding only; cannot realistically blackhole or reset the client's path |

Toxiproxy's README says it is "made specifically to work in testing, CI and development environments, supporting deterministic tampering with connections". Its latency toxic keeps order because each stream is one sequential pipe (`latency.go:30-52`). It loses here only on cost: a pinned binary per OS for what about 130 stdlib lines cover. Any home-made proxy must keep the "due = max(previous due, now + delay)" rule, or it reorders bytes.

## 4. Recommended first scenarios

Mechanics:
- A `run_netplay.sh` helper starts the proxy in front of the local relay and points the clients at it. This is the same seam `WARGRID_RELAY_URL` uses, so the clients do not change.
- Faults are set per seat.
- Use the full `match` where it finishes in under 30 s, otherwise `--stop-at-tick 1800`.

| # | Scenario | Fault | Pass criteria | Today |
|---|---|---|---|---|
| F1 | proxy-clean | none | `match` criteria (9129 and three-way hashes) | passes (5 runs, 12-15 s) |
| F2 | proxy-jitter | 20±15 ms per hop, both seats, seeded | 9129 and hashes; no `ended_protocol` | passes, but takes 101 s. CI variant: `--stop-at-tick 1800`, about 20 s by the 4/L model |
| F3 | proxy-burst | seat 2: hold 3 s at 3 s and 2 s at 7 s, 7-byte slices | 9129 and hashes; wall time ≥ clean + holds; a new `NETCLIENT WAITS <count> <ms>` line shows waits ≥ the holds | passes (19 s); the WAITS line does not exist yet |
| F4 | proxy-reset | RST on seat 2 at 4 s | s1 `ended_left`, s2 `ended_relay`, both within 2 s; the shared hash prefix is equal; no hang | behaves this way (5 s); needs a prefix compare, because `compare_replays.py` requires equal row counts |
| F5 | proxy-blackhole | seat 2 blackholed 25 s | s1 `ended_left` within 12 s; s2 `ended_relay` within 6 s | fails today: needs the 5 s silence check in `headless_client._run_steps` |
| F6 (later) | paced window | headless client paced like the online driver; seat 2 at 60 ms and 200 ms one-way | 60 ms: no stalls after warm-up; 200 ms: about 20 tps; hashes equal | the capped headless mode (`CAPPED_STEPS = 2` per physics frame, `headless_client.gd:14`, `:61-66`) lacks the online driver's catch-up credit; F6 adds it or drives the online driver. After One controller, the online driver is a RefCounted the headless client could drive (plan Decision 11). Timing-dependent, so run it locally or nightly with 5 repeats and ranges, not as a CI gate |

**CI:** add `proxy-clean proxy-burst proxy-reset` (later `proxy-blackhole`) to the loop at `ci.yml:151`, on Linux and Windows. That costs about 40 s per platform. Results do not depend on timing; a slow runner only moves the tick at which a hold lands.

## 5. Proposals for the user

1. **Recommended: an addition to the Relay guards package** (`packages.md:42`, note at `:87`).
   - Contents: the proxy, the run_netplay helper, F1, F3 and F4, the WAITS line, the headless silence check with F5, and CI for all of them.
   - Why there: the lead bound in `room.forward` must reject a racing client but never a legitimate burst after a hold. F3 is that regression test.
   - It also settles the package's existing Nagle/flush check by source (section 2.1). Only a short timestamp confirmation remains.
   - Size: small, about one night task. No protocol, simulation or trace change.
   - Caveat: this pulls part of the M9 "fault harness first" item forward, which the user placed at M9 on 2026-11-13. It needs the user's call.
2. **Alternative: its own small night package, "Fault harness lite",** before Relay guards. Same contents plus F2. Choose this only if Relay guards should stay narrow; it is a lot of ceremony for this much work.
3. **F6 goes to the Adaptive input delay package.** That package already plans stall telemetry and a `--fixed-delay` baseline, and it needs latency injection to show a gain. It can only start after One controller merges.
4. **Later (M9, as decided):**
   - resume validation;
   - 3-seat scenarios, including the double-leave hang;
   - one manual netem real-loss run (`NET_ADMIN` in Apple container is unverified);
   - a browser client through the proxy;
   - the hidden-tab check.

**Not adopted:** Toxiproxy as a CI dependency. It works and is documented, but it adds a pinned binary per OS for what about 130 lines of stdlib do. Revisit if the scenario list outgrows one small file.

## Not verified or not run

- Windows proxy behaviour (asyncio Proactor loop, `SO_LINGER` layout).
- F6: the 100-133 ms margin is derived from code, not measured.
- Toxiproxy: docs and source only, at 49299d8; not installed or run. The delete-latency hold-and-burst is inferred.
- Real loss via netem or dnctl (root needed).
- Browser WebSocket socket options.
- The 90 tps figure is a single run with load around 2. It supports the 4/L model only; it is not a ledger row.
- Process note: the first fault batch ran with no faults because zsh passed the arguments as one word. Those folders were deleted and the cases rerun with literal arguments; the first batch still counts as four extra clean runs, all at 9129.

## Ideas from the draft brief

22 ideas checked on `74950e5`; nothing run. Most of the brief already exists (adversarial protocol cases in `protocol/conformance` and `test_lockstep.gd` L8/L10, desync detection with earliest-tick bisect, per-push relay tests, disconnect-time checks, failure artifacts) or is planned (review §8, blueprint M9).

- **Adopt now (6):** faults stay out of process (no new relay environment knobs; the headless client's hooks ship in exports, `launcher.gd:20`, `:34-38`); a fault log per seat instead of a seeded byte replay (TCP chunk boundaries vary per run); the headless silence check (F5); boundary-value outages (about 4 s must survive, about 7 s must end, at least 1 s from each timer) instead of 15-30 s, because any outage over 5 s takes the same branch; a one-line repro command on failure; the existing `kill stall spike version` scenarios in CI (`ci.yml:151` runs only five of eleven).
- **Later (7):** tick-anchored proxy faults (with the paced mode); one netem real-loss run on a Linux runner; `--slow-ms` slow-simulation hook (Adaptive input delay, second half); Chromium CDP `Page.setWebLifecycleState frozen` for the hidden-tab check (experimental; frozen is not the same as a background tab); a relay goroutine-churn Go test (no `NumGoroutine` check exists); latency and stall lines with the paced mode; one proxy per seat on its own port, and a 3-seat double-leave lockstep unit test.
- **Skip (8):** a protocol interceptor (duplicates conformance), a separate disconnect item (F4 covers it), Pumba, Toxiproxy (pinned binary per OS; a chunk-dropping toxic models a fault TCP never has), stall-then-resume as new work (exists as `stall`/`silent`), CPU contention runs, a connection-lifecycle suite (covered), a new chaos CLI or declarative scenario files (`run_netplay.sh` is the framework).
- **User decision (1):** proxy language, Go (built in the relay's CI step, Windows-safe) or the prototype's stdlib Python (Windows asyncio and `SO_LINGER` behaviour unverified).

Claims in the brief, checked: state digests exist (whole-snapshot `StateHash.digest` every 30 ticks, a 64-tick per-tick ring, three-way compare with an offline oracle, `desync_diff.py`/`desync_bisect.py`); fast protocol tests run on every push; reconnect and browser parity testing are absent; `run_netplay.sh` has 11 scenarios, not 4.

## Review 2026-11-14

Reviewed with the user at kickoff; the claims that drive the proposals re-checked on `main` at `74950e5`: the CI loop runs `match perturb relay-down maps map-mismatch` only (`ci.yml:151`); `headless_client.gd` never calls `silent()` (relay loss only via `closed()`, line 145); `RelayTransport.send_text` discards the send result (`relay_transport.gd:41`). Nothing re-run.

**Where the items went** (user, 2026-11-14):

- **Relay guards** ([packages](../packages.md#package-notes)): a Go fault proxy in `tools/`, one per seat on its own port if that stays small (else M9); CI scenarios proxy-clean, proxy-burst (the lead bound's regression test), proxy-reset, and proxy-blackhole with the headless 5 s silence check; boundary-value outages; repro line and per-seat fault log; faults out of process as a plan rule. Riders: `kill stall spike version` in CI; a goroutine-churn Go test; a refused `send_text` closes the socket, with a test; the Nagle rider shrinks to one timestamp confirmation (§2.1 settles it from source).
- **Adaptive input delay:** the paced headless mode (F6) as its measurement, with F2's seeded jitter as one of its rows; local or nightly, not a CI gate.
- **P2.2 Quick rematch:** the hidden-tab check stays manual first; CDP freeze noted as a later automation option.
- **M9** ([blueprint](../blueprint.md)): 3-seat double-leave unit test, one netem run, a nightly tier once timing rows exist, a browser client through the proxy.
- **Dropped:** Toxiproxy, Pumba, CPU contention runs, a chaos CLI, an in-relay interceptor, 15-30 s outage rows, a client soak before 6-seat simulation exists.
