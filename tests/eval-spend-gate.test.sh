#!/usr/bin/env bash
# Every runner in tests/evals starts paid Claude sessions on the user's own
# credential. Each one refuses to start until EVAL_SPEND=yes says the spend
# is meant, so a run started from a glance at its name costs nothing.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/bin"
printf '#!/usr/bin/env bash\necho called >> "%s/calls"\nexit 0\n' "$dir" > "$dir/bin/claude"
chmod +x "$dir/bin/claude"
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
for r in "$root"/tests/evals/*.sh; do
  n=$(basename "$r")
  [ "$n" = lib.sh ] && continue
  rm -f "$dir/calls"
  out=$(cd "$dir" && PATH="$dir/bin:$PATH" EVAL_SPEND="" timeout 30 bash "$r" 2>&1); code=$?
  [ "$code" = 2 ] && ok "$n refuses without EVAL_SPEND=yes" || bad "$n refuses without EVAL_SPEND=yes: exit $code"
  grep -qF "EVAL_SPEND=yes" <<<"$out" && ok "$n names the opt-in" || bad "$n names the opt-in: got '$out'"
  grep -qF "paid" <<<"$out" && ok "$n says the runs are paid" || bad "$n says the runs are paid: got '$out'"
  [ ! -e "$dir/calls" ] && ok "$n starts no session" || bad "$n starts no session"
done
out=$(EVAL_SPEND=no bash -c '. "$1/tests/evals/lib.sh"' _ "$root" 2>&1); code=$?
[ "$code" = 2 ] && ok "any other value refuses" || bad "any other value refuses: exit $code"
out=$(EVAL_SPEND=yes EVAL_MODEL=m bash -c '. "$1/tests/evals/lib.sh"; echo loaded' _ "$root" 2>/dev/null); code=$?
[ "$code" = 0 ] && grep -qx loaded <<<"$out" && ok "EVAL_SPEND=yes lets the runner load" || bad "EVAL_SPEND=yes lets the runner load: exit $code"

# A pass records only where it can name one case folder in the real plugin.
mkdir -p "$dir/r/tests/evals" "$dir/r/plugins/vicky-skills/evals/a/hello" "$dir/r/plugins/vicky-skills/evals/b/hello" "$dir/copy/evals/a/solo"
cp "$root/tests/evals/lib.sh" "$dir/r/tests/evals/lib.sh"
run_pass() { PATH="$dir/bin:$PATH" EVAL_SPEND=yes EVAL_MODEL=m bash -c '. "$1/r/tests/evals/lib.sh" && eval_case "$2" "$3" out' _ "$dir" "$1" "$2" >/dev/null 2>&1; }
run_pass "$dir/r/plugins/vicky-skills" hello
[ ! -e "$dir/r/plugins/vicky-skills/evals/a/hello/passed" ] && [ ! -e "$dir/r/plugins/vicky-skills/evals/b/hello/passed" ] \
  && ok "a case name two skills share records no pass" || bad "a case name two skills share records no pass"
run_pass "$dir/copy" solo
[ ! -e "$dir/copy/evals/a/solo/passed" ] && ok "a pass on a plugin copy records nothing" || bad "a pass on a plugin copy records nothing"
exit $fail
