# M1 performance and replay validation — 2026-11-01

Baseline `7b70a61`; no mechanics changed. Host: Apple M6, 12 CPUs, 32 GiB, macOS 27.2 build 26B123. Pinned Godot `4.7.2.stable.official.ed1daf0bf`, official universal executable. Headless baseline passes 32 cases / 1089 checks / exit 0.

## Timing method and scope

Three serial native ARM64 processes. Per count/layout: 300 warmup ticks then 1800 measured ticks, unpaced (10+60 seconds of simulated time, not measured wall time); pooled 5400 samples. Record step time separately from snapshot, command submission, construction and spawn. Timed step includes route assignment when due. Every moving unit asserted moving with changed position every tick; blocked-idle remains blocked without repeated commands. Retarget normal movement every 60 ticks; burst cases command all units every tick. Timer resolution one microsecond; calibration p50/p95 0 µs, p99 1 µs; 0 µs is granularity, not zero cost.

Default 16×16 map, all stress entities deliberately stacked at `(1.25,6.25)` under M1 API. Open/rectangle targets alternate between x=1.25/14.25, y=6.25; rectangle is M1's 18-cell obstacle. Blocked scenarios use full-height wall x=8; unreachable target on opposite side. These are kernel stress cases without unit collision or distinct slots. They do not establish M2 destination allocation/64×64 navigation cost.

|Entities|Scenario|Step p50 µs|p95|p99|max|Snapshot p95 µs|Snapshot max|Step+snapshot max µs|
|---:|---|---:|---:|---:|---:|---:|---:|---:|
|1|idle|0|1|1|11|2|11|22|
|1|open_motion|1|1|5|16|2|25|27|
|1|obstacle_motion|1|1|6|9|4|28|29|
|1|blocked_idle|0|1|1|1|3|22|23|
|1|obstacle_burst|7|8|11|43|5|30|52|
|1|blocked_burst|5|5|5|23|3|21|39|
|100|idle|10|10|12|49|35|93|116|
|100|open_motion|61|88|383|717|86|173|890|
|100|obstacle_motion|61|89|485|627|93|192|777|
|100|blocked_idle|10|10|14|35|39|142|157|
|100|obstacle_burst|665|699|736|989|161|322|1187|
|100|blocked_burst|398|421|454|642|50|135|692|
|300|idle|30|33|46|82|106|268|305|
|300|open_motion|187|268|1163|1626|256|391|1977|
|300|obstacle_motion|187|269|1455|1648|274|490|2042|
|300|blocked_idle|30|32|38|120|109|261|322|
|300|obstacle_burst|2004|2081|2231|3180|484|1710|4663|
|300|blocked_burst|1199|1574|1732|3057|211|449|3309|
|500|idle|52|91|128|177|256|433|498|
|500|open_motion|321|509|2313|3165|548|903|3973|
|500|obstacle_motion|316|463|2465|3451|559|1058|4392|
|500|blocked_idle|52|55|67|105|182|328|380|
|500|obstacle_burst|3363|3570|4568|6761|915|3096|8393|
|500|blocked_burst|1994|2257|4013|9978|280|2892|10992|

Largest observed step was 9.978 ms (500 simultaneous unreachable searches); largest paired step+snapshot 10.992 ms. Worst measured 500-ID command submission 1.745 ms, outside step timing. Compare with 33.333 ms nominal tick interval; this unpaced test does not establish no backlog, rendering/FPS or blueprint's full M2 performance gate. No competing-load/power-mode control asserted; measurements describe this host/run only.

## Cross-process and cross-architecture replay

Three native ARM64 and three Rosetta x86_64 processes, all exact pinned version. Each advances 1200 ticks with off-center positions, static obstacles, future/multi-ID/replacement/unreachable/invalid commands. Compare canonical `var_to_bytes(snapshot)` at every tick, including map, routes and queue; no rounded JSON as oracle. All six full byte streams identical. SHA-256: `d92091ad588124ad8ab622dd98d18c0e14bc5a10931b8f64ab72a28e48f938a8`.

Status: **PASS for measured macOS processes/architectures/scenario**. Rosetta is same-host translated Intel execution, not native Intel hardware or another OS. Linux/Windows determinism remains pending cross-platform CI; broader determinism/lockstep guarantee not established.

## Provenance and limits

Exact harnesses, source/binary hashes, host/commands, raw samples and diagnostics stored under session scratch `/tmp/wargrid-validation/measure` (temporary, not repository dependency). Three benchmark logs and six replay logs require successful exit, completion marker and no runtime/harness errors; failing self-check probe rejected. No visible renderer measurement or runtime Zero Hour capture performed. See [movement gaps](zero-hour-movement-gaps.md): source-supported mechanisms differ; prototype lacks named reference unit, effective retail config and calibrated world scale. Keep `UNVERIFIED_REFERENCE`, not parity PASS.
