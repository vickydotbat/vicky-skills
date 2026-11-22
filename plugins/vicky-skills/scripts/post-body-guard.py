#!/usr/bin/env python3
"""post-body-guard: refuses a pull request or issue post whose body leaks.

Read by post-body-guard.sh, which hands it the hook payload on stdin. A post is
gh pr/issue create, edit, comment or review, tea pr/issue create or edit, and
tea comment. Its body is refused when it holds terminal codes (a pasted
`gh` or `tea` view), opens with another item's heading number, or names a
path into this machine. A body the hook
cannot read ($(...), backticks, stdin, a here-doc, gh api body fields) is
refused with a steer to --body-file. No marker in the body or the command lets
a post through: only the guard_post_body setting does.
Exits 2 with the reasons on stderr, else 0.
"""
import json
import os
import re
import shlex
import sys

GH_POSTS = {(noun, verb) for noun in ("pr", "issue") for verb in
            ("create", "new", "edit", "comment", "review", "close", "reopen", "merge")}
GH_POSTS |= {("release", "create"), ("release", "new"), ("release", "edit")}
GH_GLOBAL_VALUE_FLAGS = {"-R", "--repo", "--hostname"}
GH_BODY_FLAGS = {"-b": "--body", "--body": "--body", "-c": "--body", "--comment": "--body",
                 "-n": "--body", "--notes": "--body", "-F": "file", "--body-file": "file",
                 "--notes-file": "file", "-t": "title", "--title": "title", "--subject": "title"}
TEA_BODY_FLAGS = {"-d": "--description", "--description": "--description",
                  "--description-file": "file", "-t": "title", "--title": "title"}
SHELL_WORDS = {"do", "then", "else", "elif", "if", "while", "until", "!", "{", "}", "time"}
TEXT_TOOLS = {"git", "echo", "printf", "grep", "egrep", "rg", "jq", "sed", "awk"}
SYSTEM_NAMES = {"bin", "lib", "lib64", "sbin", "share", "local", "opt", "usr", "var", "etc", "tmp", "run", "src"}
TEA_KINDS = {"pr", "pulls", "pull", "issue", "issues", "i"}
TEA_VERBS = {"create", "c", "new", "edit", "e", "approve", "reject"}
TEA_VALUE_FLAGS = {"-r", "--repo", "-l", "--login", "-R", "--remote", "-o", "--output",
                   "-t", "--title", "-a", "--assignees", "-L", "--labels", "-m", "--milestone",
                   "--add-labels", "--remove-labels", "--deadline", "--head", "--base", "-b"}
GH_VALUE_FLAGS = {"-R", "--repo", "-t", "--title", "-B", "--base", "-H", "--head", "-a",
                  "--assignee", "-l", "--label", "-m", "--milestone", "-p", "--project",
                  "-r", "--reviewer", "--add-label", "--remove-label", "--add-assignee",
                  "--remove-assignee", "--add-reviewer", "--remove-reviewer", "-T", "--template"}
STEER = "Write the body to a file in an earlier call and pass it with --body-file FILE (tea: -d \"$(cat FILE)\"), so this guard reads what goes out."
CAT_SUBST = re.compile(r"^\$\((?:cat\s+|<\s*)((?:'[^']*'|\"[^\"$`]*\"|[^\s$()`;|&<>'\"]|\$\{?[A-Za-z_][A-Za-z0-9_]*\}?)+)\s*\)$")
ASSIGN = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", re.S)


HEREDOC = re.compile(r"<<-?[ \t]*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1[^\n]*\n(.*?)(?:\n[ \t]*\2[ \t]*(?=\n|$)|$)", re.S)
WRITERS = {"tee", "cp", "mv", "install", "ln", "dd", "sed", "perl"}


def strip_heredocs(command):
    """Drop each here-doc's text, which is data, not commands; keep its opening line.

    Return the command and the texts, in order. A text whose delimiter is
    unquoted and that holds $ or a backtick is None: the shell expands it.
    """
    texts = []

    def keep(m):
        quoted = bool(m.group(1))
        texts.append(m.group(3) + "\n" if quoted or not re.search(r"[$`]", m.group(3)) else None)
        return m.group(0).split("\n", 1)[0] + "\n"

    return HEREDOC.sub(keep, command), texts


def expand(word, env):
    """Expand $NAME and ${NAME} from env, then the hook's own environment; None when one is unset."""
    def sub(m):
        name = m.group(1) or m.group(2)
        return env[name] if name in env else os.environ.get(name, m.group(0))
    out = re.sub(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)", sub, word)
    return None if "$" in out else out


def written(seg, env, heredoc):
    """Return {path: text or None} for what a command segment may write.

    The text is known only for cat > FILE fed by a here-doc whose text is literal.
    """
    out = {}
    for j, t in enumerate(seg[:-1]):
        if t in {">", ">>", ">|"}:
            path = expand(seg[j + 1], env) or seg[j + 1]
            whole = t != ">>" and seg[0] == "cat" and "<<" in seg and heredoc is not None
            out[path] = heredoc if whole else None
    if os.path.basename(seg[0]) in WRITERS:
        out.update({expand(w, env) or w: None for w in seg[1:]})
    return out


LIT_TICK, LIT_DOLLAR = "\x01", "\x02"


def protect(command):
    """Mark each backtick and $ the shell takes literally: in single quotes, or escaped."""
    out, quote, i = [], "", 0
    while i < len(command):
        ch = command[i]
        if quote == "'":
            out.append({"`": LIT_TICK, "$": LIT_DOLLAR}.get(ch, ch))
            quote = "" if ch == "'" else quote
        elif ch == "\\" and i + 1 < len(command) and command[i + 1] in "`$":
            out.append(LIT_TICK if command[i + 1] == "`" else LIT_DOLLAR)
            i += 1
        else:
            if ch in "'\"" and not quote:
                quote = ch
            elif ch == quote:
                quote = ""
            out.append(ch)
        i += 1
    return "".join(out)


def restore(text):
    return text.replace(LIT_TICK, "`").replace(LIT_DOLLAR, "$")


def tokens(command):
    lex = shlex.shlex(command, posix=True, punctuation_chars="();<>|&\n")
    lex.whitespace = " \t\r"
    lex.whitespace_split = True
    return list(lex)


def segments(toks):
    seg = []
    for t in toks:
        if t and set(t) <= set(";&|()\n"):
            if seg:
                yield seg
            seg = []
        else:
            seg.append(t)
    if seg:
        yield seg


def number_of(word):
    m = re.fullmatch(r"#?(\d+)", word) or re.search(r"/(?:pull|pulls|issues)/(\d+)/?$", word)
    return m.group(1) if m else None


def parse_post(seg):
    """Return (tool, args after the verb) when seg is a post, else None."""
    for i, word in enumerate(seg):
        base = os.path.basename(word)
        if base == "gh":
            j = i + 1
            while j < len(seg) and seg[j].startswith("-"):
                j += 2 if seg[j] in GH_GLOBAL_VALUE_FLAGS else 1
            if len(seg) > j + 1 and (seg[j], seg[j + 1]) in GH_POSTS:
                rest = seg[j + 2:]
                if seg[j + 1] == "review":  # there -c is --comment, a switch, not a body
                    rest = [w for w in rest if w not in {"-c", "--comment"}]
                return "gh", rest
            if len(seg) > j and seg[j] == "api":
                return "gh-api", seg[j + 1:]
        if base == "tea" and len(seg) > i + 2 and seg[i + 1] in TEA_KINDS and seg[i + 2] in TEA_VERBS:
            return ("tea-comment" if seg[i + 2] in {"approve", "reject"} else "tea"), seg[i + 3:]
        if base == "tea" and len(seg) > i + 1 and seg[i + 1] in {"comment", "comments", "c"}:
            return "tea-comment", seg[i + 2:]


def wraps_post(word):
    """True when a quoted word, run as a command (bash -c, eval, ssh), would post."""
    try:
        inner = list(segments(tokens(protect(restore(word)))))
    except ValueError:
        return bool(re.search(r"\b(gh|tea)\b", word))
    return any(posts(parse_post(seg)) or any(" " in w and wraps_post(w) for w in seg[1:]) for seg in inner)


def posts(post):
    """True when a parsed command sends text: any post, or a gh api call with fields."""
    return bool(post) and (post[0] != "gh-api" or any(a.startswith(("-f", "-F", "--field", "--raw-field", "--input")) for a in post[1]))


def read_args(tool, args):
    """Return (bodies as (kind, value or None), number).

    A redirect's target is skipped: gh and tea read a body from stdin only
    through --body-file - or --description-file -, which check_body refuses.
    """
    bodies, number = [], None
    positional = []
    i = 0
    while i < len(args):
        a = args[i]
        if a in {"<", ">", ">>", ">&", "<<", "<<<", "<&"}:
            i += 2
            continue
        known = GH_BODY_FLAGS if tool == "gh" else TEA_BODY_FLAGS
        flag, eq, val = a.partition("=")
        if not eq and a[:2] in known and not a.startswith("--") and len(a) > 2:
            flag, eq, val = a[:2], "=", a[2:]  # a short flag with its value glued on
        if not eq:
            val = args[i + 1] if i + 1 < len(args) else None
        step = 1 if eq else 2
        if flag in known:
            bodies.append((known[flag], val))
        elif a.startswith("-"):
            step = step if flag in (GH_VALUE_FLAGS if tool == "gh" else TEA_VALUE_FLAGS) else 1
        else:
            positional.append(a)
            step = 1
        i += step
    if positional:
        number = number_of(positional[0])
    if tool == "tea-comment":
        bodies += [("comment", word) for word in positional[1:]]
    return bodies, number


def leak_lines(text):
    found = []
    home = os.environ.get("HOME", "")
    user = os.environ.get("USER", "")
    path = re.compile(r"(^|[^\w.}/-])(/(home|Users)/[^/\s<$\{][^/\s]*/|/root/)|/nix/sto[r]e/")  # local-path-ok: the pattern itself
    user_pat = re.compile(r"(^|[^\w.~}/-])(/[^/\s]+)*/" + re.escape(user) + r"/|(^|[^\w.-])" + re.escape(user) + "@") if len(user) > 2 and user not in SYSTEM_NAMES else None
    for n, line in enumerate(text.splitlines(), 1):
        line = re.sub(r"/{2,}", "/", line.replace("file://", " "))
        if "\x1b" in line or "\x07" in line or re.search(r"\^\[(\[[0-9;?]*[A-Za-z]|\]8;)", line):
            found.append(f"line {n}: terminal codes, as a pasted gh or tea view holds")
        if path.search(line) or (len(home) > 1 and home in line) or (user_pat and user_pat.search(line)):
            found.append(f"line {n}: names a path into this machine")
    return found


def body_text(kind, val, cwd, env, fresh):
    """Return (text, None), or (None, why the body can't be read)."""
    if val is None:
        return None, "a body flag has no value. " + STEER
    m = CAT_SUBST.match(val) if kind != "file" else None
    if m:
        kind, val = "file", re.sub(r"['\"]", "", m.group(1))
    if kind == "file":
        raw, val = val, expand(val, env)
        if val is None:
            return None, f"the body file {raw} holds a variable this guard can't expand. Pass the file's literal path."
        if val.startswith(("/dev/", "/proc/")) and val != "/dev/null":
            return None, f"the body file {val} is a stream this guard can't read. " + STEER
        if val in fresh:
            if fresh[val] is None:
                return None, f"the body file {val} is written earlier in this same command, so this guard would read the old file. Write it in one call, then post in the next."
            return fresh[val], None
    if kind != "file":
        if "$(" in val or "`" in val:
            return None, "the body comes from a command substitution, which this guard can't check. " + STEER
        text = expand(val, {k: v for k, v in env.items() if "$" not in v})
        if text is None:
            return None, "the body holds a variable this guard can't expand. " + STEER
        return restore(text), None
    val = restore(val)
    try:
        with open(os.path.join(cwd, os.path.expanduser(val)), encoding="utf-8", errors="replace") as f:
            return f.read(), None
    except OSError:
        return None, f"the body file {val} can't be read. " + STEER


def check_post(tool, args, cwd, env, fresh):
    """Return the problems in one post's bodies."""
    problems = []
    bodies, number = read_args(tool, args)
    for kind, val in bodies:
        text, why = body_text(kind, val, cwd, env, fresh)
        if why:
            problems.append(why)
            continue
        if kind == "title":
            problems += leak_lines(text)
            continue
        first = next((l for l in text.splitlines() if l.strip()), "")
        m = re.match(r"^\s*#\s+#(\d+)\b", first)
        if m and number and m.group(1) != number:
            problems.append(f"the body opens with the heading of #{m.group(1)}, but it posts to #{number}: it is another item's text.")
        problems += leak_lines(text)
    return problems


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0
    command = (payload.get("tool_input") or {}).get("command") or ""
    cwd = payload.get("cwd") or os.getcwd()
    try:
        stripped, texts = strip_heredocs(command)
        stripped = stripped.replace("\\\n", " ")
        toks = tokens(protect(stripped))
        if toks.count("<<") != len(texts):
            texts = [None] * toks.count("<<")  # a here-doc inside quotes: no text is trusted
    except ValueError:
        if re.search(r"\b(gh\s+(pr|issue|api)|tea\s+\S+\s+(create|edit|c|e)|tea\s+comment)\b", command):
            print("post-body-guard: refused, this command's quoting does not parse, so its body can't be read. " + STEER + " Nothing ran.", file=sys.stderr)
            return 2
        return 0
    problems = []
    fresh, env = {}, {}
    for seg in segments(toks):
        while seg and ASSIGN.match(seg[0]):
            name, value = ASSIGN.match(seg.pop(0)).groups()
            env[name] = (None if "`" in value else expand(value, env)) or "$unknown"
        if not seg:
            continue
        heredoc = texts.pop(0) if "<<" in seg and texts else None
        if seg[0] == "cd" and len(seg) > 1:
            cwd = os.path.join(cwd, os.path.expanduser(expand(seg[1], env) or seg[1]))
        seg = [w if "$" not in w else expand(w, env) or w for w in seg[:1]] + seg[1:]
        post = parse_post(seg)
        head = next((w for w in seg if w not in SHELL_WORDS), "")
        if not post and head != "for" and os.path.basename(head) not in TEXT_TOOLS and any(" " in w and wraps_post(w) for w in seg[1:]):
            problems.append("a post runs inside a quoted string (bash -c, eval, ssh), which this guard can't read. Run the post as its own command.")
        written_before = dict(fresh)
        fresh.update(written(seg, env, heredoc))
        if not post:
            continue
        tool, args = post
        if tool == "gh-api":
            if "--input" in args or any(re.match(r"^(--(raw-)?field=|-[fF])?body=", a) for a in args):
                problems.append("gh api sends a body this guard can't check. " + STEER)
            problems += [p for a in args for p in leak_lines(restore(a))]
        else:
            problems += check_post(tool, args, cwd, env, written_before)
    if not problems:
        return 0
    print("post-body-guard: refused, this post would publish what it must not:", file=sys.stderr)
    shown = list(dict.fromkeys(problems))
    for p in shown[:6]:
        print("  " + p, file=sys.stderr)
    if len(shown) > 6:
        print(f"  and {len(shown) - 6} more.", file=sys.stderr)
    print("Rewrite the body with repo-relative paths, or post the right item's text. Nothing in this command ran, not even its other steps.", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
