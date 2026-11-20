#!/usr/bin/env bash
# approved-spec: the examples set for a faster mutation runner, from the
# mutation runs of an earlier session. Each check runs the runner on a copy of
# the repo, with publickey-hint.sh as its small subject.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
cp -r "$root/plugins" "$root/tests" "$dir/"
runner="$dir/tests/mutate-hooks.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
proof() { grep "^publickey-hint.sh	" "$dir/tests/mutation-proof.tsv"; }
fresh() { bash "$runner" --check publickey-hint.sh >/dev/null 2>&1; }
# A pass first, so the copy's proof for publickey-hint.sh is fresh.
bash "$runner" --record --jobs 2 publickey-hint.sh >/dev/null 2>&1
printf '\n# A comment far from the test map.\n' >> "$dir/tests/mutate-hooks.py"
a=$(fresh; echo $?)
sed -i 's|    "publickey-hint.sh": \["publickey-hint"\],|    "publickey-hint.sh": ["publickey-hint", "refusal-note"],|' "$dir/tests/mutate-hooks.py"
b=$(fresh; echo $?)
check "a change to the runner outside one script's line in its test map leaves every proof fresh, and changing that line stales that script alone" \
  '[ "$a" = 0 ] && [ "$b" = 1 ] && bash "$runner" --check auto-tidy.sh >/dev/null 2>&1'
sed -i 's|    "publickey-hint.sh": \["publickey-hint", "refusal-note"\],|    "publickey-hint.sh": ["publickey-hint"],|' "$dir/tests/mutate-hooks.py"
# A line no test can see makes a survivor.
printf 'unseen=1\n' >> "$dir/plugins/vicky-skills/scripts/publickey-hint.sh"
bash "$runner" --jobs 2 publickey-hint.sh > "$dir/first.out" 2>&1
bash "$runner" --jobs 2 --survivors publickey-hint.sh > "$dir/again.out" 2>&1
check "after a pass that left one survivor, --survivors mutates only that survivor's line" \
  'n=$(grep -n "^unseen=1$" "$dir/plugins/vicky-skills/scripts/publickey-hint.sh" | cut -d: -f1) && grep -q "^survivor publickey-hint.sh:$n: " "$dir/first.out" && grep -q "^script publickey-hint.sh: 0/1$" "$dir/again.out"'
sed -i '/^unseen=1$/d' "$dir/plugins/vicky-skills/scripts/publickey-hint.sh"
sed -i '/^publickey-hint.sh	/d' "$dir/tests/mutation-proof.tsv"
bash "$runner" --jobs 2 publickey-hint.sh >/dev/null 2>&1
check "a pass with no survivors records its proof without --record" \
  'proof >/dev/null && fresh'
exit $fail
