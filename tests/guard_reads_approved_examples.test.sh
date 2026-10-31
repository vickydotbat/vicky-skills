#!/usr/bin/env bash
# approved-spec: the examples approved for the approved-spec guard during the
# Todo list warp. Each check is named after its example and runs the hook.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/tests" "$dir/.github/workflows"
printf 'echo ok\n' > "$dir/tests/charm_approved_examples.test.sh"
printf 'steps:\n  - run: tests/charm_approved_examples.test.sh\n' > "$dir/.github/workflows/ci.yml"
printf 'sed -i s/ok/no/ tests/charm_approved_examples.test.sh\n' > "$dir/fix.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
decide() { jq -n --arg c "$1" --arg d "$dir" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | bash "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
w=.github/workflows/ci.yml
quiet=0
for c in "grep -n run $w" "cat $w" "sed -n 1,5p $w" "grep -n run $w | head; ls"; do
  [ -z "$(decide "$c")" ] && quiet=$((quiet + 1)) || echo "     asked: $c"
done
check "the CI workflow lists the approved-examples test files, and an agent reading it with grep, cat or sed -n runs with no question" '[ $quiet = 4 ]'
asks=0
for c in "bash fix.sh" "./fix.sh" "sh fix.sh" "ls && bash fix.sh"; do
  [ "$(decide "$c")" = ask ] && asks=$((asks + 1)) || echo "     not asked: $c"
done
check "a script that names an approved-examples file asks me first when an agent runs it, as today" '[ $asks = 4 ]'
exit $fail
