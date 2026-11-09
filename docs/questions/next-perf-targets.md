# Next: performance targets for the new look

Sources: [performance ledger](../reference/performance.md), [levers note](../reference/art-perf-levers.md) (agent research, 2026-11-09, Godot 4.7.2 source and docs), ZH findings in [next-m75-art-scope.md](next-m75-art-scope.md). Already decided, not asked: the new graphics are not negotiable; an over-budget look gets a performance spike or an explicit budget change, never a silent one (user, 2026-11-09). The user does not want a 30 fps cap (high-refresh displays, 2026-11-09). Budgets stay as they are until these answers change them.

## Findings (short, cited)
- **source** The game is not slow on a desktop: Ashfall renders in 2.25-2.83 ms per frame on the development Mac, roughly 350-440 fps. The 3.04 ms budget is the 60 fps frame (16.7 ms) divided by F = 5.5, Firefox on a Steam Deck (`performance.md:7-8, 20`). Since 2026-11-06 the browser is a target (`performance.md:7`); all playtesters so far use it (user, 2026-11-09).
- **source** The simulation is lockstep, so the slowest player's machine sets the pace for everyone; graphics settings cannot help there. In Firefox on the Deck the 300-unit horde already takes 14.5 ms per tick against 10 ms (`performance.md:313-329`).
- **source** Every `draw_polygon` is its own draw call in the Compatibility renderer, rectangles batch; drawn naively the new look means 3,000-7,500 draw calls per frame for 300 units, on every displayed frame (levers note, key finding). One pre-triangulated triangle array per tick fixes that (levers note §3).
- **source** Today the world redraws only when a tick arrives (30 times a second); frames in between replay the stored drawing in C++, so camera and cursor already move at display refresh (levers note §1a). Smooth unit movement needs interpolation; Godot's built-in 2D interpolation moves whole canvas items, not our hand-drawn content, so it needs one canvas item per unit or a per-frame redraw (levers note §1b).
- **source** Retail ZH caps rendering at 30 fps (see scope findings); the user rejected a 30 fps cap (2026-11-09), so it is not offered below.
- **source** Web threads measured 4.7-8.3 % slower in Firefox, and the parallel simulation proof gained only 2-3 % natively (`performance.md:175-177, 272-273`). Godot's "Separate" render thread is forced off in our no-threads web build and is marked experimental; our GDScript drawing stays on the main thread either way (levers note §4, §8). Not re-measured.
- **source** C++ (GDExtension) works on the web with special export templates and cross-origin isolation headers, but compiler float fusion can desync native against browser players unless switched off; effort large (levers note §5).
- **source** A web benchmark already exists (`Web Bench` preset, `game/benchmarks/bench_runner.gd`); it only reports to a local helper server. A copyable result box is about 5 lines (levers note §6). **inferred** Without cross-origin isolation headers, Firefox and Safari coarsen `performance.now()` timers (1 ms per the levers research; not checked against browser docs).

## Questions
Q1. Which build is the main target for performance?
   a) The browser build   b) The desktop build   c) Both equally
   Recommendation: a, because that is what your friends play. Why it matters: budgets and benchmarks are measured on it first.
   **Answered 2026-11-09: a, the browser, unless good numbers turn out unreachable there; then an engine change may be considered (user did not know which engines suit WebAssembly best; not researched).**

Q2. Whose machine should the budget be based on?
   a) Steam Deck in Firefox (today, F = 5.5)   b) The slowest playtester's browser, measured with a benchmark page   c) A typical mid-range laptop, assumed
   Recommendation: b, keeping the Deck until the first friend numbers arrive. Why it matters: replaces the "potato" assumption with real data.
   **Answered 2026-11-09: a, keep Steam Deck in Firefox (F = 5.5), against the recommendation.**

Q3. Should friends get a benchmark page to run in their browser?
   a) Yes: they open a link and copy the result text to you   b) Yes, and results are sent automatically (needs a server endpoint)   c) No
   Recommendation: a, because it is about 5 lines plus a deploy to the test web app and needs no server. Why it matters: every deploy still asks you first.
   **Answered 2026-11-09: b, results sent automatically (needs a server endpoint; where it lives is not decided).**

Q4. Should the web app send the "cross-origin isolation" headers (no threads, just the headers)?
   a) On the test web app only, for precise benchmark timers   b) On test and production   c) No
   Recommendation: a, because they were already tried and rolled back once (`performance.md:177`), and production gains nothing until threads or C++ are used. Why it matters: without them, browser timings are rounded to 1 ms.
   **Answered 2026-11-09: a, test web app only.**

Q5. How smoothly should units move on high-refresh screens?
   a) The world changes 30 times a second, camera and cursor at display refresh (today)   b) Units move smoothly between ticks (interpolation)
   Recommendation: a for the art lab, b as a "High" option once the triangle-array drawing is in and measured. Why it matters: b costs a world redraw on every displayed frame (2x at 60 Hz, almost 5x at 144 Hz) unless each unit becomes its own canvas item.
   **Answered 2026-11-09: a for the art lab; b later as a High option once the batched drawing is measured.**

Q6. Should there be a graphics quality setting?
   a) Yes, Low and High, picked automatically from measured frame time, changeable in settings   b) Yes, fixed: browser Low, desktop High   c) No, one look for everyone
   Recommendation: a, because fast laptops in a browser deserve High and slow desktops need Low. Why it matters: a settings entry and two drawing paths to test.
   **Answered 2026-11-09: a, Low and High, picked from measured frame time, changeable in settings.**

Q7. How far may Low simplify?
   a) Drop outlines, shadows and extra effects; same shapes   b) a, plus the simple far-zoom shapes at every zoom   c) b, plus lower resolution on high-DPI (Retina) screens
   Recommendation: b, because draw work, not pixels, is the cost; c only if measurements show pixel cost. Why it matters: decides what browser players see.
   **Answered 2026-11-09: b, drop outlines, shadows and extra effects, and use the far-zoom shapes at every zoom.**

Q8. Which quality must the A/B art decisions look good on?
   a) Both, side by side   b) High only   c) Low only
   Recommendation: a, because friends may see Low. Why it matters: doubles some A/B pages.
   **Answered 2026-11-09: a, both side by side.**

Q9. Should the rendered benchmark fail when a frame needs too many draw calls?
   a) Yes, a fixed ceiling (for example 50 for 300 units)   b) No, only time budgets
   Recommendation: a, because draw calls do not depend on the machine, so the fast Mac catches the polygon trap before a slow browser does. Why it matters: a new gate in `movement_benchmark.gd`.
   **Answered 2026-11-09: a, a fixed draw-call ceiling (number set in the art lab plan).**

Q10. Should the browser build use threads?
   a) No (measured 4.7-8.3 % slower in Firefox; our GDScript gains nothing)   b) Re-measure after the art lab
   Recommendation: a, because the earlier spike measured it and the new drawing cost sits on the main thread anyway. Why it matters: avoids repeating a spike with a known result.
   **Answered 2026-11-09 (own wording): threads in the browser build only once Godot's "Separate" render thread is shown to be fast with the new graphics.**

Q11. Should the desktop build try Godot's "Separate" render thread?
   a) No (experimental, does nothing in our web build, our GDScript drawing stays on the main thread)   b) Measure it on desktop after the art lab
   Recommendation: a, because desktop already passes its budgets and the setting is marked unsafe for production. Why it matters: one project setting, but crash risk.
   **Answered 2026-11-09: b, measure once after the art lab, desktop and threaded web, with the new graphics; settles the Q10 condition. (User asked why GDScript drawing stays on the main thread; explained from the levers note §4, §8.)**

Q12. Should hot simulation code move to C++?
   a) Not now; only if the browser simulation budget still fails after the art pass and a simulation performance spike   b) Start a C++ spike now
   Recommendation: a, because it is large, risks desync between browser and desktop players, and does not help drawing. Why it matters: the horde simulation already exceeds its browser budget.
   **Answered 2026-11-09: a, not now.** Later (user): would rather move to a different engine than port parts to C++, since simulation and drawing are separated for that reason.

Q13. When should the browser simulation overrun (horde 14.5 ms against 10 ms) be tackled?
   a) A simulation performance spike right after the art lab   b) Before the art lab   c) Only when playtests show lag
   Recommendation: a, because the art lab first settles the drawing cost, and both together decide what a 3v3 in a browser can afford. Why it matters: lockstep makes the slowest browser everybody's speed.
   **Answered 2026-11-09: a, a simulation performance spike right after the art lab.**
