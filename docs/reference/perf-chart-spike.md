# Perf chart spike

## Step 1: preparation (no rendering)

Tree: `spike-visualization`. Nothing rendered, no window opened.

- (a) Godot 4.7.2.stable.official.ed1daf0bf. `godot --help` lists `--position <X>,<Y>`, `--screen <N>`, `--resolution <W>x<H>`, `-w/--windowed`, `-t/--always-on-top`, `--display-driver` (macos, headless=dummy). `--position` exists for variant (b); whether macOS clamps it back on screen is untested.
- (b) `tools/run_game.sh:2-4` forwards all args: `exec godot --path <repo>/game "$@"`. Only with zero args does it default to `res://scenes/launcher.tscn`. So `sh tools/run_game.sh --position 10000,10000 res://scenes/movement_benchmark.tscn` works as written.
- (c) No rendered web build of `movement_benchmark.tscn`. `game/export_presets.cfg:147-156` "Web Bench" preset (feature `wargrid_bench`, export_path `../build/web-bench/index.html`) runs `WargridBenchRunner` (`game/project.godot:13`, `game/benchmarks/bench_runner.gd:2`, a `SceneTree` loop), i.e. the sim bench, not the scene. `tools/serve_web_bench.py` only serves an export dir with COOP/COEP headers and takes POST `/result` into `<results>/web-*.log` (`:15-30`). `build/` does not exist; `web/site/` is the production player build. A rendered web build needs a scratch export of the default main scene (launcher) with a custom main-scene override, or a new preset into the scratchpad; not built yet.
- (d) `/Applications`: Firefox.app 159.0.1. No Chrome, Chromium, Brave or Edge. Headless Chrome is unavailable; (d) would be Firefox only.
- (e) Print sites:
  - `game/scripts/debug/movement_benchmark.gd:160-164`: `RENDERED SAMPLE <layout> wall_seconds=.. physics_ticks=.. tick_ms={json} frame_interval_ms={json} command_tick_ms={json} draw_calls={json}`
  - `game/scripts/debug/profiler.gd:66`: `PROFILE <label> zone=<z> mean_ms=%.4f share=%.1f%% p50=.. p95=.. max=%.3f calls_per_tick=%.2f`; label is `rendered_<layout>` from `movement_benchmark.gd:165` (only with `-- --profile`, `:14,146`).
  - Related: `BACKLOG` line at `movement_benchmark.gd:152`; `RENDERED PROFILE COMPLETE` at `:168` (large layout, profile mode, then quit 0).

### Proposed rendered batch for Step 2 (proposal, needs user OK)

Check `uptime` first; wait if load > 2.5. Logs to scratchpad `perf-spike/<case>-<n>.log`, `timeout: 600000`, background.

1. (a) `sh tools/run_game.sh res://scenes/movement_benchmark.tscn > perf-spike/onscreen-1.log 2>&1` (x2, `-2`).
2. (b) `sh tools/run_game.sh --position 10000,10000 res://scenes/movement_benchmark.tscn > perf-spike/offscreen-1.log 2>&1` (x2). Fallback variant if clamped: `--screen 1` or `--resolution 1x1 --position -5000,-5000`.
3. (c) `sh tools/run_game.sh res://scenes/movement_benchmark.tscn -- --profile > perf-spike/profile-1.log 2>&1` (PROFILE fixture).
4. (d) Needs a build first: scratch web export of a rendered target into the scratchpad, then Firefox only (no Chrome): `firefox --headless` serving via `python3 -I tools/serve_web_bench.py <export> <results>`; read `UNMASKED_RENDERER_WEBGL`. Likely cut or deferred unless user wants it, since no rendered web preset exists.

## Steps 2-4: rendered batch A (user-approved 2026-11-10)

Tree: `spike-visualization` at `6e0a9f5` (docs untracked, nothing else changed). Machine: Apple M6, macOS (Darwin 27.2.0), Godot 4.7.2, `OpenGL API 4.1 Metal - Compatibility, Apple M6`, window 1280x720 (windowed 640x392 per CGWindowList), vsync=off. Runs were sequential, logs in the scratchpad `perf-spike/`.

Batch D (Firefox/web) was NOT approved and is skipped; not run, no renderer string. No Chrome exists anyway (Step 1).

### Load before each run (`uptime`) and checks

| Run | Command | Load 1/5/15 | Exit | `ERROR:` lines | `RENDERED BENCHMARK PASSED 4` |
|---|---|---|---|---|---|
| onscreen-1 | plain | 1.24 1.50 1.89 | 0 | 0 | yes (last line) |
| onscreen-2 | plain | 2.41 2.44 2.22 | 0 | 0 | yes (last line) |
| offscreen-1 | `--position 10000,10000` | 2.47 2.61 2.37 | 0 | 0 | yes (last line) |
| offscreen-2 | `--position 10000,10000` | 2.46 2.55 2.42 | 0 | 0 | yes (last line) |
| profile-1 | `-- --profile` | 2.43 2.50 2.42 | 0 | 0 | yes (line 135; log then ends `RENDERED PROFILE COMPLETE`, as profile mode does) |

Loads on runs 2-5 were at 2.41-2.47, just under the 2.5 guard (the 1-minute figure, which gated the start); the 5- and 15-minute figures were 2.4-2.6. These runs are therefore not "quiet" and the machine was likely busy (WoW memory). Treat every number below as load-affected.

### Frame interval p95 (ms), 60 s sample per layout

| Layout | on-1 | on-2 | off-1 | off-2 | profile-1 (on) |
|---|---|---|---|---|---|
| open | 1.703 | 0.638 | 1.850 | 1.869 | 0.784 |
| dense | 1.289 | 0.383 | 1.214 | 0.842 | 0.647 |
| ashfall | 1.067 | 2.414 | 1.525 | 1.151 | 2.317 |
| horde | 3.109 | 3.095 | 3.160 | 2.966 | 3.460 |

(profile-1 also has large_196: 2.311.) Ledger n=2 Ashfall spread is 2.250-2.833. Judgement: the on-screen runs alone differ by 0.64 vs 1.70 (open), 0.38 vs 1.29 (dense), 1.07 vs 2.41 (ashfall), i.e. run-to-run noise on this machine at this load is as large as, or larger than, any on/off-screen gap; off-screen values fall inside the on-screen range for open/dense/ashfall/horde. Ashfall on-screen values here (1.067, 2.414, 2.317) straddle the ledger's 2.250-2.833, so that spread does not reproduce reliably either. Off-screen does not look systematically different, but this cannot be shown with n=2 at this noise.

### Clamp result

Not off-screen. `CGWindowListCopyWindowInfo` (swift helper, sampled every 8 s during the runs; JXA and pyobjc were unusable here) saw the Godot window "Wargrid (DEBUG)" at X=1280 Y=598, 640x392, onscreen=1, in 39/39 samples of offscreen-1 and 39/39 of offscreen-2. The on-screen profile run sat at X=640 Y=298 (centered). macOS clamped `--position 10000,10000` to the bottom-right screen corner, fully visible. So variant (b) is a fail: it neither hides the window nor proves off-screen rendering. The fallback (`--screen 1` or `--resolution 1x1 --position -5000,-5000`) was NOT tried: the coordinator ended the rendered runs after the approved batch.

### Task 1 fixture: `RENDERED SAMPLE` and `PROFILE rendered_` lines (verbatim, profile-1.log)

```
RENDERED SAMPLE open wall_seconds=60.000156 physics_ticks=1800 tick_ms={"max":5.554,"n":1800,"p50":1.672,"p95":1.983,"p99":2.121} frame_interval_ms={"max":10.725,"n":119157,"p50":0.369,"p95":0.784,"p99":3.265} command_tick_ms={"max":5.554,"n":2,"p50":5.42,"p95":5.554,"p99":5.554} draw_calls={"max":5.0,"n":119157,"p50":5.0,"p95":5.0,"p99":5.0}
PROFILE rendered_open zone=draw mean_ms=1.1416 share=100.0% p50=1.1470 p95=1.1720 max=1.309 calls_per_tick=1.00
PROFILE rendered_open zone=draw.units mean_ms=1.0683 share=93.6% p50=1.0740 p95=1.0970 max=1.224 calls_per_tick=1.00
PROFILE rendered_open zone=snapshot mean_ms=0.7574 share=66.3% p50=0.7490 p95=0.8240 max=2.281 calls_per_tick=1.00
PROFILE rendered_open zone=step mean_ms=0.6353 share=55.7% p50=0.6660 p95=0.8160 max=2.562 calls_per_tick=1.00
PROFILE rendered_open zone=step.advance mean_ms=0.5381 share=47.1% p50=0.5830 p95=0.6940 max=0.918 calls_per_tick=1.00
PROFILE rendered_open zone=view.copy mean_ms=0.1000 share=8.8% p50=0.0930 p95=0.1440 max=0.280 calls_per_tick=1.00
PROFILE rendered_open zone=view.points mean_ms=0.0761 share=6.7% p50=0.0750 p95=0.0830 max=0.108 calls_per_tick=1.00
PROFILE rendered_open zone=draw.overlays mean_ms=0.0710 share=6.2% p50=0.0710 p95=0.0740 max=0.100 calls_per_tick=1.00
PROFILE rendered_open zone=view.sort mean_ms=0.0535 share=4.7% p50=0.0530 p95=0.0600 max=0.084 calls_per_tick=1.00
PROFILE rendered_open zone=step.supply mean_ms=0.0431 share=3.8% p50=0.0430 p95=0.0480 max=0.060 calls_per_tick=1.00
PROFILE rendered_open zone=step.ids mean_ms=0.0330 share=2.9% p50=0.0290 p95=0.0510 max=0.064 calls_per_tick=1.00
PROFILE rendered_open zone=view.structures_key mean_ms=0.0262 share=2.3% p50=0.0260 p95=0.0280 max=0.059 calls_per_tick=1.00
PROFILE rendered_open zone=step.service_paths mean_ms=0.0044 share=0.4% p50=0.0010 p95=0.0010 max=0.253 calls_per_tick=1.00
PROFILE rendered_open zone=step.apply_orders mean_ms=0.0039 share=0.3% p50=0.0020 p95=0.0050 max=2.161 calls_per_tick=1.00
PROFILE rendered_open zone=route mean_ms=0.0038 share=0.3% p50=0.0000 p95=0.0000 max=0.247 calls_per_tick=0.17
PROFILE rendered_open zone=step.combat_fire mean_ms=0.0037 share=0.3% p50=0.0030 p95=0.0060 max=0.011 calls_per_tick=1.00
PROFILE rendered_open zone=step.combat_plan mean_ms=0.0016 share=0.1% p50=0.0010 p95=0.0030 max=0.013 calls_per_tick=1.00
PROFILE rendered_open zone=step.construction mean_ms=0.0013 share=0.1% p50=0.0010 p95=0.0020 max=0.003 calls_per_tick=1.00
PROFILE rendered_open zone=step.rates mean_ms=0.0009 share=0.1% p50=0.0010 p95=0.0020 max=0.002 calls_per_tick=1.00
PROFILE rendered_open zone=allocation.assign mean_ms=0.0008 share=0.1% p50=0.0000 p95=0.0000 max=1.480 calls_per_tick=0.00
PROFILE rendered_open zone=step.production mean_ms=0.0008 share=0.1% p50=0.0010 p95=0.0010 max=0.002 calls_per_tick=1.00
PROFILE rendered_open zone=navigation.astar mean_ms=0.0007 share=0.1% p50=0.0000 p95=0.0000 max=0.045 calls_per_tick=0.17
PROFILE rendered_open zone=combat.retaliate mean_ms=0.0006 share=0.1% p50=0.0010 p95=0.0010 max=0.002 calls_per_tick=1.00
PROFILE rendered_open zone=step.evaluate_match mean_ms=0.0002 share=0.0% p50=0.0000 p95=0.0010 max=0.001 calls_per_tick=1.00
PROFILE rendered_open zone=assign_move.unavailable mean_ms=0.0001 share=0.0% p50=0.0000 p95=0.0000 max=0.097 calls_per_tick=0.00
RENDERED SAMPLE dense wall_seconds=60.000311 physics_ticks=1800 tick_ms={"max":5.395,"n":1800,"p50":1.67,"p95":1.952,"p99":2.123} frame_interval_ms={"max":11.066,"n":117656,"p50":0.371,"p95":0.647,"p99":3.456} command_tick_ms={"max":5.395,"n":2,"p50":5.152,"p95":5.395,"p99":5.395} draw_calls={"max":6.0,"n":117656,"p50":6.0,"p95":6.0,"p99":6.0}
PROFILE rendered_dense zone=draw mean_ms=1.1379 share=100.0% p50=1.1480 p95=1.1630 max=1.251 calls_per_tick=1.00
PROFILE rendered_dense zone=draw.units mean_ms=1.0659 share=93.7% p50=1.0760 p95=1.0900 max=1.171 calls_per_tick=1.00
PROFILE rendered_dense zone=snapshot mean_ms=0.7470 share=65.6% p50=0.7470 p95=0.8050 max=2.140 calls_per_tick=1.00
PROFILE rendered_dense zone=step mean_ms=0.6280 share=55.2% p50=0.6720 p95=0.8300 max=2.638 calls_per_tick=1.00
PROFILE rendered_dense zone=step.advance mean_ms=0.5372 share=47.2% p50=0.5920 p95=0.7040 max=0.936 calls_per_tick=1.00
PROFILE rendered_dense zone=view.copy mean_ms=0.0893 share=7.8% p50=0.0870 p95=0.1180 max=0.207 calls_per_tick=1.00
PROFILE rendered_dense zone=view.points mean_ms=0.0749 share=6.6% p50=0.0740 p95=0.0790 max=0.094 calls_per_tick=1.00
PROFILE rendered_dense zone=draw.overlays mean_ms=0.0702 share=6.2% p50=0.0700 p95=0.0720 max=0.081 calls_per_tick=1.00
PROFILE rendered_dense zone=view.sort mean_ms=0.0522 share=4.6% p50=0.0520 p95=0.0560 max=0.067 calls_per_tick=1.00
PROFILE rendered_dense zone=step.supply mean_ms=0.0423 share=3.7% p50=0.0410 p95=0.0500 max=0.089 calls_per_tick=1.00
PROFILE rendered_dense zone=step.ids mean_ms=0.0282 share=2.5% p50=0.0260 p95=0.0470 max=0.070 calls_per_tick=1.00
PROFILE rendered_dense zone=view.structures_key mean_ms=0.0259 share=2.3% p50=0.0260 p95=0.0270 max=0.032 calls_per_tick=1.00
PROFILE rendered_dense zone=step.service_paths mean_ms=0.0065 share=0.6% p50=0.0000 p95=0.0010 max=0.315 calls_per_tick=1.00
PROFILE rendered_dense zone=route mean_ms=0.0059 share=0.5% p50=0.0000 p95=0.0000 max=0.310 calls_per_tick=0.17
PROFILE rendered_dense zone=navigation.astar mean_ms=0.0031 share=0.3% p50=0.0000 p95=0.0000 max=0.176 calls_per_tick=0.17
PROFILE rendered_dense zone=step.combat_fire mean_ms=0.0031 share=0.3% p50=0.0030 p95=0.0050 max=0.015 calls_per_tick=1.00
PROFILE rendered_dense zone=step.apply_orders mean_ms=0.0031 share=0.3% p50=0.0020 p95=0.0040 max=2.140 calls_per_tick=1.00
PROFILE rendered_dense zone=step.combat_plan mean_ms=0.0012 share=0.1% p50=0.0010 p95=0.0020 max=0.003 calls_per_tick=1.00
PROFILE rendered_dense zone=step.construction mean_ms=0.0010 share=0.1% p50=0.0010 p95=0.0020 max=0.010 calls_per_tick=1.00
PROFILE rendered_dense zone=allocation.assign mean_ms=0.0008 share=0.1% p50=0.0000 p95=0.0000 max=1.471 calls_per_tick=0.00
PROFILE rendered_dense zone=step.rates mean_ms=0.0008 share=0.1% p50=0.0010 p95=0.0010 max=0.006 calls_per_tick=1.00
PROFILE rendered_dense zone=step.production mean_ms=0.0006 share=0.1% p50=0.0010 p95=0.0010 max=0.024 calls_per_tick=1.00
PROFILE rendered_dense zone=combat.retaliate mean_ms=0.0005 share=0.0% p50=0.0000 p95=0.0010 max=0.002 calls_per_tick=1.00
PROFILE rendered_dense zone=step.evaluate_match mean_ms=0.0001 share=0.0% p50=0.0000 p95=0.0010 max=0.004 calls_per_tick=1.00
PROFILE rendered_dense zone=assign_move.unavailable mean_ms=0.0001 share=0.0% p50=0.0000 p95=0.0000 max=0.096 calls_per_tick=0.00
RENDERED SAMPLE ashfall wall_seconds=60.000078 physics_ticks=1800 tick_ms={"max":5.201,"n":1800,"p50":1.591,"p95":1.868,"p99":2.083} frame_interval_ms={"max":11.011,"n":69921,"p50":0.746,"p95":2.317,"p99":3.672} command_tick_ms={"max":5.486,"n":2,"p50":5.201,"p95":5.486,"p99":5.486} draw_calls={"max":45.0,"n":69921,"p50":45.0,"p95":45.0,"p99":45.0}
PROFILE rendered_ashfall zone=draw mean_ms=1.1166 share=100.0% p50=1.1400 p95=1.1620 max=1.196 calls_per_tick=1.00
PROFILE rendered_ashfall zone=draw.units mean_ms=1.0411 share=93.2% p50=1.0650 p95=1.0860 max=1.114 calls_per_tick=1.00
PROFILE rendered_ashfall zone=snapshot mean_ms=0.7354 share=65.9% p50=0.7460 p95=0.7910 max=2.205 calls_per_tick=1.00
PROFILE rendered_ashfall zone=step mean_ms=0.4936 share=44.2% p50=0.5790 p95=0.7970 max=2.367 calls_per_tick=1.00
PROFILE rendered_ashfall zone=step.advance mean_ms=0.3841 share=34.4% p50=0.4810 p95=0.6450 max=0.891 calls_per_tick=1.00
PROFILE rendered_ashfall zone=view.copy mean_ms=0.0830 share=7.4% p50=0.0840 p95=0.1120 max=0.187 calls_per_tick=1.00
PROFILE rendered_ashfall zone=view.points mean_ms=0.0789 share=7.1% p50=0.0780 p95=0.0820 max=0.094 calls_per_tick=1.00
PROFILE rendered_ashfall zone=draw.overlays mean_ms=0.0740 share=6.6% p50=0.0740 p95=0.0760 max=0.086 calls_per_tick=1.00
PROFILE rendered_ashfall zone=view.sort mean_ms=0.0525 share=4.7% p50=0.0520 p95=0.0560 max=0.065 calls_per_tick=1.00
PROFILE rendered_ashfall zone=step.supply mean_ms=0.0404 share=3.6% p50=0.0390 p95=0.0470 max=0.061 calls_per_tick=1.00
PROFILE rendered_ashfall zone=view.structures_key mean_ms=0.0351 share=3.1% p50=0.0350 p95=0.0370 max=0.044 calls_per_tick=1.00
PROFILE rendered_ashfall zone=step.ids mean_ms=0.0271 share=2.4% p50=0.0250 p95=0.0420 max=0.064 calls_per_tick=1.00
PROFILE rendered_ashfall zone=step.combat_fire mean_ms=0.0253 share=2.3% p50=0.0100 p95=0.1300 max=0.146 calls_per_tick=1.00
PROFILE rendered_ashfall zone=step.construction mean_ms=0.0032 share=0.3% p50=0.0030 p95=0.0050 max=0.007 calls_per_tick=1.00
PROFILE rendered_ashfall zone=step.service_paths mean_ms=0.0032 share=0.3% p50=0.0000 p95=0.0010 max=0.221 calls_per_tick=1.00
PROFILE rendered_ashfall zone=step.apply_orders mean_ms=0.0029 share=0.3% p50=0.0020 p95=0.0030 max=2.034 calls_per_tick=1.00
PROFILE rendered_ashfall zone=route mean_ms=0.0027 share=0.2% p50=0.0000 p95=0.0000 max=0.220 calls_per_tick=0.17
PROFILE rendered_ashfall zone=step.production mean_ms=0.0016 share=0.1% p50=0.0020 p95=0.0020 max=0.004 calls_per_tick=1.00
PROFILE rendered_ashfall zone=step.combat_plan mean_ms=0.0012 share=0.1% p50=0.0010 p95=0.0020 max=0.005 calls_per_tick=1.00
PROFILE rendered_ashfall zone=allocation.assign mean_ms=0.0008 share=0.1% p50=0.0000 p95=0.0000 max=1.362 calls_per_tick=0.00
PROFILE rendered_ashfall zone=step.rates mean_ms=0.0007 share=0.1% p50=0.0010 p95=0.0010 max=0.002 calls_per_tick=1.00
PROFILE rendered_ashfall zone=navigation.astar mean_ms=0.0006 share=0.1% p50=0.0000 p95=0.0000 max=0.154 calls_per_tick=0.17
PROFILE rendered_ashfall zone=combat.retaliate mean_ms=0.0005 share=0.0% p50=0.0000 p95=0.0010 max=0.001 calls_per_tick=1.00
PROFILE rendered_ashfall zone=step.evaluate_match mean_ms=0.0001 share=0.0% p50=0.0000 p95=0.0010 max=0.001 calls_per_tick=1.00
PROFILE rendered_ashfall zone=assign_move.unavailable mean_ms=0.0001 share=0.0% p50=0.0000 p95=0.0000 max=0.095 calls_per_tick=0.00
RENDERED SAMPLE horde wall_seconds=60.000635 physics_ticks=1800 tick_ms={"max":5.384,"n":1800,"p50":3.117,"p95":4.511,"p99":4.868} frame_interval_ms={"max":16.399,"n":44204,"p50":0.948,"p95":3.46,"p99":7.769} command_tick_ms={"max":0.0,"n":0,"p50":0.0,"p95":0.0,"p99":0.0} draw_calls={"max":239.0,"n":44204,"p50":222.0,"p95":238.0,"p99":239.0}
PROFILE rendered_horde zone=step mean_ms=2.0271 share=110.5% p50=1.9050 p95=3.0060 max=3.762 calls_per_tick=1.00
PROFILE rendered_horde zone=draw mean_ms=1.8343 share=100.0% p50=1.7740 p95=2.1110 max=2.238 calls_per_tick=1.00
PROFILE rendered_horde zone=draw.units mean_ms=1.7497 share=95.4% p50=1.6950 p95=2.0090 max=2.132 calls_per_tick=1.00
PROFILE rendered_horde zone=step.advance mean_ms=1.1170 share=60.9% p50=1.1200 p95=1.5340 max=1.913 calls_per_tick=1.00
PROFILE rendered_horde zone=snapshot mean_ms=0.9755 share=53.2% p50=0.9120 p95=1.1920 max=1.323 calls_per_tick=1.00
PROFILE rendered_horde zone=step.combat_plan mean_ms=0.6865 share=37.4% p50=0.5140 p95=1.1830 max=2.273 calls_per_tick=1.00
PROFILE rendered_horde zone=combat.build_grid mean_ms=0.1709 share=9.3% p50=0.1580 p95=0.2110 max=0.285 calls_per_tick=1.00
PROFILE rendered_horde zone=view.copy mean_ms=0.1469 share=8.0% p50=0.1390 p95=0.1970 max=0.306 calls_per_tick=1.00
PROFILE rendered_horde zone=step.combat_fire mean_ms=0.1098 share=6.0% p50=0.0520 p95=0.3260 max=0.944 calls_per_tick=1.00
PROFILE rendered_horde zone=combat.nearest mean_ms=0.0918 share=5.0% p50=0.0500 p95=0.2020 max=0.448 calls_per_tick=39.01
PROFILE rendered_horde zone=draw.overlays mean_ms=0.0827 share=4.5% p50=0.0770 p95=0.1000 max=0.110 calls_per_tick=1.00
PROFILE rendered_horde zone=view.points mean_ms=0.0809 share=4.4% p50=0.0750 p95=0.0990 max=0.109 calls_per_tick=1.00
PROFILE rendered_horde zone=view.sort mean_ms=0.0587 share=3.2% p50=0.0550 p95=0.0720 max=0.099 calls_per_tick=1.00
PROFILE rendered_horde zone=step.ids mean_ms=0.0531 share=2.9% p50=0.0450 p95=0.1040 max=0.153 calls_per_tick=1.00
PROFILE rendered_horde zone=combat.retaliate mean_ms=0.0465 share=2.5% p50=0.0010 p95=0.2180 max=0.353 calls_per_tick=1.00
PROFILE rendered_horde zone=step.supply mean_ms=0.0449 share=2.4% p50=0.0420 p95=0.0550 max=0.071 calls_per_tick=1.00
PROFILE rendered_horde zone=combat.firing_cell mean_ms=0.0291 share=1.6% p50=0.0000 p95=0.2760 max=0.954 calls_per_tick=0.52
PROFILE rendered_horde zone=view.structures_key mean_ms=0.0285 share=1.6% p50=0.0270 p95=0.0350 max=0.041 calls_per_tick=1.00
PROFILE rendered_horde zone=step.service_paths mean_ms=0.0034 share=0.2% p50=0.0010 p95=0.0310 max=0.082 calls_per_tick=1.00
PROFILE rendered_horde zone=step.rates mean_ms=0.0031 share=0.2% p50=0.0030 p95=0.0040 max=0.006 calls_per_tick=1.00
PROFILE rendered_horde zone=route mean_ms=0.0028 share=0.2% p50=0.0000 p95=0.0290 max=0.078 calls_per_tick=0.55
PROFILE rendered_horde zone=step.apply_orders mean_ms=0.0024 share=0.1% p50=0.0020 p95=0.0040 max=0.009 calls_per_tick=1.00
PROFILE rendered_horde zone=step.construction mean_ms=0.0011 share=0.1% p50=0.0010 p95=0.0020 max=0.003 calls_per_tick=1.00
PROFILE rendered_horde zone=step.production mean_ms=0.0005 share=0.0% p50=0.0010 p95=0.0010 max=0.002 calls_per_tick=1.00
PROFILE rendered_horde zone=navigation.astar mean_ms=0.0005 share=0.0% p50=0.0000 p95=0.0050 max=0.022 calls_per_tick=0.51
PROFILE rendered_horde zone=step.evaluate_match mean_ms=0.0002 share=0.0% p50=0.0000 p95=0.0010 max=0.001 calls_per_tick=1.00
RENDERED SAMPLE large_196 wall_seconds=60.000055 physics_ticks=1800 tick_ms={"max":4.038,"n":1800,"p50":2.996,"p95":3.464,"p99":3.71} frame_interval_ms={"max":14.371,"n":60951,"p50":0.793,"p95":2.311,"p99":6.552} command_tick_ms={"max":0.0,"n":0,"p50":0.0,"p95":0.0,"p99":0.0} draw_calls={"max":6.0,"n":60951,"p50":6.0,"p95":6.0,"p99":6.0}
PROFILE rendered_large_196 zone=step mean_ms=1.6246 share=132.8% p50=1.5960 p95=1.8560 max=2.415 calls_per_tick=1.00
PROFILE rendered_large_196 zone=draw mean_ms=1.2230 share=100.0% p50=1.2220 p95=1.2390 max=1.420 calls_per_tick=1.00
PROFILE rendered_large_196 zone=draw.units mean_ms=1.1340 share=92.7% p50=1.1330 p95=1.1490 max=1.323 calls_per_tick=1.00
PROFILE rendered_large_196 zone=snapshot mean_ms=1.0628 share=86.9% p50=1.0530 p95=1.1560 max=1.268 calls_per_tick=1.00
PROFILE rendered_large_196 zone=step.advance mean_ms=0.8321 share=68.0% p50=0.8230 p95=0.9190 max=1.102 calls_per_tick=1.00
PROFILE rendered_large_196 zone=step.combat_plan mean_ms=0.6455 share=52.8% p50=0.6380 p95=0.7020 max=0.901 calls_per_tick=1.00
PROFILE rendered_large_196 zone=combat.build_grid mean_ms=0.1859 share=15.2% p50=0.1840 p95=0.2120 max=0.255 calls_per_tick=1.00
PROFILE rendered_large_196 zone=view.copy mean_ms=0.1605 share=13.1% p50=0.1530 p95=0.2280 max=0.326 calls_per_tick=1.00
PROFILE rendered_large_196 zone=combat.nearest mean_ms=0.0975 share=8.0% p50=0.0960 p95=0.1040 max=0.165 calls_per_tick=44.96
PROFILE rendered_large_196 zone=view.points mean_ms=0.0876 share=7.2% p50=0.0870 p95=0.0910 max=0.107 calls_per_tick=1.00
PROFILE rendered_large_196 zone=draw.overlays mean_ms=0.0875 share=7.2% p50=0.0870 p95=0.0900 max=0.116 calls_per_tick=1.00
PROFILE rendered_large_196 zone=view.sort mean_ms=0.0619 share=5.1% p50=0.0610 p95=0.0680 max=0.083 calls_per_tick=1.00
PROFILE rendered_large_196 zone=step.ids mean_ms=0.0518 share=4.2% p50=0.0460 p95=0.1050 max=0.168 calls_per_tick=1.00
PROFILE rendered_large_196 zone=step.supply mean_ms=0.0473 share=3.9% p50=0.0470 p95=0.0500 max=0.062 calls_per_tick=1.00
PROFILE rendered_large_196 zone=step.combat_fire mean_ms=0.0371 share=3.0% p50=0.0320 p95=0.0370 max=0.678 calls_per_tick=1.00
PROFILE rendered_large_196 zone=view.structures_key mean_ms=0.0311 share=2.5% p50=0.0310 p95=0.0330 max=0.049 calls_per_tick=1.00
PROFILE rendered_large_196 zone=step.rates mean_ms=0.0028 share=0.2% p50=0.0030 p95=0.0040 max=0.009 calls_per_tick=1.00
PROFILE rendered_large_196 zone=step.apply_orders mean_ms=0.0021 share=0.2% p50=0.0020 p95=0.0050 max=0.010 calls_per_tick=1.00
PROFILE rendered_large_196 zone=combat.retaliate mean_ms=0.0018 share=0.1% p50=0.0010 p95=0.0010 max=0.127 calls_per_tick=1.00
PROFILE rendered_large_196 zone=step.construction mean_ms=0.0010 share=0.1% p50=0.0010 p95=0.0020 max=0.003 calls_per_tick=1.00
PROFILE rendered_large_196 zone=step.production mean_ms=0.0004 share=0.0% p50=0.0000 p95=0.0010 max=0.002 calls_per_tick=1.00
PROFILE rendered_large_196 zone=step.service_paths mean_ms=0.0004 share=0.0% p50=0.0000 p95=0.0010 max=0.001 calls_per_tick=1.00
PROFILE rendered_large_196 zone=step.evaluate_match mean_ms=0.0002 share=0.0% p50=0.0000 p95=0.0010 max=0.001 calls_per_tick=1.00
```

Outcome: neither
Decision: milestone gates (user, 2026-11-10). Rendered rows are recorded at milestone gates only; no further spike runs. Also accepted: `mean_ms` column; breakdown stacks measured means (step, plumbing, draw).
