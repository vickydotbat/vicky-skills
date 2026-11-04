#!/usr/bin/env python3
"""Lint an over-to-you checklist: every item says why only a person can check it.

    python3 lint-checklist.py <checklist.md>

Prints `<line>: <problem>` for each problem and exits 1, or prints nothing and exits 0.
A checklist needs a `proven by:` line naming what the agent already ran, and each item
needs a `person:` line under it naming one reason no command can prove the item.
An item that reaches a thing (spawn, give, create...) also needs a `kit:` line holding
the exact command, in backticks, that puts the thing in reach.
An item whose kit or action is a terminal read (grep, cat, ls, tail...) is the agent's to
run. A kit run in a game console or chat needs a `source:` line saying where its exact
spelling comes from. A kit that turns state on (a toggle, a debug view, a mode) needs a
later item that turns it off.
"""
import re
import sys

REASONS = ("look", "feel", "real client", "second client", "extender", "hardware", "outside account", "timing")
ITEM = re.compile(r"^\s*\d+[a-z]?\. \[[ x~-]\] ")
PERSON = re.compile(r"^\s*person:\s*(.*)$")
KIT = re.compile(r"^\s*kit:.*`[^`]+`")
REACHES = re.compile(r"\b(spawn|give|create|place|equip|summon|seed|load)s?\b", re.IGNORECASE)
TERMINAL = re.compile(r"`(?:sudo |run0 )?(grep|rg|cat|ls|tail|head|less|find|wc|jq)\b|\bgrep\b|\bread the (?:log|file)\b", re.IGNORECASE)
CONSOLE = re.compile(r"\b(console|chat)\b", re.IGNORECASE)
SOURCE = re.compile(r"^\s*source:\s*\S")
TOGGLE = re.compile(r"\b(toggles?|turns? (?:it )?on|debug view|slot view|run (?:it )?again to turn)", re.IGNORECASE)
OFF = re.compile(r"\b(turn|switch)\w* (?:\S+ ){0,4}off\b|\boff\b", re.IGNORECASE)


def lint(lines):
    problems = []
    if not any(re.match(r"^proven by:\s*\S", line) for line in lines):
        problems.append((1, "no `proven by:` line naming the checks the agent ran"))
    for number, line in enumerate(lines, 1):
        if not ITEM.match(line):
            continue
        reason, kit, kits, source = None, False, [], False
        for after in lines[number:]:
            if ITEM.match(after) or after.startswith("#"):
                break
            found = PERSON.match(after)
            if found and reason is None:
                reason = found.group(1).strip()
            if KIT.match(after):
                kit = True
                kits.append(after)
            source = source or bool(SOURCE.match(after))
        action = line.split("→")[0]
        if TERMINAL.search(action) or any(TERMINAL.search(k) for k in kits):
            problems.append((number, "item is a terminal read the agent can run itself: run it and put the result on the `proven by:` line"))
        if any(CONSOLE.search(k) for k in kits) and not source:
            problems.append((number, "kit runs in a console or chat but has no `source:` line naming where its exact spelling comes from"))
        if (TOGGLE.search(action) or any(TOGGLE.search(k) for k in kits)) and not OFF.search(action) and not any(
                ITEM.match(later) and OFF.search(later) for later in lines[number:]):
            problems.append((number, "kit turns state on, but no later item turns it off with its command"))
        if REACHES.search(line.split("→")[0]) and not kit:
            problems.append((number, "item reaches a thing but has no `kit:` line with its command in backticks"))
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
