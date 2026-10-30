#!/usr/bin/env python3
"""Mutation pass over every hook script in the plugin.

Each mutant changes one line of one script: an exit code, a comparison, a
logic operator, a negation, or the whole line deleted. The script's tests run
against it in a copy of the repo. A mutant they all pass is a survivor.

Usage: mutate-hooks.py [--jobs N] [script ...]

Prints "script <name>: <killed>/<mutants>" for each script, then each survivor
as "survivor <script>:<line>: <mutated line>", then "survivors: <n>". Exits 1
when any mutant survives. A line ending in "# mutant-ok: <reason>" is skipped,
for code no test can tell apart from its mutant.
"""
import concurrent.futures
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "plugins", "vicky-skills", "scripts")
GIT_GUARDS = ["local-path-guard", "push-behind-guard", "checkout_guard_approved_examples", "red_first_approved_examples"]
TESTS = {
    "after-push.sh": ["after-push"],
    "approved-spec-guard.sh": ["approved-spec-guard", "approved_tests_yes_approved_examples"],
    "auto-tidy.sh": ["auto-tidy"],
    "checkout-guard.sh": ["checkout_guard_approved_examples"],
    "draft-lock.sh": ["red_first_approved_examples"],
    "gamma-shift.sh": ["gamma-shift"],
    "gate-notify.sh": ["gate-notify"],
    "git-hook-lib.sh": GIT_GUARDS,
    "issue-guard.sh": ["issue-guard"],
    "local-path-guard.sh": ["local-path-guard"],
    "pr-guard.sh": ["pr-guard"],
    "push-behind-guard.sh": ["push-behind-guard"],
    "red-first-check.sh": ["red_first_approved_examples"],
    "red-first-guard.sh": ["red_first_approved_examples"],
    "skill-ledger.sh": ["skill_ledger_approved_examples"],
    "spark-joy.sh": ["spark-joy"],
    "tea-stdin.awk": ["tea-stdin"],
    "tea-stdin.sh": ["tea-stdin"],
    "ticket-drift.sh": ["ticket_drift_approved_examples"],
}
SWAPS = [
    ("exit 0", "exit 1"), ("exit 2", "exit 0"), ("exit 1", "exit 0"),
    (" -eq ", " -ne "), (" -ne ", " -eq "), (" -lt ", " -ge "), (" -ge ", " -lt "),
    (" -gt ", " -le "), (" -le ", " -gt "), (" && ", " || "), (" || ", " && "),
    (" == ", " != "), (" != ", " == "), (" = ", " != "), ("if ! ", "if "), ("[ ! ", "[ "),
    ("-q ", "-qv "), ("true|1)", "xtrue|x1)"),
]
STRUCTURE = re.compile(r"^\s*(fi|done|esac|then|else|do|;;|\}|\{|\)|[^\s()]+\)|.*\(\)\s*\{?|EOF|PY)\s*$")


def mutants(text):
    lines = text.split("\n")
    for n, line in enumerate(lines):
        code = line.strip()
        if not code or code.startswith("#") or n == 0 or "# mutant-ok:" in line:
            continue
        for old, new in SWAPS:
            if old in line:
                yield n, line.replace(old, new, 1)
        control = code.startswith(("if ", "elif ", "while ", "for ", "case "))
        if not control and not STRUCTURE.match(line) and not code.endswith(("\\", "'", "{", "(", "|")):
            yield n, ":"


def run(script, n, mutated, original):
    work = tempfile.mkdtemp(prefix="mutant-")
    try:
        for part in ("plugins", "tests"):
            shutil.copytree(os.path.join(ROOT, part), os.path.join(work, part), symlinks=True)
        lines = original.split("\n")
        lines[n] = mutated
        with open(os.path.join(work, "plugins", "vicky-skills", "scripts", script), "w") as handle:
            handle.write("\n".join(lines))
        env = dict(os.environ, MUTATE_HOOKS_INNER="1")
        for test in TESTS[script]:
            done = subprocess.run(["bash", os.path.join(work, "tests", test + ".test.sh")], env=env,
                                  stdin=subprocess.DEVNULL, capture_output=True, timeout=120)
            if done.returncode != 0:
                return True
        return False
    except subprocess.TimeoutExpired:
        return True
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main(argv):
    jobs, names = os.cpu_count() or 2, []
    while argv:
        arg = argv.pop(0)
        if arg == "--jobs":
            jobs = int(argv.pop(0))
        else:
            names.append(arg)
    if os.environ.get("MUTATE_HOOKS_INNER"):
        # A test run inside a mutation pass must not start another pass.
        for name in sorted(os.listdir(SCRIPTS)):
            print(f"script {name}: skipped inside a pass")
        print("survivors: 0")
        return 0
    names = names or sorted(os.listdir(SCRIPTS))
    unmapped = [name for name in names if name not in TESTS]
    if unmapped:
        print("no tests mapped for: " + " ".join(unmapped))
        return 2
    survivors = []
    with concurrent.futures.ThreadPoolExecutor(jobs) as pool:
        for name in names:
            with open(os.path.join(SCRIPTS, name)) as handle:
                original = handle.read()
            found = list(mutants(original))
            killed = list(pool.map(lambda m: run(name, m[0], m[1], original), found))
            print(f"script {name}: {sum(killed)}/{len(found)}", flush=True)
            survivors += [f"survivor {name}:{n + 1}: {line.strip()}" for (n, line), k in zip(found, killed) if not k]
    print("\n".join(survivors)) if survivors else None
    print(f"survivors: {len(survivors)}")
    return 1 if survivors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
