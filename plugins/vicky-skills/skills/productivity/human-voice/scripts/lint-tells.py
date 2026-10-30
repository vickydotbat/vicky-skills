#!/usr/bin/env python3
"""Find the tells in TELLS.md that a script can catch with no judgement.

Usage: lint-tells.py <draft>

Prints one line per hit, "<line>: <tell>: <match>", and exits 1 when there is
any. A clean draft prints nothing and exits 0. Code spans and code blocks are
skipped. The tells that need a reader stay with the TELLS.md sweep.
"""
import re
import sys

# Each tell: (heading in TELLS.md, regex). Matching ignores case.
WORDS = [
    ("Puffery", r"\b(vibrant|rich tapestry|groundbreaking|cutting-edge|seamless(ly)?|robust|holistic|intricate|"
                r"multifaceted|transformative|game-changer|pivotal|crucial|delve[sd]?|dive into|underscores?|"
                r"testament|beacon|landscape|realm|myriad|plethora|leverag(e|es|ed|ing)|harness(es|ed|ing)?|"
                r"foster(s|ed|ing)?|unleash(es|ed|ing)?|empower(s|ed|ing)?|streamlin(e|es|ed|ing)|showcas(es|ed|ing)|"
                r"boasts|nestled|in the heart of|meticulous(ly)?|paradigm shift)\b"),
    ("Significance talk", r"\b(marks a pivotal moment|plays a (vital|key|crucial) role|stands as a key|sets the stage for|"
                          r"shed(s)? light on|pave(s)? the way|really shines|the key takeaway|cannot be overstated)\b"),
    ("Participle tails", r", (highlighting|underscoring|showcasing|reflecting|ensuring|contributing to|fostering)\b"),
    ("Negative parallelism", r"\bnot just\b[^.]*\bbut\b|\bisn't just\b|\bit's not\b[^.]*\bit's\b|\bno \w+, no \w+, just\b"),
    ("Dodging \"is\"", r"\b(serves as|functions as|stands as|acts as)\b"),
    ("Vague sourcing", r"\b(experts (argue|say|recommend|agree)|studies show|it is widely regarded|research suggests)\b"),
    ("Vague links", r"\b(in connection with|in relation to)\b"),
    ("Sweep constructions", r"\b(whether it's\b[^.]*\bor\b|ranging from)\b"),
    ("Worth", r"\bworth (noting|asking|considering|a look|mentioning)\b"),
    ("Announced importance", r"\b(this matters|here's the useful part|the most interesting part)\b"),
    ("Totalizing", r"\b(that's the whole game|the whole game|the only thing that matters)\b"),
    ("Honesty tags", r"\b(honestly|to be honest|I want to be careful)\b"),
    ("Quietly", r"\bquietly\b"),
    ("Drama words", r"\b(unsettled|wrecked)\b"),
    ("Consultant talk", r"\b(pressure-test(s|ed|ing)?|north star|right-siz(e|es|ed|ing)|(let\'s )?unpack (this|that|it|the idea)|"
                        r"at the end of the day|lessons learned)\b"),
    ("Formula openers", r"^(in today's fast-paced world|when it comes to|at its core|picture this)\b"),
    ("Formula endings and joins", r"\b(in conclusion|furthermore|moreover|additionally|that being said|"
                                  r"it is important to note)\b|^(overall|ultimately),"),
    ("Hook lines", r"\b(here's the thing|here's the kicker|why does this matter\?)"),
    ("Talking about the writing", r"\b(in this (article|post|guide) we will|let's dive in|I hope this helps)\b"),
    ("Placeholders", r"\[(citation needed|TODO)\]|\bturn\d+search\d+\b"),
    ("Tables and emoji as decoration", "[\U0001F300-\U0001FAFF☀-➿]"),
    ("Curly quotes", "[‘’“”]"),
]
HEDGES = r"\b(may|might|could|potentially|possibly|perhaps|generally speaking|it could be argued|arguably|somewhat)\b"


def prose(text):
    """Yield (line number, text) with code blocks and code spans blanked out."""
    fenced = False
    for number, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith(("```", "~~~")):
            fenced = not fenced
            yield number, ""
            continue
        yield number, "" if fenced else re.sub(r"`[^`]*`", "", line)


def paragraphs(lines):
    """Group (line number, text) into paragraphs: (first line number, joined text)."""
    block = []
    for number, line in lines + [(0, "")]:
        if line.strip():
            block.append((number, line))
        elif block:
            yield block[0][0], " ".join(text for _, text in block)
            block = []


def lint(text):
    lines = list(prose(text))
    hits = []
    for number, line in lines:
        for tell, pattern in WORDS:
            for match in re.finditer(pattern, line.strip(), re.IGNORECASE | re.MULTILINE):
                hits.append((number, tell, match.group(0)))
        for sentence in re.split(r"(?<=[.!?])\s+", line):
            if len(re.findall(HEDGES, sentence, re.IGNORECASE)) >= 2:
                hits.append((number, "Hedge stacks", sentence.strip()[:60]))
    counts = []
    for number, block in paragraphs(lines):
        dashes = block.count("—")
        if dashes >= 3:
            hits.append((number, "Em dash flood", f"{dashes} em dashes"))
        bold = len(re.findall(r"\*\*[^*]+\*\*", block))
        if bold >= 3 and not block.lstrip().startswith(("-", "*", "|")):
            hits.append((number, "Bold on key terms", f"{bold} bold spans"))
        if not block.lstrip().startswith(("#", "-", "*", "|", ">")) and not re.match(r"\s*\d+\.", block):
            counts.append((number, len(re.findall(r"[.!?](\s|$)", block))))
    if len(counts) >= 3 and len({n for _, n in counts}) == 1:
        hits.append((counts[0][0], "Even rhythm", f"every paragraph has {counts[0][1]} sentences"))
    rules = sum(1 for (_, a), (_, b) in zip(lines, lines[1:] + [(0, "")])
                if a.strip() == "---" and b.startswith("#"))
    if rules >= 2:
        hits.append((1, "Horizontal rules", f"{rules} rules before headings"))
    return sorted(hits)


def main(argv):
    if len(argv) != 1:
        sys.exit(__doc__.strip().splitlines()[2])
    with open(argv[0], encoding="utf-8") as handle:
        hits = lint(handle.read())
    for number, tell, match in hits:
        print(f"{number}: {tell}: {match}")
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
