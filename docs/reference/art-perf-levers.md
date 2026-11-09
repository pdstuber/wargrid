# Performance levers for the geometric look (2026-11-09)

Research by an agent for the M7.5 performance questions ([next-perf-targets.md](../questions/next-perf-targets.md)); evidence, not decisions. Read-only; nothing run, nothing measured. Godot sources read at tag `4.7.2-stable` (`ed1daf0bf`, the pinned build): `godot/<path>:<line>` means github.com/godotengine/godot at that tag. Docs from `godot-docs` branch `4.7`: `docs/<path>:<line>`. Repo paths are relative to the repository root. **source** = read in that file; **inferred** = the agent's reading; numbers without a ledger row are estimates, **not measured**.

## Key finding (read first)

**source**: in the Compatibility renderer every `draw_polygon` / `draw_colored_polygon` is its own GL draw call. `godot/drivers/gles3/rasterizer_canvas_gles3.cpp:1094-1095` "Polygon's can't be batched, so always create a new batch", drawn with `glDrawElementsInstanced(..., 1)` (`:1343`). Each one also triangulates on the CPU when `_draw()` runs (`godot/servers/rendering/renderer_canvas_cull.cpp:1769`, `Geometry2D::triangulate_polygon`) and gets its own GL vertex buffer (`rasterizer_canvas_gles3.cpp:2424-2557`, `request_polygon`). Rects batch: consecutive `draw_rect` calls with the same texture share one instanced draw (`:936-941`). `draw_primitive`/`draw_line` (up to 4 points) batch by point count and texture (`:1120-1146`).

**inferred**: today a unit is one `draw_rect` (`game/scripts/presentation/world_view.gd:199`), so 300 units cost a handful of draw calls (the ledger has 5-6 on small maps and 45 on Ashfall, `docs/reference/performance.md:263`). Draw the same 300 units as 10-25 `draw_colored_polygon` each and you get 3,000-7,500 GL draws **every displayed frame**, tick or not, plus 3,000-7,500 triangulations and buffer allocations on every tick redraw. The docs call per-command validation "quite costly, especially in OpenGL, OpenGL ES and WebGL" (`docs/tutorials/performance/gpu_optimization.rst:31-41`). Changing `draw_rect` to `draw_polygon` is therefore the biggest performance risk of the art pass, ahead of anything below. Whatever shape format is chosen has to submit triangles in batches (lever 3).

## Verdicts

| # | Lever | Verdict |
|---|---|---|
| 1a | World at 30 Hz, camera at display refresh (today) | viable with caveats: per-frame replay cost grows with command count and draw calls, so polygons make it expensive |
| 1b | Interpolating units between ticks | viable with caveats: built-in 2D interpolation acts on canvas-item transforms, not on `_draw()` content |
| 2 | Quality presets | viable: few engine knobs in Compatibility (no 2D MSAA); the real knob is the number of commands |
| 3 | Let the GPU draw (batching) | viable: one pre-triangulated triangle array per tick is the smallest change with the biggest win |
| 4 | Web threads | not viable for performance (it works technically, but Firefox measured slower) |
| 5 | GDExtension / C++ | viable with caveats: works on web with dlink templates and COOP/COEP; FMA contraction can break lockstep; effort L |
| 6 | Friend benchmark page | viable: the sim bench already runs on web; the smallest addition is a copyable result box; a rendered web bench needs a CPU-time metric instead of vsync-off |
| 7 | Cheap extras | viable: a draw-call ceiling gate, one-pass `draw.units`, low-processor mode for idle frames |
| 8 | Web threads and `thread_model` "Separate", re-check | not viable on web (forced off in our no-threads build; WebGL is main-thread); native only, experimental. No earlier Separate measurement found in the repo |

## 1. Rendering above 30 fps

### 1a. World at 30 Hz, camera and cursor at display refresh

Verdict: **viable with caveats**. Cheap with rects, expensive with unbatched polygons.

- **source** (repo): the world view redraws only from `set_state` (`world_view.gd:53-70`, `queue_redraw` at :70), which runs from `_physics_process` (`game/scripts/main.gd:90-95` -> `_refresh` -> `_show` -> `set_state` at :213). The camera pans in `_process` (`main.gd:97-103`).
- **source** (Godot): every frame the 2D renderer walks the canvas items (`renderer_canvas_cull.cpp:304`, `_cull_canvas_item`; `:495`, `render_canvas`). GLES3 then rebuilds batches from each item's retained command list (`rasterizer_canvas_gles3.cpp:576` `_render_items` -> `:814` `_record_item_commands`, a loop over commands), uploads the instance data (`:1557`, `glBufferSubData` under `WEB_ENABLED`) and issues one GL draw per batch.
- **inferred**: so a frame without a tick costs no GDScript, but C++ work grows with the **number of commands**, and GL/WebGL work grows with the **number of batches**. With rects: few batches, cheap. With per-polygon commands: one GL draw per polygon per frame (key finding). Cost scales linearly with refresh rate: at 144 Hz there are about 4.8 frames per tick, each paying the full replay.
- **source**: on the web, vsync cannot be switched off. The main loop is driven by `requestAnimationFrame` (`godot/platform/web/web_main.cpp:175`, `emscripten_set_main_loop(main_loop_callback, -1, false)`; Emscripten: "Setting `int <=0` (recommended) uses the browser's `requestAnimationFrame` mechanism", emscripten.org `emscripten.h` docs), and `DisplayServerWeb::window_get_vsync_mode` returns `VSYNC_ENABLED` (`godot/platform/web/display_server_web.cpp:1465-1466`). The class reference adds that modes other than Enabled "are only supported in the Forward+ and Mobile rendering methods, not Compatibility" (`godot/doc/classes/DisplayServer.xml:2645`). Native vsync-off does produce sub-ms frames in our benchmark (p50 0.84 ms, `performance.md:263`), so that note does not seem to hold on macOS (**inferred**).
- `application/run/max_fps` is honoured on the web (`web_main.cpp:93-100`), so an optional cap is possible (the user rejected 30).

### 1b. Interpolating unit positions and headings

Verdict: **viable with caveats**.

- **source**: Godot 4.7 has 2D physics interpolation: "the renderer will interpolate the transforms of objects (both physics and non-physics) between the last two transforms" (`godot/doc/classes/ProjectSettings.xml:2690`, `physics/common/physics_interpolation`, default false). "Physics interpolation in 2D is implemented on the server side" (`docs/tutorials/physics/interpolation/2d_and_3d_physics_interpolation.rst:25`). It works on the local transform of each instance (`advanced_physics_interpolation.rst:26-28`). Per canvas item it is `RenderingServer.canvas_item_set_interpolated` / `canvas_item_reset_physics_interpolation` (`RenderingServer.xml:581-586`, `:484`). MultiMeshes are supported in 2D (`2d_and_3d_physics_interpolation.rst:24`, `multimesh_set_buffer_interpolated` `RenderingServer.xml:2907`).
- **inferred**: it **does not apply to our custom `_draw()`**. All units are commands inside one `WorldView` canvas item whose transform never moves, so there is nothing to interpolate. Two ways to get interpolation:
  - (i) **One canvas item per unit** (`RenderingServer.canvas_item_create`, no nodes). Its shape commands stay static in local space and are re-recorded only when kind, owner or heading bucket changes. Set the item transform once per tick inside `_physics_process` (it already runs there) and the server interpolates at display refresh in C++, with no GDScript per frame. Depth order: our depth key x+y is screen y (`isometric.gd:3-7`: y = 16(x+y)), so a y-sorted parent (`canvas_item_set_sort_children_by_y`, `RenderingServer.xml:629-634`) gives the same order. Heading: a world-plane rotation is the affine screen transform P·R·P⁻¹, which is exact for flat ground shapes but wrong for extruded "up" parts. So interpolate the position, and snap 2.5D bodies to heading buckets. Removing, teleporting or spawning a unit needs `reset_physics_interpolation` (`using_physics_interpolation.rst:95-136`). Effort M.
  - (ii) **Manual interpolation**: redraw the world every frame at `alpha = Engine.get_physics_interpolation_fraction()`. That puts GDScript `_draw` work at refresh rate: cost x (refresh / 30), so x2 at 60 Hz and x4.8 at 144 Hz. It only works if the per-frame draw is the cheap batched form from lever 3 (rebuilding one array: about 2 packed-array appends per unit). Effort S on top of lever 3. Per-frame cost not measured.
- Lockstep: online ticks can stall while waiting for inputs. Interpolation then holds the last pose, so motion is not extrapolated (**inferred**).

## 2. Quality presets (low / high)

Verdict: **viable**. The engine offers few knobs here; most of the gain comes from how many commands and draws we emit.

Engine knobs:
- **MSAA 2D is not available in Compatibility**: "MSAA is only supported in the Forward+ and Mobile rendering methods, not Compatibility" (`ProjectSettings.xml:2861`). The renderer table says "MSAA 2D ... ❌ Not supported" for Compatibility (`docs/tutorials/rendering/renderers.rst:298`).
- **Antialiasing per primitive**: `draw_polygon` / `draw_colored_polygon` have **no `antialiased` parameter** in 4.7 (`godot/doc/classes/CanvasItem.xml:93-101, 291-300`). Antialiased lines and rects get "feathers" on the CPU: +2 or +4 extra primitive commands (`renderer_canvas_cull.cpp:757-830`, `:1313-1390`). These batch, but switching between rect and primitive commands breaks a batch. An antialiased polyline adds two more **polygon** commands, which are unbatched draws (`:980-1070`). Smooth outlines therefore cost roughly 3 draws per outline: a high-preset-only feature (**inferred**).
- **Render scale**: the `canvas_items` stretch mode renders "directly at the target resolution" (`ProjectSettings.xml:1090`). On the web, HiDPI uses `devicePixelRatio` (`godot/platform/web/js/libs/library_godot_display.js:238`, `display/window/dpi/allow_hidpi` default true, `ProjectSettings.xml:965`), so a Retina screen fills 4x the pixels. A low preset could use the `viewport` stretch mode (render at 1280x720, then scale) or skip HiDPI on the web. **inferred**: flat polygons are rarely fill-bound, so this matters less than draw calls; the saving is unmeasured.
- `max_fps` as an optional low-preset cap (60, not 30) is a choice for the user.
- `rendering/2d/batching/item_buffer_size` (16384 commands per draw, `ProjectSettings.xml:2827`). The Compatibility `item_buffer_size` doc says commands beyond it "will be ignored" (`:3056`), but the code flushes and allocates a new buffer (`rasterizer_canvas_gles3.cpp:1550-1567`). Which behaviour applies in practice is **not verified**.

Wargrid knobs (**inferred**):
- far-zoom LOD (at zoom 0.5, one to three triangles per unit)
- drop the shading, outline and shadow layers (the air shadow `draw_circle` is a polygon command, `renderer_canvas_cull.cpp:1467-1530`)
- cap effects per frame
- health bars only when the unit is selected (open question, `docs/questions/next-m76-hud.md:26-28`)

## 3. Letting the GPU draw

Verdict: **viable**. Smallest change with the biggest win: **pre-triangulated triangle lists, one submission per tick**.

| Option | Batching (source) | Cost / risk (inferred) | Effort |
|---|---|---|---|
| **A. One triangle array per tick** | `RenderingServer.canvas_item_add_triangle_array(item, indices, points, colors)` creates one `CommandPolygon` with no triangulation (`renderer_canvas_cull.cpp:1779-1806`). With empty `indices` it draws non-indexed (`rasterizer_canvas_gles3.cpp:1344-1345`, index buffer only `if (p_indices.size())` `:2549`). One draw call for all units. | Triangulate each (kind, heading bucket) once at load into a flat triangle list (`Geometry2D.triangulate_polygon`, as the CanvasItem docs suggest: "consider pre-calculating the triangulation ... and using draw_mesh, draw_multimesh, or RenderingServer.canvas_item_add_triangle_array", `CanvasItem.xml:101`). Per unit per tick: `points.append_array(xform * tris)` (`Transform2D * PackedVector2Array` is one engine call, `godot/doc/classes/Transform2D.xml:297-300`) + `colors.append_array(owner_colors[kind])`, so 2 GDScript calls per unit. Append in depth order: within one draw call, later triangles paint over earlier ones (painter's order kept). One vertex-buffer upload per tick. Health bars, selection and text stay separate on top. | S-M |
| B. `draw_primitive` per triangle | batches by point count (`rasterizer_canvas_gles3.cpp:1120-1146`) | one GDScript call per triangle (3,000-7,500 per tick): worse than A | S |
| C. Baked textures (atlas) + `draw_texture_rect_region` | consecutive rects with the same texture batch (`:936-941`); one atlas means all units can share one draw | Bake (kind x heading bucket) at match start through a `SubViewport` or `Image`. Owner colour needs either one atlas per owner or two layers (neutral + mask x modulate). Memory example: 17 kinds x 16 headings x 2 layers x 48² px x 4 B ≈ 5 MB; baking at 2x for zoom 2.0 quadruples it. Bitmaps blur when scaled under `canvas_items`, so the vector crispness is lost. | M |
| D. MultiMesh 2D (`draw_multimesh`, `MultiMeshInstance2D`) | one draw per multimesh (`rasterizer_canvas_gles3.cpp:1175-1249`); interpolation supported | One multimesh per kind breaks depth order **between** kinds (iso overlap), and owner colour needs per-instance colour or a shader. | M-L |

Recommendation (**inferred**): A first. It keeps the CPU-side vector look and depth sort, removes the per-polygon triangulation, buffer and draw call, and is the input lever 1b(ii) needs. Gate it with a draw-call count (item 7).

## 4. Web threads

Verdict: **not viable for performance**. It works technically and was measured already.

- Requirements (**source**): the Thread Support export option needs "cross-origin isolation headers" (`docs/tutorials/export/exporting_for_web.rst:172-178`), namely `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` (`:354-363`), a secure context, or the PWA option that simulates the headers with a service worker (`:365-369`, `progressive_web_app/ensure_cross_origin_isolation_headers`, `godot/platform/web/export/export_plugin.cpp:239`). The export then picks `web_release.zip` instead of `web_nothreads_release.zip` (`godot/platform/web/export/export_plugin.h:59-71`). CI only installs `web_nothreads_release.zip` (`tools/install_export_templates.py:21`).
- Hosting (**source**): fly app `wargrid-web` (`web/fly.toml`) runs `static-web-server 2.44.1` (`web/Dockerfile`), deployed by `.github/workflows/release.yml:115-120`. Headers are set in `web/sws.toml` (an `[[advanced.headers]]` block, `source = "**"`), which has no COOP/COEP today. The host **can** send them: Task 5d put them on all 18 responses including `.br`/`.gz`, `crossOriginIsolated=true` in Firefox and Vivaldi, then rolled back (`docs/reference/performance.md:177`, `docs/reference/perf-spike-verification.md:614-618`).
- What threads would speed up: our sim and `_draw` are single-threaded GDScript and stay on the main thread. The docs name only Thread use and low-latency **Stream** audio; we use the default Sample playback (`exporting_for_web.rst:113-128, 172-176`). Measured: a threaded build costs Firefox +4.7 % (combat open p50) to +8.3 % (dense), about 0 in Vivaldi. Native parallel `advance.move` gained only 2-3 % (`performance.md:272-273`). The renderer does not move off the main thread on web (item 8).
- Side benefit: COOP/COEP alone (no threads) gives full-resolution timers. Without isolation Firefox and Safari round them to 1 ms (**inferred**, not checked against browser docs), which matters for item 6.

## 5. GDExtension (C++) for hot simulation loops

Verdict: **viable with caveats**. Effort **L**.

- Web (**source**): "If **Extensions Support** is enabled, GDExtensions will be able to be loaded. Note that GDExtensions still need to be specifically compiled for the web platform to work. Like thread support, enabling this feature requires the use of cross-origin isolation headers" (`exporting_for_web.rst:180-183`). The export picks `web_dlink[_nothreads]_*.zip` (`export_plugin.h:59-66`). The dlink templates are in the official 4.7.2 template set (seen in the local install: `web_dlink_nothreads_release.zip`), but CI's `WANTED` list lacks them (`tools/install_export_templates.py:15-22`). dlink builds are bigger ("Produces bigger binaries", `godot/platform/web/detect.py:55-56`). Presets have `variant/extensions_support=false` (`game/export_presets.cfg:164, 236`).
- Lockstep risk (**source** + **inferred**): GDScript floats are doubles, and native vs WASM digests already match (`performance.md:274`; mixed match without desync, U5 `:337`). C++ adds a compiler risk: clang's default is `-ffp-contract=on`, "enable C and C++ standard compliant fusion in the same statement" (clang Users Manual). arm64 native can fuse `a*b+c` into FMA, while core wasm32 has no FMA, so results could differ in the last bit and desync a mixed match. It needs `-ffp-contract=off` and no `-ffast-math` on every target, plus the `DIGEST` cross-check per workload. The sim uses `sqrt` (correctly rounded) and 2 `sin` calls (`rg` over `game/scripts/simulation`); libm `sin` can differ per platform, so precompute or table it.
- Effort: build toolchain for 4 targets (macOS, Linux, Windows, web dlink + emsdk), CI templates, porting, and the trace-preservation gate. The user previously dropped GDExtension (`performance.md:275`). It does not address rendering.

## 6. Friend benchmark page

Verdict: **viable**. The sim half exists; the smallest addition is a result box.

- **source**: the `Web Bench` preset (`custom_features="wargrid_bench"`, `game/export_presets.cfg:152`) swaps the main loop to `WargridBenchRunner` (`game/project.godot:13`, `game/benchmarks/bench_runner.gd`). It runs movement, combat (open, dense, contact, skirmish3v3) and the team match in 30-tick chunks, shows the lines in a Label and, on the web, POSTs them to `location.origin + "/result"` (`bench_runner.gd:24-33, 89-97`). Only `tools/serve_web_bench.py` accepts that POST (`:22`), and it has to run on the friend's own machine (`performance.md:225-229`).
- Smallest friend version (**inferred**): deploy the `Web Bench` export to the test app (`sh tools/deploy_web.sh test` exists; any fly deploy needs approval). Add COOP/COEP to its `sws.toml` so timers are not rounded to 1 ms. When the POST fails (a static host has no `/result`), put the lines into a copyable `<textarea>` through `JavaScriptBridge.eval` (already used at `bench_runner.gd:25, 92-93`). That is about 5 lines plus a deploy, effort S. "Sent somewhere" would need a receiver: the relay or a new endpoint is a protocol or infrastructure change, effort M, not suggested.
- A rendered web bench does **not** come for free: `movement_benchmark.gd:51` disables vsync, but on the web frames are paced by `requestAnimationFrame` (1a), so frame intervals only show whether refresh rate was hit. Measure `RenderingServer.viewport_get_measured_render_time_cpu` (enable with `viewport_set_measure_render_time`), which "will accurately reflect CPU utilization even if framerate is capped via V-Sync" (`RenderingServer.xml:4097-4101`), plus script time per frame. Whether GPU timing works on WebGL Compatibility is **not verified**. Effort S-M.

## 7. Cheap extras (max 3)

1. **Draw-call ceiling as a gate**. The rendered bench already samples `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` (`movement_benchmark.gd:39, 149, 164`). Asserting a ceiling (for example ≤ 50 for 300 units) is machine-independent, so it holds on a fast Mac and catches the polygon trap from the key finding before a Deck run. Effort S.
2. **One pass for `draw.units`**. Rec 3: `draw.units` costs 1.05 ms in five per-unit passes that recompute `_vehicle_bounds`; merging is estimated to save 0.3-0.5 ms per tick (`performance.md:263, 281`), not measured. With the new look, build each unit's triangles, health bar and marks in that single pass. Effort S.
3. **Idle frames for free**. `application/run/low_processor_mode` "only redraws the screen if necessary" (`ProjectSettings.xml:411-412`; skip at `godot/main/main.cpp:5086-5095` when `!RenderingServer.has_changed()`). With a still camera, frames between ticks are skipped and battery/heat drop, but the worst case (panning during a fight) is unchanged. Its 6900 µs sleep (`main.cpp:2264-2265`) and behaviour on the web are **not verified**. Effort S, low value for the worst case.

## 8. Web threads and `thread_model` "Separate": re-check

Verdict: **not viable on web**. Heavier rendering does not change this. Native only, experimental, unmeasured.

- Earlier results in the repo:
  - Web threads: measured in perf spike Tasks 5a and 5d. Atomics cost Firefox +4.7 % to +8.3 %, about 0 in Vivaldi. The parallel `advance.move` PoC gained 2-3 % natively at 4 threads and lost at 2 threads, so task 5c (threaded web PoC) was skipped because the native gain was "far below the 10 % bar" (`performance.md:175, 177, 272-273`; `perf-spike-verification.md:519-618`). The recommendation was against native threads (`docs/session-notes.md:21`). That covered sim parallelism only; rendering threads were never part of it.
  - `thread_model` / "Separate": **no earlier measurement found**. `rg -i "thread_model|render.*thread"` over `docs/` finds nothing relevant, and `git log --all -S thread_model` is empty. If it was tried, it is not recorded.
- What Separate moves (**source** + **inferred**): with a separate render thread, `RenderingServerDefault` runs a "Rendering Server pump task" on a worker and queues server calls (`godot/servers/rendering/rendering_server_default.cpp:130, 277-286`). Our GDScript `_draw()` (vertex maths, `draw_*` calls) stays on the main thread: **no gain for GDScript**. The C++ side moves: triangulation inside `canvas_item_add_polygon`, culling, batch recording and GL calls. With lever 3 that C++ part is small anyway.
- Status (**source**): the setting is marked experimental: "known bugs which can lead to crashing ... Not recommended for use in production" (`ProjectSettings.xml:2916`). Startup warns "it can lead to project crashes or instability" (`main.cpp:3517-3520`). It is forced off in the editor (`:2779-2782`) and **forced off when the build has no threads** (`main.cpp:2783-2785`, `#if !defined(THREADS_ENABLED) separate_thread_render = 0`). Our web export uses `thread_support=false` (`export_presets.cfg:165, 237`), so the setting **does nothing** on the live web build.
- Threaded web template: **not verified**. The web build has no OffscreenCanvas transfer flag (`detect.py:258-266` sets `OFFSCREEN_FRAMEBUFFER` and WebGL 2 only), so the WebGL context lives on the browser main thread (**inferred**) and the GL work cannot move to a worker. No Compatibility-specific doc statement either way was found. The threaded build also carries the measured +4.7-8.3 % Firefox atomics cost.
- Does heavier rendering change the verdict? On the web, **no**: the setting is inert in the no-threads build and probably ineffective in a threaded one. Natively it could hide C++ render cost, but natively we pass already (Deck native passes every p95 except hordes300, `performance.md:329`), and the setting is experimental. Fixing the draw-call count (lever 3) helps both platforms.

## Not verified / gaps
- No rendering was run: every per-frame cost, draw-call cost in WebGL and GDScript append cost is an estimate.
- Whether the 16384 command limit drops commands or flushes (doc vs code, item 2).
- GPU timer queries on WebGL; `low_processor_mode` on the web; a separate render thread with a threaded web template.
- Safari and Chrome (only Firefox and Vivaldi were measured in the spike).
