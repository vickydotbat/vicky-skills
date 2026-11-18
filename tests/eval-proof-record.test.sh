#!/usr/bin/env bash
# approved-spec: the examples the user ticked on 2026-11-18 for "Date each
# proof": an eval run names the model it runs on, and a passing case keeps
# that model and the run's date in its folder, so a model change shows which
# laws to run again. A stub `claude` stands in for the paid session.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/repo/tests/evals" "$t/repo/plugins/vicky-skills/evals/greet/hello"
cp "$root/tests/evals/lib.sh" "$t/repo/tests/evals/lib.sh"
case_dir="$t/repo/plugins/vicky-skills/evals/greet/hello"
# The stub logs its arguments, and passes or fails as STUB_EXIT says.
printf '#!/usr/bin/env bash\necho "$*" >> "%s/calls"\nexit "${STUB_EXIT:-0}"\n' "$t" > "$t/bin/claude"
chmod +x "$t/bin/claude"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { # run <EVAL_MODEL value>: load lib.sh and run the hello case once
  PATH="$t/bin:$PATH" EVAL_SPEND=yes EVAL_MODEL="$1" bash -c \
    '. "$1/repo/tests/evals/lib.sh" && eval_case "$1/repo/plugins/vicky-skills" hello out' _ "$t" 2>&1
}

# Given an eval runner started with EVAL_SPEND=yes and no EVAL_MODEL
# When it starts
# Then it refuses before any paid session and says to set EVAL_MODEL to the model under test
out=$(PATH="$t/bin:$PATH" EVAL_SPEND=yes bash -c '. "$1/repo/tests/evals/lib.sh"; echo loaded' _ "$t" 2>&1); rc=$?
check "T1-1 with no EVAL_MODEL the runner refuses, names EVAL_MODEL and starts no session" \
  '[ $rc = 2 ] && grep -qF EVAL_MODEL <<<"$out" && ! grep -qx loaded <<<"$out" && [ ! -e "$t/calls" ]'

# Given EVAL_MODEL is set and an eval case passes
# When the runner finishes that case
# Then the case folder holds a passed file with the model and the date of the run
day0=$(date +%F); STUB_EXIT=0 run model-a >/dev/null; rc=$?; day1=$(date +%F)
check "T1-2 a passing case runs on EVAL_MODEL and records it with today's date" \
  '[ $rc = 0 ] && grep -qF -- "--model model-a" "$t/calls" && grep -qxE "model-a ($day0|$day1)" "$case_dir/passed"'

# And a case that fails leaves any earlier passed file as it was
echo "model-a 2026-01-01" > "$case_dir/passed"
STUB_EXIT=1 run model-b >/dev/null; rc=$?
check "T1-2 a failing case leaves the earlier passed file as it was" \
  '[ $rc = 1 ] && [ "$(cat "$case_dir/passed")" = "model-a 2026-01-01" ]'
exit $fail
