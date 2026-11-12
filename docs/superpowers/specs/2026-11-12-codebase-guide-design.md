# Codebase guide: design

Status: approved (user, 2026-11-12); revised after an independent review the same day.

## Intent

The architecture outgrew its documentation during fast iteration. A guide, read mainly by the project owner, explains how Wargrid works, simple to complex, and why each design and tradeoff was taken. It also teaches the general RTS game development concept behind each system (user, 2026-11-12).

Success: the owner can read a chapter per sitting, then open the named files and recognise what they see.

## Goals, non-goals, anti-goals

- Goals: concepts first, then Wargrid's take, then tradeoffs, then code pointers; whole stack (simulation, lockstep, relay, rendering, sound, app shell, tooling, performance).
- Non-goals: no code changes; no new numbers or measurements; not a player manual (`README.md`) or status page (`docs/development.md`).
- Anti-goals: claims the code does not back; restating rules or numbers that reference notes own (`sim-interface.md`, `determinism-rules.md`, `performance.md`, blueprint §14): summarise and link; presenting proposed or branch-only work as built; milestone-history storytelling.

## Decisions (user, 2026-11-12)

- Location: `docs/guide/` in this repository (public engineering record, `tools/check_public.sh` applies).
- Shape: approach A, an index plus numbered chapters.
- RTS basics interleaved: each chapter opens with the general concept.
- Code depth: files and key functions or constants, no line numbers.
- Diagrams: Mermaid.
- Short Zero Hour comparisons where Wargrid deliberately deviates, linking the parity and verification notes; no INI values or EA text copied.
- Upkeep: one line in `docs/wrapup.md`: if the architecture changed, update the affected guide chapter.

## Approaches considered

- A, chapter series (picked): resumable, one chapter to update per system change.
- B, one long `docs/architecture.md`: single read, but too large to resume or update.
- C, generated from code: always current but explains what, never why. Dropped.

## Chapter shape

Each chapter, about 100–250 lines:

Superseded by the plan's Chapter brief after the pilot (owner feedback, 2026-11-12): payoff-first layers, no up-front primer, terms as a README appendix, a one-page TL;DR.

1. The concept (how RTS games generally solve it).
2. How Wargrid does it (with a Mermaid diagram where a flow or structure helps).
3. Tradeoffs: what was chosen, what was rejected, why; Zero Hour comparison where relevant.
4. Where in the code: files, key functions, constants.
5. Evidence and further reading: links into `docs/reference/`, blueprint sections, plans.
6. Footer: `Checked against <commit>` plus the chapter's file list, so `git log <commit>.. -- <files>` shows staleness (builder's call, from the review; complements the wrap-up line).

## Chapter outline (builder may merge or split)

0. `README.md`: reading order, glossary (tick, cell, lockstep, seat, definition, view row, digest...), and a link-only table of the major decisions pointing at blueprint §14 and the chapters.
1. Big picture and time: what an RTS is, game loop, simulation vs presentation split, Wargrid's layers (Godot, GDScript, `simulation/`, `presentation/`, `net/`, Go relay), frame vs fixed tick, tick rate.
2. The world: map data, grid cells, isometric projection, terrain, converted maps, start spots.
3. Entities and definitions: units and buildings in the simulation, definitions and factions as capability data, the simulation interface.
4. The tick: commands from input, `Simulation.step()` and what runs in what order, path request budget.
5. Presentation: view rows, presentation clock and interpolation, world view, batching, shape baking, layers, art direction, A/B lab; app shell, scenes, HUD and input (`main.gd`, `base_main.gd`, `skirmish_main.gd`, `online_main.gd`, `launcher.gd`, `match_settings.gd`, menus and settings); sound (director, cues, announcer, music; presentation only).
6. Movement: grid navigation, locomotion, destination allocation, group movement. Short: the next milestone rewrites movement and pathing.
7. Economy and building: supply collection, construction, placement, production, rebuild holes, salvage.
8. Combat: targeting, weapons, turret aiming, containers, horde bonus.
9. AI: skirmish bots, scripted human.
10. Determinism and replays: why lockstep needs it, determinism rules (summary and link), injected randomness, state hash, replay and trace comparison (`compare_replays.py`, `compare_local_traces.sh`, `desync_diff.py`).
11. Multiplayer: lockstep, wire protocol, relay, conformance, desync detection, latency.
12. Performance and platforms: budgets and ledger (link), benchmarks, what was measured, native spike outcome, browser build (`web/`, `export_build.sh`, `deploy_web.sh`) and why it drives the budget; a "proposed, not built" section for the worker thread, packed-array data layout and unit avoidance (branch `spike-avoidance`).
13. Testing and tooling: behaviour tests, simulation boundary check, parity harness, ZH INI dump, lint, CI, release.

## Production

- A shared style brief file.
- Glossary first. Then a pilot: chapters 1 and one system chapter, written, fact-checked, read by the owner; the brief is fixed from that feedback before fanning out (builder's call, from the review).
- One writer per chapter (mid tier) reads the code and the relevant reference notes, never invents; claims it cannot verify are marked "unverified".
- A fresh reviewer (strongest tier) fact-checks against the code in batches of 3–4 chapters, and resolves or deletes every "unverified" marker; none survive to merge.
- Index last.
- Checks: links and paths resolve, `sh tools/check_public.sh` passes.

## Left to the builder

Chapter merges or splits, diagram choice, glossary contents, which reference notes each chapter links.
