# Relay metrics and logs (design)

Status: **APPROVED by the user 2026-11-08**. Small change; not a milestone. Scheduled after the CI work ([CI design](2026-11-08-ci-speed-and-updates-design.md)).

Relay domain and app (user, 2026-11-08): `relay.pdstuber.dev`, served by a new fly app `wargrid-relay` (fly apps cannot be renamed, per README; the old name's "jvm" predates the Go port). Order: create `wargrid-relay` (outward-facing, user runs or approves), CNAME at the DNS registrar by the user and `fly certs add` on the new app, launcher default `wss://relay.pdstuber.dev/ws`, release workflow and README to the new app and domain, new app-scoped deploy token swapped into `FLY_API_TOKEN_RELAY` by the user. `wargrid-relay-jvm` keeps serving v0.6.0 clients and is destroyed only after the next release, with approval.

## Why

The user is a backend developer and wants to see what the relay is doing: rooms, players, traffic, runtime health. Curiosity and insight, not an incident. Metrics and dashboards are expected to serve that better than logs alone.

## Goals

- Relay exposes Prometheus metrics; fly's managed Prometheus scrapes them; one Grafana dashboard on `fly-metrics.net` shows them.
- A few more structured relay log lines for the events behind those metrics.

## Non-goals

- Web app changes: a static site; fly's built-in edge metrics (`fly_edge_*`, `fly_app_*`) already cover requests, response times and bytes.
- Browser telemetry (errors, frame rate, desyncs reported by clients): agreed as a later, separate step (approach C), with its own design for consent and privacy.
- Self-hosted metrics stack, alerting, long retention (fly keeps about 15 days).
- Protocol changes. `protocol/vectors` and the conformance suite stay untouched.

## Anti-goals

- Per-frame cost on the room loop beyond atomic counter increments.
- High-cardinality labels (room codes, seat ids, build strings as labels). Fly may drop high-cardinality series.
- The metrics port reachable from the internet.

## Approaches

- **A (picked): `prometheus/client_golang` on a second port, scraped by fly.** Standard library, adds Go runtime and process metrics for free. Costs a dependency tree in a relay that today depends only on `gws`.
- B: self-hosted VictoriaMetrics + Grafana on fly (fly's blueprint). Same dashboards, two more apps to run; rejected.
- Hand-written exposition text instead of `client_golang`: smaller, but no runtime metrics; rejected because runtime metrics are half the point.

## Design

- `/metrics` on `0.0.0.0:9091`, separate listener from the game port; `fly.toml` gets `[metrics] port = 9091, path = "/metrics"`. No `[[services]]` entry for 9091, so it is not public.
- Metrics (names are the builder's call, prefix `wargrid_relay_`):
  - gauges: open rooms, connected seats, draining (0/1)
  - counters: connections opened/closed, joins by result (`ok`, each reject reason), rooms created, matches started/ended, frames and bytes in/out, rejected messages, room crashes
  - histograms: match duration, seats per finished match
  - Go runtime and process collectors (default registry)
- Logs (`slog`, existing style): connection opened/closed with close reason, room created, seat joined. No per-frame logs.
- Dashboard: Grafana JSON committed under `relay/`, imported by hand into `fly-metrics.net`; README notes how.
- Tests: `go test -race ./...` covers counters moving on join, reject, match start/end and leave, plus a scrape of `/metrics`. Conformance and the netplay scenarios rerun unchanged.

## Open risk, measured after deploy

Fly's docs do not say whether the 15 s scrape wakes the suspended relay or counts as traffic (autostop is documented only for Fly Proxy requests). After deploy (needs user approval), leave the relay idle and check `fly machine status` and its events. If scraping keeps it awake, the user decides: accept an always-on machine, or turn metrics off between sessions.

## Left to the builder

Metric names and buckets, file layout inside `relay/`, dashboard panels.

## Result (2026-11-08)

Deployed as `wargrid-relay` behind `relay.pdstuber.dev` (cert issued, probe `RELAY WELCOME 77`); metrics reached fly's Prometheus with label `app="wargrid-relay"`, and every dashboard metric existed there.

Suspend, as measured from fly's logs and machine events (a once-a-minute `fly machine list` sample missed the short suspends and first suggested the machine never slept):

- With `[metrics]` active the proxy autosuspended the machine at 08:43:50 UTC and a request resumed it 58 s later (08:44:48); with a scrape every 15 s, **the scrape neither prevented the suspend nor woke the machine**. It suspended again at 08:53:22 and the redeploy resumed it.
- What did wake it: fly's proxy metrics showed 126 HTTP 404 responses in 40 minutes (2 were our WebSocket probes as 101, 3 our health checks as 200), peaking 08:42–08:54 and fading after; the old `wargrid-relay-jvm` got 5 404s in 24 hours. A new hostname with a new certificate appears in Certificate Transparency logs and gets scanned within minutes.
- After the 08:54 redeploy the proxy cordoned the machine at 09:02:45 and 09:09:08 but logged no autosuspend and flyd uncordoned it about 15 s later. Cause not found.

User decision (2026-11-08): remove the metrics code, dependency and dashboard anyway (the relay is plain WebSocket forwarding; metrics come back from git history, commits `935e8e7`, `2ae2f1f`, if the game shows problems). Kept: the new log lines (connection opened/closed, room created, seat joined).

For the planned lobby service: metrics are likely worth more there (state, matchmaking); the evidence above says a `[metrics]` scrape does not keep a fly machine awake.
