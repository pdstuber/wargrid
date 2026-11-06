"""Token usage of Claude Code sessions and Codex rollouts, for the milestone resume record.

"processed" is everything the model read per request (fresh + cached input), summed: the volume
that grows with session length. It is not a price.
    python3 tools/session_usage.py ~/.claude/projects/<project>/<session>.jsonl ~/.codex/sessions/2026/11/03/rollout-*.jsonl
"""

import collections
import json
import sys
from pathlib import Path


def _events(path: Path):
    with open(path) as handle:
        for line in handle:
            try:
                yield json.loads(line)
            except ValueError:
                continue


def claude(path: Path) -> dict:
    seen, contexts, output, models = set(), [], 0, collections.Counter()
    for event in _events(path):
        if event.get("type") != "assistant":
            continue
        message = event.get("message") or {}
        request = event.get("requestId") or message.get("id")
        if request in seen:
            continue
        seen.add(request)
        used = message.get("usage") or {}
        contexts.append(
            sum(
                used.get(key) or 0 for key in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens")
            )
        )
        output += used.get("output_tokens") or 0
        if message.get("model"):
            models[message["model"]] += 1
    return {
        "processed": sum(contexts),
        "requests": len(contexts),
        "output": output,
        "models": dict(models),
        "first_context": contexts[0] if contexts else 0,
        "max_context": max(contexts, default=0),
    }


def codex(path: Path) -> dict:
    result = {
        "thread": None,
        "parent": None,
        "processed": 0,
        "cached": 0,
        "output": 0,
        "requests": 0,
        "max_context": 0,
        "models": {},
    }
    models = collections.Counter()
    for event in _events(path):
        payload = event.get("payload") or {}
        if event.get("type") == "session_meta":
            result["thread"] = payload.get("id")
            source = payload.get("source")
            if isinstance(source, dict):
                result["parent"] = ((source.get("subagent") or {}).get("thread_spawn") or {}).get("parent_thread_id")
        elif event.get("type") == "turn_context" and payload.get("model"):
            models[payload["model"]] += 1
        elif payload.get("type") == "token_count" and payload.get("info"):
            total = payload["info"]["total_token_usage"]
            result.update(
                processed=total.get("input_tokens", 0),
                cached=total.get("cached_input_tokens", 0),
                output=total.get("output_tokens", 0),
            )
            result["requests"] += 1
            result["max_context"] = max(
                result["max_context"], (payload["info"].get("last_token_usage") or {}).get("input_tokens", 0)
            )
    result["models"] = dict(models)
    return result


def group_codex(threads: list) -> dict:
    by_id = {thread["thread"]: thread for thread in threads}

    def root(thread):
        hops = 0
        while thread["parent"] in by_id and hops < 20:
            thread, hops = by_id[thread["parent"]], hops + 1
        return thread["thread"]

    groups = {}
    for thread in threads:
        group = groups.setdefault(root(thread), {"processed": 0, "output": 0, "requests": 0, "threads": 0})
        group["processed"] += thread["processed"]
        group["output"] += thread["output"]
        group["requests"] += thread["requests"]
        group["threads"] += 1
    return groups


def _kind(path: Path) -> str:
    for event in _events(path):
        if event.get("type") == "session_meta" or (event.get("payload") or {}).get("type") == "token_count":
            return "codex"
        if event.get("type") == "assistant":
            return "claude"
    return ""


def main(argv: list, out=sys.stdout) -> int:
    if not argv:
        print(__doc__, file=out)
        return 2
    total, codex_threads = 0, []
    for name in argv:
        path = Path(name)
        kind = _kind(path)
        if kind == "claude":
            result = claude(path)
            total += result["processed"]
            print(
                "claude %s processed=%d requests=%d first_context=%d max_context=%d output=%d models=%s"
                % (
                    path.name,
                    result["processed"],
                    result["requests"],
                    result["first_context"],
                    result["max_context"],
                    result["output"],
                    result["models"],
                ),
                file=out,
            )
        elif kind == "codex":
            codex_threads.append(codex(path))
        else:
            print("unrecognized session file: %s" % name, file=out)
            return 1
    for thread_id, group in group_codex(codex_threads).items():
        total += group["processed"]
        print(
            "codex %s processed=%d requests=%d threads=%d output=%d"
            % (thread_id, group["processed"], group["requests"], group["threads"], group["output"]),
            file=out,
        )
    print("TOTAL processed=%d" % total, file=out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
