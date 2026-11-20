#!/usr/bin/env bash
# Regression tests beside mutation_load_approved_examples: these held before
# the CPU limit too, so they carry no approved-spec mark.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
# setup <name> <script line> <test body>: a copy of the repo whose test map runs
# <name>.test.sh against probe.sh. The test body sees $hook and $calls.
setup() {
  dir="$scratch/$1"; mkdir -p "$dir"; cp -r "$root/plugins" "$root/tests" "$dir/"
  printf '#!/usr/bin/env bash\nx=1\n%s\n' "$2" > "$dir/plugins/vicky-skills/scripts/probe.sh"
  chmod +x "$dir/plugins/vicky-skills/scripts/probe.sh"
  { echo '#!/usr/bin/env bash'; echo "hook='$dir/plugins/vicky-skills/scripts/probe.sh'"; echo "calls='$dir/calls'"
    echo 'n=$(( $(cat "$calls" 2>/dev/null || echo 0) + 1 )); echo $n > "$calls"'; echo "$3"; } > "$dir/tests/probe.test.sh"
  chmod +x "$dir/tests/probe.test.sh"
  sed -i 's|    "gamma-shift.sh": \["gamma-shift"\],|&\n    "probe.sh": ["probe"],|' "$dir/tests/mutate-hooks.py"
  grep -q '"probe.sh": \["probe"\]' "$dir/tests/mutate-hooks.py" || { echo "FAIL the test map has no gamma-shift.sh line to put probe.sh after"; exit 1; }
}
pass() { timeout 300 python3 "$dir/tests/mutate-hooks.py" --jobs 1 probe.sh 2>&1; }
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; echo "$out"; fail=1; fi; }

# ML2: a looping mutant dies on CPU, idle and with every core busy, never by the clock.
setup ml2 '[ "$x" = 1 ] || while :; do :; done # mutant-ok delete: the line only loops' 'bash "$hook"'
out=$(pass)
check "ML2 a looping mutant dies on an idle machine" 'grep -qE "^script probe.sh: ([0-9]+)/\1$" <<<"$out" && ! grep -q "^hung " <<<"$out"'
rm -f "$dir/calls" "$dir/tests/mutation-proof.tsv"
busy=()
for _ in $(seq "$(nproc)"); do timeout 120 bash -c 'while :; do :; done' & busy+=($!); done
out=$(pass)
kill "${busy[@]}" 2>/dev/null; wait "${busy[@]}" 2>/dev/null
check "ML2 a looping mutant dies with every core busy" 'grep -qE "^script probe.sh: ([0-9]+)/\1$" <<<"$out" && ! grep -q "^hung " <<<"$out"'
# ML4: a test that fails late kills its mutant through its result.
setup ml4 '[ "$x" = 1 ] || { sleep 8; exit 1; } # mutant-ok delete: the line only fails' '[ $n -gt 1 ] && sleep 8; bash "$hook"'
out=$(pass)
check "ML4 a slow test is judged by its result" 'grep -qE "^script probe.sh: [1-9][0-9]*/" <<<"$out" && ! grep -q "^hung " <<<"$out"'
exit $fail
