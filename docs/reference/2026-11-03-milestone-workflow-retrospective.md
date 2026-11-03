# Milestone workflow retrospective (M0–M4)

Status: **PROPOSED, not adopted.** Nothing in AGENTS, prompts, plans or tooling has changed. Written 2026-11-03 by merging two independent reviews of the session transcripts:

- **Codex** reviewed the M0–M3 Codex sessions plus the M4 Claude sessions. It ran out of usage before measuring tokens.
- **Claude Code** reviewed the M4 Claude sessions, measured their tokens, then measured the Codex sessions too (see [measured usage](#measured-usage-per-milestone)).

Both drafts stayed outside the repository; this file is self-contained. Tags: **[both]** means both reviews found it independently; **[Codex]** or **[Claude]** means one review only. The [evidence](#evidence) section lists the transcript locations behind the claims.

## Ranked list

Ranked by expected effect on correctness first, then tokens and wall-clock time.

### 1. Restart sessions at checkpoints, resuming from one checkpoint record [both]

- **Problem:** no M4 Claude session ever compacted. Context grew from about 48 k to 300–450 k tokens, and each request re-read all of it. Separately, M2 and M4 both needed status reconstruction after an interruption because handoff documents disagreed.
- **Change:**
  - Use the milestone verification file as the single resume record, with these fields:

    ```text
    Branch / base commit / working-tree identity:
    Last green task / next incomplete task:
    Changed paths:
    Last command / case count / failures / exit / marker / log:
    Known red case or blocker:
    Approved decisions and deferred gates:
    Next exact action:
    ```
  - A commit hash alone does not identify uncommitted work: record changed paths too. On resume, inspect the live diff and the record, run one baseline, and reopen design only on conflicting evidence.
  - End the session at every stop gate and after any long side topic. Restart with `/clear` plus "resume from `prompt.txt`", and have `prompt.txt` point at the record instead of copying its state.
- **Effect:** a restart simulation on the M4 sessions gives 40–66% fewer tokens processed. Real savings are somewhat lower, since each restart re-reads the record.

### 2. Prove risky contracts early, with interaction tests [both]

- **Problem:** the defects that escaped TDD were interactions:
  - M4: same-tick attack plus cancel (crash); opponent policy against combat state; A/S keys against camera pan; HUD text against buttons.
  - M3 review: lost Cancel clicks; collector admission order.
- **Change:**
  - Before planning dependent tasks, name the few expensive failure modes and write their failing tests or small probes first.
  - Every new command gets same-tick rows against every existing command and against removal.
  - Every AI rule gets a test using the spec's own wording.
  - Give the implementer a compact task contract instead of prose (Codex's example):

    ```text
    Task: remove a combat target safely
    Owns: shared removal path + combat references + regression case
    Invariant: no later phase dereferences removed ID
    Boundary: attack and target cancellation due on same tick
    Red: named behavioral assertion, not parser failure
    Green: named test + affected lifecycle suite
    Stop: required phase order would change approved contract
    ```
  - Tests must reject plausible mistakes, not just observe output. In M1, a click test accepted cell-centre snapping, a diagonal-pan test missed Y movement, and a sort fixture could not detect ordering. Ask the reviewer which production change makes each new test fail, and run targeted mutations when a green test's value is unclear. No mutation campaigns on trivial changes.

### 3. Keep independent review, narrowed to the delta [both]

- **Evidence:** every review paid off. M1 found three regressions; M3 found two defects. M4's three Opus reviews each found a real defect at about 3% of a session's tokens.
- **Change:**
  - One reviewer at a time.
  - Give it the changed contracts, previous rulings and the diff scope, as M4's later reviews did.
  - Pick a known working reviewer route at the start. An empty or one-line report counts as a failed review: fall back at once and record it. Grok failed this way in both M3 and M4.

### 4. Measure the new workload as soon as the mechanic exists [both]

- **Evidence:** M4's early 150-v-150 spike, 7.5–9× over budget, drove the throttling fix. The final `contact` layout first measured nothing: its infantry never fired.
- **Change:** every benchmark states which mechanics must happen inside the timed window, and asserts them. Startup, mass-order, placement and death spikes are measured separately. An unrepresentative workload is reported, never quietly changed.

### 5. One implementer in the main session [Codex]

- **Evidence:** the M2/M3 coordinator made 82 `wait_agent` calls relaying another agent's progress. M4 already ran sequentially in the main session.
- **Change:** keep that as the default. Delegate only bounded research and reviews.

### 6. Pre-authorize routine gates [both]

- **Evidence:** about a third of the user prompts in the main M4 session were routine approvals: request a review, commit, close a window.
- **Change:** keep an approval record in the checkpoint (Codex), and write pre-authorizations into the milestone prompt (Claude):
  - dispatch the review subagent at each gate;
  - commit locally after each green checkpoint;
  - close any window it opens.
- **Unchanged:** push, PR, merge and visible checks keep their separate approval.

### 7. Load context once, in bounded sections [both]

- **Evidence:** M3 and M4 startups dumped whole documents. The 59 KB M4 plan came back as a truncated preview and needed three more reads.
- **Change:**
  - Read headings first, then non-overlapping ranges.
  - During implementation, reload only the active task, the interfaces it touches and decisions changed since the last read. A per-task brief file is one way to do that.
  - Keep exact contracts in the plan, and move large sketches to appendices.

### 8. Validate the measuring tools before trusting them [Codex]

- **Evidence:** a CI workflow failed remotely on an unsupported expression that `actionlint` would have caught. The rendered benchmark logged a script error every physics tick and still exited 0.
- **Change:**
  - Lint workflows before publishing.
  - Every benchmark or debug scene gets a cheap headless smoke test.
  - Require silent diagnostics plus a completion marker.

### 9. Claim only what was checked on the final tree [Codex]

- **Evidence:** M4's handoff said "passes every headless check" although the outside-root, fresh-cache and replay runs predated the last fixes. The caveat was there; the headline overstated it.
- **Change:**
  - Report each check with the tree it ran on, e.g. "ordinary suite passes; final-tree replay and cache checks pending".
  - Use a verification ladder: focused red/green during a task, the affected suite after integration, all mandated milestone gates after review fixes.
  - Track named behaviors, not raw assertion counts: longer loops alone added 45 checks in M3.

### 10. Bring one visible slice forward [both]

- **Evidence:** M2's rendered run found 3 fps late. The M4 playtest found the HUD overlap and the missing focus feedback.
- **Change:**
  - At kickoff, offer one batched decision covering an early visible slice plus final validation.
  - Meanwhile, add headless layout tests (no overlapping controls), which catch some of what only a window showed.

### 11. Trim the fixed per-request baseline [Claude]

- **Evidence:** about 48 k tokens are re-read on every request before any work. The skill listing alone is 48.5 KB, and almost none of those skills apply to this project.
- **Change:** disable irrelevant plugins and skills in project settings, and remove rules duplicated between `AGENTS.md` and the global instructions.
- **Effect:** each 10 k tokens removed saves about 4% of M4's main-session volume.

### 12. Shell and environment hygiene [both]

- **Change:**
  - Edits always go through the Edit tool or asserted replacements. An unasserted replacement silently dropped a combat cleanup call in M4 and caused a later crash.
  - BSD `sed -i ''` only.
  - Scratch Godot scripts must `quit()` on every path. One hung for the full 120 s timeout.
  - Fix sandbox and approval friction once in the runner handoff (Codex, M1), not per command.

### 13. Keep source evidence and retail fidelity separate [Codex]

- **Why:** a replay can reproduce the same wrong rule, and a source-derived value need not match retail timing, animation or feel.
- **Change:**
  - At planning, list only the new fidelity questions and reuse pinned evidence for unchanged values.
  - Automate source/config comparisons. `tools/check_reference.py` now does this for unit, building, weapon and armor values.
  - Keep retail checks small and concrete: level 1 is reduced to three spot checks.
  - Never present source-only checks as retail validation.

### 14. One status home [both]

- **Change:**
  - Details live only in the verification file, as dated evidence.
  - README, plan and session notes carry one current-status line each, updated at milestones and handoffs, not after every assertion.

### 15. Record usage for a real baseline [Codex]

- **Change:**
  - At each milestone's start and end, record input, cached input, output, model, task scope and review scope.
  - Also record interruptions, failed tool calls, empty waits, escaped defects and time waiting for user decisions.
- **Why:** the [measured usage](#measured-usage-per-milestone) below is a first baseline for M0–M4. Without a baseline, no saving above can be confirmed; the next milestone compares against it.
- **Success criteria for the next milestone:**
  - less repeated context loading and coordination;
  - no increase in escaped defects;
  - final-tree verification retained;
  - fewer manual recovery or status repairs.

## Measured usage per milestone

Filled in 2026-11-03 by Claude Code, completing the usage section Codex left unfinished. Sources:
- **Codex:** the last cumulative `token_count` record of every Wargrid rollout in `~/.codex/sessions/2026/`. Child threads are attributed to their root thread, and "tokens processed" is `input_tokens`, which includes cached input.
- **Claude Code:** input + cache read + cache creation per API request, counted once per request.

The two harnesses use different models and tokenizers, so compare shapes, not exact amounts. The retrospective sessions themselves are excluded.

| Milestone | Harness | Phase (root session, local start time) | Tokens processed | Requests |
|---|---|---|---:|---:|
| M0 | Codex | blueprint improvement (11-01 09:45) | 11.1 M | 93 |
| M0 | Codex | implementation, 8 threads (11-01 10:43) | 23.8 M | 274 |
| M0 | Codex | wrap-up (11-01 12:05) | 0.9 M | 23 |
| M1 | Codex | implementation, 8 threads (11-01 16:04) | 40.0 M | 459 |
| M1 | Codex | follow-up docs (11-01 16:35) | 0.9 M | 17 |
| M2 | Codex | status check and recovery, 5 threads (11-02 15:52) | 9.0 M | 141 |
| M2 | Codex | implementation children (11-02 16:43–17:12) | 13.9 M | 161 |
| M3 | Codex | implementation children (11-03 07:41–09:47) | 43.9 M | 397 |
| M2+M3 | Codex | coordinator thread over both (11-02 16:42 to 11-03 09:47); 85 transcript lines mention `wait_agent` | 13.1 M | 182 |
| M4 | Codex | plan, 3 threads (11-03 14:57) | 4.7 M | 67 |
| M4 | Claude | plan finish, performance work, executor prep (A) | 32.8 M | 147 |
| M4 | Claude | Tasks 1–4 and review planning (B) | 16.2 M | 80 |
| M4 | Claude | Tasks 4d–10 up to the gate report (C, before line 1350) | 29.6 M | about 130 |
| M4 | Claude | three review subagents | 5.7 M | 61 |

Codex totals over 41 Wargrid files: output 0.61 M plus 0.14 M reasoning, against 167.8 M input of which 165.2 M (98.4%) was cached. Claude's M4 sessions show the same shape: output under 1%.

What the numbers show:
- **Implementation costs about the same per milestone in both harnesses:** M0 implementation 24 M, M1 40 M, M3 about 44–57 M (depending on the coordinator share), M4 implementation 51.5 M (B + C + reviews). M4's scope was the largest.
- **M4's planning and preparation (37.5 M: Codex plan plus Claude session A) cost almost as much as its implementation.** Session A also contained performance work and the Zero Hour verification plan, which outlive M4, so this is an upper bound for "planning".
- **Re-reading context dominates everywhere:** 98% cached input in Codex and over 99% non-output in Claude. Item 1 applies to both harnesses.
- **The Codex coordinator cost 13.1 M** (about 18% of the M2+M3 root group), for relaying the children's progress. That is item 5's saving.
- **The largest single threads** are the M1 Codex main thread (214 requests, context up to 280 k) and Claude C (context up to 447 k). Both are the long-session pattern item 1 targets.

Limits: Codex's M2/M3 coordinator can't be split between the two milestones; child threads may inherit parent context in ways the totals don't separate; and no money figures.

## Settled differences

| Topic | Codex | Claude | Settled as | Reason |
|---|---|---|---|---|
| Biggest cost lever | flatten the coordinator | restart at checkpoints | **both**: items 5 and 1 | Different harnesses had different waste: Codex relayed through a coordinator, Claude grew one huge context. Item 5 is already M4's default, so item 1 is the new change. |
| Test runs | one narrow test worker | redirect output to a file and read the summary in the main session | **redirect in the main session for Claude Code; a worker only where it runs on a cheaper tier and starts small** | Both aim to keep raw logs out of context. In Claude Code a subagent starts with the full ~48 k baseline, so about 75 M4 runs via redirect cost far less. Codex's cheap-tier worker may still pay off in Codex. |
| Inner-loop suite filter | don't build one to save seconds | add a filter | **defer, with a trigger**: add a filter when the full suite exceeds 30 s | At 13 s, M4 spent about 13 minutes per session waiting, with no token cost. Codex is right that it isn't worth the code yet. |
| Grok as reviewer | choose a known working route up front | treat an empty review as failed | **both** (item 3) | They're complementary: choose a working route, and still detect an empty result. |

## Not covered

- Splitting the Codex M2/M3 coordinator cost between the two milestones.
- Costs in money.
- Whether either set of changes reduces escaped defects. Item 15's baseline is what would show that, by comparing the next milestone against M4.

## Evidence

Transcript paths are local to this machine and are not part of the repository. Line numbers are JSONL lines.

**Claude Code** (`~/.claude/projects/-Users-pdstuber-projects-wargrid/`):

| Short | File | Claims |
|---|---|---|
| A | `02fa9e69-3ff4-42f7-9468-5b2a5a41bf28.jsonl` | M4 plan finish, performance, prep; context 47.5 k to 401 k |
| B | `0e86fa79-3ebb-41d4-833b-1f06a6ad76a7.jsonl` | Tasks 1–4; 150-v-150 spike at line 543 |
| C | `89c7cb45-5a77-4ad3-82f5-0c13014ed500.jsonl` | Tasks 4d–10; baseline attachments at lines 24–27; stumbles at lines 158, 197, 1303, 1412, 1553, 1564; review hand-backs near lines 415, 764, 1132; user playtest at line 1828 |
| C reviews | `89c7cb45-…/subagents/agent-a80a610700f06017a.jsonl`, `agent-acf1f2e720ce14eec.jsonl`, `agent-a2cfad27ff8039c26.jsonl` | the three Opus reviews |

Repository: review findings in `docs/reference/m4-verification.md` (lines 28, 40, 52), the 4d ruling (line 21), the playtest (line 72), and the Task 5 pre-check (plan line 225).

**Codex** (`~/.codex/sessions/2026/`), as cited by its review:

| Claim | Location |
|---|---|
| M1 review found regressions; weak M1 assertions | `11/01/rollout-2026-11-01T16-16-02-01a197ae-8f7c-7fd3-8b57-0a59ecc44ce8.jsonl:248` |
| M1 sandbox and approval friction | `11/01/rollout-2026-11-01T16-04-30-01a197a4-01ef-79a3-8b8c-30684b1b7508.jsonl:268` |
| M3 review defects | `11/03/rollout-2026-11-03T08-32-49-01a1a053-320e-7211-85ae-16b13449797c.jsonl:215` |
| M2/M3 coordinator waits | `11/02/rollout-2026-11-02T16-42-24-01a19ced-0edc-78a0-8563-9d2512d52973.jsonl:713` |
| delayed M2 rendered run | same file, line 606 |
| CI workflow expression failure | same file, line 891 |
| M3 startup truncated reads | `11/03/rollout-2026-11-03T07-45-56-01a1a028-4481-7883-978c-9ed0de616ea3.jsonl:41` |
| rendered benchmark script errors with exit 0 | `docs/reference/m2-verification.md:117` |
| assertion count is not coverage | `docs/reference/m2-verification.md:146` |
| internal correctness vs retail fidelity | `docs/reference/m2-verification.md:60` |
