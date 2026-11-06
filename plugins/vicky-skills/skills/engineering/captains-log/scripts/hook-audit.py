"""Count each hook's refusals in recent Claude Code session logs, and what the agent did next.

    python3 hook-audit.py [days] [logs folder]

A refusal is a tool result whose text names `scripts/<hook>.sh` in a hook
error. The agent's next tool call before the user speaks is sorted into:
retry-passed (a call like the refused one that went through), retry-refused
(one refused again), other-call, other-refused, skill (it started a skill) or
stopped (no call before the user spoke). Prints one line per hook, most
refusals first.
"""
import collections
import difflib
import glob
import json
import os
import re
import sys
import time

HOOK = re.compile(r'hook error: \[\\?"[^\]]*scripts/([a-z0-9-]+)\.(?:sh|py)')


def events(path):
    calls, seq = {}, []
    for line in open(path, errors="ignore"):
        try:
            d = json.loads(line)
        except ValueError:
            continue
        m = d.get("message") if isinstance(d.get("message"), dict) else {}
        content = m.get("content") if isinstance(m.get("content"), list) else []
        if d.get("type") == "user" and isinstance(m.get("content"), str):
            seq.append(("user",))
        for x in content:
            if x.get("type") == "tool_use":
                calls[x["id"]] = x
                seq.append(("use", x))
            elif x.get("type") == "tool_result":
                t = x.get("content")
                seq.append(("res", x.get("tool_use_id"), t if isinstance(t, str) else json.dumps(t)))
            elif x.get("type") == "text" and d.get("type") == "user":
                seq.append(("user",))
    return calls, seq


def outcome(refused, seq, k):
    nxt = None
    for e in seq[k + 1:k + 12]:
        if e[0] == "user":
            break
        if e[0] == "use" and nxt is None:
            nxt = e[1]
        elif nxt and e[0] == "res" and e[1] == nxt["id"]:
            again = bool(HOOK.search(e[2][:400]))
            if nxt["name"] == "Skill":
                return "skill"
            same = difflib.SequenceMatcher(None, json.dumps(refused["input"])[:600], json.dumps(nxt["input"])[:600]).ratio() > 0.6
            return ("retry-" if same else "other-") + ("refused" if again else "passed" if same else "call")
    return "skill" if nxt and nxt["name"] == "Skill" else "stopped"


def main():
    days = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    root = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~/.claude/projects")
    cut = time.time() - days * 86400
    counts = collections.defaultdict(collections.Counter)
    for path in glob.glob(os.path.join(root, "**", "*.jsonl"), recursive=True):
        if os.path.getmtime(path) < cut:
            continue
        calls, seq = events(path)
        for k, e in enumerate(seq):
            if e[0] != "res":
                continue
            m = HOOK.search(e[2][:400])
            if not m:
                continue
            counts[m.group(1)]["refusals"] += 1
            if e[1] in calls:
                counts[m.group(1)][outcome(calls[e[1]], seq, k)] += 1
    if not counts:
        print(f"no hook refusals in {days} days")
    for hook, c in sorted(counts.items(), key=lambda x: -x[1]["refusals"]):
        print(hook, " ".join(f"{k}={v}" for k, v in c.most_common()))


if __name__ == "__main__":
    main()
