# Roadmap wording

The README roadmap is generated from [`roadmap.toml`](roadmap.toml) by `python3 tools/roadmap.py`. State and wording are edited only in that file, never in the README block. Each row's `name` is plain words for players, not a blueprint label. The user settles wording with this prompt (`/roadmap-wording`).

1. List the rows with `wording = "draft"` (`rg -n -B5 'wording = "draft"' docs/roadmap.toml`). None: say so and stop.
2. Ask with `AskUserQuestion`, up to 4 rows per call, one short question per row: the row's candidates as the options (first option = your recommendation, labelled "(Recommended)"), the current `state` named in the question so the user can object to it. The user can pick "Other" to type their own words. Do not ask about anything else in the same call.
3. After each answer, write it at once: set `name` to the chosen text, `wording = "approved"`, delete the `candidates` line. If the user also corrects the `state`, change it (at most one row may be `next`).
4. When a new milestone is added to the blueprint, add a row here first (`wording = "draft"`, 2 or 3 candidates you propose, its blueprint id in `blueprint`), then run this prompt.
5. Run `python3 tools/roadmap.py`, then `python3 tools/roadmap.py --check` (must exit 0) and show the rendered table in the reply. A planned or idea row never promises a date or a feature; keep the blueprint's "not designed" and "not approved" labels as `planned` or `idea`.

Do not commit or push; the user approves that separately.
