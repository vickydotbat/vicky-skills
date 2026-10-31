#!/usr/bin/env python3
"""Lint an over-to-you checklist: every item says why only a person can check it.

    python3 lint-checklist.py <checklist.md>

Prints `<line>: <problem>` for each problem and exits 1, or prints nothing and exits 0.
A checklist needs a `proven by:` line naming what the agent already ran, and each item
needs a `person:` line under it naming one reason no command can prove the item.
"""
import re
import sys

REASONS = ("look", "feel", "real client", "second client", "extender", "hardware", "outside account", "timing")
ITEM = re.compile(r"^\s*\d+[a-z]?\. \[[ x~-]\] ")
PERSON = re.compile(r"^\s*person:\s*(.*)$")


def lint(lines):
    problems = []
    if not any(re.match(r"^proven by:\s*\S", line) for line in lines):
        problems.append((1, "no `proven by:` line naming the checks the agent ran"))
    for number, line in enumerate(lines, 1):
        if not ITEM.match(line):
            continue
        reason = None
        for after in lines[number:]:
            if ITEM.match(after) or after.startswith("#"):
                break
            found = PERSON.match(after)
            if found:
                reason = found.group(1).strip()
                break
        if reason is None:
            problems.append((number, "item has no `person:` line"))
        elif not reason.startswith(REASONS):
            problems.append((number, f"`person: {reason}` is not one of: {', '.join(REASONS)}"))
    return problems


def main():
    with open(sys.argv[1], encoding="utf-8") as handle:
        lines = handle.read().splitlines()
    problems = lint(lines)
    for number, problem in problems:
        print(f"{number}: {problem}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
