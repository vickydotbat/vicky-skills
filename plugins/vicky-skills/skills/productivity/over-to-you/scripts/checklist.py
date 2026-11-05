#!/usr/bin/env python3
"""Write an over-to-you checklist from a JSON spec, in the one form the page reads.

    python3 checklist.py <spec.json> <out.md>

The spec:

    {"name": "<user>", "brief": ["what this sitting is for", "..."],
     "open": "what to open, where, on which branch",
     "sitting": [1, 2],                      # optional: sitting 1 of 2
     "signed_off": "nothing yet", "proven_by": "`health.sh` answers ok",
     "sections": [{"title": "Pack", "items": [
        {"do": "Spawn the paper", "see": "the sheet shows",
         "person": "real client", "kit": "`/runscript paper` as a DM",
         "source": "scripts/paper.nss in the module"}]}],
     "extra": "checks run outside the list"}

Writes the file and exits 0, or prints `<problem>` lines and exits 1 without
writing: a missing field, more than seven items, or anything lint-checklist.py
refuses. The agent never types the checklist by hand.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [HERE, os.path.join(HERE, "..", "..", "interactive-page", "scripts")]
from importlib import import_module

loose_page = import_module("scratch").loose_page

_lint = import_module("lint-checklist")
lint, opted_out = _lint.lint, _lint.opted_out
LABELS = import_module("page").LABELS

# The legend a person reads when the file opens in an editor; the page draws its own labels.
LEGEND = "Mark each item: " + ", ".join(f"[{mark}] {label}" for mark, label in LABELS.items()) + "."
TAGS = ["BUG", "QUIRK", "FRICTION", "UGLY", "IDEA", "RULE", "WIP", "QUESTION"]
LIMIT = 7


def quick_notes():
    return ["quick notes:"] + [f"- {tag}:" for tag in TAGS]


def render(spec):
    problems = []
    for key in ("name", "open", "signed_off", "proven_by", "sections"):
        if not spec.get(key):
            problems.append(f"missing {key}")
    items = [item for section in spec.get("sections", []) for item in section.get("items", [])]
    if not items:
        problems.append("no items")
    if len(items) > LIMIT:
        problems.append(f"{len(items)} items: a sitting holds {LIMIT} at most, so split it into numbered sittings")
    for n, item in enumerate(items, 1):
        for key in ("do", "see", "person"):
            if not item.get(key):
                problems.append(f"item {n} has no {key}")
    if problems:
        return None, problems
    brief = spec.get("brief", [])
    lines = [f"# Over to you, {spec['name']}!", ""]
    lines += brief if isinstance(brief, list) else [brief]
    lines.append(spec["open"])
    if spec.get("sitting"):
        n, total = spec["sitting"]
        lines.append(f"Sitting {n} of {total}.")
    lines += [f"signed off: {spec['signed_off']}", f"proven by: {spec['proven_by']}", LEGEND, ""]
    n = 0
    for section in spec["sections"]:
        lines += [f"## {section['title']}", ""]
        for item in section["items"]:
            n += 1
            lines.append(f"{n}. [ ] {item['do']} → {item['see']}")
            lines.append(f"   person: {item['person']}")
            if item.get("kit"):
                lines.append(f"   kit: {item['kit']}")
            if item.get("source"):
                lines.append(f"   source: {item['source']}")
            lines += ["   notes:", ""]
        lines += quick_notes() + [""]
    lines += ["## Extra tests", "", spec.get("extra", "") or "nothing yet", ""] + quick_notes()
    lines += ["", "## Other", ""]
    text = "\n".join(lines) + "\n"
    found = lint(text.split("\n"), opted_out())
    if found:
        return None, [f"line {number}: {problem}" for number, problem in found]
    return text, []


def main(argv):
    if len(argv) != 3:
        print("usage: checklist.py <spec.json> <out.md>", file=sys.stderr)
        return 2
    refusal = loose_page(argv[2])
    if refusal:
        print(refusal)
        return 1
    with open(argv[1], encoding="utf-8") as f:
        text, problems = render(json.load(f))
    if problems:
        print("\n".join(problems))
        return 1
    with open(argv[2], "w", encoding="utf-8") as f:
        f.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
