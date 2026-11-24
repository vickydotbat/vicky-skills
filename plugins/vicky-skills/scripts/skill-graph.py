#!/usr/bin/env python3
"""The skill graph: each real hand-off from one skill to another.

    skill-graph.py list  <skills folder>               print every hand-off
    skill-graph.py check <skills folder> <GRAPH.tsv>   exit 1 on a difference

A hand-off is a verb that passes the work on (run, start, hand ... to, go to,
through, with) followed by a skill's name in backticks. A skill named any
other way ("`do` runs this skill") is a mention, not a hand-off. GRAPH.tsv
holds one hand-off per line: the skill that hands off, a tab, the skill it
hands to.
"""
import pathlib
import re
import sys

VERB = r"(?:\b(?:runs?|running|start(?:s|ed)?|through|with|go(?:es)?\s+(?:back\s+)?to|hand(?:s|ed)?\b[^.`]{0,40}?\b(?:to|with))\s+(?:the\s+)?)"


def hand_offs(folder):
    skills = {p.parent.name: p for p in pathlib.Path(folder).glob("*/*/SKILL.md")}
    names = "|".join(re.escape(n) for n in sorted(skills, key=len, reverse=True))
    pattern = re.compile(VERB + r"`(" + names + r")`")
    edges = set()
    for name, path in skills.items():
        text = path.read_text(encoding="utf-8")
        body = text.split("\n---\n", 1)[1] if text.startswith("---\n") else text
        for target in pattern.findall(body):
            if target != name:
                edges.add((name, target))
    return edges


def main(argv):
    if len(argv) == 3 and argv[1] == "list":
        for a, b in sorted(hand_offs(argv[2])):
            print(f"{a}\t{b}")
        return 0
    if len(argv) != 4 or argv[1] != "check":
        print(__doc__.strip(), file=sys.stderr)
        return 2
    found = hand_offs(argv[2])
    listed = set()
    for line in pathlib.Path(argv[3]).read_text(encoding="utf-8").splitlines():
        if line.strip():
            a, _, b = line.partition("\t")
            listed.add((a.strip(), b.strip()))
    bad = 0
    for a, b in sorted(found - listed):
        print(f"skill-graph: missing arrow: {a} hands off to {b}, add \"{a}<tab>{b}\" to {argv[3]}")
        bad = 1
    for a, b in sorted(listed - found):
        print(f"skill-graph: stale arrow: {a} -> {b}, no step of {a} hands off to {b}: delete the line from {argv[3]}")
        bad = 1
    return bad


if __name__ == "__main__":
    sys.exit(main(sys.argv))
