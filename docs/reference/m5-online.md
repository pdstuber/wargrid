# M5 online spike: findings

Status: written 2026-11-04 at Task 11. Evidence rows and review rulings live in [M5 verification](m5-verification.md); this file answers "how hard is multiplayer" and lists the M9 work. Labels: **measured** (command and tree in the verification file), **docs** (primary source read), **unverified**.

## Answer

Lockstep over a dumb relay was not hard once the simulation was deterministic. The determinism work of M0–M4 paid for it: exported macOS, Linux and Windows builds produce identical traces (`compare_local_traces.sh` MATCHED 364 netplay rows, CI run 41835343802), so the spike found no cross-platform divergence. The cost sits elsewhere: state-hash cost, a test runner that works in exported builds, relay lifecycle (suspend, cold start, close races) and pacing. Hardest bug: the first friend match ran at 2x speed because nothing paced ticks to the wall clock.

## What was built and its size

| Part | Lines |
|---|---|
| GDScript, net layer and online scenes (`scripts/net/*`, `online_main.gd`, `launcher.gd`, `state_hash.gd`) | 811 |
| GDScript tests for them (lockstep, wire, hash, transport, online scene) | 766 |
| Kotlin + Ktor relay (`relay/src/main`) | 272 |
| Kotlin relay tests | 269 |
| Tools (`run_netplay.sh`, `desync_diff.py`, `compare_replays.py`) | 255 |

Branch diff against `main`: 90 files, +4,600 / -99. Design: approach A, relay forwards, clients stamp ticks, input delay 4 ticks (133 ms), JSON wire, FNV-1a/`Dictionary.hash()` state digest every 30 ticks, desync report plus `desync_diff.py`.

## What broke and why

- Digest cost: SHA-256 over `var_to_bytes` cost 0.83 ms p99, over the 0.55 ms budget. Replaced by word-wise hashing: 0.136 ms p99 (measured, Task 2).
- `--script` is ignored by release templates, so exported test builds use feature tag `wargrid_tests` and a main-loop override.
- Exported test builds also loaded the launcher, whose `CenterContainer` swallowed clicks: 13 failures on CI Linux and Windows only.
- Godot dropped queued frames when it saw the close, losing the relay's `error` frame; fixed with a 200 ms grace before closing (heuristic).
- Friend match 1 ran at about 57 ticks/s. Fix f82114f paces ticks with a bounded catch-up credit; own close no longer reads as relay loss.
- Native image: four remote builds failed on build-time initialisation of `kotlinx.coroutines`/`kotlinx.io`; dropped, JVM kept.

## Latency (budget: command p95 <= 250 ms)

| Match | Command p50 / p95 | RTT p95 |
|---|---|---|
| Mac vs Windows, friend at home, pre-fix 2x speed (not the gate match) | 75 / 96 ms and 77 / 85 ms | 36 and 34 ms |
| Mac mini vs MacBook Air M1, after fix, 6001 ticks | 174 / 191 ms and 181 / 205 ms (n=13) | 42 and 34 ms |

After the fix the 4-tick delay dominates (about 133 ms); margin to budget is 45–59 ms, so a farther link would exceed it (M9: dynamic delay). Warm probe from the Mac to fra: 78 ms p50. Bytes: about 52 B per frame, about 1.55 KB/s per client uplink.

## Lockstep overhead

`finish_tick` + `receive` p50 / p95 / p99 0.007 / 0.014 / 0.060 ms against the 0.55 ms budget; snapshot on hash ticks p99 0.18 ms (Apple M6, headless, exit-gate rerun). Peer-side digest not timed. Release/WASM timings unverified.

## Hosting

- Cold start of the JVM relay on fly after stop or deploy: p50 about 3.2–3.4 s (max 16.6 s once). AppCDS gave no clear gain on fly. Native was not reached.
- Suspend and resume: manual p50 485 ms; idle autosuspend observed 71 s to 7 min after last activity; a lobby survived a suspend with the headless client only. Suspend during a live match not observed. The launcher fails after 5 s of silence, so a launcher lobby across a suspend over 5 s is expected to fail (untested).
- Memory: about 100 MiB idle, about 128 MiB peak of 256 MB (Grafana screenshot, not measured by command).
- **Cost (docs, fetched 2026-11-04, [fly pricing](https://docs.fly.io/about/pricing)):** no fixed plans for new orgs, "no monthly platform fee". Started `shared-cpu-1x` 256 MB: "$2.19/month" (quoted for `iad`/`ewr`; the `fra` 256 MB price was not captured, the page shows $7.73 for 1 GB in fra against $6.70 in `iad`). Stopped or suspended: "$0.15/GB/month of rootfs". Egress: "$0.02/GB in North America and Europe". A friends-only relay that is mostly suspended should cost cents per month. **The actual bill was not read**; this is a docs estimate.
- **Railway (docs, fetched 2026-11-04, [pricing](https://docs.railway.com/reference/pricing/plans) and [relay scaling](relay-scaling.md)):** Hobby "$5 / month" including "$5 of resource usage"; CPU "$20 / vCPU / month", RAM "$10 / GB / month", egress "$0.05 / GB". WebSocket connections "can stay open indefinitely, even while idle". Sleep after 5 minutes without packets, first request may return 502 (client retry needed). Region: Amsterdam only in Europe, farther from Bavaria than `fra`. A 256 MB always-on service is about $2.50/month of RAM plus CPU, so no clear saving; no migration recommended. Later measured (2026-11-05, relay stack spike): Kotlin, Go, Rust and Elixir relays deployed and load-tested on a Railway trial; comparison in [relay scaling](relay-scaling.md#flyio-vs-railway-measured-2026-11-0405).

## Desync findings

No desync in any test that was not deliberately perturbed, across both human matches and every scenario. The `perturb` scenario reports tick 60 with `snapshot.players[1].credits: 9200 != 9201`. Gap: "building destroyed the same tick it is cancelled" is not arranged deterministically.

## Exit-gate deviation

The plan's hard gate (macOS-Windows human match on the fixed build) is a **user-accepted deferral**: the only such match ran on the pre-fix build. Windows on the fixed build is covered only by CI netplay scenarios. User decision 2026-11-04: repeat this match later; it stays open until then. User looked at the launcher and online HUD and said "that looks fine" (statement, no screenshot).

## M9 list

Lobby and match browser; reconnect with command-log replay; dropped player becomes a bot; dynamic input delay; 3+ seats (egress about 220 KiB/s per 3v3 room in JSON, 120 binary; revisit encoding only if budgets miss); browser export; server-stamped ticks (option B); relay scaling per [relay scaling](relay-scaling.md); room cleanup, join rate limit, drain before deploy (single-process drain window on SIGINT/SIGTERM exists, see README; multi-machine drain open); fixed Docker image tags and non-root user; the 200 ms close grace replaced by a close-frame reason.
