#!/usr/bin/env python3
"""Write a page file from a JSON spec, in the one form page.py reads.

    python3 write-page.py <spec.json> <out.md>

A question page, for a pick between options, a planning page or a council:

    {"kind": "question", "title": "A question for you",
     "charts": ["course.svg"],
     "course": [{"key": "GAME-1", "kind": "Bug", "title": "...", "needs": "nothing", "ticked": true}],
     "questions": [{"q": "Which colour?", "options": ["gray", "the phase colour"],
                    "pick": 0, "other": false}]}

A draft file, for red-pen:

    {"kind": "drafts", "effort": "rgb-colour-warp",
     "sections": [{"what": "Finish button tooltip", "where": "src/Step.cs:41",
                   "text": "Put the colours on your character", "approve": false}]}

Writes the file and exits 0, or prints `<problem>` lines and exits 1 without
writing. The agent never types a page file by hand; over-to-you's checklist
comes from its own checklist.py.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scratch import loose_page

FENCE = "```"
# A location that names an approved-examples test file: approved_examples, approved-examples or ApprovedExamples.
APPROVED_FILE = re.compile(r"approved[-_]?examples", re.IGNORECASE)


def question(spec):
    problems, lines = [], [f"# {spec.get('title') or 'A question for you'}", ""]
    for chart in spec.get("charts", []):
        lines += [f"![{chart.rsplit('.', 1)[0]}]({chart})", ""]
    for item in spec.get("course", []):
        if not item.get("key") or not item.get("title"):
            problems.append("a course line needs a key and a title")
            continue
        box = "x" if item.get("ticked", True) else " "
        lines.append(f"- [{box}] {item['key']} {item.get('kind', 'Task')}: {item['title']}. Needs: {item.get('needs') or 'nothing'}")
    if spec.get("course"):
        lines.append("")
    asked = spec.get("questions", [])
    if not asked and not spec.get("course"):
        problems.append("no questions and no course")
    for n, q in enumerate(asked, 1):
        options, pick = q.get("options", []), q.get("pick", 0)
        if not q.get("q"):
            problems.append(f"question {n} has no text")
        if len(options) < 2:
            problems.append(f"question {n} needs two options at least")
        if not isinstance(pick, int) or not 0 <= pick < max(len(options), 1):
            problems.append(f"question {n}'s pick is not one of its options")
        lines.append(f"## Q{n}: {q.get('q', '')}")
        lines += [f"- ({'x' if i == pick else ' '}) {option}" for i, option in enumerate(options)]
        if q.get("other"):
            lines += ["- ( ) Other", "notes:"]
        lines.append("")
    return lines, problems


def drafts(spec):
    problems = []
    if not spec.get("effort"):
        problems.append("missing effort")
    if not spec.get("sections"):
        problems.append("no sections")
    lines = [f"# Drafts: {spec.get('effort', '')}", "", "Press Done to send the text back.", ""]
    for n, section in enumerate(spec.get("sections", []), 1):
        for key in ("what", "where", "text"):
            if not section.get(key):
                problems.append(f"section {n} has no {key}")
        text = section.get("text", "")
        if FENCE in text:
            problems.append(f"section {n}'s text holds a code fence, which would end its block early")
        if APPROVED_FILE.search(section.get("where", "")) and not section.get("approve"):
            problems.append(f"section {n} ({section.get('what', '')}) is for an approved-examples test, so it needs approve true: without its tick box no tick is recorded")
        lines += [f"## {section.get('what', '')}", section.get("where", "")]
        if section.get("approve"):
            lines.append("- [ ] approve")
        lines += ["", f"{FENCE}text", *text.split("\n"), FENCE, ""]
    return lines, problems


def main(argv):
    if len(argv) != 3:
        print("usage: write-page.py <spec.json> <out.md>", file=sys.stderr)
        return 2
    refusal = loose_page(argv[2])
    if refusal:
        print(refusal)
        return 1
    with open(argv[1], encoding="utf-8") as f:
        spec = json.load(f)
    kinds = {"question": question, "drafts": drafts}
    if spec.get("kind") not in kinds:
        print(f"kind must be one of: {', '.join(kinds)}")
        return 1
    lines, problems = kinds[spec["kind"]](spec)
    if problems:
        print("\n".join(problems))
        return 1
    with open(argv[2], "w", encoding="utf-8") as f:
        f.write("\n".join(lines).rstrip("\n") + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
