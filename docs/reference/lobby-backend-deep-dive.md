# M9 lobby backend deep dive — 2026-11-09

Status: **PROPOSED**, research only; nothing decided, planned or built. Follows [lobby backend brainstorm](lobby-backend-brainstorm.md) option B (user's chosen direction: Go lobby with `chi/v5`, existing Go relay, HMAC ticket handoff, SQLite on a fly volume with Litestream to Tigris). Labels: **source** (repo path:line), **docs** (primary page fetched 2026-11-09, quoted), **inferred**. Nothing was deployed or run; `fly status -a wargrid-relay` (read-only) shows one suspended `fra` machine.

## Q1. Why WebSocket, not REST or GraphQL?

Short answer: the lobby's core job is **pushing** room state (seats, ready, countdown, chat) to up to 6 clients within a second; only a server push channel does that without polling. WebSocket is already the project's one transport, works in the browser build, and fits the existing vectors discipline unchanged. REST is fine *beside* it for stateless calls; GraphQL adds a schema layer and still needs a WebSocket for subscriptions.

What exists today (**source**): the client speaks text JSON over `WebSocketPeer` (game/scripts/net/relay_transport.gd:8, 23, 37); no `HTTPRequest`/`HTTPClient` anywhere in `game/scripts`. The relay uses `net/http` + `gws` (relay/go.mod:5, relay/main.go:168). Vectors are `{text, message}` JSON pairs (protocol/vectors/hello.json), read by the Godot tests (game/tests/test_wire.gd) and driven against a live binary by `protocol/conformance` (tools/run_conformance.sh). Blueprint §11 chose WebSocket because "ENet is not available in browsers, so one transport keeps the later browser build open" (docs/blueprint.md, §11 Multiplayer).

| | WebSocket only | REST + polling | REST + WebSocket | REST + SSE | GraphQL (+ subscriptions) |
|---|---|---|---|---|---|
| Live push to 6 clients | yes | no: 6 clients × 1-2 polls/s, laggy countdown | yes | yes, server to client only | only via subscriptions, which ride WebSocket |
| Godot 4 client | `WebSocketPeer`, already in use | `HTTPRequest` built in | both built in | no built-in SSE; hand-parse on `HTTPClient`; addons tiny (lazy-top/godot-sse, 2 stars) | Dracks/GodotGraphQL (27 stars, last push 2025-04-02); its README mentions no subscriptions (not found) |
| Browser (WASM) | `wss://`; handshake headers "Not supported in Web exports due to browsers' restrictions" (docs, Godot WebSocketPeer) | CORS preflight; "the remote server may not allow requests from foreign origins due to CORS" (docs, Godot HTTPClient) | CORS on REST part | CORS; over HTTP/1.1 "the limit is *per browser* and set to a very low number (6)" (docs, MDN EventSource); fly serves HTTP/2 to browsers (inferred, not checked) | CORS plus WebSocket |
| Fits vectors + black-box suite | as-is: one more message family | needs an HTTP request/response vector format | two formats | two formats, SSE framing on top | GraphQL documents, a schema, and graphql-ws framing |
| Go side | `gws` (already used) or coder/websocket | chi | chi + WS | chi, plain `http.Flusher` | gqlgen: subscriptions via `srv.AddTransport(transport.Websocket{})`, protocols "`graphql-ws` or `graphql-transport-ws`" (docs, gqlgen.com/recipes/subscriptions) |

Notes:

- **Browser specifics.** WebSocket is not governed by CORS; it uses "the origin model used by web browsers" and servers "SHOULD verify the |Origin| field" and answer "HTTP 403 Forbidden" if unacceptable (docs, RFC 6455 §1.6, §10.2). The relay sets no origin check (relay/main.go:168, only payload size, UTF-8, recovery; **inferred** that gws accepts any origin by default, unverified). The lobby should check Origin against `wargrid.pdstuber.dev` and the test app. Cookies: not needed; identity is a client id from `user://` (brainstorm option B), sent in the first message, so no `SameSite`/third-party cookie issues.
- **SSE in Godot (surprise).** The web `HTTPClient` is fetch-based and reads the body as a stream (`response.body?.getReader()`, `obj.reader.read()`: godotengine/godot master `platform/web/js/libs/library_godot_fetch.js:67, 128`, read 2026-11-09). So SSE is possible in the browser build with a hand-written parser, but every client action (ready, slot, chat) would then be a separate POST: two channels to order and test instead of one.
- **Library maturity (GitHub API, 2026-11-09).** chi v5.5.0 (2026-10-14); gqlgen v0.17.98 (2026-10-22, still 0.x); coder/websocket v1.8.15 (2026-06-15; "First class context.Context support", "Compile to Wasm"; maintainer since 2024: "grateful to nhooyr for authoring and maintaining this project from 2019 to 2024"); gorilla/websocket v1.5.3 (2024-06-14, last commit 2025-03-19). `gws` is already vetted in this repo.

**Recommendation:** one WebSocket per client to the lobby for everything inside a room (`gws`, same as the relay: one library, one set of failure modes, same `Recovery` and payload limits), mounted under a chi router that also serves plain REST for stateless calls: `GET /health`, `GET /maps` or `GET /version` if needed, and later `GET /matches` (history). Join/create go over the socket (create returns the code in the first reply), so one vectors format covers the lobby. Skip GraphQL: it is a client-shaped query language for many-entity reads, the lobby has one entity (a room) and no Godot client with subscriptions. Skip SSE: it buys nothing over the socket the client already has.

## Q2. Does SQLite on a fly volume limit the lobby to one instance?

For **the database, yes**; for **the lobby, not necessarily**.

- Volumes (docs, docs.fly.io/volumes/overview): "A volume can attach to one Machine"; "A Machine can only mount one volume at a time and a volume can be attached to only one Machine"; "Volumes don't have built-in replication between them"; "Daily automatic snapshots may not have your latest data"; "the snapshots shouldn't be your primary backup method."
- Litestream is backup, not a second writer: it "continuously copies write-ahead log pages from disk to a replica"; "Each database replicates to a single replica destination" (docs, litestream.io/how-it-works); default `sync-interval` "Defaults to `1s`" (docs, litestream.io/reference/config), so a host loss can lose about the last second of writes (**inferred** from asynchronous replication). Read-only queries can be served from the replica via `litestream-vfs` (same page). Latest release v0.5.18, 2026-11-03 (GitHub API): active.
- LiteFS (docs, docs.fly.io/litefs): "LiteFS is outside our scope of support. We are not able to provide support or guidance for it. Use with caution."; "The project is still pre-1.0 so APIs may change and features could be removed."; and **"Don't use LiteFS with autostop/autostart on Fly Machines"**, because it "can be a database rollback and permanent data loss". README: "actively maintained but is currently in a beta state" (github.com/superfly/litefs). GitHub API: last release v0.5.14 on 2025-04-22; the only commit since is a 2026-10-30 reviewer-routing change. **Assessment (inferred):** effectively parked; and it conflicts with the suspend-to-zero setup every Wargrid app uses (relay/fly.toml `auto_stop_machines = "suspend"`). Do not use.

What one lobby instance means in practice (**inferred**):

- **Deploy:** a rolling deploy with one machine replaces it; open (unstarted) lobbies drop, players reconnect and recreate. Started matches are unaffected: they live on the relay after the ticket handoff (brainstorm B: "Lobby deploys no longer end live matches"). The relay already closes unstarted lobbies on SIGTERM (development.md Relay "Shutdown"); the lobby should do the same with a "server restarting" message.
- **Crash or host loss:** fly restarts the machine; the volume is tied to that host ("tied to that hardware", brainstorm Persistence table), so on host loss restore from Litestream into a new volume. Loss: open lobbies plus about 1 s of history.
- **Does live state need sharing?** No. A room lives minutes, all its members talk to one process, and the start hands everything to the relay in the ticket. Live rooms stay in memory, one goroutine per room, like the relay.

Staying ready for a second instance without provider routing: the user rejected `fly-replay` ("Rejected 2026-11-04 (provider-specific)", docs/reference/relay-scaling.md:32; "no provider-only routing, so no `fly-replay`", docs/session-notes.md:55). Apply the relay's own R2 design (relay-scaling.md:36-44) to the lobby: the first character of the room code names the owning lobby instance; each instance has its own public URL; a non-owner answers `join` with `redirect {url}`. No shared store is needed for rooms. Only **history** must be shared, and that is solved by making history writes go to one place: the relay's `match_ended` POST (brainstorm B) targets one history endpoint, so a second lobby instance never writes SQLite. Until then: one machine.

## Q3. Upstash Redis on fly

Docs (docs.fly.io/upstash/redis unless noted): "$0.20 per 100k requests"; fixed plans from "250 MB" at "$10/mo plus $5 per read region"; primary region "can't be changed later"; reached over a private IPv6 address "restricted to your Fly organization", running "on Fly.io infrastructure but not inside your organization's network"; data "replicated within the same region in a highly-available configuration" with backups "outside Fly.io"; writes go to the primary and are synchronous. Pay-as-you-go limits: 10,000 commands/s, 10 GB storage. Pub/Sub: SUBSCRIBE "is available over native Redis TCP, not the stateless REST endpoint"; "Messages published while the connection is not subscribed are not delivered later, since pub/sub keeps no history" (docs, upstash.com/docs/redis/commands/pub-sub/subscribe). Streams with `XREADGROUP`/`XACK` exist (Upstash command reference, found via search, not quoted). Fly pricing: extensions billed at "Provider's list price"; data transfer to Upstash is billed but the rate is not stated (docs, docs.fly.io/about/pricing). Upstash's own pricing page lists the free tier (500K commands/month) for AWS/GCP/Vercel, **not Fly.io** (docs, upstash.com/pricing/redis).

What it would hold, and whether it fits (**inferred**):

- **Live rooms for several lobby instances:** not needed (Q2: owner-in-code routing). Putting rooms in Redis turns a goroutine's local state into a remote store with its own consistency rules: overblown.
- **Sessions:** there are no accounts; the HMAC ticket is stateless. Only a "seen ticket ids" set for replay protection would fit (TTL keys), and only with several relays.
- **Match history:** a key-value store with eviction and TTLs is the wrong shape for queryable rows. No.
- **Directory for several relays or lobbies** (code to owner, draining flags): the one place it fits (relay-scaling.md:145 says the same), but the code already encodes the owner.
- **Latency:** same region, private network: low single-digit ms (inferred, not measured). Never on the relay's per-tick path (relay-scaling.md, option C).
- **Failure modes:** an outage of a third-party service outside the org network; primary region fixed forever; pub/sub drops messages while disconnected.
- **Cost at this scale:** pay-as-you-go, likely cents per month at a few thousand commands per match (inferred); no free tier on Fly.

Verdict: skip for M9; revisit only with public matchmaking or several relays needing shared directory state.

## Q4. bbolt instead of SQLite

Docs (github.com/etcd-io/bbolt): "Bolt is stable, the API is fixed, and the file format is fixed"; "Bolt allows only one read-write transaction at a time"; "Bolt obtains a file lock on the data file so multiple processes cannot open the same database at the same time"; hot backup via `Tx.WriteTo()` from a read-only transaction; "provides no built-in support for joining values together"; used by etcd, Consul, containerd. Latest v1.5.0 (2026-06-21). Pure Go, no cgo (inferred from the repo; SQLite has a pure-Go driver too, `modernc.org/sqlite`, not checked).

Fit (**inferred**): single process like SQLite, so no multi-instance gain. No Litestream equivalent: backup means a periodic `WriteTo` to Tigris (a goroutine and an S3 client you write and test yourself), with a loss window of the backup interval instead of about 1 s. Queries such as "matches on Ashfall with a desync last week" become hand-written cursor scans and secondary-index buckets. It teaches B+tree/MVCC internals, not SQL or replication. Worse than SQLite on every axis that matters here.

## Q5. Other fly-friendly options, briefly

- **Tigris for match logs and desync replays:** fits (already in brainstorm B as Litestream target). Pricing page could not be fetched (tigrisdata.com/pricing errored, docs pricing 404): unverified.
- **Turso / libSQL:** free plan "100" databases, "5GB", "10 Million" rows written per month; Developer "$4.99/month" (docs, turso.tech/pricing). Turso now offers "Turso Database (Embedded)" and "Turso Cloud", "Fully managed platform for Turso and libSQL databases" (docs, docs.turso.tech/introduction). A managed SQLite-dialect store reachable from several lobby instances: the natural **second step** if history ever needs a second writer, since the SQL stays SQLite. Third-party outside fly; region list not found on the pricing page.
- **NATS JetStream on a fly machine:** only for option C's event bus. Overblown for M9; skip.
- **Fly Managed Postgres:** "$38/month (Basic)" (docs, docs.fly.io/about/pricing): correct but ten times everything else.

## Persistence comparison

| Store | Multi-instance | Durability | Backup | Query | Cost at this scale | Ops burden | Teaches |
|---|---|---|---|---|---|---|---|
| SQLite + Litestream → Tigris | one writer (one volume, one machine) | volume + async copy, ~1 s window | continuous, point-in-time restore | full SQL | volume $0.15/GB-month + Tigris cents | low: one sidecar process, one restore drill | WAL, streaming backup, restore |
| LiteFS | yes (one primary, replicas) | replication, but rollback risk with autostop | needs extra off-site backup | full SQL | volumes per machine | high, unsupported, pre-1.0 | distributed FS leases; not recommended |
| bbolt | one process | volume only | hand-written `WriteTo` loop | key scans, no joins | volume only | medium (own backup code) | B+tree KV |
| Upstash Redis | yes | in-region HA, backups outside fly | provider | key/value, streams | $0.20/100k requests, no free tier on fly | low, third-party outage risk | Redis data structures, pub/sub |
| Fly Managed Postgres | yes | HA + backups included | included | full SQL | from $38/month | lowest, but costly | managed Postgres |
| Turso (libSQL) | yes, remote | managed | managed | SQLite SQL | free plan likely enough | low, third-party | edge/remote SQLite |

## Refined recommendation for option B (proposal; user decides)

- **Transport:** lobby speaks JSON text over one WebSocket per client (`gws`, as the relay), behind a chi router that also serves `/health` and later read-only REST (`GET /matches`). Origin check for the two web apps. Lobby vectors in the existing `{text, message}` shape and a lobby profile in the conformance runner. No GraphQL, no SSE.
- **Persistence:** SQLite (pure-Go driver, to be chosen) on one fly volume, Litestream to Tigris, one restore drill in the plan. Standard SQL only, so moving to Turso or Postgres later is a driver and DSN swap. Rooms stay in memory.
- **Single instance now:** not a real problem. A lobby restart loses only unstarted rooms; started matches live on the relay. Note the lobby needs `min_machines_running = 0` with suspend like the other apps; suspend keeps the volume.
- **Ready for a second instance:** room code carries the lobby owner slot (R2, no `fly-replay`); history writes come from the relay's `match_ended` to one history endpoint, so only one process ever writes SQLite; HMAC tickets need no shared state. When a second writer is truly needed, move history to Turso or a separate history service; do not reach for LiteFS or Redis.

## Questions

Q1. How should the game talk to the lobby?
   a) One live connection for everything in a room, like the relay   b) Web requests for create/join plus a live connection for updates   c) GraphQL
   Recommendation: a, because it is one channel and one test format, already working in the browser. Why it matters: decides the lobby protocol shape.

Q2. Should the lobby reuse the relay's WebSocket library?
   a) Yes, the same library (gws)   b) A different one (coder/websocket) to compare
   Recommendation: a, because one library means one set of known limits. Why it matters: b is only worth it as a deliberate learning exercise.

Q3. Should the lobby refuse connections from websites other than Wargrid's own?
   a) Yes, check the page origin   b) No, accept any origin like the relay today
   Recommendation: a, because it is a few lines and the RFC recommends it. Why it matters: stops other sites from opening lobbies in a visitor's browser.

Q4. Where should match history live?
   a) SQLite on the lobby machine, backed up continuously to Tigris   b) Turso (hosted SQLite)   c) bbolt   d) Upstash Redis
   Recommendation: a, because it costs cents and keeps plain SQL. Why it matters: picks the M9 database.

Q5. How many lobby machines in M9?
   a) One; a restart loses only unstarted lobbies   b) Two from the start, codes name the owner
   Recommendation: a, because started matches live on the relay. Why it matters: b adds routing work with no player-visible gain yet.

Q6. Who writes a finished match into history?
   a) The relay reports the end to the lobby   b) Each player's game reports it   c) The lobby records only the start
   Recommendation: a, because the relay sees the true end once. Why it matters: one writer keeps a later second lobby simple.

Q7. Should Redis be part of M9?
   a) No, only when several relays need a shared directory   b) Yes, to learn it now
   Recommendation: a, because nothing in M9 needs shared live state. Why it matters: a third-party service with no free tier on fly.

Q8. Should the plan include restoring the database from backup once?
   a) Yes, one restore drill   b) No
   Recommendation: a, because an untested backup is not a backup. Why it matters: about an hour of work.

## Unverified

- Tigris prices (pricing pages failed); Upstash TCP stream support quoted from search only; Turso regions.
- gws default origin behaviour; fly deploy downtime with one volume machine (deploy docs do not describe it); HTTP/2 to browsers on fly.
- Whether the legacy free machine allowance covers a lobby machine (brainstorm Unverified).
