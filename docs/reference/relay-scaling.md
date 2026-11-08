# Relay scaling reference — 2026-11-04

Status: **PROPOSED**. Design input for [M9](../blueprint.md#m9--3v3-online), placed there by the user 2026-11-04. **User decisions 2026-11-04:** fly.io stays the host for now; the design is cloud-agnostic, using no routing, discovery or placement feature that exists on only one provider. Provider features stay in deploy config (e.g. `fly.toml` autostop) and code must work without them. Nothing else here is approved or implemented. Host docs read 2026-11-04; providers say limits change.

## Provenance

User-supplied proposal `game_backend_rendezvous_architecture_v2.md` ("Multiplayer WebSocket Routing — Rendezvous Hashing + Encoded Match Ownership"), kept outside the repository; zip SHA-256 `853adabdfecde446ac9bd84b5c145f319d3854524b717788bed54f653e15df90`, markdown SHA-256 `9fb092eaa134a1c570ef98923be63144b812aafc9210eae81b1d1b5752d8f958`. It targets server-authoritative matches with accounts; Wargrid's relay is a lockstep forwarder for private matches with friends.

## Assessment (Claude, 2026-11-04; not a user decision)

Keep:

- **Owner encoded in the match code, never re-hashed on join.** The proposal calls this "the essential design choice". Adding or removing machines never moves a live room.
- **Owner machine admits atomically** (seats, full, build). Already true: `Rooms.join` is `@Synchronized`.
- **Drain before deploy; a new process never reuses a live owner ID.**
- **Trust boundary:** resolve only known owner IDs, never build an internal URL from client text, rate-limit joins and handshakes.

Change or drop:

- **Rendezvous hashing (HRW): drop.** The proposal concedes least-loaded is simpler with one coordinator. HRW ignores latency; lockstep input delay follows the slowest round trip, so place rooms by region (minimise worst player RTT).
- **Short codes stay.** The first code character names the owner's worker slot (32 slots per character), the rest is random, instead of the proposal's UUID-length ID. A separate `bootId` adds little: after a restart the room is gone and the relay answers `unknown match`.
- **Tickets, idempotent create, coordinator-to-worker API: defer.** No accounts exist; the code is the key for private play. Add a per-IP join rate limit. These return with accounts or public matchmaking.
- **Reconnect is mostly a lockstep problem, not routing:** the relay keeps the room's command log, a returning client replays it fast to catch up. Routing a reconnect is trivial once the owner is in the code.
- **Capacity is unmeasured.** M5: about 100 MiB idle, about 128 MiB peak for one match on 256 MB ([M5 verification](m5-verification.md)). Benchmark rooms per machine before any placement policy; until then more machines buy region latency and fault isolation, not CPU.

Keep from the proposal's test list (§10): join reaches the encoded owner after machines change (4), last-seat race (9), reconnect within grace (10), restart rejects old codes (11), drain keeps live rooms reachable (12), expiry/cleanup (15), forged owner IDs contact no arbitrary host (16).

## Routing options

| Option | How | Hosts | Cost |
|---|---|---|---|
| R1 platform replay | Any machine answers the upgrade request with `fly-replay: instance=<owner>` | fly.io only | **Rejected 2026-11-04 (provider-specific)** |
| R2 app redirect | Every worker has its own public hostname; a non-owner answers `hello` with `redirect {url}`, client reconnects | any, browser too | one extra handshake on a wrong-worker join |
| R3 coordinator | Proposal's HTTP coordinator places rooms and returns the owner URL | any | extra service, single point of failure for create/join |

**Recommended (Claude, not decided): R2** with these agnostic parts:

- **Worker = one deployable with its own public URL:** a fly app per worker, a Railway service per worker, or a DNS name per VM. Never rely on routing between replicas of one deployable.
- **Static worker list** (slot, URL, region) in relay config; every worker serves it at `GET /workers`. Adding a worker is a config change plus a deploy; no provider DNS discovery.
- **Placement by the client:** the creator pings every listed worker and creates the room on the lowest RTT. For 3v3 that favours the creator; minimising the worst player RTT needs a lobby step first, an M9 detail.
- **Drain in the relay, not the platform:** mark a worker `draining` in the list; it refuses new rooms and keeps live ones; remove it once empty. Platform kill timeouts (fly 300 s, Railway undocumented) then never decide whether a match survives.
- **Client tolerates cold start:** retry the handshake on 502 or timeout, so idle sleep on any host is safe.

## fly.io (docs read 2026-11-04)

Replay and `.internal` discovery are recorded as evidence only; the agnostic design does not use them.

- Replay: header field `instance` is "The ID of a specific Machine to route to", e.g. `fly-replay: instance=00bb33ff`; "Requests larger than 1MB cannot be replayed" (docs.fly.io/networking/dynamic-request-routing).
- WebSocket: "an application returning `fly-replay` headers should not negotiate a web socket upgrade itself … the application or instance receiving the requests should handle the upgrade" (same page). Implies replayed upgrades; not stated outright.
- Request headers `fly-prefer-instance-id` / `fly-force-instance-id` route to one Machine (same page); browsers cannot set WebSocket headers.
- Discovery: `all.vms.<appname>.internal` TXT is a "comma-separated list of Machine ID and region name for all deployed app Machines"; `vms.<appname>.internal` lists only started Machines (docs.fly.io/networking/private-networking). Use `all.vms` or a suspended owner disappears.
- Deploy: `kill_timeout` "up to a maximum of 300 seconds (5 minutes)", "best-effort" (docs.fly.io/reference/configuration). Matches last up to an hour, so draining means new machines plus retiring old ones when empty, not `fly deploy` alone.
- Regions: `fra` in use; many others.

## Railway (docs read 2026-11-04)

- WebSocket: "Websocket connections are exempt from these duration and inactivity limits, and can stay open indefinitely, even while idle." Cap "10,000 concurrent connections" per service (docs.railway.com/networking/public-networking/specs-and-limits).
- Replicas: traffic goes to the nearest region and is then distributed randomly; "Railway does not support sticky sessions"; no documented way to address one replica (docs.railway.com/reference/scaling). So R1 is impossible and replicas of one service cannot own rooms; R2 or R3 needs **one service per worker**, each with its own domain.
- Discovery: `<service>.railway.internal` "resolves to the internal IP addresses of the service"; env `RAILWAY_REPLICA_ID`, `RAILWAY_REPLICA_REGION` (docs.railway.com/networking/private-networking/how-it-works, /variables/reference).
- Deploy: old deployment gets SIGTERM, "By default, it is given 0 seconds"; `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` sets the SIGTERM-to-SIGKILL buffer, `RAILWAY_DEPLOYMENT_OVERLAP_SECONDS` the overlap (docs.railway.com/reference/deployments). **No maximum documented**; whether an hour-long drain is honoured is unverified.
- Sleep: a service is inactive 5 minutes after it stops sending packets, sleeps within 5–10 minutes; "The first request sent to a slept service may return a 502 Bad Gateway response" (docs.railway.com/reference/app-sleeping). The client would need a retry on wake. An open but silent WebSocket does not keep it awake.
- Regions: one in Europe, Amsterdam (`europe-west4-drams3a`) (docs.railway.com/reference/deployment-regions). fly `fra` is closer to Bavaria.
- Price: Hobby $5/month, includes $5 usage; RAM $10/GB/month, CPU $20/vCPU/month, egress $0.05/GB; Hobby up to 6 replicas per service (docs.railway.com/reference/pricing/plans). fly has no monthly minimum.

## fly.io vs Railway, measured (2026-11-04/05)

Source: [relay stack spike](relay-stack-spike.md), which deployed the same four relay images (Kotlin, Go, Rust, Elixir; 3v3 rooms) on both hosts and ran the same probes and a 180 s, 10-room load from the user's Mac (near Bavaria) through each host's TLS edge. fly: four temporary apps in `fra`, shared-cpu-1x 256 MB, suspend autostop. Railway: user's **trial** account, one project, one service per stack in `europe-west4` (Amsterdam). Everything was deleted afterwards; Railway usage for about 3.5 h of four services plus load was **$0.08** (`railway usage`). One machine per stack and one client location, so treat latency as indicative.

### Deploying

| | fly.io | Railway |
|---|---|---|
| Steps per service | `fly apps create`, then `fly deploy <dir> -c <abs>/fly.toml --dockerfile … --ha=false --remote-only` | `railway add --service s --variables …`, `railway service scale --service s eu-west=1 sfo=0`, `railway up <dir> --path-as-root --service s --ci`, `railway domain --service s --port 8080` |
| Config | `fly.toml` in the repository: VM size, `[http_service]`, autostop, health checks, env | Lives in Railway's project state, set through CLI or dashboard; config-as-code files not tried |
| First deploy (remote build + start) | 47–93 s, includes builder warm-up | Go 64 s, Elixir 97 s, Rust 152 s, Kotlin 183 s |
| Redeploy of an existing image | `fly deploy` again (rebuild) | `railway service redeploy --service s --yes` (no rebuild) |
| Public URL | `<app>.fly.dev`, automatic | `railway domain` generates `<service>-production-xxxx.up.railway.app`; one extra step |
| Upload | Build context = positional dir, `.dockerignore` honoured | Respects `.gitignore`; dirs without one needed a `.railwayignore`, or local `target/`, `_build/` and `build/` would upload |
| Removal | `fly apps destroy <app> --yes`, gone at once | `railway delete --project <id> --yes`: endpoints 404 at once, project soft-deleted with `deletedAt` 48 h later |

Gotchas hit (measured):

- **fly:** relative `-c` fails once a positional dir is given (absolute path needed); without `--ha=false` fly creates two machines and rooms split ([M5 verification](m5-verification.md)); app names cannot be renamed; Prometheus API needs `Authorization: FlyV1 <token>` (Bearer gives 401).
- **Railway:** a new service defaults to region `sfo` (California). `scale eu-west=1` *adds* Amsterdam next to it, and the trial refuses the deploy with "Your plan can only deploy to a single region. Please upgrade to Pro to deploy to multiple regions." Right after `railway add` the region map was not populated yet (`Unknown region sfo`), so three services silently deployed to California until `sfo=0` and a redeploy. Project creation is rate-limited ("1 project per 30 seconds"). `railway init` prints prompt text before its `--json` output, so scripts must not parse it blindly. Whether Hobby (not trial) allows multi-region is unverified.

### Operating

- **Metrics:** fly exposes Prometheus per machine (CPU by mode, `fly_instance_cpu_balance`, `_cpu_baseline`, `_cpu_throttle`, memory), 15 s steps. Railway: `railway metrics --cpu --memory --raw --json`, 30 s points, CPU in vCPU against a `CPU_LIMIT` of **2.0** on the trial; no balance or throttle concept.
- **Logs:** both stream app logs from the CLI (`fly logs`, `railway logs`). fly also logs machine lifecycle (suspend, resume, "Machine started in …"), which is what exposed a slow host.
- **Placement control:** fly `machine clone` moved a slow-resuming Rust machine to another host (resume 1.6–12 s became 0.67–0.80 s). Railway gives no host-level control in the CLI used.
- **Idle cost model:** fly suspends idle machines (resume 0.6–0.7 s, cold start 1.6–3.8 s depending on stack) and bills rootfs only while suspended (docs, [M5 findings](m5-online.md#hosting)). Railway sleep ("serverless") was **not tested**; services stayed up for the whole run. Docs: first request after sleep "may return a 502" (see Railway section above).

### Performance (measured, 10 rooms 3v3 unless stated)

| | fly `fra` shared-cpu-1x | Railway Amsterdam (trial) |
|---|---|---|
| CPU, Go / Rust / Elixir / Kotlin | 38–39 % / 29–31 % / 64 % / 98 % of one shared vCPU | 0.20–0.23 / 0.21–0.24 / 0.77 / 2.4–2.6 vCPU |
| Sustained load | Burst balance drains, then **throttled to the 6.25 % baseline** (Kotlin p99 → 30 s); balance does not accrue while suspended, so about one 3v3 room per machine is sustainable | No throttling seen in 3 min at up to 2.6 vCPU |
| Memory used, Go / Rust / Elixir / Kotlin | VM 53 / 52 / 159 / 98 MiB of 210 usable (guest base ~48) | 15 / 2–9 / 171 / 122–130 MB (service only) |
| Latency from the Mac, p50 / p99 (Go, Rust, Elixir) | 11–12 / 12–18 ms | 39–41 / 44–45 ms |
| Warm connect → welcome | 58–64 ms | 147–201 ms |

Railway's per-vCPU figures look lower than fly's percentages partly because the units differ (vCPU-seconds on an unthrottled, probably faster host vs share of a quota-limited shared vCPU); the CPU ratio between stacks is similar on both hosts except Kotlin.

### Assessment (Claude, not a user decision)

**Railway is a real alternative technically, but not a better default for Wargrid now.**

For Railway:
- WebSockets ran through its TLS edge for every stack without changes.
- Dockerfile deploys from the CLI were straightforward once the region trap was known.
- Metrics are easy to script.
- Capacity per service is much higher: no burst quota, so ten 3v3 rooms cost about 0.22 vCPU in Go or Rust instead of throttling.

Against Railway:
- **Latency:** the only EU region is Amsterdam, and players near Bavaria saw about +28 ms p50 per round trip. That eats into M5's 45–59 ms headroom under the 250 ms command budget, which the 4-tick input delay already leaves ([M5 findings](m5-online.md#latency-budget-command-p95--250-ms)). For lockstep this matters more than CPU.
- **Cost floor:** Railway Hobby is $5/month (docs). The user's fly org is on the legacy (free) Hobby plan (user, 2026-11-05), whose allowances are honoured for pre-October-2024 orgs: "Up to 3 shared-cpu-1x 256mb VMs" and "100 GB North America & Europe" outbound, with "no monthly subscription fee" (docs.fly.io/about/discontinued-plans, read 2026-11-05). So up to three relay machines cost nothing on fly. For new fly orgs the list price is $2.53/month per started shared-cpu-1x 256 MB in `fra`; fly.io/pricing.md says "invoices under $5 are waived" for new users.
- **Infra as code:** config sits in Railway's state, not in a reviewed file like `fly.toml`.
- **Multi-region:** the plan's single-region limit conflicts with M9's region-aware placement unless Pro.
- **Sleep:** the sleep/502 path is untested with the Godot client.

Recommendation (proposal):
- Stay on fly `fra` for the friends relay.
- Treat fly's 6.25 % baseline as the capacity limit to design around in M9: batching, a compact log, one room per shared machine, or a non-shared CPU size.
- Keep Railway as the cloud-agnostic fallback the R2 design already allows (one service per worker, own domain).
- Re-evaluate Railway only if fly's per-machine capacity or pricing becomes the binding constraint.

## High availability options (proposed 2026-11-05)

User, 2026-11-05: one machine is acceptable for now; it is not highly available, so what could be done there is worth exploring. Here "available" means a crash or host loss does not end live matches; deploys are already covered by draining. Nothing below is decided or measured; the options are for M9 planning.

Fly's managed Redis (docs read 2026-11-05, fly.io/docs/about/pricing and /docs/upstash/redis): it is **Upstash Redis**, a third-party extension billed through the Fly invoice. Databases run "within Fly.io infrastructure, but not inside your organization's network" and are "replicated within the same region in a highly-available configuration"; the primary region is chosen at creation and cannot change; read replicas in other regions are optional; data transfer to it is billed like other cross-boundary traffic. Standard Redis protocol, so code that uses only that protocol stays cloud-agnostic; only provisioning (`flyctl redis create`) is fly-specific.

| Option | How | What it survives | Cost / risk |
|---|---|---|---|
| A. One machine (today) | Drain before deploy; fly restarts a crashed machine | Deploys | A crash or host loss ends live rooms; players rematch |
| B. Rebuild rooms from the clients | Relay keeps no durable room state. Every client already holds the full command history in its simulation; after a restart, reconnecting clients re-send it and the relay restores the room from the longest log | Crash, host loss, deploy, with no extra service | Idea, not checked against the fixed wire protocol (`protocol/vectors`, conformance suite); likely a protocol addition, so a conformance change; clients may sit at different ticks, so the relay needs a rule for which log wins |
| C. Mirror room state to Redis | Seats and the command log appended to Redis off the hot path; a replacement machine adopts the room, clients reconnect and replay | Same as B, plus the relay can restart without any client having every command | Extra dependency, a fixed primary region, transfer cost; never put Redis on the per-tick path (the command budget has little headroom, see the latency numbers above) |
| D. Several machines, owner in the match code (existing design) | See Routing options | Fault isolation, region latency; a live room still lives on one machine | Most machinery; adds availability only when combined with B or C |

Assessment (Claude, not a user decision):

- Every option beyond A depends on **client reconnect with command-log replay**, which M9 already plans. Build and test that first; it is useful on its own for dropped players.
- B should be tried before C: it needs no new service, and the clients already hold exactly the data Redis would store. If the protocol can carry it, Redis adds little for room state.
- Redis earns its place for **shared directory state** (match code to owner machine, seat claims, public matchmaking) once there is more than one machine, which is option D, not for the live room.
- For a friends-scale game, A plus fast reconnect is probably enough; B or C is for learning and robustness. Choose at M9 planning.

## Unverified

- fly: public hostname per worker as one app per worker (cost, deploy commands); the actual bill; `performance-1x` under our relay load (planned for M9, user 2026-11-05). Docs, fetched 2026-11-05 (fly.io/docs/about/pricing, /machines/cpu-performance): `shared` baseline 5 ms per 80 ms (6.25 %), `performance` 100 %; `performance-1x` 2 GB $33/month and `performance-2x` 4 GB $66/month at the lowest-priced regions, `fra` costs more (its 1 GB shared example is $7.73 against $6.70 in `iad`); stopped or suspended machines pay only $0.15 per GB of rootfs per month. Unknown: `performance` price in `fra`, whether `shared-cpu-2x` doubles the baseline.
- Railway: Hobby vs trial limits (regions, CPU limit), maximum honoured draining time, sleep/wake time and the 502 path with the Godot client, cold start, config-as-code files, behaviour under sustained load beyond 3 minutes.
- Both: RTT from players' locations other than the user's Mac; more than one machine per stack.
