# Converted Maps Playable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dry Wells, Broken Crown and Ashfall become selectable in the launcher, offline and in online 1v1, with both online clients guaranteed the same map (or refusing to start), start spots by Zero Hour's rule, bots that build, collect and attack on all three maps, and an in-game Credits panel.

**Architecture:** The relay goes to protocol 2: the host's `hello` carries an opaque `settings` object that the relay stores byte-exact and echoes in `start` together with a relay-generated `seed`. Each client checks the settings (map id and map hash) before the simulation exists, picks start spots with one pure function (`StartSpots.assign`, Zero Hour's rule, chosen spots as input for M9), and `Skirmish.create` maps the chosen starts onto seats 1 and 2 by renumbering a copy of the map's `starts`, so everything downstream (slots, rally, camera) is unchanged. With no starts given (`skirmish.json`, tests, replays, benchmarks, CI netplay) nothing changes, so every pin holds.

**Tech Stack:** Godot 4.7.2 typed GDScript (`game/`), Go relay (`relay/`), Go conformance suite (`protocol/conformance`), POSIX sh tools.

**Spec:** [design](../specs/2026-11-08-converted-maps-playable-design.md) (approved 2026-11-08) and the user's handoff (`converted-maps-prompt.txt`, private) ("Facts", "Decided", "Done when" are binding). Execution rules: [milestone prompt](../../milestone-prompt.md), overridden where noted below.

## Zero Hour facts this plan relies on (spot-checked 2026-11-08, plan writer)

- Start-spot rule, EA source `~/projects/CnC_Generals_Zero_Hour` @ `0a05454`, `GeneralsMD/Code/GameEngine/Source/GameLogic/System/GameLogic.cpp`: `populateRandomStartPosition` (`:809`), `numPlayers = md->m_numPlayers` (`:815-819`); distance table = straight-line distance between `Player_<i+1>_Start` waypoints (`:821-850`); any pre-chosen spot sets `taken` and `hasStartSpotBeenPicked` (`:855-871`, the test `posIdx >= 0 || posIdx >= numPlayers` is effectively `>= 0`); the old `#if 0` branch (`:875-943`) is dead; the live `#else` branch (`:944-1039`): first unplaced slot with no spot picked yet gets `GameLogicRandomValue(0, numPlayers-1)` re-drawn while taken (`:964-978`); a slot whose team is none or not yet placed gets the free spot with the largest summed distance to all taken spots, strict `>` so the lowest index wins ties (`:979-1019`); a slot whose team is placed gets the free spot closest to `teamPosIdx[team]`, strict `<`, lowest index on ties (`:1020-1035`). `teamPosIdx` (`:945-947`) is set only at `:977` and `:1018`, by slots placed in this loop; pre-chosen slots are skipped at `:957-959` and never set it.
- Wargrid map seat N is Zero Hour's `Player_N_Start`: `tools/zh_map/convert.py:261-264` (`_seat_of` parses the waypoint name) and `:307-325` (starts sorted by that number, `seat=seat`). So Zero Hour's `posIdx` i is Wargrid map seat i+1, and `map.starts` is in seat order.
- Wargrid measures between start cells (`int(x // 25)`), Zero Hour between waypoint world positions. **Checked, not inferred, for these maps only:** the farthest-start table is the same both ways (raw waypoints decoded with `convert.load` from `CnC_Modding_Support` `3aad8e4`, Twilight Flame and Fallen Empire): Ashfall 1↔5, 2↔6, 3↔7, 4↔8; Broken Crown 1↔3, 2↔4; no near-ties. **Inferred:** on other maps cell rounding could flip a near-tie.
- Expected values derived from the shipped map cells (plan writer, `python3 -I`, 2026-11-08), used verbatim in Task 2: Ashfall nearest start 1→8, 2→3, 3→2, 4→5, 5→4, 6→7, 7→6, 8→1; three different teams with seat 1 chosen first: second 5, third 7 (summed 232.5 vs next 223.2); Ashfall 2v2 (teams `[1, 1, 2, 2]`, first random start f): f=1 `[1,8,5,4]`, 2 `[2,3,7,6]`, 3 `[3,2,7,6]`, 4 `[4,5,8,1]`, 5 `[5,4,8,1]`, 6 `[6,7,2,3]`, 7 `[7,6,2,3]`, 8 `[8,1,5,4]`.

## Global Constraints

Copied from the handoff and design; every task's requirements include these.

- Small task, not a milestone; do not build the M9 lobby (slots, chosen starts, teams in the UI), bot tuning (M8), tech buildings, a minimap, map transfer or a relay deploy. Do not pick a design M9 would have to undo.
- Without the launcher, scenes, tests, replays, benchmarks and the netplay client use the 48x32 `skirmish.json`. Anti-goal: any of them silently moving off it; a client that plays a guessed map. Exceptions that already use converted maps: the Ashfall team match (`team_match.gd`, pinned in `test_team_match.gd` `FINAL_DIGEST` / `TEAM_CORE_SERIES` and `run_team_match.sh` `units_peak`), the Ashfall movement layout (`movement_workload.gd`) and the map tests (MP1, MP6, Pl3).
- Pins and traces unchanged, with two exceptions the user pre-approved on 2026-11-08: pins moved by Task 3b's collector change, and pins moved by Task 3c's slot move, are re-pinned each in its own commit right after that task's commit, old and new values and the cause recorded in the verification file. Any other pin change is a Stop. Later tasks compare against the re-pinned values, never the old ones.
- `Skirmish.create(with_match, second_controller, factions, map_path, ...)`: `map_path` is the 4th positional argument.
- Protocol goes to 2; old clients and relays refuse each other with "protocol mismatch". Host picks the map, the joiner follows (Join has no map picker). The host's `hello` carries an opaque `settings` JSON object; the relay stores it exactly as sent and copies it into `start` without reading it. This task puts `map` and `map_hash` in it. The relay adds a `seed` to `start`, outside the blob. Offline uses a local random seed.
- The joiner hashes its own map file and refuses with a clear message before the simulation exists. A `start` without `settings` is a protocol error, never a fallback to `skirmish.json`. The host sees the existing `left` before the first tick and shows "Opponent left before the start (different map files or version)". No new message type.
- Start spots: Zero Hour's rule (above); one code path offline and online; it takes the taken spots as input.
- Credits: a Credits button in the launcher (under the play buttons) opens a scrollable panel with a Close button, launcher only, not the Esc menu; content: one line per music track (title, author, licence, source URL), the announcer voice line, EA's map notice, Godot's licence (`Engine.get_license_text()` at runtime), Wargrid's GPL line. `game/audio/CREDITS.md` stays the single source and is packed into every export (`include_filter`).
- `game/scripts/net/headless_client.gd` takes `--map <name>`; `tools/run_netplay.sh` keeps `skirmish.json` by default.
- Typed GDScript, no faction branches in simulation code, no comments beyond one-line WHY. Edit with the Edit tool or asserted replacements only; BSD `sed`.
- Godot runs: one at a time; every suite, lint, benchmark, netplay and parity call with `timeout: 600000`, output to a file, read only summary lines. Before starting Godot, `pgrep -fl godot`; if a process the run did not start is present, do not kill it: run only the suite and lint, defer benchmarks and rendered checks, record it. Scratch Godot scripts live inside `game/` only while they run (untracked, deleted afterwards), `quit()` on every path; their sources are kept in `/Users/pdstuber/projects/wargrid-overnight-work/scratch/`.
- Windows allowed tonight; start them with `sh tools/run_game.sh --audio-driver Dummy <scene or --script>`.
- Relay changes pass `go test -race ./...` and `golangci-lint run` in `relay/`, `sh tools/run_conformance.sh`, and the affected `tools/run_netplay.sh` scenarios. GDScript changes pass `sh tools/run_lint.sh` and `sh tools/run_warnings.sh`; Python changes `sh tools/run_python_checks.sh`.
- A budget exceeded on the new maps is recorded with its numbers in the performance ledger and the run continues; never loosened.
- If bots never attack or never collect on Broken Crown or Ashfall: only the smallest fix inside `Skirmish.issue_opponents` and what it calls, test-first; anything bigger is a finding for M8.
- Game-design questions no decision answers are recorded for the morning in the verification file, not decided by the run.
- A derived constant in a new test may be corrected only with a derivation; behavioural expectations never.

## Execution rules for this run (override milestone-prompt where they differ)

- Branch `converted-maps` from `main` HEAD; the coordinator makes one local commit per green task (short message, never push, merge or deploy). Subagents never commit.
- Per task: one fresh implementer (model as routed) and then one fresh reviewer, Opus (high), that has not seen the implementation (the handoff overrides milestone-prompt's "No per-task reviewer subagents"). The reviewer reads the task section, the diff since the previous task commit and the verification rows, names for each new test the production change that would make it fail, and returns at most 15 lines: `APPROVE` or findings ranked critical / important / minor. Critical and important findings go back to a fresh implementer (test-first), then the same reviewer brief once more, at most once: if that re-review still has a critical or important finding, the task is `BLOCKED` (rule below). Minor findings are recorded.
- Implementers default to Sonnet (medium). Briefs are files: `/Users/pdstuber/projects/wargrid-overnight-work/briefs/task-N.md` plus one shared `briefs/shared.md` (AGENTS.md pointers, Global Constraints, units: 1 cell = 25 world units; map seats are 1-based). Each implementer does a RED run and pastes the failing assertion line into the verification file before writing production code.
- The coordinator posts the `Task | What | Status` table on every task state change.
- **No stop gate waits for the user overnight.** A real stop condition (an approved-design contract would have to change, an assertion would have to be weakened, a pinned outcome changes, the record disagrees with the tree) is written to the verification file as `BLOCKED` with options and a recommendation; the task saves its diff as `~/projects/wargrid-overnight-work/patches/<task>.patch` (`git diff --binary` plus untracked new files it created), restores only the paths it changed to the last commit (`git restore` for tracked paths, delete its own untracked files; never a repo-wide `git clean`), records `BLOCKED` and the patch path in the resume record, and the run continues with the next task that does not depend on it. A blocked diff never leaks into a later commit; the coordinator checks `git status --short` is clean before the next task. Exceeded budgets and bot failures follow the Global Constraints instead.
- After every task: `git status --short` against the reported paths; `pgrep -fl 'godot'` and close only what the run started.
- Scratch Godot scripts (Tasks 4, 9) extend `SceneTree` and run as `sh tools/run_game.sh --headless --script res://<name>.gd -- <args> > <log> 2>&1` (`run_game.sh` is `exec godot --path game "$@"`; windowed runs drop `--headless` and add `--audio-driver Dummy`), `timeout: 600000`; delete the copied `.gd` and any `.uid` Godot created afterwards.
- Choices this plan makes that the user did not decide (record them under "Findings for the morning" in Task 0's file, so the morning review sees them): the map dropdown on its own row although the design says "next to the faction dropdowns" (F5 caps that row at 520 px); offline Restart keeps the same starts; the relay checks that `settings` is a JSON object of at most 4096 bytes although "Decided" says it copies it "without reading it" (clients require a Dictionary and the 65,536-byte frame cap applies to `start`); Godot's "Complying with licenses" page may also ask for third-party notices (`Engine.get_copyright_info()`), not verified, "Decided" names only `get_license_text()`.

## Risks, in task order

1. Wire protocol 2 shapes and conformance (relay and client must agree byte-for-byte; an old client must still read "protocol mismatch") → Task 1.
2. Determinism of seeded start spots across clients and platforms → Task 2 (pinned outputs, confirmed by CI on Linux and Windows later).
3. Chosen starts reaching `Skirmish.create`, the start buildings, `issue_opponents` slots, rally and camera, without touching `skirmish.json` pins → Task 3.
4. Ashfall cost in a real match (navigation, snapshot) and bots at Ashfall distances → Task 4 (one measured row before any UI work).

## Interaction cases

No new simulation or lockstep command is added (`choose_faction` is unchanged), so no same-tick table is needed; reviewers check that this stays true. The AI rule this task touches is the start-spot rule (Task 2, spec-worded tests). If Task 8 changes bot code, its fix gets a spec-worded test and same-tick cases against the commands that fix issues.

## Review Focus

1. A tampered or broken host `settings` (`map` missing, not a string, `"../x"`, unknown id, `map_hash` missing): the joiner refuses with a readable reason and never reads a file outside `res://data/maps/` → Task 5, `MS3`.
2. A map file whose only difference is line endings (a Windows checkout with `core.autocrlf`; no `.gitattributes` in the repo): same hash, no false refusal → Task 5, `MS2`.
3. `settings` so large that `start` would pass the client's 65,536-byte frame cap: the relay refuses the `hello` instead of starting a match neither client can decode → Task 1, `settings_over_cap_refused`.
4. Offline Restart after a match and the static launcher choices: Restart keeps the same map and starts; tests that set `SkirmishMain` statics restore them → Task 5, `N12`.
5. A new client against the not-yet-redeployed protocol-1 relay: the launcher shows "protocol mismatch" in its status line, buttons usable again → Task 6, `N14`.

---

### Task 0: Branch, verification file, baseline

```text
Task: branch converted-maps exists at main HEAD; docs/reference/converted-maps-verification.md holds the resume record and one baseline row
Owns: docs/reference/converted-maps-verification.md (new)
Invariant: no source file changes
Boundary: a user Godot process running (pgrep): record it, skip the benchmark, mark the row partial
Red: n/a (baseline task)
Green: every baseline command run, results recorded with the tree
Stop: a baseline check fails on main HEAD: record it as the known red case, continue (later tasks compare against it)
```

Model: coordinator does the git step (`git switch -c converted-maps`); Haiku runs the commands and writes the file (decision-free).

- [ ] **Step 1:** Create the verification file starting with the milestone-prompt resume record block (filled in), then a `## Baseline` section, then `## Rows` (append-only), then `## Findings for the morning`.
- [ ] **Step 2:** Run, each with `timeout: 600000`, output to `/Users/pdstuber/projects/wargrid-overnight-work/logs/t0-<name>.log`, read only the summary lines: `sh tools/run_tests.sh` (`CASES … CHECKS … FAILURES …`, `TESTS PASSED`), `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/run_python_checks.sh` (exit 0), `sh tools/run_netplay.sh match` (`match terminal tick 8400`, `NETPLAY PASSED match`), `sh tools/run_conformance.sh` (`CONFORMANCE PASSED <n>`), in `relay/`: `go test -race ./...` and `golangci-lint run`. Then alone, with `uptime` before and after: `sh tools/run_benchmark.sh` (`BENCHMARK PASSED 2`, `COMBAT BENCHMARK PASSED 10`, `LOCKSTEP BENCHMARK PASSED 1`, exit code).
- [ ] **Step 3:** Record one row per command: tree (`git rev-parse --short HEAD`, clean), counts, exit, marker, load averages.

---

### Task 1: Relay and wire protocol 2 (`settings`, `seed`)

```text
Task: the relay stores the creator's hello.settings byte-exact and sends start {"type":"start","seats":[…],"delay":4,"seed":<n>,"settings":<bytes>}; protocol 2
Owns: relay/envelope.go, relay/room.go, relay/envelope_test.go, relay/race_test.go, relay/stall_test.go, relay/batch_test.go, relay/shutdown_test.go, protocol/vectors/*.json, protocol/conformance/conform.go, protocol/conformance/client.go, game/scripts/net/wire.gd, game/tests/test_wire.gd, the create hello in game/scripts/launcher.gd and game/scripts/net/headless_client.gd (one key)
Invariant: tick, ping, left, welcome, error bytes unchanged; existing conformance cases keep their meaning
Boundary: protocol 1 hello (no settings) gets "protocol mismatch", not "missing settings"; joiner settings ignored; settings at 4096 bytes accepted, 4097 refused
Red: conformance settings_echoed_byte_exact fails on the protocol-1 relay
Green: go test -race, golangci-lint, run_conformance.sh, suite (test_wire W3), run_netplay.sh match (still 8400)
Stop: an existing conformance case would have to change meaning (not just its hello helper or start bytes)
```

Model: Sonnet (medium). Depends on: Task 0.

**Wire shapes (decided):**

- `hello` (create): `{"type":"hello","protocol":2,"build":"<b>","match":"","settings":{…}}`. `settings` must be a JSON object of at most `maxSettingsBytes = 4096` bytes (its raw bytes). On join (`match` non-empty) `settings` may be absent; if present it is validated the same way and ignored.
- `start`: `{"type":"start","seats":[1,2],"delay":4,"seed":<n>,"settings":<creator's raw settings bytes>}`, keys in this order, `seed` an integer in `[0, 2147483647]` from `crypto/rand`, one seed per room, the same bytes to every seat.
- Errors: protocol other than 2 → `protocol mismatch` (checked first, before settings); create without settings → `{"type":"error","reason":"missing settings"}`; settings present but not an object or over the cap → `invalid message` (parse-level).

**Interfaces:**
- Produces (Go): `envelope.settings []byte` (nil when absent; exact bytes of the value); `room.settings []byte`; `const protocol = 2`; `const maxSettingsBytes = 4096`; `func randomSeed() int` (31-bit).
- Produces (GDScript, `wire.gd`): `PROTOCOL: int = 2`; `decode` requires `start.seed` (int) and `start.settings` (Dictionary, else fail `"invalid settings"`); a `hello` with `settings` present requires a Dictionary.

- [ ] **Step 1: Vectors (the spec).** Change `hello.json` to protocol 2 with `"settings":{"map":"dry_wells","map_hash":"<64 hex>"}`; change `start.json` to `{"type":"start","seats":[1,2],"delay":4,"seed":1234567,"settings":{"map":"dry_wells","map_hash":"<same>"}}`. Add `hello_join.json` (protocol 2, match `"ABC234"`, no settings, valid), `invalid_start_without_settings.json`, `invalid_start_without_seed.json`, `invalid_start_settings_not_object.json` (`"settings":[1]`), each `"valid": false`.
- [ ] **Step 2: Conformance cases (default profile).** `hello(match, build, protocol)` now adds `,"settings":{}` when `match == ""`; `room()` checks every seat's `start` against `^\{"type":"start","seats":\[<seat list as today>\],"delay":4,"seed":([0-9]+),"settings":\{\}\}$` and that all seats got identical bytes (replaces `startMsg`). Every existing `hello(…, 1)` call (`conform.go:52,59,141,153,167,171,176,182,191,236,251,261`) becomes protocol 2. The old client's hello in `protocol_and_build_mismatch` is a raw literal `{"type":"hello","protocol":1,"build":"abc","match":""}`, because the helper would add settings. Vector hashes: any 64 lowercase hex characters. New cases:
  - `settings_echoed_byte_exact`: host settings text `{ "map" : "ashfall", "n":1.50, "u":"ü€", "nested":{"a":[1, 2]} }` → both seats' `start` ends with `,"settings":{ "map" : "ashfall", "n":1.50, "u":"ü€", "nested":{"a":[1, 2]} }}`.
  - `joiner_settings_ignored`: joiner sends `"settings":{"map":"other"}` → `start` carries the host's.
  - `create_without_settings_refused`: protocol-2 create hello without settings → `{"type":"error","reason":"missing settings"}`, closed.
  - `settings_not_object_refused`: `"settings":"x"` and `"settings":[1]` → `errInvalid`, closed.
  - `settings_over_cap_refused`: settings of exactly 4096 bytes → welcome; 4097 → `errInvalid`, closed.
  - `seed_in_range_and_varies`: three rooms; each seed in `[0, 2147483647]`; not all three equal (false failure chance 2^-62).
  - `protocol_and_build_mismatch`: the refused protocol becomes 1 (an old client's hello, no settings) and 3, both `protocol mismatch`.
- [ ] **Step 3: Relay unit cases.** `TestParseRules` gains: create hello with a settings object valid and `e.settings` equal to the exact spaced bytes; `"settings":"x"`, `"settings":[1]` and 4097-byte settings → nil; join hello without settings valid.
- [ ] **Step 4: RED.** `sh tools/run_conformance.sh` against the unchanged relay (record the `FAIL settings_echoed_byte_exact` line) and `go test ./...` in `relay/` (record the first `TestParseRules` failure; `TestVectors` still passes, the parser does not check the protocol number).
- [ ] **Step 5: Relay.** Implement: `parseEnvelope` takes the raw value from a second decode into `map[string]json.RawMessage` (exact key match, unlike struct tags, which match case-insensitively); `registry.join` checks protocol, then `match == "" && settings == nil` → `missing settings`; `create` stores `h.settings`; `admit` builds `start` with `randomSeed()` and the stored bytes. `race_test.go` uses `protocol` and `settings: []byte("{}")`. `stall_test.go:48,51` and `batch_test.go:58,61` send protocol 2, and their create hello gains `,"settings":{}`. `shutdown_test.go:25` `seated()` sets `settings: []byte("{}")` when `match == ""`.
- [ ] **Step 6: Client wire.** `test_wire.gd` W3 already decodes every vector and int-checks `_INT_FIELDS`, so it covers `seed`. Change `wire.gd` as in Interfaces. So this task stays green alone, the create `hello` in `headless_client.gd` and `launcher.gd` gains `"settings": {}` (one key each); Task 6 replaces `{}` with real settings.
- [ ] **Step 7: GREEN.** In `relay/`: `go test -race ./...`, `golangci-lint run`; `sh tools/run_conformance.sh` (`CONFORMANCE PASSED <n>`, record n against the Task 0 count); suite; lint; warnings; `sh tools/run_netplay.sh match` (`match terminal tick 8400`).

---

### Task 2: Start spots by Zero Hour's rule

```text
Task: StartSpots.assign returns each slot's map seat by Zero Hour's live rule, deterministic for a seed
Owns: game/scripts/simulation/start_spots.gd (new), game/tests/test_start_spots.gd (new), game/tests/run_tests.gd (register suite)
Invariant: pure function; reads only map.starts[*].seat and .cell; no global RNG
Boundary: chosen spots present (no random draw at all); teammates; ties broken by lowest seat
Red: SS2 "slot 2 gets the start farthest from slot 1" fails on a stub returning [1, 2]
Green: test_start_spots + full suite
Stop: SS6's pinned list differs between the first macOS run and a later run on the same tree (non-determinism)
```

Model: Sonnet (medium). Depends on: Task 0. Independent of Task 1.

**Interfaces:**
- Produces: `static func assign(map: Dictionary, match_seed: int, teams: Array[int], chosen: Array[int]) -> Array[int]` in `start_spots.gd`. `teams[k]` is slot k's team (`<= 0` means none); `chosen[k]` is a map seat or `0` for random; result `[k]` is slot k's map seat (`int(map.starts[i].seat)`: JSON numbers parse as float, as in `map_data.gd:23,28`). Slots are placed in index order. Distance: `sqrt(float(d.x * d.x + d.y * d.y))` with `d: Vector2i` between start cells (integer square, float64 root: identical on every IEEE platform). RNG: `RandomNumberGenerator`, `seed = match_seed` (parameter not named `seed`: it would shadow the global `seed()` and trip `run_warnings.sh`), `randi_range(0, n - 1)` redrawn while taken. Team position is recorded only for slots placed by the loop, as Zero Hour does (`teamPosIdx`).

- [ ] **Step 1: Write the failing tests** (`test_start_spots.gd`, spec wording in the check messages):
  - `SS1 the first random slot gets a random start from the seed`: Ashfall, teams `[1, 2]`, chosen `[0, 0]`: over seeds 0..255 slot 1 takes all 8 seats; `assign` twice with the same seed returns the same array.
  - `SS2 each later one the free start with the largest summed straight-line distance to the taken ones`: for seeds 0..255, Ashfall slot 2 = `{1:5, 2:6, 3:7, 4:8, 5:1, 6:2, 7:3, 8:4}[slot 1]`; Broken Crown `{1:3, 2:4, 3:1, 4:2}`; Dry Wells `{1:2, 2:1}`.
  - `SS3 summed distance over all taken starts`: Ashfall, teams `[1, 2, 3]`, chosen `[1, 0, 0]` → `[1, 5, 7]` for any seed.
  - `SS4 teammates take the free start closest to their team`: Ashfall, teams `[1, 1, 2, 2]`, chosen `[0, 0, 0, 0]`, for seeds 0..255 the result equals the table row for its first entry: `1:[1,8,5,4] 2:[2,3,7,6] 3:[3,2,7,6] 4:[4,5,8,1] 5:[5,4,8,1] 6:[6,7,2,3] 7:[7,6,2,3] 8:[8,1,5,4]`.
  - `SS5 chosen spots are taken first`: Ashfall, teams `[1, 2]`, chosen `[0, 3]` → `[7, 3]` for every seed (no random draw once a spot is taken).
  - `SS6 seeded start spots are pinned across platforms`: Ashfall 1v1 seeds 0..15 joined as `"a-b,…"` equals a literal. The literal is derived by the first run on macOS and recorded with that derivation (tree, platform) in the verification file; CI on Linux and Windows later confirms it (exit-gate item for the user).
  - `SS7 ties go to the lowest seat, and a chosen spot is not its team's position`: a synthetic map dictionary with starts `1:(0,0) 2:(10,0) 3:(10,10) 4:(0,10)` (expected values derived by hand from Zero Hour's rule by the plan reviewer): teams `[1, 1]`, chosen `[0, 0]` → slot 2 = `{1:2, 2:1, 3:2, 4:1}[slot 1]` for seeds 0..63; teams `[0, 0, 0]`, chosen `[1, 0, 0]` → `[1, 3, 2]` (seats 2 and 4 tie at summed 20); teams `[1, 1]`, chosen `[1, 0]` → `[1, 3]` (`GameLogic.cpp:957-959`; pins the M9 open question).
- [ ] **Step 2: RED** with a stub `assign` returning `[1, 2]`; record the `SS2` failure line.
- [ ] **Step 3: Implement** `assign`.
- [ ] **Step 4: GREEN:** suite, lint, warnings. Run the suite twice; SS6 must match both times.

---

### Task 3: Chosen starts become seats 1 and 2

```text
Task: Skirmish.create(..., map_path, starts) plays seat k from map seat starts[k-1]; without starts nothing changes
Owns: game/scripts/simulation/skirmish.gd (create), game/scripts/simulation/map_data.gd (with_starts), game/tests/test_map.gd, game/tests/test_skirmish.gd
Invariant: Skirmish.create(…, MAP_PATH) and create(…, MAP_PATH, []) return the same state hash and reuse the cached default map; every existing pin and trace unchanged
Boundary: map seat 5 → player 1 on Ashfall; start building, start unit, bot slots, rally and the camera's start cell all follow; original map dictionary not mutated
Red: SK-S1 "player 1's start building is on Ashfall seat 5" fails (lands on seat 1)
Green: test_map, test_skirmish, full suite, run_netplay.sh match (8400)
Stop: any existing pin or trace changes
```

Model: Sonnet (medium). Depends on: Task 2 (uses `assign` only in a test; can run right after Task 2 commits).

**Interfaces:**
- Produces: `static func with_starts(map: Dictionary, seats: Array[int]) -> Dictionary` in `map_data.gd`: a shallow copy whose `starts` holds, for k in order, a duplicate of the start with `seat == seats[k]`, renumbered `seat = k + 1`; every other key is the same object. A seat not in the map → `{}` with no `push_error` (the suite fails on any `ERROR:` line, `tools/run_tests.sh:39`); `Skirmish.create` calls `push_error` when `with_starts` returns `{}`, and no test takes that path.
- Produces: `static func create(with_match: bool = true, second_controller: String = "ai", factions: Dictionary = Registry.Factions.DEFAULT_SKIRMISH, map_path: String = MAP_PATH, starts: Array[int] = []) -> Simulation`: loads as today, then `with_starts` when `starts` is not empty.
- Consumes: `StartSpots.assign` (Task 2) in `SK-S4` only.

- [ ] **Step 1: Failing tests.**
  - `MP8 with_starts renumbers the chosen starts` (`test_map.gd`; MP6 and MP7 are taken): Ashfall, `[5, 1]` → `starts.size() == 2`, `starts[0].seat == 1` with seat 5's `cell` and `slots`, `starts[1].seat == 2` with seat 1's; the loaded map still has 8 starts with seat 5 at index 4; `cells` is the same object; `with_starts(dry_wells, [1, 9])` returns `{}`.
  - `SK-S1 a chosen start becomes the player's base` (`test_skirmish.gd`): `Skirmish.create(true, "ai", {1: "usa", 2: "china"}, "res://data/maps/ashfall.json", [5, 1])`: player 1's start unit is at Ashfall seat 5's `cell` + (0.5, 0.5) and its start building's origin is seat 5's `slots[<start building's slot>]` (`setup_seat`, `simulation.gd:119-124`; read both from `MapData.load`, not hard-coded); player 2 likewise on seat 1; `MapData.start_cell(sim.map_data(), 1)` is seat 5's cell.
  - `SK-S2 without starts the test map is untouched`: `StateHash.digest(create(true,"ai",DEFAULT,MAP_PATH).snapshot()) == digest(create(true,"ai",DEFAULT,MAP_PATH,[]).snapshot())` and `is_same(create(…).map_data(), create(…, []).map_data())`.
  - `SK-S3 the bot builds on its own chosen start`: the SK-S1 sim, `Skirmish.issue_opponents(sim, [1, 2])` + `sim.step()` until tick 900: player 1 has a building of `build_order("usa")[0]` at `MapData.slot(ashfall, 5, that kind)` and player 2 has `build_order("china")[0]` at `MapData.slot(ashfall, 1, that kind)`.
  - `SK-S4 a seeded 1v1 on Broken Crown is diagonal`: `assign(broken_crown, 7, [1, 2], [0, 0])` passed to `create` → the two start cells are 97.8 cells apart (±0.1).
- [ ] **Step 2: RED**; record the SK-S1 line.
- [ ] **Step 3: Implement** `with_starts` and the `create` parameter.
- [ ] **Step 4: GREEN:** suite, lint, warnings, `sh tools/run_netplay.sh match` (`match terminal tick 8400`).

---

### Task 3b: Bot collectors per supply center (USA 2, China 3, FRC 5)

User decision 2026-11-08 from the friend's playtest (evidence: `wargrid-overnight-work/questions/playtest-repair-bots.md` section B): per completed supply center, counting the depot's free collector, the same at every difficulty: **USA 2, China 3, FRC 5** (FRC down from `LABORERS` 7). Reason (user): what human players do; per-collector inflow already differs by data (`usa_collector` 8 boxes but unload 213 ticks; `china_collector` 4 boxes, speed 1.6; `frc_builder` 1 box, speed 1.0). M8 revisits this (stronger difficulty levels make increasingly optimal economic choices; Task 10 records it). Background only: Zero Hour's `ResourceGatherers` (`data\ini\default\aidata.ini:68-70`, `:96-98`, retail `INIZH.big`) and the depot "freebie" (`AIPlayer.cpp:190-215`). Today `units_for` has no supply-center entry (`factions.gd:12`, `:19`), so `Skirmish._produce` (`skirmish.gd:119-139`) never builds a collector and a USA or China bot keeps only the free one.

**Pins this change is expected to move:** `run_netplay.sh match` terminal tick 8400 (seat 2 runs `Skirmish.issue_opponent` as USA on `skirmish.json`, `headless_client.gd:141`), the team match `units_peak=160` (`run_team_match.sh:13`) and `FINAL_DIGEST` / `TEAM_CORE_SERIES` (`test_team_match.gd:13,15`), possibly `skirmish.json` bot match terminal ticks or winners in `test_skirmish*.gd` and the replay traces. **Pre-approved by the user (2026-11-08):** re-pin only pins this collector change moves; record each old and new value with the reason in the verification file; the re-pin is its own commit right after Task 3b's commit, so either can be reverted. Cause check: the old value is the recorded run of the same command on the Task 3 commit (Task 3b touches only its Owns files); only if a value is missing, run it on `git archive <task-3 sha>` extracted to scratch. Never revert in place.

```text
Task: a skirmish bot keeps <faction's per-depot count> x <its completed supply centers> collecting units (USA 2, China 3, FRC 5, the depot's free one included)
Owns: game/scripts/simulation/skirmish.gd (_produce; LABORERS removed), game/scripts/simulation/definitions/factions.gd (one data key per faction), game/tests/test_skirmish.gd (new tests; Fb1/Fb2 expectations move from 7 to 5 per the user's decision), then, in the re-pin commit only, the pins that moved
Invariant: no faction branch: the count is faction data and the rule keys on "a completed, idle building that receives supply and produces a collecting kind" (FRC's frc_builder qualifies through frc_supply_center, as today); the builder-replacement rule (replace_builder) unchanged; the rebuild laborer still not counted (Fb2)
Boundary: a collector dies → replaced; two supply centers → twice the count; credits short → no order that tick; the free collector counts; FRC's builder counts toward its 5 (as it counted toward 7)
Red: SK-C1 "a USA bot runs two collectors per supply center" fails (stays at one)
Green: test_skirmish, full suite, run_netplay.sh match, run_team_match.sh, replay traces; moved pins re-pinned in the follow-up commit with old/new values
Stop: a pin moves for any reason other than this collector change (record old/new, no re-pin)
```

Model: Sonnet (medium). Depends on: Task 3. Independent of Task 3c.

**Interfaces:**
- Produces: faction key `"bot_collectors_per_supply_center"` in `factions.gd`: `usa` 2, `china` 3, `frc` 5. In `_produce`, for a completed, idle building whose row `receives_supply` and `produces` a kind that `Registry.collects`: order that kind while `owned.count(kind) < count * <completed receives_supply buildings of the player>`. `LABORERS` and its comment go; tests that used it read the faction value.

- [ ] **Step 1: Failing tests** (`test_skirmish.gd`, `skirmish.json` fixtures, bot's point of view):
  - `SK-C1 a USA bot runs two collectors per supply center`: `Skirmish.create(true, "ai", {1: "usa", 2: "usa"})`, `sim._players[2].credits = 1000000` before the loop (as `headless_client.gd:144` writes credits), `issue_opponent(sim, 2)` + `step()` until tick 3600: player 2 owns exactly 2 `usa_collector`.
  - `SK-C2 a China bot runs three`: as SK-C1 with `china`, exactly 3 `china_collector`.
  - `SK-C3 an FRC bot runs five laborers per supply cache`: Fb1 now expects 5 (`frc_builder`, builder included, rebuild laborer excluded); Fb2's "keeps" and "replaced up to" checks use 5.
  - `SK-C4 a lost collector is replaced`: after SK-C1, remove one collector (`remove_object`); within 900 ticks the count is 2 again.
- [ ] **Step 2: RED**; record the SK-C1 line.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: GREEN:** suite, lint, warnings; `sh tools/run_netplay.sh match`; `sh tools/run_team_match.sh`; replay trace comparison as the suite does it. Record every moved pin (old, new, cause check). Coordinator: commit Task 3b, then the re-pin commit.

---

### Task 3c: Converter puts the supply center slot near supplies

User decision 2026-11-08 (same evidence). Today `_find_slot` (`convert.py:268-285`) places the 3x3 supply center 2-3 cells from the start, 15.9-26.5 cells from the nearest source on every start of the three maps. This is a stopgap (M8 moves the choice into the bot; Task 10 records it in the blueprint).

**Pins this change moves (certain, plan review 2):** the team match runs six bots on Ashfall slots (`team_match.gd:7`), pinned by `test_team_match.gd:13,15` (`FINAL_DIGEST`, `TEAM_CORE_SERIES`) and `run_team_match.sh:13` (`units_peak`); every Ashfall `supply_center` slot moves (seat 1 [23,128] → about [9,139]) and later slots shift. **Pre-approved by the user (2026-11-08):** re-pin only pins this slot move changes (expected: those three; anything else only if proven caused by the slot move by running the check on `git archive` of the Task 3b re-pin commit, i.e. without the converter change); old and new values recorded; the re-pin is its own commit right after Task 3c's commit. Also exposed: the Ashfall movement layout (`movement_workload.gd:29-40`, 300 units at x 4-23, y 107-121, each spawn asserted) and `test_map.gd`, `test_supply.gd:646`.

```text
Task: the supply_center slot becomes the open, legal 3x3 site nearest to the start's nearest full dock (400 boxes; small piles ignored), searched within MAX_RING 12 of the start; other slots keep today's order and rule
Owns: tools/zh_map/convert.py (place/_find_slot), tools/zh_map/test_zh_map.py, game/data/maps/dry_wells.json, broken_crown.json, ashfall.json (regenerated), docs/reference/more-maps.md (why the byte-identical fact no longer holds)
Invariant: skirmish.json untouched (not converter output); legality as today (inside EDGE_MARGIN, open cells, 1-cell grown ring open and clear of sources and earlier slots); no other converter output changes except slot positions
Boundary: ties between equally near sites → the first in today's ring scan order; small piles (`delete_when_empty`, 50 boxes) are never the target (user, 2026-11-08), so Dry Wells seat 1 aims at its nearest 400-box dock
Red: test_supply_center_slot_nearest_supply fails (slot at ring 2)
Green: converter tests, python checks, suite, run_team_match.sh; moved team-match pins re-pinned in the follow-up commit with old/new values
Stop: a pin moves for a reason other than the slot move (record old/new, no re-pin); a start has no legal site within 12 (a design question: record it, no fallback)
```

Model: Sonnet (medium). Depends on: Task 0 in code; runs after Task 3b's re-pin commit so each re-pin has one cause. If committed, Task 4 measures the new maps; if `BLOCKED`, Task 4 records that it measured the old ones.

**Interfaces:**
- Produces: `_supply_site(grid, size, taken, start, sources) -> tuple[list[int], set] | tuple[None, None]` in `convert.py`: the target is the source without `delete_when_empty` whose centre (`origin + footprint / 2`) is closest (Euclidean, cells) to the start cell; among all origins `_find_slot` would accept within rings 2..MAX_RING, return the one whose 3x3 centre (`origin + 1.5`) is closest to that source centre. `place` uses it for `supply_center` only.

- [ ] **Step 1: Failing tests** (`test_zh_map.py`):
  - `test_supply_center_slot_nearest_supply`: synthetic `raw_map(80, 30, starts=[(10, 15), (70, 15)], sources=[(22, 15), (58, 15)])` → seat 1's `supply_center == [16, 14]` (centre 4.5 cells from the dock centre (22, 15.5); a 4x5 dock with the 1-cell grown ring allows no closer 3x3 centre) and `power_plant == [12, 13]` (today's rule; today's converter puts `supply_center` at `[12, 16]`, so RED holds). Values simulated by plan review 2.
  - `test_shipped_supply_centers_moved_closer`: loads the three shipped JSON maps and asserts, per start, slot-centre to nearest-full-dock-centre distance strictly below the before value from `wargrid-overnight-work/supply_distance.txt`: Dry Wells 28.3 (seat 1's nearest 400-box dock; its 25.6 was a pile), 19.5; Broken Crown 22.4, 18.1, 15.9, 19.8; Ashfall 21.5, 22.4, 25.1, 18.0, 20.4, 21.1, 23.7, 26.5 (seats in order). Record the after values next to the before values in `more-maps.md`.
  - `test_slots_ordered_and_apart` keeps passing with its footprints still disjoint.
- [ ] **Step 2: RED**; record the first failing line.
- [ ] **Step 3: Implement**, then regenerate the three maps from `~/projects/CnC_Modding_Support` at `3aad8e4` (as in `game/data/maps/NOTICE.md`), `R="$HOME/projects/CnC_Modding_Support/Zero Hour/Maps/official"`: `python3 tools/zh_map/convert.py "$R/Twilight Flame/Twilight Flame.map" game/data/maps/ashfall.json Ashfall`, `… "$R/Tournament Desert/Tournament Desert.map" game/data/maps/dry_wells.json "Dry Wells"`, `… "$R/Fallen Empire/Fallen Empire.map" game/data/maps/broken_crown.json "Broken Crown"`; check that `skirmish.json` is unchanged (`git diff --stat`).
- [ ] **Step 4: GREEN:** `sh tools/run_python_checks.sh`, converter tests, suite, lint; `sh tools/run_team_match.sh`; the Ashfall movement layout still spawns all 300 seat-1 units: a scratch headless script (execution rules) calls `MovementWorkload.create("ashfall")` and counts them (no suite or benchmark test builds that layout). Moved team-match pins → re-pin commit; any other pin change → Stop.

---

### Task 4: Ashfall 1v1 spike — cost and bot behaviour, one row

```text
Task: measure one headless bot-vs-bot match on Ashfall from seeded starts: per-tick cost of the scene's work and whether both bots build, collect and attack
Owns: scratch script only (source kept in wargrid-overnight-work/scratch/bot_match.gd, copied to game/scratch_bot_match.gd for the run, deleted after); docs/reference/performance.md (one ledger row); verification file
Invariant: no tracked source change
Boundary: cap 45,000 ticks; first time one row end to end (Long sweeps rule)
Red: n/a (measurement)
Green: the row recorded with tree, host load and every number below
Stop: none overnight; an exceeded budget is recorded and the run continues
```

Model: Sonnet (medium). Depends on: Task 3; runs after Tasks 3b (and its re-pin commit) and 3c are committed or `BLOCKED` (record which tree it measured).

**Scratch script contract** (reused by Task 8; run as in the execution rules: `sh tools/run_game.sh --headless --script res://scratch_bot_match.gd -- --map ashfall --factions usa,china --seed 1 --cap 45000 > <log> 2>&1`): args `--map <id> --factions <a>,<b> --seed <n> --cap <ticks>`; creates `Skirmish.create(true, "ai", {1: a, 2: b}, "res://data/maps/<id>.json", starts)` with `starts = StartSpots.assign(map, seed, [1, 2], [0, 0])` (for `skirmish` pass `[]`); per tick: `Skirmish.issue_opponents(sim, [1, 2])`, `sim.step()`, `sim.snapshot()` (what the scene does each tick), timed with `Time.get_ticks_usec()` around those three; uses `Profiler` zones the way `game/benchmarks/run_team_match.gd` does. Prints one line: `BOT MATCH map=… factions=… seed=… starts=a,b end_tick=… winner=… first_build=[t1,t2] first_collect=[t1,t2] first_enemy_damage=[t1,t2] tick_ms p50/p95/p99/max=… zones: step.service_paths=… snapshot=… opponent.decide=…`, then `quit()`. Definitions: build = first tick a completed building other than the start building exists for the seat; collect = first tick a unit of the seat has `collection.phase == "loading"`; attack = first tick a building of the other seat has `hp < max_hp`. Sampled every 30 ticks.

- [ ] **Step 1:** Write the scratch script; run Ashfall `usa,china`, seed 1, cap 45,000, alone, `uptime` before and after. Record wall time (for Task 8's sweep estimate).
- [ ] **Step 2:** Ledger row in `docs/reference/performance.md` History: tick p50/p95/p99/max against the team-match budget (p95 1.82 / p99 3.64 ms) and the snapshot plumbing row (0.91 ms); label each passes / **exceeded**; nothing loosened.
- [ ] **Step 3:** If a seat never builds, collects or attacks: record it; Task 8 owns any fix.

---

### Task 5: Match settings and the launcher's map choice offline

```text
Task: the launcher's Map dropdown picks Dry Wells, Broken Crown or Ashfall for Play offline, with seeded Zero Hour start spots; MatchSettings builds and checks settings
Owns: game/scripts/match_settings.gd (new), game/scripts/launcher.gd, game/scenes/launcher.tscn, game/scripts/skirmish_main.gd (static starts), game/tests/test_match_settings.gd (new), game/tests/test_online_scene.gd, game/tests/run_tests.gd
Invariant: opening skirmish.tscn without the launcher still plays skirmish.json on seats 1/2 (N7's first check)
Boundary: tampered settings; CRLF map file; Restart keeps map and starts
Red: MS3 "an unknown map id is refused" fails (no MatchSettings)
Green: test_match_settings, test_online_scene (N5, F5, N11, N12), full suite
Stop: Map fits neither on its own row nor as the third control in FactionRow at 1280x720
```

Layout fallback (not a stop): own row first; if N5 or F5 fails at 1280x720, put `Map` as the third control in `FactionRow` (the design's "next to the faction dropdowns") and record it.

Model: Sonnet (medium). Depends on: Task 3.

**Interfaces:**
- Produces, `match_settings.gd` (static, no state):
  - `const PLAY_MAPS := {"dry_wells": "Dry Wells", "broken_crown": "Broken Crown", "ashfall": "Ashfall"}` (dropdown order, default `dry_wells`).
  - `const TEST_MAP := "skirmish"`.
  - `static func map_path(id: String) -> String` → `"res://data/maps/%s.json" % id`.
  - `static func map_hash(path: String) -> String` → SHA-256 hex of the file text with `"\r"` removed (`FileAccess.get_file_as_string(path).replace("\r", "").sha256_text()`; one-line WHY comment: no `.gitattributes`, so a CRLF checkout must not refuse).
  - `static func for_map(id: String) -> Dictionary` → `{"map": id, "map_hash": map_hash(map_path(id))}`.
  - `static func refusal(settings: Dictionary) -> String` → `""` or exactly `"The host's map is not in your build"` (map not a String, not matching `^[a-z0-9_]{1,32}$`, or `FileAccess.file_exists` false, checked before any read: reading a missing path prints `ERROR:` and fails the suite) or `"Your copy of %s differs from the host's" % PLAY_MAPS.get(id, id)` (`map_hash` not a String or different).
  - `static func starts(id: String, match_seed: int) -> Array[int]` → `[]` for `TEST_MAP` (WHY comment: the test map keeps seat N on start N so pinned traces hold), else `StartSpots.assign(MapData.load(map_path(id)), match_seed, [1, 2], [0, 0])`.
- Produces: `static var starts: Array[int] = []` in `skirmish_main.gd`, passed as the 5th argument in `_create_simulation` (Task 6 does the same in `online_main.gd`, which overrides it).
- Every test that calls `_offline_setup`, `_start` or sets `SkirmishMain` statics saves and restores **both** `map_path` and `starts` (a leaked `starts` with the restored `skirmish.json` breaks later scene tests, and shard order varies).
- Produces, launcher: node `Center/Box/Map` (`OptionButton`, own row directly under `FactionRow`, tooltip "Map for Play offline and Create match; Join plays the host's map"); `func _map_id() -> String`; `_play_offline` split into `func _offline_setup() -> void` (sets `factions`, `map_path`, `starts = MatchSettings.starts(id, randi())`) plus the scene change; `PLAY_MAP_PATH` removed; `Map` added to `_set_busy`.

- [ ] **Step 1: Failing tests.**
  - `test_match_settings.gd`: `MS1 display names match the map files` (each `PLAY_MAPS` value equals `MapData.load(map_path(id)).name`); `MS2 line endings do not change the hash` (write a scratch copy of `dry_wells.json` with `\r\n` to `user://`, `map_hash` equal to the original's; delete it); `MS3 bad host settings are refused, never read outside data/maps` (`{}`, `{"map": 5}`, `{"map": "../project"}`, `{"map": "nope"}` → "The host's map is not in your build"; `{"map": "ashfall"}` and `{"map": "ashfall", "map_hash": "0"}` → "Your copy of Ashfall differs from the host's"; `for_map(id)` → `""` for all three ids and `skirmish`); `MS4 the test map keeps its seats` (`starts("skirmish", 9) == []`); `MS5 a play map gets seeded starts` (`starts("ashfall", s)` equals `StartSpots.assign(...)` for s in 0..3, size 2).
  - `test_online_scene.gd`: add `Map` to N5's path list and to F5's "row clear of" list; `N11 Play offline uses the chosen map`: for each id, select it, `_offline_setup()`: `SkirmishMain.map_path == map_path(id)`, `SkirmishMain.starts.size() == 2`, on Ashfall the pair is diagonal (Task 2 table); restore statics. `N12 Restart keeps the map and the starts`: statics Broken Crown `[3, 1]`, instantiate `skirmish.tscn`, `_restart()`: `MapData.start_cell(main.simulation.map_data(), 1)` is Broken Crown seat 3's cell and the camera is on it; restore statics.
- [ ] **Step 2: RED**; record the MS3 line.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: GREEN:** suite, lint, warnings.

---

### Task 6: Online map agreement end to end

```text
Task: Create match sends the chosen map's settings; both clients check start.settings, refuse a mismatch before the simulation exists, and play the same map on the same seeded starts
Owns: game/scripts/launcher.gd, game/scripts/online_main.gd, game/scripts/net/lockstep.gd (left_before_start), game/scripts/net/headless_client.gd, tools/run_netplay.sh, .github/workflows/ci.yml (netplay scenario list only), game/tests/test_online_scene.gd, game/tests/test_lockstep.gd
Invariant: run_netplay.sh match/kill/stall/silent/spike/perturb/version/relay-down/relay-term unchanged in meaning; match still pins the terminal tick pinned in `tools/run_netplay.sh` after Task 3b's re-pin commit (value in the verification file)
Boundary: joiner refusal → host notice; start without settings; protocol mismatch from an old relay
Red: N13 "the joiner refuses a different map before the simulation exists" fails (the scene is created)
Green: test_online_scene, test_lockstep, suite, run_netplay.sh match maps map-mismatch kill version, run_conformance.sh
Stop: an existing netplay pin changes (match terminal tick, scenario outcome)
```

Model: Sonnet (medium). Depends on: Tasks 1 and 5.

**Interfaces:**
- Consumes: `MatchSettings.for_map`, `refusal`, `starts`, `map_path` (Task 5); `start.seed`, `start.settings` (Task 1).
- Produces: `func left_before_start() -> bool` in `lockstep.gd` (`_left_seat != 0 and _left_after < _delay`); `online_main.notice()` returns `"Opponent left before the start (different map files or version)"` for `ended_left` when `left_before_start()`, else today's text.
- `online_main._create_simulation` returns `Skirmish.create(true, "human", {}, map_path, starts)` (it overrides `skirmish_main`'s, so without this every online match plays map seats 1 and 2).
- Launcher: create `hello` carries `"settings": MatchSettings.for_map(_map_id())` (join: no settings). `func _start(message: Dictionary) -> bool`, and `_handle` returns `_start(message)` for `"start"` (`_fail` nulls `_transport`, so `_process` must stop after a refusal). `refusal(message.settings)` non-empty → `_transport.close()`, `_fail(reason)`, `return false`. Otherwise `SkirmishMain.map_path = map_path(id)`, `SkirmishMain.starts = starts(id, message.seed)`, then today's scene start, `return true`. A decode failure in `_handle` calls `_transport.close()` before `_fail`. `_process` returns at once when `_transport == null`. N7, N13 and N15 save and restore both `SkirmishMain.map_path` and `SkirmishMain.starts`.
- Headless client: `--map <id>` (default `MatchSettings.TEST_MAP`) for the create `hello`; `_start` runs the same `refusal` → `_finish("ended_settings", reason)`; else `Skirmish.create(true, "human", {}, map_path(id), starts(id, message.seed))` and prints `NETCLIENT MAP <id> STARTS <a>,<b>` (`-` for `[]`). Test hook `--perturb-map-hash` (joiner only): duplicate the received `settings`, append `"x"` to its `map_hash`, then call `refusal` (same effect as a different local file).
- `run_netplay.sh` new scenarios: `maps` (starts its two clients with `start_client` directly, since `start_pair` hard-codes `--seat-script human` for s1, `run_netplay.sh:47`; both seats `--seat-script opponent`, host `--map ashfall`, both `--stop-at-tick 900`; both `END stopped`, identical `NETCLIENT MAP` lines with a diagonal Ashfall pair, `same_hashes s1 s2`); `map-mismatch` (host `--map ashfall`, joiner `--perturb-map-hash`; joiner `END ended_settings … REASON Your copy of Ashfall differs from the host's`; host `END ended_left TICK 4`). `ci.yml` netplay loop becomes `match perturb relay-down maps map-mismatch`.

- [ ] **Step 1: Failing tests.**
  - `N7` (existing) changes to pass `{"type": "start", "seats": [1, 2], "delay": 4, "seed": 3, "settings": MatchSettings.for_map("dry_wells")}` and keeps its camera check; rename its message "N7 seat %d plays the host's map".
  - `N13 the joiner refuses a different map before the simulation exists`: `launcher._handle(Wire.encode(start))` with `settings` `{"map": "ashfall", "map_hash": "0"}` returns `false`; no online scene in the tree, `FakeTransport.close_calls == 1`, status text is "Your copy of Ashfall differs from the host's", `Create` enabled again; one `_process(0.0)` after it raises no error (Interfaces: `_process` returns at once when `_transport == null`).
  - `N14 a protocol mismatch from an old relay is shown`: `_handle('{"type":"error","reason":"protocol mismatch"}')` → status "protocol mismatch", buttons enabled.
  - `N15 both seats play the host's map on the same seeded starts`: `_start` for seat 1 and seat 2 with Ashfall settings and seed 11: in both sims `[start_cell(map, 1), start_cell(map, 2)]` equals the Ashfall cells of the seats in `MatchSettings.starts("ashfall", 11)`, that pair is in the SS2 diagonal table, and seat k's camera is on `start_cell(map, k)`.
  - `N16 the host is told the opponent left before the start` (online scene, seat 1): `lockstep.receive('{"type":"left","seat":2,"after_tick":3}')`, run frames → status contains the exact notice and `_layout_ok(runner, main, "left before start")` holds; with `after_tick` 40 after 40 peer ticks → "Player 2 disconnected".
  - `L14 left before the start` in `test_lockstep.gd`: `left_before_start()` true for `after_tick` 3 with delay 4, false for 4, false with no `left`.
- [ ] **Step 2: RED**; record the N13 line.
- [ ] **Step 3: Implement**, then the two netplay scenarios.
- [ ] **Step 4: GREEN:** suite, lint, warnings; `sh tools/run_netplay.sh` for `match` (the terminal tick pinned in `tools/run_netplay.sh` after Task 3b's re-pin commit (value in the verification file)), `maps`, `map-mismatch`, `kill`, `version`, one at a time; `sh tools/run_conformance.sh`.

---

### Task 6b: Cancel and Copy while waiting for player 2

User decision 2026-11-08 from a friend's playtest ([design answers](../../reference/design-answers-2026-11-08.md), "Friend's playtest"): no way out after "Create match", and the code should be copyable.

```text
Task: while the host waits for player 2, a Cancel button closes the connection and restores the normal launcher, and a Copy button puts the match code on the clipboard
Owns: game/scripts/launcher.gd, game/scenes/launcher.tscn, game/tests/test_online_scene.gd
Invariant: Join, Create and Play offline behave as before when not waiting; the Join field's paste is unchanged
Boundary: Cancel before welcome (Connecting…) is not offered; start arriving after Cancel is never handled (transport gone)
Red: N17 "Cancel restores the launcher" fails (no Cancel button)
Green: test_online_scene (N5, N17, N18), suite
Stop: none beyond the run's rules
```

Model: Sonnet (medium). Depends on: Task 6 (same launcher flow).

**Interfaces:**
- Node `Center/Box/WaitRow` (`HBoxContainer`, hidden) directly above `Status`, holding `Copy` (`Button`, "Copy code") and `Cancel` (`Button`, "Cancel"). Shown only on `welcome` with seat 1; hidden by `_fail` and on start. Neither button is in `_set_busy`.
- `var _code: String` set on `welcome`. `Copy` → `DisplayServer.clipboard_set(_code)`. `Cancel` → `_transport.close()`, `_fail("Match cancelled")` (buttons re-enabled, `set_process(false)`).
- Unverified: browser clipboard (`clipboard_set` on the web export needs a user gesture and a secure context; not checked until a web run). Recorded for the playtest.

- [ ] **Step 1: Failing tests** (`test_online_scene.gd`):
  - `N17 Cancel restores the launcher`: set `launcher._transport = FakeTransport.new()`, call `launcher._set_busy(true)` and `launcher.set_process(true)` (no frame awaited in between), then `_handle('{"type":"welcome","seat":1,"match":"ABC234"}')` → `WaitRow` visible, `Offline` and `Create` disabled; press `Cancel` → `close_calls == 1`, `WaitRow` hidden, `Offline`, `Create`, `Join`, `Map` and the faction selectors enabled, status "Match cancelled", `is_processing() == false`.
  - `N18 Copy puts the match code on the clipboard`: after the same welcome, press `Copy` → `DisplayServer.clipboard_get() == "ABC234"` (if the headless display server has no clipboard and returns "", assert the call path instead through `_code == "ABC234"` and record that the clipboard itself is unverified headless). Seat 2's welcome leaves `WaitRow` hidden.
  - N5: `WaitRow/Copy` and `WaitRow/Cancel` added to the inside-viewport and no-overlap lists with `WaitRow` shown, at 1280x720 and 1920x1080.
- [ ] **Step 2: RED**; record the N17 line.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: GREEN:** suite, lint, warnings.

---

### Task 7: Credits panel

```text
Task: a Credits button under the play buttons opens a scrollable panel with every music line, the voice line, EA's map notice, Godot's licence and Wargrid's GPL line, read at runtime from packed files
Owns: game/scripts/presentation/credits.gd (new), game/scripts/launcher.gd, game/scenes/launcher.tscn, game/export_presets.cfg (include_filter only), game/tests/test_credits.gd (new), game/tests/test_online_scene.gd (layout), game/tests/test_map.gd (MP5 sibling), game/tests/run_tests.gd
Invariant: CREDITS.md stays the only place music credits are written (tools/test_audio_assets.py unchanged and green); not in the Esc menu
Boundary: a new music row in CREDITS.md appears without code changes; 1280x720 and 1920x1080
Red: CR1 "every CREDITS.md music row is in the panel" fails (no credits.gd)
Green: test_credits, test_online_scene (N5, N10), test_map (MP9), suite, python checks
Stop: an export cannot carry audio/CREDITS.md through include_filter; or the Credits button fits neither under JoinRow nor in JoinRow at 1280x720
```

Layout fallback (not a stop): Credits on its own row under `JoinRow` first; if N5 fails at 1280x720, put it as the last control in `JoinRow` and record it.

Model: Sonnet (medium). Depends on: Task 5; runs after Task 6b (same scene file).

**Interfaces:**
- Produces: `static func text(credits_md: String, notice_md: String, license_text: String) -> String` in `credits.gd`, sections in this order:
  1. `Wargrid © 2026 Philipp Stuber. Free software under the GNU GPL v3 or later, with no warranty. License and source: github.com/pdstuber/wargrid`
  2. `Music`: one line per `music/` table row: `"<title>" by <author> (<source URL>), licensed <licence> (<licence URL>)`, then `; <attribution notice>` when not `-`, then `; changes: <changes>` with backticks stripped (CC BY 4.0 §3(a)(1)(B) asks to indicate modifications); then the fenced `text` block under "Attribution text requested by Kevin MacLeod" verbatim (his requested format).
  3. `Voice: Piper en_US-kristin-medium (public-domain LibriVox recordings), <source URL of the first voice/ row>; announcer lines vocoded by Wargrid`
  4. `Maps`: `notice_md` verbatim.
  5. `Godot Engine`: `license_text` verbatim.
- Launcher: node `Center/Box/Credits` (`Button`, text "Credits", directly under `JoinRow`); root-level `CreditsPanel` (`PanelContainer`, full rect, margins 32, hidden) > `Box` (`VBoxContainer`) > `Text` (`RichTextLabel`, `bbcode_enabled = false`, `selection_enabled = true`, scrolls itself, expand vertically) + `Close` (`Button`); `func _show_credits(open: bool) -> void` toggles `CreditsPanel` and `Center` visibility and fills `Text` on first open from `res://audio/CREDITS.md`, `res://data/maps/NOTICE.md`, `Engine.get_license_text()`.
- Export: every preset's `include_filter` becomes `"data/maps/NOTICE.md, audio/CREDITS.md"`.

- [ ] **Step 1: Failing tests.**
  - `test_credits.gd`, parsing `res://audio/CREDITS.md` with its own split (lines starting `` | `music/ ``): `CR1 every CREDITS.md music row is in the panel` (title, author, source URL, licence, licence URL per row); `CR2 a new music row appears` (the real file plus one appended fake row `` | `music/x.ogg` | Xtitle | https://x.test | Xauthor | CC-BY-4.0 | https://l.test | - | none | `` → its title and URL present); `CR3 the MacLeod attribution block is verbatim`; `CR4 voice line`; `CR5 EA's notice` (contains "Copyright 2025 Electronic Arts Inc." and "ADDITIONAL TERMS per GNU GPL Section 7"); `CR6 Godot's licence text` (contains `Engine.get_license_text()`); `CR7 Wargrid GPL line`.
  - `test_map.gd`: `MP9 exports ship the audio credits` (copy of MP5's loop for `audio/CREDITS.md`, ten presets; `res://audio/CREDITS.md` exists in project or pack).
  - `test_online_scene.gd`: `Credits` added to N5's path list; `N10 Credits panel layout` at 1280x720 and 1920x1080: press `Credits` → `CreditsPanel` visible and inside the viewport, `Center` hidden (so nothing overlaps the status text), `Text` and `Close` inside the panel and not intersecting, `Text.get_parsed_text()` contains "Zhelanov"; press `Close` → panel hidden, `Center` visible.
- [ ] **Step 2: RED**; record the CR1 line.
- [ ] **Step 3: Implement**, then the presets.
- [ ] **Step 4: GREEN:** suite, lint, warnings, `sh tools/run_python_checks.sh`.
- [ ] **Step 5: Export evidence.** If export templates 4.7.2 are installed locally: `sh tools/export_build.sh Linux <scratch>/Wargrid.x86_64` and `sh tools/export_build.sh Web <scratch>/web/index.html`, each with `timeout: 600000` and output to a log file; `grep -c Zhelanov` on each `.pck` > 0 (the handoff's 0.9.0 exe had 0). Record counts; if templates are missing, record "not verified locally, CI exports".

---

### Task 8: Bot-vs-bot sweep on all maps

```text
Task: every faction pair plays bot vs bot on Broken Crown and Ashfall, compared with skirmish.json and Dry Wells on the same tree
Owns: scratch script from Task 4; docs/reference/more-maps.md (results table); verification file; if needed, the smallest fix in game/scripts/simulation/skirmish.gd issue_opponents path plus its test in game/tests/test_skirmish.gd
Invariant: no tracked change unless a seat never builds, collects or attacks on Broken Crown or Ashfall
Boundary: mirror pairs hitting the 45,000-tick cap are existing behaviour (record, not a failure)
Red: only for a fix: a spec-worded test of the failing bot rule on the new map
Green: 24 rows recorded (6 pairs x 4 maps); if a fix: test + suite + run_netplay.sh match (the terminal tick pinned in `tools/run_netplay.sh` after Task 3b's re-pin commit (value in the verification file)) + pins unchanged against the re-pinned values of Tasks 3b and 3c
Stop: a fix would change a pinned outcome or needs more than the existing bot code (record as an M8 finding)
```

Model: Sonnet (medium); a bot fix, if any, gets its own fresh implementer (Sonnet high). Depends on: Task 4.

- [ ] **Step 1:** Estimate total wall time from Task 4's row (24 runs). If above 15 minutes, check for caps first (it is a fixed tick cap, so mostly CPU), then run in the background, one at a time, alone.
- [ ] **Step 2:** Pairs `usa,usa china,china frc,frc usa,china china,frc frc,usa`, seed 1, on `skirmish`, `dry_wells`, `broken_crown`, `ashfall`. One table in `more-maps.md`: map, pair, starts, end tick or cap, winner, first build / collect / enemy damage per seat, tick p95.
- [ ] **Step 3:** Judge per row on the new maps: both seats build, collect and damage an enemy building before the cap. A failing seat → smallest fix per Global Constraints, or a finding for M8 with the numbers.
---

### Task 9: Rendered check per map and Credits on screen

```text
Task: one windowed run per play map with the camera panning across the whole map, frame intervals recorded, plus the launcher Credits panel on screen and the rendered movement benchmark rerun
Owns: scratch script (wargrid-overnight-work/scratch/pan_check.gd, copied into game/ for the run); docs/reference/performance.md (one row); scratchpad screenshots
Invariant: no tracked source change
Boundary: vsync off; audio driver Dummy; 1280x720
Red: n/a (measurement)
Green: three map rows + benchmark row recorded with tree and load
Stop: none overnight (exceeded → recorded)
```

Model: Sonnet (medium). Depends on: Tasks 5 and 7.

- [ ] **Step 1:** Scratch script (run as `sh tools/run_game.sh --audio-driver Dummy --script res://scratch_pan_check.gd -- --map <id>`): sets `SkirmishMain` statics as `_offline_setup` does (seed 1), instantiates `skirmish.tscn`, disables vsync, waits 5 s, then moves the camera at the game's pan speed (400 px/s) from the local start to each of the map diamond's four corners and back, recording frame intervals (`TimingStats.summary`), the time each leg takes, and one screenshot per corner to `/Users/pdstuber/projects/wargrid-overnight-work/screens/`; prints `PAN CHECK map=… frame_ms p50/p95/p99/max=… legs_s=…` and quits.
- [ ] **Step 2:** Run it for `dry_wells`, `broken_crown`, `ashfall`; then a second scratch `--script` instantiates `launcher.tscn`, calls `_show_credits(true)`, waits two frames, saves one screenshot and quits.
- [ ] **Step 3:** `sh tools/run_game.sh --audio-driver Dummy res://scenes/movement_benchmark.tscn` once (`RENDERED BENCHMARK PASSED 4`, Ashfall guard 3.3 ms).
- [ ] **Step 4:** Ledger row: per map frame p50/p95/p99 against the 16.7 ms render goal, Ashfall also against the 3.04 ms Ashfall-layout budget (different workload: say so); pan time across each map at 400 px/s and whether the empty corners outside the diamond dominate the screenshots (observation for the user, not a decision).

---

### Task 10: Exit checks, docs and reviews

```text
Task: final tree passes every check; docs say what changed; one Opus whole-branch review and one /ponytail-review
Owns: docs/development.md, docs/blueprint.md (§7 entry), docs/reference/more-maps.md, docs/reference/performance.md, docs/session-notes.md, AGENTS.md (task pointers), README.md (map choice and Credits are player-visible), docs/reference/relay-stack-spike.md (conformance count only if it states one as current), verification file
Invariant: no source change except fixes from the reviews (each test-first, its own commit)
Boundary: user Godot process present → benchmark deferred and recorded
Red: n/a
Green: all rows below on the final tree
Stop: a review finding needs a design change (record, do not apply)
```

Model: Sonnet (medium) for checks and docs; whole-branch review Opus (high), fresh; `/ponytail-review` run by the coordinator.

- [ ] **Step 1:** On the final tree, one at a time: suite, lint, warnings, python checks, `go test -race ./...`, `golangci-lint run`, `run_conformance.sh`, `run_netplay.sh` all scenarios (`match kill stall silent spike perturb version relay-down relay-term maps map-mismatch`), then alone `sh tools/run_benchmark.sh` with `uptime` at start and end and a new ledger row. Record each with the tree.
- [ ] **Step 2:** Docs as listed in Owns; check every link and path (`rg -o '\]\([^)]+\)'` on changed docs, resolve each). The blueprint §7 M8 entry gets: "Bot depot placement: the converter's slot near supplies is a stopgap (2026-11-08); M8 replaces it with the bot choosing the depot site near supplies itself, Zero Hour's buildBySupplies/findSupplyCenter (AIPlayer.cpp:1849-1960, 2180-2250)". It also gets: "Bot collector counts per supply center (USA 2, China 3, FRC 5, user 2026-11-08, what human players do) are a stopgap; M8 revisits them, with stronger difficulty levels making increasingly optimal economic choices." If Task 3b or 3c ended `BLOCKED`, the docs say so with the recorded old/new pin values.
- [ ] **Step 3:** Opus (high) whole-branch review of `main..converted-maps` with the verification file and this plan; fix critical / important findings test-first; record rulings.
- [ ] **Step 4:** `/ponytail-review` on the branch diff; apply cuts, re-run suite, lint, warnings.
- [ ] **Step 5:** Update the resume record: implemented / verified / pending lists.

## Left for the user (not done overnight)

- Relay deploy to fly (protocol 2). Order: deploy the relay before any client with protocol 2 is released; until then new clients get "protocol mismatch" from the live relay, and after it 0.9.0 clients do.
- Push, CI on Linux and Windows (confirms SS6's pinned start spots and the new netplay scenarios on exported builds), `sh tools/compare_local_traces.sh <run id>` for macOS.
- Merge to `main` (check `git merge-tree --write-tree HEAD main` first; main moves fast).
- Playtest: offline and online on each map; the Credits panel and the Copy button's clipboard in the desktop and web builds (web not opened tonight); judge pan speed and the empty corners from Task 9's screenshots.
- Open questions recorded for M9: Zero Hour does not count a chosen spot as its team's position (`teamPosIdx` only from random placement), so a teammate of a player with a chosen spot is placed far away; keep or fix?
