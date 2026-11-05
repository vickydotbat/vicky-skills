#!/usr/bin/env python3
"""Tags each timed snag line in the familiar's debt notes by what the watch
could show of it: visible, not visible, or no transcript.

    familiar-visibility.py <notes folder> <transcripts folder>

    familiar-visibility.py --kind < snag lines

A note names its session by the 8-hex id in its file name. A line is visible
when familiar-watch.sh prints an event of the line's kind within a minute of
its time. Prints "<session> <code> <HH:MM> <tag>" per line, then one count per
tag. With --kind it prints "<HH:MM> <kind>" for each snag line on stdin.
"""
import os
import re
import subprocess
import sys
from pathlib import Path

LINE = re.compile(r"^\s*-\s*\*{0,2}([SM]\d+b?) (\d{2}):(\d{2})\b")
SESSION = re.compile(r"\b([0-9a-f]{8})\b")
EVENT = re.compile(r"^\[(\d{2}):(\d{2}):\d{2}\] (?:\S+ )?(REFUSED|AGENT|USER|SKILL):")
WATCH = Path(__file__).with_name("familiar-watch.sh")
TAGS = ("visible", "not visible", "no transcript")
# The watch event each kind of snag shows up as, tried in order; "none" never shows.
KINDS = [
    ("refused", re.compile(r"refus|\bguard\b|hook (refused|sent back)")),
    ("skill", re.compile(r"\bskill\b|never ran")),
    ("user", re.compile(r"\b(user|vicky) (said|asked|reported|had to|found)")),
    ("agent", re.compile(r"\basked\b|\bpick\b|in chat|reported|claimed|\bsaid\b|\btold\b|\bwrote\b|message|going with")),
]

def kind(text):
    text = text.lower()
    return next((name for name, rule in KINDS if rule.search(text)), "none")

def watch_minutes(transcript):
    env = dict(os.environ, FAMILIAR_WATCH_ONCE="1")
    try:
        out = subprocess.run(["bash", str(WATCH), str(transcript)], env=env,
                             capture_output=True, text=True, timeout=120).stdout
    except subprocess.TimeoutExpired:
        sys.exit(f"familiar-visibility: the watch ran past 120 seconds on {transcript}")
    return {(int(m[1]) * 60 + int(m[2]), m[3].lower()) for m in map(EVENT.match, out.splitlines()) if m}

def main(notes, corpus):
    counts = dict.fromkeys(TAGS, 0)
    for note in sorted(Path(notes).glob("*Familiar debt*.md")):
        ids = SESSION.findall(note.stem.split(" ", 1)[-1])
        if not ids:
            continue
        session = ids[-1]
        found = sorted(Path(corpus).glob(f"*/{session}*.jsonl"))
        minutes = watch_minutes(found[0]) if found else None
        for line in note.read_text().splitlines():
            m = LINE.match(line)
            if not m:
                continue
            at = int(m[2]) * 60 + int(m[3])
            if minutes is None:
                tag = "no transcript"
            elif {(t, kind(line)) for t in (at - 1, at, at + 1)} & minutes:  # the same window as familiar-replay.sh
                tag = "visible"
            else:
                tag = "not visible"
            counts[tag] += 1
            print(f"{session} {m[1]} {m[2]}:{m[3]} {tag}")
    for tag in TAGS:
        print(f"{tag}: {counts[tag]}")

def kinds():
    for line in sys.stdin:
        if m := LINE.match(line):
            print(f"{m[2]}:{m[3]} {kind(line)}")

if __name__ == "__main__":
    if sys.argv[1:] == ["--kind"]:
        sys.exit(kinds())
    if len(sys.argv) != 3:
        sys.exit("usage: familiar-visibility.py <notes folder> <transcripts folder>")
    main(sys.argv[1], sys.argv[2])
