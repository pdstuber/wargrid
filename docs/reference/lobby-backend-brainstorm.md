# M9 lobby backend brainstorm — 2026-11-09

Status: **PROPOSED**, research only; nothing here is decided, planned or built. Input for M9 planning ([blueprint §7 M9](../blueprint.md#m9--3v3-online)). User brief (2026-11-09): "I do love microservices, Go etc, so if it's slightly overengineered, cool. Not totally overblown of course. We also might need persistence etc. I'd want to stay at fly.io." Fixed inputs: relay stays `net/http` + `gws`, new services in Go with `chi/v5` (blueprint §7 M9 "Backend stack"); cloud-agnostic routing (relay-scaling.md:3); one relay machine is fine, availability is the open question (relay-scaling.md:128-146). Labels: **source** (repo path:line or ZH src), **docs** (fetched 2026-11-09, quoted), **inferred**.

## What the lobby must do

| Need | Where it comes from |
|---|---|
| Create match, get a code; join by code | mockup [lobby-mockup.jpg](../images/lobby-mockup.jpg); blueprint §7 M9 "Lobby look" |
| Map choice with start positions; maps with too few starts filtered | mockup; [next-m9-lobby](../questions/next-m9-lobby.md) Q2, Q12 |
| Seats: you + two friend slots, bot team; faction per seat; colour, team, random faction | mockup; next-m9-lobby Q3-Q7 |
| Bots in seats: one difficulty 1-5 and one play style for all bots | mockup; blueprint §7 M9 |
| Ready / Accept, cleared on any change, 5 s countdown | next-m9-lobby Q9 (ZH: GameInfo.h:66-68, multiplayer.ini:36) |
| Version / simulation fingerprint matching | relay `build` string (room.go:141-142); R1.1 wants a simulation hash instead of the version |
| Start handoff to the relay with seats, seed, settings | protocol `start` vector (protocol/vectors/start.json) |
| Drops, reconnect, bot takeover | [next-m9-drops](../questions/next-m9-drops.md); relay-stack-spike.md:107 (grace timer, log replay) |
| Rooms list / match browser, chat | not in the mockup; M5 M9 list says "Lobby and match browser" (m5-online.md:61); ZH had both (questions below) |

What the relay does today (**source**): seat count is one process-wide env var, `WARGRID_SEATS` default 2 (relay/main.go:129); the room starts by itself the moment the last seat joins, numbering seats 1..n (relay/room.go:159-166); `settings` are opaque bytes from the creator's `hello` (envelope.go:60, room.go:166); codes are 6 characters from a 32-letter alphabet (room.go:18, 318). **Consequence (inferred):** a 3v3 with one to three humans plus bots needs a per-room seat count and an explicit start. "Relay unchanged" therefore cannot hold literally for any option; every option below adds at least a protocol 3 `hello`/`start` change and new vectors.

## Options

### A. Relay-only lobby (small)

- **Services:** the relay. The lobby is a pre-start phase inside the room goroutine: new messages `slot`, `ready`, `start_request`, `lobby_state`; host is seat 1. This is the spike's own idea: "lobby slot changes, drop timeouts and drain become more `select` cases in the one goroutine that owns the room" (relay-stack-spike.md:108).
- **Persistence:** none. Match end already logs `MATCH END` (development.md Relay section); history = `fly logs`.
- **Protocol:** one WebSocket from lobby to end of match; no handoff at all.
- **Identity:** a typed name sent in `hello`, kept on the device.
- **Conformance:** new vectors in `protocol/vectors`, new cases in `protocol/conformance`; same suite, same runner (`tools/run_conformance.sh`).
- **Test env:** R1.3 test relay = a second app `wargrid-relay-test`; `wargrid-web-test` points at it.
- **Cost:** unchanged (one shared-cpu-1x).
- **Ops:** lowest. A relay deploy also kills open lobbies (it already closes unstarted lobbies on SIGTERM, development.md Relay "Shutdown").
- **Teaches:** actor-per-room state machines. Little new architecture; does not use chi/v5 or persistence.

### B. Go lobby service + relay, signed ticket handoff (recommended, "slightly over-engineered but sane")

- **Services:** `wargrid-lobby` (Go, chi/v5, WebSocket per client; one goroutine per lobby room, same pattern as the relay) owns codes, seats, teams, factions, colours, bots, ready, countdown, optional room list and chat. `wargrid-relay` stays a forwarder.
- **Handoff (how the relay learns about a match):** on start the lobby signs one ticket per human, HMAC-SHA256 with a secret shared by both apps (fly secret): `{match, seat, seats:[...], build, settings, seed, exp}`. The client opens the relay with `hello{protocol:3, ticket}`. The relay creates the room on the first valid ticket and starts once every human seat in the ticket has arrived. No lobby-to-relay call, no private network, no shared store: cloud-agnostic and testable with a golden vector (inferred design). Optional reverse path: the relay POSTs `match_ended {match, ticks, desync, left}` to the lobby with the same secret, for history.
- **Multi-relay later:** the ticket carries the relay URL; the lobby picks the worker, which is option R3 "coordinator" in relay-scaling.md:34, without the client choosing it (R2). The relay's code-encodes-owner design stays valid.
- **Persistence:** SQLite file on a Fly Volume in the lobby machine, streamed by Litestream to Tigris (see Persistence). Live lobbies stay in memory.
- **Identity:** typed name + random client id stored in `user://` (no accounts); the lobby stores the id-name pair only if history is kept.
- **Conformance:** two black-box suites: existing relay suite gains ticket vectors (valid, expired, wrong secret, wrong seat, replayed); a new `protocol/lobby/vectors` + `protocol/lobby/conformance` against the lobby binary; one end-to-end vector where a lobby-issued ticket opens a relay room. `tools/run_netplay.sh` starts both binaries locally.
- **Test env:** `wargrid-lobby-test` + `wargrid-relay-test` with a *different* ticket secret, so a test ticket can never open a production room; isolation by key instead of only by build string (fulfils R1.3).
- **Deploy:** release.yml gains one `flyctl deploy "$PWD/lobby" ... -a wargrid-lobby --ha=false` step plus `/health`, beside the relay step (release.yml:108-120). Lobby deploys no longer end live matches; relay deploys still do.
- **Cost (docs, fly pricing page):** shared-cpu-1x 256 MB "$2.19/month" (lowest region; `fra` $2.53 per development.md Hosting), suspended machines pay rootfs only; volume "$0.15/GB per month of provisioned capacity"; snapshots "$0.08/GB per month" with "First 10GB free each month"; Tigris "billed by usage with no up-front costs". Order of magnitude: **$0-5/month**. Whether the legacy "Up to 3 shared-cpu-1x 256mb VMs" allowance (development.md Hosting) still covers a 4th Wargrid machine is **unverified**: the org lists 8 apps (`fly apps list`, 2026-11-09, all suspended).
- **Ops:** two deployables, one secret, one volume to back up. Moderate.
- **Teaches:** service split along a real seam (long-lived lobby vs hot path), stateless auth tokens, a second protocol under conformance discipline, SQLite + streaming backup, independent deploys.

### C. Lobby, relay, history/presence services with an event bus (upper bound)

- **Services:** `lobby` (as B), `relay`, `history` (consumes `match.started` / `match.ended`, serves `/matches`), `presence` (who is online, friends' status). Bus: Redis Streams on Upstash, or a self-hosted NATS machine (inferred; NATS is no fly product).
- **Persistence:** Managed Postgres for history. Docs: "Fly.io's Managed Postgres is our fully-managed database service"; "All plans include high availability, backups, and connection pooling"; Basic "$38.00 per month". Upstash: "a fully-managed, Redis-compatible database service", "$0.20 per 100k requests", "available in all Fly regions via a private IPv6 address restricted to your Fly organization" (docs.fly.io/upstash/redis).
- **Protocol:** as B, plus events with an outbox in the lobby so a lost publish is retried.
- **Cost:** **about $40-50/month** floor with Managed Postgres, more than everything Wargrid runs today combined many times over. With SQLite per service instead: about $5-10/month.
- **Ops:** high: four deployables, a bus, event schemas, idempotent consumers, more test fixtures. Presence has no consumer in M9 (no friends list exists).
- **Teaches:** event-driven design, outbox, consumer idempotency. Real lessons, but the 3v3 gate needs none of it.

## Persistence

Needed for the M9 exit gate: **nothing**. Lobbies, seats, ready state, chat and codes live in memory and die with a deploy (inferred: a lobby is minutes long and players simply recreate it).

Worth persisting (proposal):

- **Match history:** code, map, build fingerprint, seats (name, faction, team, bot or human), start, end, result, desync flag, drop events. Useful as playtest and desync evidence. Small rows.
- **Player names:** only as the client-id-to-name pair inside history; no accounts.
- **Desync replays:** clients already hold the command log; on a desync, upload the log (a few hundred KB, inferred) to Tigris for debugging. Tigris: "a globally distributed, multi-cloud object storage service with built-in support for the S3 API" (docs.fly.io/tigris). ZH keeps replays only locally (`LastReplay.rep`, ZH src Common/Recorder.cpp:530).
- **Ratings, ladder:** later, only with accounts.

Store choice on fly (docs, 2026-11-09):

| Store | Docs say | Fit |
|---|---|---|
| SQLite on a Fly Volume | "local persistent storage for Fly Machines"; "tied to that hardware"; "Volumes don't have built-in replication"; daily snapshots "may not have your latest data" | Good for one lobby machine; pair with Litestream: "Continuously stream SQLite changes to your preferred cloud storage" (litestream.io) to Tigris |
| LiteFS | "distributed file system that transparently replicates SQLite databases"; "still pre-1.0"; "We are not able to provide support or guidance for it" | Only if the lobby runs on several machines; skip for now |
| Managed Postgres | fully managed, HA, backups; from $38/month | Correct but costs ten times the rest |
| Fly Postgres (unmanaged) | "no longer maintained, and Fly.io Support is not able to provide support or guidance for it"; pages "archived" | **Do not use** |
| Upstash Redis | managed, pay per request | Directory state for multi-relay (relay-scaling.md:145), event bus in C; not a history store |
| Tigris | S3 object storage, usage-billed | Litestream target, desync logs |

## Recommendation (proposal; user decides)

**B: Go lobby service (chi/v5) + relay with a signed-ticket handoff, SQLite on a volume + Litestream to Tigris for match history, anonymous names.** It uses the user's stack choice where a new service genuinely earns its place (lobby lifetime and deploys differ from the hot path), keeps the relay a forwarder with only a ticket check and per-room seats, adds persistence that costs cents, and gives R1.3 a clean test pair. Write the lobby protocol vectors before the lobby, as the relay was. Keep C's history service as a later spike if the user wants event-driven practice; build presence only when a friends list exists. Availability: as relay-scaling.md:143-146 says, reconnect with log replay comes first; the lobby needs no HA (a crashed lobby loses only unstarted rooms).

## Questions

Q1. How do friends find a match?
   a) A public list of open games, optionally password-protected — ZH default (ZH src GameClient/GUI/GUICallbacks/Menus/WOLLobbyMenu.cpp:1186, 1605)   b) Join by code only, as in the mockup   c) Code only now, public list later
   Recommendation: c, because the mockup and friends play need only codes and a list invites strangers. Why it matters: a list needs the lobby service (option B) and moderation.

Q2. How should the backend be split?
   a) Relay only: the lobby runs inside the relay room (option A)   b) A Go lobby service plus the relay (option B)   c) Lobby, relay, history and presence services with an event bus (option C)
   Recommendation: b, because it is real architecture learning at about $0-5/month. Why it matters: decides how many services M9 builds and deploys.

Q3. How does the relay learn about a started match?
   a) The lobby hands each player a signed ticket; the relay checks it   b) The lobby calls the relay's API to create the room   c) Lobby and relay are one program
   Recommendation: a, because it needs no service-to-service call and is testable with a golden vector. Why it matters: shapes protocol 3.

Q4. How do players name themselves?
   a) An online account login — ZH default (GameSpy login, ZH src GUICallbacks/Menus/WOLLoginMenu.cpp)   b) Type a name once; the game remembers it on this device   c) Log in with GitHub or Discord
   Recommendation: b, because friends know each other and accounts add privacy and auth work. Why it matters: c is needed before ratings.

Q5. Should the backend remember finished matches?
   a) Per-player win/loss stats — ZH default (GameSpy persistent stats, ZH src Include/GameNetwork/GameSpy/PersistentStorageThread.h:40)   b) A list of matches only (map, factions, result, length, desync)   c) Nothing; logs are enough
   Recommendation: b, because it is playtest evidence without needing accounts. Why it matters: decides if M9 has a database at all.

Q6. Where should match history live?
   a) SQLite on the lobby machine, streamed to Tigris storage (cents per month)   b) Fly Managed Postgres (from $38/month)   c) Upstash Redis
   Recommendation: a, because one lobby machine needs no database server. Why it matters: Managed Postgres would cost more than everything else combined.

Q7. Should desync logs be uploaded for debugging?
   a) No, replays stay on each player's machine — ZH default (Recorder.cpp:530)   b) Yes, only when a desync happens   c) Yes, every match
   Recommendation: b, because a desync between friends is otherwise hard to reproduce. Why it matters: needs Tigris and an upload endpoint.

Q8. Can players chat in the lobby before the match?
   a) Yes, a chat box in the game setup screen — ZH default (ZH src GUICallbacks/Menus/WOLGameSetupMenu.cpp:534, 850)   b) No, friends use voice   c) Later
   Recommendation: c, because voice covers friends and text input must also work in the browser. Why it matters: chat is the lobby's only free-text input to moderate.

Q9. Can the match creator remove a player from the lobby?
   a) Yes, the host can kick — ZH default (WOLGameSetupMenu.cpp:2131, 2206)   b) No
   Recommendation: a, because a wrong code holder otherwise blocks a seat. Why it matters: one lobby message and a test.

Q10. What happens to a lobby when its creator leaves before the start?
   a) The lobby closes for everyone (ZH: not found)   b) The next player becomes host   c) The code stays valid for 10 minutes
   Recommendation: b, because friends should not have to share a new code. Why it matters: host migration is a lobby-state rule to test.

Q11. Should test builds get their own lobby and relay?
   a) Yes, a test pair with its own ticket secret (fulfils R1.3)   b) No, share production and keep them apart by build string (today)
   Recommendation: a, because relay and lobby changes can then be played before release. Why it matters: two more small fly apps.

Q12. Should rooms survive a relay crash in M9?
   a) No: one machine, players rematch (today)   b) Yes, rebuilt from the clients' own command logs   c) Yes, mirrored to Redis
   Recommendation: a for the exit gate, then b as an availability spike, because b needs reconnect first (relay-scaling.md:143-144). Why it matters: decides if M9 changes the relay beyond tickets.

## Unverified

- Whether the legacy free allowance covers a 4th started machine; the bill was not read.
- Tigris and Litestream prices for this volume (Tigris pricing page not fetched); Litestream's backends were not confirmed on its home page.
- An idle lobby WebSocket across fly autosuspend: M5 saw a headless lobby survive a suspend, launcher behaviour over 5 s silence untested (m5-online.md:46).
- The ticket design is unbuilt and unreviewed; replay protection and clock skew for `exp` need a plan.
