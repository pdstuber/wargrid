import json
import sys


def _walk(a, b, path):
    if type(a) is not type(b) and not (isinstance(a, (int, float)) and isinstance(b, (int, float))):
        return f"{path}: {a!r} != {b!r}"
    if isinstance(a, dict):
        for key in sorted(set(a) | set(b)):
            if key not in a or key not in b:
                return f"{path}.{key}: {'missing' if key not in a else 'present'} on first"
            found = _walk(a[key], b[key], f"{path}.{key}")
            if found:
                return found
        return None
    if isinstance(a, list):
        for i in range(max(len(a), len(b))):
            if i >= len(a) or i >= len(b):
                return f"{path}[{i}]: length {len(a)} != {len(b)}"
            found = _walk(a[i], b[i], f"{path}[{i}]")
            if found:
                return found
        return None
    return None if a == b else f"{path}: {a!r} != {b!r}"


def first_difference(first: dict, second: dict) -> str | None:
    for key in ("command_log", "snapshot"):
        found = _walk(first.get(key), second.get(key), key)
        if found:
            return found
    return None


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("usage: desync_diff.py A.json B.json", file=sys.stderr)
        sys.exit(2)
    reports = []
    for path in sys.argv[1:]:
        with open(path) as handle:
            reports.append(json.load(handle))
    difference = first_difference(*reports)
    if difference is None:
        print("IDENTICAL")
        sys.exit(0)
    print(difference)
    sys.exit(1)
