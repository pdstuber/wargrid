# Project instructions

## Intent and scope

Wargrid is a Godot isometric pixel-art RTS inspired by Zero Hour's game design. Preserve strategic identity and feel; original bugs and slow algorithms are not compatibility requirements.

Current setup and milestone status live in [README](README.md). Milestone scope lives in [the blueprint](Wargrid_Kickoff_Blueprint.md). M0–M3 are implemented; remaining acceptance evidence lives in README. Implement only the explicitly requested milestone and stop at its exit gate; do not automatically expand into later milestones, factions or multiplayer.

## Read before changing

- For `/kickoff` and `/wrapup`, follow [kickoff](docs/kickoff.md) and [wrap-up](docs/wrapup.md). Keep resumable working notes in [session notes](docs/session-notes.md); they do not override authoritative docs.
- Start with [README](README.md) for actual project state and commands, then relevant blueprint sections for scope and acceptance criteria.
- For M1, read [vehicle execution plan](docs/superpowers/plans/2026-11-01-m1-vehicle.md) fully. It defines movement and the intentional updates to M0 tests; do not retain a stationary compatibility mode. Editing the plan does not start implementation.
- For M2, read [groups execution plan](docs/superpowers/plans/2026-11-01-m2-groups.md) fully and its linked M1 contracts. Resume from the recorded checkpoint after inspecting live changes; do not restart completed tasks or treat partial UI stubs as implemented behavior.
- For M3, read [approved design](docs/superpowers/specs/2026-11-02-m3-base-supplies-design.md), [source evidence](docs/reference/m3-economy.md) and [execution plan](docs/superpowers/plans/2026-11-02-m3-base-supplies.md) fully. M3 was explicitly kicked off with remaining M2 visible/performance gates deferred by user approval; see verification evidence. Planning/branch preparation alone never starts implementation.
- For M0 history, read [execution plan](docs/superpowers/plans/2026-11-01-m0-foundation.md) fully. It fixes API/data shapes and acceptance cases; follow its order instead of redesigning the foundation. Resume completed steps; mark them complete only with verification evidence.
- Use [installation reference](docs/reference/installation.md) and other reference notes for evidence. Preserve confirmed, proposed, provisional and deferred labels; never invent approvals or playtests.
- Keep setup/current status in README, design decisions in the blueprint, milestone implementation contracts in their execution plans, evidence in reference notes. Link rather than duplicate rules and numeric values.
- Inspect existing work before editing. Keep changes small; do not scaffold future systems or generic frameworks.

## Implementation

- Terminal-first: author, import and test through files and documented commands; no routine editor clicking.
- Keep Godot project under `game/`, repository tools outside it. `res://` resolves to `game/`. Follow the active milestone execution plan for exact paths and contracts.
- Use typed GDScript. Keep authoritative simulation separate from scenes, rendering, wall-clock time and networking callbacks. Advance it explicitly by ticks; inject randomness when needed.
- Adapt Hell's Verdict's wrappers and CI patterns without modifying that project. Keep Wargrid's planned renderer and tick rate; do not inherit FPS settings or server assumptions.
- Follow personal code-style, Superpowers, review and model-routing instructions. Do not import another project's agent models or workflow exceptions.

## Verification and desktop use

- Write meaningful behavior tests alongside mechanics. Keep small suites per system; fail on zero checks, parse errors, failed expectations and incomplete suites. Require successful exit plus final completion marker.
- Run commands before claiming they work. Report counts, exit status, unverified checks and reference gaps. Planned commands in README are not implemented until M0 creates and verifies them.
- Keep tests, replays and simulation benchmarks headless. Open a visible game window only when the user asks to play. Ask before screenshots or other rendering-dependent checks; batch such checks into one request.
- Separate internal correctness from reference fidelity. Record intentional fixes with regression tests; never silently widen tolerances or change expected results to hide failures.
- For documentation-only changes, check links, paths, status labels and consistency. Automated tests do not establish game feel or measured performance.

## Reference handling and Git

- Keep EA source and installation backups outside this repository and unchanged. Record source revision or archive hash, internal path and uncertainty for findings. Do not copy EA code or assets into Wargrid.
- M0 and future ordinary CI must work without sibling projects or retail game data.
- Preserve user changes. Keep caches, build output, local environment files and temporary analysis out of tracked source.
- Do not commit, push, open a PR or merge without explicit approval. Subagents never commit or push. Never set `GITHUB_TOKEN` or `GH_TOKEN` in the shell or print secrets.
