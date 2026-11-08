# Kickoff

Start a Wargrid work day in any agent and a clean session. `AGENTS.md` holds standing rules; this file says where to resume.

1. During a milestone run, read `AGENTS.md` and the active verification file's resume record first and follow [milestone prompt](milestone-prompt.md) instead of the rest of this list. Otherwise read `AGENTS.md`, `docs/development.md`, then `docs/session-notes.md`: Session, Pending user action, Deferred experiments and research, Next action, and newest dated sections. Treat confirmed decisions as settled; do not re-ask them. Read only relevant blueprint sections and the active execution plan before changing implementation.
2. Run `git status --short` and, if HEAD exists, `git log --oneline -5`. Inspect `game/` and `tools/` for work in flight. Preserve untracked user work; no HEAD means no commits yet, not a broken project.
3. Give a three-to-five-line recap: last completed work, work in flight, and anything waiting on the user. Ask one question about today's work, offering two or three options from the notes. Use a selector tool when available. If the user already supplied a task, resume that task without asking them to choose again.
4. During the day, ask one focused question when a decision is needed. Challenge weak ideas before implementing them. Record confirmed answers, hypotheses and verification evidence at checkpoints in `docs/session-notes.md`. Keep authoritative setup in `docs/development.md`, design decisions in the blueprint, implementation contracts in the execution plan, and evidence in reference notes; link rather than duplicate.
5. Never commit, push, open a PR or merge without explicit approval. Do not promote proposals or invent playtests. Stop at the active milestone's exit gate.
6. End with `/wrapup` (`docs/wrapup.md`), which checks the documents and notes this file reads.
