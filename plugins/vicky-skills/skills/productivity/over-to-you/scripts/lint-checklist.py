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
later item that turns it off with the same command. A repo whose docs/agents files
say "Checklist lint: basic" keeps only the person, kit and proof checks.
"""
import glob
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
OFF = re.compile(r"\boff\b", re.IGNORECASE)
COMMAND = re.compile(r"`([^`]+)`")
OPT_OUT = "Checklist lint: basic"


def lint(lines, basic=False):
    problems = []
    if not any(re.match(r"^proven by:\s*\S", line) for line in lines):
        problems.append((1, "no `proven by:` line naming the checks the agent ran"))
    for number, line in enumerate(lines, 1):
        if not ITEM.match(line):
            continue
        reason, kits, source = None, [], False
        for after in lines[number:]:
            if ITEM.match(after) or after.startswith("#"):
                break
            found = PERSON.match(after)
            if found and reason is None:
                reason = found.group(1).strip()
            if KIT.match(after):
                kits.append(after)
            source = source or bool(SOURCE.match(after))
        action = line.split("→")[0]
        if REACHES.search(action) and not kits:
            problems.append((number, "item reaches a thing but has no `kit:` line with its command in backticks"))
        if reason is None:
            problems.append((number, "item has no `person:` line"))
        elif not reason.startswith(REASONS):
            problems.append((number, f"`person: {reason}` is not one of: {', '.join(REASONS)}"))
        if basic:
            continue
        if TERMINAL.search(action) or any(TERMINAL.search(k) for k in kits):
            problems.append((number, "item is a terminal read the agent can run itself: run it and put the result on the `proven by:` line"))
        if any(CONSOLE.search(k) for k in kits) and not source:
            problems.append((number, "kit runs in a console or chat but has no `source:` line naming where its exact spelling comes from"))
        toggles = {c for k in kits if TOGGLE.search(k) or TOGGLE.search(action) for c in COMMAND.findall(k)}
        if (TOGGLE.search(action) or any(TOGGLE.search(k) for k in kits)) and not OFF.search(action) and not any(
                ITEM.match(later) and OFF.search(later) and (not toggles or any(c in later for c in toggles))
                for later in lines[number:]):
            problems.append((number, "item turns state on, but no later item turns it off with the same command"))
    return problems


def opted_out():
    """True when the repo's docs/agents files say "Checklist lint: basic"."""
    return any(OPT_OUT in open(f, encoding="utf-8").read() for f in glob.glob("docs/agents/*.md"))


def main():
    with open(sys.argv[1], encoding="utf-8") as handle:
        lines = handle.read().splitlines()
    problems = lint(lines, opted_out())
    for number, problem in problems:
        print(f"{number}: {problem}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
