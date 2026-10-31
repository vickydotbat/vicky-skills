#!/usr/bin/env bash
# approved-spec: the example approved for the approved-spec guard during the
# Todo list warp: a new approved test asks nothing. Runs the hook.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir"
mkdir -p "$dir/tests"; printf 'echo ok\n' > "$dir/draft.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
bash_decide() { jq -n --arg c "$1" --arg d "$dir" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | bash "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
write_decide() { jq -n --arg f "$1" '{tool_name: "Write", tool_input: {file_path: $f, content: "echo ok"}}' | bash "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
n=tests/charm_approved_examples.test.sh
quiet=0
for c in "cat > $n <<'X'
echo ok
X" "cp draft.sh $n" "cp draft.sh $n && chmod +x tests/*_approved_examples.test.sh"; do
  [ -z "$(bash_decide "$c")" ] && quiet=$((quiet + 1)) || echo "     asked: $c"
done
[ -z "$(write_decide "$dir/$n")" ] && quiet=$((quiet + 1)) || echo "     asked: Write $n"
check "an agent creating an approved-examples file that does not exist yet runs with no question" '[ $quiet = 4 ]'
exit $fail
