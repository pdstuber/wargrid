# Codebase guide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write `docs/guide/`, a simple-to-complex guide to how Wargrid works and why, with the general RTS concept behind each system.

**Architecture:** Documentation only. An index with glossary plus 13 numbered chapters. One writer subagent per chapter reads the code and the listed notes; a fresh reviewer fact-checks each batch against the code. Pilot first, then the owner reads and the brief is fixed before fanning out.

**Tech Stack:** Markdown, Mermaid (GitHub-rendered).

**Spec:** [codebase guide design](../specs/2026-11-12-codebase-guide-design.md)

## Global Constraints

- No code, test, config or numeric value changes outside `docs/guide/`, `docs/wrapup.md` (one line) and `docs/development.md` (one link).
- Soft target about 150–350 lines per chapter: depth comes from linking the reference notes, not restating them, so chapters stay cheap to fact-check and update.
- Code pointers: files and key functions or constants, never line numbers.
- Key numbers that explain the system (tick rate, budgets, counts) may appear with a link to the note that owns them; never copy whole rule lists or tuning tables from `docs/reference/sim-interface.md`, `docs/reference/determinism-rules.md`, `docs/reference/performance.md` or blueprint §14. Measured results are labelled measured (with ledger row or note), estimates labelled estimates.
- Proposed, branch-only or deferred work is labelled as such, never described as built. Status labels copied from the source note.
- Public repository rules of `AGENTS.md` ("Reference handling and Git"): no personal detail, home-relative paths, no EA text or INI values; Zero Hour comparisons link the parity or verification note that holds the evidence.
- "(user, DATE)" tags only where the linked source already carries that decision.
- Subagents never commit or push. Commits only after the owner approves, at the stop gates below.
- Work on branch `codebase-guide` from `main`.

## Review Focus

- A chapter states something the code no longer does (written from a stale reference note): reviewer checks every behavioural claim against the code at the footer commit.
- A chapter presents the worker thread, packed-array data layout or unit avoidance as built: reviewer greps for them.
- A term is used with a different meaning than in the README's reference appendix: reviewer checks terms against it.
- A Mermaid syntax error renders as an error box on GitHub: diagrams stay `flowchart` or `sequenceDiagram`, labels with punctuation quoted; reviewer reads each against that syntax.
- A diagram wider than the page gets a scrollbar (owner feedback, 2026-11-12): flowcharts `TD`, at most 3 nodes side by side, node label lines at most ~25 characters (break with `<br/>`), edge labels at most ~15 characters or none, sequence diagrams at most 5 participants; no back edges or loops in flowcharts (Mermaid routes them across other lines); detail goes in the text, not the diagram.
- Flowchart nodes are coloured by layer, same palette in every chapter (owner choice, 2026-11-12); copy only the `classDef` lines a diagram uses, then `class <ids> <layer>`:
  `classDef sim fill:#2f5d8a,stroke:#7fb3e6,color:#ffffff` (simulation),
  `classDef pres fill:#2f6b45,stroke:#7fd09a,color:#ffffff` (presentation, HUD, sound),
  `classDef driver fill:#5b3f86,stroke:#b79ae6,color:#ffffff` (scene scripts: `main.gd` and subclasses, launcher),
  `classDef net fill:#8a5a1f,stroke:#e6b06f,color:#ffffff` (`net/`, relay, protocol),
  `classDef ext fill:#4a4f57,stroke:#a0a7b1,color:#ffffff` (Godot engine, tools, tests, external input).
  Function names stay in the text as `code`, not styled inside labels.
- Broken relative links or backticked paths that do not exist: the link check in Task 6 catches both.

## Chapter brief (every writer gets this section plus their chapter row)

Reader: an experienced software engineer (the owner) who knows the project's goals but lost the architecture, and is not an RTS engine specialist: explain RTS techniques at engineer level, where they first matter. Write like an excellent engineer explaining a compelling system to another: practical, precise, no ceremony. Make the value clear first, then deliver the depth (owner feedback, 2026-11-12).

Write `docs/guide/NN-<slug>.md` as layers, with descriptive headings you choose (a heading says something, e.g. "Every client runs the whole battle", never "The concept" or "Overview"):

1. **Opening (a few lines):** the problem this system solves and why it matters, or the key idea, stated concretely. No background, history or definitions first.
2. **The big picture:** the system's main parts and how they fit, usually with a Mermaid diagram of structure or data flow.
3. **A concrete example:** follow one real case through the code (one move order, one tick, one shot, one packet), naming the functions it passes.
4. **The mechanics:** what happens under the hood: algorithms, data structures, ordering, costs. Name functions by default; quote code (at most ~5 lines) only where it shows the mechanism better than prose, since excerpts rot fastest.
5. **Engineering depth:** why it was designed this way, alternatives considered and their consequences, the assumptions it depends on, when it breaks or would not scale, what an experienced engineer would question. Failure modes and limits come from evidence: `shortcut:` comments in the code, exceeded rows in the performance ledger, limits stated in the notes; anything beyond that is labelled "speculation". The general RTS practice and Zero Hour comparisons ("Zero Hour does X; Wargrid does Y because Z", with the evidence link) belong here or in the layer they explain, not in an up-front primer.
6. **Where in the code:** bullet list `path` — role; key functions or constants.
7. **Reference appendix (only if no reference note already holds it):** lists or tables that would interrupt the narrative.
8. **Further reading:** links into `docs/reference/`, blueprint sections, plans.

Footer: `---` then `Checked against <short commit>. Files: path, path, ...`

Rules for writers:

- Read the chapter's files (grep the functions, read ranges; never dump a whole large file) and its notes. Every behavioural claim comes from code you read; design reasons come from the notes, blueprint or plans.
- A claim you cannot verify gets `(unverified)` at the end of its sentence. The reviewer resolves or deletes it.
- Introduce a term where it first matters, in a clause, not in a definitions block. Use terms with the meanings in the README's reference appendix.
- Short sections, no walls of prose, no filler, no repeating the obvious, no executive summaries, no theatrics or exaggeration. Conversational but precise.
- Each section answers a concrete question, explains a mechanism, shows a result or supports a decision.
- Report back: the file path, line count, the list of `(unverified)` claims, and anything in the code that contradicts a reference note.

## Chapters

| N | File | Code to read | Notes to read |
|---|---|---|---|
| 1 | `01-big-picture.md` (big picture and time) | `game/scripts/main.gd`, `base_main.gd`, `simulation/simulation.gd` (top and `step`), `presentation/presentation_clock.gd`, `game/project.godot` | blueprint §1, §3, §6, §11; `docs/development.md` Overview; `sim-interface.md` |
| 2 | `02-world.md` | `simulation/map_data.gd`, `start_spots.gd`, `presentation/isometric.gd`, `terrain_view.gd`, `tools/zh_map/convert.py` | `more-maps.md`, `m6-map-and-feel.md`, `converted-maps-verification.md`, small supply piles design |
| 3 | `03-entities.md` | `simulation/definitions/*.gd`, `combat_definitions.gd`, `economy_definitions.gd`, entity storage in `simulation.gd` | `sim-interface.md`, `m7-factions.md`, blueprint §8, §14 |
| 4 | `04-the-tick.md` | `simulation/simulation.gd` (`step` and what it calls), command entry points in `skirmish_main.gd` and `net/lockstep.gd` | `sim-interface.md`, `determinism-rules.md` (link only), `movement.md` |
| 5 | `05-presentation.md` | `simulation/view_rows.gd`, `presentation/*.gd`, `lab/*.gd`, `main.gd`, `base_main.gd`, `skirmish_main.gd`, `online_main.gd`, `launcher.gd`, `match_settings.gd`, `game/scenes/*.tscn` | `docs/art-direction/ART_DIRECTION.md`, `art-godot-integration.md`, `art-perf-levers.md`, view rows design, art lab design, sound spike design, `sound-spike.md` |
| 6 | `06-movement.md` (short: next milestone rewrites it) | `simulation/grid_navigation.gd`, `locomotion.gd`, `destination_allocation.gd` | `movement.md`, `group-movement.md`, `zero-hour-movement-gaps.md` |
| 7 | `07-economy.md` | `simulation/supply_collection.gd`, `construction.gd`, `production.gd`, `rebuild_holes.gd`, `salvage.gd`, `economy_definitions.gd` | `m3-economy.md`, `m7-economy-parity.md`, `m7-placement-rules.md`, `m7-supply-parity-measured.md` |
| 8 | `08-combat.md` | `simulation/combat.gd`, `combat_definitions.gd`, `containers.gd`, `horde.gd` | `m4-combat.md`, `turret-aiming.md`, `m4-scenario-envelope.md` |
| 9 | `09-ai.md` | `simulation/skirmish.gd`, `scripted_human.gd`, `debug/team_match.gd` | `fair-bots-research.md`, `m7-verification-archive-research.md` |
| 10 | `10-determinism-and-replays.md` | `simulation/state_hash.gd`, `tools/compare_replays.py`, `compare_local_traces.sh`, `desync_diff.py`, `game/tests/test_replay.gd` | `determinism-rules.md` (summary and link), `state-digest-research.md` |
| 11 | `11-multiplayer.md` | `net/*.gd`, `online_main.gd`, `relay/*.go`, `protocol/conformance/*.go`, one vector in `protocol/vectors/` | `m5-online.md`, `m5.1-acquisition.md`, `relay-stack-spike.md`, `relay-scaling.md`, `docs/playing-online.md` |
| 12 | `12-performance-and-platforms.md` | `debug/*.gd`, `tools/run_benchmark.sh`, `export_build.sh`, `deploy_web.sh`, `web/` | `performance.md` (link numbers), `performance-next.md`, `native-sim-spike.md`, `sim-core-options.md`, `engine-portability-and-horde-mode.md`; section "Proposed, not built": worker thread design, `data-layout-decision.md`, unit avoidance (branch `spike-avoidance`) |
| 13 | `13-testing-and-tooling.md` | `game/tests/run_tests.gd`, one small `test_*.gd`, `tools/run_*.sh`, `test_sim_boundary.py`, `zh_parity/`, `zh_ini.py`, `check_public.sh`, `.github/workflows/*.yml` | blueprint §5, `zero-hour-parity-harness.md`, static checks plan, release workflow plan |

Paths under `game/scripts/` are written without that prefix above; reference notes live in `docs/reference/`, designs in `docs/superpowers/specs/`, plans in `docs/superpowers/plans/`.

## Reviewer brief (fresh subagent per batch, strongest tier, e.g. Fable 5.2)

Input: the chapter paths, this plan's Global Constraints and Review Focus, the glossary. For every chapter: check each behavioural claim and code pointer against the code at the footer commit, resolve or delete every `(unverified)`, flag restated numbers or rules that should be links, flag built-vs-proposed errors, flag failure modes not backed by evidence and not labelled speculation, check Mermaid against the allowed diagram types, and judge the writing against the Chapter brief: does the opening deliver the payoff in its first lines, do the layers build up, are headings descriptive, is there filler or a wall of prose. Report findings ranked, each with chapter, the wrong sentence, and the fix. The coordinator applies fixes.

---

### Task 1: Branch and glossary

**Files:**
- Create: `docs/guide/README.md`

**Interfaces:**
- Produces: glossary terms and meanings every writer uses; `README.md` sections `## Reading order` (placeholder line until Task 6) and `## Glossary`.

- [ ] **Step 1:** `git switch -c codebase-guide` from clean `main`.
- [ ] **Step 2:** Write `README.md`: an opening that hooks (the core idea of Wargrid's architecture in a few concrete lines, e.g. every client runs the same deterministic battle and only commands travel), `## Reading order` with the line "Filled in when all chapters exist.", then at the end `## Appendix: terms` of 20–35 terms, one line each, alphabetical (reference only; chapters explain terms in context). Revised after the pilot (owner feedback, 2026-11-12): the glossary no longer opens the guide. At least: cell, command, definition, determinism, digest/state hash, faction, frame, interpolation, lockstep, path request, presentation, relay, replay, seat, simulation, skirmish, supply, tick, trace, view row. Meanings verified in code (`rg -n` the term in `game/scripts`).
- [ ] **Step 3:** `sh tools/check_public.sh > <scratchpad>/guide-public.log 2>&1; echo "exit=$?"`. Expected: `exit=0`.

### Task 2: Pilot (chapters 1 and 4) — STOP GATE

- [ ] **Step 1:** Dispatch writers for chapters 1 and 4 in parallel (mid tier), each with the Chapter brief and its row.
- [ ] **Step 2:** Dispatch one reviewer for both chapters with the Reviewer brief. Apply its fixes.
- [ ] **Step 3:** Run the Task 6 link check on the two chapters. Expected: no output.
- [ ] **Step 4: STOP.** Ask the owner to read both chapters. Change the Chapter brief in this plan from their feedback, apply it to the two chapters, then ask for approval to commit `docs/guide/` plus this plan (`Start the codebase guide`).

### Task 3: Batch A (chapters 2, 3, 5)

- [ ] **Step 1:** Dispatch writers for 2, 3, 5 in parallel.
- [ ] **Step 2:** One reviewer for the batch; apply fixes.
- [ ] **Step 3:** Link check. Expected: no output.

### Task 4: Batch B (chapters 6, 7, 8, 9)

- [ ] **Step 1:** Dispatch writers for 6–9 in parallel.
- [ ] **Step 2:** One reviewer for the batch; apply fixes.
- [ ] **Step 3:** Link check. Expected: no output.

### Task 5: Batch C (chapters 10, 11, 12, 13)

- [ ] **Step 1:** Dispatch writers for 10–13 in parallel.
- [ ] **Step 2:** One reviewer for the batch; apply fixes.
- [ ] **Step 3:** Link check. Expected: no output.

### Task 6: Index, upkeep hooks, final checks — STOP GATE

**Files:**
- Modify: `docs/guide/README.md` (reading order, decision table)
- Modify: `docs/wrapup.md` step 1 (one sentence)
- Modify: `docs/development.md` "Start here" (one link)

- [ ] **Step 1:** Replace the reading-order placeholder with the 13 chapters, one line each (link plus the question the chapter answers). Add `## Major decisions`: a table Decision | Chapter | Evidence, links only, pointing at blueprint §14 rows and the chapters.
- [ ] **Step 2:** Add to `docs/wrapup.md` step 1: "If simulation, presentation, net or relay architecture changed, update the affected chapter in `docs/guide/` and its `Checked against` footer."
- [ ] **Step 3:** Add one line linking `docs/guide/README.md` to "Start here" in `docs/development.md`.
- [ ] **Step 4: Link check.** From the repo root:

```bash
python3 - <<'EOF'
import re, pathlib
for md in sorted(pathlib.Path("docs/guide").glob("*.md")):
    text = md.read_text()
    for target in re.findall(r"\]\(([^)#\s]+)", text):
        if not target.startswith("http") and not (md.parent / target).exists():
            print(f"{md}: broken link {target}")
    for path in re.findall(r"`((?:game|tools|relay|protocol|web|docs|\.github)/[^`*\s]+)`", text):
        if not pathlib.Path(path).exists() and not pathlib.Path("game/scripts", path).exists():
            print(f"{md}: missing path {path}")
EOF
```

Expected: no output.
- [ ] **Step 5:** `sh tools/check_public.sh` → `exit=0`. `rg -n '\(unverified\)' docs/guide` → no hits. `wc -l docs/guide/*.md` → each chapter about 100–250.
- [ ] **Step 6:** Run `/ponytail-review` on the diff (cut padding and duplicated content); re-run Steps 4–5.
- [ ] **Step 7: STOP.** Show the line counts, check results and proposed commit (`Finish the codebase guide`); commit only after approval. No push.
