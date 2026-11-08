# Relay metrics and logs (design)

Status: **APPROVED by the user 2026-11-08**. Small change; not a milestone. Scheduled after the CI work ([CI design](2026-11-08-ci-speed-and-updates-design.md)).

Relay domain and app (user, 2026-11-08): `relay.pdstuber.dev`, served by a new fly app `wargrid-relay` (fly apps cannot be renamed, per README; the old name's "jvm" predates the Go port). Order: create `wargrid-relay` (outward-facing, user runs or approves), CNAME at Namecheap by the user and `fly certs add` on the new app, launcher default `wss://relay.pdstuber.dev/ws`, release workflow and README to the new app and domain, new app-scoped deploy token swapped into `FLY_API_TOKEN_RELAY` by the user. `wargrid-relay-jvm` keeps serving v0.6.0 clients and is destroyed only after the next release, with approval.

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
