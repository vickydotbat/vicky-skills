#!/usr/bin/env bash
# law-lint: every law in a repo's agent files names the check that proves it.
#
#   law-lint.sh                 list each law with no proof or a missing one; exit 1 on any
#   law-lint.sh --since <base>  the same, but only laws this branch added fail; the rest are backlog
#   law-lint.sh reach <base>    list the laws the diff since <base> reaches, with their proofs
#   law-lint.sh prove <base>    run the reached proofs, print one Laws line; exit 1 on a red
#                               proof or an unproven law the branch added
#   law-lint.sh stale <model>   list each law whose eval case last passed on another model,
#                               or holds no passed record: the laws to run again
#
# A law is a top-level "- " bullet or "1. " step in AGENTS.md, CLAUDE.md,
# docs/agents/*.md or a SKILL.md. Lines in code fences, under an Examples,
# Pointers, Comments or Notes heading, and lines that only link are not laws.
# Its proof is a "Proven by: <repo-relative path>" line inside the item.
# A "Law proofs: off" line in docs/agents/ switches the lint off.
set -u
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root" || exit 2 # mutant-ok: the folder git or pwd just printed exists
exec python3 - "$@" <<'PY'
import glob, os, re, subprocess, sys

SKIP_DIRS = {".git", "node_modules", "vendor"}
SKIP_HEADINGS = {"examples", "pointers", "comments", "notes"}
ITEM = re.compile(r"^(?:- |\d+\. )(.*)")
PROOF = re.compile(r"^\s*Proven by:\s*(.*?)\s*$")
TIMEOUT = float(os.environ.get("LAW_LINT_TIMEOUT", "600"))  # seconds per proof
POINTER = re.compile(r"^(See\b.*|\[[^\]]*\]\([^)]*\)\.?)$")


def agent_files():
    for top, dirs, files in os.walk("."):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        rel = os.path.relpath(top)
        for f in sorted(files):
            path = os.path.normpath(os.path.join(rel, f))
            if f in ("AGENTS.md", "CLAUDE.md", "SKILL.md") or (
                    rel == os.path.join("docs", "agents") and f.endswith(".md")):
                yield path


def switched_off():
    return next((p for p in sorted(glob.glob("docs/agents/*.md"))
                 if any(l.strip() == "Law proofs: off" for l in open(p, errors="replace"))), None)


def laws(path):
    found, fence, skip, current = [], False, False, None
    for n, line in enumerate(open(path, errors="replace").read().splitlines(), 1):
        if line.lstrip().startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        if line.startswith("#"):
            current = None
            skip = line.lstrip("#").strip().lower() in SKIP_HEADINGS
            continue
        m = PROOF.match(line)
        # A proof at the left margin is the whole file's, never the last item's.
        if m and current is not None and line[:1].isspace():
            current["proof"] = m.group(1) or None
            continue
        if line and not line[0].isspace():
            current = None
            m = ITEM.match(line)
            if m and not skip and not POINTER.match(m.group(1).strip()):
                current = {"file": path, "line": n, "text": m.group(1).strip(), "proof": None}
                found.append(current)
    return found


def all_laws():
    return [law for f in agent_files() for law in laws(f)]


def problem(law):
    if not law["proof"]:
        return "unproven"
    if not os.path.exists(law["proof"]):
        return "broken"
    return None


def say(kind, law):
    tail = f" (proof {law['proof']} is missing)" if kind == "broken" else ""
    print(f"{kind} {law['file']}:{law['line']}: {law['text']}{tail}")


def report(new, backlog):
    for kind, law in new:
        say(kind, law)
    for _, law in backlog:
        say("backlog", law)


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True).stdout


def added_lines(base):
    added, path = {}, None
    for line in git("diff", "-U0", "--no-color", "--src-prefix=a/", "--dst-prefix=b/", base, "--").splitlines():
        if line.startswith("+++ "):
            path = line[6:] if line.startswith("+++ b/") else None
        m = re.match(r"^@@ -\S+ \+(\d+)(?:,(\d+))? @@", line)
        if m and path:
            start, count = int(m.group(1)), int(m.group(2) or 1)
            added.setdefault(path, set()).update(range(start, start + count))
    return added


def sort_problems(base):
    """(new, backlog): laws with a problem, split by whether the branch added them."""
    added = added_lines(base) if base else None
    new, backlog = [], []
    for law in all_laws():
        kind = problem(law)
        if kind:
            fresh = added is None or law["line"] in added.get(law["file"], ())
            (new if fresh else backlog).append((kind, law))
    return new, backlog


def reached(base):
    changed = set(git("diff", "--name-only", base, "--").split())
    out = []
    for law in all_laws():
        proof = law["proof"]
        hit = law["file"] in changed
        if proof and not hit:
            hit = any(c == proof or c.startswith(proof.rstrip("/") + "/") for c in changed)
        if proof and not hit and os.path.isfile(proof):
            text = open(proof, errors="replace").read()
            hit = any(c in text for c in changed)
        if hit:
            out.append(law)
    return out


def lint(args):
    base = None
    if args[:1] == ["--since"]:
        if len(args) < 2:
            sys.exit("law-lint: --since needs a base ref")
        base = args[1]
    new, backlog = sort_problems(base)
    report(new, backlog)
    return 1 if new else 0


def reach(base):
    for law in reached(base):
        print(f"{law['file']}:{law['line']} {law['proof'] or '-'} {law['text']}")
    return 0


def short(law):
    # Markdown marks go, so a cut inside a code span or bold run can't leave it open in a body.
    text = re.sub(r"~~|[*`<>|\[\]]", "", law["text"])
    return text if len(text) <= 60 else text[:57].rstrip() + "..."


def last_pass(case):
    """'<model> <date>' from an eval case's passed file, which tests/evals/lib.sh writes."""
    path = os.path.join(case, "passed")
    return open(path, errors="replace").read().strip() if os.path.isfile(path) else None


def pass_note(passed):
    return f"passed on {passed}" if passed else "never recorded"


def stale(model):
    for law in all_laws():
        proof = law["proof"]
        if not proof or not os.path.isdir(proof):
            continue
        passed = last_pass(proof)
        if passed and passed.split()[0] == model:
            continue
        print(f"{law['file']}:{law['line']} {short(law)} ({proof}: {pass_note(passed)})")
    return 0


def prove(base):
    parts, red = [], False
    for law in reached(base):
        proof = law["proof"]
        if not proof:
            continue
        if os.path.isfile(proof) and os.access(proof, os.X_OK):
            try:
                ok = subprocess.run([os.path.abspath(proof)], capture_output=True, timeout=TIMEOUT).returncode == 0
            except subprocess.TimeoutExpired:
                ok = False
            result = "passed" if ok else "failed"
            red |= not ok
        elif os.path.isdir(proof):  # an eval case: a run costs money, so show its last pass
            result = "not run, " + pass_note(last_pass(proof))
        else:
            result = "not run"  # a plain file is no command
        parts.append(f"{law['file']}:{law['line']} {short(law)} ({proof}: {result})")
    print("Laws: " + ("; ".join(parts) if parts else "none touched"))
    new, backlog = sort_problems(base)
    report(new, backlog)
    return 1 if red or new else 0


def main(args):
    off = switched_off()
    if off:
        print(f"law proofs: off in {off}")
        return 0
    if args[:1] in (["reach"], ["prove"]):
        if len(args) < 2:
            sys.exit(f"law-lint: {args[0]} needs a base ref")
        return (reach if args[0] == "reach" else prove)(args[1])
    if args[:1] == ["stale"]:
        if len(args) < 2:
            sys.exit("law-lint: stale needs a model, such as claude-opus-5-5")
        return stale(args[1])
    return lint(args)


sys.exit(main(sys.argv[1:]))
PY
