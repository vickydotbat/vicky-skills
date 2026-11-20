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
         "source": "scripts/paper.nss in the module", "ran": "paper"}]}],
     "extra": "checks run outside the list"}

Writes the file and exits 0, or prints `<problem>` lines and exits 1 without
writing: a missing field, more than seven items, or anything lint-checklist.py
refuses. The agent never types the checklist by hand.

Every item names in "ran" the receipt of the agent's own run of it, written by
ran.sh into over-to-you-receipts/ beside the checklist. A receipt that is missing,
exited non-zero, was run on a commit other than HEAD, or (for an item with a kit)
holds the kit's command in neither its command nor its output is refused: the agent runs every check before a
person does.
"""
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [HERE, os.path.join(HERE, "..", "..", "..", "writing", "interactive-page", "scripts")]
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


def receipt(item, n, out_dir):
    """Returns (the item's ran: line, None) or (None, the problem)."""
    rid = item.get("ran") or ""
    if not rid:
        return None, f"item {n} has no ran: run it first with ran.sh <id> <command>, then name the id"
    path = os.path.join(out_dir, "over-to-you-receipts", f"{rid}.json")
    try:
        with open(path, encoding="utf-8") as f:
            got = json.load(f)
    except (OSError, ValueError):
        return None, f"item {n}: no receipt {rid}: run the check with ran.sh {rid} <command> in this session first"
    if got.get("exit") != 0:
        return None, f"item {n}: receipt {rid} exited {got.get('exit')}: fix the check until your own run passes"
    command = got.get("command", "")
    for kit in re.findall(r"`([^`]+)`", item.get("kit", "")):
        if kit not in command and kit not in got.get("tail", ""):
            return None, f"item {n}: receipt {rid} ran `{command}`, and neither it nor its output holds the kit `{kit}`: run the kit itself through ran.sh"
    head = got.get("head") or ""
    if head:
        now = subprocess.run(["git", "-C", got.get("cwd") or ".", "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
        if now and now != head:
            return None, f"item {n}: receipt {rid} ran on {head[:9]}, not HEAD {now[:9]}: run it again on this build"
    return f"   ran: `{command}` exit 0 at {got.get('at', '')}", None


def render(spec, out_dir="."):
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
    ran = {}
    for n, item in enumerate(items, 1):
        line, problem = receipt(item, n, out_dir)
        if problem:
            problems.append(problem)
        ran[n] = line
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
            lines.append(ran[n])
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
        text, problems = render(json.load(f), os.path.dirname(os.path.abspath(argv[2])))
    if problems:
        print("\n".join(problems))
        return 1
    with open(argv[2], "w", encoding="utf-8") as f:
        f.write(text)
    return 0  # mutant-ok delete: sys.exit(None) also exits 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
