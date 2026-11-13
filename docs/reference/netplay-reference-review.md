# Netplay reference review (2026-11-12)

Research only: no production code, test gate or deploy changed. Wargrid tree: branch `spike-net-optimizations` at `4b444a2`. Working notes with raw findings: `netplay-research-notes.md` (private). Reviewed with the user on 2026-11-13: decisions and corrections in [Review 2026-11-13](#review-2026-11-13); corrections are also marked in place. Labels: **code** (read in source at the revision named), **measured** (an existing Wargrid evidence note, cited), **docs** (primary web source, quoted), **derived** (arithmetic from code and measured figures, not measured), **unverified**.

Reference revisions (all local under `~/projects`):

| Repo | Revision | Licence (for adaptation) |
|---|---|---|
| OpenRA | `b4d95a56717d` (2026-11-08) | GPL-3.0 |
| RecoilEngine | `a0240a9b5c0c` (2026-11-04) | GPL-2.0-or-later |
| Beyond-All-Reason | `a31aa1c194e4` (2026-11-12) | GPL-2.0-or-later (gadgets) |
| 0ad | `136720dada50` (2026-11-12) | GPL-2.0-or-later |
| warzone2100 | `b904885ffcec` (2026-11-11) | GPL-2.0-or-later |
| permafrost-engine | `083a99cace3e` (2026-10-07) | GPL-3.0 |
| CnC_Generals_Zero_Hour | `0a05454d8574` | GPL-3.0 plus EA's additional terms |

Every recommendation below is a small mechanism that can be written from its description; none needs ported code.

## 1. Executive conclusion

**The architecture is sound. Keep the Go WebSocket relay, client-side lockstep and JSON.** Every mature reference uses the same core shape: deterministic lockstep, reliable ordered delivery, one hub that forwards commands without simulating. OpenRA's dedicated server is the closest match: a relay with no simulation, over TCP.

What Wargrid lacks is not transport or topology but **policy around the lockstep**:

1. A dropped connection ends the match. No grace period, no resume, no way to continue without the seat. Fine for 1v1 with friends; for 3v3 one Wi-Fi blip ends the game for five other people.
2. The input delay is a fixed 4 ticks (`relay/room.go:20`). It is too much for nearby players and too little once the one-way path from sender through the relay to receiver passes about 133 ms (**derived**, §3). Zero Hour, Warzone 2100 and OpenRA's TickScale all adapt something to measured conditions. Wargrid adapts nothing.
3. The relay validates identity and tick order well but not volume. A seat can run arbitrarily far ahead and send 64 KiB frames, and one host can hold every connection slot on the machine.
4. Relay CPU per frame is the capacity limit on fly's shared CPU (about one 3v3 room, measured). The driver is network frame rate (30 frames/s per seat). The language comparison rules out Go as the cause. Ruling out JSON is an inference: the spike blames wakeups, syscalls and virtio, but no note isolates parse cost.

None of these needs a new transport, a server-side simulation or new infrastructure. WebSockets are not limiting current workloads. No measurement shows TCP head-of-line blocking hurting a Wargrid match. Loss has never been injected, so that is a gap in evidence, not proof it is fine (§8).

## 2. Top five improvements (ranked by expected benefit)

| # | Improvement | User-visible benefit | Confidence | Size | Depends on sim work |
|---|---|---|---|---|---|
| 1 | **Seat resume after a short disconnect**: relay keeps the seat for a grace period and replays the frames it missed; others see "waiting", not "match over" | Wi-Fi blips, laptop sleep, browser network change, relay-side socket errors no longer end matches | High (mechanism); frequency of blips in real play unmeasured | Medium: protocol 3, relay ring buffer, client reconnect | No: the client process keeps its state |
| 2 | **Agreed adaptive input delay**, Zero Hour / Warzone 2100 style, carried in-band so it stays deterministic; plus stall and arrival-slack telemetry first | Lower command latency for nearby players; fewer per-tick stalls for far ones | Medium-high (both references ship it; Wargrid gain must be measured) | Medium: client only, relay change minimal | No |
| 3 | **Continue the match when a seat leaves for good**, using the relay's existing `left{after_tick}` as the deterministic marker (OpenRA's model) | 3v3 survives a quit; base for M9's "becomes a bot" | High | Small on net side; sim needs a `seat_left` command and a policy (idle or bot) | **Yes** (simulation command, M9 scope) |
| 4 | **Relay volume guards**: lead bound (`tick ≤ min(other seats) + delay + 1`), per-seat byte budget, hello deadline, unstarted-lobby expiry, per-IP connection cap; relay-side hash comparison logged per match | One buggy or hostile client cannot flood peers or lock the machine; desyncs become visible in relay logs without user reports | High (the lead bound follows from the client's send order, see §7) | Small, all in `room.go`/`main.go` | No |
| 5 | **Network fault harness and 3v3 load**: a per-seat TCP fault proxy (delay, jitter, hold-and-burst, blackhole, reset), Go fuzzing of `parseEnvelope`, stall metrics in the netplay scenarios | Makes 1, 2 and 4 testable and keeps them from regressing; answers the WebSocket-under-loss question with data | High | Small-medium, tooling only | No |

Not in the top five but next: cutting relay frames per second (turn batching or the existing `WARGRID_BATCH_MS`) before the M9 3v3 gate, because one 3v3 room sits at the fly shared-CPU baseline (§6). It is ranked lower only because today's load is one friends match at a time.

Roadmap order differs from benefit order: build #5 first, because #1, #2 and #4 need it to show they work (§9). (Superseded 2026-11-13: the Relay guards and Adaptive input delay packages come before M9's fault harness; see Review 2026-11-13.)

## 3. Current architecture assessment

### How it works (code)

- **Relay** (`relay/`, Go 1.27.3, `github.com/lxzan/gws` v1.10.2). One goroutine per room owns all room state (`room.run`, `relay/room.go:74`). The registry lock is taken only on create, join, remove and the shutdown room count, never per frame. Reader goroutines post `tickMsg`/`leaveMsg` to a 64-slot channel. Writes go through gws's per-connection async queue, with a 1 MiB byte cap and a write deadline (`writeLater`, `relay/main.go:68`). A panic ends only its room (`recoverCrash`, `room.go:129`). SIGTERM drains for 3.5 s (`shutdown`, `main.go:196`).
- **Protocol 2**, JSON text frames, fixed by `protocol/vectors` and a black-box conformance suite (`protocol/conformance/conform.go`; 41 cases counted across its server profiles). Client to relay: `hello`, `tick{seat,tick,commands[],hash?}`, `ping`. Relay to client: `welcome`, `start{seats,delay,seed,settings}`, forwarded `tick` (byte-exact), `left{seat,after_tick}`, `pong`, `error`.
- **Relay checks per tick** (`room.forward`, `room.go:174`): match started, the seat field matches the connection's seat, and tick = previous + 1 (the first is 4). Commands are opaque apart from being an array. `hash` is syntax-checked (`validHash`, `envelope.go:45`) but never compared.
- **Client lockstep** (`game/scripts/net/lockstep.gd`). `submit` stamps a command with `_last_sent + 1` (line 55), so it runs 5 ticks after the current one at 30 Hz. `finish_tick` sends **one frame per simulated tick, empty or not** (line 112). It is called after `step()` with the new tick (`online_main.gd:58-59`), so after running tick T a seat sends the frame for `T + 1 + delay`. `advance` runs a tick only when every seat's frame for it is present, issuing commands in seat order (line 89). The simulation then sorts them by (tick, player, sequence) (`docs/reference/determinism-rules.md`). **This is the handoff point to the simulation:** `lockstep.advance` → `sim.issue_command` → `sim.step()`.
- **Pacing** (`game/scripts/online_main.gd:50`) is client-driven: one credit per physics frame (cap 4), at most 2 steps per frame. No server clock. A late frame stalls that client ("Waiting for player N"). Because every client needs every frame, the match runs at the pace of the slowest link or machine.
- **Desync**: a state digest every 30 ticks (`state_hash.gd`), carried in the outgoing frame and checked when that frame's tick executes (`_verify_hashes`, `lockstep.gd:212`). On mismatch the match ends `ended_desync` and writes a report `{seat, tick, hash_rows, command_log, snapshot}` (download in the browser). `tools/desync_diff.py` diffs two reports. `run_netplay.sh match` replays the command log through a headless oracle and compares three hash series.
- **Disconnect**: the relay turns a socket close into `left{after_tick}` (`room.leave`, `room.go:197`). The client plays up to `after_tick` and ends `ended_left`. Silence limits: relay read deadline 10 s (`WARGRID_SILENCE_MS`), client 5 s (`relay_transport.gd:6`), application ping 1 Hz.
- **Lobby**: none. A room fills in join order up to the global `WARGRID_SEATS` (default 2), then starts. The 6-character code from a 32-letter alphabet is about 30 bits.
- **Hosting**: fly `fra`, one shared-cpu-1x 256 MB machine that suspends when idle, at most 70 connections (`relay/fly.toml`).
- **Observability**: slog lines for open, close, create, join, start and `MATCH END` (frames and bytes per seat). No metrics; Prometheus was removed on 2026-11-08 (`docs/development.md#relay`). Client HUD and an end-of-match file show command-latency p50/p95 and RTT p95.

### Strengths (keep)

- **Determinism is proven, not assumed**: identical traces across Linux and Windows exports in CI (`godot-replays`) and macOS by `tools/compare_local_traces.sh`, oracle replay in the suite, one 10-minute browser-against-native match without desync (`docs/reference/m5-online.md`, `docs/reference/determinism-rules.md`).
- **The relay binds identity to the socket**: a client cannot speak for another seat. The client also rejects commands whose `player` or `tick` stamp does not match the frame (`_receive_tick`, `lockstep.gd:187`). Spoofing is closed off on both sides.
- **Actor-per-room with byte-exact forwarding**: no shared lock on the hot path, one copy of each frame shared by all recipients. The design fits everything M9 adds (timers, grace periods, lobby) as more `select` cases.
- **Test depth is unusual for the size**: conformance vectors, a black-box suite tested by mutation (`docs/reference/relay-stack-spike.md`), 11 end-to-end scenarios with real Godot clients, including relay kill and SIGTERM.
- **Cost**: zero on the legacy fly plan; Go relay 5.2 % of a shared vCPU per 3v3 room, 53 MiB VM memory idle including about 48 MiB guest base (measured, relay stack spike).

### Limitations and risks

| Risk | Evidence | Severity for M9 3v3 |
|---|---|---|
| Any socket drop ends the match for everyone | `leave` → `left` → `ended_left`; no reconnect path in code | **High** |
| Fixed delay: about 167 ms floor for everyone; stalls once the one-way path exceeds about 133 ms | `inputDelay = 4`; M5 command p50 174–181 ms at RTT p95 34–42 ms (measured). **Derived:** a frame sent after tick T is needed `delay + 1` = 5 ticks (167 ms) later, minus up to one 33 ms poll on the receiver, so roughly `(RTT_sender + RTT_receiver)/2 > 133 ms` stalls; send-flush timing (§7) may lower it | Medium |
| Slowest machine sets the pace as stall-and-burst stutter, with no smoothing | `online_main.gd` credit loop; no pace agreement | Medium (low-end target, browser) |
| Background browser tab freezes its client, stalls the match for everyone, then gets dropped at 10 s | MDN: "requestAnimationFrame() calls are paused in most browsers when running in background tabs" (docs); Wargrid behaviour **unverified** (Godot's web main loop runs on rAF, not checked in Godot source) | Medium-high for browser play |
| A seat can send up to 64 KiB frames as fast as its link allows; nothing bounds how far ahead it runs | `forward` checks contiguity only; the client caps queued ticks at 300 and then ends the match (`lockstep.gd:7`) | Medium (friends threat model) |
| 70 connections per machine, no per-IP cap, unstarted lobbies live as long as the creator pings | `fly.toml` `hard_limit = 70`; no lobby expiry in `room.go` | Medium once the URL is public (it is: the repository is public) |
| Relay CPU at the fly shared baseline with one 3v3 room | 6.25 % baseline vs 5.2 % per room; burst balance does not accrue while suspended (measured) | **High** for the 3v3 gate; throttling adds latency to every seat |
| Deploy ends live matches after 3.5 s | `WARGRID_DRAIN_MS`; fly `kill_timeout` max 300 s (docs, `relay-scaling.md`) | Low (manual, rare deploys) |
| Desyncs are visible only if a player sends the report | Report is local; relay does not compare hashes | Low-medium |

## 4. Comparative reference findings

Beyond All Reason has **no network code of its own**: it is a game (Lua) running on the Recoil engine. Its transport, pacing, sync check and reconnect are Recoil's and are counted once, under Recoil. BAR adds game-layer policy only (below). Permafrost Engine has **no multiplayer networking** (no net, socket or lockstep sources under `src/`), so it is excluded.

### Architecture comparison

| | Wargrid | OpenRA | Recoil (and BAR) | 0 A.D. | Warzone 2100 | Zero Hour |
|---|---|---|---|---|---|---|
| Hub | Dedicated relay, no sim | Dedicated or player-hosted server, no sim | Dedicated or host server, no sim | Host's server, no sim | Host | Host as "packet router" |
| Transport | WebSocket/TCP | TCP, `NoDelay` | UDP with its own reliable ordered layer | ENet, one reliable channel | TCP (default) or Valve GNS (UDP) | UDP |
| Who stamps the execution tick | Client (`tick + delay`) | **Server** (`frame + OrderLatency`, acks sender) | **Server** (commands enter the server's frame stream) | Client, server releases turns | Client (own queue time + agreed latency) | Client (`frame + runAhead`) |
| Input delay | Fixed 4 ticks (133 ms + 1 tick) | Static per game speed: 3 net frames × 3 ticks × 40 ms = 360 ms default | None fixed; client keeps a small jitter buffer | 4 turns × 200 ms = 800 ms | **Adaptive**, 100–1000 ms in 100 ms steps | **Adaptive** run-ahead, min 10 frames |
| Network frame rate | 30/s per seat (every tick) | 1 per 3 ticks | 30/s server frames | 5/s turns | 10/s | Frame grouping derived from run-ahead |
| Pace control | Client credit; stall when a frame is missing | Client; server TickScale slows fast clients up to 10 % | **Server clock**; LagProtection lowers speed by CPU load; server does not wait for laggers | Server releases a turn when all are ready | Clients wait; latency adapts | Router lowers frame rate to the slowest FPS |
| Sync check | Clients, every 30 ticks, whole-state digest | Server and clients, every net frame, plus defeat state | Server, every frame, majority vote | Server, every turn (quick), full every 20 turns | Every update, CRC of a sync-debug log | (not studied) |
| On desync | Match ends, report file | Message, 7-frame per-trait dump, game continues | Message, optional state dump, game continues | OOS dump, game continues | Dump; logs sent to host | (not studied) |
| Player drops | Match ends | Deterministic disconnect marker, game continues | Game continues (server clock keeps running; on timeout the server broadcasts PlayerLeft, `GameServer.cpp:2018-2023`); reconnect within `ReconnectTimeout`; BAR `/take` | Rejoin from a snapshot | (not studied) | Everyone waits behind a disconnect screen after 5 s; drop after 60 s or a unanimous vote; the dropped player's units and buildings are destroyed (corrected 2026-11-13, from [dropped players](../questions/next-m9-drops.md)) |
| Rejoin | None | None (saved games only) | Replay the whole cached packet stream | **Snapshot from a peer** + saved commands | (not studied) | None found (corrected 2026-11-13, [dropped players](../questions/next-m9-drops.md) Q11) |
| Flood limits | 1 MiB write queue; 64 KiB frame | 128 KiB order cap; chat flood limit | Per-player token bucket (2 KiB/s sustained, 32 KiB peak, 64 pkt/s) | Turn-order checks | (not studied) | (not studied) |

### Lockstep scheduling and input delay

- **Zero Hour** (`GeneralsMD/Code/GameEngine/Source/GameNetwork/ConnectionManager.cpp:1213` `updateRunAhead`, `Network.cpp:644` `processRunAheadCommand`, `NetworkUtil.cpp:30-31`, `Common/GlobalData.cpp:936-938`). Every `m_networkRunAheadMetricsTime` = 500 ms (corrected 2026-11-13: that is the code default, `Common/GlobalData.cpp:936`; retail sets `NetworkRunAheadMetricsTime = 5000` in `data\ini\gamedata.ini:454`, mapped at `GlobalData.cpp:480`, so shipped Zero Hour recomputes every 5 s), the packet router takes the maximum latency and minimum FPS over all players. It computes `runAhead = maxLatency/2 × minFps` plus `m_networkRunAheadSlack` = 10 %, bounded by `MIN_RUNAHEAD` = 10 and `MAX_FRAMES_AHEAD/2` = 64. It sends the result as an in-band command that executes on a future frame. The same command sets the game frame rate and the packet grouping interval. **This is the design Wargrid's identity points to**: delay and pace adapt to the worst player, and everyone gets the same value. Zero Hour's floor of 10 frames (333 ms at 30 fps) is far above Wargrid's 4 ticks; Wargrid need not copy the floor.
- **Warzone 2100** (`lib/gamelib/gtime.cpp:550` `updateLatency`, `:591`, `sendPlayerGameTime`). Each client measures how long its last update waited for others and broadcasts a `wantedLatency` in every `GAME_GAME_TIME` message. Every client computes the same `chosenLatency = max(wanted)` from the same messages, so the result is deterministic. It rises at most 60 ms and falls at most 5 ms per update, and is rounded to whole 100 ms updates between 1 and 10 (`gtime.h:39`). A `gameTimeSetDeterministicLatency` switch freezes the negotiation for traces and benchmarks (`gtime.h:173`), so orders apply on reproducible ticks. **Most directly portable idea** (as a design, not code): no relay involvement, deterministic, fair.
- **OpenRA** (`OpenRA.Game/Server/Server.cs:911-945` `ReceiveOrders`, `OrderBuffer.cs:83` `GetTickScales`, `Network/OrderManager.cs:300` `TryTick`, `Session.cs:222`). The server adds `OrderLatency` to each client's frame and sends the sender only an Ack (its own orders wait in a local queue). Delay is static per game speed (`mods/ra/mod.yaml:285-307`); the code carries `// TODO: Replace static latency with a dynamic order buffering system` (`Server.cs:929`). `OrderBuffer` records when each player's frame arrives relative to a baseline player. Once a second it tells clients whose frames arrive early to slow down by up to 10 % (`MaxTickScale = 1.1f`). Lagging links then stop causing stall-and-burst. `NetFrameInterval = 3` sends one packet per 3 ticks, "to improve robustness against network jitter at the expense of input latency" (`OrderManager.cs:330-331`).
- **Recoil** (`rts/Net/GameServer.cpp:2640` `CreateNewFrame`, `:888` `LagProtection`, `rts/Net/NetCommands.cpp:186-208`). The server emits frames on its own clock and never waits for a slow client. A slow client falls behind and catches up. LagProtection lowers the game speed so the highest (or median) player CPU load stays at 75 % (or 60 %). The client keeps a few frames queued and adjusts its consumption speed to the queue length ("we *NEVER* want the queue to run completely dry", `NetCommands.cpp:191`). Fair to good players; bad for whoever lags. BAR's Take Manager then lets allies take over units of players whose ping exceeds 33 s (`luarules/gadgets/cmd_idle_players.lua:21`, `:145`).
- **0 A.D.** (`source/simulation2/system/TurnManager.h:63-82`, `source/network/NetServerTurnManager.cpp:80` `CheckClientsReady`). 200 ms turns; multiplayer commands are delayed 4 turns (800 ms). The server releases turn N only when every client has finished sending for it. The code says the delay "could vary based on server-client pings" (TODO, `TurnManager.h:79`). Observers may lag (`network.observermaxlag`).

**Takeaway for Wargrid:** network frame rate and input delay are separate knobs. OpenRA (`NetFrameInterval`) and Zero Hour (frame grouping) send fewer network frames than simulation ticks. 0 A.D. (one simulation update per 200 ms turn, `TurnManager.cpp:155`) and Warzone 2100 (10 game updates/s) send one message per simulation step like Wargrid, at a lower simulation rate. Two shipping games (Zero Hour, Warzone 2100) adapt delay to measured lag and keep it identical for all players by negotiating it in-band.

### Latency, jitter and transport

- Every reference uses **reliable, ordered delivery** for the command stream, including those on UDP. 0 A.D. opens ENet with one channel (`NetServer.cpp:85`). Recoil builds its own resend and ack logic in `rts/System/Net/UDPConnection.cpp`. Lockstep needs every command for every tick, so dropping a late packet is never an option; UDP only buys control over retransmission timing and redundancy. OpenRA runs on plain TCP with `NoDelay = true` (`Network/Connection.cs:142`). Warzone 2100 defaults to TCP and offers Valve GameNetworkingSockets behind one provider interface (`lib/netplay/connection_provider_registry.h:33-37`).
- **Ping and quality display**: OpenRA keeps a 15-sample ping history per connection and labels Good/Moderate/Poor against the order lag (`Server.cs:1179` `ReceivePing`). 0 A.D. tells other players when a client has been silent for 2 s or its mean RTT exceeds half the command window (`NetServer.cpp:101`, `:583`, `NetProtocol.h:33`). Wargrid measures RTT but shows only its own p95.
- **Browser constraint** (docs): MDN marks WebTransport "Baseline 2026, Newly available"; caniuse lists Safari support from 26.4. Godot's `WebSocketPeer` exposes `set_no_delay` and `heartbeat_interval` (Godot 4.7.2 `--doctool`; descriptions and defaults were not dumped). Wargrid sets neither (`relay_transport.gd`). Whether Godot's native WebSocket disables Nagle by default is **unverified**. The Rust spike showed Nagle plus delayed ACK adding about 18 ms p50 (`relay-stack-spike.md`), so this deserves a five-minute check.

**Is WebSocket limiting Wargrid now? No evidence says so.** The measured command latency is dominated by the 4-tick delay (M5 note). Relay-added p99 is 1.6–8.7 ms locally. Loss and jitter have never been injected. TCP head-of-line blocking on loss is real in principle: after a lost segment, later frames wait for the retransmit. But lockstep must wait for that command anyway. The only gain a datagram transport offers is redundancy (repeat recent ticks' commands in every packet so a single loss costs nothing). That needs WebTransport in the browser, a QUIC stack natively (Godot has neither built in) and a second relay listener. Measure first (§8).

### Lag handling and player experience

| Situation | Wargrid today | Best reference behaviour |
|---|---|---|
| One player high latency | Everyone stalls each tick their frame is late | ZH/WZ: delay rises for everyone, no stalls |
| Latency jumps | Stalls until the network recovers | WZ: latency climbs ≤60 ms per update, drops slowly; OpenRA TickScale smooths arrival skew |
| Short loss burst | TCP retransmit → stall (not measured) | Same in all TCP/reliable engines; Recoil's resend tuning |
| Client freezes for seconds | Everyone stalls; at 10 s the relay's read deadline drops it → match over. (The client's own 5 s silence rule does not fire: on unfreezing it polls buffered frames first, which refresh its receive time, `online_main.gd:51-52`, `relay_transport.gd:30`. Review 2026-11-13: this holds when the other seats sent frames during the freeze, the usual case; if nothing arrived meanwhile, the 5 s rule fires on thaw.) | 0 A.D.: other players get a "client timed out" notice after 2 s and keep waiting |
| Background browser tab | Expected: client stops, match stalls, dropped at 10 s (**unverified**) | No reference runs in a browser |
| Slow hardware | Stall-and-burst at the slowest machine's pace | ZH: frame rate lowered to the minimum FPS; Recoil: speed lowered to hold CPU at 75 % |
| Disconnect then reconnect | Match over | Recoil: rejoin and fast-forward the full stream; 0 A.D.: rejoin from a peer's snapshot |
| Quit | Match over | OpenRA: deterministic disconnect marker, game continues; BAR: allies `/take` units |

### Desync detection and recovery

- **Detection**: OpenRA, Recoil and 0 A.D. compare hashes **on the server**. Recoil votes by majority on a dedicated server, so a 3v3 desync names the odd client out (`GameServer.cpp:595` `CheckSync`). 0 A.D. trusts the host (`NetServerTurnManager.cpp:148`). Wargrid compares on clients only. That is enough to stop a match, but in 1v1 it cannot say who diverged, and nothing reaches the relay log.
- **Granularity**: OpenRA keeps a ring of the last 7 frames of per-trait values tagged `[Sync]` and dumps it on mismatch (`Network/SyncReport.cs:25`). Warzone 2100 keeps 12 ticks of a "sync debug" log (every sync-relevant event, each with a CRC) and **sends the desync logs to the host** (`lib/netplay/sync_debug.cpp:297`, `:789`). Recoil has a build-time sync debugger that pauses the game and bisects (`rts/CMakeLists.txt:18` `SYNCDEBUG`). 0 A.D. writes a full serialized state (`NetClientTurnManager.cpp:124`). BAR adds a gadget that stresses many unit types and saves a per-frame sync-hash series (`luarules/gadgets/dbg_synctest.lua`).
- **Wargrid's advantage**: the full command log plus a headless replay reproduces a match exactly (`run_netplay.sh` oracle). A per-tick hash series from two replays finds the first divergent tick with no extra in-game cost, provided the divergence reproduces on the same platform. For cross-platform divergence (browser against native), replay the same log on both platforms and compare per-tick hashes; the tools exist (`compare_replays.py`), the browser replay path does not.
- **Recovery**: no reference resynchronises a desynced client automatically. All except Wargrid let the game continue in a desynced state, which only makes sense with spectators or for debugging. Wargrid ending the match is honest. **Recommendation: better detection and diagnostics first, no automatic recovery.**

### Server architecture

- All references run **one process per game** (Recoil's dedicated server, OpenRA's server, 0 A.D.'s host). Wargrid's many rooms in one process with a goroutine each is lighter and already isolates crashes per room.
- Recoil keeps every broadcast packet (`packetCache`, `GameServer.cpp:563-564`) so that reconnecting players and late spectators can replay from the start. Wargrid's measured cost of keeping every frame (113 MiB per hour-long room for the Go relay, relay stack spike) shows why a full-stream cache does not fit a 256 MB machine. A **short ring** for resume (seconds) and, later, a commands-only log for rejoin do fit (derived: about 52 B × 30 × 6 seats ≈ 9.4 KB/s per room, so 30 s ≈ 280 KB). (Corrected 2026-11-13: while the match waits for the away seat, the lead bound of §7 keeps every other seat within `delay + 1` ticks of the away seat's last frame, so the resume ring holds a few frames per seat; a ring sized in seconds is needed only if the match keeps running without the away seat, §10 E.)
- 0 A.D.'s rejoin asks an existing player for a serialized state and forwards it (`NetServer.cpp:1141-1185`), then sends the saved commands since then (`:1458`). No server-side simulation needed, but a deterministic state restore is. Wargrid has `snapshot()` but no restore (`docs/reference/sim-interface.md`).

### Security and adversarial behaviour

- OpenRA drops order packets above 128 KiB (`Server/Connection.cs:26`) and rate-limits chat (`PlayerMessageTracker`). It drops a client that sends game frames before the start (`Server.cs:915`).
- Recoil applies a per-player incoming token bucket by default (sustained 2 KiB/s, peak 32 KiB, 64 packets/s, 512 waiting packets; `rts/System/GlobalConfig.cpp:42-57`, applied in `ServerReadNet`, `GameServer.cpp:2003-2117`). Sync and keyframe packets are exempt from dropping.
- 0 A.D. disconnects a client that skips a turn in its ready messages (`NetServerTurnManager.cpp:64`). Wargrid's contiguity check is the same idea.
- BAR's command limiter is **client-side** (700 shift-queued build orders per 6 s, warnings, then forced resign; `luarules/gadgets/cmd_limiter.lua`): a courtesy guard against accidental spam, not a security boundary.
- No reference prevents map hacking: every client in lockstep holds the full state. Only a server-authoritative simulation with interest management would.

## 5. Protocol and synchronization recommendations

### P1. Seat resume within a grace period (top 1)

- **Reference**: Recoil reconnect (`GameServer.cpp:2937` `BindConnection`, `ReconnectTimeout` default 15 s, `GlobalConfig.cpp:24`); 0 A.D. rejoin flow (`NetServer.cpp:1044-1121`).
- **Now**: `OnClose` → `leave` → `left` at once (`main.go:95`, `room.go:197`).
- **Change** (protocol 3): `welcome` carries a random resume token (128 bits, never the match code). On close the relay marks the seat `away`, starts a grace timer in the room's `select` and keeps a ring of the frames sent to it (the last N seconds; the other seats' frames; corrected 2026-11-13: about `2 × delay + 2` frames per seat while the match waits, see §4 Server architecture). Frames from the away seat stop, so the others stall naturally with "Waiting for player N". The client reconnects with `resume{token, last_received[seat]}`, the relay replays the ring from there, and play continues. The client keeps its simulation, so there is no replay of the match and no snapshot. `left` is sent only when the timer fires. Frames the away client sent but the relay never received are lost with the socket. So the relay answers `resumed{last_tick}` with the last tick it accepted from that seat, and the client resends everything after it.
- **Benefit**: removes the most likely cause of a lost 3v3 match (high confidence for the mechanism; real-world blip frequency unmeasured). The client-side 5 s silence rule must turn into "reconnect" instead of "end".
- **Trade-offs**: everyone waits during the grace period (already the case for up to 10 s). The ring costs relay memory (derived: a few hundred KB per room for 30 s; corrected 2026-11-13: a few frames per seat while the match waits, see §4 Server architecture). The browser needs a new `WebSocketPeer` per attempt; a token in a URL query string would show in proxy logs, so send it in the first message.
- **Validation**: fault proxy `reset` and `blackhole 3 s` per seat (§8). Expect `match_over` with identical hashes, plus a stall counter showing the pause. Conformance cases: resume with wrong token, double resume, resume after timeout → `unknown seat`, resume from another seat's token.
- **Sim dependency**: none.

### P2. Agreed adaptive input delay (top 2)

- **Reference**: Warzone 2100 `updateLatency` (in-band, max of wants, ramp up fast and down slowly, quantised); Zero Hour `updateRunAhead` (router computes from max latency + 10 % slack, executes on a future frame).
- **Now**: `delay` comes from `start` and never changes. The `+1` in `submit` adds a tick for every command.
- **Change**:
  1. First add telemetry (cheap, needed anyway): per peer frame, the **arrival slack** = time between the frame's arrival and the moment the tick wanted to run (negative means a stall). Also per match: stall count and total stall time. Add them to the `NETPLAY LATENCY` line and the HUD.
  2. Each tick frame carries an optional `want` (the delay this seat would like, from its slack percentiles and RTT). When every client executes tick T, it computes `delay' = clamp(max(want in the frames for T), 1, D_max)`, limited to +2/−1 tick per change and at most one change every 15 ticks. All clients read the same frames, so all compute the same value. The new delay applies to frames sent after T. Raising the delay means sending extra frames to fill the gap; queued commands are stamped `_last_sent + 1` and peers reject a stamp that differs from its frame (`lockstep.gd:196`), so the queue goes into the first gap frame and the rest are empty. Lowering it means skipping sends until `T + 1 + delay'` passes the last sent tick. Tick contiguity holds either way, so the relay's rule is unaffected.
  3. Relay: `inputDelay` remains only the start value; the lead bound (§7, S1) uses `D_max`.
- **Why agreed and not per seat**: a per-seat delay is also deterministic (commands carry their tick), but a seat that picks a small delay reacts faster in game time while everyone else stalls, which is a lag-switch advantage. Zero Hour and Warzone 2100 both give everyone the same value.
- **Benefit**: for players near `fra`, command latency could drop by one or two ticks (derived from M5's RTT p95 34–42 ms against a 133 ms window; **not measured**, the slack telemetry tells). For far players, no per-tick stalls in exchange for a higher steady delay. Medium-high confidence: the mechanism is shipped by two references; the size of the gain must be measured.
- **Trade-offs**: slightly more client code; the delay must be logged in the command log, or the replay oracle cannot reproduce frame timing. The command ticks are already in the log, so replays stay exact even without it.
- **Validation**: fault proxy with per-seat delay 20/80/150 ms and jitter ±30 ms. Compare command latency p50/p95, stall count and stall ms against the fixed-delay baseline on the same scenario seed. Add a `--fixed-delay` switch (WZ's deterministic mode) so the existing pinned-terminal-tick scenario stays unchanged.
- **Sim dependency**: none.

### P3. Continue after a permanent leave (top 3)

- **Reference**: OpenRA `ReceiveDisconnect` inserts a marker that all clients process "on the same world tick" (`OrderManager.cs:147`); the server writes it at `LastOrdersFrame + 1` (`Server.cs:1265`). BAR's `/take` (Recoil gadget) hands units to allies.
- **Now**: the relay's `left{after_tick}` is exactly this marker. The client uses it to end the match (`advance`, `lockstep.gd:92`).
- **Change**: on `left`, treat the seat's frames after `after_tick` as empty and issue a deterministic `seat_left` command at `after_tick + 1`. The simulation applies the M9 policy (units idle, team shares, or bot). Not a network problem; the network side is about 20 lines.
- **Validation**: existing `kill` scenario changed to expect play to continue to `match_over` with identical hashes on the remaining seats (needs 3 seats).
- **Sim dependency**: **yes**, a simulation command and the drop policy (blueprint M9: "handling a dropped player (pause, or the player becomes a bot)").

### P4. Network frame rate separate from tick rate (scalability; see S4)

- **Reference**: OpenRA `NetFrameInterval = 3`; Zero Hour frame grouping.
- **Now**: one frame per tick per seat; the relay forwards 6 × 30 × 5 = 900 frames/s per 3v3 room.
- **Change** (experiment): a frame covers K ticks (`tick` = last tick covered, commands keep their own tick). K = 2 halves frames at a cost of at most one tick of extra command wait; combined with P2 the delay absorbs it. The relay's contiguity rule becomes "first covered tick = previous last + 1".
- **Benefit**: relay CPU is per-frame dominated (Go 93 µs per inbound frame at 10 rooms, measured), so frames/s is the cost driver. The existing 33 ms relay batching (one write per recipient per interval) halved CPU at +18 ms p50 (measured). Client-side K = 2 removes inbound parsing and syscalls as well, but the size of the gain is unmeasured.
- **Sim dependency**: none.

### P5. Desync: relay comparison, first divergent tick, collection

- **Reference**: server comparison in OpenRA (`Server.cs:816` `HandleSyncOrder`), Recoil (`CheckSync`, majority), 0 A.D. (`NotifyFinishedClientUpdate`); Warzone 2100 sends desync logs to the host.
- **Change**:
  1. The relay records `hash.value` per seat per hash tick (it already parses the field). On mismatch it logs `DESYNC code tick seats=<groups>`; with three or more seats the majority group names the odd seat. Cost: one string compare per seat every 30 ticks. Behaviour unchanged (clients still end the match).
  2. Offline tool: replay a desync report's command log headless with a hash on **every** tick and diff snapshots at the first divergent tick. That turns "somewhere in these 30 ticks" into one tick and one field. Mostly glue over `compare_replays.py` and the oracle path.
  3. Later, with the M9 analytics store (lobby deep dive: "desync uploads"): upload the report instead of a manual download.
- **Not recommended now**: per-subsystem hash rings in the running game (OpenRA style). Command-log replay gives more for less, unless a desync turns out to be non-reproducible on replay (platform or memory dependent). Revisit then.

## 6. Server architecture and performance recommendations

### S1. Keep one process, many rooms, on fly; size CPU before the 3v3 gate

- **Evidence**: fly's shared CPU baseline is 6.25 % and does not refill while suspended; one Go 3v3 room is 5.2 % (measured). A second concurrent room, or a busier room, throttles **every** room on the machine, and in lockstep throttling shows up as stalls for all players.
- **Options, cheapest first**: (a) cut frames/s with P4 or the existing `WARGRID_BATCH_MS` (the client must parse newline-joined frames first); (b) `performance-1x` (listed at $33/month, billed per second, so cheap while suspended; already parked for M9 planning in the blueprint); (c) more shared machines with the owner in the match code (`relay-scaling.md` R2), which also buys fault isolation.
- **Validation**: the spike's load harness (`~/projects/wargrid-relay-spike`, outside the repository) on fly: 1, 2 and 4 rooms with K = 1 and 2 and with 33 ms batching; record `fly_instance_cpu`, `_cpu_balance`, `_cpu_throttle` and relay-added p99. Decide from the numbers.

### S2. Micro-optimizations: not worth doing now

`parseEnvelope` decodes into `map[string]any` and `bytes.Clone`s each frame (`main.go:136`). At 180 inbound frames/s per room that is a few hundred small allocations per second. The measured cost sits in wakeups, syscalls and virtio interrupts (relay stack spike: per-frame cost falls from 93 µs to 18 µs as load grows). Hand-written parsing or buffer pools would be marginal. Fewer frames (P4) is the lever. If profiling is wanted anyway: `go test -bench` with `-benchmem` on `forward`, and `pprof` under the spike harness.

### S3. Deploys without killing matches, the cheap way

The relay already counts rooms (`registry.count`). Expose it (`/health` body or a one-line `/rooms`), and make the manual deploy command and the release workflow wait until it reads 0 (with a timeout and an override). That gives zero dropped matches for the cost of a wait. Multi-machine blue/green drain stays M9 (`relay-scaling.md`).

### S4. Crash recovery

A relay crash or host loss ends every live room. With P1 in place, the cheapest availability step is `relay-scaling.md` option B: clients resend their command history to a restarted relay. It needs P1's resume protocol plus a commands-only log on the client. Redis (option C) adds a dependency for the same result. Keep for M9 planning; do not build before P1.

## 7. Security and reliability recommendations

Threat model: private matches among friends, a public repository and a public relay URL, no accounts. Goal: a stranger cannot take the service down cheaply, and a buggy or hostile participant cannot hurt the relay or other matches. Within a match, participants can always ruin their own game (by leaving); lockstep cannot stop map hacking (§4); neither is worth relay complexity.

| # | Guard | Where | Why it is correct | Cost |
|---|---|---|---|---|
| S1 | **Lead bound**: reject a tick frame with `tick > min(max(lastTick, d−1) over other seats) + D_max + 1` | `room.forward` | An honest seat sends `T + 1 + d` only after running T (`finish_tick` runs after `step()`), and running T needed every seat's frame for T. Those passed through this same room goroutine first, so the bound holds for honest clients. At the start the preloaded empty ticks below `d` (`lockstep.gd:46-47`) let a seat send up to `2d` before hearing from anyone, which is exactly `(d−1) + d + 1`. The `+ 1` is required: without it an honest seat is rejected at the start and in steady state. Rules to state in the plan: with no other seat left, skip the check; a rejected (`dead`) or, under P1, away seat stays in `r.seats` with a frozen `lastTick`; that tightens the bound, but honest seats cannot pass its frames anyway, so it stays valid. It caps per-seat lead and therefore relay queue growth from a racing client; the client-side cap of 300 queued ticks stays as the backstop (`lockstep.gd:7`). | ~10 lines + conformance cases for both edges |
| S2 | **Per-seat byte budget** (token bucket, Recoil style) in addition to the 64 KiB frame cap | `room.forward` | A seat inside S1 can still send 64 KiB per tick, about 1.9 MB/s to every peer (derived), enough to trip a slow peer's 1 MiB queue and disconnect the *victim*. Calibrate sustained and peak from real play: log max frame size and peak bytes per second per seat in `MATCH END` first; legitimate average is about 1.55 KB/s (measured). | small |
| S3 | **Hello deadline** (a few seconds) separate from the 10 s silence | `OnOpen` | Today a socket may sit 10 s before saying anything. | 1 line |
| S4 | **Unstarted lobby expiry** (say 15 min) | room timer in `run()` | A creator that pings keeps a room alive forever. | small |
| S5 | **Per-IP connection cap and join rate limit** | `newServer` | 70 connections per machine (`fly.toml`); one host could take them all. Needs the client IP from the proxy (`X-Forwarded-For`, trusted only behind the platform edge, set by env to stay cloud-agnostic). Also slows code guessing (30-bit codes). Already on the M5 and lobby-design lists. | small-medium |
| S6 | Origin check | upgrader | Low value: no cookies or auth to steal, and native clients send no Origin. Skip until accounts exist (the lobby design adds HMAC tickets). | — |

Not relay work: command *content* validation. The simulation validates every command deterministically (`issue_command` returns `ok`/`error`; rejections are reported in `lockstep.gd:105`), which is the authoritative check every lockstep engine relies on. The relay cannot do better without simulating.

Reliability, client side:
- **Background tab**: measure it first (§8 scenario). If it behaves as expected (frozen, dropped at 10 s), the minimum fix is UX plus P1: the returning tab resumes and catches up (the existing 2-steps-per-frame credit). Whether the match should keep running without the hidden player (relay-filled empty frames, as Recoil's server keeps its clock) is a game-design decision; see §10, E-lite.
- **Nagle and flush timing**: check whether Godot's native `WebSocketPeer` sets `TCP_NODELAY` and whether `send_text` writes at once or on the next `poll()`. If the latter, each hop waits up to one physics frame (33 ms). Cheap test: timestamps in a two-client local run with and without `set_no_delay(true)` and an extra `poll()` after `send_text`.

## 8. Network testing and observability plan

### Infrastructure (small, in-repo, no new services)

1. **Fault proxy** (`tools/netfault/`, Go, about 150 lines): a TCP proxy per seat between the Godot client and the relay. Per-direction fixed delay, jitter (uniform or normal), hold-and-burst (stop forwarding for X ms, then release; this is what TCP loss looks like to the application), blackhole (drop and keep the socket), reset, bandwidth cap. Scriptable timeline (`at 30s blackhole 3s`). Works on macOS without root, unlike `dnctl`/`pfctl`. Real packet loss with TCP retransmission needs `tc netem` in a Linux container (Apple `container`; whether it grants `NET_ADMIN` is **unverified**); use it only to confirm the proxy's hold-and-burst model once.
2. **Metrics in existing outputs, not Prometheus** (the user removed it on 2026-11-08; corrected 2026-11-13: both, relay `/metrics` stays for live health, see Review 2026-11-13): client `NETPLAY LATENCY` line gains stall count, stall ms, arrival-slack p5/p50 and delay changes. Relay `MATCH END` gains duration, end reason per seat, desync tick and groups (P5), max lead, max frame bytes, queue high-water mark.
3. **Go fuzz** `FuzzParseEnvelope` (and later `FuzzResume`) next to `envelope_test.go`; seed corpus from `protocol/vectors`.
4. **Conformance cases** for every new rule: lead bound, byte budget, hello deadline, lobby expiry, resume (wrong token, late, duplicate, other seat).

### Scenarios

| Scenario | How | Pass criteria / metrics |
|---|---|---|
| 1v1 low latency | `run_netplay.sh match` (exists) | Pinned terminal tick, three-way hashes (exists); add stall count = 0 |
| 1v1 asymmetric latency | proxy 10 ms on seat 1, 120 ms on seat 2 | Hashes equal; command latency p95, stalls (baseline vs P2) |
| High jitter | proxy ±40 ms jitter both seats | Stall count and ms, slack distribution |
| Burst loss | proxy hold-and-burst 300 ms every 20 s | Stall ms ≈ hold time, no protocol errors |
| Badly lagging player | proxy 250 ms on one seat | P2: steady delay, no per-tick stalls |
| Temporary disconnect | proxy reset at tick 600, reconnect | P1: `match_over`, equal hashes, one stall of grace length |
| Permanent quit, 3 seats | `--exit-at-tick` (exists) | P3: remaining seats reach `match_over` with equal hashes |
| Slow simulation client | new `--slow-ms N` (delay per tick, periodic, unlike the one-shot `--stall-at-tick`) | Pace and stalls; later pace agreement |
| Background tab | manual, Chrome/Firefox/Safari, hide for 3 s, 8 s, 15 s | Time to `left` or resume; written checklist |
| Multiple simultaneous matches | spike load harness on fly, 1/2/4 rooms | CPU, balance, throttle, relay p99 |
| Malformed / abusive | conformance + fuzz; flood client (max-size frames, racing ticks, 70 sockets) | Rejected or closed with the right reason; other rooms unaffected (latency unchanged) |
| 3v3 varied latency | needs the client to run 6 seats (M9); until then 3 seats if the netclient supports it | Same metrics, per seat |

### Comparing baseline and change without confusing sim and network cost

- Same map, seed and seat scripts; `--fixed-delay` for the baseline (Warzone 2100's deterministic mode is the model).
- Separate the two causes of a missed tick in the client counters: **waiting for a peer frame** (network) vs **credit exhausted / step too slow** (simulation). Only the first counts as a network stall.
- Headless clients for network behaviour; simulation time is already in `run_benchmark.sh` and the performance ledger. Never compare a network change using the rendered benchmark.
- Repeat each fault scenario at least 5 times and report ranges (the fly latency in the stack spike did not reproduce across runs). Tag runs on a loaded host, as the performance ledger does.

## 9. Prioritized implementation roadmap

Each step is its own small package with its own plan and stop gate; none is approved by this report. (Superseded 2026-11-13: the order and placement decided with the user are in Review 2026-11-13.)

| Step | Contents | Category | Protocol change | Sim change |
|---|---|---|---|---|
| 0 | Fault proxy, stall and slack telemetry, relay `MATCH END` fields, fuzz target, Nagle/flush check | High-value immediate | No | No |
| 1 | Relay guards S1–S4 (lead bound, byte budget after calibration, hello deadline, lobby expiry); relay hash comparison logged (P5.1); `/rooms` deploy wait (S3) | High-value immediate | No (new `error` reasons only, conformance cases added) | No |
| 2 | Seat resume with grace (P1) | High-value immediate for M9 | Protocol 3 | No |
| 3 | Agreed adaptive delay (P2), measured against step 0 baselines | Experiment, then adopt | Optional `want` field (additive) | No |
| 4 | Continue after leave (P3) | M9 scope | No | Yes |
| 5 | Frames per K ticks (P4) or relay batching; fly CPU sizing (S1) | Experiment before the 3v3 gate | Yes (frame covers K ticks) | No |
| 6 | Per-tick-hash replay bisect tool, browser replay path (P5.2) | Experiment | No | No |
| 7 | Per-IP caps (S5), several machines, client-held log recovery after relay restart (S4) | Future scalability | Some | No |
| 8 | Snapshot rejoin for a client that lost its process | Future | Yes | **Yes** (deterministic restore) |

### Recommendation matrix

| Recommendation | Type | Benefit | Confidence | Effort | Risk |
|---|---|---|---|---|---|
| Fault proxy + telemetry | Infrastructure | Enables everything else | High | S | Low |
| Lead bound | Confirmed gap | Abuse and queue growth | High | S | Low (argued in §7; edges covered by conformance) |
| Byte budget | Confirmed gap | Peer flood | High | S | Medium: a budget set too low cuts real players; calibrate first |
| Hello deadline, lobby expiry | Confirmed gap | Resource hold | High | S | Low |
| Relay hash compare | Observability | Desync visibility, odd seat in 3v3 | High | S | Low |
| Deploy wait for 0 rooms | Ops | No dropped matches on deploy | High | S | Low |
| Seat resume | Missing feature | Survives blips | High | M | Medium: new state machine; must not hold dead seats forever |
| Adaptive agreed delay | Speculative improvement | Latency and fewer stalls | Medium-high | M | Medium: oscillation; ramp limits from WZ |
| Continue after leave | Missing feature | 3v3 survives quits | High | S net + sim | Depends on drop policy |
| Frames per K ticks / batching | Measured bottleneck (fly CPU) | Rooms per machine | Medium | M | Latency cost of up to K−1 ticks |
| Nagle / flush check | Speculative | 0–33 ms per hop | Unknown | XS | Low |
| Pace agreement for slow machines | Speculative | Smoother play on low-end hardware | Medium | M | Interacts with the worker-thread design |
| Per-tick-hash bisect | Tooling | Faster desync fixes | High | S | Low |
| Snapshot rejoin | Future | Rejoin after a crash | Medium | L | Needs deterministic restore |

## 10. Rejected alternatives and reasons

| Option | Verdict | Reason |
|---|---|---|
| **A. Keep and improve the relay** | **Adopt** | Sound shape (matches OpenRA's dedicated server), measured cheap, well tested. Everything in §5–§7 is incremental. |
| **B. WebSockets with better scheduling, protocol and buffering** | **Adopt** (this is §5) | All gains named here fit over WebSocket: adaptive delay, resume, K-tick frames, guards. |
| **C. Second transport for native clients** (UDP/ENet, QUIC, WebTransport, WebRTC) | **Reject now** | No measurement shows WebSocket limiting play. Every reference sends the stream reliable and ordered, so UDP's gain is limited to redundancy and retransmit control. It doubles the transport surface (relay listener, conformance, two client paths). Godot has no built-in QUIC or WebTransport; ENet has no browser path. WebTransport in browsers is only "Baseline 2026, Newly available" (MDN), Safari from 26.4 (caniuse). WebRTC data channels need signalling and TURN and change the topology. Revisit only if the burst-loss scenario shows stalls that redundancy would remove and that are large enough to matter. |
| **D. Server-authoritative simulation** | **Reject** | Needs the GDScript simulation in a server process per match: memory per match is far above a relay room, and simulation CPU (milliseconds per tick, performance ledger) is impossible on a 6.25 % shared vCPU. It also needs state replication and interest management, which is a different game architecture. The only unique gains are anti-map-hack and join-in-progress without a client snapshot; neither matters for friends' matches. |
| **E. Hybrid: relay controls scheduling and validates what it can see** | **Adopt the light parts, reject the heavy ones** | Adopt: lead bound, byte budget, hash comparison, resume ring (all §5–§7). Reject for now: OpenRA-style server stamping (moves delay control to the relay but adds an Ack round trip for one's own commands; the in-band WZ method gets adaptive delay without it) and Recoil-style server clock (never waits for laggers, which suits large games with spectators; Zero Hour waits and adapts, closer to Wargrid's identity). **Open design question for M9 (user's call):** while a seat is away (resume grace, background tab), should the match pause for everyone (today; Zero Hour pauses: a disconnect screen after 5 s, drop after 60 s or a unanimous vote, corrected 2026-11-13 from [dropped players](../questions/next-m9-drops.md), where this is Q1) or continue with the relay filling empty frames for the away seat (Recoil-like)? Both are deterministic; the second is fairer to those present and harsher to the one away. |
| Redis / external store for room state | Defer | Clients already hold the same data (`relay-scaling.md` option B); only after P1. |
| Binary encoding instead of JSON | Defer | Bytes are not the bottleneck; frames per second are. Relay forwards bytes as-is; a format change touches every vector and test for little measured gain. Revisit if P4 is not enough. |
| Prometheus metrics endpoint | Do not reintroduce yet | Removed by the user (2026-11-08); log fields cover the questions here. (Corrected 2026-11-13: the Is Wargrid healthy package keeps a relay `/metrics` for live health; log fields add the per-match detail.) |
| Per-subsystem in-game sync rings | Defer | Command-log replay already reproduces divergences; build rings only if a desync does not reproduce on replay. |

## Gaps and unverified points

- Background-tab behaviour of the Wargrid web client: expected from MDN (rAF paused), not observed. Whether browsers answer WebSocket pings for hidden tabs (useful to tell "hidden" from "gone"): unverified.
- Godot `WebSocketPeer` Nagle default and send flush timing: unverified (doctool dump has no descriptions).
- Real-world loss, jitter and disconnect rates for Wargrid players: never measured; only one home connection and one friend match exist.
- Gains from adaptive delay, K-tick frames and resume: mechanisms confirmed in references, Wargrid numbers not measured. No numeric improvement is claimed.
- Warzone 2100 drop/rejoin handling and the flood limits of Warzone 2100 and Zero Hour: not studied (marked in the table). Zero Hour's drop handling: see the 2026-11-13 corrections.
- BAR's lobby and autohost (Teiserver, SPADS) are not in the BAR repository and were not reviewed.
- `tc netem` inside Apple `container`: unverified.

## Review 2026-11-13

Reviewed with the user against `main` at `8f6f528` (no relay, protocol or `game/scripts/net/` change since `4b444a2`). Decisions: [design answers](design-answers-2026-11-08.md#netplay-reference-review-user-2026-11-13).

**Where the items went.** Relay guards package (rough rest of [packages](../packages.md)): lead bound, hello deadline, unstarted-lobby expiry, relay hash comparison, `MATCH END` byte fields, per-IP cap and join rate limit, the desync bisect tool (moved the same day to the Sim quick wins package, with the per-tick hash ring of the simulation review), the abusive-client conformance rows; rider: the Nagle and flush check. Adaptive input delay package (rough rest): the agreed in-band delay with its own telemetry and baseline, then pace for slow machines. Rider on Is Wargrid healthy: deploys wait for 0 rooms. [Blueprint M9](../blueprint.md#m9--3v3-online): fault harness first (with §8 as its acceptance list), seat resume, continue after leave, peer connection quality, crash recovery from client-held logs as the first availability option, relay frames per second and machine sizing before the 3v3 gate, the byte budget. Blueprint Later: snapshot rejoin. Fog (M7.9): map hacking accepted for friends' matches. Pause or keep playing for an away seat stays open as [dropped players](../questions/next-m9-drops.md) Q1. §10's rejections and deferrals agreed, except the Prometheus row: relay `/metrics` stays for live health, log fields add per-match detail.

**Claims re-checked in code:** the lead-bound argument at the start (`lockstep.gd` preloads ticks below the delay; `start()` sends tick `delay`) and in steady state; `room.leave` deletes the seat, so a seat gone for good drops out of the bound's minimum; the relay rejects any first message that is not `hello` and WebSocket pings do not extend the read deadline, so a socket without `hello` lives at most the 10 s silence, and `ReadHeaderTimeout` (10 s) bounds the upgrade; gws reads payloads up to 1 MiB, the envelope parser rejects anything above 64 KiB; `WARGRID_BATCH_MS` joins frames with newlines that the game client does not split; the freeze case (buffered frames refresh the client's receive time). Cited numbers in the M5 and relay stack spike notes match. Reference citations spot-checked at the revisions above: Zero Hour run-ahead formula and constants, Warzone 2100 `updateLatency` (it also skips dropped players and spectators when taking the maximum), OpenRA (`Server.cs:929` TODO, `MaxTickScale`, `NetFrameInterval`, `NoDelay`, 128 KiB cap), Recoil (`ReconnectTimeout` 15 s, token bucket defaults), 0 A.D. (`COMMAND_DELAY_MP = 4`, 200 ms turns).

**Corrections** (marked in place): Zero Hour's run-ahead interval is 5 s in retail; the resume ring is a few frames per seat while the match waits (about `2 × delay + 2`); metrics are kept both ways; the §2 and §9 order is superseded; Zero Hour's drop handling is known.

**New findings:** with three or more seats, two leaves close together can hang the remaining clients: `lockstep.gd` keeps one `_left_seat`, so a second `left` that arrives before play passes the first seat's `after_tick`, with a later `after_tick`, overwrites the first and `can_step` waits forever on the first seat's frames (read in code, not reproduced; two-seat rooms cannot reach it; placed in M9). Peer connection quality (OpenRA's ping labels, 0 A.D.'s notice after 2 s) is in §4 but was missing from the roadmap (placed in M9).

**Still unverified:** Godot `WebSocketPeer` Nagle and flush behaviour, hidden-tab behaviour (placed at the next browser playtest), Recoil `GameServer.cpp` line numbers, loss and jitter in real play.
