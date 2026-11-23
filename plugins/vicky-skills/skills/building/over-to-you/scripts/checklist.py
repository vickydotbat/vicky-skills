#!/usr/bin/env python3
"""Write an over-to-you checklist from a JSON spec, in the one form the page reads.

    python3 checklist.py <spec.json> <out.md>

The spec:

    {"name": "<user>", "brief": ["what this sitting is for", "..."],
     "open": "what to open, where, on which branch",
     "sitting": [1, 2],                      # optional: sitting 1 of 2
     "signed_off": "nothing yet", "proven_by": "`health.sh` answers ok",
     "stage_ran": "stage",                   # the liveness receipt; not needed when proven_by is "no server"
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

"stage_ran" names the receipt of a liveness command (a process or container
running, a port answering) run within 15 minutes of the page, and passed again RAN_HOLD=60 seconds later.
A receipt whose command runs a script from the session folder is refused: its
last line, not the test, decides its exit. A command that
reads a file is refused, since a log line can come from another server, and
a repo's `Stage check:` line in docs/agents/testing.md names the one command,
matched whole, or says `none` to switch the check off.
"""
import json
import os
import re
import shlex
import subprocess
import sys
from datetime import datetime, timedelta, timezone

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


# Commands that print or exit and test nothing.
NOOPS = {"true", "false", ":", "echo", "printf"}


def receipt(item, n, out_dir, label=None):
    """Returns (the item's ran: line, None) or (None, the problem)."""
    label = label or f"item {n}"
    rid = item.get("ran") or ""
    if not rid:
        return None, f"{label} has no ran: run it first with ran.sh <id> <command>, then name the id"
    path = os.path.join(out_dir, "over-to-you-receipts", f"{rid}.json")
    try:
        with open(path, encoding="utf-8") as f:
            got = json.load(f)
    except (OSError, ValueError):
        return None, f"{label}: no receipt {rid}: run the check with ran.sh {rid} <command> in this session first"
    if got.get("exit") != 0:
        return None, f"{label}: receipt {rid} exited {got.get('exit')}: fix the check until your own run passes"
    command = got.get("command", "")
    if (command.split() or [""])[0] in NOOPS:
        return None, f"{label}: receipt {rid} ran `{command}`, which does nothing: run the check itself through ran.sh"
    for kit in re.findall(r"`([^`]+)`", item.get("kit", "")):
        if kit not in command and kit not in got.get("tail", ""):
            return None, f"{label}: receipt {rid} ran `{command}`, and neither it nor its output holds the kit `{kit}`: run the kit itself through ran.sh"
    sid = os.environ.get("CLAUDE_CODE_SESSION_ID") or "\0"
    scratches = tuple(os.path.join(root, sid) + os.sep for root in {os.environ.get("TMPDIR") or "/tmp", "/tmp"})
    if any((path + os.sep).startswith(scratches) for path in command_paths(command, got.get("cwd") or "/")):
        return None, (f"{label}: receipt {rid} ran `{command}`, a script written in the session folder: its last line, "
                      "not the test, decides its exit. Run the test command itself through ran.sh")
    head = got.get("head") or ""
    if head:
        now = subprocess.run(["git", "-C", got.get("cwd") or ".", "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
        if now and now != head:
            return None, f"{label}: receipt {rid} ran on {head[:9]}, not HEAD {now[:9]}: run it again on this build"
    return f"   ran: `{command}` exit 0 at {got.get('at', '')}", None


def command_paths(command, cwd):
    """Every word of the command as an absolute path, quotes stripped, -c payloads opened."""
    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        words = list(lexer)
    except ValueError:
        words = command.split()
    for word in words:
        if " " in word:
            yield from command_paths(word, cwd)
        elif "/" in word:
            yield os.path.normpath(os.path.join(cwd, os.path.expandvars(word)))


# Commands that read a file: a log line can come from another server writing the same log.
READS_A_FILE = {"grep", "rg", "egrep", "fgrep", "tail", "head", "cat", "tac", "less", "more", "bat", "awk", "sed", "cut",
                "sort", "wc", "nl", "od", "dd", "xxd", "strings", "zcat", "journalctl"}
# Words that run the command after them, so the reader check looks past them.
WRAPPERS = {"env", "sudo", "run0", "timeout", "nice", "nohup", "exec", "command", "sh", "bash", "-c"}
STAGE_MINUTES = 15
# A server can answer a check seconds after boot and crash a minute later.
STAGE_HOLD = 60
SKEW = timedelta(minutes=1)


def reads_a_file(command):
    """True when the command reads a file: a < redirect, a logs subcommand, or a reader that runs as a command,
    through pipes, lists, quotes and wrappers. A reader's name as an argument (pgrep -f tail) is no read."""
    if re.search(r"(?<![<\d])<(?![<(])", command):
        return True
    for segment in re.split(r"[;&|()'\"`]+", command):
        words = segment.split()
        if "logs" in words:
            return True
        while words and (os.path.basename(words[0]) in WRAPPERS or words[0].startswith("-") or words[0].isdigit() or "=" in words[0]):
            words.pop(0)
        if words and os.path.basename(words[0]) in READS_A_FILE:
            return True
    return False  # mutant-ok delete: falling off the end returns None, which reads false too


def same_command(a, b):
    """True when two commands hold the same words once shell quoting is gone, as ran.sh records them."""
    try:
        return " ".join(shlex.split(a)) == " ".join(shlex.split(b))
    except ValueError:
        return a.split() == b.split()


def stage_check(directory):
    """The command the repo's Stage check: line names in docs/agents/testing.md, "none", or None with no line."""
    top = subprocess.run(["git", "-C", directory or ".", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
    if not top:
        return None
    try:
        with open(os.path.join(top, "docs", "agents", "testing.md"), encoding="utf-8") as f:
            line = re.search(r"^Stage check:\s*(\S.*)$", f.read(), re.MULTILINE)
    except OSError:
        return None
    if not line:
        return None
    value = line.group(1).strip()
    if value.rstrip(".").lower() == "none":
        return "none"
    quoted = re.match(r"`([^`]+)`", value)
    return quoted.group(1) if quoted else value


def stage_problem(spec, out_dir):
    """The problem with the stage's liveness receipt, or None. A spec whose proven_by is `no server`, or a repo whose
    Stage check: line says none, needs none."""
    if (spec.get("proven_by") or "").strip().lower() == "no server" or "none" in (stage_check(out_dir), stage_check(".")):
        return None
    rid = spec.get("stage_ran") or ""
    if not rid:
        return ("stage: proven_by names a server, so stage_ran must name the ran.sh receipt of a liveness command run "
                "just before the page opens: a process or container running, a port answering, as the repo's "
                "`Stage check:` line in docs/agents/testing.md names. A log line proves nothing: another server can write it.")
    _, problem = receipt({"ran": rid}, 0, out_dir, "stage")
    if problem:
        return problem
    with open(os.path.join(out_dir, "over-to-you-receipts", f"{rid}.json"), encoding="utf-8") as f:
        got = json.load(f)
    command = got.get("command", "")
    try:
        age = datetime.now(timezone.utc) - datetime.strptime(got.get("at", ""), "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError:
        age = timedelta.max
    if age < -SKEW:
        return f"stage: receipt {rid} is dated in the future: run the liveness check again through ran.sh"
    if age > timedelta(minutes=STAGE_MINUTES):
        return f"stage: receipt {rid} ran more than {STAGE_MINUTES} minutes ago: run the liveness check again just before the page opens"
    if (got.get("hold") or 0) < STAGE_HOLD:
        return (f"stage: receipt {rid} checked the server once: run it as RAN_HOLD={STAGE_HOLD} ran.sh {rid} <command>, "
                "which checks again a minute later, since a server can answer seconds after boot and crash after")
    if reads_a_file(command):
        return f"stage: receipt {rid} ran `{command}`, which reads a file: a log line can come from another server. Check the process, container or port itself"
    named = stage_check(got.get("cwd"))
    if named and named != "none" and not same_command(command, named):
        return f"stage: receipt {rid} ran `{command}`, not the repo's Stage check `{named}`: run that through ran.sh"
    return None  # mutant-ok delete: falling off the end returns None too


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
    problem = stage_problem(spec, out_dir)
    if problem:
        problems.append(problem)
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
