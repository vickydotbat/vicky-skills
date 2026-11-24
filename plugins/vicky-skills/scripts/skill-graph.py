#!/usr/bin/env python3
"""The skill graph: each real hand-off from one skill to another.

    skill-graph.py list  <skills folder>               print every hand-off
    skill-graph.py check <skills folder>  exit 1 when a skill's
                                          hands-off field and steps differ

A hand-off is a verb that passes the work on (run, start, dispatch, load,
follow, engage, then, hand ... to, go to, through, with) followed by a skill's
name in backticks, or a list of them, in any Markdown file of the skill. A
negated verb ("never run") and a verb led by another skill as its subject are
no hand-off. A skill named any
other way ("`do` runs this skill") is a mention, not a hand-off. Each skill
declares its hand-offs in a frontmatter field, `hands-off: [a, b]`, and the
check compares that field with the steps.
"""
import pathlib
import re
import sys

# shortcut: a bare "with" also reads "files with `do`" as a hand-off; no skill
# says that today, and "write it with `human-voice`" needs the bare word.
VERB = (
    r"(?:runs?|running|start(?:s|ed)?|dispatch(?:es)?|loads?|follows?|engages?|then|through|with"
    r"|go(?:es)?\s+(?:back\s+)?to|hand(?:s|ed)?\b[^.`]{0,40}?\b(?:to|with))"
)
NEGATION = re.compile(r"\b(?:never|not|don't)\b", re.IGNORECASE)


def hand_offs(folder):
    skills = {p.parent.name: p.parent for p in pathlib.Path(folder).glob("*/*/SKILL.md")}
    # Skill names match in their own case only.
    name = r"(?-i:`(?:" + "|".join(re.escape(n) for n in sorted(skills, key=len, reverse=True)) + r")`)"
    # A verb, not led by another skill as its subject, then one skill or a list
    # of them joined by "and", "or", commas or slashes.
    pattern = re.compile(
        r"\b" + VERB + r"\s+(?:the\s+)?(" + name + r"(?:\s*(?:,|/|\band\b|\bor\b)\s*" + name + r")*)",
        re.IGNORECASE,
    )
    edges = set()
    for skill, home in skills.items():
        for path in home.rglob("*.md"):
            text = path.read_text(encoding="utf-8")
            if text.startswith("---\n"):
                text = text.split("\n---\n", 1)[-1]
            # A fenced block counts too: a subagent's brief hands off inside one.
            # A line wrapped mid-sentence joins the next, unless that starts a new block.
            text = re.sub(r"\n(?![ \t]*(?:\n|\d+\.|[-*#|>]))", " ", text)
            for sentence in re.split(r"(?<=[.;:!?])\s+|\n", text):
                for match in pattern.finditer(sentence):
                    before = sentence[: match.start()]
                    # "never run", "do not, at any point, start": a negation in the six words before the verb.
                    if NEGATION.search(" ".join(before.split()[-6:])):
                        continue
                    # "when `h` runs `i`": the verb's subject is another skill.
                    if re.search(name + r"\s*$", before):
                        continue
                    targets = re.findall(r"`([^`]+)`", match.group(1))
                    # "with `t`'s SETTLE.md" points into a file t owns, not at t.
                    if sentence[match.end():].startswith(("'s", "’s")):
                        targets = targets[:-1]
                    for target in targets:
                        if target != skill:
                            edges.add((skill, target))
    return edges


def declared(folder):
    """Each skill's hands-off frontmatter field, as (skill, target) pairs, and
    a line for each field the check cannot read."""
    edges, problems = set(), []
    for path in pathlib.Path(folder).glob("*/*/SKILL.md"):
        text, skill = path.read_text(encoding="utf-8"), path.parent.name
        front = text.split("\n---\n", 1)[0] if text.startswith("---\n") else ""
        lines = re.findall(r"^hands-off:.*$", front, re.MULTILINE)
        if len(lines) > 1:
            problems.append(f"skill-graph: {skill} has more than one hands-off line: keep one")
        for line in lines[:1]:
            field = re.fullmatch(r"hands-off:\s*\[(.*)\]\s*", line)
            if not field:
                problems.append(f"skill-graph: {skill}: write hands-off as [a, b] on one line")
                continue
            for target in re.findall(r"[^,\s\"']+", field.group(1)):
                edges.add((skill, target))
    return edges, problems


def check_declared(folder):
    skills = {p.parent.name for p in pathlib.Path(folder).glob("*/*/SKILL.md")}
    listed, problems = declared(folder)
    found = hand_offs(folder)
    for line in problems:
        print(line)
    bad = 1 if problems else 0
    for a, b in sorted(found - listed):
        print(f"skill-graph: {a} hands off to {b}: add {b} to hands-off in the frontmatter of {a}")
        bad = 1
    for a, b in sorted(listed - found):
        if b not in skills:
            print(f"skill-graph: {a} lists {b} in hands-off, and no skill {b} exists")
        else:
            print(f"skill-graph: {a} lists {b} in hands-off, and no step of {a} hands off to {b}")
        bad = 1
    return bad


def main(argv):
    if len(argv) == 3 and argv[1] == "check":
        return check_declared(argv[2])
    if len(argv) == 3 and argv[1] == "list":
        for a, b in sorted(hand_offs(argv[2])):
            print(f"{a}\t{b}")
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
