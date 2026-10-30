#!/usr/bin/env python3
"""List the skills nothing has started in a while, from the skill ledger.

Usage: idle-skills.py <skill-ledger.tsv> <skills folder> [--days 60] [--today YYYY-MM-DD]

The ledger has one line per skill start: a UTC time, a tab, the skill's name.
The skills folder is searched for <name>/SKILL.md. A ledger name counts for a
skill with or without its plugin prefix ("vicky-skills:sup" and "sup").

Prints one skill name per line, each with no start in the last --days days.
With no ledger it prints "no ledger" and exits 3. With a ledger younger than
--days it prints "too young: <n> days" and exits 4, since it can't tell yet.
"""
import datetime
import os
import sys


def skills_in(folder):
    found = set()
    for root, _dirs, files in os.walk(folder):
        if "SKILL.md" in files:
            found.add(os.path.basename(root))
    return found


def idle(lines, skills, days, today):
    starts = {}
    for line in lines:
        when, _, name = line.rstrip("\n").partition("\t")
        try:
            day = datetime.date.fromisoformat(when[:10])
        except ValueError:
            continue
        name = name.rpartition(":")[2]
        starts[name] = max(day, starts.get(name, day))
        starts.setdefault("", day)
        starts[""] = min(starts[""], day)
    if not starts:
        return None, 0
    age = (today - starts.pop("")).days
    if age < days:
        return None, age
    cutoff = today - datetime.timedelta(days=days)
    return sorted(s for s in skills if starts.get(s, datetime.date.min) < cutoff), age


def main(argv):
    args, days, today = list(argv), 60, datetime.datetime.now(datetime.timezone.utc).date()
    if "--days" in args:
        at = args.index("--days")
        days = int(args[at + 1])
        del args[at:at + 2]
    if "--today" in args:
        at = args.index("--today")
        today = datetime.date.fromisoformat(args[at + 1])
        del args[at:at + 2]
    if len(args) != 2:
        sys.exit(__doc__.strip().splitlines()[2])
    ledger, folder = args
    if not os.path.exists(ledger):
        print("no ledger")
        sys.exit(3)
    with open(ledger) as handle:
        names, age = idle(handle, skills_in(folder), days, today)
    if names is None:
        print(f"too young: {age} days")
        sys.exit(4)
    print("\n".join(names))


if __name__ == "__main__":
    main(sys.argv[1:])
