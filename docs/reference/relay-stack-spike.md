# Relay stack spike — 2026-11-04/05

Status: spike between milestones. **Adopted (user, 2026-11-05):** the go-idiomatic port replaced the Kotlin relay in `relay/` and on fly (`wargrid-relay-jvm`); the conformance suite lives in `protocol/conformance` (`sh tools/run_conformance.sh`, 41 cases since protocol 2 (33 before); the 6-seat profile stayed in the spike). On `main`: race tests, golangci-lint, conformance and all eleven `run_netplay.sh` scenarios pass locally; deployed relay cold start 1.3–1.8 s, resume 0.33–0.51 s, remote match passed ([development notes](../development.md#relay)). Question (user, 2026-11-04): compare relay tech stacks on performance, resource use, fly.io fit, ease of implementation and maintenance, with real benchmark runs, and recommend one with the [M9](../blueprint.md#m9--3v3-online) requirements in mind. Labels: **measured** (command below), **docs** (primary source read), **unverified**.

## What was built

Every port implements the M5 relay wire protocol byte-for-byte (`relay/src/main/kotlin/wargrid/relay/`), plus spike knobs: `WARGRID_SEATS` (6 for 3v3), `WARGRID_SILENCE_MS`, `WARGRID_KEEP_LOG` (keep every forwarded frame, the naive M9 reconnect log). A black-box Go suite (35 cases, 4 server profiles, mutation-checked: wrong server config fails 1/2, 2/2, 24/30) gates every port; **all six builds pass 35/35**.

| Build | Design | Non-test lines | Dependencies |
|---|---|---|---|
| kotlin (current, M5) | Ktor CIO, one global lock, coroutine outbox per socket | 280 | 44 runtime artifacts |
| go (mirror) | net/http + lxzan/gws v1.10.2, Kotlin's structure | 424 | 2 modules |
| go-idiomatic | goroutine per room (actor), gws `WriteAsync`, frames shared | 516 (+45 opt-in batching) | 2 modules |
| rust (mirror) | Axum 0.8.9 / tokio, Kotlin's structure | ~300 | 86 crates |
| rust-idiomatic | task per room (actor), shared `Utf8Bytes`, feed+flush batching | ~330 | 86 crates |
| elixir | Bandit 1.14 + WebSock, GenServer per room, Registry, monitors | 314 | 10 hex packages |

Ports were written by Sonnet subagents from one spec; the conformance suite and harness by Opus. Other ports, the load harness (`drive.py`, `bench/`) and raw JSONL results are kept outside the repository in `~/projects/wargrid-relay-spike` on the user's Mac (not backed up by git).

## Method

- **Local:** each image in an Apple `container` VM, 256 MB, runtime pinned to one scheduler (`GOMAXPROCS=1`, `TOKIO_WORKER_THREADS=1`, `+S 1:1`, `ActiveProcessorCount=1`) to mimic fly `shared-cpu-1x`; load generator in its own 6-vCPU VM (macOS blocks host→VM traffic). CPU two ways: guest cgroup (`container stats`) and hypervisor (CPU time of the VM's `Virtualization.framework` process, includes virtio). Load = R rooms × 6 seats × 30 Hz ticks, each fanned out to 5 peers, 5 s warmup + 20 s window. Apple M6.
- **fly.io:** one temporary app per stack (`wargrid-spike-*`, fra, shared-cpu-1x 256 MB, suspend autostop), load from the user's Mac over TLS, CPU/balance/throttle from fly's Prometheus (`fly_instance_cpu`, `_cpu_balance`, `_cpu_throttle`).
- **Railway:** trial account, one service per stack in `europe-west4` (Amsterdam), CPU/memory from `railway metrics`. Deploy workflow, operations and the fly-vs-Railway verdict: [relay scaling](relay-scaling.md#flyio-vs-railway-measured-2026-11-0405).
- Fly and Railway hosts are shared and runs are single machines; fly CPU readings reproduced within ~1 point across repeats (Go 37.9/39.0 %, Rust 25.5/26.5 % pre-fix), latency through the home link did not (Go window p99 280 ms one run, 17 ms the next). Treat host latency as indicative only.

## Results

### CPU per 3v3 room (measured)

| | kotlin | go-idiomatic | rust-idiomatic | elixir |
|---|---|---|---|---|
| **fly**, 1 room, % of shared vCPU | 23, throttled | 5.2 | 5.6 | ~6 (4–9.5) |
| **fly**, 2 rooms | 47, throttled (p99 1.6 s) | 9.4 | 7.9 | 13.7 |
| **fly**, 10 rooms | 98, throttled after ~100 s (p99 → 30 s) | 38–39 | 29–31 | 64 |
| **Railway**, 10 rooms, vCPU | 2.4–2.6 | 0.20–0.23 | 0.21–0.24 | 0.77 |
| local VM, 10 rooms, guest % | 97.7 | 16.6 | 7.3 | 37.3 |
| native macOS, 10 rooms, % | 201 | 25.3 | 16.8 | — |
| local, rooms at saturation (one core) | < 10 | ~300 | ~600 | OOM at 150 (≤ 100 fine) |

- fly docs (docs.fly.io/machines/cpu-performance): shared vCPU "a quota of 5ms" per 80 ms = **6.25 %** baseline, bursts to 100 % from a balance, then "throttled". **Measured: the balance does not accrue while a machine is suspended or stopped and is not reset by a cold start.** A relay that autosuspends between matches therefore starts matches with little burst and lives on the 6.25 % baseline: one 3v3 room fits for Go/Rust/Elixir, a second room needs burst. Kotlin does not fit one room.
- Per-frame cost is strongly non-linear (Go 93 µs/inbound frame at 10 rooms, 18 µs at 200+): wakeups, syscalls and virtio interrupts amortise under load. A friends relay lives at the expensive end.
- Hypervisor CPU is about 2× guest CPU at low load (virtio); fly's guest metric at 10 rooms is about 2× the local guest figure.

### Kotlin/Ktor CIO anomaly (measured, cause unverified)

The current relay burns CPU with little work: 14.8 % of a core with 1,000 idle lobbies (others 0.6–3 %), 201 % natively with `ActiveProcessorCount=1`, 2.5 vCPU on Railway's 2-vCPU limit. Full JIT plus `MaxRAMPercentage=70` (`kotlin-c2`) changes nothing (95 % at 10 rooms). JFR top frames are kotlinx-coroutines scheduler work-stealing and parking (`WorkQueue.pollBuffer`, `tryStealLastScheduled`, `parkedWorkersStackPop`). **Hypothesis:** scheduler threads spinning before they park under Ktor CIO's IO dispatcher. Not tried: Netty engine, scheduler tuning. Also: JVM default max heap is 25 % of RAM = 64 MB on 256 MB, and the 1-hour log fill died at 2 rooms.

### Memory (measured)

| | kotlin | go-idiomatic | rust-idiomatic | elixir |
|---|---|---|---|---|
| idle, local cgroup | 135 MiB | 7.9 MiB | 4.6 MiB | 156 MiB (92 with `RELEASE_MODE=interactive`) |
| idle, fly VM used of 210 MiB (guest base ~48) | 98 | 53 | 52 | 159 |
| per idle lobby socket | ~60 KiB | 21–27 KiB | 17–20 KiB | 44–51 KiB |
| 5,000 idle lobbies in 256 MB | fails at ~3,000 | ok (135 MiB) | ok (105 MiB) | OOM (default and tuned) |
| 1 h 3v3 room, every frame kept (`KEEP_LOG`) | ~40–60 MiB, died at 2 rooms (64 MB heap) | 113 MiB | 55–65 MiB | OOM at 1 room |

### Latency (measured)

Local relay-added p99 at 10–100 rooms: Go 1.6–8.7 ms, Rust 1.1–2.3 ms, Elixir 3.0–4.8 ms, Kotlin 157 ms at 10 rooms (saturated). From the Mac: fly fra p50 11–12 ms for Go/Rust/Elixir after fixes, Railway Amsterdam p50 39–41 ms, warm welcome 58–64 ms fly vs 150–200 ms Railway. Input delay is 4 ticks (133 ms) and M5 command p95 margin was 45–59 ms ([M5 findings](m5-online.md)), so Railway's extra ~28 ms per round trip is a real cost for players near Bavaria.

### Startup and size (measured)

| | kotlin | go-idiomatic | rust-idiomatic | elixir |
|---|---|---|---|---|
| fly image | 113 MB | 3.6 MB | 8.4 MB | 39 MB |
| fly cold start (stopped → welcome), p50 of 5 | 3,807 ms | 1,664 ms | 1,721 ms | 2,699 ms |
| fly resume (suspended → welcome), p50 of 5 | 723 ms | 592 ms | ~720 ms on a second host | 674 ms |
| native start → `/health`, macOS, 5 runs | 178–189 ms | 7–13 ms | 8–9 ms | 215–264 ms (167–172 tuned) |
| clean image build (`--no-cache`, base images cached, 8 builder CPUs) | 38.7 s | 9.2 s | 13.7 s | 6.0 s |
| rebuild after a one-line change: image / native | 34.8 s / 5.6 s | 7.9 s / 0.5 s | 4.0 s / 3.9 s | 4.2 s / 0.7 s |
| fly remote build + deploy (first deploy, includes builder warm-up) | 84 s | 93 s | 84 s | 47 s |

The first fly Rust machine resumed in 1.6–12 s on its host; a clone on another host resumed in 0.67–0.80 s, so resume latency is host-dependent, not language-dependent. Local `container run` readiness (~5 s) is Apple VM boot plus `exec` overhead, not a stack metric.

### Pitfalls found per stack

- **Rust:** Axum/tokio does not set `TCP_NODELAY`; Nagle + delayed ACK added ~18 ms p50 and 50 ms room setup and *hid* write cost (Railway 0.085 vCPU before, 0.22 after). tungstenite's default 128 KiB read+write buffers cost 145 KiB per idle socket and OOM-killed the container at ~1,800 lobbies. Both fixed with two settings (`tap_io(set_nodelay)`, `read/write_buffer_size(8 KiB)`); defaults are wrong for this workload.
- **Go:** none found with gws defaults. Risk: gws is mainly one maintainer; the relay is small enough to swap to another WebSocket library (the bench uses coder/websocket).
- **Elixir:** release default (embedded mode) idles at 156 MiB on a 256 MB machine; per-frame binaries make a raw command log expensive. Runtime as root in the spike image.
- **Kotlin:** see anomaly above; 64 MB default heap.
- **Railway:** a new service defaults to region `sfo`; `railway service scale eu-west=1` adds a second region and the trial plan refuses multi-region deploys ("Your plan can only deploy to a single region"); `sfo=0` is needed.

### Batching (measured, Go idiomatic, `WARGRID_BATCH_MS=33`)

One message per recipient per 33 ms instead of one per forwarded frame: CPU at 10 rooms 8.8 % vs 16.6 %, saturation ~500 vs ~300 rooms, p50 +18 ms (half the interval). This is the shape of M5's "server-stamped ticks (option B)".

## Assessment against M9 (Claude, not a user decision)

M9 needs ([blueprint](../blueprint.md#m9--3v3-online), [M5 list](m5-online.md#m9-list), [relay scaling](relay-scaling.md)): 6-seat rooms, lobby with slots, drop → pause or bot, reconnect by replaying the room's command log, dynamic input delay, possibly server-stamped ticks, rooms on several machines with owner in the match code, drain before deploy, rate limits, browser clients over the same WebSocket.

1. **Language is not the deciding factor between Go, Rust and Elixir on the real hosts**; host model and relay design are. On fly, the 6.25 % baseline with no accrual while suspended caps a shared-cpu-1x machine at about one 3v3 room for any of them. More rooms per machine come from batching (option B, ~2×), a compact log, a non-shared CPU, or more machines, not from switching Go ↔ Rust.
2. **The current Kotlin/Ktor CIO relay does not fit M9 on shared-cpu-1x as is**: 23 % of a vCPU for one room, throttled on fly. Staying on Kotlin means first finding and fixing the CPU burn (Netty engine or scheduler) and sizing the heap; effort unknown.
3. **Reconnect by replaying a raw frame log is infeasible on 256 MB in every stack** (55–113 MiB per hour-long room, Elixir/Kotlin OOM). M9 should log only ticks with commands (most ticks are empty) or a compact binary form, independent of language.
4. Actor-per-room (goroutine, tokio task, GenServer) maps directly onto M9's per-room timer (server-stamped ticks), lobby state, reconnect grace and drain; the global-lock mirror ports do not and were not faster.

### Recommendation (proposal)

**Go (net/http + gws) with the idiomatic room-goroutine design**, because it ties for best on the hosts (fly 5.2 % per room, Railway 0.22 vCPU per 10 rooms), had no defaults that broke the workload, has the smallest image (3.6 MB), fastest fly cold start (1.7 s), two dependencies, and a concurrency model close to Kotlin coroutines for a Kotlin developer. Runner-up **Rust/Axum**: best local efficiency (2× Go per frame, 600 rooms per core, least memory) but its edge mostly vanishes on fly/Railway, it needed two non-obvious fixes, and async ownership adds friction to M9's stateful room logic. Pick Rust instead if the learning goal favours it; the numbers do not forbid it. **Elixir** has the best design fit and latency but its memory baseline is a poor match for 256 MB machines. **Kotlin**: replace, or fix the CPU burn before M9.

Independent of language, M9 design inputs: batch per tick (option B), compact command log, size per-machine capacity at the fly baseline (~1 room per shared-cpu-1x) or evaluate a non-shared CPU, and keep fly `fra` over Railway Amsterdam for latency unless capacity forces otherwise.

### Patterns from the Elixir port worth carrying into Go for M9 (proposal; two implemented 2026-11-05)

- **Crash isolation per room:** a panic in one room goroutine kills the whole relay; `recover` in `room.run()` should end only that room (notify its seats, log) and gws `Recovery` should guard handlers, like a crashing GenServer taking down only its match. **Implemented 2026-11-05** (`58d13f2`, `relay/room.go` `recoverCrash`).
- **Monitor + timer for reconnect:** on disconnect keep the seat reserved with a grace timer in the room's `select`, replay the command log on rejoin, announce `left` or hand the seat to a bot only when the timer fires.
- **Everything is a message to the room:** the per-room 30 Hz ticker (server-stamped ticks), lobby slot changes, drop timeouts and drain become more `select` cases in the one goroutine that owns the room; no locks.
- **Supervised shutdown as drain:** on SIGTERM refuse new rooms, let live rooms finish (`http.Server.Shutdown` plus a live-room count), then exit. **Implemented 2026-11-05 for one process** (`58d13f2`): drain bounded by `WARGRID_DRAIN_MS` under fly's `kill_timeout`, so hour-long matches still end on deploy; multi-machine drain stays M9.
- **Bounded mailboxes:** cap each connection's outbound queue and drop a peer that cannot keep up, so one slow link cannot exhaust a 256 MB machine (both the BEAM mailbox and today's Go queue are unbounded). Done in the Go relay 2026-11-12: 1 MiB cap per connection, see the [development notes](../development.md#relay).

Not worth copying: distributed Erlang and hot code upgrade (the R2 redirect and drain cover the need), and the Elixir port's synchronous call per tick.

## Unverified

- Kotlin root cause and whether Netty or tuning fixes it.
- fly `performance` CPU machines and their price; fly bill (pricing in [M5 findings](m5-online.md#hosting) is docs only).
- Railway sleep/wake (serverless) path; Railway cold start; Elixir and Kotlin on fly with the tuned settings.
- Browser (WASM) clients; real Godot clients against the new ports (only the bench client and the conformance suite were used).
- Load from players' real locations; only one home connection was used.
