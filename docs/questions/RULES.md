# Shared rules for the question-research agents (2026-11-08)

Context: Wargrid (/Users/pdstuber/projects/wargrid) is a Godot isometric RTS that should feel very close to Command & Conquer: Generals – Zero Hour (ZH), with its own code. The user gives game-design input through a wizard: MANY EASY questions, one at a time, each answerable in seconds. Your job is research that turns into such questions. You never decide game design yourself.

- Read-only except your question file in `docs/questions/` (moved into the repo 2026-11-09). Never commit, never run Godot or the ZH game. The repository is public: cite sources as path:line, never paste decoded INI blocks or EA source. `rg`, file reads and `python3 -I` scripts on copies are fine.
- Primary sources only: code and data, cited as path:line. ZH source: ~/projects/CnC_Generals_Zero_Hour @ 0a05454 (GeneralsMD/Code/...). Patched fork for cross-checks: ~/projects/GeneralsGameCode. OpenRA: ~/projects/OpenRA. Recoil (Spring): ~/projects/RecoilEngine. Retail ZH config: root INIZH.big under "$HOME/CnC/run/Command & Conquer Generals - Zero Hour/", query it through `python3 tools/zh_ini.py dump` (output `build/zh_ini/inizh.jsonl`, gitignored; cite entry:line), never a hand-written decoder and never paste the output into the repo. Run the dump without `-I` (it imports `check_reference`); writing under `build/` is allowed.
- Mark every claim as **source** (with path:line) or **inferred**. If you could not find something, say "not found" rather than guessing.
- Write your result to the file your prompt names, in this shape:

```
# <topic>
## Findings (short, cited)
- ...
## Questions
Q1. <one plain sentence, no jargon>
   a) <option> — ZH default (path:line)   b) <option>   c) <option>
   Recommendation: <letter>, because <one line>. Why it matters: <one line>.
```

- 8 to 15 questions. Each question is ONE choice with 2-4 concrete options. Split anything compound into several questions. Order them from most to least important. Put the ZH behaviour first as an option whenever it exists, labelled "ZH default". Gameplay should play like ZH; UI/UX may improve on it (user, 2026-11-09): for interface, controls and feedback questions also offer what modern RTS games do (cite the game and a primary source), and do not recommend the ZH option just because it is ZH.
- Skip anything already decided: check docs/blueprint.md §7 and §14 and docs/session-notes.md "Deferred experiments and research" for existing user decisions, and do not ask those again.
- Return to the coordinator at most 6 lines: the file path, the number of questions, and the single most surprising finding.
