# Relay metrics, logs and new relay app Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The relay exposes Prometheus metrics scraped by fly, logs connection and room events, and runs as fly app `wargrid-relay` behind `relay.pdstuber.dev`.

**Architecture:** `prometheus/client_golang` metrics as package-level vars in one new file, incremented at the existing event points in `main.go` and `room.go`; a second listener on `:9091` serves `/metrics`; fly scrapes it via `[metrics]` in `fly.toml`. Then a new fly app, custom domain, launcher default and release workflow switch to it.

**Tech Stack:** Go 1.27.3, `github.com/prometheus/client_golang` (latest release at implementation time), `log/slog`, fly.io managed Prometheus/Grafana, Godot launcher scene.

**Spec:** [Relay metrics and logs design](../specs/2026-11-08-relay-metrics-design.md)

## Global Constraints

- Protocol unchanged: `protocol/vectors` and `sh tools/run_conformance.sh` pass untouched.
- Relay change gate (AGENTS.md): `go test -race ./...` and `golangci-lint run` in `relay/`, `sh tools/run_conformance.sh`, and the netplay scenarios `match perturb relay-down` (`sh tools/run_netplay.sh <scenario>`).
- No high-cardinality labels: no room codes, seat numbers, build strings or IPs as labels. The only label is `result` on joins (`ok` plus the four reject reasons in `room.go`).
- No per-frame logs; per-frame metric cost is atomic adds only.
- Metrics port `9091`, path `/metrics`, never in `[[services]]` or `[http_service]`.
- No client IPs in logs (public game; personal data).
- Outward-facing steps (fly app create, deploy, certs, token, DNS, destroying the old app) need the user's approval at the time; DNS and the GitHub secret are done by the user.
- `wargrid-relay-jvm` stays up; destroying it is out of scope (after the next release, with approval).

## Review Focus

- Metrics listener failing to bind (port in use when several relays run locally): the relay must keep serving games and log a warning. Task 1 test.
- Seat gauge drifting on every leave path (normal leave, drain close, stop, room crash): Task 1 tests leave and crash paths return the gauge to its start value.
- A room that never started (lobby closed by drain or creator leaving) must not count as a match end or add a duration sample. Task 1 test.
- Joins racing room crash (`unknown match` via `r.done`) counted once, as `unknown match`. Task 1 covers via the existing reasons.
- Scraping keeps the suspended machine awake: measured in Task 3, reported to the user, never silently accepted.

---

### Task 1: Metrics and logs in the relay

**Files:**
- Create: `relay/metrics.go`, `relay/metrics_test.go`
- Modify: `relay/main.go`, `relay/room.go`, `relay/go.mod`, `relay/go.sum`

**Interfaces:**
- Produces: metric names (prefix `wargrid_relay_`): gauges `rooms` (GaugeFunc over `reg.count()`, registered in `main`), `seats`, `draining`; counters `connections_opened_total`, `connections_closed_total`, `joins_total{result}`, `rooms_created_total`, `matches_started_total`, `matches_ended_total`, `room_crashes_total`, `frames_total`, `frame_bytes_total`, `messages_rejected_total`; histogram `match_duration_seconds` (buckets 60, 120, 300, 600, 900, 1200, 1800, 2700, 3600). Default Go and process collectors stay registered.
- Produces: `func serveMetrics(addr string)` in `metrics.go`: listens on addr, serves `promhttp.Handler()` at `GET /metrics`, logs `slog.Warn("metrics listen failed", ...)` and returns on bind error (never exits). `main` calls `go serveMetrics(":9091")`.
- Produces: `room.startedAt time.Time`, set when the match starts.

- [ ] **Step 1: Failing tests** in `metrics_test.go`, using `prometheus/testutil.ToFloat64` deltas (metrics are global; read before, compare after) and the helpers in `shutdown_test.go` (`seated`, `eventually`, `nop`) and `batch_test.go` (`dial`, `say`):
  - `TestJoinResultsAreCounted`: create (`ok` +1), join with wrong build (`build mismatch` +1), unknown code (`unknown match` +1), wrong protocol (`protocol mismatch` +1), third seat into a full 2-seat room (`match full` +1).
  - `TestMatchLifecycleIsCounted`: two seats → `matches_started_total` +1, `seats` +2, `rooms_created_total` +1; both leave → `matches_ended_total` +1, `seats` back to start, `match_duration_seconds` sample count +1.
  - `TestLobbyThatNeverStartedIsNoMatch`: one seat creates then leaves → `matches_ended_total` +0, histogram count +0, `seats` back to start.
  - `TestRoomCrashRestoresGauges`: as `TestRoomPanicEndsOnlyThatRoom` → `room_crashes_total` +1 and `seats` back to start once sockets close.
  - `TestFramesAndRejectsAreCounted`: valid tick → `frames_total` +1, `frame_bytes_total` +len(frame); out-of-order tick → `messages_rejected_total` +1.
  - `TestConnectionsAreCounted`: `httptest` server with `newServer`, `dial` once, close → opened +1, closed +1 (`eventually`).
  - `TestMetricsEndpoint`: `serveMetrics` on `127.0.0.1:0`-style free port (listen first to find one, or factor the handler so the test uses `httptest`) → body contains `wargrid_relay_seats` and `go_goroutines`.
  - `TestMetricsBindFailureKeepsRunning`: occupy a port, `serveMetrics` on it returns (does not exit).
- [ ] **Step 2:** `go test -race ./...` in `relay/` → the new tests fail to compile or fail (no metrics yet).
- [ ] **Step 3:** `go get github.com/prometheus/client_golang@latest`; implement `metrics.go` and the increments at: `OnOpen`/`OnClose` (connections), `registry.join`/`create` (joins by result), `create` (rooms created), `admit` (seats +1; on start: matches started, `startedAt`), `forward` (frames, bytes; reject path: rejected), `OnMessage` invalid paths (rejected), `leave` (seats −1; on empty room and `started`: matches ended, duration), `recoverCrash` (crashes; seats −len(seats) for seats still present), `shutdown` (`draining` 1).
- [ ] **Step 4:** Logs (`slog.Info`, existing style, no IPs): `connection opened`; `connection closed` with `err` from `OnClose`; `room created` with `code`, `build`; `seat joined` with `code`, `seat`. Keep `join rejected`, `match start`, `MATCH END`.
- [ ] **Step 5:** Gate: `go test -race ./...`, `golangci-lint run` (in `relay/`), `sh tools/run_conformance.sh`, `sh tools/run_netplay.sh match`, `perturb`, `relay-down` all pass; `container build -t relay-check relay` builds.
- [ ] **Step 6:** Commit: `Add Prometheus metrics and event logs to the relay`.

### Task 2: Dashboard and fly config

**Files:**
- Create: `relay/grafana-dashboard.json`
- Modify: `relay/fly.toml`, `README.md` (relay section)

- [ ] **Step 1:** `fly.toml`: `app = "wargrid-relay"`; add `[metrics]` `port = 9091`, `path = "/metrics"`.
- [ ] **Step 2:** Dashboard JSON (Grafana import format, Prometheus datasource as a `${DS_PROMETHEUS}` input, `app` variable defaulting to `wargrid-relay`). Panels: rooms and seats; joins by result (`rate`); matches started/ended (`increase` per hour); match duration p50/p90; frames/s and bytes/s; rejected messages and crashes; goroutines, heap, GC pause; plus fly's built-in `fly_instance_cpu` / memory and `fly_app_concurrency` for the app.
- [ ] **Step 3:** Verify: `python3 -c 'import json,sys; json.load(open("relay/grafana-dashboard.json"))'` exits 0; every metric name in the dashboard exists in `metrics.go` or the fly built-in list in the design (grep each).
- [ ] **Step 4:** README relay section: metrics port, the dashboard file and "import it in fly-metrics.net → Dashboards → Import".
- [ ] **Step 5:** Commit: `Add the relay Grafana dashboard and fly metrics config`.

### Task 3: New relay app and domain (user steps marked USER)

**Files:**
- Modify: `game/scenes/launcher.tscn:48`, `.github/workflows/release.yml` (relay deploy app and health URL), `README.md` (relay URLs and commands)

- [ ] **Step 1 (approval):** `fly apps create wargrid-relay --org <user's org>`; `fly deploy relay -c $PWD/relay/fly.toml -a wargrid-relay --ha=false`; `fly machine list -a wargrid-relay` shows exactly one machine; `curl -fsS https://wargrid-relay.fly.dev/health` prints `ok`.
- [ ] **Step 2 (approval):** `fly certs add relay.pdstuber.dev -a wargrid-relay`; give the user the record it prints. USER adds the CNAME at the DNS registrar. Then `fly certs show relay.pdstuber.dev -a wargrid-relay` shows issued, and `curl -fsS https://relay.pdstuber.dev/health` prints `ok`.
- [ ] **Step 3:** `godot --headless --path game -- --probe-relay wss://relay.pdstuber.dev/ws` prints `RELAY WELCOME <ms>`.
- [ ] **Step 4:** Launcher default `wss://relay.pdstuber.dev/ws`; `release.yml` deploys `-a wargrid-relay` and checks `https://relay.pdstuber.dev/health`; README relay status, commands and URLs updated (old app noted as serving v0.6.0 until removed). `sh tools/run_tests.sh` passes with unchanged totals (482 cases).
- [ ] **Step 5:** USER creates `fly tokens create deploy -a wargrid-relay` and stores it as repo secret `FLY_API_TOKEN_RELAY` (the agent never prints a token).
- [ ] **Step 6: Scrape vs suspend.** Leave the relay idle 15 min; `fly machine status` / `fly logs -a wargrid-relay` show whether it suspends. Also confirm metrics arrive in fly-metrics.net (`wargrid_relay_seats` query). Record both in the design doc. If scraping keeps it awake, stop and ask the user (always-on vs metrics off).
- [ ] **Step 7:** Commit: `Move the relay to wargrid-relay behind relay.pdstuber.dev`.
