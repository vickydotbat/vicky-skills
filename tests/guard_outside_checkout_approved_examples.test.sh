#!/usr/bin/env bash
# approved-spec: the example approved for the approved-spec guard after the
# K5 council, when reads of a session log were refused. Each check is named
# after its example and runs the hook.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
# A session log quotes a test file, mark and all, and sits in no checkout.
printf '{"text":"# approved-spec: the examples"}\n' > "$dir/session.jsonl"
git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 && { echo "FAIL the scratch folder is inside a git checkout"; exit 1; }
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
decide() { jq -n --arg c "$1" --arg d "$dir" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | bash "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
passed=0
for c in "awk '{print}' session.jsonl" \
         "python3 -c 'print(open(\"session.jsonl\").read())'" \
         "sed -n 1p session.jsonl | python3 -c 'import sys; print(sys.stdin.read())'"; do
  [ -z "$(decide "$c")" ] && passed=$((passed + 1)) || echo "     refused: $c"
done
check "Given a file outside any git checkout that holds the approved-spec mark, such as a session log / When a command reads it with awk or python3 code of its own / Then the guard lets the command through" '[ $passed = 3 ]'
exit $fail
