# Relay scaling reference — 2026-11-04

Status: **PROPOSED**. Design input for [M9](../../Wargrid_Kickoff_Blueprint.md#m9--3v3-online), placed there by the user 2026-11-04. **User decisions 2026-11-04:** fly.io stays the host for now; the design is cloud-agnostic, using no routing, discovery or placement feature that exists on only one provider. Provider features stay in deploy config (e.g. `fly.toml` autostop) and code must work without them. Nothing else here is approved or implemented. Host docs read 2026-11-04; providers say limits change.

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

## Unverified

- fly: public hostname per worker as one app per worker (cost, deploy commands).
- Railway (evaluation in M5 Task 11): Kotlin relay deploy and cold/warm `--probe-relay`; maximum honoured draining time; wake time and the 502 path with the Godot client; memory and idle cost of the relay.
- Both: rooms per machine; RTT from players' locations.
