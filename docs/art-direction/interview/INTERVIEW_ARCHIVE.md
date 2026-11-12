# Wargrid — Complete Art-Direction Interview Archive

> **Images moved (user, 2026-11-09):** the interview images are not in the repository. They live outside it at `~/projects/wargrid-art-archive/interview/` (same file names as cited below), together with GPT's QA images and pack bookkeeping. The 13 answers are the starting point for the art pass and may be revisited.

**13 questions / 13 final user decisions.** Source: the interactive interview on November 8, 2026. This is a design-decision record and visual archive; for the visual rules read [`../ART_DIRECTION.md`](../ART_DIRECTION.md).

> **Fidelity note:** The generated images from questions 1–2 are **copied original PNG/SVG files**. Questions 3–13 originally used interactive *inline vector diagrams*, not downloadable illustrations. Their shape coordinates, paths and colors have been **recreated in standalone editable SVGs** and rasterized to PNG for convenient viewing. The new comparison sheets and label layout are reconstructions, **not byte-for-byte screenshots of the original chat interface**. Do not claim screenshots of A/B/C/D where the original question did not illustrate every option.

> **Answer fidelity:** User selections below are quoted as supplied; the two free-text remarks (question 1 and before question 5) are summarised. Question wording and the option text preserve the substance of the original interview; some explanatory assistant prose has been condensed. Question 1 is especially important: its initial recommendation was *rejected* by the user and replaced with a different high-contrast primitive direction.

## Quick index

| Question | Topic | Final answer |
|---:|---|---|
| [1](#q01) | The overall aesthetic | High-contrast flat geometric abstraction inspired by Space Invaders; the contrast from the early C image is valuable, but its faux-detailed/pixel-art look is not. |
| [2](#q02) | How abstract should the units be? | B — Functional icons made from simple primitives. |
| [3](#q03) | Filled shapes or outlines? | C — Hybrid filled geometric shapes with selective outlines and accents. |
| [4](#q04) | How much personality should the geometry have? | B — Responsive and punchy animations. |
| [5](#q05) | How much depth should our shapes have? | B — Minimalist 2.5D with simple top and side faces. |
| [6](#q06) | What should the terrain look like? | C — Muted biomes with bright units and effects. |
| [7](#q07) | What should combat effects look like? | D — Hybrid: geometric destruction for normal combat and cinematic geometric effects for powerful attacks. |
| [8](#q08) | Should each faction have its own geometric language? | B — Shared functions, faction-specific styling. |
| [9](#q09) | How should buildings communicate their purpose? | D — Functional building silhouettes with selective mechanical animations. |
| [10](#q10) | Lighting, shadows and glow | D — Matte and shaded objects with selective luminous components and effects. |
| [11](#q11) | How should detail change when zooming out? | B — Progressive simplification. |
| [12](#q12) | How much player color should units have? | B — Balanced player-colored surfaces with neutral sides. |
| [13](#q13) | How polished should the simplicity feel? | B — Refined geometric minimalism. |

---

<a id="q01"></a>

## Q01 — The overall aesthetic

**Question:** Which overall aesthetic should Wargrid pursue, rather than replacing the original primitive graphics with traditional pixel sprites?

**Alternatives presented:**

- **A** — Precision diagram — crisp, flat, abstract and functional.
- **B** — Geometric diorama — chunky shapes, subtle depth, tactile and playful.
- **C** — Neon tactical — dark, futuristic, glowy and digital.
- **Hybrid** — B + A readability + selective C effects (the assistant’s *initial* preference, superseded).

**User’s answer (verbatim):**

> (Summarised.) All three options are still pixel art; the intent is closer to Space Invaders: rectangles, circles and triangles. Option C's high contrast goes in the right direction.

**Final interpretation:** High-contrast flat geometric abstraction inspired by Space Invaders; the contrast from the early C image is valuable, but its faux-detailed/pixel-art look is not.

**Why this matters:** The user challenged the initial image direction: all three felt too much like pixel/low-poly art. The revised north star is deliberately primitive rectangles, circles, triangles and lines. Keep C’s high contrast, not its visual complexity.

**Images originally presented:**

- Original A/B/C concept triptych (unaltered generated image) (`~/projects/wargrid-art-archive/interview/original-generated-images/q01_initial_abc_concept_triptych.png`)
- A original pixels (crop) (`~/projects/wargrid-art-archive/interview/original-generated-images/q01_a_crop.png`)
- B original pixels (crop) (`~/projects/wargrid-art-archive/interview/original-generated-images/q01_b_crop.png`)
- C original pixels (crop) (`~/projects/wargrid-art-archive/interview/original-generated-images/q01_c_crop.png`)

Question 1 original generated concept (`~/projects/wargrid-art-archive/interview/original-generated-images/q01_initial_abc_concept_triptych.png`)

---

<a id="q02"></a>

## Q02 — How abstract should the units be?

**Question:** How should simple rectangles, circles, triangles and lines convey recognizable roles?

**Alternatives presented:**

- **A** — Pure symbols — as few components as possible, almost arcade-like.
- **B** — Functional icons — recognizable tracks, turrets, blades and machinery from simple primitives. **← chosen**
- **C** — Adaptive abstraction — pure symbols at far zoom; functional icons at normal gameplay zoom.

**User’s answer (verbatim):**

> For Wargrid art direction question 2, I choose B: functional icons made from simple primitives. Continue the interview.

**Final interpretation:** B — Functional icons made from simple primitives.

**Why this matters:** Role clarity matters more than decorative fidelity. At normal gameplay zoom a tank must read as a tank, and a bulldozer as a bulldozer, without labels.

**Images originally presented:**

- Revised flat geometric battlefield (unaltered generated image) (`~/projects/wargrid-art-archive/interview/original-generated-images/q02_revised_flat_vector_concept.png`)
- Primitive silhouette vocabulary (original PNG) (`~/projects/wargrid-art-archive/interview/original-generated-images/q02_primitive_silhouette_sheet.png`)
- Primitive silhouette vocabulary (original SVG) (`~/projects/wargrid-art-archive/interview/original-generated-images/q02_primitive_silhouette_sheet.svg`)

Question 2 original generated concept (`~/projects/wargrid-art-archive/interview/original-generated-images/q02_revised_flat_vector_concept.png`)

Question 2 original silhouette sheet (`~/projects/wargrid-art-archive/interview/original-generated-images/q02_primitive_silhouette_sheet.png`)

---

<a id="q03"></a>

## Q03 — Filled shapes or outlines?

**Question:** How should geometric primitives be rendered?

**Alternatives presented:**

- **A** — Solid shapes — bold filled forms, strongly reminiscent of classic arcade graphics.
- **B** — Outlines — wireframe-like tactical display, highly abstract.
- **C** — Hybrid — filled shapes with selected outlines, highlights and contrasting accents. **← chosen**

**User’s answer (verbatim):**

> For Wargrid art direction question 3, I choose C — Hybrid filled geometric shapes with selective outlines and accents. Continue the interview.

**Final interpretation:** C — Hybrid filled geometric shapes with selective outlines and accents.

**Why this matters:** Mass is conveyed by fills; an outline is added only where it clarifies depth, silhouette, selection or meaning.

**Original inline diagrams, repackaged as a comparison sheet:**

Question 3 alternatives (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q03_comparison.png`)

**Individual illustrations (SVG / PNG):**

- **A — Solid:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q03_a.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q03_a.png`)
- **B — Outline:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q03_b.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q03_b.png`)
- **C — Hybrid:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q03_c.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q03_c.png`)

---

<a id="q04"></a>

## Q04 — How much personality should the geometry have?

**Question:** How much mechanical motion and exaggeration should accompany each action?

**Alternatives presented:**

- **A** — Mechanical and restrained — rigid, realistic rotation and recoil.
- **B** — Responsive and punchy — recoil, small hull reactions, impacts, debris and bursts. **← chosen**
- **C** — Exaggerated arcade — bounce, squash/stretch, huge reactions.
- **Mix** — Mechanical units, exaggerated effects — unchosen option.

**User’s answer (verbatim):**

> For Wargrid art direction question 4, I choose B — Responsive and punchy animations. Continue the interview.

**Final interpretation:** B — Responsive and punchy animations.

**Why this matters:** Movement and impact should be felt without turning large-scale combat into a bouncy cartoon.

**Related user comment:** Between questions 4 and 5, the user additionally asked whether an isometric game needs some 3D look or could work flat, expecting flat to look strange. This led directly to Question 5.

**Original inline diagrams, repackaged as a comparison sheet:**

Question 4 alternatives (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q04_comparison.png`)

**Individual illustrations (SVG / PNG):**

- **A — Mechanical and restrained:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q04_a.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q04_a.png`)
- **B — Responsive and punchy:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q04_b.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q04_b.png`)
- **C — Exaggerated arcade:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q04_c.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q04_c.png`)

---

<a id="q05"></a>

## Q05 — How much depth should our shapes have?

**Question:** How should flat primitives communicate physical depth within the existing isometric perspective?

**Alternatives presented:**

- **A** — Flat symbols — objects could resemble board markers painted on terrain.
- **B** — Minimalist 2.5D — a top and one/two darker side faces, no elaborate 3D art. **← chosen**
- **C** — Detailed geometric 3D — additional surfaces, mechanical details, more realistic depth.
- **Mix** — Flat infantry with 2.5D vehicles and buildings — unchosen option.

**User’s answer (verbatim):**

> For Wargrid art direction question 5, I choose B — Minimalist 2.5D with simple top and side faces. Continue the interview.

**Final interpretation:** B — Minimalist 2.5D with simple top and side faces.

**Why this matters:** Use cheap, deliberate extrusion to give objects presence, not conventional 3D meshes or textured sprites.

**Original inline diagrams, repackaged as a comparison sheet:**

Question 5 alternatives (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q05_comparison.png`)

**Individual illustrations (SVG / PNG):**

- **A — Flat geometry:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q05_a.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q05_a.png`)
- **B — Minimal 2.5D:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q05_b.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q05_b.png`)
- **C — Detailed geometry:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q05_c.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q05_c.png`)

---

<a id="q06"></a>

## Q06 — What should the terrain look like?

**Question:** What should the battlefield do visually while still identifying different maps?

**Alternatives presented:**

- **A** — Tactical board — near-black terrain, subtle grid, abstract command display.
- **B** — Colored biomes — saturated sand, greenery, snow and other natural colors.
- **C** — Muted biomes — recognizable but desaturated/darker desert, forest, snow etc. **← chosen**
- **D** — Mostly tactical board with distinct geometric environmental features — unchosen option.

**User’s answer (verbatim):**

> For Wargrid art direction question 6, I choose C — Muted biomes with bright units and effects. Continue the interview.

**Final interpretation:** C — Muted biomes with bright units and effects.

**Why this matters:** Terrain should have location identity without stealing contrast from player colors or combat effects. Prominent full-map grids are unnecessary.

**Original inline diagrams, repackaged as a comparison sheet:**

Question 6 alternatives (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q06_comparison.png`)

**Individual illustrations (SVG / PNG):**

- **A — Tactical board:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q06_a.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q06_a.png`)
- **B — Colored biomes:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q06_b.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q06_b.png`)
- **C — Muted biomes:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q06_c.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q06_c.png`)

---

<a id="q07"></a>

## Q07 — What should combat effects look like?

**Question:** How much geometry, fragmentation, smoke, glow and spectacle belong in explosions?

**Alternatives presented:**

- **A** — Tactical — expanding circles, lines and small precise flashes.
- **B** — Geometric destruction — angular bright polygons, chunks of debris, simple smoke.
- **C** — Geometric spectacle — large shockwaves, powerful flashes, glow and layered particles.
- **D** — B for ordinary combat, C only for particularly powerful attacks (chosen hybrid). **← chosen**

**User’s answer (verbatim):**

> For Wargrid art direction question 7, I choose D — Hybrid: geometric destruction for normal combat and cinematic geometric effects for powerful attacks. Continue the interview.

**Final interpretation:** D — Hybrid: geometric destruction for normal combat and cinematic geometric effects for powerful attacks.

**Why this matters:** Everyday fighting stays legible and relatively inexpensive; superweapons and major events may briefly be spectacular. Scale down redundant particles during heavy battles.

**Original inline diagrams, repackaged as a comparison sheet:**

Question 7 alternatives (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q07_comparison.png`)

**Individual illustrations (SVG / PNG):**

- **A — Tactical effects:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q07_a.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q07_a.png`)
- **B — Geometric destruction:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q07_b.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q07_b.png`)
- **C — Geometric spectacle:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q07_c.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q07_c.png`)

---

<a id="q08"></a>

## Q08 — Should each faction have its own geometric language?

**Question:** How should USA, China and FRC be identifiable while using the same geometric primitives?

**Alternatives presented:**

- **A** — Shared geometry with different colors — economical, limited faction identity.
- **B** — Shared function silhouettes, different construction styles and proportions. **← chosen**
- **C** — Completely distinct shape languages for each faction — recognizable but may hurt role readability.
- **D** — Mostly B with radical differentiation for iconic objects — unchosen option.

**User’s answer (verbatim):**

> For Wargrid art direction question 8, I choose B — Shared functions, faction-specific styling. Continue the interview.

**Final interpretation:** B — Shared functions, faction-specific styling.

**Why this matters:** Role → faction → owner: a tank reads as tank first, as USA/China/FRC second, then shows player color independently. The illustrative faction colors are examples, not mandated ownership colors.

**Original inline diagrams, repackaged as a comparison sheet:**

Question 8 alternatives (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q08_comparison.png`)

**Individual illustrations (SVG / PNG):**

- **A — Shared shapes / colors:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q08_a.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q08_a.png`)
- **B — Faction styling:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q08_b.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q08_b.png`)
- **C — Separate shape languages:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q08_c.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q08_c.png`)

---

<a id="q09"></a>

## Q09 — How should buildings communicate their purpose?

**Question:** Can a power plant and a war factory be recognizable from physical structure alone?

**Alternatives presented:**

- **A** — Symbolic buildings — box-shaped structures differentiated mainly with icons.
- **B** — Functional silhouettes — distinct power-generator structures, factory doors, supply areas and so on.
- **C** — Animated machinery — visibly rotating/pumping/opening components.
- **D** — B + selective C: strong functional silhouette, purposeful animations (chosen hybrid). **← chosen**

**User’s answer (verbatim):**

> For Wargrid art direction question 9, I choose D — Functional building silhouettes with selective mechanical animations. Continue the interview.

**Final interpretation:** D — Functional building silhouettes with selective mechanical animations.

**Why this matters:** A factory should be recognizable in a still, then become lively when its door opens. A plant should have identifiable generators, then pulse when active.

**Illustration scope:** The original illustration compared a **power plant and war factory**, not separate A/B/C/D artwork. Only those two original object illustrations exist.

**Original inline diagrams, repackaged as a comparison sheet:**

Question 9 alternatives (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q09_comparison.png`)

**Individual illustrations (SVG / PNG):**

- **POWER_PLANT — Power plant:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q09_power_plant.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q09_power_plant.png`)
- **WAR_FACTORY — War factory:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q09_war_factory.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q09_war_factory.png`)
- Options A/B/C/D were conceptual descriptions, not four illustrated alternatives.

---

<a id="q10"></a>

## Q10 — Lighting, shadows and glow

**Question:** Should units feel like physical matte objects or luminous tactical holograms?

**Alternatives presented:**

- **A** — Pure graphic contrast — virtually no lighting and shadows.
- **B** — Matte/shaded geometry — brighter tops, darker sides, shadows, minor highlights.
- **C** — Luminous geometry — always-glowing outlines, rim lights and accents.
- **D** — B with selective C — energy components, shots, selection and important effects glow. **← chosen**

**User’s answer (verbatim):**

> For Wargrid art direction question 10, I choose D — Matte and shaded objects with selective luminous components and effects. Continue the interview.

**Final interpretation:** D — Matte and shaded objects with selective luminous components and effects.

**Why this matters:** Do not glow every hull edge; reserve strong luminance for communication and emphasis.

**Original inline diagrams, repackaged as a comparison sheet:**

Question 10 alternatives (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q10_comparison.png`)

**Individual illustrations (SVG / PNG):**

- **A — Pure graphic:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q10_a.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q10_a.png`)
- **B — Matte and shaded:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q10_b.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q10_b.png`)
- **C — Luminous:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q10_c.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q10_c.png`)

---

<a id="q11"></a>

## Q11 — How should detail change when zooming out?

**Question:** How do hundreds of units remain recognizable at smaller on-screen sizes?

**Alternatives presented:**

- **A** — Consistent geometry — same drawing at every zoom; detail simply disappears.
- **B** — Progressive simplification — remove accents while preserving hull, turret, barrel, blade etc. **← chosen**
- **C** — Tactical icon transition — switch to strategic icons at far zoom.
- **D** — B plus optional separate tactical overview mode — unchosen option.

**User’s answer (verbatim):**

> For Wargrid art direction question 11, I choose B — Progressive simplification. Continue the interview.

**Final interpretation:** B — Progressive simplification.

**Why this matters:** Role-defining structures are sacred. Outlines, minor highlights and tiny moving pieces are expendable; effects also scale with crowding.

**Original inline diagrams, repackaged as a comparison sheet:**

Question 11 alternatives (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q11_comparison.png`)

**Individual illustrations (SVG / PNG):**

- **A — Consistent geometry:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q11_a.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q11_a.png`)
- **B — Progressive simplification:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q11_b.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q11_b.png`)
- **C — Tactical icon transition:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q11_c.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q11_c.png`)

---

<a id="q12"></a>

## Q12 — How much player color should units have?

**Question:** What portion of visible surfaces should show the owner color rather than neutral materials?

**Alternatives presented:**

- **A** — Full color — most of each unit uses the owner’s color.
- **B** — Balanced — strong owner color on large upper-facing surfaces, darker neutral sides/machinery. **← chosen**
- **C** — Color accents — neutral charcoal/steel machinery with small owner-color details.
- **D** — B, but infantry and very small units with more ownership color — unchosen option.

**User’s answer (verbatim):**

> For Wargrid art direction question 12, I choose B — Balanced player-colored surfaces with neutral sides. Continue the interview.

**Final interpretation:** B — Balanced player-colored surfaces with neutral sides.

**Why this matters:** Top-facing faction/ownership surfaces must be readable from the camera; avoid hiding color in thin edge strokes.

**Original inline diagrams, repackaged as a comparison sheet:**

Question 12 alternatives (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q12_comparison.png`)

**Individual illustrations (SVG / PNG):**

- **A — Full color:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q12_a.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q12_a.png`)
- **B — Balanced:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q12_b.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q12_b.png`)
- **C — Color accents:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q12_c.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q12_c.png`)

---

<a id="q13"></a>

## Q13 — How polished should the simplicity feel?

**Question:** Should Wargrid be raw arcade minimalism, refined primitives or high-production geometric spectacle?

**Alternatives presented:**

- **A** — Raw arcade — ultra-minimal forms and almost no decorative treatment.
- **B** — Refined geometry — deliberate proportions, consistent edges, subtle shadows and excellent timing. **← chosen**
- **C** — Showpiece — more elaborate luminous layers, visual embellishment, intense effects.
- **D** — B with some C spectacle for key moments — unchosen option.

**User’s answer (verbatim):**

> For Wargrid art direction question 13, I choose B — Refined geometric minimalism. Please now create the complete AI-ready Wargrid art direction Markdown document and visual reference package based on our 13 decisions, with concrete Godot implementation guidance and milestone acceptance criteria.

**Final interpretation:** B — Refined geometric minimalism.

**Why this matters:** Choose deliberate visual craftsmanship over decorative complexity. First perfect the readable machine made from a handful of shapes.

**Original inline diagrams, repackaged as a comparison sheet:**

Question 13 alternatives (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q13_comparison.png`)

**Individual illustrations (SVG / PNG):**

- **A — Raw arcade:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q13_a.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q13_a.png`)
- **B — Refined geometry:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q13_b.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q13_b.png`)
- **C — Showpiece:** editable SVG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q13_c.svg`) · PNG (`~/projects/wargrid-art-archive/interview/original-option-illustrations/q13_c.png`)

---

## Reading rules for future AI agents

1. **Chosen decisions override the rejected alternatives.** Never infer that the user selected the first low-poly B / neon C direction in Q1. The final result intentionally rejects that aesthetic.
2. **Images are visual evidence, not implementation mandates.** The original comparisons explore one dimension each; the final north-star references in `../references/` synthesize the accepted principles.
3. **Do not invent missing alternate illustrations.** Several D choices were verbal hybrids without a dedicated image. Q9 compared a power plant with a factory rather than an A/B/C illustration set.
4. **Faction identity and player identity are different axes.** The colors in Q8 sketches illustrate comparative grammar only.
5. **Treat all numerical limits in the art bible as proposals** until validated in Godot against the current rendering architecture and performance benchmarks.

## Image-provenance index

| Asset family | Provenance | Content |
|---|---|---|
| `original-generated-images/q01*` | Original pixel data copied from image generation during this interview | Initial concept triptych and lossless crops |
| `original-generated-images/q02_revised*` | Original generated concept copied unchanged | Corrected flat high-contrast abstraction |
| `original-generated-images/q02_primitive*` | Original locally generated SVG and PNG copied unchanged | Functional primitive shape vocabulary |
| `original-option-illustrations/q03…q13_[option].svg` | Faithful standalone recreation of original inline vector diagrams | Geometry originally displayed in the choice cards |
| `original-option-illustrations/q03…q13_[option].png` | Rasterization of the accompanying standalone SVG | Convenient viewing without SVG viewer |
| `original-option-illustrations/q03…q13_comparison.png` | Newly laid-out contact sheets of the above drawings | All visually illustrated alternatives together |
| `../references/` | New post-interview art-bible concepts | Synthesized *approved* visual direction, not original choice illustrations |
