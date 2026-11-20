#!/usr/bin/env bash
# Regression tests beside mutation_load_approved_examples: these held before
# the CPU limit too, so they carry no approved-spec mark.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
# setup <name> <script line> <test body>: a copy of the repo whose test map runs
# <name>.test.sh against probe.sh. The test body sees $hook and $calls.
probe_dir=skills/testing/probe/scripts; probe=$probe_dir/probe.sh
setup() {
  dir="$scratch/$1"; mkdir -p "$dir"; cp -r "$root/plugins" "$root/tests" "$dir/"
  # A skill script, since the map adds the slow shared exit-code test to every hook script.
  mkdir -p "$dir/plugins/vicky-skills/$probe_dir"
  printf '#!/usr/bin/env bash\nx=1\n%s\n' "$2" > "$dir/plugins/vicky-skills/$probe"
  chmod +x "$dir/plugins/vicky-skills/$probe"
  { echo '#!/usr/bin/env bash'; echo "hook=\"\$(dirname \"\$0\")/../plugins/vicky-skills/$probe\""; echo "calls='$dir/calls'"
    echo 'n=$(( $(cat "$calls" 2>/dev/null || echo 0) + 1 )); echo $n > "$calls"'; echo "$3"; } > "$dir/tests/probe.test.sh"
  chmod +x "$dir/tests/probe.test.sh"
  sed -i "s|    \"gamma-shift.sh\": \\[\"gamma-shift\"\\],|&\\n    \"$probe\": [\"probe\"],|" "$dir/tests/mutate-hooks.py"
  grep -qF "\"$probe\": [\"probe\"]" "$dir/tests/mutate-hooks.py" || { echo "FAIL the test map has no gamma-shift.sh line to put probe.sh after"; exit 1; }
}
pass() { timeout 300 python3 "$dir/tests/mutate-hooks.py" --jobs 1 "$probe" 2>&1; }
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; echo "$out"; fail=1; fi; }

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
busy=()
for _ in $(seq "$(nproc)"); do timeout 120 bash -c 'while :; do :; done' & busy+=($!); done
out=$(pass)
kill "${busy[@]}" 2>/dev/null; wait "${busy[@]}" 2>/dev/null
check "ML2 a looping mutant dies with every core busy" 'grep -qE "^script $probe: ([0-9]+)/\1$" <<<"$out" && ! grep -q "^hung " <<<"$out"'
# ML4: a test that fails late kills its mutant through its result.
setup ml4 '[ "$x" = 1 ] || { sleep 3; exit 1; } # mutant-ok delete: the line only fails' '[ $n -gt 1 ] && sleep 3; bash "$hook"'
out=$(pass)
check "ML4 a slow test is judged by its result" 'grep -qE "^script $probe: [1-9][0-9]*/" <<<"$out" && ! grep -q "^hung " <<<"$out"'
exit $fail
