# State digest research (2026-11-09)

Status: **RESEARCH, PROPOSAL ONLY; nothing decided or changed.** Follows [engine portability](engine-portability-and-horde-mode.md) prep step 3. No Godot run, benchmark or suite was run; every cost below is from the ledger or older verification notes, or marked inferred. Godot source and class docs were fetched at tag `4.7.2-stable` (the CI and release pin, `.github/workflows/ci.yml:17`).

## 1. Today

**What it is (source).** `digest` = `"%08x%08x" % [state.hash() & MASK, core_check(state)]` (`game/scripts/simulation/state_hash.gd:10-14`). Half one is Godot's `Dictionary.hash()` over the whole snapshot at full float precision. Half two, `core_check`, is a word-wise 32-bit FNV-1a over `entities[].id, owner, hp, position[0], position[1]` and `players[].credits` only, floats as `floori(x * 1024)`, NaN/inf as one constant (`:16-34`). So only the Godot half sees full precision and all the other fields (order, route, combat, buildings, sources, rng, map...).

**Snapshot contents (source, `simulation.gd:634-650`).** Top level: `tick`, `next_entity_id`, `entities` (sorted by id), `pending_commands`, `last_sequences`, `map` (`size`, `blocked_cells`: read-only cached pairs, `grid_navigation.gd:129-141`), `path_queue`, `players`, `buildings`, `sources`, `terrain_cells` (cached, `:723-733`), `next_production_id`, `command_results`, `combat_events`, `match`, `rng` (an `int`, `:50`), optional `crates`. An entity (`:85`) holds ints (`id`, `hp`, `move_after`), float64 values (`position`, `heading`, `speed`), strings (`kind`, `status`, `mode`), `null`, nested dicts (`combat` 8-12 keys, `combat_definitions.gd:37-39`; `collection` 7 keys) and arrays (`route`). No `Vector2`, `StringName` or `Object` values were found in the snapshot (checked `simulation.gd` builders, not every writer). Floats are float64 in the snapshot; the float32 rounding the portability note describes happens inside the tick maths, so it reaches the hash only as already-rounded float64 values.

**Consumers (source).**

| Consumer | Uses | Where |
|---|---|---|
| Lockstep desync check | `digest` every 30 ticks (`hash_interval` default, not overridden by `launcher.gd:161` or `headless_client.gd:126`); sent as `hash: {tick, value}` in the tick message, compared in `_verify_hashes`; mismatch ends with `ended_desync` and a desync report (command log + snapshot) | `game/scripts/net/lockstep.gd:34, 111-125, 162-163, 195-202` |
| Relay | **format only**: `^[0-9a-f]{16}$`, never compares values | `relay/envelope.go:16, 45-56`; `protocol/vectors/tick.json:2`, `protocol/conformance/conform.go:130-154` |
| Netplay traces | `--hash-log` rows every 30 ticks, compared by `tools/compare_replays.py` (accepts 16 or 64 hex, `:20`) | `headless_client.gd:243-247`, `tools/run_netplay.sh:40, 73` |
| Pins | `PINNED` `test_state_hash.gd:6`; `FINAL_DIGEST` `test_team_match.gd:13` (team trace every 200 ticks, `:70-84`) | 4 re-pins in M6 alone (`m6-verification.md:362`) |
| Equality checks | `test_lockstep.gd:132`, `test_factions.gd:79-123`, `test_skirmish.gd:638`, `test_profiler.gd:45` | compare two runs, no pin |
| `core_check` series | `S1_CORE_SERIES`, `TEAM_CORE_SERIES` | `test_skirmish_match.gd:24`, `test_team_match.gd:93` |
| Desync diff | diffs the JSON snapshot, not the hash | `tools/desync_diff.py:27-28` |

Not using `digest` at all: the CI replay traces (`replay`, `economy`, `combat`) hash **SHA-256 over `var_to_bytes(state)`** every tick (`game/tests/test_replay.gd:56-60`), compared across Linux, Windows, exports and local macOS (`.github/workflows/ci.yml:205-212`, `tools/compare_local_traces.sh`). That is a second Godot-only digest the portability note did not list.

**Cost (source, ledger and M5 notes; Apple M6 headless).** Contact layout, 200 entities: `digest` p99 0.136 ms, `core_check` 0.127 ms (`m5-verification.md:89`); Opus pre-measure: `hash()` 0.043 ms, a packed-subset build 0.157 ms, byte-wise FNV 0.378 ms (`superpowers/plans/2026-11-04-m5-online-spike.md:76`). So the native `hash()` over the whole snapshot is about 3x cheaper than GDScript FNV over five fields per entity. Budget: lockstep overhead p99 (encode, decode, digest on hash ticks) 3.3 ms target = 0.6 ms on the dev machine, measured 0.067 (`performance.md:21`), F = 5.5 (`performance.md:7`). Hash ticks are 1 in 30 (3.3 % of ticks), so a slow digest lands inside p99 (inferred). The profiler zone `hash.digest` exists (`state_hash.gd:13`) but no ledger row quotes it: **not found**.

## 2. What `Dictionary.hash()` does (Godot 4.7.2-stable source, fetched)

- `Dictionary::recursive_hash`: `h = hash_murmur3_one_32(Variant::DICTIONARY)`, then for each entry in **insertion order** `h = hash_murmur3_one_32(E.key.recursive_hash(...), h)` and the same for the value, then `hash_fmix32(h)` (`core/variant/dictionary.cpp:369-383`). `Array` is the same over elements (`core/variant/array.cpp:195-207`).
- `Variant::recursive_hash` (`core/variant/variant.cpp:2809ff`): `INT` → `hash_one_uint64` (a Thomas Wang 64→32 mix, `core/templates/hashfuncs.h:87-96`); `FLOAT` → `hash_murmur3_one_double`, which first does "Normalize +/- 0.0 and NaN values so they hash the same." (`core/templates/hashfuncs.cpp:51-67`); `STRING` → djb2 over UTF-32 code points (`core/string/ustring.cpp:2755-2768`); `OBJECT` → `hash_one_uint64(reinterpret_cast<uint64_t>(_get_obj().obj))`, a **pointer**; seed `HASH_MURMUR3_SEED 0x7F07C65` (`hashfuncs.h:108`).
- Docs promise only: "Returns a hashed 32-bit integer value representing the dictionary contents." and "[b]Note:[/b] Dictionaries with the same entries but in a different order will not have the same hash." (`doc/classes/Dictionary.xml:362, 378`). No stability promise across versions.

**Cross-platform, same Godot build: not a risk (source + measured).** It is pure unsigned integer arithmetic on IEEE bit patterns, and every target (x86-64, ARM64, WASM) is little-endian. Measured: native editor, native release and web gave equal `DIGEST` lines (`performance.md:175`); CI compares Linux, Windows and exports each run.
**Real but latent risks (inferred from the source):** (1) a Godot upgrade may change it silently (any re-pin then hides whether the sim changed); (2) it ignores `-0.0` vs `0.0` and NaN payloads; (3) `1` and `1.0` hash differently, so a JSON-decoded float leaking into an int field is a desync on one peer only if code paths differ; (4) an `Object` in the snapshot would desync every match at once (pointer hash); (5) insertion order is part of the hash, so a port has to reproduce Godot's dictionary insertion order exactly. Correction to the portability note: it is not unreproducible. It is about 80 lines of C++ that Go could copy, but nothing guarantees it stays that way, and (5) makes a port painful.

## 3. Canonical form options

Godot's own `JSON.stringify(x, "", true, true)` is **not** RFC 8785: it writes `0.0` for zero and `-0.0` (`core/io/json.cpp:93-95`), adds `.0` to integral floats (`:98-104`), writes NaN as `null` and inf as `1e99999` (`:80-89`), and formats with Grisu2, whose header says "this does not mean that Grisu2 always generates the shortest possible number" (`thirdparty/grisu2/grisu2.h:757-758`). RFC 8785 requires ECMAScript number text ("MUST be serialized according to Section 7.1.12.1 of [ECMA-262]", §3.2.2.3), sorts keys by UTF-16 code units (§3.2.3), maps minus zero to `0` (Appendix B) and says "occurrences of NaN or Infinity MUST cause a compliant JCS implementation to terminate with an appropriate error" (§3.2.2.3). Useful finding: Godot's JSON keeps int vs float (`.0`) and round-trips doubles, so the existing desync-report JSON is a faithful input for a Python or Go reference hasher (except NaN, and `-0.0` which it folds to `0.0`).

| Option | Cross-engine / language | Floats | Key order | GDScript cost per hash tick (200 units) | Size | Debugging |
|---|---|---|---|---|---|---|
| A. Today: `hash()` + `core_check` | no promise; insertion order | `-0`, NaN folded | insertion | 0.136 ms p99 (source) | 0 | JSON dump + `desync_diff.py` |
| B. Canonical JSON (JCS) text, then hash | good in JS/Go/Python libs | shortest decimal, NaN forbidden | sorted UTF-16 | must hand-roll in GDScript (Godot's JSON is not JCS): string building per leaf, worst option (inferred) | M | text is diffable |
| C. **Generic type-tagged word stream** (walk any Variant: tag, int as 64-bit word, float as IEEE bits, string via cached UTF-8 word, dict keys sorted, array length) | trivial in any language, spec fits half a page | exact bits; `-0.0`→`+0.0`, one NaN | sorted (by code point) | about 0.8-1.2 ms on M6, 4.5-6.6 ms at F 5.5 (inferred: core_check is ~1,000 words in 0.127 ms; a full entity is ~70-100 words) | S (~80 lines GDScript, ~60 Python) | reuse JSON dump; the Python oracle names the first differing path |
| D. Fixed schema per record (core_check widened), like ZH's per-class `Xfer` CRC (`XferCRC.cpp:98`) | trivial | exact bits | by code | slightly cheaper than C (no key words, no sort) | M, and grows with each field | as C |
| E. `var_to_bytes` + native hash | Godot binary format: documented but the page is flagged `:article_outdated: True` (godot-docs `binary_serialization_api.rst:1`); floats shrink to float32 when exact (`core/io/marshalls.cpp:1378-1382`); insertion order | exact | insertion | lowest (native, not measured) | XS | none beyond the dump |
| F. CBOR deterministic (RFC 8949 §4.2.1) | good libs; keys "MUST be sorted in the bytewise lexicographic order of their deterministic encodings"; floats "MUST use the shortest form that preserves the value" | -0.0 kept (`0xf98000`), NaN needs a pick (§4.2.2) | sorted | hand-rolled in GDScript, byte-level: like byte-wise FNV (0.378 ms for 5 fields, source) times ~10 (inferred) | M-L | cbor tools |
| G. MessagePack | spec has no canonical form: apps "may sort keys of maps to make the serialized data deterministic" (msgpack `spec.md:535`) | width choices free | not defined | as F | M-L | weak |
| H. protobuf | "Protobuf serialization is not (and cannot be) canonical" and "hashes of serialized protos are fragile and not stable across time or space" (protobuf.dev, serialization-not-canonical) | n/a | n/a | needs a runtime | L | no |

D trades the main property of today's hash: a new field is covered without code ("picks it up without new code", `turret-aiming.md:29`). A forgotten field in D is an invisible desync blind spot, so C beats D unless C is too slow.

**Hash function.** GDScript `int` is signed 64-bit and "When it exceeds these bounds, it will wrap around." (`doc/classes/int.xml:7`), so FNV-1a 64 runs inline; add a fold (`h ^= (h >> 32) & 0xFFFFFFFF`) per word, because a multiply only carries low bits upward (inferred). xxHash64 and SipHash need logical right shifts and many more ops per word in GDScript (arithmetic `>>`, inferred 3-4x FNV). CRC32 is byte-wise with a table, slow. SHA-256 is native only via `HashingContext` (MD5, SHA1, SHA256: `HashingContext.xml:85-91`) and needs the bytes first; the measured packed-subset build (0.157 ms) was slower than inline FNV (0.120 ms) for the same fields. Desync detection is not adversarial, so FNV-1a 64 with fold is enough. Print as two 32-bit halves to keep 16 hex chars.

**Incremental.** Per-entity caching does not pay: moving units change each tick, and detecting "unchanged" costs about as much as hashing. Two cheap wins: hash the static cached lists (`map`, `terrain_cells`) once per cache build (they are read-only copies, rebuilt on change, `grid_navigation.gd:130`), and **time-slice**: the snapshot is already a frozen copy, so walk 1/30 of it per tick and send the digest for tick T at about T+30. `hash.tick` already names the tick it covers, so no wire change (inferred; `_verify_hashes` order must be checked).

## 4. Recommendation (proposal; the user decides)

**Option C with FNV-1a 64 + fold, computed in `StateHash.digest` from the snapshot, 16 hex chars.** `core_check` stays for the two series tests. Lead risk: the full walk is about 7-10x today's cost (inferred); if the measured `hash.digest` p99 on the contact and horde layouts exceeds 0.6 ms, time-slice over the 30-tick interval before shipping; never loosen the budget.

Migration: (1) measure first: profile `hash.digest` with a scratch C walker on contact, horde and Ashfall; ledger row. (2) Write the canonical-form spec (tags, word order, float rules, key order) into the determinism rules note. (3) Implement `digest`; add a Python reference hasher in `tools/` that reads the desync-report JSON and must match a committed golden snapshot + digest, so CI proves cross-language agreement. (4) One re-pin: `PINNED`, `FINAL_DIGEST`; update H2/H4 cases, add `-0.0`, int-vs-float and key-order cases. (5) Relay, `protocol/vectors` and conformance: **no change** (format only); the portability note's "relay hash value" re-pin is not needed. Netplay traces compare within a run: no change. (6) Release: old and new clients must not share rooms; the relay already refuses `build mismatch` on `application/config/version` (`relay/room.go:141-142`, `launcher.gd:121`), so a version bump is enough. (7) Optionally move the R1-R3 replay traces from `var_to_bytes` SHA-256 to the new digest. Effort: S-M, about one day plus measurement (inferred).

Order: determinism rules note first (it hosts the spec), then digest and golden scenarios **in one change**, so golden vectors pin the new digest and nothing is re-pinned twice.

## Questions

Q1. Should the online desync check stop using Godot's built-in dictionary hash and use our own hash over the whole game state?
   a) Keep today's Godot hash plus core check   b) Own hash over every field (one re-pin)   c) Own hash over the core fields only
   Recommendation: b, because only b keeps full coverage and works outside Godot. Why it matters: decides whether replays and pins survive a Godot upgrade or a port.
Q2. Should the hash read every field automatically, or a hand-written field list?
   a) Hand-written list per record — ZH default (`GeneralsMD/Code/GameEngine/Source/Common/System/XferCRC.cpp:98`, fed by each class's `xfer`)   b) Every field automatically, keys sorted
   Recommendation: b, because a forgotten field in a list is an invisible desync gap. Why it matters: every new mechanic either updates the list or is covered for free.
Q3. Which hash function?
   a) 32-bit rotate-and-add checksum per word (ZH calls it CRC; not CRC32) — ZH default (`XferCRC.cpp:98-116`)   b) 64-bit FNV-1a with a fold (today's family)   c) SHA-256 (native, needs a byte buffer first)
   Recommendation: b, because it is the cheapest in GDScript and keeps 16 hex chars on the wire. Why it matters: per-hash-tick cost on the Steam Deck browser.
Q4. If the full hash is too slow on a hash tick, what then?
   a) Hash less often, every 100 ticks — ZH default (`GameNetwork/Network.cpp:64`, `NET_CRC_INTERVAL = 100`)   b) Spread one hash over the next 30 ticks (desync shows about 1 s later)   c) Accept the budget overrun
   Recommendation: b, because detection stays every second and no tick gets the whole cost. Why it matters: keeps lockstep overhead inside 0.6 ms p99.
Q5. Should 0.0 and -0.0 count as the same value in the hash?
   a) Same (as Godot does today)   b) Different
   Recommendation: a, because the JSON desync dump cannot tell them apart, so a Python checker could not verify b. Why it matters: one rule in the determinism note.
Q6. Should the new hash ship together with the golden test scenarios?
   a) Together, one re-pin   b) Hash first, golden scenarios later   c) Golden scenarios first with core check only
   Recommendation: a, because the golden files then pin the final digest once. Why it matters: avoids pinning twice.
Q7. Is a new game version number enough to keep old and new clients apart online?
   a) Yes, version only (relay already refuses build mismatch)   b) Also raise the network protocol number
   Recommendation: a, because b changes the protocol vectors and conformance suite for no gain. Why it matters: size of the relay-side change (none with a).
Q8. Should the CI replay traces also switch to the new hash?
   a) Yes, one digest everywhere   b) Keep their Godot-specific SHA-256 of the binary snapshot
   Recommendation: a, because then every trace can be checked outside Godot. Why it matters: cross-engine checks need it later.
