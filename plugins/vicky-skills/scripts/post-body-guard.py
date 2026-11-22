#!/usr/bin/env python3
"""post-body-guard: refuses a pull request or issue post whose body leaks.

Read by post-body-guard.sh, which hands it the hook payload on stdin. A post is
gh pr/issue create, edit, comment or review, tea pr/issue create or edit, and
tea comment. Its body is refused when it holds terminal codes (a pasted
`gh` or `tea` view), opens with another item's heading number, names a
host from the post_guard_hosts setting or the checkout's own forge when the
post goes to another one, or names a path into this machine. A body the hook
cannot read ($(...), backticks, stdin, a here-doc, gh api body fields) is
refused with a steer to --body-file. No marker in the body or the command lets
a post through: only the guard_post_body setting does.
Exits 2 with the reasons on stderr, else 0.
"""
import json
import os
import re
import shlex
import subprocess
import sys

SEPARATORS = {";", "&&", "||", "|", "&", "(", ")", "\n", "|&"}
GH_POSTS = {("pr", "create"), ("pr", "edit"), ("pr", "comment"), ("pr", "review"),
            ("issue", "create"), ("issue", "edit"), ("issue", "comment")}
TEA_KINDS = {"pr", "pulls", "pull", "issue", "issues", "i"}
TEA_VERBS = {"create", "c", "edit", "e"}
TEA_VALUE_FLAGS = {"-r", "--repo", "-l", "--login", "-R", "--remote", "-o", "--output",
                   "-t", "--title", "-a", "--assignees", "-L", "--labels", "-m", "--milestone",
                   "--add-labels", "--remove-labels", "--deadline", "--head", "--base", "-b"}
GH_VALUE_FLAGS = {"-R", "--repo", "-t", "--title", "-B", "--base", "-H", "--head", "-a",
                  "--assignee", "-l", "--label", "-m", "--milestone", "-p", "--project",
                  "-r", "--reviewer", "--add-label", "--remove-label", "--add-assignee",
                  "--remove-assignee", "--add-reviewer", "--remove-reviewer", "-T", "--template"}
STEER = "Write the body to a file and pass it with --body-file (tea: --description-file or -d with the text inline), so this guard reads what goes out."


def tokens(command):
    lex = shlex.shlex(command, posix=True, punctuation_chars="();<>|&\n")
    lex.whitespace = " \t\r"
    lex.whitespace_split = True
    lex.commenters = "#"
    return list(lex)


def segments(toks):
    seg = []
    for t in toks:
        if t in SEPARATORS:
            if seg:
                yield seg
            seg = []
        else:
            seg.append(t)
    if seg:
        yield seg


def host_of(url):
    m = re.match(r"^[a-z+]+://(?:[^@/]+@)?([^/:]+)", url) or re.match(r"^(?:[^@/]+@)?([^/:]+):", url)
    return m.group(1).lower() if m else ""


def checkout_hosts(cwd):
    try:
        out = subprocess.run(["git", "-C", cwd, "remote", "-v"], capture_output=True, text=True, timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return set()
    return {h for h in (host_of(line.split()[1]) for line in out.splitlines() if len(line.split()) > 1) if h}


def number_of(word):
    m = re.fullmatch(r"#?(\d+)", word) or re.search(r"/(?:pull|pulls|issues)/(\d+)/?$", word)
    return m.group(1) if m else None


def parse_post(seg):
    """Return (tool, args after the verb) when seg is a post, else None."""
    for i, word in enumerate(seg):
        base = os.path.basename(word)
        if base == "gh" and len(seg) > i + 2 and (seg[i + 1], seg[i + 2]) in GH_POSTS:
            return "gh", seg[i + 3:]
        if base == "gh" and len(seg) > i + 1 and seg[i + 1] == "api":
            return "gh-api", seg[i + 2:]
        if base == "tea" and len(seg) > i + 2 and seg[i + 1] in TEA_KINDS and seg[i + 2] in TEA_VERBS:
            return "tea", seg[i + 3:]
        if base == "tea" and len(seg) > i + 1 and seg[i + 1] in {"comment", "c"}:
            return "tea-comment", seg[i + 2:]
    return None


def read_args(tool, args):
    """Return (bodies as (label, text or None for unreadable, reason), number, repo, redirects)."""
    bodies, number, repo, stdin = [], None, "", []
    positional = []
    i = 0
    while i < len(args):
        a = args[i]
        if a in {"<<", "<<<"} or (a == "<" and (i + 1 >= len(args) or args[i + 1] != "/dev/null")):
            stdin.append(a)
            i += 2
            continue
        if a in {"<", ">", ">>", ">&", "2"}:
            i += 2 if a in {"<", ">", ">>", ">&"} else 1
            continue
        flag, eq, val = a.partition("=")
        if not eq:
            val = args[i + 1] if i + 1 < len(args) else None
        step = 1 if eq else 2
        if tool == "gh" and flag in {"-b", "--body"}:
            bodies.append(("--body", val))
        elif tool == "gh" and flag in {"-F", "--body-file"}:
            bodies.append(("file", val))
        elif tool == "tea" and flag in {"-d", "--description"}:
            bodies.append(("--description", val))
        elif tool == "tea" and flag == "--description-file":
            bodies.append(("file", val))
        elif flag in {"-R", "--repo", "-r"}:
            repo = val or ""
        elif a.startswith("-") and (flag in (GH_VALUE_FLAGS if tool == "gh" else TEA_VALUE_FLAGS)):
            pass
        elif a.startswith("-"):
            step = 1
        else:
            positional.append(a)
            step = 1
        i += step
    if positional:
        number = number_of(positional[0])
    if tool == "tea-comment" and len(positional) > 1:
        bodies.append(("comment", " ".join(positional[1:])))
    return bodies, number, repo, stdin


def leak_lines(text, hosts):
    found = []
    home = os.environ.get("HOME", "")
    user = os.environ.get("USER", "")
    path = re.compile(r"(^|[^\w.}/-])/(home|Users)/[^/\s<$\{][^/\s]*/|/nix/store/")  # local-path-ok: the pattern itself
    user_pat = re.compile(r"(^|[^\w.~}/-])(/[^/\s]+)*/" + re.escape(user) + r"/|(^|[^\w.-])" + re.escape(user) + "@") if user else None
    for n, line in enumerate(text.splitlines(), 1):
        if "\x1b" in line or "\x07" in line or "^[]8;" in line or "^[[" in line:
            found.append(f"line {n}: terminal codes, as a pasted gh or tea view holds")
        for h in sorted(hosts):
            if re.search(r"(?<![\w.-])" + re.escape(h) + r"(?![\w-])", line, re.IGNORECASE):
                found.append(f"line {n}: names the host {h}")
        if path.search(line) or (len(home) > 1 and home in line) or (user_pat and user_pat.search(line)):
            found.append(f"line {n}: names a path into this machine")
    return found


def main():
    if os.environ.get("CLAUDE_PLUGIN_OPTION_GUARD_POST_BODY", "true") in {"false", "0"}:
        return 0
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0
    command = (payload.get("tool_input") or {}).get("command") or ""
    cwd = payload.get("cwd") or os.getcwd()
    if not re.search(r"\b(gh|tea)\b", command):
        return 0
    try:
        toks = tokens(command)
    except ValueError:
        if re.search(r"\b(gh\s+(pr|issue|api)|tea\s+\S+\s+(create|edit|c|e)|tea\s+comment)\b", command):
            print("post-body-guard: refused, this command's quoting does not parse, so its body can't be read. " + STEER + " Nothing ran.", file=sys.stderr)
            return 2
        return 0
    listed = {h.lower() for h in re.split(r"[\s,]+", os.environ.get("CLAUDE_PLUGIN_OPTION_POST_GUARD_HOSTS", "")) if h}
    problems = []
    for seg in segments(toks):
        if seg[0] == "cd" and len(seg) > 1:
            cwd = os.path.join(cwd, os.path.expanduser(seg[1]))
            continue
        post = parse_post(seg)
        if not post:
            continue
        tool, args = post
        if tool == "gh-api":
            if any(re.match(r"^(-f|-F|--field|--raw-field)$", a) and j + 1 < len(args) and args[j + 1].startswith("body=")
                   or re.match(r"^(--field|--raw-field|-f|-F)=?body=", a) or a == "--input" for j, a in enumerate(args)):
                problems.append("gh api sends a body this guard can't check. " + STEER)
            continue
        bodies, number, repo, stdin = read_args(tool, args)
        if stdin:
            problems.append("the post reads from " + stdin[0] + ", which this guard can't check. " + STEER)
        hosts = set(listed)
        if tool == "gh":
            target = host_of(repo if "://" in repo else "https://" + repo) if repo.count("/") >= 2 else os.environ.get("GH_HOST", "github.com").lower()
            hosts |= {h for h in checkout_hosts(cwd) if h != target}
        for kind, val in bodies:
            if val is None:
                problems.append("a body flag has no value. " + STEER)
                continue
            if kind == "file":
                if val == "-":
                    problems.append("--body-file - reads stdin, which this guard can't check. " + STEER)
                    continue
                p = os.path.join(cwd, os.path.expanduser(val))
                try:
                    with open(p, encoding="utf-8", errors="replace") as f:
                        text = f.read()
                except OSError:
                    problems.append(f"the body file {val} can't be read. " + STEER)
                    continue
            else:
                if "$(" in val or "`" in val:
                    problems.append("the body comes from a command substitution, which this guard can't check. " + STEER)
                    continue
                text = val
            first = next((l for l in text.splitlines() if l.strip()), "")
            m = re.match(r"^\s*#\s+#(\d+)\b", first)
            if m and number and m.group(1) != number:
                problems.append(f"the body opens with the heading of #{m.group(1)}, but it posts to #{number}: it is another item's text.")
            problems += leak_lines(text, hosts)
    if not problems:
        return 0
    print("post-body-guard: refused, this post would publish what it must not:", file=sys.stderr)
    for p in dict.fromkeys(problems):
        print("  " + p, file=sys.stderr)
    print("Rewrite the body by role (\"the team's forge\", a repo-relative path), or post the right item's text. Nothing in this command ran, not even its other steps.", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
