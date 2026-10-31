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
import argparse
import datetime
import os
import pathlib
import sys


def idle(lines, skills, days, today):
    starts, first = {}, None
    for line in lines:
        when, _, name = line.rstrip("\n").partition("\t")
        try:
            day = datetime.date.fromisoformat(when[:10])
        except ValueError:
            continue
        name = name.rpartition(":")[2]
        starts[name] = max(day, starts.get(name, day))
        first = min(day, first or day)
    age = (today - first).days if first else 0
    if age < days:
        return None, age
    cutoff = today - datetime.timedelta(days=days)
    return sorted(s for s in skills if starts.get(s, datetime.date.min) < cutoff), age


def main(argv):
    parser = argparse.ArgumentParser(description="List the skills nothing has started in a while.")
    parser.add_argument("ledger")
    parser.add_argument("folder")
    parser.add_argument("--days", type=int, default=60)
    parser.add_argument("--today", type=datetime.date.fromisoformat,
                        default=datetime.datetime.now(datetime.timezone.utc).date())
    args = parser.parse_args(argv)
    if not os.path.exists(args.ledger):
        print("no ledger")
        sys.exit(3)
    skills = {path.parent.name for path in pathlib.Path(args.folder).rglob("SKILL.md")}
    with open(args.ledger) as handle:
        names, age = idle(handle, skills, args.days, args.today)
    if names is None:
        print(f"too young: {age} days")
        sys.exit(4)
    print("\n".join(names))


if __name__ == "__main__":
    main(sys.argv[1:])
