#!/usr/bin/env python3
"""Mutation pass over the plugin's hook scripts, inside a time budget.

Usage: mutate-hooks.py [--jobs N] [--all] [--survivors] [--check] [--budget SECONDS] [script ...]

Each mutant changes one line of one script: an exit code, a comparison, a
logic operator, a negation, or the whole line deleted. The script's tests run
against it, fastest first, and the first red one kills it. A mutant they all
pass is a survivor.

Only what changed is mutated. tests/mutation-proof.tsv keeps each script's
last clean pass against two hashes: the script's, and its tests' with the
script's own line of the test map below. A script
whose hashes match is proven without a run. A script whose tests changed is
mutated whole. A script whose code alone changed is mutated on the lines that
differ from the merge base with origin/main. --all mutates every line of every
script. A clean pass always writes its proof (--record is accepted and does
nothing more). Each pass keeps its survivors in tests/.mutation-survivors, and
--survivors mutates only those lines: a quick check of a fix before the full
pass, which records nothing. --check mutates nothing: it names each script
whose proof is stale and exits 1 when any is.

The pass stops before it starts when its estimate (mutants x the slowest test
time / jobs) passes the budget, 3000 seconds by default, and stops mid-run at
the budget. Either way it exits 3 and names what was left unrun.

Prints "script <name>: <killed>/<mutants>" for each script, then each survivor
as "survivor <script>:<line>: <mutated line>", then "survivors: <n>". Exits 1
when any mutant survives. A line ending in "# mutant-ok: <reason>" makes no
mutant, and one ending in "# mutant-ok delete: <reason>" makes no deletion,
for code no test can tell apart from its mutant.

Every test runs under `ulimit -d`, MUTANT_MEMORY of allocated memory per
process, on the real script too, so a test that needs more fails before the
pass starts rather than counting as a kill. The data limit leaves alone the
address space a runtime such as Bun reserves and never uses.
"""
import concurrent.futures
import hashlib
import os
import queue
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLUGIN = os.path.join(ROOT, "plugins", "vicky-skills")
SCRIPTS = os.path.join(PLUGIN, "scripts")
PROOF = os.path.join(ROOT, "tests", "mutation-proof.tsv")
SURVIVORS = os.path.join(ROOT, "tests", ".mutation-survivors")
# Each process a mutant's test starts may allocate this much memory. A mutant that
# loops while it grows a string dies here, not at its timeout with the
# machine's memory full.
MUTANT_MEMORY = 2**30
GIT_GUARDS = ["git-guard", "git_guard_approved_examples", "push-behind-guard", "merged-branch-guard", "local-path-guard", "red_first_approved_examples"]
TESTS = {
    "familiar-voice.sh": ["familiar_approved_examples", "familiar"],
    "auto-tidy.sh": ["auto-tidy", "auto-tidy-clone", "clone_takeover_approved_examples"],
    "stale-copy-hint.sh": ["stale_copy_hint_approved_examples", "stale-copy-hint", "hint_once_approved_examples"],
    "approved-spec.sh": ["approved-spec", "open-draft"],
    "git-guard.sh": ["git-guard", "git_guard_approved_examples"],
    "gamma-shift.sh": ["gamma-shift"],
    "publickey-hint.sh": ["publickey-hint"],
    "publish-guard.sh": ["publish-guard"],
    "since-user.sh": ["publish-guard"],
    "gate-notify.sh": ["gate-notify"],
    "keep-awake.sh": ["keep-awake", "keep-awake-crash", "sleep_lock_approved_examples"],
    "git-hook-lib.sh": GIT_GUARDS,
    "ai-credit.sh": ["git-guard", "git_guard_approved_examples", "pr-guard", "pr_guard_ai_credit_approved_examples"],
    "heredoc-strip.awk": ["heredoc-strip"] + GIT_GUARDS + ["pr-guard", "pkill_guard_approved_examples"],
    "quote-mask.awk": ["pr-guard"],
    "local-path-guard.sh": ["local-path-guard"],
    "draft-guard.sh": ["draft-guard"],
    "skill-started.sh": ["draft-guard", "ticket-filing-guard"],
    "pr-guard.sh": ["pr-guard", "pr_guard_ai_credit_approved_examples", "pr_guard_one_pr_approved_examples", "pr_guard_create_approved_examples"],
    "push-behind-guard.sh": ["push-behind-guard"],
    "red-first-check.sh": ["red-first", "red_first_approved_examples"],
    "red-first-guard.sh": ["red-first", "red-first-paths", "red_first_approved_examples"],
    "skill-ledger.sh": ["skill_ledger_approved_examples"],
    "spark-joy.sh": ["spark-joy", "no-remote-quiet"],
    "tea-stdin.awk": ["tea-stdin"],
    "tea-stdin.sh": ["tea-stdin", "refusal-note"],
    "pkill-guard.sh": ["pkill_guard_approved_examples", "pkill-guard", "refusal-note"],
    "read-item.sh": ["read_item_approved_examples", "read-item"],
    "gate-state-guard.sh": ["gate-state-guard"],
    "ticket-drift.sh": ["ticket_drift_approved_examples", "no-remote-quiet"],
    "plane-block-guard.sh": ["plane_block_approved_examples", "plane-block-guard", "refusal-note"],
    "watch.sh": ["watch", "watch_approved_examples"],
    "assign-expand.sh": ["pr-guard", "worktree-place"],
    "worktree-place.sh": ["worktree-place", "worktree_place_approved_examples", "worktree_cleanup_approved_examples", "worktree_drop_approved_examples"],
    "lesson-ledger.sh": ["lesson-ledger", "lesson_ledger_approved_examples"],
    "todo-reminder.sh": ["todo-reminder", "todo_reminder_approved_examples"],
    "springboard.sh": ["springboard", "springboard_approved_examples", "summit_approved_examples"],
    "summit.sh": ["summit", "summit_approved_examples"],
    "plugin-data.sh": ["summit", "lesson-ledger"],
    "stop-reply.sh": ["stop-reply", "review-fresh-guard", "read-before-asking"],
    "review-fresh-guard.sh": ["review-fresh-guard"],
    "read-before-asking.sh": ["read-before-asking"],
    "fetch-place-hint.sh": ["fetch-place-hint"],
    "foreign-post-hint.sh": ["foreign-post-hint"],
    "adr-scope-hint.sh": ["adr-scope-hint"],
    "ticket-filing-guard.sh": ["ticket-filing-guard"],
    "step-hint.sh": ["mutation_step_approved_examples", "step-hint", "review-prevention", "do_imp_pass_approved_examples", "read_item_approved_examples"],
    "lesson-hint.sh": ["lesson-hint", "engrave_approved_examples", "hint_once_approved_examples"],
    "merged-branch-guard.sh": ["merged-branch-guard", "merged_branch_approved_examples"],
    "merge-point.sh": ["merged-branch-guard", "merged_branch_approved_examples", "auto-tidy-clone", "clone_takeover_approved_examples"],
    # Skill scripts, by their path under the plugin.
    "skills/engineering/captains-log/scripts/hook-audit.py": ["hook-audit"],
    "skills/engineering/captains-log/scripts/idle-skills.py": ["idle_skills_approved_examples"],
    "skills/engineering/decision-record/scripts/check-adr.sh": ["check-adr", "decision-record-skill"],
    "skills/engineering/lay-course/scripts/draw-chart.py": ["draw-chart", "black_hole_drawing_approved_examples"],
    "skills/productivity/drawing-board/scripts/board.py": ["drawing-board", "drawing_board_approved_examples"],
    "skills/productivity/drawing-board/scripts/fetch-drawio.sh": ["fetch-drawio"],
    "skills/productivity/familiar/scripts/familiar-replay.sh": ["familiar-replay", "familiar_replay_approved_examples", "familiar_evidence_approved_examples"],
    "skills/productivity/familiar/scripts/familiar-sessions.sh": ["familiar", "familiar-sessions-off", "familiar_approved_examples", "familiar_catchup_approved_examples", "familiar_handoff_id_approved_examples", "familiar_intent_approved_examples"],
    "skills/productivity/familiar/scripts/familiar-shapes.sh": ["familiar-shapes", "familiar_shapes_approved_examples"],
    "skills/productivity/familiar/scripts/familiar-visibility.py": ["familiar-visibility", "familiar_visibility_approved_examples", "familiar_evidence_approved_examples"],
    "skills/productivity/familiar/scripts/familiar-watch.sh": ["familiar", "familiar_watch_approved_examples", "familiar_watch_moves_approved_examples", "familiar_catchup_approved_examples", "familiar-visibility", "familiar-watch-move-empty"],
    "skills/productivity/human-voice/scripts/lint-tells.py": ["lint-tells", "lint_tells_approved_examples"],
    "skills/productivity/interactive-page/scripts/open-draft.sh": ["open-draft", "open-draft-page"],
    "skills/productivity/interactive-page/scripts/open-page.sh": ["open-draft", "interactive_page_approved_examples", "open-draft-page"],
    "skills/productivity/interactive-page/scripts/page.py": ["interactive-page", "interactive_page_approved_examples", "page_needs_ticks_approved_examples", "page_owns_pages_approved_examples"],
    "skills/productivity/interactive-page/scripts/write-page.py": ["write-page", "page_needs_ticks_approved_examples"],
    "skills/productivity/over-to-you/scripts/checklist.py": ["over-to-you-checklist"],
    "skills/productivity/over-to-you/scripts/lint-checklist.py": ["over_to_you_lint_checklist"],
    "skills/productivity/standing-orders/scripts/todo.sh": ["todo-sh", "todo_script_approved_examples"],
    "skills/productivity/video-captions/scripts/flatten-captions.sh": ["flatten-captions"],
}
# The shared exit-code test reaches every hook and runs in a fraction of a second.
TESTS = {name: tests if "/" in name else ["hook-exits"] + tests for name, tests in TESTS.items()}
SWAPS = [
    ("exit 0", "exit 1"), ("exit 2", "exit 0"), ("exit 1", "exit 0"),
    (" -eq ", " -ne "), (" -ne ", " -eq "), (" -lt ", " -ge "), (" -ge ", " -lt "),
    (" -gt ", " -le "), (" -le ", " -gt "), (" && ", " || "), (" || ", " && "),
    (" == ", " != "), (" != ", " == "), (" = ", " != "), ("if ! ", "if "), ("[ ! ", "[ "),
    ("grep -q", "grep -qv"), ("true|1)", "xtrue|x1)"),
]
# Python has its own operators, and a deleted line keeps its indent as `pass`.
PY_SWAPS = [
    (" == ", " != "), (" != ", " == "), (" < ", " >= "), (" >= ", " < "), (" > ", " <= "), (" <= ", " > "),
    (" and ", " or "), (" or ", " and "), ("if not ", "if "), (" not in ", " in "), (" in ", " not in "),
    ("return True", "return False"), ("return False", "return True"), ("sys.exit(1)", "sys.exit(0)"),
    ("sys.exit(0)", "sys.exit(1)"), (" + 1", " - 1"), (" - 1", " + 1"),
]
STRUCTURE = re.compile(r"^\s*(fi|done|esac|then|else|do|;;|\}|\{|\)|[^\s()]+\)|.*\(\)\s*\{?|EOF|PY)\s*$")
# A line that only talks to a person makes no mutant: no test reads its wording.
ARID = re.compile(r"^\s*(echo|printf)\b[^|;&]*>&2\s*$|^\s*(\"[^\"]*\"\s*)+\\?$")


def path_of(script):
    """A hook script by its name, a skill script by its path under the plugin (skills/<group>/<skill>/scripts/...)."""
    return os.path.join(PLUGIN if "/" in script else SCRIPTS, script)


def skill_scripts():
    """Skill scripts that hold a proof. One joins the default set once a named pass has proven it."""
    return sorted(name for name in proofs() if name.startswith("skills/"))


def string_lines(text):
    """0-based lines a Python string spans past its first: text there is no code."""
    import io, tokenize
    inside = set()
    try:
        for tok in tokenize.generate_tokens(io.StringIO(text).readline):
            if tok.type == tokenize.STRING:
                inside.update(range(tok.start[0], tok.end[0]))
                if tok.start[0] != tok.end[0]:
                    inside.add(tok.start[0] - 1)
    except (tokenize.TokenError, SyntaxError):
        pass  # a file that won't tokenise won't compile either, and compiles() drops its mutants
    return inside


def compiles(text, n, line):
    lines = text.split("\n")
    lines[n] = line
    try:
        compile("\n".join(lines), "<mutant>", "exec")
        return True
    except SyntaxError:
        return False


def mutants(text, lines_wanted, awk=False, py=False):
    if py:
        skip = string_lines(text)
        for n, line in shell_mutants(text, lines_wanted, awk, py):
            if n not in skip and compiles(text, n, line):
                yield n, line
    else:
        yield from shell_mutants(text, lines_wanted, awk, py)


def shell_mutants(text, lines_wanted, awk=False, py=False):
    for n, line in enumerate(text.split("\n")):
        code = line.strip()
        if lines_wanted is not None and n + 1 not in lines_wanted:
            continue
        if not code or code.startswith("#") or n == 0 or "# mutant-ok:" in line or code.startswith("set -") \
                or ARID.match(line):
            continue
        for old, new in PY_SWAPS if py else SWAPS:
            # "|| true" only matters under set -e, and awk's " = " is an assignment.
            if old == " || " and "|| true" in line or awk and old == " = ":
                continue
            if old in line:
                yield n, line.replace(old, new, 1)
        control = code.startswith(("if ", "elif ", "while ", "for ", "case "))
        # "# mutant-ok delete: <reason>" spares a line whose deletion no test can see.
        if "# mutant-ok delete:" in line:
            continue
        if py:
            if not code.endswith((":", ",", "(", "[", "{", "\\")) and not code.startswith((")", "]", "}", "@", "def ", "class ", "import ", "from ")):
                yield n, line[:len(line) - len(line.lstrip())] + "pass"
        elif not control and not STRUCTURE.match(line) and not code.endswith(("\\", "'", "{", "(", "|")):
            yield n, ":"


def sha(paths, extra=""):
    digest = hashlib.sha256(extra.encode())
    for path in paths:
        with open(path, "rb") as handle:
            digest.update(handle.read())
    return digest.hexdigest()[:16]


def hashes(script):
    """The script's hash, and its tests' hash with its own line of the test map: the rest of the runner is no test."""
    tests = [os.path.join(ROOT, "tests", t + ".test.sh") for t in TESTS[script]]
    return sha([path_of(script)]), sha(tests, repr(TESTS[script]))


def last_survivors():
    """The lines that survived the last pass, by script, kept beside the proof."""
    found = {}
    try:
        with open(SURVIVORS) as handle:
            for line in handle:
                name, n = line.rstrip("\n").split("\t")
                found.setdefault(name, set()).add(int(n))
    except FileNotFoundError:
        pass
    return found


def proofs():
    try:
        with open(PROOF) as handle:
            return {row[0]: row[1:] for row in (line.rstrip("\n").split("\t") for line in handle) if len(row) == 4}
    except FileNotFoundError:
        return {}


def changed_lines(script):
    """Lines of the script that differ from the merge base, or None for the whole file."""
    path = os.path.relpath(path_of(script), ROOT)
    base = subprocess.run(["git", "-C", ROOT, "merge-base", "origin/main", "HEAD"], capture_output=True, text=True)
    if base.returncode:
        return None
    diff = subprocess.run(["git", "-C", ROOT, "diff", "-U0", base.stdout.strip(), "--", path],
                          capture_output=True, text=True).stdout
    if not diff:
        return set()
    if "new file mode" in diff:
        return None
    lines = set()
    for match in re.finditer(r"^@@ -\S+ \+(\d+)(?:,(\d+))? @@", diff, re.M):
        start, count = int(match.group(1)), int(match.group(2) or 1)
        lines.update(range(start, start + count))
    return lines


def replace(path, text):
    mode = os.stat(path).st_mode
    with tempfile.NamedTemporaryFile("w", dir=os.path.dirname(path), delete=False) as handle:
        handle.write(text)
    os.chmod(handle.name, mode)
    os.replace(handle.name, path)


def capped(test):
    """The command that runs a test with each of its processes held to MUTANT_MEMORY."""
    return ["bash", "-c", f'ulimit -d {MUTANT_MEMORY // 1024} && exec bash "$0"', test]


class Worker:
    """A copy of the repo's plugins and tests, made once and reused by every mutant it runs."""

    def __init__(self):
        self.root = tempfile.mkdtemp(prefix="mutant-")
        for part in ("plugins", "tests"):
            shutil.copytree(os.path.join(ROOT, part), os.path.join(self.root, part), symlinks=True)

    def run(self, script, text, timeouts):
        path = os.path.join(self.root, os.path.relpath(path_of(script), ROOT))
        # A new file renamed into place, since a test left running may still hold the old one open.
        replace(path, text)
        try:
            for test, limit in timeouts:
                # Its own process group, so a timeout stops every child the test started.
                proc = subprocess.Popen(capped(os.path.join(self.root, "tests", test + ".test.sh")),
                                        env=dict(os.environ, MUTATE_HOOKS_INNER="1"), stdin=subprocess.DEVNULL,
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                try:
                    code = proc.wait(timeout=limit)
                except subprocess.TimeoutExpired:
                    os.killpg(proc.pid, signal.SIGKILL)
                    proc.wait()
                    return True
                if code != 0:
                    return True
            return False
        finally:
            with open(path_of(script)) as handle:
                replace(path, handle.read())


def baseline(script):
    """Each test's time on the real script, fastest first, with its per-mutant timeout."""
    times = []
    for test in TESTS[script]:
        start = time.monotonic()
        done = subprocess.run(capped(os.path.join(ROOT, "tests", test + ".test.sh")), stdin=subprocess.DEVNULL,
                              env=dict(os.environ, MUTATE_HOOKS_INNER="1"), capture_output=True)
        took = time.monotonic() - start
        if done.returncode:
            sys.exit(f"mutate-hooks: {test} fails on the real {script}; fix it before a pass")
        # Stryker's rule: a mutant times out at the baseline times 1.5 plus a fixed margin.
        times.append((took, test, took * 1.5 + 5))
    return [(test, limit) for _, test, limit in sorted(times)], sum(t for t, _, _ in times)


def main(argv):
    jobs, names, everything, budget, check, again = os.cpu_count() or 2, [], False, 3000.0, False, False
    while argv:
        arg = argv.pop(0)
        if arg == "--jobs":
            jobs = int(argv.pop(0))
        elif arg == "--all":
            everything = True
        elif arg == "--record":
            pass  # a clean pass always records; the flag stays for old callers
        elif arg == "--survivors":
            again = True
        elif arg == "--check":
            check = True
        elif arg == "--budget":
            budget = float(argv.pop(0))
        else:
            names.append(arg)
    if os.environ.get("MUTATE_HOOKS_INNER"):
        # A test run inside a mutation pass must not start another pass.
        for name in sorted(os.listdir(SCRIPTS)):
            print(f"script {name}: skipped inside a pass")
        print("survivors: 0")
        return 0
    started = time.monotonic()
    names = names or sorted(os.listdir(SCRIPTS)) + skill_scripts()
    unmapped = [name for name in names if name not in TESTS]
    if unmapped:
        print("no tests mapped for: " + " ".join(unmapped))
        return 2
    if check:
        stale = [n for n in names if (proofs().get(n) or [None, None])[:2] != list(hashes(n))]
        for name in stale:
            print(f"stale: {name}")
        return 1 if stale else 0
    proven, plan, previous = proofs(), [], last_survivors()
    if again:
        # Only the lines the last pass left alive: a quick check before the full pass.
        names = [n for n in names if n in previous]
    for name in names:
        code_hash, test_hash = hashes(name)
        old = proven.get(name)
        if not again and not everything and old and old[0] == code_hash and old[1] == test_hash:
            print(f"script {name}: {old[2]}, proven at {code_hash}", flush=True)
            continue
        wanted = previous[name] if again else None if everything or not old or old[1] != test_hash else changed_lines(name)
        with open(path_of(name)) as handle:
            original = handle.read()
        found = list(mutants(original, wanted, name.endswith(".awk"), name.endswith(".py")))
        timeouts, total = baseline(name)
        plan.append((name, original, found, timeouts, total, code_hash, test_hash, wanted is None))
    # Most mutants die in the first, fastest test, so the full time per mutant is the worst case.
    estimate = sum(len(found) * total for _, _, found, _, total, *_ in plan) / jobs
    if estimate > budget:
        print(f"mutate-hooks: the worst case is {estimate:.0f} s, past the {budget:.0f} s budget. Narrow it: name "
              f"the scripts, or speed up their slowest tests.")
        return 3
    workers = queue.Queue()
    for _ in range(jobs):
        workers.put(Worker())

    def one(name, original, mutant, timeouts):
        if time.monotonic() - started > budget:
            return None
        n, line = mutant
        lines = original.split("\n")
        lines[n] = line
        worker = workers.get()
        try:
            return worker.run(name, "\n".join(lines), timeouts)
        finally:
            workers.put(worker)

    survivors, unrun = [], 0
    with concurrent.futures.ThreadPoolExecutor(jobs) as pool:
        for name, original, found, timeouts, _, code_hash, test_hash, whole in plan:
            killed = list(pool.map(lambda m: one(name, original, m, timeouts), found))
            unrun += killed.count(None)
            print(f"script {name}: {killed.count(True)}/{len(found)}", flush=True)
            mine = [f"survivor {name}:{n + 1}: {line.strip()}" for (n, line), k in zip(found, killed) if k is False]
            survivors += mine
            if not mine and None not in killed and not again:
                count = f"{len(found)}/{len(found)}" if whole else proven.get(name, ["", "", "0/0"])[2]
                proven[name] = [code_hash, test_hash, count]
    while not workers.empty():
        shutil.rmtree(workers.get().root, ignore_errors=True)
    with open(PROOF, "w") as handle:
        handle.writelines(f"{name}\t" + "\t".join(row) + "\n" for name, row in sorted(proven.items()) if name in TESTS)
    if not again:
        alive = {name: lines for name, lines in previous.items() if name not in names}
        for survivor in survivors:
            name, n = survivor.split(" ")[1].rstrip(":").split(":")
            alive.setdefault(name, set()).add(int(n))
        with open(SURVIVORS, "w") as handle:
            handle.writelines(f"{name}\t{n}\n" for name, lines in sorted(alive.items()) for n in sorted(lines))
    print("\n".join(survivors)) if survivors else None
    print(f"survivors: {len(survivors)}")
    print(f"mutate-hooks: {time.monotonic() - started:.0f} s", file=sys.stderr)
    if unrun:
        print(f"mutate-hooks: {unrun} mutants unrun, the {budget:.0f} s budget ran out")
        return 3
    return 1 if survivors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
