#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its single-quoted condition later; the sed line writes shell text
# shellcheck disable=SC2034 # n is read inside check()'s eval
# mutate-hooks' kill reasons: a test that fails a mutant with no FAIL line
# leaves that mutant a survivor, MUTATE_HOOKS_SHOW_KILLS names the FAIL line
# behind a kill, and a mutant's test that prints without end can't grow the
# runner past its memory limit.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
cp -r "$root/plugins" "$root/tests" "$dir/"
runner="$dir/tests/mutate-hooks.sh"
hook="$dir/plugins/vicky-skills/scripts/publickey-hint.sh"
spec="$dir/tests/publickey-hint.test.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
printf 'unseen=1\n' >>"$hook"
n=$(grep -n '^unseen=1$' "$hook" | cut -d: -f1)
# The test dies with no FAIL line once the unseen line is gone.
sed -i '2i grep -q "^unseen=1$" "$(cd "$(dirname "$0")/.." \&\& pwd)/plugins/vicky-skills/scripts/publickey-hint.sh" || exit 3' "$spec"
MUTATE_HOOKS_SHOW_KILLS=1 bash "$runner" --jobs 2 publickey-hint.sh >"$dir/a.out" 2>&1
check "a kill with no FAIL line is named and left a survivor" \
  'grep -q "^no FAIL line publickey-hint.sh:$n: " "$dir/a.out" && grep -q "^survivor publickey-hint.sh:$n: " "$dir/a.out"'
check "MUTATE_HOOKS_SHOW_KILLS names the FAIL line behind a kill" \
  'grep -q "^kill publickey-hint.sh: publickey-hint: FAIL " "$dir/a.out"'
check "without it no kill line is printed" \
  '! bash "$runner" --jobs 2 publickey-hint.sh 2>&1 | grep -q "^kill "'
# Now the test prints 400 MB on one line before it dies, and the runner runs under a 700 MB address limit.
sed -i '2s/|| exit 3/|| { head -c 400000000 \/dev\/zero | tr "\\0" x; exit 3; }/' "$spec"
( ulimit -v 700000; bash "$runner" --jobs 1 publickey-hint.sh >"$dir/b.out" 2>&1 )
check "an endless output leaves the runner whole" 'grep -q "^survivor publickey-hint.sh:$n: " "$dir/b.out"'
exit $fail
