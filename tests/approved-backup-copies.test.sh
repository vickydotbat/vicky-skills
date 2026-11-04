#!/usr/bin/env bash
# A backup copy of an approved test (.new, .bak, .orig, a trailing ~) is no
# approved test: approved-spec-guard lets it be deleted or moved, and
# red-first-guard lets a commit run beside it.
set -u
scripts="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
repo="$dir/repo"; git init -q -b main "$repo"; mkdir "$repo/tests"
printf '# Given a\n# When b\n# Then c\nexit 1\n' > "$repo/tests/a_approved_examples.test.sh"
printf '# approved-spec: x\n# Given a\n# Then c\nexit 1\n' > "$repo/tests/marked.test.sh"
git -C "$repo" add -A; git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -qm base
fail=0
expect() { if [ "$3" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
spec() { jq -n --arg f "$1" '{tool_input:{file_path:$f}}' | bash "$scripts/approved-spec-guard.sh" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
rm_cmd() { jq -n --arg c "$1" --arg d "$repo" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | (cd "$repo" && bash "$scripts/approved-spec-guard.sh") | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
red() { jq -n --arg c "$1" --arg d "$repo" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' |
  CLAUDE_PLUGIN_OPTION_GUARD_RED_FIRST=true bash "$scripts/red-first-guard.sh" >/dev/null 2>&1; echo $?; }
expect "the approved test itself stays locked" deny "$(spec "$repo/tests/a_approved_examples.test.sh")"
for ext in new bak orig; do
  for base in a_approved_examples marked; do
    cp "$repo/tests/$base.test.sh" "$repo/tests/$base.test.sh.$ext"
    expect "an edit to $base.test.sh.$ext is free" "" "$(spec "$repo/tests/$base.test.sh.$ext")"
    expect "deleting $base.test.sh.$ext is free" "" "$(rm_cmd "rm tests/$base.test.sh.$ext")"
  done
  printf 'code\n' > "$repo/code.sh"
  expect "a commit beside a .$ext copy runs" 0 "$(red 'git add -A && git commit -m code')"
  rm -f "$repo"/tests/*."$ext" "$repo/code.sh"; git -C "$repo" reset -q
done
cp "$repo/tests/a_approved_examples.test.sh" "$repo/tests/a_approved_examples.test.sh~"
expect "an edit to a ~ copy is free" "" "$(spec "$repo/tests/a_approved_examples.test.sh~")"
printf 'code\n' > "$repo/code.sh"
expect "a commit beside a ~ copy runs" 0 "$(red 'git add -A && git commit -m code')"
rm -f "$repo/tests/a_approved_examples.test.sh~"
printf 'exit 1\n' > "$repo/tests/b_approved_examples.test.sh"
expect "a real new approved test with code is still refused" 2 "$(red 'git add -A && git commit -m both')"
exit $fail
