# Project instructions

## Intent and scope

Wargrid is a Godot isometric pixel-art RTS inspired by Zero Hour's game design. Preserve strategic identity and feel; original bugs and slow algorithms are not compatibility requirements. The goal is Wargrid's own pixel-art game that feels very close to it, not mathematical parity; see [Zero Hour verification](docs/reference/zero-hour-verification.md).

Current setup and milestone status live in the [development notes](docs/development.md); `README.md` is the player-facing page. Milestone scope lives in [the blueprint](docs/blueprint.md); see its §7 and the long-term 3v3 target. Remaining acceptance evidence lives in the development notes. Implement only the explicitly requested milestone and stop at its exit gate; do not automatically expand into later milestones, factions or multiplayer. Writing, editing or approving a plan, or preparing a branch, never starts implementation on its own.

## Read before changing

- For `/kickoff` and `/wrapup`, follow [kickoff](docs/kickoff.md) and [wrap-up](docs/wrapup.md). Keep resumable working notes in [session notes](docs/session-notes.md); they do not override authoritative docs.
- Start with the [development notes](docs/development.md) for actual project state and commands, then relevant blueprint sections for scope and acceptance criteria.
- Finished milestones' (M0–M7) designs, plans and evidence are listed in [Start here](docs/development.md#start-here) of the development notes; read the one you touch fully; do not redo completed steps, and mark a step complete only with verification evidence. Wargrid's own names in code and UI (`usa`, `china`, `frc`); faction differences are capability data, not simulation branches (user, 2026-11-06; blueprint §14).
- For the active converted maps playable task, read its handoff [converted maps prompt](docs/converted-maps-prompt.txt) (see its "Decided" section), [more maps](docs/reference/more-maps.md) and the relay docs below before changing map selection or online start. Handoffs live at `docs/<task>-prompt.txt`, never at the root (user, 2026-11-08).
- For follow-up work on the post-M7 performance spike, read its [handoff](docs/performance-spike-prompt.txt), the [performance ledger](docs/reference/performance.md) and the [2026-11-05 spike](docs/reference/performance-spike.md) fully; resume record `docs/reference/perf-spike-verification.md`.
- Before touching the GDScript checks (`tools/run_lint.sh`, `tools/run_warnings.sh`), read the static checks [plan](docs/superpowers/plans/2026-11-05-gdscript-static-checks.md); Task 3 was skipped by the user.
- Before touching `.github/workflows/release.yml`, the release tools or fly deploys from CI, read the release workflow [plan](docs/superpowers/plans/2026-11-06-release-workflow.md) and `docs/reference/release-verification.md`.
- Before touching `tools/zh_map/` or `game/data/maps/`, read [more maps](docs/reference/more-maps.md); for supply sources also the [small piles design](docs/superpowers/specs/2026-11-08-small-supply-piles-design.md).
- For relay changes (`relay/`, `protocol/`), read the [relay stack spike](docs/reference/relay-stack-spike.md) and [relay scaling](docs/reference/relay-scaling.md). The wire protocol is fixed by `protocol/vectors` and the black-box suite in `protocol/conformance`; a relay change passes `go test -race ./...` and `golangci-lint run` in `relay/`, `sh tools/run_conformance.sh`, and the affected `tools/run_netplay.sh` scenarios. Deploying to fly needs explicit approval.
- Use [installation reference](docs/reference/installation.md) and other reference notes for evidence. Preserve confirmed, proposed, provisional and deferred labels; never invent approvals or playtests.
- Performance targets a low-end device and possibly a browser (WebAssembly), not the fast development machine. Budgets, assumptions and measurement history live in the [performance ledger](docs/reference/performance.md). A milestone exit gate is not met without a passing `sh tools/run_benchmark.sh`, a rendered benchmark rerun if presentation changed, and a new ledger row. Never loosen a budget or the assumed slowdown to make a row pass; report it as exceeded.
- Keep setup/current status in `docs/development.md`, design decisions in the blueprint, milestone implementation contracts in their execution plans, evidence in reference notes. Link rather than duplicate rules and numeric values.
- Inspect existing work before editing. Keep changes small; do not scaffold future systems or generic frameworks.

## Implementation

- Terminal-first: author, import and test through files and documented commands; no routine editor clicking.
- Keep Godot project under `game/`, repository tools outside it. `res://` resolves to `game/`. Follow the active milestone execution plan for exact paths and contracts.
- Use typed GDScript. Keep authoritative simulation separate from scenes, rendering, wall-clock time and networking callbacks. Advance it explicitly by ticks; inject randomness when needed.
- Adapt Hell's Verdict's wrappers and CI patterns without modifying that project. Keep Wargrid's planned renderer and tick rate; do not inherit FPS settings or server assumptions.
- Follow personal code-style, Superpowers, review and model-routing instructions. Do not import another project's agent models or workflow exceptions.
- Milestone runs follow [milestone prompt](docs/milestone-prompt.md): run as a coordinator with one fresh subagent per task, each starting from the verification file's resume record; stop at every stop gate.
- Edit files with the Edit tool or asserted replacements only; an unasserted replacement once dropped a cleanup call silently. Agent shells use BSD `sed` (`sed -i ''`). Scratch Godot scripts must `quit()` on every path, or a script error hangs until the shell timeout.

## Verification and desktop use

- Test output (Wargrid override of the global delegate-to-subagent rule): redirect suite and benchmark output to a file and read only the summary lines; on failure read only the failing lines. Use subagents for reviews, not for running tests.
- Plans list same-tick interaction cases for every new command (against every existing command and against removal) and a spec-worded test for every AI rule. Benchmarks assert that their mechanics run inside the timed window. HUD changes get a headless layout test. Report every check with the tree it ran on.
- Before reporting GDScript changes done, `sh tools/run_lint.sh` and `sh tools/run_warnings.sh` pass (new code is typed; tests are exempt from `untyped_declaration` only).
- Before reporting Python tooling changes done, `sh tools/run_python_checks.sh` passes (config in `tools/pyproject.toml`).
- Write meaningful behavior tests alongside mechanics. Keep small suites per system; fail on zero checks, parse errors, failed expectations and incomplete suites. Require successful exit plus final completion marker.
- Rendered benchmarks (`sh tools/run_game.sh res://scenes/movement_benchmark.tscn`) open a window: ask first, batch with other visible checks. They disable vsync themselves (header shows `vsync=off`) so frame intervals measure render cost, not display refresh.
- Pass `timeout: 600000` on every suite, benchmark, netplay, lint and parity call (the suite takes about 78 s; the default 120 s fired 57 times in two days); details in [milestone prompt](docs/milestone-prompt.md).
- Run commands before claiming they work. Report counts, exit status, unverified checks and reference gaps.
- Keep tests, replays and simulation benchmarks headless. Open a visible game window only when the user asks to play. Ask before screenshots or other rendering-dependent checks; batch such checks into one request.
- Separate internal correctness from reference fidelity. Record intentional fixes with regression tests; never silently widen tolerances or change expected results to hide failures.
- In any milestone, a mechanic Zero Hour also has can be measured with the [parity harness](docs/reference/zero-hour-parity-harness.md) (headless, silent, source build). Results are evidence for a decision list, never an automatic number change.
- For documentation-only changes, check links, paths, status labels and consistency. Automated tests do not establish game feel or measured performance.

## Reference handling and Git

- Keep EA source and installation backups outside this repository and unchanged. Record source revision or archive hash, internal path and uncertainty for findings. Read the source to learn behaviour, values and ideas for a close clone, then write Wargrid's own code: Zero Hour is full of bugs and slow paths. Wargrid is GPL-3.0-or-later (`LICENSE`), so porting GPL code (EA source, OpenRA, GeneralsGameCode) is legally allowed but the exception: only a small algorithm where our own version would be clearly worse, rewritten in typed GDScript, with a comment naming source repo, revision and path; ported EA code keeps EA's copyright line and a pointer to EA's additional terms. No bulk translation. Never copy EA assets, INI/map data, art, audio, text or trademarks into Wargrid. Exception (user, 2026-11-05): maps from EA's GPL-released `CnC_Modding_Support` may be converted by a repo tool into Wargrid map data; the output keeps EA's copyright line, a pointer to EA's additional terms and the source revision, and uses Wargrid's own map name.
- M0 and future ordinary CI must work without sibling projects or retail game data.
- Preserve user changes. Keep caches, build output, local environment files and temporary analysis out of tracked source.
- Do not commit, push, open a PR or merge without explicit approval, except local commits pre-authorized by the [milestone prompt](docs/milestone-prompt.md) during a milestone run. Subagents never commit or push. Never set `GITHUB_TOKEN` or `GH_TOKEN` in the shell or print secrets.
