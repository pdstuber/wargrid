# Next: art pass scope and process (M7.5)

Sources. The art pack (`docs/art-direction/`, made with GPT; trimmed 2026-11-09, the rest in `~/projects/wargrid-art-archive/`): [art bible](../art-direction/ART_DIRECTION.md), [Godot integration](../reference/art-godot-integration.md), GPT's handoff (archive `IMPLEMENTATION_HANDOFF.md`), the 8 reference sheets in `references/`, and the [13-answer interview](../art-direction/interview/INTERVIEW_ARCHIVE.md). Current plan: [blueprint M7.5](../blueprint.md#m75--art-pass-placement-decided-by-the-user-2026-11-05-scope-proposed-not-approved) and §2 (rewritten for geometric 2.5D on 2026-11-09). Look questions: [next-m75-art-look.md](next-m75-art-look.md). Already decided, not asked: geometry replaces pixel art (user, 2026-11-09); M7.5 sits after ground batch A (blueprint §7, user 2026-11-05/08); visuals never own rules (§2).

## Findings (short, cited)
- **source** User, 2026-11-09: abandon the retro pixel-art style for the art-direction pack's geometric style; the 13 interview answers are a starting point and may be revisited. Blueprint §2, README and AGENTS said pixel art until this was recorded on 2026-11-09; M7.5 Task 1 was an A/B spike of pixel sprites against pushed geometry, now moot.
- **source** The pack was 20 MB before the trim: 8.7 MB a copy of GPT's own v1.2 zip, 7.3 MB interview images, 2.4 MB QA thumbnails, 1.1 MB the 8 current sheets (`du -sh`). Six of its ten Markdown files were about the pack itself (provenance, validation, QA, two handoffs). Repo rule: decisions go to the blueprint, evidence to reference notes, link instead of duplicate (`AGENTS.md`, "Read before changing").
- **source** The Godot review is mostly right and useful: structures draw entirely behind units (`world_view.gd` structure child `show_behind_parent`), so tall buildings cannot overlap units correctly today; and combat events from a skipped online tick never reach the screen, unlike sound, which collects per step ([integration note](../reference/art-godot-integration.md) §2-3).
- **inferred** The handoff wants "explicit archetype geometry" per role in draw code. With about 40 kinds after ground batches A and B, one short shape list per kind (boxes and cylinders with offset, size, height and a colour slot) drawn by one function is less code than one draw function per kind, and keeps faction styling as data (blueprint §14: faction differences are data).
- **source** Every `draw_polygon` is its own draw call in the Compatibility renderer and is triangulated again on each redraw; rectangles batch ([levers note](../reference/art-perf-levers.md), key finding, citing `rasterizer_canvas_gles3.cpp:1094`).
- **source** Cost is the biggest risk. With today's plain rectangles the Ashfall rendered frame p95 is 2.25-2.83 ms against the 3.04 ms budget (0.2-0.8 ms left), the horde layout already exceeds it at 3.4-4.0 ms, and Web rendering was never measured (`docs/reference/performance.md:19-20, 360`). The pack ran no benchmark (archive `VALIDATION.md`, "Limits"). **inferred** Each unit becomes 10-25 polygons instead of one rectangle.
- **source** The world view redraws only when a new tick's state arrives or the hover changes (`world_view.gd:53-88` `queue_redraw` calls); frames in between replay cached draw commands, so the cost sits in tick frames. Recoil, turret aim or smooth movement between ticks would need a redraw every frame. The render goal is 60 fps (16.7 ms), the simulation 30 Hz (`performance.md:8`).
- **source** Retail ZH renders at 30 fps, the logic rate, and does not interpolate between logic frames: the frame limit is on and set to 30 (INI `data/ini/gamedata.ini:10-11`), one logic update per engine update (ZH src `GeneralsMD/Code/GameEngine/Source/Common/GameEngine.cpp:746-776, 879-884`), no lerp in `GameClient/Drawable.cpp`. The GeneralsGameCode fork added a frame pacer and interpolation later (its `Drawable.cpp:1381-1389`).
- **source** User, 2026-11-09: the new graphics are not negotiable; if they exceed the budget, a performance spike speeds things up or the budgets change (by explicit decision, never silently: `AGENTS.md`).
- **source** Licence for original art was "undecided" in README until Q2 below; the logo and Wargrid-made audio are GPL-3.0-or-later. Geometry drawn by code is code.

## Questions
Q1-Q2 decide what `spike-design` must look like before it merges into `main` (user, 2026-11-09: merge first, then the art milestone). Q3 is how to answer the look questions; Q4-Q11 shape M7.5 itself.

Q1. What should stay of `docs/art-direction/` before `spike-design` merges into `main`?
   a) Everything, as GPT made it (20 MB)   b) Fold the 13 decisions and visual rules into blueprint §2, keep the 8 sheets (SVG + PNG) and the interview text (Markdown + JSON) as a reference note; move the zip, QA images, interview images and the six meta docs to a folder outside the repo   c) Keep the art bible and sheets only, delete the interview
   Recommendation: b, because the repo is public and history keeps every byte, and decisions belong in the blueprint; the interview text is the record of your answers. Why it matters: about 19 MB less in the public history, one source of truth.
   **Answered 2026-11-09 (11 smaller questions, [log](answers-2026-11-09.md#art-pass-merge-prep-evening)):** keep sheets, art bible, palette and interview text; move interview images, QA and meta docs to `~/projects/wargrid-art-archive/`; delete GPT's zip; Godot notes to `docs/reference/art-godot-integration.md`; short blueprint §2 with link.

Q2. Which licence should Wargrid's own art use (sheets, any later textures, icons)?
   a) GPL-3.0-or-later, like the code, logo and Wargrid-made audio   b) CC BY-SA 4.0   c) Decide later
   Recommendation: a, because art drawn by code is already GPL and one licence is simplest. Why it matters: closes "undecided" in README before art ships.
   **Answered 2026-11-09: a, GPL-3.0-or-later.**

Q3. Should the look questions marked **A/B** be answered on mock-up pages first, before any game code?
   a) Yes: variants of the reference SVGs (ground darkness, selection colour, roof colour, faction outlines at real size, 8 owner colours, shadows) on labelled A/B pages in Firefox, about five steps per page   b) No, wait for the in-game art lab
   Recommendation: a for colour and shape, because SVG variants cost minutes and you answered the sound spike this way; motion, shake, fog and cost still need the lab. Why it matters: most of the look files can be answered before `spike-design` merges.

Q4. What should the M7.5 Task 1 spike compare, now that pixel sprites are out?
   a) Nothing: build the art lab straight in the new style   b) Today's rectangles against the new style, on one A/B page   c) Two variants of the new style for each open look question (for example dark vs lighter ground), on A/B pages
   Recommendation: c, because the open look questions are easier to answer side by side in the real game than as sheets, and that is the workflow you liked in the sound spike. Why it matters: decides how many lab variants get built.

Q5. When should the art lab run?
   a) Where M7.5 sits: after ground batch A   b) Right after `spike-design` merges, as an evidence-only spike on its own branch (like the sound spike); the rest of M7.5 stays after batch A   c) Before batch A, so batch A's new units are drawn once in the new style
   Recommendation: b, because the lab touches no simulation or movement, so it does not collide with avoidance, and early evidence on cost and readability shapes batch A's kinds. Why it matters: changes milestone order only if you pick c.

Q6. Which objects go into the art lab?
   a) The handoff's five: tank, bulldozer, infantry, power plant, war factory   b) Those five plus supply source and supply depot (the economy screen)   c) One faction's full current roster
   Recommendation: b, because supply piles and the depot fill most of every base screen and the sheets barely show them. Why it matters: lab size.

Q7. How should shapes be described in code?
   a) A short shape list per kind (boxes and cylinders: offset, size, height, colour slot), drawn by one shared function   b) One hand-written draw function per kind, as the handoff suggests   c) Import the SVG sheets as textures
   Recommendation: a, because ~40 kinds as data is far less code than 40 functions, faction style stays data, and the same list rotates to any heading. Why it matters: decides how cheap it is to add every later unit.

Q8. How should the game draw them?
   a) Triangulate each shape once at load, then send all units as one triangle array per tick (one draw call)   b) One `draw_polygon` per shape (simplest, but each is its own draw call: 3,000-7,500 per frame for 300 units)   c) Bake each kind, owner and heading into textures at match start and draw sprites
   Recommendation: a, because the Compatibility renderer cannot batch polygons, and a keeps the crisp vector look and depth order that c loses ([levers note](../reference/art-perf-levers.md) §3). Why it matters: the biggest performance risk of the whole art pass.

Q9. Must the art lab's exit include a measured Web build, not just the native benchmark?
   a) Native rendered benchmark row only (today's gate)   b) Native row plus a Web frame-time measurement of the same scene
   Recommendation: b, because polygon-heavy drawing costs more in WebAssembly and the Web build is a target platform. Why it matters: a native pass could hide a Web failure.

Q10. Should every shot and death be shown even when online play catches up several ticks at once?
   a) Yes: collect visual events after every simulation step, as sound already does   b) No: show only the latest tick (today)
   Recommendation: a, because missing muzzle flashes online look like lag, and the pattern exists in `SoundDirector.collect_step()`. Why it matters: small new presentation code with tests for catch-up, repeated ticks and restart.

Q11. Should tall buildings and units overlap correctly (a tank behind a factory hidden by its roof)?
   a) Yes: draw buildings and units in one depth-sorted list   b) Keep buildings flat enough that it never matters   c) Keep drawing buildings always behind units (today)
   Recommendation: a, because the sheets' tall factories look wrong otherwise; picking stays on ground footprints. Why it matters: replaces one renderer assumption and its view test.

Render rate, smooth movement, quality presets and the performance budget moved to [next-perf-targets.md](next-perf-targets.md) (2026-11-09).
