#!/usr/bin/env python3
"""Catch the habits a script can find in a draft, and give the move to make.

Usage: lint-tells.py <draft>

Prints one line per hit, "<line>: <matched words>: <move to make>", and exits
1 when there is any. A clean draft prints nothing and exits 0. Code spans and
code blocks are skipped. The habits that need a reader are the guiderails in
SKILL.md.
"""
import re
import sys

# Each check: (move to make, regex). Matching ignores case.
WORDS = [
    ("Say what it does, how fast or for whom, with a number or a name.",
     r"\b(vibrant|rich tapestry|groundbreaking|cutting-edge|seamless(ly)?|robust|holistic|intricate|"
     r"multifaceted|transformative|game-changer|pivotal|crucial|delve[sd]?|dive into|underscores?|"
     r"testament|beacon|landscape|realm|myriad|plethora|leverag(e|es|ed|ing)|harness(es|ed|ing)?|"
     r"foster(s|ed|ing)?|unleash(es|ed|ing)?|empower(s|ed|ing)?|streamlin(e|es|ed|ing)|showcas(es|ed|ing)|"
     r"boasts|nestled|in the heart of|meticulous(ly)?|paradigm shift)\b"),
    ("State the fact and its size, and let the reader judge it.",
     r"\b(marks a pivotal moment|plays a (vital|key|crucial) role|stands as a key|sets the stage for|"
     r"shed(s)? light on|pave(s)? the way|really shines|the key takeaway|cannot be overstated)\b"),
    ("End the sentence on its fact. Give the result its own sentence, with a number in it.",
     r", (highlighting|underscoring|showcasing|reflecting|ensuring|contributing to|fostering)\b"),
    ("Say the one thing it is.",
     r"\bnot just\b[^.]*\bbut\b|\bisn't just\b|\bit's not\b[^.]*\bit's\b|\bno \w+, no \w+, just\b"),
    ("Use is, are or has.", r"\b(serves as|functions as|stands as|acts as)\b"),
    ("Name the source and what it says, or cut the claim.",
     r"\b(experts (argue|say|recommend|agree)|studies show|it is widely regarded|research suggests)\b"),
    ("Say the link: caused by, built on, replaced.", r"\b(in connection with|in relation to)\b"),
    ("Give the two or three real cases.", r"\b(whether it's\b[^.]*\bor\b|ranging from)\b"),
    ("Say the thing itself.", r"\bworth (noting|asking|considering|a look|mentioning)\b"),
    ("State the point with no label before it.",
     r"\b(this matters|here's the useful part|the most interesting part)\b"),
    ("Scale the claim to what is true.", r"\b(that's the whole game|the whole game|the only thing that matters)\b"),
    ("Open the sentence with its claim.", r"(?:^|(?<=[.!?] ))(honestly|to be honest)\b|\bI want to be careful\b"),
    ("Say what was done, and who saw it.", r"\bquietly\b"),
    ("Use the measured word: open, decided, slowed by 20%.", r"\b(unsettled|wrecked)\b"),
    ("Use the plain verb: test, goal, size, explain.",
     r"\b(pressure-test(s|ed|ing)?|north star|right-siz(e|es|ed|ing)|(let\'s )?unpack (this|that|it|the idea)|"
     r"at the end of the day|lessons learned)\b"),
    ("Open with the content.", r"^(in today's fast-paced world|when it comes to|at its core|picture this)\b"),
    ("Start the sentence on its subject, and stop on the last real point.",
     r"\b(in conclusion|furthermore|moreover|additionally|that being said|"
     r"it is important to note)\b|^(overall|ultimately),"),
    ("Stop on the last real point.", r"\b(in summary|to sum up)\b,?"),
    ("Open the paragraph on its point.", r"\bone of the key\b"),
    ("Say must, then the action.", r"\bit is imperative\b"),
    ("Say the next fact.", r"\b(here's the thing|here's the kicker|why does this matter\?)"),
    ("Open with the content, and stop when it ends.",
     r"\b(in this (article|post|guide) we will|let's dive in|I hope this helps)\b"),
    ("Fill it in, or cut the sentence.", r"\[(citation needed|TODO)\]|\bturn\d+search\d+\b"),
    ("Use words. Emoji go only where the house style uses them.", "[\U0001F300-\U0001FAFF☀-➿]"),
    ("Use straight quotes.", "[‘’“”]"),
    ("Write the literal word, and say which part matters and why.",
     r"\b(load-bearing|throughline|doing the heavy lifting)\b"),
]
HEDGES = r"\b(may|might|could|potentially|possibly|perhaps|generally speaking|it could be argued|arguably|somewhat)\b"
HEDGE_MOVE = "Keep one qualifier, or commit to the claim."
DASH_MOVE = "Use a full stop or a comma. Keep one dash pair per paragraph at most."
BOLD_MOVE = "Bold only the one word a reader must not miss."
RHYTHM_MOVE = "Size each paragraph to its content: short for one point, longer where the reasoning runs."
RULE_MOVE = "Let headings separate the sections, with no rule above them."


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
        for move, pattern in WORDS:
            for match in re.finditer(pattern, line.strip(), re.IGNORECASE | re.MULTILINE):
                hits.append((number, match.group(0), move))
        for sentence in re.split(r"(?<=[.!?])\s+", line):
            if len(re.findall(HEDGES, sentence, re.IGNORECASE)) >= 2:
                # A colon in the match would split the line's fields.
                hits.append((number, sentence.strip()[:60].replace(":", ""), HEDGE_MOVE))
    counts = []
    for number, block in paragraphs(lines):
        dashes = block.count("—")
        if dashes >= 3:
            hits.append((number, f"{dashes} em dashes", DASH_MOVE))
        bold = len(re.findall(r"\*\*[^*]+\*\*", block))
        if bold >= 3 and not block.lstrip().startswith(("-", "*", "|")):
            hits.append((number, f"{bold} bold spans", BOLD_MOVE))
        if not block.lstrip().startswith(("#", "-", "*", "|", ">")) and not re.match(r"\s*\d+\.", block):
            counts.append((number, len(re.findall(r"[.!?](\s|$)", block))))
    if len(counts) >= 3 and len({n for _, n in counts}) == 1:
        hits.append((counts[0][0], f"every paragraph has {counts[0][1]} sentences", RHYTHM_MOVE))
    rules = sum(1 for (_, a), (_, b) in zip(lines, lines[1:] + [(0, "")])
                if a.strip() == "---" and b.startswith("#"))
    if rules >= 2:
        hits.append((1, f"{rules} rules before headings", RULE_MOVE))
    return sorted(hits)


def main(argv):
    if len(argv) != 1:
        sys.exit(__doc__.strip().splitlines()[2])
    with open(argv[0], encoding="utf-8") as handle:
        hits = lint(handle.read())
    for number, match, move in hits:
        print(f"{number}: {match}: {move}")
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
