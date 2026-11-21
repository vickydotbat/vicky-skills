#!/usr/bin/env bash
# Regression tests beside mutation_load_approved_examples: these held before
# the CPU limit too, so they carry no approved-spec mark.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
. "$root/tests/lib/mutation-probe.sh"

# Found in the deathmatch: a process that leaves the test's session with setsid
# still counts toward its CPU limit, and is stopped with the test.
mark=$(mktemp -u); spin="$scratch/spin.test.sh"
printf '#!/usr/bin/env bash\nsetsid bash -c "echo \\$\\$ > %s; while :; do :; done" &\nwait\n' "$mark" > "$spin"
out=$(timeout 60 python3 - "$root/tests/mutate-hooks.py" "$scratch" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("mutate_hooks", sys.argv[1])
mh = importlib.util.module_from_spec(spec); spec.loader.exec_module(mh)
worker = mh.Worker.__new__(mh.Worker); worker.root = sys.argv[2]
import os; os.makedirs(os.path.join(sys.argv[2], "tests"), exist_ok=True)
os.replace(os.path.join(sys.argv[2], "spin.test.sh"), os.path.join(sys.argv[2], "tests", "spin.test.sh"))
print(worker.test("spin", 2, 20))
PY
)
sleep 0.5
left=$(cat "$mark" 2>/dev/null); alive=no; [ -n "$left" ] && kill -0 "$left" 2>/dev/null && { alive=yes; kill "$left"; }
rm -f "$mark"
check "a spinner that leaves the test's session dies on CPU, and stops with the test" '[ "$out" = cpu ] && [ $alive = no ]'

# ML2: a looping mutant dies on CPU, idle and with every core busy, never by the clock.
setup ml2 '[ "$x" = 1 ] || while :; do :; done # mutant-ok delete: the line only loops' 'bash "$hook"'
out=$(pass)
check "ML2 a looping mutant dies on an idle machine" 'grep -qE "^script $probe: ([0-9]+)/\1$" <<<"$out" && ! grep -q "^hung " <<<"$out"'
rm -f "$dir/calls" "$dir/tests/mutation-proof.tsv"
for _ in $(seq "$(nproc)"); do timeout 120 bash -c 'while :; do :; done' & busy+=($!); done
out=$(pass)
kill "${busy[@]}" 2>/dev/null; wait "${busy[@]}" 2>/dev/null
check "ML2 a looping mutant dies with every core busy" 'grep -qE "^script $probe: ([0-9]+)/\1$" <<<"$out" && ! grep -q "^hung " <<<"$out"'
slow=3
# ML4: a test that fails late, slow seconds past its usual time, kills its mutant through its result.
setup ml4 "[ \"\$x\" = 1 ] || { sleep $slow; exit 1; } # mutant-ok delete: the line only fails" "[ \$n -gt 1 ] && sleep $slow; bash \"\$hook\" || { echo 'FAIL the probe failed'; exit 1; }"
out=$(pass)
check "ML4 a slow test is judged by its result" 'grep -qE "^script $probe: [1-9][0-9]*/" <<<"$out" && ! grep -q "^hung " <<<"$out"'
exit $fail
