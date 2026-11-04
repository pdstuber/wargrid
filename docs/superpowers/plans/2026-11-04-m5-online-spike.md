# M5 Online Spike Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (native, sequential, per `prompt.txt`). Steps use checkbox (`- [ ]`) syntax for tracking. Implementer: **Sonnet 5.5, medium effort** (user, 2026-11-04). Steps marked **Opus preflight** dispatch one read-only Opus subagent before the task starts (see "Opus preflight" below).

**Goal:** Two desktop clients (macOS, Windows) play today's 1v1 skirmish over the internet in deterministic lockstep through a Kotlin/Ktor relay on fly.io, with desync detection, relay-owned membership, measured latency, and a findings report for M9.

**Architecture:** A transport-agnostic GDScript `Lockstep` class sits between input/scripts and the unchanged `Simulation`: it stamps commands with tick + 4, sends one JSON packet per tick, steps only when every seat's packet is present, and compares snapshot hashes every 30 ticks. A WebSocket transport connects it to a dumb Ktor relay (rooms, seats, membership, raw forwarding). Offline play keeps today's direct path.

**Tech Stack:** Godot 4.7.2 typed GDScript (`WebSocketPeer`, `JSON`), Godot 4.7.2 export templates; Kotlin + Ktor (CIO engine) on JDK 21 with Gradle wrapper; GraalVM native image (experiment); fly.io (`fra`); Python 3 tools; GitHub Actions (Linux, Windows).

**Status:** plan approved by user 2026-11-04; implementation starts only on explicit kickoff (`prompt.txt`).

**Spec:** [M5 design](../specs/2026-11-04-m5-online-spike-design.md) (approved 2026-11-04). Scope and gate: [blueprint](../../../Wargrid_Kickoff_Blueprint.md) §7 M5, §11. Run rules: [milestone prompt](../../milestone-prompt.md). Evidence file: `docs/reference/m5-verification.md` (Task 0 creates it). Reference reading (ideas only, own code): OpenRA `9636b63eae` `OpenRA.Game/Network/OrderManager.cs`, `SyncReport.cs`; GeneralsGameCode `afc2a103f` `Core/GameEngine/Source/GameNetwork/ConnectionManager.cpp`.

## Global Constraints

- Simulation 30 Hz (`game/project.godot` `physics_ticks_per_second=30`). `DELAY = 4` ticks (a command also waits ≤ 1 tick for its packet, so 4–5 ticks, 133–167 ms, before network waits). `HASH_INTERVAL = 30` ticks. `PROTOCOL = 1`.
- Latency budget: click to own command executing **≤ 250 ms p95**, both clients through fly `fra`. Localhost numbers never count toward it.
- Lockstep overhead budget (user 2026-11-04): **10% of a tick on the target, 3.3 ms; 0.55 ms p99 on the development machine** (encode, decode, hash tick). Never loosened to pass.
- JSON text frames. Encode with `JSON.stringify(value, "", true, true)` (full precision; probe 2026-11-04: plain `stringify` writes `0.30000000000000004` as `0.3`). `JSON.parse_string` returns every number as `float` (probe: `typeof == TYPE_FLOAT` for ints); the decoder converts known integer fields back to `int` and rejects non-integral values.
- **Every client applies the decoded wire form of every command, its own included.** Online, commands reach `Simulation.issue_command` only from `Lockstep`, immediately before the step of their tick. Offline paths (`main.gd`, `skirmish_main.gd`, `base_main.gd` submit) unchanged; pinned scenario `TERMINAL_TICK 10667 / WINNER 1` and all replay traces unchanged.
- Relay: Kotlin, Ktor **CIO** engine, JDK 21, directory `relay/`. Forwards client frame text **byte for byte** (never re-serializes). Silence timeout `10_000` ms (any message counts; clients ping every 1 s). Max frame `65_536` bytes. Match code: 6 chars from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`.
- fly: region `fra`, shared CPU, 256 MB, `[http_service]` with `auto_stop_machines = "stop"`, `auto_start_machines = true`, `min_machines_running = 0`. **Every `fly deploy`, `fly apps create`, `fly apps destroy` needs explicit user approval.**
- Gradle runs: `./gradlew --max-workers=4 --priority=low ...` from `relay/`.
- Not in M5: lobby, reconnect, dropped player becoming a bot, dynamic delay, more than two seats, browser export, binary encoding, accounts, restart online.
- Test output: redirect to a file, read summary lines only (AGENTS). Scratch Godot scripts `quit()` on every path.

## Review Focus

1. **Player's machine freezes > 10 s with the socket open** (debugger, sleep, App Nap): expected the relay announces `left` and the other client ends cleanly with "player N disconnected", never hangs. Task 5 scenario `silent`.
2. **Relay dies or fly stops the machine mid-match:** expected both clients end with "connection to relay lost" within 2 s of the socket closing, no hang, no crash. Task 5 scenario `relay-down`.
3. **Both seats act on the same entity in the same tick** (seat 1 attacks a seat-2 unit that seat 2 moves that tick): expected identical outcome on both clients. Task 3 `test_cross_seat_same_tick`.
4. **Third player or stale code joins:** expected `error` "match full" / "unknown match", the running match unaffected. Task 4 `roomRejectsThirdSeatAndUnknownCode`.
5. **One tick with a huge order** (selection of 300 units, or 50 commands in one tick): expected delivered intact below the 64 KiB cap, applied in sequence order. Task 3 `test_many_commands_one_tick`, Task 4 `frameCapBoundary`.

## Opus preflight

At the start of Tasks 1, 3, 5 and 9, dispatch one read-only subagent on Opus (`model: opus`) with: the task's section of this plan, the live files it names, and the instruction "Check every API, signature, flag, file path and assumption in this task against the live code and primary docs. Report only what is wrong or missing, with the fix. Do not edit." Record its findings and the implementer's ruling for each in the verification file before writing code. A finding that changes a design contract is a stop condition.

## Task contracts

Format per milestone prompt. **Stop gates** (gate review, then restart): after Task 1, Task 3, Task 5, Task 9, Task 11.

---

### Task 0: Baseline, branch, records

Task: start M5 from a verified baseline. Owns: `docs/reference/m5-verification.md`, status lines in `README.md`, `AGENTS.md`, blueprint §7 M4.1 header, `docs/session-notes.md`. Stop: baseline count differs from below.

- [ ] Branch `m5-online` from local `main`; `sh tools/run_tests.sh > <log> 2>&1`; expect `TESTS PASSED 104024` (160 cases).
- [ ] Check M4.1 status lines agree (updated during planning, 2026-11-04): merged to `main` at `f2c5f9e`; **user playtest still pending** ("I did not play test 4.1 yet, will do so later"). Fix any line that still says "not merged".
- [ ] Create the verification file with the resume-record block; record branch, base commit, counts.
- [ ] Commit `Start M5 verification record`.

### Task 1: Risk spike (scratch first) — **Opus preflight; run by Opus**

Task: measure the four riskiest unknowns before anything depends on them. Owns: `game/export_presets.cfg`, `tools/export_build.sh`, `game/project.godot` (one line, `import_etc2_astc`), verification notes; everything else scratch. Stop: any result below fails.

Riskiest contracts: (R1) exported release builds give the same traces as the editor binary on macOS/Linux/Windows; (R2) exported builds run headless with user args (and whether `--script` works in a release template); (R3) `var_to_bytes` + SHA-256 of a 300-unit snapshot fits 0.55 ms p99; (R4) JSON round-trip of every command type is bit-exact.

- [ ] Download Godot 4.7.2 export templates (`Godot_v4.7.2-stable_export_templates.tpz` from the `4.7.2-stable` GitHub release), record its SHA-256 in the verification file, install to `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`.
- [ ] Create `game/export_presets.cfg` with presets `macOS`, `Windows Desktop`, `Linux` (release, all resources, unsigned; macOS ad-hoc signing). Create `tools/export_build.sh PRESET OUT_PATH` (`godot --headless --path game --export-release "$1" "$2"`; non-zero exit or missing file fails).
- [ ] R2: export macOS; run `<binary> --headless --script res://tests/run_tests.gd` with the three `WARGRID_*_REPLAY_TRACE` env vars. `--script` is unavailable in release templates (found; never use it against an export, it runs the main scene and hangs). Decided path: feature tag `wargrid_tests` (test preset `custom_features`, `run/main_loop_type` override to a `class_name WargridTestRunner` in `tests/run_tests.gd`); implemented in Task 6.
- [ ] R1: compare exported-macOS traces with editor traces (`python3 tools/compare_replays.py`), expect `REPLAYS MATCHED 1200` ×3. Linux/Windows exported comparison waits for Task 6 CI (no push here).
- [ ] R3: scratch script: build the `contact` combat workload (`game/scripts/debug/combat_workload.gd`) at peak unit count; time 300 iterations of `var_to_bytes(snapshot)` + SHA-256 and of `JSON.stringify` + `JSON.parse_string` of a 50-command packet; record p50/p99. If digest p99 > 0.55 ms: **stop**, report to user with options (cadence, hashed subset).
- [ ] R4: scratch script: for every command type in `Simulation._payload_fields` build one command with float targets like `[14.1, 0.1 + 0.2]`, round-trip with full precision, assert `==` per field after int normalization. Record result.
- [ ] Commit `export_presets.cfg`, `tools/export_build.sh`, verification notes: `Add export presets and M5 risk spike results`. **Stop gate.**

### Task 2: State hash and wire format

Task: one hash function and one deterministic wire codec. Owns: `game/scripts/simulation/state_hash.gd`, `game/scripts/net/wire.gd`, `protocol/vectors/*.json`, `game/tests/test_wire.gd`, `game/tests/test_state_hash.gd`, `game/tests/run_tests.gd` (register suite). Invariant: replay traces byte-identical to before. Boundary: non-integral number in an integer field.

**Interfaces — Produces:**
- `state_hash.gd`: `static func digest(state: Dictionary) -> String` = `"%08x%08x" % [state.hash(), core_check(state)]` (16 hex chars); `static func core_check(state: Dictionary) -> int`: FNV-1a-style 32-bit, **one word per field** (byte-wise costs 0.378 ms, measured by gate review): seed `2166136261`, `h = ((h ^ (v & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF` (the mask keeps `%08x` at 8 digits), over `entities[].id, owner, hp, position[0], position[1]` then `players[].credits`, in snapshot order (buildings not included); a float `x` becomes `floori(x * 1024.0) if is_finite(x) else 0x7FF0000000000000` (NaN/inf convert differently per CPU). Measured: word-wise 0.120 ms p99, digest about 0.164 ms. `test_replay.gd` `_hash` stays SHA-256, unchanged. **Measure first (Task 2 first step):** `digest` p99 on the contact peak snapshot must be ≤ 0.25 ms; if `core_check` pushes it over, stop and report (user approved hash plus core check 2026-11-04, Opus measurement: `hash()` 0.043 ms, packed-subset build 0.157 ms).
- `wire.gd` (`extends RefCounted`, static only): `const PROTOCOL: int = 1`; `static func encode(message: Dictionary) -> String`; `static func decode(text: String) -> Dictionary` returning `{"ok": bool, "error": String, "message": Dictionary}`; `static func tick_message(seat: int, tick: int, commands: Array, hash: Variant) -> Dictionary` (`hash` is `null` or `{"tick": int, "value": String}`; key omitted when null).
- Messages (exact keys): `hello {type, protocol, build, match}` (`match` `""` creates), `welcome {type, seat, match}`, `start {type, seats, delay}`, `tick {type, seat, tick, commands, hash?}`, `ping {type, t}`, `pong {type, t}`, `left {type, seat, after_tick}`, `error {type, reason}`. Reasons exactly: `"protocol mismatch"`, `"build mismatch"`, `"match full"`, `"unknown match"`, `"invalid message"`.
- Integer fields normalized by `decode`: `protocol, seat, tick, delay, after_tick, t, seats[]`, `hash.tick`, and inside each command `tick, player, sequence, builder_id, building_id, production_id, source_id, target_id, entity_ids[], origin[]`. Command `target` stays float.

- [ ] Red `test_state_hash` (new `game/tests/test_state_hash.gd`): pinned literal `digest` of the R1 world after one step (CI Linux/Windows prove cross-platform equality); changing each of id, owner, hp, position, credits, a route entry, a nested event field changes the digest; `core_check` alone changes for the core fields (position by at least 1/1024) and not for a route entry, and is identical for NaN and inf inputs on every platform; 1e-12 float change detected.
- [ ] Red `test_round_trip_every_command`: for each of the 11 command types (list taken from `Simulation._payload_fields` on a sim instance), `decode(encode(m)).message == m` with `target [14.1, 0.30000000000000004]`; ints come back `TYPE_INT`.
- [ ] Red `test_decode_rejects`: `tick: 3.5` → `ok false`; missing `type`; non-object JSON; `entity_ids: ["1"]`; text > 65,536 bytes → all `ok false`, `error` non-empty.
- [ ] Red `test_vectors`: every `protocol/vectors/*.json` file (`{"text": <frame string>, "message": <expected decoded>}` or `{"text", "valid": false}`) decodes as stated. Vectors: one per message type, one 50-command tick, three invalid. Path: `ProjectSettings.globalize_path("res://").path_join("../protocol/vectors")`.
- [ ] Implement; suite green, `test_replay.gd` untouched, traces unchanged (`sh tools/compare_local_traces.sh <last green CI run>` still matches).
- [ ] Commit `Add state hash and lockstep wire format`.

### Task 3: Lockstep core — **Opus preflight**

Task: the deterministic lockstep state machine, tested with an in-memory fake transport. Owns: `game/scripts/net/lockstep.gd`, `game/scripts/net/seat_sim.gd`, `game/scripts/simulation/scripted_human.gd`, `game/scripts/simulation/skirmish.gd` (controller param), `game/tests/test_skirmish_match.gd` (preload moved script), `game/tests/test_lockstep.gd`. Invariant: offline traces and scenario pin unchanged. Boundary: packet arrives for a tick already stepped (protocol error).

**Interfaces — Consumes:** `Wire`, `StateHash` (Task 2); `Simulation.issue_command`, `step`, `tick`, `snapshot` (unchanged).
**Produces:**
- `Skirmish.create(with_match: bool = true, second_controller: String = "ai") -> RefCounted`.
- `scripted_human.gd`: `static func issue(sim: RefCounted) -> void` (moved `_human` + `_threat` + `_command` + constants `HUMAN_ATTACK_TICK 9000`, `STAGE`; comment `# formerly in test_skirmish_match.gd`).
- `lockstep.gd` (`extends RefCounted`):
  - `func _init(seat: int, seats: Array[int], delay: int = 4, hash_interval: int = 30, clock: Callable = Time.get_ticks_usec) -> void`
  - `var send: Callable` — called with one `String` frame per outgoing message.
  - `func start(state: Dictionary) -> void` — prefill empty packets for ticks `0..delay-1` for every seat; record hash for tick 0; send own packet for tick `delay`.
  - `func submit(payload: Dictionary) -> void` — copies payload, sets `tick` = the **next own packet's tick** (after `finish_tick` of tick t sent packet t + delay, the next is t + delay + 1), `player = seat`, `sequence` from own counter (starts 0), records submit time; queued into that packet. So a command waits ≤ 1 tick for its packet plus `delay` ticks.
  - Per-tick call order for every caller (UI, headless client, tests): `receive` all frames → seat script/UI `submit`s at the current tick → `advance` → `finish_tick(snapshot)`.
  - `func receive(text: String) -> void` — handles `tick`, `left`, `error`; anything else or decode failure → state `ended_protocol`.
  - `func can_step(sim_tick: int) -> bool`
  - `func advance(sim: RefCounted) -> bool` — if `can_step`: issue every seat's decoded commands for `sim.tick()` in seat order then packet order, record each in the command log, `sim.step()`, return true.
  - `func finish_tick(tick: int, state: Variant) -> void` — must follow each successful `advance`; the caller passes a snapshot only when `tick % hash_interval == 0` (else `null`; ruling 2026-11-04: `snapshot()` costs 0.375 ms p99, so no snapshot on other ticks). On a hash tick record `StateHash.digest(state)`, compare with any peer hash for that tick (mismatch → `ended_desync`, keep `state` for the report); then encode own packet for `tick + delay` (with hash if recorded), store **its decoded form** as own packet, call `send`.
  - `func status() -> String` — `"running" | "waiting" | "ended_left" | "ended_desync" | "ended_relay" | "ended_protocol"`; `func set_relay_lost() -> void` → `ended_relay`.
  - `func waiting_for() -> Array[int]`, `func left_seat() -> int`.
  - `func hash_rows() -> PackedStringArray` (`"%d\t%s"`), `func command_log() -> Array[Dictionary]`, `func desync_report() -> Dictionary` (`{"seat", "tick", "hash_rows", "command_log", "snapshot"}`), `func latency_samples() -> PackedInt64Array` (µs, submit → start of the `advance` that applied it).
  - `left {seat, after_tick}`: keep stepping while `sim.tick() <= after_tick`; then `ended_left`.
  - Incoming packet must have `seat` ≠ own seat, tick = last received + 1 for that seat, every command `player == seat` and `tick == packet tick`; else `ended_protocol`.
- `seat_sim.gd`: `func _init(sim: RefCounted, lockstep: RefCounted)`; `snapshot()`, `tick()` pass through; `issue_command(command: Dictionary) -> Dictionary` → `lockstep.submit(command)`, returns `{"ok": true, "error": ""}`. Scripts' own `tick`/`sequence` are overwritten by `submit` (pitfall: `Skirmish._send` computes sequence from the snapshot, which lags by `delay`).

Fake transport in the test: two `Lockstep` instances, two `Skirmish.create(true, "human")` sims, a queue per direction; a test helper delivers frames after N ticks or holds them.

- [ ] Red `test_delay_and_prefill`: command submitted while the sim is at tick 10 (after `finish_tick` of 10) executes in the step from 15; ticks 0–3 step without any received packet; tick 4 waits until the peer's packet 4 arrives (`status() == "waiting"`, `waiting_for() == [2]`).
- [ ] Red `test_two_clients_equal_hashes`: seat 1 runs `ScriptedHuman.issue` through `SeatSim`, seat 2 runs `Skirmish.issue_opponent(seat_sim, 2)`; 1,800 ticks with random per-frame delivery delay 0–6 ticks (seeded `RandomNumberGenerator`, seed 5); `hash_rows()` equal on both; equal to a single-process replay of `command_log()` hashed every 30 ticks.
- [ ] Red `test_own_command_uses_wire_form`: submit `move` with target `[0.1 + 0.2, 3.0]`; the logged applied command equals `Wire.decode(Wire.encode(...))` form, `target[0] == 0.30000000000000004`.
- [ ] Red `test_cross_seat_same_tick` (Review Focus 3): same execution tick: seat 1 `attack` on a seat-2 tank, seat 2 `move` of that tank; then pairs `stop`/`attack_move`, `produce`/`attack` on producer, `cancel_build` of a building the enemy destroys that tick; equal hash rows and equal `command_results` on both clients.
- [ ] Red `test_many_commands_one_tick` (Review Focus 5): 50 commands in one tick plus one `move` with 300 entity ids; all applied in sequence order on both clients; frame length < 65,536.
- [ ] Red `test_desync_detected`: seat 2 sim gets `_players[2].credits += 1` at tick 40 (test-only private access) → both reach `ended_desync` at hash tick 60; `desync_report().snapshot.tick == 60`, report command logs equal.
- [ ] Red `test_left_after_tick`: `left {seat 2, after_tick 20}` → seat 1 steps to 21 then `ended_left`; packets for later ticks are not required.
- [ ] Red `test_protocol_errors`: duplicate tick, skipped tick, command with `player` ≠ seat, unknown type → `ended_protocol`, no step.
- [ ] Red `test_latency_samples`: injected clock advancing 33,333 µs per tick, no network delay, submit right after `finish_tick` → every sample == 5 × 33,333 µs.
- [ ] Implement; full suite green; offline traces and `TERMINAL_TICK 10667` unchanged.
- [ ] Commit `Add lockstep core with fake transport tests`. **Stop gate.**

### Task 4: Relay (Kotlin, Ktor)

Task: rooms, seats, membership, validated raw forwarding. Owns: `relay/**`, `.github/workflows/tests.yml` (new `relay` job), `.gitignore` (`relay/build`, `relay/.gradle`). Invariant: forwarded text equals received text byte for byte. Boundary: frame exactly at the cap.

- [ ] Install Gradle once to create the wrapper (`brew install gradle`; `gradle wrapper` inside `relay/`), pin Kotlin, Ktor `3.6.1` (or newest 3.x patch at kickoff, recorded), `ktor-server-cio`, `ktor-server-websockets`, `kotlinx-serialization-json` (parse only: `Json.parseToJsonElement`), Ktor Gradle plugin for `buildFatJar` → `relay/build/libs/relay-all.jar`. Test deps: `ktor-server-test-host`, `kotlin-test`.

**Interfaces — Produces:**
- `relay/src/main/kotlin/wargrid/relay/Main.kt`: `data class RelayConfig(val port: Int = 8080, val protocol: Int = 1, val delay: Int = 4, val silenceMillis: Long = 10_000, val maxFrameBytes: Int = 65_536, val testDelayMillis: Long = 0)`; `fun main()` reads `PORT`, `WARGRID_TEST_DELAY_MS` (shortcut: test-only knob, never set in `fly.toml`); `fun Application.relay(config: RelayConfig, codes: () -> String = ::randomCode)`. Routes: `GET /health` → 200 `ok`; WebSocket `/ws`.
- `Rooms.kt`: `class Rooms(config, codes)` holding `code → Room(seats: Map<Int, Seat>, build: String, started: Boolean)`; seats 1 then 2; room deleted when empty.
- `Envelope.kt`: `fun parseEnvelope(text: String, maxBytes: Int): Envelope?` with `type`, `seat`, `tick`, `protocol`, `build`, `match`; null on any shape error.
- Rules: first frame must be `hello`; protocol ≠ config → `error "protocol mismatch"`, close; `match == ""` → new room, `welcome {seat 1, match code}`; existing code → build must equal room build else `"build mismatch"`; full → `"match full"`; unknown → `"unknown match"`. Second seat joined → `start {seats [1,2], delay 4}` to both. `tick`: `seat` must equal the connection's seat and `tick` must be `delay` for the first packet then last + 1, else `"invalid message"` and the seat is dropped. Valid `tick` frames go to the other seat unchanged (after `testDelayMillis`, order preserved). `ping` → `pong` with same `t` to the sender. Any frame resets the silence timer. Socket close or silence → `left {seat, after_tick}` to the remaining seat, `after_tick` = last forwarded tick or `delay - 1`.

- [ ] Red tests in `relay/src/test/kotlin/wargrid/relay/RelayTest.kt` (Ktor `testApplication`, two WebSocket clients): `createJoinStart`, `forwardsTickFramesByteForByte` (frame with `0.30000000000000004` arrives identical), `rejectsWrongSeatAndNonContiguousTick`, `protocolAndBuildMismatch`, `roomRejectsThirdSeatAndUnknownCode` (Review Focus 4), `frameCapBoundary` (65,536 bytes accepted, 65,537 rejected), `closeAnnouncesLeftWithLastTick`, `silenceAnnouncesLeft` (config `silenceMillis = 200`), `pingPong`, `healthOk`.
- [ ] Red `VectorsTest.kt`: every `protocol/vectors/*.json` frame: `parseEnvelope` non-null for valid, null for invalid.
- [ ] Implement; `./gradlew --max-workers=4 --priority=low test buildFatJar` green; record test count.
- [ ] CI: add job `relay` (ubuntu, `actions/setup-java` Temurin 21, Gradle cache, `./gradlew test buildFatJar`, upload `relay-all.jar` artifact for Task 6).
- [ ] Commit `Add Ktor relay with rooms and membership`.

### Task 5: Transport, headless client, end-to-end and failure scenarios — **Opus preflight**

Task: real sockets end to end, locally, with every failure scenario automated. Owns: `game/scripts/net/relay_transport.gd`, `game/scripts/net/headless_client.gd`, `game/scenes/net_headless.tscn`, `tools/run_netplay.sh`, `tools/desync_diff.py`, `tools/test_desync_diff.py`, `tools/compare_replays.py` (+ its test), `game/tests/test_relay_transport.gd`. Invariant: suite stays relay-free (no JVM needed for `run_tests.sh`). Boundary: relay dies mid-match.

**Interfaces — Produces:**
- `relay_transport.gd` (`extends RefCounted`): `func connect_to(url: String) -> Error`; `func poll() -> PackedStringArray` (received text frames; call every frame); `func send_text(text: String) -> void`; `func is_open() -> bool`; `func closed() -> bool` (was open, now closed); pings every 1,000 ms with `Time.get_ticks_usec()`, keeps `rtt_samples() -> PackedInt64Array` from `pong`.
- `headless_client.gd` on `net_headless.tscn`, user args (after `--`): `--relay URL`, `--match CODE|new`, `--code-file PATH` (writes the code when creating), `--seat-script human|opponent|idle`, `--hash-log PATH`, `--command-log PATH`, `--report-dir DIR`, `--uncapped` (step whenever ready, ≤ 64 steps per frame; capped mode ≤ 2 per physics frame), `--exit-at-tick N` (hard exit without closing, via `OS.kill(OS.get_process_id())`), `--stall-at-tick N --stall-seconds S` (`OS.delay_msec`, blocks pings too), `--perturb-at-tick N` (shortcut: test-only, `_players[seat].credits += 1`), `--build STR` (override), `--replay-log PATH` (oracle mode: no network, replays a command log, writes `--hash-log`), `--hash-every N` (oracle mode only, default 30; `1` narrows a desync to its first tick when run on each machine), `--probe-relay URL` (prints `RELAY WELCOME <ms>` for Task 9). Prints exactly one final line `NETCLIENT END <status> TICK <t>` (`<status>` is `match_over` when `sim.match_over()`, else `Lockstep.status()`); exit 0. On `ended_desync` writes `desync_report()` as JSON to `--report-dir`.
- Build string: `ProjectSettings application/config/version` (add `config/version="0.5.0"` to `project.godot`) unless overridden.
- `compare_replays.py`: add `--interval N` (default 1) and `--rows N` (default 1200; `0` = any length, all files equal length); rows must be `k*interval` ticks with k ≥ 0 (netplay logs include the tick-0 row); all compared files use the same digest width; digests may be 64 hex (replay traces) or 16 hex (netplay logs), `compare_replays.py` currently hard-codes 64 (line 13). Existing CI calls unchanged.
- `desync_diff.py A.json B.json`: prints first differing command-log index, else the first differing snapshot key path (`entities[3].position[0]: 14.1 != 14.100000000000001`); exit 1 if reports differ, 0 if identical.
- `run_netplay.sh SCENARIO` (`match | kill | stall | silent | spike | perturb | version | relay-down`): starts `java -jar relay/build/libs/relay-all.jar` on a free port, client binary from `$WARGRID_CLIENT` else `godot --headless --path game res://scenes/net_headless.tscn`, both `--uncapped`; writes logs to a temp dir; checks expectations; prints `NETPLAY PASSED <scenario>`; non-zero exit otherwise.

Scenario expectations:
- `match`: seat 1 `human`, seat 2 `opponent`, until match over; both `NETCLIENT END ended_*`/match-over at the same tick; hash logs equal each other and the oracle (`compare_replays.py --interval 30 --rows 0`).
- `kill`: seat 2 `--exit-at-tick 600` → seat 1 `ended_left`, tick ≥ 600.
- `stall`: seat 2 stalls 3 s at tick 300 → match continues, hash logs equal.
- `silent` (Review Focus 1): seat 2 stalls 15 s → seat 1 `ended_left` within 12 s of the stall start.
- `spike`: relay `WARGRID_TEST_DELAY_MS=200` → match completes, hashes equal.
- `perturb`: seat 2 `--perturb-at-tick 40` → both `ended_desync` at tick 60; `desync_diff.py` exit 1 and names `players`.
- `version`: seat 2 `--build other` → seat 2 ends with `build mismatch`, seat 1 still waiting, then harness stops it.
- `relay-down` (Review Focus 2): harness kills the relay at tick ~300 → both `ended_relay` within 2 s.

- [ ] Red `test_relay_transport` (GDScript suite, no relay): `poll()` on a never-connected transport returns empty and `closed()` false; ping scheduling with injected clock.
- [ ] Red `tools/test_desync_diff.py` and the new `test_compare_replays.py` cases (interval, any-length, old 1200 default unchanged).
- [ ] Implement transport, headless client, tools.
- [ ] Run all eight scenarios locally; each `NETPLAY PASSED`; record wall time per scenario and the `match` terminal tick.
- [ ] Commit `Add headless netplay client and failure scenarios`. **Stop gate.**

### Task 6: Cross-platform CI with exported builds

Task: the Mac-vs-Windows determinism signal on what players run. Owns: `.github/workflows/tests.yml`, `tools/compare_local_traces.sh`. Invariant: existing replay comparison unchanged. Boundary: export-template download failure fails the job (no silent skip).

- [ ] CI `godot` job (Linux, Windows): install pinned templates (SHA-256 from Task 1, `actions/cache` keyed on it), `sh tools/export_build.sh` for the platform, download `relay-all.jar` from the `relay` job (`needs: relay`), Temurin 21, run `WARGRID_CLIENT=<export> sh tools/run_netplay.sh match` with hash logs written to `netplay-<platform>.tsv`; upload; also run `perturb` and `relay-down`. Upload the Windows export as artifact `wargrid-windows` (Task 10 uses it). Test-runner decision from Task 1: add the `wargrid_tests` test presets, the `run/main_loop_type.wargrid_tests` override in `project.godot` and `class_name WargridTestRunner`, then run the exported suite and the three replay traces from exports in CI (R1 for Linux/Windows; never `--script`). On Windows run `Wargrid.console.exe` (GUI exe may print nothing); verify `NETCLIENT END` reaches `run_netplay.sh`. Task 6 owns `game/export_presets.cfg` and `game/project.godot` changes too.
- [ ] `compare-replays` job: `python3 tools/compare_replays.py --interval 30 --rows 0 traces/netplay-linux.tsv traces/netplay-windows.tsv`.
- [ ] `compare_local_traces.sh`: also download `netplay-*`, export macOS locally, run `match` with it, compare all three.
- [ ] Ask the user before `git push` (push needs approval); then CI green on Linux and Windows; `sh tools/compare_local_traces.sh <run id>` prints four matched lines. Record run id.
- [ ] Commit `Run exported netplay match in CI`.

### Task 7: Online play in the game

Task: a person can create or join a match and play it. Owns: `game/scenes/launcher.tscn`, `game/scripts/launcher.gd`, `game/scenes/online_skirmish.tscn`, `game/scripts/online_main.gd`, `game/scripts/base_main.gd`, `game/scripts/main.gd`, `game/scripts/skirmish_main.gd`, `game/scripts/presentation/world_view.gd` (local player), `game/project.godot` (`run/main_scene`), `game/tests/test_online_scene.gd`, `docs/playing-online.md`. Invariant: offline scenes behave exactly as today. Boundary: seat 2 controls player 2's units.

- Local player is hard-coded as `1` in `main.gd:165,167`, `base_main.gd:52,87,145,173,183`, `skirmish_main.gd:69,71,98`, `world_view.gd:45,126,195`. Add `var local_player: int = 1` on `main.gd` and `WorldView.local_player`; replace each literal; offline value stays 1.
- `online_main.gd extends "res://scripts/skirmish_main.gd"`: `func setup(transport: RefCounted, lockstep: RefCounted, seat: int) -> void`; `_create_simulation()` → `Skirmish.create(true, "human")`; `_step_simulation()` → poll transport, feed `receive`, `advance`, then `finish_tick(tick, snapshot or null)` (snapshot only on hash ticks; `main.gd` calls `_step_simulation()` before `_refresh()`, so no refresh snapshot exists yet); `_submit(payload)` → `lockstep.submit(payload)`; Restart hidden; HUD line shows `Waiting for player N`, `Player N disconnected`, `Connection to relay lost`, `Desync — report saved to <path>` (report under `user://desync/`); on match end print latency p50/p95 and RTT p95 to stdout and `user://netplay-latency.txt`.
- `launcher.gd` (new `run/main_scene`): relay URL field (default `wss://wargrid-relay.fly.dev/ws` until Task 9 decides the app name), buttons `Play offline` (→ `skirmish.tscn`), `Create match`, code field + `Join`; status label shows `Match code: XXXXXX — waiting for player 2` and relay errors verbatim. If user args contain `--relay` or `--replay-log` or `--probe-relay`, switch to `net_headless.tscn`.
- [ ] Red `test_online_scene` (headless, fake transport): seat 2 instance selects and moves a player-2 tank (command `player == 2`), cannot select player-1 units; status lines above; Restart hidden; HUD layout: no button overlaps any status line in each of the four status states (existing K5 rule).
- [ ] Red `test_launcher_layout`: controls do not overlap at 1280×720 and 1920×1080; `Play offline` loads the offline skirmish.
- [ ] Implement; suite green; offline traces and pin unchanged.
- [ ] `docs/playing-online.md`: download, open past Gatekeeper (right-click → Open) and SmartScreen (More info → Run anyway), create/join, what the end messages mean, where the desync report is.
- [ ] Commit `Add online match flow`.

### Task 8: Lockstep benchmark and ledger

Task: prove the overhead budget. Owns: `game/benchmarks/run_lockstep.gd`, `tools/run_benchmark.sh`, `docs/reference/performance.md`. Invariant: existing benchmark outputs unchanged. Boundary: the hash tick.

- [ ] `run_lockstep.gd`: on the `contact` combat workload, two `Lockstep` instances with the in-memory transport, 10 s warmup + 60 s sample (ticks, not wall time, as today's benchmarks), time per tick of `finish_tick` + `receive` (encode, decode, digest on hash ticks); assert inside the window: ≥ 60 hash ticks and ≥ 1 non-empty packet per 30 ticks; print `LOCKSTEP BUDGET PASS p99 <ms>` or `FAIL`; exit non-zero on fail.
- [ ] `run_benchmark.sh` expects the new line; `sh tools/run_benchmark.sh` passes; add ledger Budgets row (10% / 3.3 ms / 0.55 ms) and History row; exceeded → stop, report.
- [ ] Ask the user once for the rendered rerun (presentation changed), batched with Task 10's visible checks.
- [ ] Commit `Add lockstep benchmark and ledger row`.

### Task 9: fly.io hosting and the GraalVM experiment — **Opus preflight**

Task: deploy the relay and decide JVM vs native. Owns: `relay/Dockerfile`, `relay/Dockerfile.native`, `relay/fly.toml`, `relay/src/main/resources/META-INF/native-image/**` (if needed), README hosting section, verification notes. Stop: each deploy or app creation without approval; native build fails to serve WebSockets after 2 attempts (record and continue with JVM).

- [ ] `Dockerfile` (JVM): Gradle build stage on Temurin 21 → `eclipse-temurin:21-jre` runtime running `relay-all.jar`. `Dockerfile.native`: GraalVM community 21 native-image stage → slim runtime. Both `EXPOSE 8080`.
- [ ] `fly.toml`: `app = "wargrid-relay"`, `primary_region = "fra"`, `[http_service] internal_port = 8080, force_https = true, auto_stop_machines = "stop", auto_start_machines = true, min_machines_running = 0`, health check `GET /health`, `[[vm]] size = "shared-cpu-1x", memory = "256mb"`.
- [ ] **Ask the user** to approve: `fly apps create wargrid-relay-jvm`, `wargrid-relay-native`, and one deploy each (`fly deploy -c relay/fly.toml -a <app> --dockerfile <file>`, remote builder).
- [ ] Per app, 5 runs: `fly machine stop` all machines, wait until stopped, then `--probe-relay wss://<app>.fly.dev/ws` → `RELAY WELCOME <ms>`; then warm runs ×5. Record cold/warm p50/max and memory (`fly machine status` / metrics). Run `run_netplay.sh match` against each deployed relay once (client-side relay URL override) to prove WebSockets work end to end.
- [ ] Decide with the user: keep one, rename to `wargrid-relay` or keep the name, **ask before** `fly apps destroy` of the other. Record the decision, image, cost assumptions and commands in README (hosting) and the verification file; set the launcher default URL.
- [ ] Commit `Host relay on fly.io`. **Stop gate.**

### Task 10: Human matches

Task: the exit-gate matches. Owns: verification notes, `docs/reference/m5-online.md` (measurements section). Stop: any desync or crash → systematic-debugging with the desync report before anything else.

- [ ] Exported builds: macOS locally, Windows from CI artifact `wargrid-windows`.
- [ ] With the user at home: a complete match macOS ↔ Windows through the deployed relay; collect both `user://netplay-latency.txt`; check p95 ≤ 250 ms; both clients' hash logs equal (`compare_replays.py --interval 30 --rows 0`). Batched visible checks: rendered benchmark rerun, launcher and online HUD looked at by the user.
- [ ] With one friend from their own location (hard gate): one complete match; same evidence; their OS recorded.
- [ ] Record bytes/s per client (relay log line per match end: frames and bytes per seat — add to relay if not present, tested).
- [ ] Commit `Record M5 human match evidence`.

### Task 11: Findings report and exit gate

Task: answer "how hard is multiplayer" and close M5. Owns: `docs/reference/m5-online.md`, README, blueprint §7 M5 status + §14 decision log, AGENTS reading list, session notes.

- [ ] `m5-online.md`: what was built and its size (lines GDScript / Kotlin), what broke and why, latency (p50/p95, RTT, waits), bytes/s, cold start JVM vs native, cost, desync findings, and the M9 list (lobby, reconnect, dropped player becomes bot, dynamic delay, 3+ seats, browser export, server-stamped ticks option B), and a **hosting-cost follow-up (user, 2026-11-04):** fly.io no longer sells fixed monthly plans, so record the measured fly cost and investigate railway.com as an alternative backend host (pricing model, idle cost, WebSocket support, region near Bavaria, deploy of the Kotlin relay); investigation only, no migration without user approval.
- [ ] Exit-gate run on the final tree: full suite; `sh tools/run_benchmark.sh` + ledger row; relay `./gradlew test`; all eight `run_netplay.sh` scenarios; CI Linux/Windows + `compare_local_traces.sh`; one substantive review (Grok, command in `~/.claude/CLAUDE.md`), then `/ponytail-review`; fix findings test-first.
- [ ] Status docs updated; report implemented / verified / pending separately. **Stop gate.**
