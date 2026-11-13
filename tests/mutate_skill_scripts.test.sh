#!/usr/bin/env bash
# The mutation tool takes skill scripts as well as hook scripts, so no skill
# script is mutated by hand. A skill script is named by its path under the
# plugin. Python lines get Python's operators, and a deleted Python line
# keeps its indent as `pass`, so a mutant tests behaviour, not syntax.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
[ -n "${MUTATE_HOOKS_INNER:-}" ] && { echo "ok   skipped inside a mutation pass"; exit 0; }

copy="$dir/copy"; mkdir "$copy"; cp -r "$root/plugins" "$root/tests" "$copy/"
name=skills/productivity/video-captions/scripts/flatten-captions.sh
# Start with no proof for it, so the pass has to run and record one.
grep -v "^$name	" "$root/tests/mutation-proof.tsv" > "$copy/tests/mutation-proof.tsv"
out=$(timeout 300 python3 "$copy/tests/mutate-hooks.py" --jobs 2 "$name" 2>&1)
check "a skill script named by its path gets a mutation pass" 'grep -qE "^script $name: [0-9]+/[0-9]+" <<<"$out"'
check "its clean pass is recorded as a proof" 'grep -q "^$name	" "$copy/tests/mutation-proof.tsv"'
echo "# changed" >> "$copy/plugins/vicky-skills/$name"
check "a proven skill script joins the default check" 'python3 "$copy/tests/mutate-hooks.py" --check 2>&1 | grep -qx "stale: $name"'
check "a skill script with no tests mapped is refused" 'out=$(python3 "$copy/tests/mutate-hooks.py" skills/x/y/scripts/z.sh 2>&1); [ $? = 2 ] && grep -q "no tests mapped for: skills/x/y/scripts/z.sh" <<<"$out"'

py=$(python3 - "$root/tests/mutate-hooks.py" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("m", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
text = "#!/usr/bin/env python3\ndef f(a, b):\n    if a and not b:\n        return True\n    x = a == b\n    return False\n"
for n, line in m.mutants(text, None, py=True):
    print(f"{n}|{line}")
PY
)
check "a Python line swaps Python's operators" 'grep -qxF "2|    if a or not b:" <<<"$py" && grep -qxF "4|    x = a != b" <<<"$py" && grep -qxF "3|        return False" <<<"$py"'
check "a deleted Python line keeps its indent as pass" 'grep -qxF "4|    pass" <<<"$py" && ! grep -q "|:$" <<<"$py"'
check "a def line is never deleted" '! grep -qxF "1|pass" <<<"$py"'
py=$(python3 - "$root/tests/mutate-hooks.py" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("m", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
text = '#!/usr/bin/env python3\ndef f(a):\n    """Says a == b\n    and a or b."""\n    for x in a:\n        return x == 1\n'
for n, line in m.mutants(text, None, py=True):
    print(f"{n}|{line}")
PY
)
check "a line inside a string makes no mutant" '! grep -q "^[23]|" <<<"$py"'
check "a mutant that does not compile is never made" '! grep -qF "for x not in a" <<<"$py" && grep -qxF "5|        return x != 1" <<<"$py"'
py2=$(python3 - "$root/tests/mutate-hooks.py" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("m", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
text = '#!/usr/bin/env python3\ndef f(a):\n    say("not in backticks and done")  # a == b\n    return a in "x"\n'
for n, line in m.mutants(text, None, py=True):
    print(f"{n}|{line}")
PY
)
check "a swap inside a one-line string or a comment makes no mutant" '! grep -qF "backticks or done" <<<"$py2" && ! grep -qF "a != b" <<<"$py2" && ! grep -qF "in backticks and" <<<"$py2"'
check "code beside a string still mutates" 'grep -qxF "3|    return a not in \"x\"" <<<"$py2"'
exit $fail
