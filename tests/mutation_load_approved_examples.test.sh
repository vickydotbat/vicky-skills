#!/usr/bin/env bash
# approved-spec: a machine's load decides no mutant's verdict. Each check runs
# the runner on a copy of the repo, with a small probe.sh as its subject.
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

# Given a mutant its tests cannot tell from the real script
# When the pass runs while every core is busy, and its tests take twice their usual time
# Then the mutant survives, as it does on an idle machine
# Every mutant's run takes 12 s of waiting, as a test starved of CPU does.
setup ml1 ': "$x"' '[ $n -gt 1 ] && sleep 12; bash "$hook"'
out=$(pass)
check "ML1 a busy machine kills no mutant" 'grep -qE "^script probe.sh: 0/[1-9]" <<<"$out"'

# Given a mutant that makes the script wait forever without working
# When the pass runs
# Then the pass stops its test, counts the mutant killed, and names it hung in its output
setup ml3 '[ "$x" = 1 ] || sleep 1000 # mutant-ok delete: the line only sleeps' 'bash "$hook"'
out=$(MUTATE_HOOKS_CEILING=4 pass)
check "ML3 a mutant that waits forever is named hung" \
  'grep -qE "^script probe.sh: ([0-9]+)/\1$" <<<"$out" && grep -qE "^hung probe.sh:3: " <<<"$out"'
exit $fail
